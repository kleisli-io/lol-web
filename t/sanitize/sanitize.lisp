(in-package :lol-web/sanitize/test)
(in-suite :lol-web/sanitize/test)

;;; ============================================================================
;;; sanitize-html
;;; ============================================================================

(test sanitize-html-escapes-five-special-chars
  "sanitize-html escapes the five HTML/XML metacharacters: & < > \" '"
  (is (string= "&lt;script&gt;alert(1)&lt;/script&gt;"
               (sanitize-html "<script>alert(1)</script>"))
      "tag delimiters become &lt; / &gt;")
  (is (string= "Tom &amp; Jerry" (sanitize-html "Tom & Jerry"))
      "& becomes &amp;")
  (is (string= "&quot;hi&quot;" (sanitize-html "\"hi\""))
      "double-quote becomes &quot;")
  (is (string= "&#39;hi&#39;" (sanitize-html "'hi'"))
      "single-quote becomes &#39;"))

(test sanitize-html-noop-on-safe-input
  "sanitize-html leaves text without metacharacters unchanged"
  (is (string= "hello world" (sanitize-html "hello world")))
  (is (string= "" (sanitize-html ""))))

(test sanitize-html-nil-passthrough
  "sanitize-html returns NIL for NIL input (not an error)"
  (is (null (sanitize-html nil))))

;;; ============================================================================
;;; sanitize-url
;;; ============================================================================

(test sanitize-url-allows-safe-schemes
  "http, https, mailto, relative paths, and fragment-only URLs pass through"
  (is (string= "https://example.com/path?q=1"
               (sanitize-url "https://example.com/path?q=1")))
  (is (string= "/relative/path" (sanitize-url "/relative/path")))
  (is (string= "#anchor"        (sanitize-url "#anchor")))
  (is (string= "mailto:a@b"     (sanitize-url "mailto:a@b"))))

(test sanitize-url-blocks-script-bearing-schemes
  "javascript:, data:, vbscript: URLs return NIL so the caller can omit the link"
  (is (null (sanitize-url "javascript:alert(1)")))
  (is (null (sanitize-url "JaVaScRiPt:alert(1)"))
      "scheme detection must be case-insensitive")
  (is (null (sanitize-url "data:text/html,<script>")))
  (is (null (sanitize-url "vbscript:msgbox 1"))))

(test sanitize-url-nil-passthrough
  "sanitize-url returns NIL for NIL input"
  (is (null (sanitize-url nil))))

;;; ============================================================================
;;; sanitize-attribute
;;; ============================================================================

(test sanitize-attribute-escapes-quote-pair
  "sanitize-attribute escapes both quote characters so attribute boundaries hold"
  (let ((out (sanitize-attribute "a\"b'c")))
    (is (search "&quot;" out)
        "double-quote becomes &quot;")
    (is (search "&#39;" out)
        "single-quote becomes &#39;")
    (is (null (search "\"" out))
        "no raw double-quote remains")
    (is (null (find #\' out))
        "no raw single-quote remains")))
