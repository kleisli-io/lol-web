(in-package :lol-web/optimization/test)
(in-suite :lol-web/optimization/test)

;;; ============================================================================
;;; with-reactive-bindings: no macro-time eval of the controller
;;; ============================================================================

(test regression-with-reactive-bindings-takes-explicit-names
  "with-reactive-bindings macro-expands to a let that holds the
   controller, never invoking it at macro-expansion time. Macro-time
   evaluation of a runtime variable would only succeed for literal
   forms and would mask symbol-resolution failures."
  (let ((expansion (macroexpand-1
                    '(lol-web/optimization:with-reactive-bindings (some-var x y)
                      (+ x y)))))
    (is (consp expansion)
        "with-reactive-bindings must expand to a form")
    (is (eq (car expansion) 'let)
        "expansion wraps the controller in a let")))

(test regression-with-reactive-bindings-runtime-fetches-named-bindings
  "Runtime: with-reactive-bindings fetches each named binding through the
   controller's :get message and binds it locally for the body."
  (let* ((calls nil)
         (controller (lambda (msg &rest args)
                       (push (cons msg args) calls)
                       (case msg
                         (:get (case (first args)
                                 (x 10)
                                 (y 32)))
                         (t nil)))))
    (let ((sum (lol-web/optimization:with-reactive-bindings (controller x y)
                 (+ x y))))
      (is (= sum 42)
          "with-reactive-bindings binds named values from controller :get")
      (is (member '(:get x) calls :test #'equal)
          "controller was queried for x")
      (is (member '(:get y) calls :test #'equal)
          "controller was queried for y"))))

;;; ============================================================================
;;; CSS prefix-matching: bare prefixes must not validate as classes
;;; ============================================================================

(test regression-css-prefix-bare-not-valid
  "A registered prefix like \"p-\" must not itself validate as a CSS
   class — bare prefixes are not real Tailwind class names. Validation
   accepts a class only when it extends a prefix with at least one
   trailing character."
  (let ((lol-web/optimization:*registered-css-classes* (make-hash-table :test 'equal))
        (lol-web/optimization:*registered-css-prefixes* nil))
    (lol-web/optimization:register-tailwind-classes)
    (signals warning
             (lol-web/optimization:validate-css-class "p-"))
    (signals warning
             (lol-web/optimization:validate-css-class "text-"))))

(defun %warnings-emitted (thunk)
  "Collect every WARNING signalled while THUNK runs, returning the list
   of condition objects. Lets tests assert on the absence of warnings
   without confusing fiveam's IS macro about nil vs no-warning."
  (let ((warnings nil))
    (handler-bind ((warning (lambda (c)
                              (push c warnings)
                              (muffle-warning c))))
      (funcall thunk))
    (nreverse warnings)))

(test regression-css-prefix-extends-prefix-validates
  "A class that extends a registered prefix (p-4, text-red-500,
   hover:bg-blue-500) validates without warning. Tailwind class names
   compose freely after the prefix, so prefix support is required to
   avoid noise on every utility class."
  (let ((lol-web/optimization:*registered-css-classes* (make-hash-table :test 'equal))
        (lol-web/optimization:*registered-css-prefixes* nil))
    (lol-web/optimization:register-tailwind-classes)
    (let ((warnings (%warnings-emitted
                     (lambda ()
                       (lol-web/optimization:validate-css-class "p-4")
                       (lol-web/optimization:validate-css-class "text-red-500")
                       (lol-web/optimization:validate-css-class "hover:bg-blue-500")))))
      (is (null warnings)
          "extending classes p-4, text-red-500, hover:bg-blue-500 must not warn"))))

(test regression-css-static-utility-validates
  "Static utility classes (flex, grid, block, inline, hidden) live in
   the exact-match registry and validate without involving the prefix
   table."
  (let ((lol-web/optimization:*registered-css-classes* (make-hash-table :test 'equal))
        (lol-web/optimization:*registered-css-prefixes* nil))
    (lol-web/optimization:register-tailwind-classes)
    (let ((warnings (%warnings-emitted
                     (lambda ()
                       (lol-web/optimization:validate-css-class "flex")
                       (lol-web/optimization:validate-css-class "block")))))
      (is (null warnings)
          "static utilities flex/block must not warn"))))

;;; ============================================================================
;;; analyze-dependencies: smoke-level structural check
;;; ============================================================================

(test smoke-analyze-dependencies-detects-direct-references
  "analyze-dependencies returns a hash table mapping each binding to the
   subset of other binding names it references in its value form."
  (let ((g (lol-web/optimization:analyze-dependencies
            '((count 0)
              (doubled (* count 2))
              (message (format nil "~A ~A" count doubled))))))
    (is (hash-table-p g))
    (is (null (gethash 'count g))
        "root binding has no dependencies")
    (is (equal '(count) (gethash 'doubled g))
        "doubled depends on count")
    (let ((deps (gethash 'message g)))
      (is (and (member 'count deps) (member 'doubled deps))
          "message depends on count and doubled"))))
