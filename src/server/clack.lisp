;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: LOL-WEB/SERVER; Base: 10 -*-
;;;; Clack request/response abstraction layer
;;;;
;;;; Provides a clean API over Clack's env plist for request handling
;;;; and standardized response builders.

(in-package :lol-web/server)

;;; ============================================================================
;;; REQUEST ENVIRONMENT
;;; ============================================================================

(defvar *env* nil
  "Current Clack request environment (plist).
   Bound during request handling.")

(defvar *response-headers* nil
  "Accumulated response headers for current request.
   Used by add-response-header and included in final response.")

;;; ============================================================================
;;; REQUEST ACCESSORS
;;; ============================================================================

(defun request-path ()
  "Get request path from Clack env.
   Returns the path portion of the URL (e.g., \"/api/users\")."
  (getf *env* :path-info "/"))

(defun request-method ()
  "Get request method as keyword (:GET, :POST, :PUT, :DELETE, etc.)."
  (getf *env* :request-method :get))

(defun request-query-string ()
  "Get raw query string (without leading ?)."
  (getf *env* :query-string ""))

(defun request-header (name)
  "Get request header by name (case-insensitive).
   NAME can be a string or keyword."
  (let ((headers (getf *env* :headers)))
    (when headers
      (gethash (string-downcase (string name)) headers))))

(defun request-content-type ()
  "Get Content-Type header value."
  (getf *env* :content-type))

(defun request-content-length ()
  "Get Content-Length as integer, or NIL if not present."
  (getf *env* :content-length))

(defun request-body ()
  "Get raw request body as a UTF-8 decoded string.
   Prefers the cached octet vector populated by build-clack-env so that
   repeated calls return the same body — historically reading :raw-body
   as a stream would silently return NIL on second access. Falls back
   to draining :raw-body for environments that bypass build-clack-env."
  (let ((cached (getf *env* :lol/cached-body)))
    (cond
      (cached
       (babel:octets-to-string cached :encoding :utf-8))
      (t
       (let ((body-stream (getf *env* :raw-body)))
         (when body-stream
           (let ((content-length (request-content-length)))
             (if content-length
                 (let ((octets (make-array content-length :element-type '(unsigned-byte 8))))
                   (read-sequence octets body-stream)
                   (babel:octets-to-string octets :encoding :utf-8))
                 (let ((octets (alexandria:read-stream-content-into-byte-vector body-stream)))
                   (when (> (length octets) 0)
                     (babel:octets-to-string octets :encoding :utf-8)))))))))))

;;; ============================================================================
;;; JSON ENCODE / DECODE
;;; ============================================================================
;;;
;;; The public API is encode-json-string and decode-json-string. Decoded values
;;; come back as alists with kebab-cased keyword keys, lists for arrays, and
;;; NIL for null. Encoding accepts the same shape: alists become JSON objects,
;;; proper lists become arrays, NIL becomes null. The internal helpers below
;;; bridge between this shape and the underlying jzon parser/stringifier.

(defun %camel-to-kebab-keyword (s)
  "Map a JSON object key string to a Lisp keyword by inserting a hyphen at
   each lowercase→uppercase boundary, then upcasing. \"componentId\" → :COMPONENT-ID."
  (intern
   (with-output-to-string (out)
     (loop for c across s
           for i from 0
           do (when (and (> i 0)
                         (upper-case-p c)
                         (lower-case-p (char s (1- i))))
                (write-char #\- out))
              (write-char (char-upcase c) out)))
   :keyword))

(defun %jzon-to-alist-shape (elt)
  "Recursively convert a jzon-parsed element to the public decode shape:
   alists with keyword keys, lists for arrays, NIL for null."
  (cond
    ((stringp elt) elt)
    ((hash-table-p elt)
     (loop for k being the hash-keys of elt using (hash-value v)
           collect (cons (%camel-to-kebab-keyword k)
                         (%jzon-to-alist-shape v))))
    ((vectorp elt)
     (map 'list #'%jzon-to-alist-shape elt))
    ((eq elt 'null) nil)
    (t elt)))

(defun %alist-of-conses-p (x)
  "True iff X is a non-empty list whose every element is (atom . anything).
   Heuristic for treating X as an alist-encoded JSON object."
  (and (consp x)
       (every (lambda (cell) (and (consp cell) (atom (car cell)))) x)))

(defun %coerce-key-to-string (k)
  (cond ((stringp k) k)
        ((keywordp k) (string-downcase (symbol-name k)))
        ((symbolp k) (string-downcase (symbol-name k)))
        (t (princ-to-string k))))

(defun %coerce-for-jzon (x)
  "Recursively coerce alist/list/scalar shapes into jzon-encodable forms.
   Alists → hash-tables (string keys), proper lists → vectors, NIL → null."
  (cond
    ((null x) 'null)
    ((eq x t) t)
    ((hash-table-p x) x)
    ((stringp x) x)
    ((numberp x) x)
    ((%alist-of-conses-p x)
     (let ((ht (make-hash-table :test 'equal)))
       (dolist (cell x ht)
         (setf (gethash (%coerce-key-to-string (car cell)) ht)
               (%coerce-for-jzon (cdr cell))))))
    ((vectorp x) (map 'vector #'%coerce-for-jzon x))
    ((listp x) (map 'vector #'%coerce-for-jzon x))
    ((symbolp x) (string-downcase (symbol-name x)))
    (t x)))

(defun encode-json-string (data)
  "Encode DATA to a JSON string. Auto-detects alists and encodes them as
   JSON objects; encodes proper lists as arrays; NIL as null; T as true."
  (com.inuoe.jzon:stringify (%coerce-for-jzon data)))

(defun decode-json-string (string)
  "Parse STRING as JSON. Returns alists with kebab-cased keyword keys,
   lists for arrays, NIL for null. Returns NIL on empty or malformed input."
  (when (and string (> (length string) 0))
    (handler-case
        (%jzon-to-alist-shape (com.inuoe.jzon:parse string))
      (com.inuoe.jzon:json-error () nil))))

(defun parse-request-json ()
  "Parse the request body as JSON, memoizing the result in *env* under
   :lol/cached-body-json. Returns NIL if the body is empty or not valid JSON.

   Single chokepoint for JSON-body parsing: every caller (request-body-json
   and the :json-body extractor in :lol-web/extractors) routes through this
   one to avoid double-decoding the same request payload. Returns the alist
   shape produced by decode-json-string so callers can use
   (cdr (assoc :foo body-json))."
  (let ((cached (getf *env* :lol/cached-body-json 'unbound)))
    (if (eq cached 'unbound)
        (let ((parsed (decode-json-string (request-body))))
          ;; Cache even NIL so a malformed body doesn't get re-parsed on
          ;; every accessor call.
          (setf (getf *env* :lol/cached-body-json) parsed)
          parsed)
        cached)))

(defun request-body-json ()
  "Parse request body as JSON. Returns NIL if body is empty or not valid JSON.
   Memoized via parse-request-json — calling this multiple times in one
   request hits the cache after the first decode."
  (parse-request-json))

;;; ============================================================================
;;; PARAMETER ACCESSORS
;;; ============================================================================

(defun query-param (name)
  "Get query parameter by name.
   NAME is a string. Returns NIL if not found."
  (let ((params (getf *env* :query-parameters)))
    (cdr (assoc name params :test #'string=))))

(defun query-params ()
  "Get all query parameters as alist of (name . value)."
  (getf *env* :query-parameters))

(defun post-param (name)
  "Get POST parameter by name.
   NAME is a string. Returns NIL if not found."
  (let ((params (getf *env* :body-parameters)))
    (cdr (assoc name params :test #'string=))))

(defun post-params ()
  "Get all POST parameters as alist of (name . value)."
  (getf *env* :body-parameters))

(defun param (name)
  "Get parameter by name, checking POST first, then query string.
   NAME is a string."
  (or (post-param name)
      (query-param name)))

;;; ============================================================================
;;; RESPONSE BUILDERS
;;; ============================================================================

(defun response (status &key headers body content-type)
  "Build a Clack response list: (status headers-plist body-list).

   STATUS: HTTP status code (integer)
   HEADERS: Additional headers as plist
   BODY: Response body (string or list of strings)
   CONTENT-TYPE: Convenience for setting Content-Type header

   Accumulated headers from *response-headers* are included automatically."
  (let ((all-headers (append
                      (when content-type
                        (list :content-type content-type))
                      *response-headers*
                      headers)))
    (list status
          all-headers
          (if (listp body) body (list body)))))

(defun html-response (body &key (status 200) headers)
  "Build an HTML response with proper Content-Type.

   BODY: HTML string
   STATUS: HTTP status code (default 200)
   HEADERS: Additional headers"
  (response status
            :content-type "text/html; charset=utf-8"
            :headers headers
            :body body))

(defun json-response (data &key (status 200) headers)
  "Build a JSON response, encoding DATA to JSON string.

   DATA: Lisp data structure to encode
   STATUS: HTTP status code (default 200)
   HEADERS: Additional headers"
  (response status
            :content-type "application/json; charset=utf-8"
            :headers headers
            :body (encode-json-string data)))

(defun text-response (body &key (status 200) headers)
  "Build a plain text response.

   BODY: Text string
   STATUS: HTTP status code (default 200)
   HEADERS: Additional headers"
  (response status
            :content-type "text/plain; charset=utf-8"
            :headers headers
            :body body))

(defun redirect-response (url &key (status 302) headers)
  "Build a redirect response.

   URL: Target URL for redirect
   STATUS: HTTP status (302 for temporary, 301 for permanent)
   HEADERS: Additional headers"
  (response status
            :headers (append (list :location url) headers)
            :body nil))

(defun error-response (status &key message headers content-type)
  "Build an error response.

   STATUS: HTTP error status code
   MESSAGE: Error message (optional)
   HEADERS: Additional headers
   CONTENT-TYPE: Response content type"
  (response status
            :content-type (or content-type "text/plain; charset=utf-8")
            :headers headers
            :body (or message (http-status-text status))))

;;; ============================================================================
;;; RESPONSE HEADER ACCUMULATION
;;; ============================================================================

(defmacro with-response-headers (() &body body)
  "Execute BODY with fresh response header accumulation.
   Headers added via add-response-header will be included in final response."
  `(let ((*response-headers* nil))
     ,@body))

(defun add-response-header (name value)
  "Add a header to the current response.
   NAME: Header name (string or keyword)
   VALUE: Header value (string)

   Must be called within with-response-headers context."
  ;; Headers are accumulated as plist, push in reverse order
  (push value *response-headers*)
  (push (if (keywordp name)
            name
            (intern (string-upcase name) :keyword))
        *response-headers*))

(defun get-response-headers ()
  "Get currently accumulated response headers as plist."
  *response-headers*)

;;; ============================================================================
;;; HTTP STATUS HELPERS
;;; ============================================================================

(defun http-status-text (code)
  "Get standard text for HTTP status code."
  (case code
    (200 "OK")
    (201 "Created")
    (204 "No Content")
    (301 "Moved Permanently")
    (302 "Found")
    (304 "Not Modified")
    (400 "Bad Request")
    (401 "Unauthorized")
    (403 "Forbidden")
    (404 "Not Found")
    (405 "Method Not Allowed")
    (409 "Conflict")
    (422 "Unprocessable Entity")
    (429 "Too Many Requests")
    (500 "Internal Server Error")
    (502 "Bad Gateway")
    (503 "Service Unavailable")
    (otherwise "Unknown Status")))

;;; ============================================================================
;;; SESSION ACCESSORS (Lack middleware integration)
;;; ============================================================================

(defun session-get (key)
  "Get value from Lack session.
   KEY can be a symbol or string.
   Returns NIL if session not available or key not found."
  (let ((session (getf *env* :lack.session)))
    (when session
      (gethash key session))))

(defun session-set (key value)
  "Set value in Lack session.
   KEY can be a symbol or string.
   VALUE is any serializable Lisp value.
   Returns VALUE, or NIL if session not available."
  (let ((session (getf *env* :lack.session)))
    (when session
      (setf (gethash key session) value))))

(defun session-delete (key)
  "Remove key from Lack session.
   Returns T if key was present, NIL otherwise."
  (let ((session (getf *env* :lack.session)))
    (when session
      (remhash key session))))

(defun session-clear ()
  "Clear all session data.
   Returns T if session was available, NIL otherwise."
  (let ((session (getf *env* :lack.session)))
    (when session
      (clrhash session)
      t)))

(defun session-keys ()
  "Get list of all session keys."
  (let ((session (getf *env* :lack.session)))
    (when session
      (loop for key being the hash-keys of session collect key))))

;;; ============================================================================
;;; CSRF INTEGRATION (Lack middleware)
;;; ============================================================================

(defun csrf-token ()
  "Get current CSRF token from session.
   Works with both Lack CSRF middleware and custom CSRF (security.lisp).
   Returns NIL if session not available."
  (session-get "csrf-token"))
