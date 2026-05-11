(in-package :lol-web/wizards/test)

(def-suite :lol-web/wizards/test
  :description "Tests for :lol-web/wizards.")

(defun run-tests ()
  "Run :lol-web/wizards/test suite. Signals an error on any failure so
   the buildLisp test phase fails the derivation."
  (unless (fiveam:run! :lol-web/wizards/test)
    (error "lol-web/wizards/test: at least one assertion failed"))
  t)
