(defpackage :lol-web/css/test
  (:use :cl :lol-web/css)
  (:import-from :fiveam
                #:def-suite
                #:in-suite
                #:test
                #:is
                #:signals)
  (:export
   #:run-tests))

(in-package :lol-web/css/test)
