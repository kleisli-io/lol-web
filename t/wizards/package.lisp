(defpackage :lol-web/wizards/test
  (:use :cl :lol-web/wizards)
  (:import-from :fiveam
                #:def-suite
                #:in-suite
                #:test
                #:is)
  (:export
   #:run-tests))

(in-package :lol-web/wizards/test)
