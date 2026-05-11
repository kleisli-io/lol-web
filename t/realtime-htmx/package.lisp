(defpackage :lol-web/realtime-htmx/test
  (:use :cl :lol-web/realtime-htmx)
  (:import-from :fiveam
                #:def-suite
                #:in-suite
                #:test
                #:is)
  (:export
   #:run-tests))

(in-package :lol-web/realtime-htmx/test)
