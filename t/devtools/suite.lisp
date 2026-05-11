(in-package :lol-web/devtools/test)

(def-suite :lol-web/devtools/test
  :description "Tests for :lol-web/devtools.")

(defun run-tests ()
  "Run :lol-web/devtools/test suite. Signals an error on any failure so
   the buildLisp test phase fails the derivation."
  (unless (fiveam:run! :lol-web/devtools/test)
    (error "lol-web/devtools/test: at least one assertion failed"))
  t)
