(defpackage :lol-web/htmx/test
  (:use :cl :lol-web/htmx)
  (:import-from :fiveam
                #:def-suite
                #:in-suite
                #:test
                #:is)
  (:export
   #:run-tests))

(in-package :lol-web/htmx/test)
