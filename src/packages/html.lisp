;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: CL-USER; Base: 10 -*-
;;;; :lol-web/html — HTML rendering, page template, escape
;;;;   src/html/{elements,page,escape}.lisp
;;;;
;;;; Stands alone in the package graph apart from :lol-web/sanitize. html-page
;;;; references later-loaded helpers (htmx, server, devtools) through their
;;;; full package names so this sub-package can be consumed independently.

(in-package :cl-user)

(defpackage :lol-web/html
  (:use :cl :iterate
        :lol-web/sanitize)
  (:export
   ;; elements.lisp
   #:htm
   #:htm-str
   #:html-attrs
   #:render-component
   #:component->html
   #:*component-render-hook*
   #:highlight-sexp
   ;; page.lisp
   #:html-page
   #:reactive-runtime-js
   ;; escape.lisp
   #:escape-html
   #:safe-str
   #:safe-fmt))
