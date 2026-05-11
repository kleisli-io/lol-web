;;;; LOL-REACTIVE Routes
;;;; Enhanced route handling with integrated security and error handling
;;;;
;;;; Provides:
;;;; - defroute: Define routes with automatic security headers and error handling

(in-package :lol-web/server)

;;; ============================================================================
;;; ROUTE DEFINITION MACROS (Clack-compatible)
;;; ============================================================================

;; Note: *routes* is defined in app.lisp

(defmacro! defroute (o!path (&key (method :get)
                                  (content-type "text/html")
                                  (secure t))
                     &body body)
  "Define a route with automatic error handling and security.

   Options:
   - METHOD: HTTP method (:get, :post, :put, :delete)
   - CONTENT-TYPE: Response content type (default \"text/html\")
   - SECURE: Add security headers (default t)

   The body should return a string (response body) or a full response list.
   If a string is returned, it will be wrapped with appropriate headers.

   PATH and METHOD are each evaluated exactly once at registration time,
   even though both appear at multiple sites in the expansion (route key,
   return values).

   Example:
     (defroute \"/\" (:method :get)
       \"<h1>Welcome</h1>\")

     (defroute \"/api/data\" (:method :post :content-type \"application/json\" :secure t)
       (encode-json-string (get-data)))"
  (let ((handler-name (gensym "ROUTE-HANDLER-")))
    `(let ((,g!method ,method))
       (defun ,handler-name ()
         ;; Security headers are added by dispatch-request (once, in
         ;; with-response-headers scope).  Errors propagate to
         ;; dispatch-request's with-error-handling for proper logging,
         ;; 500 status, and styled error pages.
         (let ((result ,(if secure
                            `(with-security ,@body)
                            `(progn ,@body))))
           ;; If result is a string, wrap in response
           (if (stringp result)
               (response 200 :content-type ,content-type :body result)
               result)))
       (bordeaux-threads:with-recursive-lock-held (*routes-lock*)
         (setf (gethash (cons ,g!method ,g!path) *routes*) #',handler-name))
       (values ,g!path ,g!method))))
