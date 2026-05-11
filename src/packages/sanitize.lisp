;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: CL-USER; Base: 10 -*-
;;;; :lol-web/sanitize — input sanitization (HTML escape, attribute escape, URL guard)
;;;;   src/sanitize/sanitize.lisp

(in-package :cl-user)

(defpackage :lol-web/sanitize
  (:use :cl :iterate)
  (:export
   #:sanitize-html
   #:sanitize-attribute
   #:sanitize-url))
