;;;; Regression tests for :lol-web/htmx.
;;;;
;;;; Covers: oob-swap duplicate-id avoidance, find-tag-end quote awareness,
;;;; inject-oob-attribute self-closing handling, content-starts-with-id-p
;;;; quote awareness, and the htmx-runtime-js cluster composition contract
;;;; (every behavioural marker from each runtime/* sub-cluster must appear
;;;; in the composed output, and each cluster helper must return an even-
;;;; length list of (string-key, value) pairs).

(in-package :lol-web/htmx/test)
(in-suite :lol-web/htmx/test)

;;; ============================================================================
;;; oob-swap — duplicate ID avoidance
;;; ============================================================================

(test regression-oob-swap-no-duplicate-id
  "oob-swap with outerHTML doesn't wrap when content has target ID"
  (let ((html "<div id=\"target\">content</div>"))
    (let ((result (oob-swap "target" html :swap "outerHTML")))
      (is (null (search "<div id=\"target\"><div id=\"target\"" result)))
      (is (search "hx-swap-oob" result)))))

(test regression-oob-swap-wrap-when-no-id
  "oob-swap still wraps when content lacks target ID"
  (let ((html "<span>some content</span>"))
    (let ((result (oob-swap "my-target" html :swap "innerHTML")))
      (is (search "id=\"my-target\"" result))
      (is (search "hx-swap-oob" result)))))

(test regression-oob-swap-innerhtml-always-wraps
  "oob-swap innerHTML strategy always wraps"
  (let ((html "<div id=\"target\">content</div>"))
    (let ((result (oob-swap "target" html :swap "innerHTML")))
      (is (search "hx-swap-oob" result)))))

;;; ============================================================================
;;; find-tag-end — quoted > handling
;;; ============================================================================

(test regression-find-tag-end-simple
  "find-tag-end works with simple tags"
  (is (= 4 (lol-web/htmx::find-tag-end "<div>")))
  (is (= 17 (lol-web/htmx::find-tag-end "<div class=\"test\">x"))))

(test regression-find-tag-end-quoted-gt
  "find-tag-end handles > inside quoted attributes"
  (let ((html "<input value=\"a > b\" />"))
    (is (= 22 (lol-web/htmx::find-tag-end html)))))

(test regression-find-tag-end-multiple-quoted-gt
  "find-tag-end handles multiple > in quotes"
  (let ((html "<div title=\"x > y > z\" class=\"a > b\">content"))
    (let ((pos (lol-web/htmx::find-tag-end html)))
      (is (numberp pos))
      (is (char= #\> (char html pos))))))

(test regression-find-tag-end-self-closing
  "find-tag-end works with self-closing tags"
  (is (= 4 (lol-web/htmx::find-tag-end "<br/>")))
  (is (= 5 (lol-web/htmx::find-tag-end "<br />")))
  (is (= 30 (lol-web/htmx::find-tag-end "<input type=\"text\" value=\">\" />"))))

;;; ============================================================================
;;; inject-oob-attribute — self-closing tag boundary
;;; ============================================================================

(test regression-inject-oob-self-closing
  "inject-oob-attribute correctly handles self-closing tags"
  (let ((html "<input type=\"text\" />"))
    (let ((result (lol-web/htmx::inject-oob-attribute html "outerHTML")))
      (is (search "hx-swap-oob=\"outerHTML\"" result))
      (is (search "/>" result)))))

(test regression-inject-oob-regular-tag
  "inject-oob-attribute works with regular tags"
  (let ((html "<div class=\"test\">content</div>"))
    (let ((result (lol-web/htmx::inject-oob-attribute html "true")))
      (is (search "hx-swap-oob=\"true\"" result)))))

;;; ============================================================================
;;; content-starts-with-id-p — quote awareness
;;; ============================================================================

(test regression-content-starts-with-id-basic
  "content-starts-with-id-p detects ID in simple element"
  (is (lol-web/htmx::content-starts-with-id-p
        "<div id=\"target\">content</div>" "target"))
  (is (not (lol-web/htmx::content-starts-with-id-p
             "<div id=\"other\">content</div>" "target"))))

(test regression-content-starts-with-id-quoted-gt
  "content-starts-with-id-p handles > in quoted attributes"
  (is (lol-web/htmx::content-starts-with-id-p
        "<div title=\"x > y\" id=\"target\">content</div>" "target"))
  (is (not (lol-web/htmx::content-starts-with-id-p
             "<div title=\"id=target\">content</div>" "target"))))

;;; ============================================================================
;;; HTMX runtime composition — every cluster's marker must survive ps:ps* splice
;;; ============================================================================

(test regression-htmx-runtime-composition-markers
  "Composed htmx-runtime-js contains every behavioural marker from each cluster"
  (let ((js (htmx-runtime-js)))
    ;; Config cluster
    (is (search "HTMX" js) "HTMX object name missing")
    (is (search "0.3.1" js) "version string missing")
    (is (search "defaultSwapStyle" js) "config.defaultSwapStyle missing")
    (is (search "abortControllers" js) "AbortController storage missing")
    (is (search "observers" js) "IntersectionObserver storage missing")
    ;; Swap cluster
    (is (search "innerHTML" js) "swap innerHTML strategy missing")
    (is (search "outerHTML" js) "swap outerHTML strategy missing")
    (is (search "beforebegin" js) "swap beforebegin strategy missing")
    (is (search "afterbegin" js) "swap afterbegin strategy missing")
    (is (search "beforeend" js) "swap beforeend strategy missing")
    (is (search "afterend" js) "swap afterend strategy missing")
    (is (search "textContent" js) "swap textContent strategy missing")
    (is (search "hx-swap-oob" js) "OOB swap selector missing")
    ;; AJAX cluster
    (is (search "issueRequest" js) "issueRequest method missing")
    (is (search "AbortController" js) "AbortController constructor reference missing")
    (is (search "FormData" js) "FormData reference missing")
    (is (search "URLSearchParams" js) "URLSearchParams reference missing")
    (is (search "csrf-token" js) "CSRF token meta selector missing")
    (is (search "htmx:beforeRequest" js) "htmx:beforeRequest event missing")
    (is (search "htmx:configRequest" js) "htmx:configRequest event missing")
    (is (search "htmx:beforeSwap" js) "htmx:beforeSwap event missing")
    (is (search "htmx:afterSwap" js) "htmx:afterSwap event missing")
    (is (search "htmx:afterSettle" js) "htmx:afterSettle event missing")
    (is (search "htmx:afterRequest" js) "htmx:afterRequest event missing")
    (is (search "htmx:responseError" js) "htmx:responseError event missing")
    (is (search "htmx:sendError" js) "htmx:sendError event missing")
    ;; Triggers cluster
    (is (search "parseTrigger" js) "parseTrigger missing")
    (is (search "parseInterval" js) "parseInterval missing")
    (is (search "addTriggerHandler" js) "addTriggerHandler missing")
    (is (search "processElement" js) "processElement missing")
    (is (search "processHxOn" js) "processHxOn missing")
    (is (search "IntersectionObserver" js) "IntersectionObserver constructor missing")
    (is (search "MutationObserver" js) "MutationObserver constructor missing")
    (is (search "setupAutocomplete" js) "setupAutocomplete missing")
    (is (search "highlightOption" js) "highlightOption missing")
    (is (search "clearHighlights" js) "clearHighlights missing")
    (is (search "ArrowDown" js) "ArrowDown navigation missing")
    (is (search "ArrowUp" js) "ArrowUp navigation missing")
    (is (search "Escape" js) "Escape keypress missing")
    ;; Public API cluster
    (is (search "process" js) "htmx.process API missing")
    (is (search "ajax" js) "htmx.ajax API missing")
    (is (search "trigger" js) "htmx.trigger API missing")
    (is (search "onLoad" js) "htmx.onLoad API missing")
    (is (search "init" js) "init method missing")
    ;; Boot cluster
    (is (search "DOMContentLoaded" js) "DOMContentLoaded boot listener missing")
    (is (search "window.htmx" js) "window.htmx alias missing")))

(test regression-htmx-runtime-cluster-helpers-return-pairs
  "Each runtime/* helper returns a flat list with even length and string keys"
  (dolist (helper '(lol-web/htmx::htmx-runtime-config-pairs
                    lol-web/htmx::htmx-runtime-swap-pairs
                    lol-web/htmx::htmx-runtime-ajax-pairs
                    lol-web/htmx::htmx-runtime-triggers-pairs
                    lol-web/htmx::htmx-runtime-public-api-pairs))
    (let ((pairs (funcall helper)))
      (is (listp pairs)
          "~A did not return a list" helper)
      (is (evenp (length pairs))
          "~A returned ~D entries — must be even (key/value pairs)"
          helper (length pairs))
      (loop for (k v) on pairs by #'cddr
            do (is (stringp k)
                   "~A produced non-string key ~S" helper k)))))

;;; ============================================================================
;;; htmx-indicator-css — keyword-as-property bug
;;; ============================================================================

(test regression-htmx-indicator-css-lowercase-properties
  "htmx-indicator-css produces lowercase CSS property names. (css-rules
   formats keys via ~A; keyword keys came out uppercase as 'OPACITY: 0.7'
   which browsers don't recognise. Property keys must now be strings.)"
  (let ((css (htmx-indicator-css)))
    (is (search "opacity:" css)
        "must contain lowercase 'opacity:' property")
    (is (search "cursor:" css)
        "must contain lowercase 'cursor:' property")
    (is (search "display:" css)
        "must contain lowercase 'display:' property")
    (is (null (search "OPACITY:" css))
        "must NOT contain uppercase 'OPACITY:' (regression: keyword formatting)")
    (is (null (search "CURSOR:" css))
        "must NOT contain uppercase 'CURSOR:'")
    (is (null (search "DISPLAY:" css))
        "must NOT contain uppercase 'DISPLAY:'")))

;;; ============================================================================
;;; with-htmx-response — runtime stringp on TRIGGER
;;; ============================================================================

(defun %find-header (name plist)
  "Walk *response-headers* plist by 2; return the value for the (case-
   insensitive) header NAME, or NIL. add-response-header downcases the
   header key on insertion."
  (loop for (k v) on plist by #'cddr
        when (string-equal k name)
        return v))

(test regression-with-htmx-response-trigger-string-literal
  "Literal string TRIGGER lands in HX-Trigger header verbatim — no JSON wrap."
  (lol-web/server:with-response-headers ()
    (with-htmx-response (:trigger "cartUpdated")
      "<p>x</p>")
    (is (equal "cartUpdated"
               (%find-header "hx-trigger" (lol-web/server:get-response-headers)))
        "string literal must pass through unencoded")))

(test regression-with-htmx-response-trigger-runtime-stringp
  "Variable holding a string at runtime must NOT be double-JSON-encoded.
   Regression: previous (if (stringp trigger) ...) ran at macroexpansion
   on the symbol form, taking the encode-json-string branch and emitting
   '\"cartUpdated\"' (with embedded quotes) instead of 'cartUpdated'."
  (let ((evt "cartUpdated"))
    (lol-web/server:with-response-headers ()
      (with-htmx-response (:trigger evt)
        "<p>x</p>")
      (is (equal "cartUpdated"
                 (%find-header "hx-trigger"
                               (lol-web/server:get-response-headers)))
          "runtime string must not be JSON-encoded a second time"))))

(test regression-with-htmx-response-trigger-non-string-encodes
  "Non-string TRIGGER (alist for HX-Trigger detail map) JSON-encodes at runtime."
  (lol-web/server:with-response-headers ()
    (with-htmx-response (:trigger '(("cartUpdated" . ((item . "x")))))
      "<p>x</p>")
    (let ((val (%find-header "hx-trigger"
                             (lol-web/server:get-response-headers))))
      (is (stringp val) "header value must be a string")
      (is (search "cartUpdated" val)
          "encoded JSON must include the event name")
      (is (search "{" val)
          "encoded JSON for an alist must include object braces"))))

;;; ============================================================================
;;; hx-get/post/put/delete URL sanitization
;;; ============================================================================

(test regression-hx-get-rejects-javascript-scheme
  "javascript: URLs produce no hx-get attribute. sanitize-url returns NIL
   for the unsafe scheme; the format string then suppresses the entire
   hx-get pair so the payload cannot reach the rendered HTML."
  (let ((s (hx-get "javascript:alert(1)")))
    (is (null (search "javascript:" s)))
    (is (null (search "hx-get" s))
        "without a safe URL the hx-get attr must be suppressed")))

(test regression-hx-get-rejects-data-and-vbscript-schemes
  "data: and vbscript: are equally dangerous and equally rejected."
  (is (null (search "data:" (hx-get "data:text/html,<script>alert(1)</script>"))))
  (is (null (search "vbscript:" (hx-get "vbscript:msgbox(1)")))))

(test regression-hx-get-allows-safe-urls
  "https://, root-relative paths, and query strings all pass through."
  (is (search "hx-get=\"https://example.com\"" (hx-get "https://example.com")))
  (is (search "hx-get=\"/api/users\"" (hx-get "/api/users")))
  (is (search "hx-get=\"/search?q=lol\"" (hx-get "/search?q=lol"))))

(test regression-hx-get-escapes-quote-in-url
  "A literal `\"` inside a safe-scheme URL is HTML-attribute-escaped so it
   cannot close the surrounding `\"...\"` and inject sibling attributes."
  (let ((s (hx-get "/search?q=evil\"onclick=alert(1)")))
    (is (null (search "evil\"onclick" s)))
    (is (search "&quot;onclick=alert(1)" s))))

(test regression-hx-post-put-delete-also-sanitize
  "All four hx-* helpers share the sanitization path."
  (is (null (search "javascript:" (hx-post "javascript:x"))))
  (is (null (search "javascript:" (hx-put "javascript:x"))))
  (is (null (search "javascript:" (hx-delete "javascript:x")))))

(test regression-hx-get-target-trigger-attribute-escaped
  "A `\"` in target or trigger is escaped so caller-controlled values
   cannot break out of the attribute."
  (let ((s (hx-get "/api/x"
                   :target "evil\" onerror=alert(1)"
                   :trigger "click consume")))
    (is (null (search "evil\" onerror" s)))
    (is (search "&quot; onerror=alert(1)" s))
    (is (search "hx-trigger=\"click consume\"" s))))

