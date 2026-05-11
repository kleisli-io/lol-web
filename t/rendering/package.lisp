(defpackage :lol-web/rendering/test
  (:use :cl :lol-web/rendering)
  (:import-from :fiveam
                #:def-suite
                #:in-suite
                #:test
                #:is)
  (:export
   #:run-tests))

(in-package :lol-web/rendering/test)
