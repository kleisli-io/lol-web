(in-package :lol-web/optimization/test)

(def-suite :lol-web/optimization/test
  :description "Tests for :lol-web/optimization.")

(defun run-tests ()
  "Run :lol-web/optimization/test suite. Signals an error on any failure
   so the buildLisp test phase fails the derivation."
  (unless (fiveam:run! :lol-web/optimization/test)
    (error "lol-web/optimization/test: at least one assertion failed"))
  t)
