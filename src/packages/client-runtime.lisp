;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: CL-USER; Base: 10 -*-
;;;; :lol-web/client-runtime — bare reactive runtime JS for the browser
;;;;   src/client/runtime.lisp

(in-package :cl-user)

(defpackage :lol-web/client-runtime
  (:use :cl :iterate
        :lol-web/html             ; reactive-runtime-js
        :lol-web/htmx              ; htmx-runtime-js
        :lol-web/realtime-htmx)    ; ws-client-js, sse-client-js, optimistic-js
  (:export
   #:lol-reactive-runtime-js))
