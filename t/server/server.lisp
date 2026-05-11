(in-package :lol-web/server/test)
(in-suite :lol-web/server/test)

;;; ============================================================================
;;; Route registration macros
;;; ============================================================================

(test defroute-macro-exists
  "defroute macro exists"
  (is (macro-function 'defroute)))

(test routes-hash-table-exists
  "Routes are stored in a hash table"
  (is (hash-table-p *routes*)))

;;; ============================================================================
;;; Security primitives present
;;; ============================================================================

(test add-security-headers-exists
  "add-security-headers function exists"
  (is (fboundp 'add-security-headers)))

(test add-csp-header-exists
  "add-csp-header function exists"
  (is (fboundp 'add-csp-header)))

;;; ============================================================================
;;; CSRF
;;; ============================================================================

(test generate-csrf-token-exists
  "generate-csrf-token function exists"
  (is (fboundp 'generate-csrf-token)))

(test validate-csrf-token-exists
  "validate-csrf-token function exists"
  (is (fboundp 'validate-csrf-token)))

(test csrf-token-input-exists
  "csrf-token-input function exists"
  (is (fboundp 'csrf-token-input)))

;;; ============================================================================
;;; Rate limiting
;;; ============================================================================

(test check-rate-limit-exists
  "check-rate-limit function exists"
  (is (fboundp 'check-rate-limit)))

;;; ============================================================================
;;; Error rendering
;;; ============================================================================

(test log-error-exists
  "log-error function exists"
  (is (fboundp 'log-error)))

(test render-error-page-exists
  "render-error-page function exists"
  (is (fboundp 'render-error-page)))

(test render-404-page-exists
  "render-404-page function exists"
  (is (fboundp 'render-404-page)))

(test render-500-page-exists
  "render-500-page function exists"
  (is (fboundp 'render-500-page)))
