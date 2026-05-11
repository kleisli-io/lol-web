;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: LOL-WEB/OPENAPI; Base: 10 -*-
;;;; Pure mappings from extractor declarations to OpenAPI 3.1 fragments.
;;;; No I/O, no metadata reads — just Lisp-type → schema, extractor-kind →
;;;; parameter location, and path-template translation.

(in-package :lol-web/openapi)

;;; ============================================================================
;;; PATH TEMPLATE TRANSLATION
;;; ============================================================================

(defun %lisp-path-to-openapi-path (path)
  "Translate a defroute path string (`/users/:id`) to the OpenAPI 3.1
   path-template form (`/users/{id}`). A segment starting with `:` becomes
   an OpenAPI path parameter named after the rest of the segment. Other
   segments are emitted verbatim."
  (cl-ppcre:regex-replace-all "/:([^/]+)" path "/{\\1}"))

;;; ============================================================================
;;; LISP TYPE → JSON SCHEMA
;;; ============================================================================

(defun lisp-type-to-openapi-schema (type)
  "Map a Lisp type symbol from an extractor's :TYPE slot to a JSON-Schema
   2020-12 fragment suitable for an OpenAPI 3.1 parameter or request body
   schema. Returns either an alist describing the schema, or T (which
   ENCODE-JSON-STRING serialises as JSON `true`, the boolean-schema form
   meaning `any value valid`).

   Built-in coercions:
     T          → T          (no constraint; permissive schema)
     INTEGER    → {type: integer}
     STRING     → {type: string}
     BOOLEAN    → {type: boolean}
     KEYWORD    → {type: string}
     SYMBOL     → {type: string}

   Unknown types fall back to T (permissive). Users wanting tighter
   schemas can post-process the alist returned by BUILD-OPENAPI-SPEC."
  (cond ((eq type t)        t)
        ((eq type 'integer) (list (cons "type" "integer")))
        ((eq type 'string)  (list (cons "type" "string")))
        ((eq type 'boolean) (list (cons "type" "boolean")))
        ((or (eq type 'keyword) (eq type 'symbol))
         (list (cons "type" "string")))
        (t t)))

;;; ============================================================================
;;; EXTRACTOR KIND → PARAMETER LOCATION
;;; ============================================================================

(defun kind-to-openapi-location (kind)
  "Map an extractor KIND keyword to an OpenAPI 3.1 parameter location
   string (`path` / `query` / `header` / `cookie`), or NIL if KIND
   denotes a request body (`:body`, `:json-body`) or an unrecognised
   custom extractor.

   The NIL return is the discrimination signal used by SPEC-BUILDER: a
   non-NIL value routes the extractor into `parameters`; a NIL value
   routes it into `requestBody`. Extractors with KIND not in this set
   are dropped from the emitted spec (custom extractors must register
   their own emitter integration)."
  (case kind
    (:path   "path")
    (:query  "query")
    (:header "header")
    (:cookie "cookie")
    (t       nil)))
