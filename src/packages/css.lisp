;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: CL-USER; Base: 10 -*-
;;;; :lol-web/css — CSS infrastructure, tokens, generation, tailwind helpers
;;;;   src/css/{registry,tokens,generation,tailwind}.lisp

(in-package :cl-user)

(defpackage :lol-web/css
  (:use :cl :iterate)
  (:export
   ;; registry.lisp
   #:*component-css-registry*
   #:*css-load-order*
   #:make-css-module
   #:get-css-module
   #:get-component-css
   #:generate-all-component-css
   #:defcss
   #:clear-css-registry
   #:list-registered-css-components
   #:inspect-css-registry
   ;; generation.lisp
   #:css-rule
   #:css-rules
   #:css-section
   #:css-keyframes
   #:css-media
   #:css-var
   #:css-var-definition
   ;; tokens.lisp
   #:*colors*
   #:*typography*
   #:*spacing*
   #:*effects*
   #:*default-colors*
   #:*default-typography*
   #:*default-spacing*
   #:*default-effects*
   #:get-color
   #:get-font
   #:get-spacing
   #:get-effect
   #:validate-token
   #:levenshtein-distance
   #:find-closest-match
   #:generate-css-variables
   ;; tailwind.lisp
   #:tw-color
   #:tw-spacing
   #:tw-bg
   #:tw-text
   #:tw-border
   #:tw-arbitrary
   #:tw-bg-value
   #:tw-text-value
   #:tw-border-value
   #:classes
   #:null-or-empty-p
   #:tailwind-config))
