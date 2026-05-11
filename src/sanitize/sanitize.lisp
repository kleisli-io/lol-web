;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: LOL-WEB/SANITIZE; Base: 10 -*-
;;;; Input sanitization: HTML escape, attribute escape, URL guard.
;;;;
;;;; Standalone — depends only on iterate and cl-ppcre. The HTML escape
;;;; inlines the five-character substitution rather than calling
;;;; cl-who:escape-string, so this sub-system doesn't drag in cl-who.

(in-package :lol-web/sanitize)

(defun sanitize-html (string)
  "Escape HTML special characters (& < > \" ') to their entity equivalents.

   Example:
     (sanitize-html \"<script>alert('xss')</script>\")
     => \"&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;\""
  (when string
    (with-output-to-string (out)
      (iter (for char in-string string)
            (case char
              (#\& (write-string "&amp;" out))
              (#\< (write-string "&lt;" out))
              (#\> (write-string "&gt;" out))
              (#\" (write-string "&quot;" out))
              (#\' (write-string "&#39;" out))
              (t (write-char char out)))))))

(defun sanitize-attribute (string)
  "Escape string for use in HTML attributes. Same five-character set as
   sanitize-html — quote handling is the only thing that matters extra in
   attribute context, and these escapes cover both single- and double-quoted
   attribute values."
  (when string
    (with-output-to-string (out)
      (iter (for char in-string string)
            (case char
              (#\" (write-string "&quot;" out))
              (#\' (write-string "&#39;" out))
              (#\< (write-string "&lt;" out))
              (#\> (write-string "&gt;" out))
              (#\& (write-string "&amp;" out))
              (t (write-char char out)))))))

(defun sanitize-url (url)
  "Reject javascript:/data:/vbscript: schemes that can carry executable code.
   Returns NIL for unsafe URLs, the original URL otherwise.

   Example:
     (sanitize-url \"javascript:alert(1)\") => NIL
     (sanitize-url \"https://example.com\") => \"https://example.com\""
  (when url
    (let ((lower-url (string-downcase (string-trim '(#\Space #\Tab #\Newline) url))))
      (cond
        ((cl-ppcre:scan "^javascript:" lower-url) nil)
        ((cl-ppcre:scan "^data:" lower-url) nil)
        ((cl-ppcre:scan "^vbscript:" lower-url) nil)
        (t url)))))
