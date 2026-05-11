;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: LOL-WEB/JSCHEMA; Base: 10 -*-
;;;; The JSON-SCHEMA struct and the cross-document registry.
;;;;
;;;; Two namespaces:
;;;;   (a) *REGISTRY* — global URI → JSON-SCHEMA. Populated when a parsed
;;;;       schema declared an $id with a host. CLEAR-REGISTRY wipes it.
;;;;   (b) self-registry — per-document JSON Pointer → JSON-SCHEMA. Lives on
;;;;       each root JSON-SCHEMA instance. Populated by parse as it descends.
;;;;       Used to resolve same-document $ref / $dynamicRef.

(in-package :lol-web/jschema)

;;; ============================================================================
;;; JSON-SCHEMA — parsed schema instance
;;; ============================================================================

(defstruct json-schema
  "A parsed JSON Schema. Boolean schemas (true/false) carry BOOL set to
   :TRUE / :FALSE and have no other slots populated. Object schemas carry
   KEYWORDS as an alist of (NAME . PARSED-VALUE) pairs."
  (bool nil)              ; :TRUE / :FALSE / NIL when BOOL is not boolean-shaped
  (id nil)                ; resolved-against-base-URI string, or NIL
  (base-uri nil)          ; PURI:URI for this schema-resource document, or NIL
  (anchor nil)            ; "$anchor" value, or NIL
  (dynamic-anchor nil)    ; "$dynamicAnchor" value, or NIL
  (schema-uri nil)        ; "$schema" string, or NIL — only meaningful at root
  (defs nil)              ; alist of ($defs-name . child-json-schema)
  (keywords nil)          ; alist of (keyword-string . parsed-value)
  (self-registry nil)     ; hash-table json-pointer → json-schema (root only)
  (parent-self-registry nil)) ; back-link for child schemas to find sibling refs

;;; ============================================================================
;;; GLOBAL REGISTRY
;;; ============================================================================

(defvar *registry* (make-hash-table :test 'equal)
  "Global cross-document registry. Keys are URI strings (post-resolution).
   Values are JSON-SCHEMA instances. Populated by PARSE when the input
   document declares a hosted $id.")

(defvar *registry-lock*
  (bordeaux-threads:make-recursive-lock "lol-web/jschema registry"))

(defun clear-registry ()
  "Wipe the global cross-document registry. Useful between test runs."
  (bordeaux-threads:with-recursive-lock-held (*registry-lock*)
    (clrhash *registry*))
  (values))

(defun register-schema (uri schema)
  "Register SCHEMA under URI in the global registry. URI is a string."
  (bordeaux-threads:with-recursive-lock-held (*registry-lock*)
    (setf (gethash uri *registry*) schema)))

(defun get-schema (uri)
  "Find a schema by URI. URI may be a string or a PURI:URI. Returns the
   JSON-SCHEMA, or NIL if no schema is registered. If URI carries a fragment,
   the fragment is resolved through the schema's self-registry as a JSON
   Pointer or anchor name."
  (let* ((uri-obj (etypecase uri
                    (string (puri:parse-uri uri))
                    (puri:uri uri)))
         (fragment (puri:uri-fragment uri-obj))
         (uri-no-frag (puri:copy-uri uri-obj))
         lookup-key)
    (setf (puri:uri-fragment uri-no-frag) nil
          lookup-key (puri:render-uri uri-no-frag nil))
    (let ((root (bordeaux-threads:with-recursive-lock-held (*registry-lock*)
                  (gethash lookup-key *registry*))))
      (cond
        ((null root) nil)
        ((or (null fragment) (string= fragment ""))
         root)
        (t
         (resolve-fragment root fragment))))))

(defun resolve-fragment (root fragment)
  "Resolve FRAGMENT against ROOT's self-registry. FRAGMENT is the URI fragment
   without the leading '#'. JSON Pointer fragments start with '/'; everything
   else is treated as an anchor name."
  (let ((self (json-schema-self-registry root)))
    (when self
      (gethash (if (or (string= fragment "")
                       (char= (char fragment 0) #\/))
                   fragment
                   fragment)
               self))))
