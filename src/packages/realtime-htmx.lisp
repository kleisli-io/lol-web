;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: CL-USER; Base: 10 -*-
;;;; :lol-web/realtime-htmx — client-side JS emitters for WS/SSE/optimistic
;;;;   src/realtime/{ws-client,sse-client,optimistic}.lisp

(in-package :cl-user)

(defpackage :lol-web/realtime-htmx
  (:use :cl :iterate)
  (:export
   #:ws-client-js
   #:sse-client-js
   #:optimistic-js))
