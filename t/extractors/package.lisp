(defpackage :lol-web/extractors/test
  (:use :cl :lol-web/server :lol-web/extractors)
  (:import-from :fiveam
                #:def-suite
                #:in-suite
                #:test
                #:is
                #:signals)
  (:export
   #:run-tests))

(in-package :lol-web/extractors/test)
