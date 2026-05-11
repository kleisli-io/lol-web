;;;; Regression tests for html-page's pre-computed string parameters.
;;;;
;;;; html-page used to call tailwind-config / generate-css-variables /
;;;; generate-all-component-css / htmx-indicator-css / htmx-runtime-js /
;;;; surgery-css / surgery-runtime-js / get-csrf-token directly — pulling
;;;; css-tokens, htmx, surgery, and CSRF machinery into :lol-web/html as
;;;; hard dependencies. Each generator now has a string parameter; the
;;;; helper is the lazy default via (or PARAM (HELPER)). Callers can
;;;; pre-compute once and thread strings on each request, decoupling
;;;; html-page from those subsystems.

(in-package :lol-web/html/test)
(in-suite :lol-web/html/test)

(test regression-html-page-accepts-precomputed-strings
  "html-page emits caller-provided strings verbatim, bypassing internal generators"
  (let ((html (html-page
                :title "Probe"
                :base-css "/* CUSTOM-BASE-CSS */"
                :component-css "/* CUSTOM-COMPONENT-CSS */"
                :csrf-token "CUSTOM-CSRF-TOKEN"
                :reactive-runtime "/* CUSTOM-REACTIVE-RUNTIME */"
                :htmx-runtime "/* CUSTOM-HTMX-RUNTIME */"
                :tailwind-script "/* CUSTOM-TAILWIND-SCRIPT */"
                :htmx-indicator-css "/* CUSTOM-HTMX-INDICATOR-CSS */")))
    (is (search "CUSTOM-BASE-CSS" html)
        "BASE-CSS override missing from page")
    (is (search "CUSTOM-COMPONENT-CSS" html)
        "COMPONENT-CSS override missing")
    (is (search "CUSTOM-CSRF-TOKEN" html)
        "CSRF-TOKEN override missing — page generator still calls get-csrf-token")
    (is (search "CUSTOM-REACTIVE-RUNTIME" html)
        "REACTIVE-RUNTIME override missing")
    (is (search "CUSTOM-HTMX-RUNTIME" html)
        "HTMX-RUNTIME override missing")
    (is (search "CUSTOM-TAILWIND-SCRIPT" html)
        "TAILWIND-SCRIPT override missing")
    (is (search "CUSTOM-HTMX-INDICATOR-CSS" html)
        "HTMX-INDICATOR-CSS override missing")))

(test regression-html-page-include-htmx-nil-suppresses
  "INCLUDE-HTMX NIL suppresses HTMX assets even when overrides are provided"
  (let ((html (html-page
                :title "NoHtmx"
                :include-htmx nil
                :htmx-runtime "/* CUSTOM-HTMX-RUNTIME */"
                :htmx-indicator-css "/* CUSTOM-HTMX-INDICATOR-CSS */"
                :csrf-token "CUSTOM-CSRF-TOKEN")))
    (is (null (search "CUSTOM-HTMX-RUNTIME" html))
        "INCLUDE-HTMX NIL must suppress HTMX runtime even with explicit override")
    (is (null (search "CUSTOM-HTMX-INDICATOR-CSS" html))
        "INCLUDE-HTMX NIL must suppress HTMX indicator CSS")
    (is (null (search "CUSTOM-CSRF-TOKEN" html))
        "INCLUDE-HTMX NIL must suppress the CSRF meta tag")))

;;; ============================================================================
;;; highlight-sexp — content escape
;;; ============================================================================

(test regression-highlight-sexp-escapes-html-in-string-content
  "A form whose string slot contains <script> must not round-trip through
   highlight-sexp as raw HTML. With escape-html running first, < and > are
   inert entities and the rendered span body cannot inject markup."
  (let ((out (highlight-sexp '("<script>alert(1)</script>"))))
    (is (null (search "<script>" out))
        "raw <script> tag must not appear in output")
    (is (search "&lt;script&gt;" out)
        "tag chars must be HTML-escaped to &lt;/&gt;")
    (is (search "alert(" out)
        "string content itself is preserved (digits get wrapped in number spans)")))

(test regression-highlight-sexp-escapes-ampersand
  "Bare `&` in a string is escaped to `&amp;` before regex passes run, so
   no unintentional entity-like sequences leak through."
  (let ((out (highlight-sexp '("a&b"))))
    (is (search "a&amp;b" out))
    (is (null (search "a&b" out)))))

(test regression-highlight-sexp-still-tags-keywords-and-numbers
  "Keyword and number highlighting still works after the escape pass."
  (let ((out (highlight-sexp '(:k 42))))
    (is (search "<span class=\"sexp-keyword\">:K</span>" out))
    (is (search "<span class=\"sexp-number\">42</span>" out))))
