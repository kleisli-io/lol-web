(defpackage :lol-web/jschema/test
  (:use :cl :lol-web/jschema)
  (:import-from :fiveam
                #:def-suite
                #:in-suite
                #:test
                #:is
                #:signals
                #:finishes)
  (:export
   #:run-tests))

(in-package :lol-web/jschema/test)
