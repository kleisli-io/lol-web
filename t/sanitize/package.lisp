(defpackage :lol-web/sanitize/test
  (:use :cl :lol-web/sanitize)
  (:import-from :fiveam
                #:def-suite
                #:in-suite
                #:test
                #:is)
  (:export
   #:run-tests))

(in-package :lol-web/sanitize/test)
