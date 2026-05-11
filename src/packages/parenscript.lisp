;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: CL-USER; Base: 10 -*-
;;;; :lol-web/parenscript — Lisp-side helpers for emitting JS via parenscript
;;;;   src/client/parenscript.lisp

(in-package :cl-user)

(defpackage :lol-web/parenscript
  (:use :cl :iterate)
  (:import-from :let-over-lambda
                :aif
                :symb)
  (:export
   #:reactive-script
   #:on-click
   #:on-change))
