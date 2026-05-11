;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: LOL-WEB/SERVER; Base: 10 -*-
;;;; Lack application builder and Clack integration
;;;;
;;;; Provides a composable application builder using Lack middleware,
;;;; abstracting away direct Hunchentoot usage.

(in-package :lol-web/server)

;;; ============================================================================
;;; ROUTE REGISTRY
;;; ============================================================================

(defvar *routes* (make-hash-table :test 'equal)
  "Route registry mapping (method . path) to handler functions.
   Methods are keywords (:GET, :POST, etc.), paths are strings.
   Handlers in *routes* take zero arguments and read state from *env*.")

(defvar *streaming-routes* (make-hash-table :test 'equal)
  "Streaming-route registry mapping (method . path) to handler functions.
   Streaming handlers take the full Clack env as a single argument and own
   the connection lifecycle (WebSocket upgrade, SSE event loop, etc.).
   Populated by defstreaming-route, defws, defsse — never by defroute.

   Keeping these two registries disjoint replaces the prior sb-introspect
   heuristic (which was non-portable and silently misclassified handlers
   on non-SBCL implementations).")

(defvar *routes-lock* (bordeaux-threads:make-recursive-lock "lol-web/server routes")
  "Guards *routes* and *streaming-routes*. Plain hash-tables race under
   concurrent registration (multi-file load, hot-reload from a worker, parallel
   defroute calls). Recursive so find-matching-route's HEAD-as-GET fallback can
   chain a second %lookup-route without releasing.")

(defmacro! defstreaming-route (o!path (&key (method :get)) (env-var) &body body)
  "Register a streaming route: handler runs with ENV-VAR bound to the Clack
   env plist and is responsible for the response (WebSocket upgrade, SSE
   stream, long-poll, etc.). Unlike defroute, no with-response-headers /
   with-error-handling wrapper — streaming handlers manage their own headers
   and lifecycle.

   PATH and METHOD are each evaluated exactly once at registration time."
  (let ((handler-name (gensym "STREAMING-HANDLER-")))
    `(let ((,g!method ,method))
       (defun ,handler-name (,env-var) ,@body)
       (bordeaux-threads:with-recursive-lock-held (*routes-lock*)
         (setf (gethash (cons ,g!method ,g!path) *streaming-routes*) #',handler-name))
       (values ,g!path ,g!method))))

(defun clear-routes ()
  "Clear all registered routes (regular + streaming)."
  (bordeaux-threads:with-recursive-lock-held (*routes-lock*)
    (clrhash *routes*)
    (clrhash *streaming-routes*)))

(defun list-routes ()
  "List all registered routes (regular + streaming) as list of (method path) pairs."
  (bordeaux-threads:with-recursive-lock-held (*routes-lock*)
    (append
      (loop for key being the hash-keys of *routes*
            collect (list (car key) (cdr key)))
      (loop for key being the hash-keys of *streaming-routes*
            collect (list (car key) (cdr key))))))

;;; ============================================================================
;;; PATH PARAMETER SUPPORT
;;; ============================================================================

(defvar *path-params* nil
  "Alist of path parameters extracted from route matching.
   Bound during request handling for routes with :param segments.")

(defun path-param (name)
  "Get a path parameter value by name (string).
   Returns nil if parameter not found."
  (cdr (assoc name *path-params* :test #'string=)))

(defun path-pattern-p (path)
  "Check if path contains parameter segments (e.g., :slug)."
  (and (stringp path)
       (find #\: path)))

(defun match-path-pattern (pattern request-path)
  "Match a path pattern against a request path.
   Pattern segments starting with : are parameters.
   Returns alist of (name . value) if match, nil otherwise.
   Example: (match-path-pattern \"/users/:id\" \"/users/123\") => ((\"id\" . \"123\"))"
  (let ((pattern-segments (remove "" (uiop:split-string pattern :separator "/") :test #'string=))
        (path-segments (remove "" (uiop:split-string request-path :separator "/") :test #'string=)))
    (when (= (length pattern-segments) (length path-segments))
      (loop with params = nil
            for pat in pattern-segments
            for seg in path-segments
            do (cond
                 ;; Parameter segment
                 ((and (> (length pat) 0) (char= (char pat 0) #\:))
                  (push (cons (subseq pat 1) seg) params))
                 ;; Literal segment must match
                 ((string= pat seg) nil)
                 ;; No match
                 (t (return nil)))
            finally (return (nreverse params))))))

(defun %lookup-route (table method request-path)
  "Lookup METHOD/REQUEST-PATH in TABLE. Returns (handler . path-params) or NIL.
   All reads happen under *routes-lock* so concurrent registration cannot
   corrupt iteration state mid-request."
  (bordeaux-threads:with-recursive-lock-held (*routes-lock*)
    (let ((exact (gethash (cons method request-path) table)))
      (when exact
        (return-from %lookup-route (cons exact nil))))
    (loop for key being the hash-keys of table using (hash-value handler)
          for (route-method . route-path) = key
          when (and (eq route-method method)
                    (path-pattern-p route-path))
          do (let ((params (match-path-pattern route-path request-path)))
               (when params
                 (return (cons handler params)))))))

(defun find-route-for-method (method request-path)
  "Lookup a regular handler registered for METHOD on REQUEST-PATH.
   Returns (handler . path-params) or NIL."
  (%lookup-route *routes* method request-path))

(defun find-streaming-route-for-method (method request-path)
  "Lookup a streaming handler registered for METHOD on REQUEST-PATH.
   Returns (handler . path-params) or NIL."
  (%lookup-route *streaming-routes* method request-path))

(defun find-matching-route (method request-path)
  "Find a regular route handler that matches the request.
   First tries exact match, then pattern matching.
   HEAD requests fall back to GET handlers per RFC 7231 §4.3.2 — body is
   stripped by `route-handler' so headers stay identical to GET.
   Returns (handler . path-params) or nil."
  (or (find-route-for-method method request-path)
      (when (eq method :head)
        (find-route-for-method :get request-path))))

(defun find-matching-streaming-route (method request-path)
  "Find a streaming route handler that matches the request.
   Streaming routes do not respect HEAD-as-GET — a HEAD against a
   WebSocket endpoint should 405, not run the upgrade handler."
  (find-streaming-route-for-method method request-path))

;;; ============================================================================
;;; ROUTE DISPATCHER
;;; ============================================================================

(defvar *before-handler-hook* nil
  "Optional zero-arg function called within `with-response-headers' scope
   before each regular route handler runs.  Use `add-response-header' inside
   the hook to inject app-wide response headers (e.g. discovery affordances).
   Skipped on the streaming-handler path (WebSocket/SSE).")

(defvar *before-server-start-hook* nil
  "List of zero-arg functions run by START-SERVER before the Hunchentoot
   acceptor binds its port. Use to validate ambient state (registries,
   resolvable extractors, etc.) before requests can hit.

   Registration: (pushnew #'fn lol-web/server:*before-server-start-hook*)
   Execution:    (mapc #'funcall lol-web/server:*before-server-start-hook*)

   Ordering between registrants is unspecified — each fn must be
   order-independent and safely re-runnable. If a fn signals a condition,
   START-SERVER propagates it; the server does NOT come up.

   Distinct from *BEFORE-HANDLER-HOOK* (per-request) — different lifetimes,
   different intents. :LOL-WEB/EXTRACTORS pushes a sentinel onto this hook
   at file load time so DEFHANDLER references to unregistered KIND values
   are caught at startup rather than first-request.")

(defun strip-body-for-head (response)
  "Return RESPONSE with body removed if present.  Used to satisfy RFC 7231
   §4.3.2 for HEAD requests routed to GET handlers — same status, same
   headers, no body."
  (cond
    ;; Standard (status headers body) Clack response.
    ((and (consp response) (>= (length response) 2))
     (list (first response) (second response) nil))
    ;; Delayed/function response — leave alone; the underlying handler is
    ;; responsible for not streaming on HEAD.
    (t response)))

(defun route-handler (env)
  "Main route dispatcher for Clack.
   Streaming routes (WebSocket/SSE) are looked up first in *streaming-routes*
   and called with ENV directly — they own their connection lifecycle.
   Regular routes are looked up in *routes* and called with no arguments;
   the handler reads request state via the *env* dynamic binding.
   Path parameters (/users/:id) are bound via *path-params* in both cases."
  (let* ((*env* env)
         (path (request-path))
         (method (request-method))
         (streaming-match (find-matching-streaming-route method path))
         (response
           (cond
             (streaming-match
              (let ((*path-params* (cdr streaming-match))
                    (handler (car streaming-match)))
                (funcall handler env)))
             (t
              (let ((match (find-matching-route method path)))
                (if match
                    (let ((*path-params* (cdr match))
                          (handler (car match)))
                      (with-response-headers ()
                        (when *before-handler-hook*
                          (funcall *before-handler-hook*))
                        (with-error-handling (format nil "~A ~A" method path)
                          (funcall handler))))
                    (error-response 404 :message "Not Found")))))))
    (if (eq method :head)
        (strip-body-for-head response)
        response)))

;;; ============================================================================
;;; APPLICATION BUILDER
;;; ============================================================================

(defun make-app (&key (static-path "/static/")
                      (static-root #P"static/")
                      (use-session t)
                      (use-csrf t)
                      (use-accesslog t)
                      (use-static t)
                      (use-cors nil))
  "Create a Lack application with configurable middleware stack.

   Middleware (applied bottom-up):
   - Session: Memory-backed session management (optional)
   - CSRF: Cross-site request forgery protection (optional, requires session)
   - Accesslog: Request logging (optional)
   - Static: Static file serving (optional)
   - CORS: Access-Control-Allow-Origin + OPTIONS preflight (optional;
     short-circuits OPTIONS to 204 inside the middleware)

   Returns a function suitable for Clack:clackup."
  ;; Build middleware wrapper functions dynamically
  ;; Each middleware fn takes an app and returns wrapped app
  (let ((middleware-fns '()))
    ;; CORS (outermost — must see OPTIONS before any inner dispatch and
    ;; must wrap responses last so its headers ride out on every reply)
    (when use-cors
      (push (lack/util:find-middleware :cors) middleware-fns))
    ;; Static file serving (checked before app-level routing)
    (when use-static
      (let ((static-mw (lack/util:find-middleware :static)))
        (push (lambda (app)
                (funcall static-mw app :path static-path :root static-root))
              middleware-fns)))
    ;; Access logging
    (when use-accesslog
      (push (lack/util:find-middleware :accesslog) middleware-fns))
    ;; CSRF protection (requires session)
    ;; Configure to use "csrf-token" (matching security.lisp) instead of Lack's default "_csrf_token"
    (when use-csrf
      (let ((csrf-mw (lack/util:find-middleware :csrf)))
        (push (lambda (app)
                (funcall csrf-mw app
                         :session-key "csrf-token"
                         :form-token "csrf-token"))
              middleware-fns)))
    ;; Session management (innermost middleware)
    (when use-session
      (push (lack/util:find-middleware :session) middleware-fns))
    ;; Compose middlewares: reduce from right wraps innermost first
    (reduce #'funcall
            (remove-if #'null middleware-fns)
            :initial-value (lack/component:to-app 'route-handler)
            :from-end t)))

;;; ============================================================================
;;; SERVER LIFECYCLE
;;; ============================================================================
;;; Note: defroute is defined in routes.lisp with enhanced security, error
;;; handling, and content-type support. The :lol-web/extractors sub-system
;;; layers defhandler on top of defroute.

(defvar *server* nil
  "Current Hunchentoot acceptor.")

(defvar *lack-app* nil
  "Current Lack application function.")

(defvar *client-socket* nil
  "Current client socket for streaming responses.")

;;; ----------------------------------------------------------------------------
;;; Clack-compatible client for streaming/WebSocket support
;;; ----------------------------------------------------------------------------

(defclass streaming-client ()
  ((stream :initarg :stream :reader client-stream)
   (socket :initarg :socket :reader client-socket)
   (read-callback :initform nil :accessor client-read-callback)
   (write-lock :initform (bordeaux-threads:make-lock "client-write")
               :reader client-write-lock)
   (write-buffer :initform (make-array 4096 :element-type '(unsigned-byte 8)
                                            :adjustable t :fill-pointer 0)
                 :accessor client-write-buffer))
  (:documentation "Client wrapper for streaming responses and WebSocket."))

(defmethod clack.socket:read-callback ((client streaming-client))
  (client-read-callback client))

(defmethod (setf clack.socket:read-callback) (callback (client streaming-client))
  (setf (client-read-callback client) callback))

(defmethod clack.socket:write-sequence-to-socket ((client streaming-client) data &key callback)
  (bordeaux-threads:with-lock-held ((client-write-lock client))
    (let ((stream (client-stream client)))
      (write-sequence data stream)
      (force-output stream)))
  (when callback
    (funcall callback)))

(defmethod clack.socket:write-sequence-to-socket-buffer ((client streaming-client) data)
  "Buffer data for later flushing (used by WebSocket handshake)."
  (bordeaux-threads:with-lock-held ((client-write-lock client))
    (let ((buffer (client-write-buffer client)))
      (loop for byte across data
            do (vector-push-extend byte buffer)))))

(defmethod clack.socket:write-byte-to-socket-buffer ((client streaming-client) byte)
  "Buffer a single byte for later flushing."
  (bordeaux-threads:with-lock-held ((client-write-lock client))
    (vector-push-extend byte (client-write-buffer client))))

(defmethod clack.socket:close-socket ((client streaming-client))
  (bordeaux-threads:with-lock-held ((client-write-lock client))
    (finish-output (client-stream client))))

(defmethod clack.socket:flush-socket-buffer ((client streaming-client) &key callback)
  "Flush buffered data to the socket stream."
  (bordeaux-threads:with-lock-held ((client-write-lock client))
    (let ((buffer (client-write-buffer client))
          (stream (client-stream client)))
      (when (> (length buffer) 0)
        (write-sequence buffer stream)
        (setf (fill-pointer buffer) 0))
      (force-output stream)))
  (when callback
    (funcall callback)))

(defmethod clack.socket:socket-async-p ((client streaming-client))
  nil)

(defmethod clack.socket:socket-stream ((client streaming-client))
  (client-stream client))

;;; ----------------------------------------------------------------------------
;;; Lack Acceptor with streaming support
;;; ----------------------------------------------------------------------------

(defclass lack-acceptor (hunchentoot:easy-acceptor)
  ((app :initarg :app :accessor lack-app)
   (debug :initarg :debug :initform nil :accessor acceptor-debug))
  (:documentation "Hunchentoot acceptor that dispatches to a Lack app with streaming support."))

(defmethod hunchentoot:acceptor-log-message ((acceptor lack-acceptor) log-level format-string &rest format-arguments)
  "Filter out noisy connection errors from health check clients."
  (let ((message (apply #'format nil format-string format-arguments)))
    ;; Suppress connection-aborted and connection-reset errors (common with health checks)
    (unless (or (search "CONNECTION-ABORTED" message)
                (search "Connection reset by peer" message))
      (call-next-method))))

(defmethod hunchentoot:process-connection :around ((acceptor lack-acceptor) socket)
  "Capture client socket for streaming responses.
   Silently handles connection-aborted errors (common with health check clients)."
  (let ((*client-socket* socket))
    (handler-case (call-next-method)
      (usocket:connection-aborted-error ()
        ;; Client disconnected early - common with health checks, not an error
        nil))))

(defmethod hunchentoot:acceptor-dispatch-request ((acceptor lack-acceptor) request)
  "Dispatch request through Lack app with streaming/delayed response support."
  (let ((app (lack-app acceptor)))
    (if app
        (let* ((env (build-clack-env request))
               (response (if (acceptor-debug acceptor)
                             (funcall app env)
                             (handler-case (funcall app env)
                               (error (e)
                                 ;; Last-resort handler for errors escaping
                                 ;; middleware.  Route errors are caught by
                                 ;; with-error-handling in route-handler;
                                 ;; this only fires for middleware failures.
                                 (log-error (format nil "~A ~A (middleware)"
                                                    (getf env :request-method)
                                                    (getf env :path-info))
                                            e)
                                 (list 500
                                       '(:content-type "text/html; charset=utf-8")
                                       (list (handler-case
                                                 (render-error-page e :context "middleware")
                                               (error ()
                                                 "Internal Server Error")))))))))
          (handle-lack-response response))
        (call-next-method))))

(defun handle-lack-response (response)
  "Handle Lack response - either normal (status headers body) or delayed (function)."
  (etypecase response
    (list (handle-normal-response response))
    (function (funcall response #'handle-normal-response))))

(defun handle-normal-response (response)
  "Handle a normal (status headers body) response."
  (destructuring-bind (status headers &optional body) response
    (setf (hunchentoot:return-code*) status)
    ;; Emit headers.  A header key may appear more than once in the plist
    ;; — e.g. a global before-handler hook adds `Link: </llms.txt>; rel=
    ;; \"llms-txt\"` and a per-route handler adds another `Link` entry for
    ;; an alternate representation.  Per RFC 7230 §3.2.2 / RFC 8288 these
    ;; must be preserved as separate header lines (or comma-joined), not
    ;; collapsed.  `(setf hunchentoot:header-out)` has replace semantics,
    ;; so we use it only for the first occurrence and append subsequent
    ;; occurrences via the same `rplacd` pattern as `:set-cookie`.
    (let ((seen (make-hash-table :test 'eq)))
      (loop for (key val) on headers by #'cddr
            if (eq key :content-type)
              do (setf (hunchentoot:content-type*) val)
            else if (eq key :content-length)
              do (setf (hunchentoot:content-length*) val)
            else if (or (eq key :set-cookie) (gethash key seen))
              do (rplacd (last (hunchentoot:headers-out*))
                         (list (cons key val)))
            else
              do (setf (hunchentoot:header-out key) val)
                 (setf (gethash key seen) t)))
    ;; Handle body
    (unless body
      ;; No body provided - return streaming writer for delayed response
      (return-from handle-normal-response
        (let ((out (hunchentoot:send-headers)))
          (lambda (data &key (start 0) (end (length data)) close)
            (handler-case
                (etypecase data
                  (null nil)
                  (string
                   (write-sequence
                    (flexi-streams:string-to-octets
                     data :start start :end end
                     :external-format hunchentoot:*hunchentoot-default-external-format*)
                    out))
                  ((vector (unsigned-byte 8))
                   (write-sequence data out :start start :end end)))
              (error (e)
                (format *error-output* "~&Error writing to socket: ~A~%" e)))
            (if close
                (finish-output out)
                (force-output out))))))
    ;; Normal body handling
    (handler-case
        (etypecase body
          (null nil)
          (pathname
           (hunchentoot:handle-static-file body (getf headers :content-type)))
          (list
           (let ((out (hunchentoot:send-headers)))
             (dolist (chunk body)
               (write-sequence
                (flexi-streams:string-to-octets
                 chunk :external-format hunchentoot:*hunchentoot-default-external-format*)
                out))
             (finish-output out)))
          ((vector (unsigned-byte 8))
           (let ((out (hunchentoot:send-headers)))
             (write-sequence body out)
             (finish-output out))))
      (error (e)
        (format *error-output* "~&Error writing response: ~A~%" e)))))

(defun %form-body-content-type-p (content-type)
  "True when CONTENT-TYPE names a body shape that hunchentoot:post-parameters
   knows how to parse — application/x-www-form-urlencoded for plain forms or
   multipart/form-data for file uploads. Browsers select the latter when any
   field has type=file (see forms/form-dsl.lisp render-form), so omitting it
   here causes :body-parameters to be NIL on every file-upload POST and
   (post-param ...) returns NIL even though the bytes arrived intact."
  (and content-type
       (or (search "application/x-www-form-urlencoded" content-type :test #'char-equal)
           (search "multipart/form-data" content-type :test #'char-equal))))

(defun %read-raw-body-bytes (request)
  "Read the raw POST body of REQUEST into a fresh octet vector exactly once.
   Returns NIL if there is no body. Hunchentoot caches the bytes internally
   when called with :force-binary t, so callers of get/post-parameters can
   still see their parsed form."
  (handler-case
      (let ((bytes (hunchentoot:raw-post-data :request request :force-binary t)))
        (when (and bytes (plusp (length bytes)))
          bytes))
    (error () nil)))

(defun %make-cached-body-stream (bytes)
  "Wrap BYTES in a fresh flexi-stream-style readable stream. Each call to
   build-clack-env produces a new stream, so consumers reading :raw-body
   independently of the parsed parameters see the bytes from offset 0."
  (when bytes
    (flexi-streams:make-in-memory-input-stream bytes)))

(defun build-clack-env (request)
  "Build Clack environment plist from Hunchentoot request.
   Includes :clack.streaming and :clack.io for WebSocket/SSE support.

   Populates :query-parameters and :body-parameters so that the clack.lisp
   accessors (query-param, post-param, param) actually return values. The
   raw body bytes are read once and exposed via both :raw-body (a fresh
   stream over the cached bytes) and :lol/cached-body (the bytes themselves,
   for memoized request-body access)."
  (let* ((headers-ht (make-hash-table :test 'equal))
         (content-type (hunchentoot:header-in :content-type request))
         (raw-bytes (%read-raw-body-bytes request))
         ;; Hunchentoot's get-parameters parses the URI's query string
         ;; without reading the body. post-parameters parses both
         ;; application/x-www-form-urlencoded and multipart/form-data
         ;; bodies, which is exactly what we want exposed as
         ;; :body-parameters.
         (query-params (hunchentoot:get-parameters request))
         (body-params (when (%form-body-content-type-p content-type)
                        (hunchentoot:post-parameters request))))
    (dolist (header (hunchentoot:headers-in request))
      (setf (gethash (string-downcase (string (car header))) headers-ht)
            (cdr header)))
    (list :request-method (hunchentoot:request-method request)
          :script-name ""
          :path-info (hunchentoot:script-name request)
          :query-string (or (hunchentoot:query-string request) "")
          :server-name (hunchentoot:host request)
          :server-port (hunchentoot:acceptor-port (hunchentoot:request-acceptor request))
          :server-protocol (hunchentoot:server-protocol request)
          :request-uri (hunchentoot:request-uri request)
          :url-scheme (if (hunchentoot:ssl-p) "https" "http")
          :remote-addr (hunchentoot:remote-addr request)
          :remote-port (hunchentoot:remote-port request)
          :content-type content-type
          :content-length (alexandria:when-let (cl (hunchentoot:header-in :content-length request))
                            (parse-integer cl :junk-allowed t))
          :headers headers-ht
          :query-parameters query-params
          :body-parameters body-params
          ;; Memoized body bytes — handlers that need the raw payload
          ;; (e.g. JSON, multipart inspection) read this directly. Stays
          ;; usable across multiple reads since it is just a vector.
          :lol/cached-body raw-bytes
          ;; A fresh in-memory stream for legacy callers that read
          ;; :raw-body. Consumers can call request-body multiple times
          ;; because each call rebuilds the stream from the cached bytes.
          :raw-body (%make-cached-body-stream raw-bytes)
          ;; Streaming support for WebSocket/SSE
          ;; Use Hunchentoot's content-stream for bidirectional communication
          ;; (same as Clack's hunchentoot handler does)
          :clack.streaming t
          :clack.io (when *client-socket*
                      (make-instance 'streaming-client
                                     :socket *client-socket*
                                     :stream (hunchentoot::content-stream request))))))

(defun start-server (&key (port 8080) debug
                          (static-path "/static/") (static-root #P"static/")
                          (use-session t) (use-csrf t) (use-accesslog t) (use-static t)
                          (use-cors nil))
  "Start the web server.

   PORT: Listen port (default 8080)
   DEBUG: Enable debug mode for verbose errors
   STATIC-PATH: URL path for static files (default /static/)
   STATIC-ROOT: Filesystem path for static files
   USE-SESSION: Enable session middleware (default t)
   USE-CSRF: Enable CSRF protection (default t)
   USE-ACCESSLOG: Enable access logging (default t)
   USE-STATIC: Enable static file serving (default t)
   USE-CORS: Enable CORS + OPTIONS preflight middleware (default nil)

   Returns server handle for stop-server, or NIL if port is already in use."
  (when *server*
    (error "Server already running. Call stop-server first."))
  ;; Run pre-server-start validators before allocating any state. A failing
  ;; hook signals out of START-SERVER without binding a port or mutating
  ;; *server* / *lack-app* — so the next call can retry once the user fixes
  ;; the underlying issue (typically a defhandler referencing an unregistered
  ;; extractor kind).
  (mapc #'funcall *before-server-start-hook*)
  (when debug
    (enable-debug-mode))
  (setf *lack-app* (make-app :static-path static-path
                             :static-root static-root
                             :use-session use-session
                             :use-csrf use-csrf
                             :use-accesslog use-accesslog
                             :use-static use-static
                             :use-cors use-cors))
  (setf *server* (make-instance 'lack-acceptor :port port :app *lack-app*))
  (handler-case
      (progn
        (hunchentoot:start *server*)
        (format t "~&Server started on port ~A~%" port)
        *server*)
    (usocket:address-in-use-error (c)
      (format *error-output* "~&[lol-reactive] Port ~A already in use: ~A~%" port c)
      (setf *server* nil)
      (setf *lack-app* nil)
      nil)))

(defun stop-server (&optional (server *server*))
  "Stop the web server.

   SERVER: Server handle from start-server (default *server*)"
  (when server
    (hunchentoot:stop server)
    (setf *server* nil)
    (setf *lack-app* nil)
    (format t "~&Server stopped~%")
    t))
