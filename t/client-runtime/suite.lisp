(in-package :lol-web/client-runtime/test)

(def-suite :lol-web/client-runtime/test
  :description "Tests for :lol-web/client-runtime.")

(defun run-tests ()
  "Run :lol-web/client-runtime/test suite. Signals an error on any
   failure so the buildLisp test phase fails the derivation."
  (unless (fiveam:run! :lol-web/client-runtime/test)
    (error "lol-web/client-runtime/test: at least one assertion failed"))
  t)
