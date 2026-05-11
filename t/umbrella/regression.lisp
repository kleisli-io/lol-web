;;;; Umbrella regression tests — shim parity with :lol-web.
;;;;
;;;; The :lol-reactive shim's contract: every external symbol of :lol-web
;;;; is also external in :lol-reactive, and resolves to the same symbol
;;;; object. The tests enumerate externals at runtime so they track
;;;; whichever umbrella surface is loaded.

(in-package :lol-web/test)
(in-suite :lol-web/test)

(test regression-shim-external-symbol-parity-with-umbrella
  "Every external symbol of :lol-web is also external in :lol-reactive,
   and refers to the same symbol object."
  (let ((umbrella-pkg (find-package :lol-web))
        (shim-pkg     (find-package :lol-reactive)))
    (is (not (null umbrella-pkg)) ":lol-web package exists")
    (is (not (null shim-pkg))     ":lol-reactive shim package exists")
    (let ((missing-from-shim '())
          (mismatched-symbol '())
          (not-external      '()))
      (do-external-symbols (sym umbrella-pkg)
        (multiple-value-bind (shim-sym status)
            (find-symbol (symbol-name sym) shim-pkg)
          (cond
            ((null status)            (push sym missing-from-shim))
            ((not (eq shim-sym sym))  (push sym mismatched-symbol))
            ((not (eq status :external)) (push sym not-external)))))
      (is (null missing-from-shim)
          "shim is missing ~D symbols: ~{~A~^, ~}"
          (length missing-from-shim) missing-from-shim)
      (is (null mismatched-symbol)
          "shim aliases ~D symbols to a different home: ~{~A~^, ~}"
          (length mismatched-symbol) mismatched-symbol)
      (is (null not-external)
          "shim has ~D symbols present but not external: ~{~A~^, ~}"
          (length not-external) not-external))))

(test regression-shim-external-symbol-count-matches-umbrella
  "Counting external symbols of the shim and the umbrella confirms the shim
   doesn't accidentally export anything beyond the umbrella's surface."
  (let ((umbrella-count 0)
        (shim-count     0))
    (do-external-symbols (s :lol-web) (declare (ignore s)) (incf umbrella-count))
    (do-external-symbols (s :lol-reactive) (declare (ignore s)) (incf shim-count))
    (is (= umbrella-count shim-count)
        "shim external count (~D) matches umbrella external count (~D)"
        shim-count umbrella-count)))

(test regression-umbrella-facades-every-sub-system
  "Every external symbol of every :lol-web/<n> sub-system is also external
   in the umbrella :lol-web (resolving to the same symbol object). Catches
   the drift where a new sub-system ships without an umbrella refresh —
   the failure mode that left :lol-web/extractors, :lol-web/jschema, and
   :lol-web/openapi unfacaded across Phases 7.2 / 7.5(b)' / 7.5(b)."
  (let ((sub-systems '(:lol-web/sanitize :lol-web/core :lol-web/css
                       :lol-web/html :lol-web/parenscript
                       :lol-web/server :lol-web/extractors :lol-web/jschema
                       :lol-web/openapi :lol-web/htmx :lol-web/realtime
                       :lol-web/realtime-htmx :lol-web/wizards
                       :lol-web/devtools :lol-web/fullstack
                       :lol-web/optimization :lol-web/forms
                       :lol-web/rendering :lol-web/resources
                       :lol-web/client-runtime))
        (umbrella-pkg (find-package :lol-web))
        (missing-by-sub (make-hash-table :test 'eq)))
    (is (not (null umbrella-pkg)) ":lol-web umbrella package exists")
    (dolist (sub sub-systems)
      (let ((sub-pkg (find-package sub)))
        (is (not (null sub-pkg)) "sub-system ~A is loaded" sub)
        (when sub-pkg
          (let ((missing '()))
            (do-external-symbols (sym sub-pkg)
              (multiple-value-bind (umbrella-sym status)
                  (find-symbol (symbol-name sym) umbrella-pkg)
                (cond
                  ((null status)               (push sym missing))
                  ((not (eq umbrella-sym sym)) (push sym missing))
                  ((not (eq status :external)) (push sym missing)))))
            (when missing
              (setf (gethash sub missing-by-sub) (nreverse missing)))))))
    (is (zerop (hash-table-count missing-by-sub))
        "umbrella :lol-web is missing exports from sub-systems:~%~{  ~A: ~A~%~}"
        (loop for k being the hash-keys of missing-by-sub
              for v = (gethash k missing-by-sub)
              collect k collect v))))
