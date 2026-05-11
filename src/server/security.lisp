;;;; LOL-REACTIVE Security
;;;; Security headers and CSRF protection.
;;;;
;;;; Provides:
;;;; - add-security-headers: Standard security headers
;;;; - with-security: Wrap handlers with security
;;;; - generate-csrf-token / validate-csrf-token: CSRF surface
;;;; - check-rate-limit / with-rate-limit: rate limiting
;;;;
;;;; Input sanitization (sanitize-html, sanitize-attribute, sanitize-url)
;;;; lives in :lol-web/sanitize so it can be consumed without dragging in
;;;; the full server stack.

(in-package :lol-web/server)

;;; ═══════════════════════════════════════════════════════════════════════════
;;; Security Headers
;;; ═══════════════════════════════════════════════════════════════════════════

(defun add-security-headers ()
  "Add standard security headers to the current response.
   Must be called within a with-response-headers context.

   Headers added:
   - X-Frame-Options: DENY - Prevent clickjacking
   - X-Content-Type-Options: nosniff - Prevent MIME sniffing
   - X-XSS-Protection: 1; mode=block - Enable XSS filter
   - Referrer-Policy: strict-origin-when-cross-origin - Control referrer info"
  (add-response-header "X-Frame-Options" "DENY")
  (add-response-header "X-Content-Type-Options" "nosniff")
  (add-response-header "X-XSS-Protection" "1; mode=block")
  (add-response-header "Referrer-Policy" "strict-origin-when-cross-origin"))

