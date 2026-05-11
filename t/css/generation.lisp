(in-package :lol-web/css/test)
(in-suite :lol-web/css/test)

;;; ============================================================================
;;; css-rule — symbol/keyword keys downcase to lowercase property names
;;; ============================================================================

(test regression-css-rule-keyword-keys-downcase
  "Keyword keys produce lowercase CSS property names. Unguarded `~A`
   formats `:opacity` as `OPACITY`, which browsers silently ignore."
  (let ((rule (css-rule ".x" '((:opacity . "0.7")
                               (:transition . "opacity 0.2s")))))
    (is (search "opacity: 0.7" rule)
        "keyword :opacity must render as `opacity`, not `OPACITY`")
    (is (search "transition: opacity 0.2s" rule)
        "keyword :transition must render as `transition`")
    (is (not (search "OPACITY" rule))
        "no uppercase property name should appear")))

(test regression-css-rule-symbol-keys-downcase
  "Non-keyword symbol keys also downcase. Reader uppercases symbol names
   by default, so unguarded `~A` would emit uppercase property names for
   any symbol key, not just keywords."
  (let ((rule (css-rule ".y" `((,(intern "MARGIN") . "1rem")))))
    (is (search "margin: 1rem" rule))
    (is (not (search "MARGIN: " rule)))))

(test regression-css-rule-string-keys-passthrough
  "String keys are passed through unchanged — including mixed-case
   strings, which must not be downcased."
  (let ((rule (css-rule ".z" '(("padding" . "0.5rem")
                               ("Border-Radius" . "4px")))))
    (is (search "padding: 0.5rem" rule))
    (is (search "Border-Radius: 4px" rule)
        "mixed-case string keys are preserved verbatim")))

(test regression-css-rule-mixed-keys
  "An alist mixing string, symbol, and keyword keys renders all of them
   correctly in a single rule."
  (let ((rule (css-rule ".mix" `(("padding" . "1rem")
                                 (:margin . "0")
                                 (,(intern "COLOR") . "black")))))
    (is (search "padding: 1rem" rule))
    (is (search "margin: 0" rule))
    (is (search "color: black" rule))))

;;; ============================================================================
;;; css-rules — alternating-pair convenience wrapper
;;; ============================================================================

(test regression-css-rules-keyword-keys-downcase
  "css-rules builds an alist from alternating pairs and delegates to
   css-rule, so the keyword-key normalisation applies transparently."
  (let ((rule (css-rules ".indicator" :opacity "0.7" :display "none")))
    (is (search "opacity: 0.7" rule))
    (is (search "display: none" rule))
    (is (not (search "OPACITY" rule)))
    (is (not (search "DISPLAY" rule)))))

;;; ============================================================================
;;; css-keyframes — composes css-rule
;;; ============================================================================

(test regression-css-keyframes-keyword-keys-downcase
  "css-keyframes renders each frame via css-rule, so keyword keys inside
   a frame's property alist are downcased the same way."
  (let ((kf (css-keyframes "fade"
              '("0%"   . ((:opacity . "0")))
              '("100%" . ((:opacity . "1"))))))
    (is (search "0% { opacity: 0;" kf))
    (is (search "100% { opacity: 1;" kf))
    (is (not (search "OPACITY" kf)))))

(test regression-css-keyframes-shape
  "css-keyframes emits a complete @keyframes block with each frame's
   selector wrapped in braces."
  (let ((kf (css-keyframes "spin"
              '("from" . (("transform" . "rotate(0deg)")))
              '("to"   . (("transform" . "rotate(360deg)"))))))
    (is (search "@keyframes spin {" kf))
    (is (search "from { transform: rotate(0deg); }" kf))
    (is (search "to { transform: rotate(360deg); }" kf))))
