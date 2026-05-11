(in-package :lol-web/fullstack/test)

(def-suite :lol-web/fullstack/test
  :description "Tests for :lol-web/fullstack.")

(defun run-tests ()
  "Run :lol-web/fullstack/test suite. Signals an error on any failure so
   the buildLisp test phase fails the derivation."
  (unless (fiveam:run! :lol-web/fullstack/test)
    (error "lol-web/fullstack/test: at least one assertion failed"))
  t)
