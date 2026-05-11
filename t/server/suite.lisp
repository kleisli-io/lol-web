(in-package :lol-web/server/test)

(def-suite :lol-web/server/test
  :description "Tests for :lol-web/server.")

(defun run-tests ()
  "Run :lol-web/server/test suite. Signals an error on any failure so
   the buildLisp test phase fails the derivation."
  (unless (fiveam:run! :lol-web/server/test)
    (error "lol-web/server/test: at least one assertion failed"))
  t)
