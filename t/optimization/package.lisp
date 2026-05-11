(defpackage :lol-web/optimization/test
  (:use :cl :lol-web/optimization)
  (:import-from :fiveam
                #:def-suite
                #:in-suite
                #:test
                #:is
                #:signals)
  (:export
   #:run-tests))
