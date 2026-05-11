(in-package :lol-web/forms/test)

(def-suite :lol-web/forms/test
  :description "Tests for :lol-web/forms.")

(defun run-tests ()
  "Run :lol-web/forms/test suite. Signals an error on any failure so
   the buildLisp test phase fails the derivation."
  (unless (fiveam:run! :lol-web/forms/test)
    (error "lol-web/forms/test: at least one assertion failed"))
  t)
