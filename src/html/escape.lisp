;;;; HTML escape utilities — thin wrappers over :lol-web/sanitize.

(in-package :lol-web/html)

;;; ============================================================================
;;; HTML ESCAPING (XSS Prevention)
;;;
;;; Thin wrappers exposing :lol-web/sanitize's sanitize-html under HTML-flavoured
;;; names. The :lol-web/html package :uses :lol-web/sanitize, so sanitize-html
;;; resolves directly here.
;;; ============================================================================

(defun escape-html (string)
  "Escape HTML special characters to prevent XSS. Delegates to sanitize-html.

   Example:
     (escape-html \"<script>alert('xss')</script>\")
     => \"&lt;script&gt;alert('xss')&lt;/script&gt;\""
  (sanitize-html string))

(defmacro safe-str (expr)
  "Output escaped string in cl-who context.
   Use this when outputting user-provided content.

   Example (in cl-who):
     (:p (safe-str user-input))"
  `(cl-who:str (escape-html ,expr)))

(defmacro safe-fmt (control-string &rest args)
  "Format and escape for safe HTML output.

   Example:
     (safe-fmt \"Hello, ~A!\" username)"
  `(cl-who:str (escape-html (format nil ,control-string ,@args))))
