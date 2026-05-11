;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: CL-USER; Base: 10 -*-
;;;; :lol-web/server — clack abstraction, routes, app, security, error handling
;;;;   src/server/{clack,security,http-errors,errors,app,routes}.lisp

(in-package :cl-user)

(defpackage :lol-web/server
  (:use :cl :iterate
        :lol-web/core    ; find-component, register-component, etc.
        :lol-web/html)   ; render-component, html-page, htm-str
  (:import-from :let-over-lambda
                :defmacro!
                :symb)
  (:export
   ;; clack.lisp — request/response abstraction
   #:*env*
   #:*response-headers*
   #:request-path
   #:request-method
   #:request-query-string
   #:request-header
   #:request-content-type
   #:request-content-length
   #:request-body
   #:request-body-json
   #:query-param
   #:query-params
   #:post-param
   #:post-params
   #:param
   #:parse-request-json
   #:encode-json-string
   #:decode-json-string
   #:response
   #:html-response
   #:json-response
   #:text-response
   #:redirect-response
   #:error-response
   #:with-response-headers
   #:add-response-header
   #:get-response-headers
   #:http-status-text
   #:session-get
   #:session-set
   #:session-delete
   #:session-clear
   #:session-keys
   #:csrf-token
   ;; security.lisp
   #:add-security-headers
   #:add-csp-header
   #:with-security
   #:generate-csrf-token
   #:get-csrf-token
   #:validate-csrf-token
   #:csrf-token-input
   #:constant-time-string=
   #:with-csrf-validation
   #:check-rate-limit
   #:get-client-ip
   #:with-rate-limit
   #:*rate-limit-store*
   ;; http-errors.lisp
   #:http-error
   #:http-error-status
   #:http-error-body
   #:client-error
   #:server-error
   #:http-bad-request
   #:http-unauthorized
   #:http-forbidden
   #:http-not-found
   #:http-unprocessable-entity
   ;; errors.lisp
   #:*debug-mode*
   #:*error-log-path*
   #:with-error-handling
   #:log-error
   #:render-error-page
   #:render-404-page
   #:render-500-page
   #:enable-debug-mode
   #:disable-debug-mode
   ;; app.lisp
   #:*path-params*
   #:path-param
   #:*routes*
   #:clear-routes
   #:list-routes
   #:route-handler
   #:make-app
   #:*server*
   #:*before-handler-hook*
   #:*before-server-start-hook*
   #:start-server
   #:stop-server
   #:defstreaming-route
   ;; routes.lisp
   #:defroute))
