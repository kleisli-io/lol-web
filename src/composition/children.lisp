;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: LOL-WEB/CORE; Base: 10 -*-
;;;; Children and Slots System
;;;; Enables React-style children passing and Vue-style named slots

(in-package :lol-web/core)

;;; ============================================================================
;;; CHILDREN RENDERING
;;; ============================================================================

(defun render-children (children)
  "Render children to HTML string, handling various input types.

   CHILDREN can be:
     - nil -> \"\"
     - string -> string
     - function -> (funcall function)
     - list -> concatenated renders
     - other -> princ-to-string"
  (cond
    ((null children) "")
    ((stringp children) children)
    ((functionp children) (funcall children))
    ((listp children)
     (format nil "~{~A~}" (mapcar #'render-children children)))
    (t (princ-to-string children))))

;;; ============================================================================
;;; WITH-CHILDREN - Execute body with children context
;;; ============================================================================

(defmacro! with-children (&body body)
  "Execute body with CHILDREN bound to rendered child content.
   Returns the concatenation of body result and children.

   Example:
   (defcomponent-with-props wrapper ()
     (with-children
       (htm-str (:div :class \"wrapper\"
                 (cl-who:str children)))))"
  `(let ((,g!result (progn ,@body)))
     (if children
         (concatenate 'string ,g!result (render-children children))
         ,g!result)))

;;; ============================================================================
;;; NAMED SLOTS
;;; ============================================================================

(defvar *current-slots* nil
  "Dynamic variable holding current slot contents during rendering.")

(defmacro! slot (name &optional default)
  "Render a named slot, falling back to default if not provided.

   In parent component:
   (my-component :slots '((:header \"Title\") (:footer \"Footer\")))

   In child component definition:
   (defcomponent-with-props my-component ((slots :type list))
     (with-named-slots slots
       (htm-str
         (:header (slot :header))
         (:main (slot :content \"Default content\"))
         (:footer (slot :footer)))))"
  `(or (getf *current-slots* ,name)
       ,(if default default "")))

(defmacro with-named-slots (slots-binding &body body)
  "Execute body with slots available via SLOT macro.

   SLOTS-BINDING: Expression evaluating to a plist of slot name/content pairs.

   Example:
   (with-named-slots '(:header \"My Header\" :content \"Body text\")
     (slot :header)  ; => \"My Header\"
     (slot :content) ; => \"Body text\"
     (slot :missing \"default\")) ; => \"default\""
  `(let ((*current-slots* ,slots-binding))
     ,@body))

;;; ============================================================================
;;; SLOT COMPONENT - Declarative slot definition
;;; ============================================================================

(defmacro defslot-component (name (&rest prop-specs) &key slots body)
  "Define a component with declarative named slots.

   SLOTS: List of (slot-name &key default required) slot definitions
   BODY: Component body using (slot :name) to render slots

   Example:
   (defslot-component card ()
     :slots ((header :required t)
             (body :default \"No content\")
             (footer))
     :body (htm-str
             (:div :class \"card\"
               (:div :class \"card-header\" (slot :header))
               (:div :class \"card-body\" (slot :body))
               (when (slot :footer)
                 (htm-str (:div :class \"card-footer\" (slot :footer)))))))

   Usage:
   (card :slots '(:header \"Title\" :body \"Content\"))"
  (let ((slot-names (mapcar (lambda (s) (if (consp s) (car s) s)) slots)))
    `(defcomponent-with-props ,name (,@prop-specs (slots :type list))
       (with-named-slots slots
         ;; Validate required slots
         ,@(mapcar (lambda (s)
                     (when (and (consp s) (getf (cdr s) :required))
                       `(unless (getf slots ,(car s))
                          (error "Slot ~A is required for ~A" ,(car s) ',name))))
                   slots)
         ,body))))

;;; ============================================================================
;;; RENDER-SLOT - Explicit slot rendering function
;;; ============================================================================

(defun render-slot (slots name &optional default)
  "Render a slot from a slots plist.
   Functional alternative to SLOT macro for use outside WITH-SLOTS context."
  (let ((content (getf slots name)))
    (if content
        (render-children content)
        (if default (render-children default) ""))))
