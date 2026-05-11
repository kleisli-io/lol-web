;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: LOL-WEB/CORE; Base: 10 -*-
;;;; LOL-REACTIVE Collections - Reactive data structures
;;;;
;;;; Fine-grained reactive collections built on the signal infrastructure.

(in-package :lol-web/core)

;;; ============================================================================
;;; REACTIVE LIST - Fine-Grained Collection Updates
;;; ============================================================================

(defun make-reactive-list (initial-items)
  "Create a reactive list with fine-grained tracking.

   Returns a dlambda with messages:
     :items () - Get all items (reactive)
     :push (item) - Add to end
     :pop () - Remove from end
     :nth (index) - Get item at index (reactive)
     :set-nth (index value) - Set item at index
     :length () - Get length (reactive via signal)
     :map (fn) - Map function over items (reactive)
     :filter (pred) - Filter items (reactive)

   Example:
     (let ((todos (make-reactive-list '(\"Buy milk\" \"Learn Lisp\"))))
       (funcall todos :push \"Write code\")
       (funcall todos :items))  ; => (\"Buy milk\" \"Learn Lisp\" \"Write code\")"
  (let ((items (coerce initial-items 'vector))
        (subscribers (make-hash-table :test 'eq)))
    (flet ((notify ()
             (maphash (lambda (e v)
                        (declare (ignore v))
                        (when e (funcall e)))
                      subscribers)))
      (dlambda
        ;; Get all items (reactive)
        (:items ()
         (track-subscription subscribers)
         (coerce items 'list))

        ;; Push item to end
        (:push (item)
         (setf items (concatenate 'vector items (vector item)))
         (notify)
         item)

        ;; Pop from end
        (:pop ()
         (when (> (length items) 0)
           (let ((item (aref items (1- (length items)))))
             (setf items (subseq items 0 (1- (length items))))
             (notify)
             item)))

        ;; Get item at index (reactive)
        (:nth (idx)
         (track-subscription subscribers)
         (when (< idx (length items))
           (aref items idx)))

        ;; Set item at index
        (:set-nth (idx value)
         (when (< idx (length items))
           (setf (aref items idx) value)
           (notify)
           value))

        ;; Length
        (:length ()
         (track-subscription subscribers)
         (length items))

        ;; Map over items (reactive)
        (:map (fn)
         (track-subscription subscribers)
         (map 'list fn items))

        ;; Filter items (reactive)
        (:filter (pred)
         (track-subscription subscribers)
         (remove-if-not pred (coerce items 'list)))))))
