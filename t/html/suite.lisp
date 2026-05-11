(in-package :lol-web/html/test)

(def-suite :lol-web/html/test
  :description "Tests for :lol-web/html.")

(defun run-tests ()
  "Run :lol-web/html/test suite. Signals an error on any failure so
   the buildLisp test phase fails the derivation."
  (unless (fiveam:run! :lol-web/html/test)
    (error "lol-web/html/test: at least one assertion failed"))
  t)
