;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: LOL-WEB/DEVTOOLS; Base: 10 -*-
;;;; devtools/surgery-routes.lisp - HTTP routes backing the surgery panel UI.
;;;;
;;;; surgery-js.lisp issues fetches against /api/surgery/{state,update,eval,
;;;; snapshot,panel,undo,redo}. The handlers in surgery.lisp implement the
;;;; behaviour (component-state-tree, surgery-set-state, surgery-eval-in-context,
;;;; capture-snapshot, restore-snapshot, surgery-panel-html, surgery-undo,
;;;; surgery-redo) but were never wired to the HTTP surface — every endpoint
;;;; returned 404. defhandler calls live here so route registration follows
;;;; surgery.lisp (handlers) and the extractor protocol in load order.

(in-package :lol-web/devtools)

(defun %surgery-not-found ()
  "Standard 'component not registered' response shape."
  '((:success . nil) (:error . "Component not found")))

(defun %surgery-component (component-id)
  "Resolve a surgery POST's :component-id to a live component, or NIL."
  (when component-id
    (find-component component-id)))

(defhandler surgery-state-handler "/api/surgery/state"
    (:method :post :content-type "application/json")
    ((body-json :json-body :required nil))
  "Return the component-state-tree for the panel's state inspector."
  (encode-json-string
    (let* ((component-id (cdr (assoc :component-id body-json)))
           (component (%surgery-component component-id)))
      (if component
          `((:success . t)
            (:state . ,(component-state-tree component)))
          (%surgery-not-found)))))

(defhandler surgery-update-handler "/api/surgery/update"
    (:method :post :content-type "application/json")
    ((body-json :json-body :required nil))
  "Apply a surgical state change. Body: {component-id, key, value}."
  (encode-json-string
    (let* ((component-id (cdr (assoc :component-id body-json)))
           (raw-key (cdr (assoc :key body-json)))
           (key (when raw-key (intern (string-upcase raw-key) :keyword)))
           (value (cdr (assoc :value body-json)))
           (component (%surgery-component component-id)))
      (cond
        ((not component) (%surgery-not-found))
        ((not key) '((:success . nil) (:error . "Missing :key in request body")))
        (t (let ((tree (surgery-set-state component-id key value)))
             `((:success . t)
               (:html . ,(funcall component :render))
               (:state . ,tree))))))))

(defhandler surgery-eval-handler "/api/surgery/eval"
    (:method :post :content-type "application/json")
    ((body-json :json-body :required nil))
  "Evaluate a Lisp form in a component's lexical state context."
  (encode-json-string
    (let* ((component-id (cdr (assoc :component-id body-json)))
           (form (cdr (assoc :form body-json)))
           (component (%surgery-component component-id)))
      (cond
        ((not component) (%surgery-not-found))
        ((not form) '((:success . nil) (:error . "Missing :form in request body")))
        (t (let ((result (surgery-eval-in-context component-id form)))
             ;; surgery-eval-in-context already returns the
             ;; ((:success . t/nil) (:result . ...) (:state . ...)) shape, plus
             ;; a top-level html refresh string when the change took effect.
             (if (cdr (assoc :success result))
                 (append result `((:html . ,(funcall component :render))))
                 result)))))))

(defhandler surgery-snapshot-handler "/api/surgery/snapshot"
    (:method :post :content-type "application/json")
    ((body-json :json-body :required nil))
  "Capture or restore a snapshot. Body: {component-id, action, ...}.
   :action 'capture' uses :description; :action 'restore' uses :timestamp."
  (encode-json-string
    (let* ((component-id (cdr (assoc :component-id body-json)))
           (action (cdr (assoc :action body-json)))
           (component (%surgery-component component-id)))
      (cond
        ((not component) (%surgery-not-found))
        ((string= action "capture")
         (let ((ts (capture-snapshot component
                                     (cdr (assoc :description body-json)))))
           `((:success . t) (:timestamp . ,ts))))
        ((string= action "restore")
         (let ((ts (cdr (assoc :timestamp body-json))))
           (if (and ts (restore-snapshot component ts))
               `((:success . t)
                 (:html . ,(funcall component :render))
                 (:state . ,(component-state-tree component)))
               '((:success . nil) (:error . "Snapshot not found")))))
        (t '((:success . nil) (:error . "Unknown :action — expected 'capture' or 'restore'")))))))

(defhandler surgery-panel-handler "/api/surgery/panel"
    (:method :post :content-type "application/json")
    ((body-json :json-body :required nil))
  "Return the surgery panel HTML for the requested component."
  (encode-json-string
    (let* ((component-id (cdr (assoc :component-id body-json)))
           (component (%surgery-component component-id)))
      (if component
          `((:success . t)
            (:panel-html . ,(surgery-panel-html component)))
          (%surgery-not-found)))))

(defhandler surgery-undo-handler "/api/surgery/undo"
    (:method :post :content-type "application/json")
    ((body-json :json-body :required nil))
  "Undo the most recent surgical change."
  (encode-json-string
    (let* ((component-id (cdr (assoc :component-id body-json)))
           (component (%surgery-component component-id)))
      (cond
        ((not component) (%surgery-not-found))
        ((not (can-undo-p component-id))
         '((:success . nil) (:error . "Nothing to undo")))
        (t (let ((tree (surgery-undo component-id)))
             `((:success . t)
               (:html . ,(funcall component :render))
               (:state . ,tree))))))))

(defhandler surgery-redo-handler "/api/surgery/redo"
    (:method :post :content-type "application/json")
    ((body-json :json-body :required nil))
  "Redo a previously undone change."
  (encode-json-string
    (let* ((component-id (cdr (assoc :component-id body-json)))
           (component (%surgery-component component-id)))
      (cond
        ((not component) (%surgery-not-found))
        ((not (can-redo-p component-id))
         '((:success . nil) (:error . "Nothing to redo")))
        (t (let ((tree (surgery-redo component-id)))
             `((:success . t)
               (:html . ,(funcall component :render))
               (:state . ,tree))))))))
