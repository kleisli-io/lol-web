(in-package :lol-web/css/test)

(def-suite :lol-web/css/test
  :description "Tests for :lol-web/css.")

(defun run-tests ()
  "Run :lol-web/css/test suite. Signals an error on any failure so
   the buildLisp test phase fails the derivation."
  (unless (fiveam:run! :lol-web/css/test)
    (error "lol-web/css/test: at least one assertion failed"))
  t)
