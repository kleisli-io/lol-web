;;;; Regression tests for surgery snapshot/undo/redo + surgery API routes.
;;;;
;;;; normalize-state-pairs converts plist-shaped :state values from
;;;; defcomponent-with-api into the alist form that capture-snapshot /
;;;; restore-snapshot / surgery-undo / surgery-redo / component-state-tree
;;;; expect. Without it, dolist over a plist yielded individual keywords
;;;; and (car :key) signalled TYPE-ERROR — snapshot round-trip never
;;;; worked for API components.
;;;;
;;;; The /api/surgery/* POST routes (state, update, eval, snapshot, panel,
;;;; undo, redo) must be registered at load time; surgery-js.lisp issues
;;;; fetches against them. Before src/devtools/surgery-routes.lisp existed,
;;;; surgery panel actions silently 404'd.

(in-package :lol-web/devtools/test)
(in-suite :lol-web/devtools/test)

(test regression-surgery-normalize-state-pairs
  "normalize-state-pairs converts plist or alist to alist form"
  (is (equal '((:a . 1) (:b . 2))
             (lol-web/devtools::normalize-state-pairs '((:a . 1) (:b . 2))))
      "alist input passes through unchanged")
  (is (equal '((:a . 1) (:b . 2))
             (lol-web/devtools::normalize-state-pairs '(:a 1 :b 2)))
      "plist input is converted to alist")
  (is (null (lol-web/devtools::normalize-state-pairs nil))
      "empty input yields empty list"))

(test regression-surgery-restore-snapshot-plist-state
  "restore-snapshot works on plist :state (defcomponent-with-api shape)"
  (let* ((restored (make-hash-table :test 'eq))
         (probe-id "regression-snapshot-probe-plist")
         (component
           (lambda (msg &rest args)
             (ecase msg
               (:id probe-id)
               (:inspect (list :id probe-id
                               :state (list :counter 7 :name "alice")
                               :subscribers 0
                               :mounted t))
               (:set-state (setf (gethash (first args) restored)
                                 (second args)))))))
    (let ((ts (capture-snapshot component "test")))
      (is (restore-snapshot component ts)
          "restore-snapshot returns t on success")
      (is (= 7 (gethash :counter restored))
          ":counter restored from plist snapshot")
      (is (string= "alice" (gethash :name restored))
          ":name restored from plist snapshot"))
    (clear-snapshots probe-id)))

(test regression-surgery-restore-snapshot-alist-state
  "restore-snapshot still works on alist :state (defcomponent shape)"
  (let* ((restored (make-hash-table :test 'eq))
         (probe-id "regression-snapshot-probe-alist")
         (component
           (lambda (msg &rest args)
             (ecase msg
               (:id probe-id)
               (:inspect (list :id probe-id
                               :state '((counter . 7) (name . "alice"))
                               :subscribers 0
                               :mounted t))
               (:set-state (setf (gethash (first args) restored)
                                 (second args)))))))
    (let ((ts (capture-snapshot component "test")))
      (is (restore-snapshot component ts)
          "restore-snapshot returns t on success")
      (is (= 7 (gethash 'counter restored))
          "counter restored from alist snapshot")
      (is (string= "alice" (gethash 'name restored))
          "name restored from alist snapshot"))
    (clear-snapshots probe-id)))

(test regression-surgery-component-state-tree-plist
  "component-state-tree renders plist :state correctly"
  (let* ((probe-id "regression-state-tree-probe")
         (component
           (lambda (msg &rest args)
             (declare (ignore args))
             (ecase msg
               (:id probe-id)
               (:inspect (list :id probe-id
                               :state (list :counter 42)
                               :subscribers 0
                               :mounted t))))))
    (let* ((tree (component-state-tree component))
           (state (cdr (assoc :state tree))))
      (is (= 1 (length state))
          "one state entry rendered")
      (is (eq :counter (cdr (assoc :key (first state))))
          ":key correctly extracted from plist pair")
      (is (= 42 (cdr (assoc :value (first state))))
          ":value correctly extracted from plist pair"))))

(test regression-surgery-api-routes-registered
  "All seven /api/surgery/* POST routes are registered at load time"
  (dolist (path '("/api/surgery/state"
                  "/api/surgery/update"
                  "/api/surgery/eval"
                  "/api/surgery/snapshot"
                  "/api/surgery/panel"
                  "/api/surgery/undo"
                  "/api/surgery/redo"))
    (is (gethash (cons :post path) lol-web/server:*routes*)
        "POST ~A is registered" path)))

(test regression-surgery-mode-installs-render-hook
  "enable-surgery-mode installs xray-wrapper-html as
   :lol-web/html's *component-render-hook*; disable-surgery-mode
   clears it. The hook is the bridge that lets *surgery-mode*
   actually change what component->html returns."
  (let ((hook-before lol-web/html:*component-render-hook*))
    (unwind-protect
         (progn
           (lol-web/devtools::disable-surgery-mode)
           (is (null lol-web/html:*component-render-hook*)
               "disable-surgery-mode clears the render hook")
           (lol-web/devtools::enable-surgery-mode)
           (is (eq #'lol-web/devtools::xray-wrapper-html
                   lol-web/html:*component-render-hook*)
               "enable-surgery-mode installs xray-wrapper-html as the hook")
           (lol-web/devtools::disable-surgery-mode)
           (is (null lol-web/html:*component-render-hook*)
               "disable-surgery-mode clears the hook again"))
      (setf lol-web/html:*component-render-hook* hook-before))))

(test regression-component-to-html-uses-render-hook
  "lol-web/html:component->html consults *component-render-hook* under
   :wrapper t and bypasses it when :wrapper nil. The hook receives the
   component and is responsible for the entire wrapped output."
  (let ((hook-before lol-web/html:*component-render-hook*)
        (probe (lambda (msg &rest args)
                 (declare (ignore args))
                 (ecase msg
                   (:id "render-hook-probe")
                   (:render "<inner/>")))))
    (unwind-protect
         (progn
           (setf lol-web/html:*component-render-hook*
                 (lambda (c)
                   (declare (ignore c))
                   "<wrapped-by-hook/>"))
           (is (search "<wrapped-by-hook/>"
                       (lol-web/html:component->html probe :wrapper t))
               "hook output is returned when :wrapper t")
           (is (string= "<inner/>"
                        (lol-web/html:component->html probe :wrapper nil))
               "hook is bypassed when :wrapper nil"))
      (setf lol-web/html:*component-render-hook* hook-before))))

(test regression-behavior-presets-symbols-not-defined
  "register-behavior-preset, *behavior-presets*, and
   list-behavior-presets must not be defined in :lol-web/devtools.
   They have no consumers in-tree and no exports — leaving them
   defined would just keep dead surface alive."
  (dolist (sym '(:register-behavior-preset
                 :*behavior-presets*
                 :list-behavior-presets))
    (let ((s (find-symbol (symbol-name sym) :lol-web/devtools)))
      (is (or (null s) (not (or (boundp s) (fboundp s))))
          (format nil "symbol ~A must not be bound or fbound in :lol-web/devtools"
                  sym)))))
