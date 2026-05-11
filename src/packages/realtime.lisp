;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: CL-USER; Base: 10 -*-
;;;; :lol-web/realtime — server-side WebSocket and SSE primitives
;;;;   src/realtime/{websocket,sse}.lisp

(in-package :cl-user)

(defpackage :lol-web/realtime
  (:use :cl :iterate
        :lol-web/server)   ; encode-json-string, decode-json-string
  (:export
   ;; websocket.lisp
   #:*ws-connections*
   #:ws-connection-count
   #:ws-channels
   #:make-ws-handler
   #:defws
   #:ws-send
   #:ws-send-text
   #:ws-send-binary
   #:ws-send-json
   #:ws-close
   #:ws-broadcast
   #:ws-broadcast-json
   #:ws-broadcast-all
   #:ws-broadcast-html
   #:ws-broadcast-oob
   #:ws-broadcast-trigger
   ;; sse.lisp
   #:*sse-connections*
   #:sse-connection-count
   #:sse-channels
   #:make-sse-handler
   #:defsse
   #:format-sse-event
   #:sse-send
   #:sse-send-comment
   #:sse-ping-all
   #:sse-broadcast
   #:sse-broadcast-all
   #:sse-broadcast-html
   #:sse-broadcast-oob
   #:sse-broadcast-trigger))
