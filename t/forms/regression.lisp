;;;; Regression test for forms/form-dsl.lisp Parenscript symbol-concat typos.
;;;;
;;;; (ps:@ elremove) emits elremove() instead of el.remove();
;;;; (ps:@ eprevent-default) emits epreventDefault() instead of e.preventDefault();
;;;; (ps:@ etarget) emits etarget instead of e.target.
;;;; Every form with validation errors threw a JS ReferenceError on submit
;;;; (or on input clearing) before the fix.

(in-package :lol-web/forms/test)
(in-suite :lol-web/forms/test)

(test regression-form-dsl-no-symbol-concat-typos
  "Generated form validation JS uses property access, not symbol concat"
  (lol-web/forms::defform regression-form-probe ()
    :fields ((username :type :string :min 3 :required t)))
  (let ((js (lol-web/forms::generate-form-validation-js 'regression-form-probe)))
    ;; Typo forms must not appear
    (is (null (search "elremove" js))
        "elremove() typo present — should be el.remove()")
    (is (null (search "epreventDefault" js))
        "epreventDefault() typo present — should be e.preventDefault()")
    (is (null (search ".etarget" js))
        ".etarget property access typo present — should be .target on e")
    ;; Correct forms must appear
    (is (search "el.remove" js)
        "Expected el.remove() in generated JS for error-element removal")
    (is (search "e.preventDefault" js)
        "Expected e.preventDefault() in generated JS for invalid-form submit")
    (is (search "e.target" js)
        "Expected e.target in generated JS for input-clear listener")))

(test regression-render-form-emits-multipart-enctype-when-file-field-present
  "A form with any :file field renders enctype=\"multipart/form-data\"; a form
   with no :file field omits the attribute. Browsers ignore the file input's
   contents under the default urlencoded enctype, so the attribute is the
   only mechanism that makes file uploads reach the server."
  (lol-web/forms::defform regression-form-with-upload ()
    :fields ((avatar :type :file :required t)
             (caption :type :string)))
  (lol-web/forms::defform regression-form-text-only ()
    :fields ((username :type :string :required t)))
  (let ((with-file (lol-web/forms::render-form 'regression-form-with-upload))
        (without-file (lol-web/forms::render-form 'regression-form-text-only)))
    (is (search "enctype=\"multipart/form-data\"" with-file)
        "form with :file field must include enctype=\"multipart/form-data\"")
    (is (null (search "enctype=" without-file))
        "form without :file fields must not emit an enctype attribute")))
