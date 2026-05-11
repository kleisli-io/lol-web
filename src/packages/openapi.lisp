;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: CL-USER; Base: 10 -*-
;;;; :lol-web/openapi — OpenAPI 3.1 spec emitter
;;;;   src/openapi/{schema-mapping,spec-builder}.lisp
;;;;
;;;; Walks LOL-WEB/EXTRACTORS:*HANDLER-METADATA* to build an OpenAPI 3.1
;;;; document as a Lisp alist, and serialises it to JSON via
;;;; LOL-WEB/SERVER:ENCODE-JSON-STRING. The emitter is read-only over the
;;;; metadata registry; it never mutates *ROUTES* or *HANDLER-METADATA*.

(in-package :cl-user)

(defpackage :lol-web/openapi
  (:use :cl
        :lol-web/server
        :lol-web/extractors)
  (:export
   ;; schema-mapping.lisp
   #:lisp-type-to-openapi-schema
   #:kind-to-openapi-location
   ;; spec-builder.lisp
   #:build-openapi-spec
   #:emit-openapi-json))
