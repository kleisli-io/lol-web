(in-package :lol-web/resources/test)

(def-suite :lol-web/resources/test
  :description "Tests for :lol-web/resources.")

(defun run-tests ()
  "Run :lol-web/resources/test suite. Signals an error on any failure
   so the buildLisp test phase fails the derivation."
  (unless (fiveam:run! :lol-web/resources/test)
    (error "lol-web/resources/test: at least one assertion failed"))
  t)
