;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: CL-USER; Base: 10 -*-
;;;; :lol-web/forms — form DSL (no public API today; carved for boundary intent)
;;;;   src/forms/form-dsl.lisp

(in-package :cl-user)

(defpackage :lol-web/forms
  (:use :cl :iterate
        :lol-web/sanitize  ; sanitize-attribute
        :lol-web/css       ; classes, css-rule, css-var, css-section
        :lol-web/html      ; htm, htm-str, escape-html
        :lol-web/server)   ; post-param, csrf-token-input
  (:import-from :let-over-lambda :symb)
  (:export))
