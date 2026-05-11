;;;; Regression tests for js-value (src/client/parenscript.lisp).
;;;;
;;;; NIL is both null and symbol in CL, so the typecase that produces JS
;;;; literals must dispatch on null before symbol — otherwise NIL stringifies
;;;; to "nil" instead of "null", and downstream JSON.parse / setState calls
;;;; explode at runtime.

(in-package :lol-web/parenscript/test)
(in-suite :lol-web/parenscript/test)

(test regression-js-value-nil-is-null
  "js-value converts nil to 'null', not 'nil'"
  (is (string= "null" (lol-web/parenscript::js-value nil))))

(test regression-js-value-symbol
  "js-value still works correctly for non-nil symbols"
  (let ((result (lol-web/parenscript::js-value 'foo)))
    (is (stringp result))
    (is (search "foo" result :test #'char-equal))))

(test regression-js-value-numbers
  "js-value handles numbers correctly"
  (is (string= "42"   (lol-web/parenscript::js-value 42)))
  (is (string= "3.14" (lol-web/parenscript::js-value 3.14))))

(test regression-js-value-strings
  "js-value wraps strings in quotes"
  (let ((result (lol-web/parenscript::js-value "hello")))
    (is (char= #\' (char result 0)))
    (is (search "hello" result))))

(test regression-generate-ws-client-derives-protocol
  "generate-ws-client uses window.location.protocol so https pages get wss://"
  (let ((js (lol-web/parenscript::generate-ws-client "abc")))
    (is (stringp js))
    (is (search "window.location.protocol" js)
        "missing protocol switch — hardcoded ws:// breaks https pages")
    (is (search "'wss://'" js) "missing wss:// branch")
    (is (search "'ws://'"  js) "missing ws:// branch")))

(test regression-component-client-script-on-mount-call
  "component-client-script accesses on-mount with string key and invokes it"
  (let ((js (lol-web/parenscript::component-client-script "abc")))
    (is (stringp js))
    (is (search "['on-mount']()" js)
        "on-mount must be accessed as ['on-mount'] and invoked with ()")
    (is (null (search ".at('on-mount')" js))
        ".at('on-mount') is the broken (ps:chain ... (ps:@ :on-mount)) form")))
