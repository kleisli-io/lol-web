;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: LOL-WEB/JSCHEMA; Base: 10 -*-
;;;; Schema-side and validation-side condition hierarchy.

(in-package :lol-web/jschema)

;;; ============================================================================
;;; SCHEMA-SIDE: signaled by PARSE
;;; ============================================================================

(define-condition invalid-schema (error)
  ((error-message
    :initarg :error-message
    :reader invalid-schema-error-message
    :initform "Invalid JSON Schema.")
   (base-uri
    :initarg :base-uri
    :reader invalid-schema-base-uri
    :initform nil)
   (json-pointer
    :initarg :json-pointer
    :reader invalid-schema-json-pointer
    :initform ""))
  (:report (lambda (c stream)
             (format stream "~@[~A : ~]~A"
                     (let ((p (invalid-schema-json-pointer c)))
                       (when (and p (plusp (length p)))
                         p))
                     (invalid-schema-error-message c))))
  (:documentation
   "Signaled by PARSE when input is not a valid JSON Schema document."))

(define-condition unparsable-json (invalid-schema)
  ((unparsable-json-error
    :initarg :unparsable-json-error
    :reader unparsable-json-error
    :initform nil))
  (:documentation
   "Signaled when PARSE's input string cannot be decoded by the underlying
    JSON parser. The wrapped condition is exposed via UNPARSABLE-JSON-ERROR."))

(define-condition not-implemented (invalid-schema)
  ()
  (:documentation
   "Signaled when a schema uses a JSON Schema feature this validator does
    not implement. The error message names the missing feature."))

;;; ============================================================================
;;; VALIDATION-SIDE: signaled by VALIDATE
;;; ============================================================================

(define-condition invalid-json (error)
  ((errors
    :initarg :errors
    :reader invalid-json-errors
    :initform nil))
  (:report (lambda (c stream)
             (format stream "JSON value invalid against schema (~D error~:P)."
                     (length (invalid-json-errors c)))))
  (:documentation
   "Signaled by VALIDATE when the value fails validation. The full error list
    (one INVALID-JSON-VALUE per failure) is available via INVALID-JSON-ERRORS."))

(define-condition invalid-json-value (error)
  ((error-message
    :initarg :error-message
    :reader invalid-json-value-error-message
    :initform "")
   (json-pointer
    :initarg :json-pointer
    :reader invalid-json-value-json-pointer
    :initform ""))
  (:report (lambda (c stream)
             (format stream "~@[~A : ~]~A"
                     (let ((p (invalid-json-value-json-pointer c)))
                       (when (and p (plusp (length p))) p))
                     (invalid-json-value-error-message c))))
  (:documentation
   "One validation failure inside an INVALID-JSON. The pointer is RFC 6901
    relative to the validated value's root."))

;;; ============================================================================
;;; INTERNAL HELPERS — used by parse/validate to raise typed conditions
;;; ============================================================================

(defvar *parse-base-uri* nil
  "Bound during PARSE to the document's resolved $id (or NIL).")

(defvar *parse-json-pointer* ""
  "Bound during PARSE to the JSON Pointer of the schema location currently
   being parsed. Carried into INVALID-SCHEMA conditions for diagnostic clarity.")

(defun raise-invalid-schema (format-control &rest format-arguments)
  "Signal INVALID-SCHEMA with the current parse-position context attached."
  (error 'invalid-schema
         :error-message (apply #'format nil format-control format-arguments)
         :base-uri *parse-base-uri*
         :json-pointer *parse-json-pointer*))

(defun raise-not-implemented (format-control &rest format-arguments)
  "Signal NOT-IMPLEMENTED — a sub-condition of INVALID-SCHEMA — with the same
   parse-position context."
  (error 'not-implemented
         :error-message (apply #'format nil format-control format-arguments)
         :base-uri *parse-base-uri*
         :json-pointer *parse-json-pointer*))
