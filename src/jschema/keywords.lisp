;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: LOL-WEB/JSCHEMA; Base: 10 -*-
;;;; Per-keyword PARSE / CHECK functions. Each REGISTER-KEYWORD call attaches
;;;; one keyword's logic to the parser's and validator's dispatch tables.

(in-package :lol-web/jschema)

;;; ============================================================================
;;; SHARED: jzon shape predicates
;;; ============================================================================

(defun %json-null-p (v) (eq v 'null))
(defun %json-true-p (v) (eq v t))
(defun %json-false-p (v) (eq v nil))
(defun %json-bool-p (v) (or (%json-true-p v) (%json-false-p v)))
(defun %json-string-p (v) (stringp v))
(defun %json-integer-p (v) (integerp v))
(defun %json-number-p (v) (and (numberp v) (not (complexp v))))
(defun %json-array-p (v) (and (vectorp v) (not (stringp v))))
(defun %json-object-p (v) (hash-table-p v))

(defun %json-type-tag (v)
  "Return the JSON Schema type tag for a jzon-shaped value, as a string."
  (cond
    ((%json-null-p v) "null")
    ((%json-bool-p v) "boolean")
    ((%json-integer-p v) "integer")
    ((%json-number-p v) "number")
    ((%json-string-p v) "string")
    ((%json-array-p v) "array")
    ((%json-object-p v) "object")
    (t "unknown")))

(defun %json-equal (a b)
  "Structural equality used by 'const' and 'enum' (and 'uniqueItems').
   Hash-tables compare by keys + recursive value equality; vectors compare
   length-then-pointwise."
  (cond
    ((and (numberp a) (numberp b)) (= a b))
    ((and (stringp a) (stringp b)) (string= a b))
    ((and (%json-bool-p a) (%json-bool-p b)) (eq a b))
    ((and (%json-null-p a) (%json-null-p b)) t)
    ((and (vectorp a) (vectorp b))
     (and (= (length a) (length b))
          (loop for i below (length a)
                always (%json-equal (aref a i) (aref b i)))))
    ((and (hash-table-p a) (hash-table-p b))
     (and (= (hash-table-count a) (hash-table-count b))
          (loop for k being the hash-keys of a using (hash-value va)
                always (multiple-value-bind (vb present-p) (gethash k b)
                         (and present-p (%json-equal va vb))))))
    (t nil)))

;;; ============================================================================
;;; ANNOTATION-ONLY KEYWORDS — parse cleanly, don't check
;;; ============================================================================

(dolist (k '("title" "description" "default" "examples" "deprecated"
             "readOnly" "writeOnly" "format"))
  (register-keyword k :parser #'identity))

;;; ============================================================================
;;; type
;;; ============================================================================

(defparameter +valid-type-tags+
  '("null" "boolean" "integer" "number" "string" "array" "object"))

(defun %parse-type (val)
  (cond
    ((stringp val)
     (unless (find val +valid-type-tags+ :test #'string=)
       (raise-invalid-schema "Invalid type ~S" val))
     (list val))
    ((vectorp val)
     (let ((tags (coerce val 'list)))
       (unless (every #'stringp tags)
         (raise-invalid-schema "type array must contain only strings"))
       (dolist (t1 tags)
         (unless (find t1 +valid-type-tags+ :test #'string=)
           (raise-invalid-schema "Invalid type ~S" t1)))
       tags))
    (t (raise-invalid-schema "type must be a string or array of strings"))))

(defun %check-type (allowed value ctx schema)
  (declare (ignore schema))
  (let ((tag (%json-type-tag value)))
    ;; integer is a refinement of number — a number with integer value passes
    ;; type=integer; a number passes type=number.
    (unless (or (find tag allowed :test #'string=)
                (and (string= tag "integer")
                     (find "number" allowed :test #'string=))
                (and (string= tag "integer")
                     (find "integer" allowed :test #'string=))
                (and (%json-integer-p value)
                     (find "integer" allowed :test #'string=))
                (and (%json-number-p value)
                     (find "number" allowed :test #'string=)
                     (or (%json-integer-p value)
                         (floatp value)
                         (rationalp value))))
      (push-error ctx (format nil "Expected type ~A, got ~A"
                              (format nil "~{~A~^/~}" allowed) tag)))))

(register-keyword "type" :parser #'%parse-type :checker #'%check-type)

;;; ============================================================================
;;; const
;;; ============================================================================

(defun %check-const (parsed value ctx schema)
  (declare (ignore schema))
  (unless (%json-equal value parsed)
    (push-error ctx (format nil "Value does not equal const ~S" parsed))))

(register-keyword "const" :parser #'identity :checker #'%check-const)

;;; ============================================================================
;;; enum
;;; ============================================================================

(defun %parse-enum (val)
  (unless (and (vectorp val) (plusp (length val)))
    (raise-invalid-schema "enum must be a non-empty array"))
  (coerce val 'list))

(defun %check-enum (parsed value ctx schema)
  (declare (ignore schema))
  (unless (some (lambda (e) (%json-equal value e)) parsed)
    (push-error ctx (format nil "Value not in enum (~D options)"
                            (length parsed)))))

(register-keyword "enum" :parser #'%parse-enum :checker #'%check-enum)

;;; ============================================================================
;;; required
;;; ============================================================================

(defun %parse-required (val)
  (unless (vectorp val)
    (raise-invalid-schema "required must be an array"))
  (let ((names (coerce val 'list)))
    (unless (every #'stringp names)
      (raise-invalid-schema "required must contain only strings"))
    names))

(defun %check-required (names value ctx schema)
  (declare (ignore schema))
  (when (%json-object-p value)
    (dolist (name names)
      (unless (multiple-value-bind (_ present) (gethash name value)
                (declare (ignore _))
                present)
        (push-error ctx (format nil "Missing required property ~S" name))))))

(register-keyword "required" :parser #'%parse-required :checker #'%check-required)

;;; ============================================================================
;;; properties / patternProperties / additionalProperties / propertyNames /
;;; unevaluatedProperties
;;; ============================================================================

(defun %parse-properties (val)
  (unless (hash-table-p val)
    (raise-invalid-schema "properties must be a JSON object"))
  (let ((acc '()))
    (loop for k being the hash-keys of val using (hash-value v)
          do (with-pointer-extension
                 ((concatenate 'string "/" (%escape-pointer-segment k)))
               (push (cons k (%make-schema v nil)) acc)))
    (nreverse acc)))

(defun %check-properties (parsed value ctx schema)
  (declare (ignore schema))
  (when (%json-object-p value)
    (dolist (entry parsed)
      (multiple-value-bind (sub present-p) (gethash (car entry) value)
        (when present-p
          (with-pointer (ctx (concatenate 'string "/"
                                          (%escape-pointer-segment (car entry))))
            (%check-schema (cdr entry) sub ctx))
          (setf (gethash (car entry) (eval-ctx-evaluated-props ctx)) t))))))

(register-keyword "properties"
                  :parser #'%parse-properties
                  :checker #'%check-properties
                  :child-schemas
                  (lambda (parsed)
                    (mapcar (lambda (entry)
                              (cons (concatenate 'string "/properties/"
                                                 (%escape-pointer-segment
                                                  (car entry)))
                                    (cdr entry)))
                            parsed)))

(defun %parse-pattern-properties (val)
  (unless (hash-table-p val)
    (raise-invalid-schema "patternProperties must be a JSON object"))
  (let ((acc '()))
    (loop for k being the hash-keys of val using (hash-value v)
          do (let ((scanner
                     (handler-case (cl-ppcre:create-scanner k)
                       (error () (raise-invalid-schema
                                  "patternProperties key ~S is not a valid regex"
                                  k)))))
               (with-pointer-extension
                   ((concatenate 'string "/" (%escape-pointer-segment k)))
                 (push (list k scanner (%make-schema v nil)) acc))))
    (nreverse acc)))

(defun %check-pattern-properties (parsed value ctx schema)
  (declare (ignore schema))
  (when (%json-object-p value)
    (loop for k being the hash-keys of value using (hash-value v)
          do (dolist (triple parsed)
               (when (cl-ppcre:scan (second triple) k)
                 (with-pointer (ctx (concatenate 'string "/"
                                                 (%escape-pointer-segment k)))
                   (%check-schema (third triple) v ctx))
                 (setf (gethash k (eval-ctx-evaluated-props ctx)) t))))))

(register-keyword "patternProperties"
                  :parser #'%parse-pattern-properties
                  :checker #'%check-pattern-properties
                  :child-schemas
                  (lambda (parsed)
                    (mapcar (lambda (triple)
                              (cons (concatenate 'string "/patternProperties/"
                                                 (%escape-pointer-segment
                                                  (first triple)))
                                    (third triple)))
                            parsed)))

(defun %parse-additional-properties (val)
  (%make-schema val nil))

(defun %check-additional-properties (sub value ctx schema)
  (declare (ignore schema))
  (when (%json-object-p value)
    (let ((covered (eval-ctx-evaluated-props ctx)))
      (loop for k being the hash-keys of value using (hash-value v)
            do (unless (gethash k covered)
                 (with-pointer (ctx (concatenate 'string "/"
                                                 (%escape-pointer-segment k)))
                   (%check-schema sub v ctx))
                 (setf (gethash k covered) t))))))

(register-keyword "additionalProperties"
                  :parser #'%parse-additional-properties
                  :checker #'%check-additional-properties
                  :child-schemas
                  (lambda (parsed) (list (cons "/additionalProperties" parsed))))

(defun %parse-property-names (val)
  (%make-schema val nil))

(defun %check-property-names (sub value ctx schema)
  (declare (ignore schema))
  (when (%json-object-p value)
    (loop for k being the hash-keys of value
          do (with-pointer (ctx (concatenate 'string "/"
                                             (%escape-pointer-segment k)))
               (%check-schema sub k ctx)))))

(register-keyword "propertyNames"
                  :parser #'%parse-property-names
                  :checker #'%check-property-names
                  :child-schemas
                  (lambda (parsed) (list (cons "/propertyNames" parsed))))

(defun %parse-unevaluated-properties (val)
  (%make-schema val nil))

(defun %check-unevaluated-properties (sub value ctx schema)
  (declare (ignore schema))
  (when (%json-object-p value)
    (let ((covered (eval-ctx-evaluated-props ctx)))
      (loop for k being the hash-keys of value using (hash-value v)
            do (unless (gethash k covered)
                 (with-pointer (ctx (concatenate 'string "/"
                                                 (%escape-pointer-segment k)))
                   (%check-schema sub v ctx))
                 (setf (gethash k covered) t))))))

(register-keyword "unevaluatedProperties"
                  :parser #'%parse-unevaluated-properties
                  :checker #'%check-unevaluated-properties
                  :child-schemas
                  (lambda (parsed) (list (cons "/unevaluatedProperties" parsed))))

;;; ============================================================================
;;; minProperties / maxProperties
;;; ============================================================================

(defun %parse-non-negative-integer (val keyword)
  (unless (and (integerp val) (>= val 0))
    (raise-invalid-schema "~A must be a non-negative integer" keyword))
  val)

(defun %check-min-properties (n value ctx schema)
  (declare (ignore schema))
  (when (%json-object-p value)
    (when (< (hash-table-count value) n)
      (push-error ctx (format nil "Object has fewer than ~D properties" n)))))

(defun %check-max-properties (n value ctx schema)
  (declare (ignore schema))
  (when (%json-object-p value)
    (when (> (hash-table-count value) n)
      (push-error ctx (format nil "Object has more than ~D properties" n)))))

(register-keyword "minProperties"
                  :parser (lambda (v) (%parse-non-negative-integer v "minProperties"))
                  :checker #'%check-min-properties)
(register-keyword "maxProperties"
                  :parser (lambda (v) (%parse-non-negative-integer v "maxProperties"))
                  :checker #'%check-max-properties)

;;; ============================================================================
;;; items / prefixItems / contains / minItems / maxItems / uniqueItems
;;; ============================================================================

(defun %parse-items (val)
  (%make-schema val nil))

(defun %check-items (sub value ctx schema)
  (declare (ignore schema))
  (when (%json-array-p value)
    ;; prefixItems consumed some prefix — items only applies past that.
    (let ((start (or (cdr (assoc "prefixItems" (json-schema-keywords
                                                 (eval-ctx-root ctx))
                                  :test #'string=))
                     0)))
      (declare (ignore start))
      (loop for i below (length value)
            for item = (aref value i)
            do (with-pointer (ctx (format nil "/~D" i))
                 (%check-schema sub item ctx))
            do (pushnew i (eval-ctx-evaluated-items ctx))))))

(register-keyword "items"
                  :parser #'%parse-items
                  :checker #'%check-items
                  :child-schemas
                  (lambda (parsed) (list (cons "/items" parsed))))

(defun %parse-prefix-items (val)
  (unless (vectorp val)
    (raise-invalid-schema "prefixItems must be an array"))
  (let ((acc '()))
    (loop for i from 0
          for v across val
          do (with-pointer-extension ((format nil "/~D" i))
               (push (%make-schema v nil) acc)))
    (nreverse acc)))

(defun %check-prefix-items (subs value ctx schema)
  (declare (ignore schema))
  (when (%json-array-p value)
    (loop for i below (min (length subs) (length value))
          for sub in subs
          for item = (aref value i)
          do (with-pointer (ctx (format nil "/~D" i))
               (%check-schema sub item ctx))
          do (pushnew i (eval-ctx-evaluated-items ctx)))))

(register-keyword "prefixItems"
                  :parser #'%parse-prefix-items
                  :checker #'%check-prefix-items
                  :child-schemas
                  (lambda (parsed)
                    (loop for s in parsed
                          for i from 0
                          collect (cons (format nil "/prefixItems/~D" i) s))))

(defun %check-min-items (n value ctx schema)
  (declare (ignore schema))
  (when (%json-array-p value)
    (when (< (length value) n)
      (push-error ctx (format nil "Array has fewer than ~D items" n)))))

(defun %check-max-items (n value ctx schema)
  (declare (ignore schema))
  (when (%json-array-p value)
    (when (> (length value) n)
      (push-error ctx (format nil "Array has more than ~D items" n)))))

(register-keyword "minItems"
                  :parser (lambda (v) (%parse-non-negative-integer v "minItems"))
                  :checker #'%check-min-items)
(register-keyword "maxItems"
                  :parser (lambda (v) (%parse-non-negative-integer v "maxItems"))
                  :checker #'%check-max-items)

(defun %check-unique-items (val value ctx schema)
  (declare (ignore schema))
  (when (and val (%json-array-p value))
    (loop for i below (length value)
          do (loop for j from (1+ i) below (length value)
                   when (%json-equal (aref value i) (aref value j))
                     do (push-error ctx
                                    (format nil "Duplicate items at indices ~D and ~D"
                                            i j))))))

(register-keyword "uniqueItems"
                  :parser #'identity
                  :checker #'%check-unique-items)

;;; ============================================================================
;;; minLength / maxLength / pattern
;;; ============================================================================

(defun %check-min-length (n value ctx schema)
  (declare (ignore schema))
  (when (%json-string-p value)
    (when (< (length value) n)
      (push-error ctx (format nil "String shorter than ~D characters" n)))))

(defun %check-max-length (n value ctx schema)
  (declare (ignore schema))
  (when (%json-string-p value)
    (when (> (length value) n)
      (push-error ctx (format nil "String longer than ~D characters" n)))))

(register-keyword "minLength"
                  :parser (lambda (v) (%parse-non-negative-integer v "minLength"))
                  :checker #'%check-min-length)
(register-keyword "maxLength"
                  :parser (lambda (v) (%parse-non-negative-integer v "maxLength"))
                  :checker #'%check-max-length)

(defun %parse-pattern (val)
  (unless (stringp val)
    (raise-invalid-schema "pattern must be a string"))
  (handler-case (cl-ppcre:create-scanner val)
    (error () (raise-invalid-schema "pattern ~S is not a valid regex" val))))

(defun %check-pattern (scanner value ctx schema)
  (declare (ignore schema))
  (when (%json-string-p value)
    (unless (cl-ppcre:scan scanner value)
      (push-error ctx "String does not match pattern"))))

(register-keyword "pattern" :parser #'%parse-pattern :checker #'%check-pattern)

;;; ============================================================================
;;; minimum / maximum / exclusiveMinimum / exclusiveMaximum / multipleOf
;;; ============================================================================

(defun %check-minimum (n value ctx schema)
  (declare (ignore schema))
  (when (%json-number-p value)
    (when (< value n)
      (push-error ctx (format nil "Value less than minimum ~A" n)))))

(defun %check-maximum (n value ctx schema)
  (declare (ignore schema))
  (when (%json-number-p value)
    (when (> value n)
      (push-error ctx (format nil "Value greater than maximum ~A" n)))))

(defun %check-exclusive-minimum (n value ctx schema)
  (declare (ignore schema))
  (when (%json-number-p value)
    (when (<= value n)
      (push-error ctx (format nil "Value not greater than exclusive minimum ~A" n)))))

(defun %check-exclusive-maximum (n value ctx schema)
  (declare (ignore schema))
  (when (%json-number-p value)
    (when (>= value n)
      (push-error ctx (format nil "Value not less than exclusive maximum ~A" n)))))

(defun %check-multiple-of (n value ctx schema)
  (declare (ignore schema))
  (when (%json-number-p value)
    (let ((q (/ value n)))
      (unless (zerop (- q (truncate q)))
        (push-error ctx (format nil "Value is not a multiple of ~A" n))))))

(dolist (k '(("minimum" . %check-minimum)
             ("maximum" . %check-maximum)
             ("exclusiveMinimum" . %check-exclusive-minimum)
             ("exclusiveMaximum" . %check-exclusive-maximum)))
  (register-keyword (car k)
                    :parser (lambda (v)
                              (unless (%json-number-p v)
                                (raise-invalid-schema "~A must be a number" (car k)))
                              v)
                    :checker (symbol-function (cdr k))))

(register-keyword "multipleOf"
                  :parser (lambda (v)
                            (unless (and (%json-number-p v) (plusp v))
                              (raise-invalid-schema
                               "multipleOf must be a number > 0"))
                            v)
                  :checker #'%check-multiple-of)

;;; ============================================================================
;;; allOf / anyOf / oneOf / not
;;; ============================================================================

(defun %parse-schema-array (val keyword)
  (unless (vectorp val)
    (raise-invalid-schema "~A must be an array of schemas" keyword))
  (let ((acc '()))
    (loop for i from 0
          for v across val
          do (with-pointer-extension ((format nil "/~D" i))
               (push (%make-schema v nil) acc)))
    (nreverse acc)))

(defun %check-all-of (subs value ctx schema)
  (declare (ignore schema))
  (dolist (s subs)
    (%check-schema s value ctx)))

(defun %check-any-of (subs value ctx schema)
  (declare (ignore schema))
  ;; Try each branch with its own scratch error list. Pass if any succeeds;
  ;; surface a generic failure if all fail (per-branch errors are not
  ;; propagated to keep diagnostics terse).
  (let ((any-passed nil)
        (saved-evaluated (alexandria:copy-hash-table
                          (eval-ctx-evaluated-props ctx)))
        (saved-evaluated-items (copy-list (eval-ctx-evaluated-items ctx))))
    (dolist (s subs)
      (let ((scratch (make-eval-ctx :root (eval-ctx-root ctx)
                                     :pointer (eval-ctx-pointer ctx)
                                     :ignore-unresolvable-refs
                                     (eval-ctx-ignore-unresolvable-refs ctx)
                                     :dynamic-scope (eval-ctx-dynamic-scope ctx)
                                     :evaluated-props
                                     (alexandria:copy-hash-table saved-evaluated)
                                     :evaluated-items
                                     (copy-list saved-evaluated-items))))
        (%check-schema s value scratch)
        (unless (eval-ctx-errors scratch)
          (setf any-passed t)
          ;; Merge the passing branch's annotations into the parent context.
          (loop for k being the hash-keys of (eval-ctx-evaluated-props scratch)
                do (setf (gethash k (eval-ctx-evaluated-props ctx)) t))
          (setf (eval-ctx-evaluated-items ctx)
                (union (eval-ctx-evaluated-items ctx)
                       (eval-ctx-evaluated-items scratch))))))
    (unless any-passed
      (push-error ctx "Value matched no anyOf branches"))))

(defun %check-one-of (subs value ctx schema)
  (declare (ignore schema))
  (let ((passed 0)
        (passed-scratch nil)
        (saved-evaluated (alexandria:copy-hash-table
                          (eval-ctx-evaluated-props ctx)))
        (saved-evaluated-items (copy-list (eval-ctx-evaluated-items ctx))))
    (dolist (s subs)
      (let ((scratch (make-eval-ctx :root (eval-ctx-root ctx)
                                     :pointer (eval-ctx-pointer ctx)
                                     :ignore-unresolvable-refs
                                     (eval-ctx-ignore-unresolvable-refs ctx)
                                     :dynamic-scope (eval-ctx-dynamic-scope ctx)
                                     :evaluated-props
                                     (alexandria:copy-hash-table saved-evaluated)
                                     :evaluated-items
                                     (copy-list saved-evaluated-items))))
        (%check-schema s value scratch)
        (unless (eval-ctx-errors scratch)
          (incf passed)
          (setf passed-scratch scratch))))
    (cond
      ((zerop passed)
       (push-error ctx "Value matched no oneOf branches"))
      ((> passed 1)
       (push-error ctx (format nil "Value matched ~D oneOf branches; expected 1"
                               passed)))
      (t
       (loop for k being the hash-keys of
                                (eval-ctx-evaluated-props passed-scratch)
             do (setf (gethash k (eval-ctx-evaluated-props ctx)) t))
       (setf (eval-ctx-evaluated-items ctx)
             (union (eval-ctx-evaluated-items ctx)
                    (eval-ctx-evaluated-items passed-scratch)))))))

(defun %check-not (sub value ctx schema)
  (declare (ignore schema))
  (let ((scratch (make-eval-ctx :root (eval-ctx-root ctx)
                                 :pointer (eval-ctx-pointer ctx)
                                 :dynamic-scope (eval-ctx-dynamic-scope ctx))))
    (%check-schema sub value scratch)
    (unless (eval-ctx-errors scratch)
      (push-error ctx "Value matched a `not` branch"))))

(dolist (entry '(("allOf" . %check-all-of)
                 ("anyOf" . %check-any-of)
                 ("oneOf" . %check-one-of)))
  (register-keyword (car entry)
                    :parser (let ((kw (car entry)))
                              (lambda (v) (%parse-schema-array v kw)))
                    :checker (symbol-function (cdr entry))
                    :child-schemas
                    (let ((kw (car entry)))
                      (lambda (parsed)
                        (loop for s in parsed
                              for i from 0
                              collect (cons (format nil "/~A/~D" kw i) s))))))

(register-keyword "not"
                  :parser (lambda (v) (%make-schema v nil))
                  :checker #'%check-not
                  :child-schemas (lambda (p) (list (cons "/not" p))))

;;; ============================================================================
;;; if / then / else
;;; ============================================================================
;;; Stored as separate keywords in the alist; the checker for IF runs first
;;; and stashes the branch decision on the ctx via a per-validation
;;; properties map keyed by schema-pointer (we use the IF's parsed-form
;;; itself as the identity key since each schema's IF is unique per location).

(defun %check-if (sub value ctx schema)
  (declare (ignore schema))
  (let ((scratch (make-eval-ctx :root (eval-ctx-root ctx)
                                 :pointer (eval-ctx-pointer ctx)
                                 :dynamic-scope (eval-ctx-dynamic-scope ctx))))
    (%check-schema sub value scratch)
    (let ((matched (null (eval-ctx-errors scratch))))
      (setf (gethash sub *if-branch-cache*) matched)
      (when matched
        ;; If the branch passed, merge its annotations.
        (loop for k being the hash-keys of (eval-ctx-evaluated-props scratch)
              do (setf (gethash k (eval-ctx-evaluated-props ctx)) t))))))

(defun %check-then (sub value ctx schema)
  ;; Look up the sibling 'if' to decide whether to apply.
  (let ((if-form (cdr (assoc "if" (json-schema-keywords schema)
                              :test #'string=))))
    (when (and if-form *if-branch-cache* (gethash if-form *if-branch-cache*))
      (%check-schema sub value ctx))))

(defun %check-else (sub value ctx schema)
  (let ((if-form (cdr (assoc "if" (json-schema-keywords schema)
                              :test #'string=))))
    (when (and if-form *if-branch-cache*
               (not (gethash if-form *if-branch-cache*)))
      (%check-schema sub value ctx))))

(register-keyword "if"
                  :parser (lambda (v) (%make-schema v nil))
                  :checker #'%check-if
                  :child-schemas (lambda (p) (list (cons "/if" p))))
(register-keyword "then"
                  :parser (lambda (v) (%make-schema v nil))
                  :checker #'%check-then
                  :child-schemas (lambda (p) (list (cons "/then" p))))
(register-keyword "else"
                  :parser (lambda (v) (%make-schema v nil))
                  :checker #'%check-else
                  :child-schemas (lambda (p) (list (cons "/else" p))))

;;; ============================================================================
;;; dependentSchemas / dependentRequired
;;; ============================================================================

(defun %parse-dependent-schemas (val)
  (unless (hash-table-p val)
    (raise-invalid-schema "dependentSchemas must be a JSON object"))
  (let ((acc '()))
    (loop for k being the hash-keys of val using (hash-value v)
          do (with-pointer-extension
                 ((concatenate 'string "/" (%escape-pointer-segment k)))
               (push (cons k (%make-schema v nil)) acc)))
    (nreverse acc)))

(defun %check-dependent-schemas (parsed value ctx schema)
  (declare (ignore schema))
  (when (%json-object-p value)
    (dolist (entry parsed)
      (multiple-value-bind (_ present-p) (gethash (car entry) value)
        (declare (ignore _))
        (when present-p
          (%check-schema (cdr entry) value ctx))))))

(register-keyword "dependentSchemas"
                  :parser #'%parse-dependent-schemas
                  :checker #'%check-dependent-schemas
                  :child-schemas
                  (lambda (parsed)
                    (mapcar (lambda (e)
                              (cons (concatenate 'string "/dependentSchemas/"
                                                 (%escape-pointer-segment
                                                  (car e)))
                                    (cdr e)))
                            parsed)))

(defun %parse-dependent-required (val)
  (unless (hash-table-p val)
    (raise-invalid-schema "dependentRequired must be a JSON object"))
  (let ((acc '()))
    (loop for k being the hash-keys of val using (hash-value v)
          do (unless (vectorp v)
               (raise-invalid-schema
                "dependentRequired entry ~S must be an array" k))
          do (push (cons k (coerce v 'list)) acc))
    (nreverse acc)))

(defun %check-dependent-required (parsed value ctx schema)
  (declare (ignore schema))
  (when (%json-object-p value)
    (dolist (entry parsed)
      (multiple-value-bind (_ present-p) (gethash (car entry) value)
        (declare (ignore _))
        (when present-p
          (dolist (req (cdr entry))
            (multiple-value-bind (__ req-present) (gethash req value)
              (declare (ignore __))
              (unless req-present
                (push-error ctx
                            (format nil "Property ~S requires ~S to also be present"
                                    (car entry) req))))))))))

(register-keyword "dependentRequired"
                  :parser #'%parse-dependent-required
                  :checker #'%check-dependent-required)

;;; ============================================================================
;;; $ref / $dynamicRef
;;; ============================================================================
;;; Stored as a parsed-marker so the validator dispatches to %CHECK-REF.
;;; Resolution happens lazily at validate time (lets parse complete even when
;;; the target schema is forward-defined inside the same document).

(defstruct ref-marker uri kind) ; KIND is :REF or :DYNAMIC

(defun %parse-ref (val)
  (unless (stringp val)
    (raise-invalid-schema "$ref must be a string"))
  (make-ref-marker :uri val :kind :ref))

(defun %parse-dynamic-ref (val)
  (unless (stringp val)
    (raise-invalid-schema "$dynamicRef must be a string"))
  (make-ref-marker :uri val :kind :dynamic))

(defun %resolve-ref (marker ctx)
  "Resolve MARKER against CTX's root self-registry. Returns the JSON-SCHEMA
   referent or NIL when unresolvable. For $dynamicRef, walks the dynamic-scope
   stack looking for a matching $dynamicAnchor."
  (let* ((uri (ref-marker-uri marker))
         (root (eval-ctx-root ctx))
         (self (json-schema-self-registry root)))
    (cond
      ;; Same-document JSON Pointer: "#/foo/bar"
      ((and (plusp (length uri))
            (char= (char uri 0) #\#)
            (or (= (length uri) 1)
                (char= (char uri 1) #\/)))
       (gethash (subseq uri 1) self))
      ;; Same-document anchor / dynamic-anchor: "#meta"
      ((and (plusp (length uri))
            (char= (char uri 0) #\#))
       (let ((name (subseq uri 1)))
         (or (when (eq (ref-marker-kind marker) :dynamic)
               ;; Dynamic resolution: search the scope stack outermost-first.
               (loop for scope in (reverse (eval-ctx-dynamic-scope ctx))
                     for found = (gethash (concatenate 'string "$dyn:" name)
                                          scope)
                     when found return found))
             (gethash name self)
             ;; Fall through: anchor lookup may match a $dynamicAnchor entry.
             (gethash (concatenate 'string "$dyn:" name) self))))
      ;; Cross-document URI lookup (registry).
      (t (get-schema uri)))))

(defun %check-ref (marker value ctx schema)
  (declare (ignore schema))
  (let ((target (%resolve-ref marker ctx)))
    (cond
      ((null target)
       (unless (eval-ctx-ignore-unresolvable-refs ctx)
         (push-error ctx (format nil "Unresolvable ~A: ~S"
                                 (ref-marker-kind marker)
                                 (ref-marker-uri marker)))))
      (t (%check-schema target value ctx)))))

(register-keyword "$ref" :parser #'%parse-ref :checker #'%check-ref)
(register-keyword "$dynamicRef"
                  :parser #'%parse-dynamic-ref
                  :checker #'%check-ref)
