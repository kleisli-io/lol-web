;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: LOL-WEB/EXTRACTORS; Base: 10 -*-
;;;; String→typed-value coercion. Failures signal EXTRACTOR-COERCION-ERROR
;;;; (status 400) so WITH-ERROR-HANDLING translates them to a Bad Request
;;;; response with a useful message naming the failing extractor.

(in-package :lol-web/extractors)

(defun %coerce-value (raw target-type spec)
  "Coerce RAW (a string) to TARGET-TYPE. Returns the coerced value or
   signals EXTRACTOR-COERCION-ERROR. SPEC is passed through to the
   condition so the response message can name the extractor."
  (case target-type
    ((t) raw)
    ((string) raw)
    ((integer) (%coerce-integer raw spec))
    ((boolean) (%coerce-boolean raw spec))
    ((keyword) (%coerce-keyword raw spec))
    ((symbol) (%coerce-symbol raw spec))
    (t
     (error 'extractor-coercion-error
            :extractor-name (extractor-spec-name spec)
            :extractor-kind (extractor-spec-kind spec)
            :raw-value raw
            :target-type target-type
            :body (format nil "Unsupported coercion target type ~S for extractor ~S."
                          target-type (extractor-spec-name spec))))))

(defun %coerce-integer (raw spec)
  "Parse RAW as an integer. Accepts already-INTEGER values (e.g. from
   :json-body with a numeric field) and returns them unchanged. Strings
   are parsed via PARSE-INTEGER with surrounding-whitespace tolerance.
   Anything else signals EXTRACTOR-COERCION-ERROR."
  (cond
    ((integerp raw) raw)
    ((stringp raw)
     (handler-case
         (let ((trimmed (string-trim '(#\Space #\Tab) raw)))
           (when (zerop (length trimmed))
             (%signal-coercion raw 'integer spec))
           (parse-integer trimmed))
       (parse-error () (%signal-coercion raw 'integer spec))
       (type-error () (%signal-coercion raw 'integer spec))))
    (t (%signal-coercion raw 'integer spec))))

(defun %coerce-boolean (raw spec)
  "Coerce RAW to a boolean. Accepts CL booleans (T / NIL) directly.
   Strings are parsed for true/false/1/0/yes/no/on/off case-insensitively.
   Anything else signals EXTRACTOR-COERCION-ERROR."
  (cond
    ((eq raw t) t)
    ((null raw) nil)
    ((stringp raw)
     (let ((normalized (string-downcase (string-trim '(#\Space #\Tab) raw))))
       (cond
         ((member normalized '("true" "1" "yes" "on" "t") :test #'string=) t)
         ((member normalized '("false" "0" "no" "off" "nil" "") :test #'string=) nil)
         (t (%signal-coercion raw 'boolean spec)))))
    (t (%signal-coercion raw 'boolean spec))))

(defun %coerce-keyword (raw spec)
  "Coerce RAW to a keyword. Accepts existing KEYWORDS unchanged. Strings
   are upcased and interned into the keyword package. Empty strings fail —
   a missing-input should have been caught earlier in RESOLVE-EXTRACTOR's
   required-p check; reaching coercion with an empty string means the
   source literally contained an empty value, which is not a valid keyword."
  (cond
    ((keywordp raw) raw)
    ((stringp raw)
     (let ((trimmed (string-trim '(#\Space #\Tab) raw)))
       (when (zerop (length trimmed))
         (%signal-coercion raw 'keyword spec))
       (intern (string-upcase trimmed) :keyword)))
    (t (%signal-coercion raw 'keyword spec))))

(defun %coerce-symbol (raw spec)
  "Coerce RAW to a symbol. Accepts existing symbols unchanged. Strings are
   upcased and interned into the keyword package — same shape as
   %COERCE-KEYWORD; the distinction matters at OpenAPI emission time, not
   at runtime. Kept separate so user code that types its parameters as
   SYMBOL vs KEYWORD reads naturally."
  (cond
    ((symbolp raw) raw)
    ((stringp raw)
     (let ((trimmed (string-trim '(#\Space #\Tab) raw)))
       (when (zerop (length trimmed))
         (%signal-coercion raw 'symbol spec))
       (intern (string-upcase trimmed) :keyword)))
    (t (%signal-coercion raw 'symbol spec))))

(defun %signal-coercion (raw target-type spec)
  (error 'extractor-coercion-error
         :extractor-name (extractor-spec-name spec)
         :extractor-kind (extractor-spec-kind spec)
         :raw-value raw
         :target-type target-type
         :body (format nil "Cannot coerce ~S to ~A for ~A extractor ~S."
                       raw target-type
                       (extractor-spec-kind spec)
                       (extractor-spec-name spec))))
