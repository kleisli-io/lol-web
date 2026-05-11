(defpackage :lol-web/client-runtime/test
  (:use :cl :lol-web/client-runtime)
  (:import-from :fiveam
                #:def-suite
                #:in-suite
                #:test
                #:is)
  (:export
   #:run-tests))

(in-package :lol-web/client-runtime/test)
