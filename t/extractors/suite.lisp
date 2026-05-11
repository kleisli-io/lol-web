(in-package :lol-web/extractors/test)

(def-suite :lol-web/extractors/test
  :description "Tests for :lol-web/extractors.")

(defun run-tests ()
  "Run :lol-web/extractors/test suite. Signals an error on any failure so
   the buildLisp test phase fails the derivation."
  (unless (fiveam:run! :lol-web/extractors/test)
    (error "lol-web/extractors/test: at least one assertion failed"))
  t)
