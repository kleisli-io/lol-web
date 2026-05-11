(in-package :lol-web/rendering/test)

(def-suite :lol-web/rendering/test
  :description "Tests for :lol-web/rendering.")

(defun run-tests ()
  "Run :lol-web/rendering/test suite. Signals an error on any failure so
   the buildLisp test phase fails the derivation."
  (unless (fiveam:run! :lol-web/rendering/test)
    (error "lol-web/rendering/test: at least one assertion failed"))
  t)
