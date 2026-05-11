(in-package :lol-web/htmx/test)

(def-suite :lol-web/htmx/test
  :description "Tests for :lol-web/htmx.")

(defun run-tests ()
  "Run :lol-web/htmx/test suite. Signals an error on any failure so
   the buildLisp test phase fails the derivation."
  (unless (fiveam:run! :lol-web/htmx/test)
    (error "lol-web/htmx/test: at least one assertion failed"))
  t)
