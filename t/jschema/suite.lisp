(in-package :lol-web/jschema/test)

(def-suite :lol-web/jschema/test
  :description "Tests for :lol-web/jschema — JSON Schema 2020-12 subset.")

(defun run-tests ()
  "Run :lol-web/jschema/test suite. Signals an error on any failure so the
   buildLisp test phase fails the derivation."
  (unless (fiveam:run! :lol-web/jschema/test)
    (error "lol-web/jschema/test: at least one assertion failed"))
  t)
