;;;; Regression tests for :lol-web/server.
;;;;
;;;; Covers: minimal-error-html token decoupling, CSRF token shape +
;;;; constant-time compare + end-to-end validate, clack param accessors,
;;;; request-body memoization, streaming-route dispatch, rate-limit
;;;; thread-safety + bounded store, X-Forwarded-For parsing fallbacks,
;;;; HTTP-error condition hierarchy + with-error-handling translation,
;;;; JSON encode/decode round-trip + parse-request-json memoization.

(in-package :lol-web/server/test)
(in-suite :lol-web/server/test)

;;; ============================================================================
;;; minimal-error-html — design-token decoupling
;;; ============================================================================

(test regression-minimal-error-html-no-design-token-coupling
  "minimal-error-html does not reference design-token getters or CSS vars"
  (let ((html (lol-web/server::minimal-error-html "Test" "Heading" "Message")))
    (is (search "Heading" html))
    (is (search "Message" html))
    (is (search "<style>" html))
    (is (null (search "--color-background" html))
        "minimal-error-html must not declare --color-* CSS variables")
    (is (null (search "--font-family" html))
        "minimal-error-html must not declare --font-family CSS variable")
    (is (null (search ":root {" html))
        "minimal-error-html must not emit a :root CSS block (token leak)")))

;;; ============================================================================
;;; CSRF — token shape, constant-time compare, end-to-end validate
;;; ============================================================================

(test regression-csrf-token-shape
  "generate-csrf-token returns 32 lowercase hex chars and varies per call"
  (let ((t1 (generate-csrf-token))
        (t2 (generate-csrf-token)))
    (is (= 32 (length t1)) "token length must be 32 hex chars (128 bits)")
    (is (every (lambda (c) (digit-char-p c 16)) t1)
        "token must be hex-only")
    (is (not (string= t1 t2))
        "consecutive tokens must differ (CSPRNG, not seeded PRNG)")))

(test regression-constant-time-string-equal-correctness
  "constant-time-string= matches string= for the equality predicate itself"
  (is (lol-web/server::constant-time-string= "" "")
      "two empty strings are equal")
  (is (lol-web/server::constant-time-string= "abcd1234" "abcd1234")
      "identical non-empty strings are equal")
  (is (not (lol-web/server::constant-time-string= "abc" "abcd"))
      "different-length strings are not equal")
  (is (not (lol-web/server::constant-time-string= "abcd" "abce"))
      "same-length, last-char-different strings are not equal")
  (is (not (lol-web/server::constant-time-string= "abcdefgh01234567"
                                                  "abcdefgh76543210"))
      "matching prefix is not enough for equality"))

