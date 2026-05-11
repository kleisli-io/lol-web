(in-package :lol-web/parenscript/test)

(def-suite :lol-web/parenscript/test
  :description "Tests for :lol-web/parenscript.")

(defun run-tests ()
  "Run :lol-web/parenscript/test suite. Signals an error on any failure so
   the buildLisp test phase fails the derivation."
  (unless (fiveam:run! :lol-web/parenscript/test)
    (error "lol-web/parenscript/test: at least one assertion failed"))
  t)
