;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: LOL-WEB/SERVER; Base: 10 -*-
;;;; HTTP-error condition hierarchy
;;;;
;;;; A small condition tree handlers can SIGNAL/ERROR to short-circuit a
;;;; request with a specific HTTP status. with-error-handling translates
;;;; them into responses; everything else still falls through to the
;;;; catch-all 500 path.
;;;;
;;;; Usage:
;;;;   (error 'http-not-found)                                ; → 404 with default body
;;;;   (error 'http-bad-request :body "missing 'name' param") ; → 400 with custom body

(in-package :lol-web/server)

(define-condition http-error (error)
  ((status :reader http-error-status :initarg :status)
   (body :reader http-error-body :initarg :body :initform nil))
  (:documentation
   "Base condition for application-signalled HTTP errors. Subclasses fix the
    status code; callers may provide :body to override the default status text."))

(define-condition client-error (http-error) ()
  (:documentation "4xx family — caller-fault. with-error-handling logs at info level."))

(define-condition server-error (http-error) ()
  (:documentation "5xx family — server-fault. with-error-handling logs at error level."))

(define-condition http-bad-request          (client-error) ()
  (:default-initargs :status 400))
(define-condition http-unauthorized         (client-error) ()
  (:default-initargs :status 401))
(define-condition http-forbidden            (client-error) ()
  (:default-initargs :status 403))
(define-condition http-not-found            (client-error) ()
  (:default-initargs :status 404))
(define-condition http-unprocessable-entity (client-error) ()
  (:default-initargs :status 422))
