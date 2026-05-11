(in-package :lol-web/wizards/test)
(in-suite :lol-web/wizards/test)

;;; ============================================================================
;;; Wizard registration
;;; ============================================================================

(test register-wizard-exists
  "register-wizard function exists"
  (is (fboundp 'register-wizard)))

(test list-wizards-exists
  "list-wizards function exists"
  (is (fboundp 'list-wizards)))

(test get-wizard-spec-exists
  "get-wizard-spec function exists"
  (is (fboundp 'get-wizard-spec)))

;;; ============================================================================
;;; Wizard sessions
;;; ============================================================================

(test start-wizard-exists
  "start-wizard function exists"
  (is (fboundp 'start-wizard)))

(test get-wizard-session-exists
  "get-wizard-session function exists"
  (is (fboundp 'get-wizard-session)))

(test process-wizard-submission-exists
  "process-wizard-submission function exists"
  (is (fboundp 'process-wizard-submission)))

;;; ============================================================================
;;; Wizard rendering
;;; ============================================================================

(test render-wizard-step-exists
  "render-wizard-step function exists"
  (is (fboundp 'render-wizard-step)))

(test render-wizard-complete-exists
  "render-wizard-complete function exists"
  (is (fboundp 'render-wizard-complete)))

;;; ============================================================================
;;; Form-field helpers — boundedness and HTML output
;;; ============================================================================

(test wizard-text-field-exists
  "wizard-text-field function exists"
  (is (fboundp 'wizard-text-field)))

(test wizard-select-field-exists
  "wizard-select-field function exists"
  (is (fboundp 'wizard-select-field)))

(test wizard-radio-group-exists
  "wizard-radio-group function exists"
  (is (fboundp 'wizard-radio-group)))

(test wizard-text-field-renders-html
  "wizard-text-field produces HTML output"
  (let ((html (wizard-text-field "username" :label "Username")))
    (is (stringp html))
    (is (search "username" html))
    (is (search "input" html :test #'char-equal))))

(test wizard-select-field-renders-options
  "wizard-select-field includes options"
  (let ((html (wizard-select-field "country"
                '(("us" . "United States") ("uk" . "United Kingdom"))
                :label "Country")))
    (is (stringp html))
    (is (search "select" html :test #'char-equal))
    (is (search "option" html :test #'char-equal))))

;;; ============================================================================
;;; Session-binding regression: another user cannot drive someone else's wizard
;;; ============================================================================

(defun %make-fake-session (&optional initial-pairs)
  "Build a hash-table that mimics the Lack session contract enough for
   session-get / session-set to round-trip."
  (let ((h (make-hash-table :test 'equal)))
    (loop for (k v) on initial-pairs by #'cddr
          do (setf (gethash k h) v))
    h))

(defmacro with-fake-session ((session) &body body)
  "Bind lol-web/server:*env* with the given session table installed
   under :lack.session, so session-get / session-set work without a
   live Hunchentoot acceptor."
  `(let ((lol-web/server:*env* (list :lack.session ,session)))
     ,@body))

(test regression-wizard-session-hijack-attempt-rejected
  "An attacker who guesses a victim's wizard-session-id but submits from
   their own Lack session must be refused (status :forbidden), not
   served the victim's in-progress wizard. process-wizard-submission
   compares the wizard's owner-token to the token stored in the
   submitter's session under wizard-owner-key."
  (lol-web/wizards::register-wizard
   'regression-hijack-probe
   (list :steps (list (list :name :a :title "A"
                            :form (lambda (data)
                                    (declare (ignore data))
                                    "<input name='x'/>")))
         :on-complete nil))
  (let* ((victim-session (%make-fake-session))
         (attacker-session (%make-fake-session))
         (wizard nil)
         (wid nil))
    ;; Victim starts a wizard. start-wizard stores the owner-token in
    ;; the victim's session.
    (with-fake-session (victim-session)
      (setf wizard (lol-web/wizards::start-wizard 'regression-hijack-probe))
      (setf wid (funcall wizard :id)))
    (unwind-protect
         (progn
           ;; Attacker presents the victim's wizard id from their own
           ;; session — the owner-token lookup fails.
           (with-fake-session (attacker-session)
             (multiple-value-bind (status result)
                 (lol-web/wizards::process-wizard-submission
                  'regression-hijack-probe wid :next nil)
               (is (eq status :forbidden)
                   "attacker submission must be :forbidden")
               (is (stringp result)
                   "forbidden response carries an explanation string")))
           ;; Victim, submitting from their own session, is still
           ;; allowed. Use :back so we don't trip step-validation.
           (with-fake-session (victim-session)
             (multiple-value-bind (status result)
                 (lol-web/wizards::process-wizard-submission
                  'regression-hijack-probe wid :back nil)
               (declare (ignore result))
               (is (eq status :continue)
                   "victim submission still :continue from owning session"))))
      (lol-web/wizards::remove-wizard-session wid))))
