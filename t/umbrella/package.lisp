;;;; lol-web umbrella test package
;;;;
;;;; Hosts the umbrella suite (shim-parity assertions that need both
;;;; :lol-web and :lol-reactive loaded) plus the run-all-tests entry
;;;; point that the umbrella build phase invokes.

(defpackage :lol-web/test
  (:use :cl)
  (:import-from :fiveam
                #:def-suite
                #:in-suite
                #:test
                #:is)
  (:export
   #:run-all-tests))

(in-package :lol-web/test)
