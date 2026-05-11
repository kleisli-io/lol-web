(in-package :lol-web/sanitize/test)

(def-suite :lol-web/sanitize/test
  :description "Tests for :lol-web/sanitize.")

(defun run-tests ()
  "Run :lol-web/sanitize/test suite. Signals an error on any failure so
   the buildLisp test phase fails the derivation."
  (unless (fiveam:run! :lol-web/sanitize/test)
    (error "lol-web/sanitize/test: at least one assertion failed"))
  t)
