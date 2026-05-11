;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: LOL-WEB/HTMX; Base: 10 -*-
;;;; HTMX runtime — swap cluster
;;;;
;;;; DOM mutation strategies: 9 swap styles (innerHTML/outerHTML/before-/after-
;;;; begin/end/textContent/delete/none) and out-of-band (hx-swap-oob) processing.

(in-package :lol-web/htmx)

(defun htmx-runtime-swap-pairs ()
  "Property-value pairs for the *htmx* swap + processOobSwaps cluster."
  (list
   "swap" '(lambda (target html swap-style)
            (let ((style (or swap-style (ps:@ *htmx* config default-swap-style))))
              (cond
                ((= style "innerHTML")
                 (setf (ps:@ target inner-h-t-m-l) html))
                ((= style "outerHTML")
                 (setf (ps:@ target outer-h-t-m-l) html))
                ((= style "beforebegin")
                 (ps:chain target (insert-adjacent-h-t-m-l "beforebegin" html)))
                ((= style "afterbegin")
                 (ps:chain target (insert-adjacent-h-t-m-l "afterbegin" html)))
                ((= style "beforeend")
                 (ps:chain target (insert-adjacent-h-t-m-l "beforeend" html)))
                ((= style "afterend")
                 (ps:chain target (insert-adjacent-h-t-m-l "afterend" html)))
                ((= style "textContent")
                 (setf (ps:@ target text-content) html))
                ((= style "delete")
                 (ps:chain target (remove)))
                ((= style "none")
                 nil)
                (t
                 (setf (ps:@ target inner-h-t-m-l) html)))))

   "processOobSwaps" '(lambda (response-html)
                        (let ((temp (ps:chain document (create-element "div"))))
                          (setf (ps:@ temp inner-h-t-m-l) response-html)
                          (let ((oob-elements (ps:chain temp (query-selector-all "[hx-swap-oob]"))))
                            (ps:chain oob-elements (for-each
                                                    (lambda (el)
                                                      (let* ((oob-value (ps:chain el (get-attribute "hx-swap-oob")))
                                                             (target-id (ps:@ el id))
                                                             (target (ps:chain document (get-element-by-id target-id))))
                                                        (when target
                                                          (ps:chain el (remove-attribute "hx-swap-oob"))
                                                          (let ((strategy (if (or (= oob-value "true")
                                                                                  (= oob-value ""))
                                                                              "outerHTML"
                                                                              oob-value)))
                                                            ;; For outerHTML, preserve dynamic classes from target
                                                            (when (= strategy "outerHTML")
                                                              ;; Copy dynamic state classes (e.g., "open") to new element
                                                              (when (ps:chain target class-list (contains "open"))
                                                                (ps:chain el class-list (add "open"))))
                                                            ;; Perform the swap
                                                            (if (= strategy "outerHTML")
                                                                ((ps:@ *htmx* swap) target (ps:@ el outer-h-t-m-l) strategy)
                                                                ((ps:@ *htmx* swap) target (ps:@ el inner-h-t-m-l) strategy))
                                                            ;; Re-initialize HTMX on the new element
                                                            (let ((new-el (ps:chain document (get-element-by-id target-id))))
                                                              (when new-el
                                                                ;; Process the element itself
                                                                ((ps:@ *htmx* process-element) new-el)
                                                                ;; Process any children with hx-* attributes
                                                                (let ((htmx-children (ps:chain new-el
                                                                                       (query-selector-all
                                                                                        "[hx-get], [hx-post], [hx-put], [hx-delete]"))))
                                                                  (ps:chain htmx-children
                                                                            (for-each (ps:@ *htmx* process-element))))
                                                                ;; Dispatch htmx:load on new OOB content
                                                                ((ps:@ *htmx* dispatch-event) "htmx:load" new-el
                                                                 (ps:create :elt new-el))))))
                                                        (ps:chain el (remove)))))))
                          (ps:@ temp inner-h-t-m-l)))))
