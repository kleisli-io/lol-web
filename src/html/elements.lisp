;;;; LOL-REACTIVE HTML Elements
;;;; cl-who shorthand macros and component rendering utilities
;;;;
;;;; GENERIC INFRASTRUCTURE - NO hardcoded colors, fonts, or theme styles.

(in-package :lol-web/html)

;;; ============================================================================
;;; CL-WHO CONFIGURATION
;;; ============================================================================

(setf cl-who:*attribute-quote-char* #\"
      cl-who:*html-empty-tag-aware-p* t)

;;; ============================================================================
;;; CL-WHO SHORTHAND MACROS
;;; ============================================================================

(defmacro htm (&body body)
  "Shorthand for cl-who output to *standard-output*."
  `(cl-who:with-html-output (*standard-output*) ,@body))

(defmacro htm-str (&body body)
  "Generate HTML and return as string."
  `(cl-who:with-html-output-to-string (s) ,@body))

;;; ============================================================================
;;; ATTRIBUTE STRING BUILDER
;;; ============================================================================

(defun html-attrs (&rest pairs)
  "Build an HTML attribute fragment from key-value pairs.
   NIL values are omitted entirely; T values become boolean attributes
   (no `=value` suffix). All other values are coerced to strings and
   passed through `sanitize-attribute` so embedded quotes and angle
   brackets cannot escape the attribute context.

   Returns a string with a leading space when non-empty so it can be
   spliced directly after a tag name: `(format nil \"<input~A/>\"
   (html-attrs ...))`."
  (with-output-to-string (s)
    (loop for (name value) on pairs by #'cddr
          when value do
          (if (eq value t)
              (format s " ~A" name)
              (format s " ~A=\"~A\"" name (sanitize-attribute (princ-to-string value)))))))

;;; ============================================================================
;;; COMPONENT RENDERING
;;; ============================================================================

(defun render-component (component)
  "Render a component to HTML string."
  (funcall component :render))

(defparameter *component-render-hook* nil
  "Optional function (function (component) string) that replaces the
   default component-wrapper div around a component's rendered HTML.
   :lol-web/devtools installs an x-ray wrapper here when surgery mode
   is enabled. Held in :lol-web/html so the renderer never has to know
   about devtools (which depends on html, so the reverse edge would
   create a cycle).")

(defun component->html (component &key (wrapper t))
  "Convert a component to HTML, optionally wrapping in a container.
   When *component-render-hook* is bound to a function and WRAPPER is
   true, the hook produces the wrapper instead of the default div."
  (cond
    ((and wrapper *component-render-hook*)
     (funcall *component-render-hook* component))
    (wrapper
     (let ((html (render-component component))
           (id (funcall component :id)))
       (cl-who:with-html-output-to-string (s)
         (:div :id id
               :class "component-wrapper"
               :data-component-id id
           (cl-who:str html)))))
    (t
     (render-component component))))

;;; ============================================================================
;;; S-EXPRESSION HIGHLIGHTING (generic utility)
;;; ============================================================================

(defun highlight-sexp (form)
  "Convert a Lisp form to syntax-highlighted HTML.

   Uses CSS classes that apps can style as needed. The printed form is
   HTML-escaped before the regex passes run so any `<`, `>`, `&`, `'`,
   or `\"` characters appearing inside string-valued positions become
   inert entities. The string-tag regex therefore matches `&quot;...&quot;`
   rather than raw `\"...\"`."
  (let ((str (escape-html (prin1-to-string form))))
    (setf str (cl-ppcre:regex-replace-all
               ":(\\w+)"
               str
               "<span class=\"sexp-keyword\">:\\1</span>"))
    (setf str (cl-ppcre:regex-replace-all
               "&quot;(.*?)&quot;"
               str
               "<span class=\"sexp-string\">&quot;\\1&quot;</span>"))
    (setf str (cl-ppcre:regex-replace-all
               "\\b(\\d+)\\b"
               str
               "<span class=\"sexp-number\">\\1</span>"))
    str))
