(in-package :lol-web/realtime-htmx/test)

(def-suite :lol-web/realtime-htmx/test
  :description "Tests for :lol-web/realtime-htmx.")

(defun run-tests ()
  "Run :lol-web/realtime-htmx/test suite. Signals an error on any failure
   so the buildLisp test phase fails the derivation."
  (unless (fiveam:run! :lol-web/realtime-htmx/test)
    (error "lol-web/realtime-htmx/test: at least one assertion failed"))
  t)
