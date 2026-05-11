(defpackage :lol-web/core/test
  (:use :cl :lol-web/core)
  (:import-from :fiveam
                #:def-suite
                #:in-suite
                #:test
                #:is
                #:is-true
                #:is-false)
  (:export
   #:run-tests))

(in-package :lol-web/core/test)
