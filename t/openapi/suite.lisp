(in-package :lol-web/openapi/test)

(def-suite :lol-web/openapi/test
  :description "Tests for :lol-web/openapi — OpenAPI 3.1 emitter.")

(defun run-tests ()
  "Run :lol-web/openapi/test suite. Signals an error on any failure so the
   buildLisp test phase fails the derivation."
  (unless (fiveam:run! :lol-web/openapi/test)
    (error "lol-web/openapi/test: at least one assertion failed"))
  t)
