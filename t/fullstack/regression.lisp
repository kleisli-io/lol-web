;;;; Regression test for defcomponent-with-api auto-registration.
;;;;
;;;; The generated constructor built the pandoriclet closure but never called
;;;; register-component, so every API route's (find-component id) lookup
;;;; returned NIL and the handler responded "Component not found". The whole
;;;; API surface for components defined via defcomponent-with-api was inert.
;;;;
;;;; The fixture is interned in :lol-web/fullstack so the macro-template
;;;; expansion (which references find-component, render, etc. as bare symbols)
;;;; resolves them in the same package the macro author wrote them in.

(in-package :lol-web/fullstack)

(defcomponent-with-api regression-api-bug19-component ()
  :state ((counter 0))
  :actions ((incr () (incf counter)))
  :render "<div>probe</div>")

(in-package :lol-web/fullstack/test)
(in-suite :lol-web/fullstack/test)

(test regression-defcomponent-with-api-registers-instance
  "An instance from defcomponent-with-api is findable via find-component"
  (let* ((c (lol-web/fullstack::regression-api-bug19-component))
         (id (funcall c :id)))
    (unwind-protect
         (progn
           (is (eq c (find-component id))
               "find-component returns the same closure as the constructor")
           (is (equal '(:counter 0) (funcall c :state))
               "state surface unchanged by registration"))
      (unregister-component id))))

(test regression-hydration-runtime-uses-property-access-on-el
  "Generated hydration runtime accesses el.getAttribute(), not the
   concatenated identifier elgetAttribute. (ps:@ elget-attribute)
   compiles to a single bare symbol that throws ReferenceError at
   first hydration; the correct (ps:@ el get-attribute) emits the
   property access."
  (let ((js (lol-web/fullstack::hydration-runtime-js)))
    (is (null (search "elgetAttribute" js))
        "elgetAttribute concat-typo present — must be el.getAttribute")
    (is (search "el.getAttribute" js)
        "expected el.getAttribute() in hydrate-all body")))
