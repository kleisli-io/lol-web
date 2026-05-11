(in-package :lol-web/css/test)
(in-suite :lol-web/css/test)

;;; ============================================================================
;;; Token accessors
;;; ============================================================================

(test get-color-returns-default-palette-entry
  "get-color reads from *colors*"
  (is (string= (cdr (assoc :primary *default-colors*))
               (get-color :primary))
      "default :primary value matches *default-colors*"))

(test get-font-typography-keys
  "get-font reads from *typography*"
  (is (string= (cdr (assoc :family *default-typography*))
               (get-font :family))))

(test get-spacing-numeric-keys
  "get-spacing accepts the numeric keyword keys :0 :4 :8 ..."
  (is (string= (cdr (assoc :4 *default-spacing*))
               (get-spacing :4))))

(test get-effect-shadow
  "get-effect reads from *effects*"
  (is (string= (cdr (assoc :shadow-md *default-effects*))
               (get-effect :shadow-md))))

;;; ============================================================================
;;; Validation: keyword shape + Levenshtein "did you mean?"
;;; ============================================================================

(test validate-token-rejects-non-keyword
  "validate-token rejects non-keyword tokens with a type-shaped error"
  (signals error (validate-token "primary" *colors* "color")))

(test validate-token-rejects-unknown-and-suggests
  "Unknown token errors with a suggestion derived from Levenshtein distance"
  (handler-case
      (progn (validate-token :primry *colors* "color")
             (is nil "expected an error for an unknown token"))
    (error (c)
      (let ((msg (princ-to-string c)))
        ;; Symbols print upcased via ~A; do a case-insensitive search.
        (is (search "primry" msg :test #'char-equal)
            "error message includes the bad token")
        (is (search "primary" msg :test #'char-equal)
            "error message suggests :primary as the closest match")))))

(test validate-token-accepts-known-key
  "validate-token returns the token for a known key"
  (is (eq :primary (validate-token :primary *colors* "color"))))

;;; ============================================================================
;;; Levenshtein distance
;;; ============================================================================

(test levenshtein-distance-known-cases
  "levenshtein-distance returns the standard edit-distance values"
  (is (= 0 (levenshtein-distance "kitten" "kitten")))
  (is (= 3 (levenshtein-distance "kitten" "sitting")))
  (is (= 1 (levenshtein-distance "abc" "abcd")))
  (is (= 1 (levenshtein-distance "abcd" "abc"))))

;;; ============================================================================
;;; CSS variable generation iterates the alists directly
;;; ============================================================================

(test generate-css-variables-emits-root-block
  "generate-css-variables emits a :root block with variables for every alist key"
  (let* ((colors    '((:bg . "#000") (:fg . "#fff")))
         (typography '((:family . "monospace")))
         (spacing   '((:4 . "1rem")))
         (effects   '((:shadow-md . "0 0 4px rgba(0,0,0,0.1)")))
         (css (generate-css-variables :colors colors
                                      :typography typography
                                      :spacing spacing
                                      :effects effects)))
    (is (search ":root {" css))
    (is (search "--color-bg: #000" css))
    (is (search "--color-fg: #fff" css))
    (is (search "--font-family: monospace" css))
    (is (search "--space-4: 1rem" css))
    (is (search "--effect-shadow-md: 0 0 4px rgba(0,0,0,0.1)" css))))

(test generate-css-variables-uses-dynamic-defaults
  "Calling without keyword args reads the dynamic *colors* / *typography* etc."
  (let* ((*colors*     '((:probe-bg . "#123456")))
         (*typography* '((:family . "probe-font")))
         (*spacing*    '((:probe-4 . "0.4rem")))
         (*effects*    '((:probe-effect . "probe-value")))
         (css (generate-css-variables)))
    (is (search "--color-probe-bg: #123456" css))
    (is (search "--font-family: probe-font" css))
    (is (search "--space-probe-4: 0.4rem" css))
    (is (search "--effect-probe-effect: probe-value" css))))