(defun add-csp-header (&key (default-src "'self'")
                            (script-src "'self' 'unsafe-inline' https://cdn.tailwindcss.com")
                            (style-src "'self' 'unsafe-inline' https://fonts.googleapis.com")
                            (font-src "'self' https://fonts.gstatic.com")
                            (img-src "'self' data: https:")
                            (connect-src "'self'"))
  "Add Content-Security-Policy header with customizable directives.
   Default allows Tailwind CDN and Google Fonts.
   Must be called within a with-response-headers context.

   Example:
     (add-csp-header :script-src \"'self'\" :style-src \"'self'\")"
  (add-response-header "Content-Security-Policy"
                       (format nil "default-src ~A; script-src ~A; style-src ~A; font-src ~A; img-src ~A; connect-src ~A"
                               default-src script-src style-src font-src img-src connect-src)))

(defmacro with-security (&body body)
  "Wrap handler with security headers.
   Convenience macro that adds security headers before executing body.

   Example:
     (defroute \"/api/data\" (:method :get)
       (with-security
         (get-data-json)))"
  `(progn
     (add-security-headers)
     ,@body))

;;; ═══════════════════════════════════════════════════════════════════════════
;;; CSRF Protection
;;; ═══════════════════════════════════════════════════════════════════════════

(defun generate-csrf-token ()
  "Generate a 128-bit CSRF token from the OS CSPRNG, hex-encoded.
   ironclad:random-data reads from /dev/urandom (or platform equivalent);
   plain CL `random` is a PRNG only and unsuitable for security tokens."
  (let ((bytes (ironclad:random-data 16)))
    (with-output-to-string (s)
      (loop for byte across bytes
            do (format s "~(~2,'0X~)" byte)))))

(defun get-csrf-token ()
  "Get current CSRF token from session, creating if needed.
   Uses Lack session middleware via *env*.
   Note: Uses string key to match Lack CSRF middleware configuration."
  (or (session-get "csrf-token")
      (session-set "csrf-token" (generate-csrf-token))))

(defun constant-time-string= (a b)
  "Compare two strings in time proportional to MAX(|a|,|b|), independent of
   matching prefix length. XOR-folds char codes into a single accumulator and
   tests it against zero only after the full pass. Returns NIL when lengths
   differ (length is non-secret) but does not short-circuit on character
   mismatch within equal-length inputs."
  (declare (type string a b)
           (optimize (speed 3) (safety 1)))
  (and (= (length a) (length b))
       (let ((acc 0))
         (declare (type (unsigned-byte 32) acc))
         (loop for ca across a
               for cb across b
               do (setf acc (logior acc
                                    (logxor (char-code ca) (char-code cb)))))
         (zerop acc))))

(defun validate-csrf-token (token)
  "Validate CSRF token from request matches session token.
   Returns T if valid, NIL if invalid. Uses constant-time-string= so a
   timing side channel cannot leak the matching prefix length to an
   attacker controlling the submitted token.
   Note: Uses string key to match Lack CSRF middleware configuration."
  (when token
    (let ((session-token (session-get "csrf-token")))
      (and session-token
           (constant-time-string= token session-token)))))

(defun csrf-token-input ()
  "Generate hidden input field with CSRF token.
   Include this in all forms that modify data.
   Uses html-attrs for proper attribute escaping.

   Example (in cl-who):
     (:form :method \"post\" :action \"/submit\"
       (who:str (csrf-token-input))
       ...)"
  (format nil "<input~A/>"
          (html-attrs "type" "hidden"
                      "name" "csrf-token"
                      "value" (get-csrf-token))))

(defmacro with-csrf-validation (&body body)
  "Wrap handler with CSRF token validation.
   Returns 403 Forbidden response if token is invalid.

   Example:
     (defroute \"/submit\" (:method :post)
       (with-csrf-validation
         (process-form)))"
  `(let ((token (post-param "csrf-token")))
     (if (validate-csrf-token token)
         (progn ,@body)
         (error-response 403
                         :content-type "text/html; charset=utf-8"
                         :message (minimal-error-html "403 Forbidden" "403" "Invalid or missing CSRF token")))))

;;; ═══════════════════════════════════════════════════════════════════════════
;;; Rate Limiting (Simple In-Memory)
;;; ═══════════════════════════════════════════════════════════════════════════

(defvar *rate-limit-store* (make-hash-table :test 'equal)
  "In-memory store for rate limiting. Maps IP -> (count . timestamp).
   All access serialised through *rate-limit-lock*.")

(defvar *rate-limit-lock* (bordeaux-threads:make-lock "lol-reactive rate-limit")
  "Guards *rate-limit-store*. Plain SBCL hash-tables are not thread-safe under
   concurrent read-modify-write — without this lock two requests racing on the
   same IP either lose an increment or corrupt the table outright.")

(defvar *rate-limit-max-entries* 10000
  "Soft cap on *rate-limit-store* size. When a new IP would push the count over
   the cap, expired entries are swept first; if still over, the single oldest
   entry by timestamp is evicted. Prevents unbounded growth from rotating
   client IPs (legitimate or X-Forwarded-For spoofed).")

(defun %evict-rate-limit-entries (window-seconds now)
  "Caller must hold *rate-limit-lock*. Drop entries whose window has expired;
   if the store is still at or above the cap, drop the single oldest entry."
  (let ((store *rate-limit-store*)
        (stale '()))
    (maphash (lambda (ip entry)
               (when (> (- now (cdr entry)) window-seconds)
                 (push ip stale)))
             store)
    (dolist (ip stale) (remhash ip store))
    (when (>= (hash-table-count store) *rate-limit-max-entries*)
      (let ((oldest-ip nil)
            (oldest-ts nil))
        (maphash (lambda (ip entry)
                   (let ((ts (cdr entry)))
                     (when (or (null oldest-ts) (< ts oldest-ts))
                       (setf oldest-ip ip
                             oldest-ts ts))))
                 store)
        (when oldest-ip (remhash oldest-ip store))))))

(defun check-rate-limit (ip &key (max-requests 100) (window-seconds 60))
  "Check if IP is within rate limit.
   Returns T if allowed, NIL if rate limited.
   Default: 100 requests per 60 seconds per IP.
   All store reads and writes happen under *rate-limit-lock* so concurrent
   requests for the same IP cannot lose increments or corrupt the table.
   Bounds growth at *rate-limit-max-entries* via expiry sweep + oldest-eviction."
  (bordeaux-threads:with-lock-held (*rate-limit-lock*)
    (let* ((now (get-universal-time))
           (entry (gethash ip *rate-limit-store*))
           (count (if entry (car entry) 0))
           (timestamp (if entry (cdr entry) now)))
      (when (> (- now timestamp) window-seconds)
        (setf count 0
              timestamp now))
      (cond
        ((>= count max-requests) nil)
        (t
         (when (and (null entry)
                    (>= (hash-table-count *rate-limit-store*)
                        *rate-limit-max-entries*))
           (%evict-rate-limit-entries window-seconds now))
         (setf (gethash ip *rate-limit-store*) (cons (1+ count) timestamp))
         t)))))

(defun %first-forwarded-ip (header)
  "Return the first non-empty IP in a comma-delimited X-Forwarded-For chain,
   trimmed of surrounding whitespace. NIL when the chain is empty or all-blank.
   Per RFC 7239 the leftmost address is the originating client; using the
   whole header as a rate-limit key lets attackers bypass limits trivially by
   appending '1.2.3.4, anything' to vary the key per request."
  (when header
    (loop for tok in (cl-ppcre:split "," header)
          for trimmed = (string-trim '(#\Space #\Tab) tok)
          when (plusp (length trimmed))
            return trimmed)))

(defun get-client-ip ()
  "Get client IP address.
   Prefers the leftmost X-Forwarded-For entry (RFC 7239 originating client),
   then X-Real-IP, then Clack's :remote-addr. Reads from *env*."
  (or (%first-forwarded-ip (request-header "X-Forwarded-For"))
      (request-header "X-Real-IP")
      (getf *env* :remote-addr)))

(defmacro with-rate-limit ((&key (max-requests 100) (window-seconds 60)) &body body)
  "Wrap handler with rate limiting.
   Returns 429 Too Many Requests response if limit exceeded."
  `(let ((ip (get-client-ip)))
     (if (check-rate-limit ip :max-requests ,max-requests :window-seconds ,window-seconds)
         (progn ,@body)
         (error-response 429
                         :content-type "text/html; charset=utf-8"
                         :message (minimal-error-html "429 Too Many Requests" "429"
                                                      "You're making too many requests. Please slow down.")))))
