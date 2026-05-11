(in-package :lol-web/css/test)
(in-suite :lol-web/css/test)

;;; ============================================================================
;;; classes — composition with nil/empty filtering and list flattening
;;; ============================================================================

(test classes-filters-nil-and-empty
  "classes drops NIL and empty-string entries"
  (is (string= "p-4 bg-black"
               (classes "p-4" nil "" "bg-black" nil))))

(test classes-flattens-nested-lists
  "classes flattens nested lists for conditional composition"
  (is (string= "a b c"
               (classes (list "a" "b") "c"))))

(test classes-empty-input-yields-empty-string
  "classes with only nil/empty strings returns the empty string"
  (is (string= "" (classes nil "" nil))))

;;; ============================================================================
;;; tw- helpers
;;; ============================================================================

(test tw-color-prefix-and-key
  "tw-color formats prefix-key with the keyword downcased"
  (is (string= "bg-primary"   (tw-color "bg" :primary)))
  (is (string= "text-muted"   (tw-color "text" :muted)))
  (is (string= "border-error" (tw-color "border" :error))))

(test tw-spacing-numeric-keys
  "tw-spacing handles numeric keyword keys"
  (is (string= "p-4"  (tw-spacing "p" :4)))
  (is (string= "mx-8" (tw-spacing "mx" :8))))

(test tw-bg-text-border-shorthands
  "tw-bg / tw-text / tw-border are shorthands for tw-color"
  (is (string= "bg-primary"  (tw-bg :primary)))
  (is (string= "text-muted"  (tw-text :muted)))
  (is (string= "border-error" (tw-border :error))))

(test tw-arbitrary-strips-spaces
  "tw-arbitrary wraps a literal value in [] and removes spaces"
  (is (string= "w-[clamp(1rem,5vw,3rem)]"
               (tw-arbitrary "w" "clamp(1rem, 5vw, 3rem)"))))

(test tw-bg-value-resolves-token
  "tw-bg-value pulls the colour from *colors* and wraps in [...]"
  (let ((*colors* '((:probe . "#abcdef"))))
    (is (string= "bg-[#abcdef]" (tw-bg-value :probe)))))

;;; ============================================================================
;;; tailwind-config — alist iteration through Parenscript
;;; ============================================================================

(test tailwind-config-emits-color-pairs-from-alist
  "tailwind-config maps every alist colour into the generated JS"
  (let* ((colors    '((:primary . "#00FF41") (:secondary . "#FF006E")))
         (typography '((:family . "\"JetBrains Mono\", monospace")))
         (js (tailwind-config :colors colors :typography typography)))
    (is (stringp js))
    (is (search "tailwind.config" js))
    (is (search "#00FF41" js)
        "value from alist appears verbatim in generated JS")
    (is (search "#FF006E" js)
        "second alist value also appears")
    (is (search "JetBrains Mono" js)
        "font family from typography alist is interpolated")))

(test tailwind-config-errors-on-missing-family
  "tailwind-config requires the :family typography token"
  (signals error
    (tailwind-config :colors '((:primary . "#000"))
                     :typography '((:weight . "400")))))
