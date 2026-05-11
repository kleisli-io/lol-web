(defpackage :lol-web/realtime/test
  (:use :cl :lol-web/realtime)
  (:import-from :fiveam
                #:def-suite
                #:in-suite
                #:test
                #:is)
  (:export
   #:run-tests))

(in-package :lol-web/realtime/test)
