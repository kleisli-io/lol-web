(in-package :lol-web/realtime/test)

(def-suite :lol-web/realtime/test
  :description "Tests for :lol-web/realtime.")

(defun run-tests ()
  "Run :lol-web/realtime/test suite. Signals an error on any failure
   so the buildLisp test phase fails the derivation."
  (unless (fiveam:run! :lol-web/realtime/test)
    (error "lol-web/realtime/test: at least one assertion failed"))
  t)