(test regression-csrf-validate-end-to-end
  "validate-csrf-token returns T for matching tokens, NIL for any mismatch,
   when given a faked Lack session via *env* binding"
  (let* ((stored "deadbeefdeadbeefdeadbeefdeadbeef")
         (fake-session (make-hash-table :test 'equal)))
    (setf (gethash "csrf-token" fake-session) stored)
    (let ((*env* (list :lack.session fake-session)))
      (is (validate-csrf-token stored)
          "matching token validates")
      (is (null (validate-csrf-token nil))
          "NIL token rejected")
      (is (null (validate-csrf-token ""))
          "empty token rejected (length mismatch)")
      (is (null (validate-csrf-token
                  "deadbeefdeadbeefdeadbeefdeadbeeg"))
          "single-char-different token rejected")
      (is (null (validate-csrf-token "deadbeef"))
          "shorter prefix-match token rejected"))))

;;; ============================================================================
;;; Clack env — :query-parameters / :body-parameters; request-body memoization
;;; ============================================================================

(test regression-clack-param-accessors-read-populated-env
  "query-param / post-param / param all read from the populated env keys"
  (let ((*env*
          '(:query-parameters (("name" . "alice") ("color" . "blue"))
            :body-parameters (("name" . "bob") ("submit" . "ok")))))
    (is (string= "alice" (query-param "name")))
    (is (string= "blue"  (query-param "color")))
    (is (null (query-param "missing")))
    (is (string= "bob" (post-param "name")))
    (is (string= "ok"  (post-param "submit")))
    (is (null (post-param "missing")))
    (is (string= "bob" (param "name")))
    (is (string= "blue" (param "color")))))

(test regression-request-body-memoized-via-cached-bytes
  "request-body reads :lol/cached-body so repeated calls return the same string"
  (let* ((bytes (babel:string-to-octets "hello=world&n=42" :encoding :utf-8))
         (*env* (list :lol/cached-body bytes
                      :content-length (length bytes))))
    (let ((first  (request-body))
          (second (request-body)))
      (is (string= "hello=world&n=42" first))
      (is (string= first second)
          "request-body must be idempotent across repeated calls"))))

(test regression-form-body-content-type-accepts-multipart
  "%form-body-content-type-p must accept both
   application/x-www-form-urlencoded and multipart/form-data, so
   build-clack-env populates :body-parameters for file-upload POSTs.
   Without multipart acceptance, (post-param NAME) returns NIL on
   every form whose enctype is multipart/form-data — exactly the
   shape forms/form-dsl.lisp emits when any field is :file."
  (is (lol-web/server::%form-body-content-type-p
       "application/x-www-form-urlencoded")
      "plain form encoding accepted")
  (is (lol-web/server::%form-body-content-type-p
       "application/x-www-form-urlencoded; charset=utf-8")
      "plain form encoding with charset accepted")
  (is (lol-web/server::%form-body-content-type-p
       "multipart/form-data; boundary=----WebKitFormBoundaryXYZ")
      "multipart with boundary parameter accepted (browser file uploads)")
  (is (lol-web/server::%form-body-content-type-p
       "MULTIPART/FORM-DATA; boundary=abc")
      "case-insensitive match (Content-Type values are not case-sensitive)")
  (is (null (lol-web/server::%form-body-content-type-p
             "application/json"))
      "JSON bodies must not be routed through post-parameters")
  (is (null (lol-web/server::%form-body-content-type-p
             "text/plain"))
      "plain text bodies must not be routed through post-parameters")
  (is (null (lol-web/server::%form-body-content-type-p nil))
      "missing Content-Type header (NIL) must not match"))

;;; ============================================================================
;;; Streaming-route dispatch wins over regular dispatch
;;; ============================================================================

(test regression-streaming-routes-dispatch-wins-over-regular
  "When the same path is registered as streaming, streaming dispatch runs first"
  (let ((path "/regression/streaming-probe"))
    (unwind-protect
         (let ((streaming-called 0)
               (regular-called 0))
           (setf (gethash (cons :get path) lol-web/server::*streaming-routes*)
                 (lambda (env)
                   (declare (ignore env))
                   (incf streaming-called)
                   '(200 (:content-type "text/plain") ("ok"))))
           (setf (gethash (cons :get path) *routes*)
                 (lambda ()
                   (incf regular-called)
                   '(200 (:content-type "text/plain") ("ok"))))
           (let ((env (list :request-method :get
                            :path-info path
                            :query-string "")))
             (route-handler env))
           (is (= 1 streaming-called)
               "streaming handler invoked exactly once")
           (is (zerop regular-called)
               "regular handler must NOT run when streaming registry has the route"))
      (remhash (cons :get path) lol-web/server::*streaming-routes*)
      (remhash (cons :get path) *routes*))))

;;; ============================================================================
;;; Rate limiting — thread-safe counter, bounded store, XFF parsing
;;; ============================================================================

(test regression-rate-limit-counter-thread-safe
  "check-rate-limit increments are serialised across concurrent threads"
  (clrhash *rate-limit-store*)
  (unwind-protect
       (let* ((ip "regression-rate-limit-thread-safe")
              (per-thread 200)
              (n-threads 16)
              (expected (* per-thread n-threads))
              (threads
                (loop repeat n-threads
                      collect (bordeaux-threads:make-thread
                                (lambda ()
                                  (dotimes (_ per-thread)
                                    (check-rate-limit
                                      ip
                                      :max-requests 1000000
                                      :window-seconds 3600)))))))
         (dolist (th threads) (bordeaux-threads:join-thread th))
         (let ((entry (gethash ip *rate-limit-store*)))
           (is (consp entry)
               "store entry must be a (count . timestamp) cons after concurrent updates")
           (is (= expected (car entry))
               "expected ~D increments, got ~A — concurrent updates lost"
               expected (and (consp entry) (car entry)))))
    (clrhash *rate-limit-store*)))

(test regression-rate-limit-store-bounded
  "rate-limit store size never exceeds *rate-limit-max-entries*"
  (clrhash *rate-limit-store*)
  (unwind-protect
       (let ((lol-web/server::*rate-limit-max-entries* 100))
         (dotimes (i 1000)
           (check-rate-limit (format nil "regression-bounded-ip-~D" i)
                             :max-requests 10
                             :window-seconds 3600))
         (is (<= (hash-table-count *rate-limit-store*) 100)
             "store size ~D exceeds cap of 100"
             (hash-table-count *rate-limit-store*)))
    (clrhash *rate-limit-store*)))

(test regression-get-client-ip-xff-first-only
  "get-client-ip returns only the leftmost X-Forwarded-For entry, trimmed"
  (flet ((with-xff (val)
           (let* ((h (make-hash-table :test 'equal))
                  (*env* (progn
                           (setf (gethash "x-forwarded-for" h) val)
                           (list :headers h))))
             (get-client-ip))))
    (is (string= "1.2.3.4" (with-xff "1.2.3.4, 10.0.0.1, 172.16.0.1"))
        "multi-IP chain must collapse to the first address")
    (is (string= "1.2.3.4" (with-xff "  1.2.3.4  "))
        "single-IP value must be trimmed of surrounding whitespace")
    (is (string= "1.2.3.4" (with-xff "1.2.3.4"))
        "single-IP unpadded value must pass through")
    (is (null (with-xff ""))
        "empty XFF must yield NIL so the X-Real-IP / :remote-addr fallback runs")
    (is (null (with-xff " ,  , "))
        "all-blank XFF tokens must yield NIL — never an empty IP key")))

(test regression-get-client-ip-fallbacks
  "get-client-ip falls back to X-Real-IP and then :remote-addr when XFF is absent"
  (let* ((h (make-hash-table :test 'equal))
         (*env* (progn
                  (setf (gethash "x-real-ip" h) "203.0.113.7")
                  (list :headers h :remote-addr "127.0.0.1"))))
    (is (string= "203.0.113.7" (get-client-ip))
        "X-Real-IP wins over :remote-addr"))
  (let* ((h (make-hash-table :test 'equal))
         (*env* (list :headers h :remote-addr "127.0.0.1")))
    (is (string= "127.0.0.1" (get-client-ip))
        ":remote-addr is the final fallback")))

;;; ============================================================================
;;; HTTP-error condition hierarchy + with-error-handling
;;; ============================================================================

(test regression-http-error-hierarchy-shape
  "http-error subclasses fix their status and inherit from client/server-error"
  (is (subtypep 'client-error 'http-error))
  (is (subtypep 'server-error 'http-error))
  (is (subtypep 'http-bad-request 'client-error))
  (is (subtypep 'http-unauthorized 'client-error))
  (is (subtypep 'http-forbidden 'client-error))
  (is (subtypep 'http-not-found 'client-error))
  (is (subtypep 'http-unprocessable-entity 'client-error))
  (is (= 400 (http-error-status (make-condition 'http-bad-request))))
  (is (= 401 (http-error-status (make-condition 'http-unauthorized))))
  (is (= 403 (http-error-status (make-condition 'http-forbidden))))
  (is (= 404 (http-error-status (make-condition 'http-not-found))))
  (is (= 422 (http-error-status
              (make-condition 'http-unprocessable-entity))))
  (is (string= "missing name"
               (http-error-body
                (make-condition 'http-bad-request :body "missing name"))))
  (is (null (http-error-body (make-condition 'http-not-found)))))

(test regression-with-error-handling-translates-http-error
  "with-error-handling catches http-error subclasses and emits the right status"
  (let ((response (with-error-handling "test"
                    (error 'http-not-found))))
    (is (= 404 (first response))
        "http-not-found must produce status 404, got ~A" (first response))
    (let ((body (third response)))
      (is (or (search "Not Found" (princ-to-string body))
              (search "Not Found" (with-output-to-string (s) (princ body s))))
          "404 body should mention 'Not Found', got ~S" body))))

(test regression-with-error-handling-honours-body-override
  "http-error :body is used in the response when supplied"
  (let ((response (with-error-handling "test"
                    (error 'http-bad-request
                           :body "missing 'name' parameter"))))
    (is (= 400 (first response)))
    (let ((body (third response)))
      (is (search "missing 'name' parameter"
                  (with-output-to-string (s)
                    (dolist (chunk body) (princ chunk s))))
          "400 body should contain custom message, got ~S" body))))

(test regression-with-error-handling-non-http-error-still-500
  "Non-http-error conditions still hit the catch-all 500 path"
  (let ((*error-output* (make-broadcast-stream))
        (*error-log-path* nil))
    (let ((response (with-error-handling "test"
                      (error "plain unhandled error"))))
      (is (= 500 (first response))
          "Plain (error ...) must produce status 500, got ~A" (first response)))))

;;; ============================================================================
;;; JSON — parse memoization, encode/decode round-trip
;;; ============================================================================

(test regression-parse-request-json-memoizes-result
  "parse-request-json caches the parsed result in *env*; second call hits the cache"
  (let* ((body-bytes (babel:string-to-octets "{\"name\":\"test\",\"count\":42}"
                                              :encoding :utf-8))
         (*env*
           (list :lol/cached-body body-bytes
                 :raw-body (flexi-streams:make-in-memory-input-stream body-bytes)
                 :content-type "application/json")))
    (let ((first (parse-request-json)))
      (is (consp first) "First call should return a non-empty alist, got ~S" first)
      (is (string= "test" (cdr (assoc :name first)))
          "Decoded :name should equal \"test\""))
    (is (not (eq 'unbound (getf *env* :lol/cached-body-json 'unbound)))
        ":lol/cached-body-json should be set after first parse")
    (let ((first  (getf *env* :lol/cached-body-json))
          (second (parse-request-json)))
      (is (eq first second)
          "Second parse-request-json call must return the cached object"))))

(test regression-decode-json-string-shapes
  "decode-json-string returns alists with kebab-keyword keys, lists for arrays,
   NIL for null/false, and NIL for empty or malformed input."
  (let ((decoded (decode-json-string
                  "{\"componentId\":\"x\",\"value\":42,\"items\":[1,2,3],\"flag\":true,\"empty\":null}")))
    (is (consp decoded) "decoded a non-empty alist")
    (is (string= "x" (cdr (assoc :component-id decoded)))
        "camelCase 'componentId' → :COMPONENT-ID, value preserved")
    (is (= 42 (cdr (assoc :value decoded)))
        "numbers preserved as numbers")
    (is (equal '(1 2 3) (cdr (assoc :items decoded)))
        "JSON arrays decode to lists, not vectors")
    (is (eq t (cdr (assoc :flag decoded)))
        "JSON true → CL T")
    (is (null (cdr (assoc :empty decoded)))
        "JSON null → CL NIL"))
  (is (equal '(1 2 3) (decode-json-string "[1,2,3]"))
      "top-level array decodes to plain list")
  (is (string= "hi" (decode-json-string "\"hi\""))
      "top-level string decodes to string (not a character list)")
  (is (null (decode-json-string ""))
      "empty input → NIL")
  (is (null (decode-json-string "{not json"))
      "malformed input → NIL (not an error)"))

(test regression-encode-json-string-shapes
  "encode-json-string auto-detects alists as objects, lists as arrays,
   NIL as null, T as true, and downcases keyword keys."
  (is (string= "{\"success\":true,\"html\":\"<p>x</p>\"}"
               (encode-json-string '((:success . t) (:html . "<p>x</p>"))))
      "alist of (keyword . value) → JSON object")
  (is (string= "[1,2,3]" (encode-json-string '(1 2 3)))
      "plain list → JSON array")
  (is (string= "null" (encode-json-string nil))
      "NIL → JSON null")
  (is (string= "true" (encode-json-string t))
      "T → JSON true")
  (is (string= "{\"type\":\"html\",\"items\":[1,2,3]}"
               (encode-json-string
                 '((:type . "html") (:items . (1 2 3)))))
      "nested: outer alist becomes object, inner list becomes array")
  (is (string= "[1,\"x\",true]"
               (encode-json-string (vector 1 "x" t)))
      "vectors encode as arrays"))

(test regression-encode-decode-round-trip
  "encoding then decoding preserves alist shape end-to-end."
  (let* ((original '((:component-id . "abc")
                    (:nested . ((:k . 1) (:v . "two")))
                    (:items . (10 20 30))))
         (round-tripped (decode-json-string
                          (encode-json-string original))))
    (is (string= "abc" (cdr (assoc :component-id round-tripped))))
    (is (= 1 (cdr (assoc :k (cdr (assoc :nested round-tripped))))))
    (is (string= "two" (cdr (assoc :v (cdr (assoc :nested round-tripped))))))
    (is (equal '(10 20 30) (cdr (assoc :items round-tripped))))))

;;; ============================================================================
;;; Routes registry — concurrent registration under *routes-lock*
;;; ============================================================================

(test regression-routes-registry-concurrent-registration
  "*routes* setfs from multiple threads land without loss when serialised
   through *routes-lock*. Models the load-time race between defroute calls
   from parallel file loads or hot-reload from a Hunchentoot worker."
  (let* ((n-threads 8)
         (per-thread 50)
         (initial (hash-table-count lol-web/server::*routes*))
         (threads
           (loop for tid from 0 below n-threads
                 collect (let ((tid tid))
                           (bordeaux-threads:make-thread
                            (lambda ()
                              (loop for i from 0 below per-thread
                                    for path = (format nil "/regression/concurrent/t~a/~a" tid i)
                                    do (bordeaux-threads:with-recursive-lock-held
                                           (lol-web/server::*routes-lock*)
                                         (setf (gethash (cons :get path)
                                                        lol-web/server::*routes*)
                                               (lambda () "ok"))))))))))
    (mapc #'bordeaux-threads:join-thread threads)
    (let ((added (- (hash-table-count lol-web/server::*routes*) initial)))
      (is (= (* n-threads per-thread) added)
          "all concurrent registrations visible — none lost"))
    ;; Clean up injected entries so the registry is unaffected for other tests.
    (loop for tid from 0 below n-threads
          do (loop for i from 0 below per-thread
                   for path = (format nil "/regression/concurrent/t~a/~a" tid i)
                   do (remhash (cons :get path) lol-web/server::*routes*)))))
