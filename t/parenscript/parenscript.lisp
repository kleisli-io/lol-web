(in-package :lol-web/parenscript/test)
(in-suite :lol-web/parenscript/test)

;;; ============================================================================
;;; js-value — internal helper, accessed via package qualifier
;;; ============================================================================

(test js-value-nil
  "js-value converts nil to null"
  (is (string= "null" (lol-web/parenscript::js-value nil))))

(test js-value-numbers
  "js-value handles integers and floats"
  (is (string= "42"  (lol-web/parenscript::js-value 42)))
  (is (string= "0"   (lol-web/parenscript::js-value 0)))
  (is (string= "-10" (lol-web/parenscript::js-value -10))))

(test js-value-strings
  "js-value wraps strings in quotes"
  (let ((result (lol-web/parenscript::js-value "hello")))
    (is (stringp result))
    (is (> (length result) (length "hello")))
    (is (search "hello" result))))

(test js-value-symbols
  "js-value converts symbols to lowercase strings"
  (let ((result (lol-web/parenscript::js-value 'my-symbol)))
    (is (stringp result))
    (is (search "my-symbol" result :test #'char-equal))))

;;; ============================================================================
;;; Event-handler JS generation
;;; ============================================================================

(test on-click-generates-js
  "on-click generates dispatch JavaScript"
  (let ((result (on-click "test-comp" '(alert "clicked"))))
    (is (stringp result))
    (is (search "dispatch" result :test #'char-equal))))

(test on-change-generates-js
  "on-change generates setState JavaScript"
  (let ((result (on-change "test-comp" 'value)))
    (is (stringp result))
    (is (search "setState" result :test #'char-equal))))

