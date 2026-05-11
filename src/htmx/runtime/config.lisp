;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: LOL-WEB/HTMX; Base: 10 -*-
;;;; HTMX runtime — config cluster
;;;;
;;;; Object-init pairs for the *htmx* runtime: version string, config defaults,
;;;; AbortController storage (hx-sync), IntersectionObserver storage
;;;; (revealed/intersect triggers).

(in-package :lol-web/htmx)

(defun htmx-runtime-config-pairs ()
  "Property-value pairs for the *htmx* runtime config cluster.
   Returns a flat list (NAME FORM ...) suitable for splicing into ps:create."
  (list
   "version" "0.3.1"
   "config" '(ps:create
              "defaultSwapStyle" "innerHTML"
              "defaultSettleDelay" 20
              "withCredentials" nil
              "timeout" 0)
   "abortControllers" '(ps:create)
   "observers" '(ps:create)))
