(in-package :lol-web/core/test)

(def-suite :lol-web/core/test
  :description "Tests for :lol-web/core.")

(defun run-tests ()
  "Run :lol-web/core/test suite. Signals an error on any failure so
   the buildLisp test phase fails the derivation."
  (unless (fiveam:run! :lol-web/core/test)
    (error "lol-web/core/test: at least one assertion failed"))
  t)
