;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: LOL-WEB/EXTRACTORS; Base: 10 -*-
;;;; Pre-server-start sentinel: walks *HANDLER-METADATA* and signals
;;;; EXTRACTOR-NOT-REGISTERED at startup if any DEFHANDLER references an
;;;; extractor KIND with no RESOLVE-EXTRACTOR method (or names a
;;;; CUSTOM-RESOLVER symbol that isn't fbound). Pushed onto
;;;; LOL-WEB/SERVER:*BEFORE-SERVER-START-HOOK* at load time.

(in-package :lol-web/extractors)

(defun %kind-has-method-p (kind)
  "True iff RESOLVE-EXTRACTOR has a method that runs for KIND, established by
   probing rather than MOP introspection.

   Probe construction: an EXTRACTOR-SPEC of the queried KIND with NIL env and
   NIL path-params, no custom-resolver. If a kind-specific method is
   registered, its body sees missing input and signals MISSING-EXTRACTOR-INPUT
   (a subtype of EXTRACTOR-ERROR) — the kind IS registered. If only the
   default (KIND T) method matches, it signals EXTRACTOR-NOT-REGISTERED
   directly — the kind is NOT registered.

   This trades a single throwaway condition allocation per registered kind at
   startup for portability across implementations without depending on
   closer-mop / SB-MOP."
  (let ((probe (make-extractor-spec :name 'sentinel-probe
                                    :kind kind
                                    :type t
                                    :required-p t)))
    (handler-case
        (progn
          (resolve-extractor kind probe nil nil)
          ;; Method ran without erroring — kind is registered.
          t)
      (extractor-not-registered () nil)
      ;; Any other EXTRACTOR-ERROR (missing input, coercion failure, …)
      ;; means a kind-specific method ran far enough to error on the empty
      ;; probe — the kind IS registered, just not satisfiable here.
      (extractor-error () t))))

(defun %check-spec-resolvable (spec method path)
  "Verify SPEC is resolvable: either CUSTOM-RESOLVER names an fbound function,
   or KIND has a registered RESOLVE-EXTRACTOR method. Signals
   EXTRACTOR-NOT-REGISTERED naming METHOD/PATH otherwise."
  (let ((custom (extractor-spec-custom-resolver spec))
        (kind (extractor-spec-kind spec))
        (name (extractor-spec-name spec)))
    (cond
      (custom
       (unless (and (symbolp custom) (fboundp custom))
         (error 'extractor-not-registered
                :extractor-name name
                :extractor-kind kind
                :body (format nil
                              "Handler ~S ~A ~S declares :resolver ~S, but the symbol is not fbound."
                              method path name custom))))
      (t
       (unless (%kind-has-method-p kind)
         (error 'extractor-not-registered
                :extractor-name name
                :extractor-kind kind
                :body (format nil
                              "Handler ~S ~A ~S declares :kind ~S, but no RESOLVE-EXTRACTOR method is registered for that kind."
                              method path name kind)))))))

(defun %validate-handler-metadata-or-error (&optional (metadata *handler-metadata*))
  "Walk METADATA (default: *HANDLER-METADATA*); for each registered handler,
   check that every EXTRACTOR-SPEC in its :EXTRACTORS list is resolvable.
   Signals EXTRACTOR-NOT-REGISTERED on the first offender. Returns the count
   of validated extractors when every spec passes.

   Pushed onto LOL-WEB/SERVER:*BEFORE-SERVER-START-HOOK* at load time so
   START-SERVER fails fast with a typed condition naming the offending route
   and extractor instead of letting the broken handler 500 on its first
   request."
  (let ((checked 0))
    (bordeaux-threads:with-recursive-lock-held (*handler-metadata-lock*)
      (loop for key being the hash-keys of metadata using (hash-value plist)
            for method = (car key)
            for path = (cdr key)
            do (dolist (spec (getf plist :extractors))
                 (%check-spec-resolvable spec method path)
                 (incf checked))))
    checked))

(eval-when (:load-toplevel :execute)
  (pushnew '%validate-handler-metadata-or-error
           lol-web/server:*before-server-start-hook*))
