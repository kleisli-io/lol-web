;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: LOL-WEB/JSCHEMA; Base: 10 -*-
;;;; VALIDATE — apply a parsed JSON-SCHEMA to a jzon-shaped value.
;;;;
;;;; Validation is a single recursive walk over the schema's keyword alist.
;;;; Each keyword's checker pushes INVALID-JSON-VALUE conditions onto the
;;;; current evaluation context's error list and may extend the
;;;; evaluated-properties / evaluated-items annotation sets that
;;;; unevaluatedProperties / unevaluatedItems consult.

(in-package :lol-web/jschema)

;;; ============================================================================
;;; EVALUATION CONTEXT
;;; ============================================================================

(defvar *if-branch-cache* nil
  "Bound per-validate to a hash-table mapping each `if` parsed-schema instance
   to T (matched) / NIL (did not match). Consulted by then/else checkers.")

(defstruct eval-ctx
  "Per-validation-call mutable state. ROOT is the top-level JSON-SCHEMA.
   ERRORS accumulates INVALID-JSON-VALUE instances. POINTER is the current
   value-side JSON Pointer. EVALUATED-PROPS / EVALUATED-ITEMS are filled by
   applicators so unevaluated* keywords know what's already covered.
   IGNORE-UNRESOLVABLE-REFS mirrors cl-jschema's option of the same name."
  root
  (errors nil)
  (pointer "")
  (evaluated-props (make-hash-table :test 'equal))
  (evaluated-items '())
  (ignore-unresolvable-refs nil)
  (dynamic-scope nil))         ; stack of root self-registries for $dynamicRef

(defmacro with-pointer ((ctx suffix) &body body)
  "Run BODY with CTX's pointer extended by SUFFIX (already including its
   leading slash). Restores the prior pointer on exit."
  (alexandria:with-gensyms (g-saved g-ctx g-suffix)
    `(let* ((,g-ctx ,ctx)
            (,g-suffix ,suffix)
            (,g-saved (eval-ctx-pointer ,g-ctx)))
       (unwind-protect
            (progn
              (setf (eval-ctx-pointer ,g-ctx)
                    (concatenate 'string ,g-saved ,g-suffix))
              ,@body)
         (setf (eval-ctx-pointer ,g-ctx) ,g-saved)))))

(defun push-error (ctx message)
  "Record an INVALID-JSON-VALUE on the eval context."
  (push (make-condition 'invalid-json-value
                        :error-message message
                        :json-pointer (eval-ctx-pointer ctx))
        (eval-ctx-errors ctx)))

;;; ============================================================================
;;; ENTRYPOINT
;;; ============================================================================

(defgeneric validate (schema value &key &allow-other-keys)
  (:documentation
   "Validate VALUE against SCHEMA. Returns T on success or signals INVALID-JSON
    with all collected errors on failure. VALUE must be in jzon shape (hash-
    tables for objects, vectors for arrays)."))

(defmethod validate ((schema json-schema) value &key ignore-unresolvable-refs)
  (let ((ctx (make-eval-ctx
              :root schema
              :ignore-unresolvable-refs ignore-unresolvable-refs
              :dynamic-scope (when (json-schema-self-registry schema)
                               (list (json-schema-self-registry schema)))))
        ;; The if/then/else dispatcher stashes per-`if` branch results here;
        ;; bound per-validate so cross-call state never leaks.
        (*if-branch-cache* (make-hash-table :test 'eq)))
    (%check-schema schema value ctx)
    (when (eval-ctx-errors ctx)
      (error 'invalid-json :errors (nreverse (eval-ctx-errors ctx))))
    t))

;;; ============================================================================
;;; CORE: %CHECK-SCHEMA
;;; ============================================================================

(defun %check-schema (schema value ctx)
  "Apply SCHEMA to VALUE, mutating CTX. Boolean schemas short-circuit:
   true → no-op; false → one error."
  (case (json-schema-bool schema)
    (:true (return-from %check-schema (values)))
    (:false
     (push-error ctx "Schema is `false` — value cannot validate.")
     (return-from %check-schema (values))))
  ;; Object schema — walk the keyword alist in order.
  (dolist (entry (json-schema-keywords schema))
    (let ((checker (gethash (car entry) *keyword-checkers*)))
      (when checker
        (funcall checker (cdr entry) value ctx schema))))
  (values))
