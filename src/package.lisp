;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: CL-USER; Base: 10 -*-
;;;; Umbrella + shim package definitions.
;;;;
;;;; Each :lol-web/<sub> defpackage lives in src/packages/<name>.lisp and is
;;;; loaded as the head of its sub-system's source list. This file only
;;;; defines the umbrella :lol-web facade and the :lol-reactive deprecation
;;;; shim, so it must load AFTER every sub-system is in the image.

(in-package :cl-user)

(defpackage :lol-web
  (:documentation
   "Umbrella facade for the lol-web framework. Re-exports the external
    symbols of every :lol-web/<sub> sub-package. New code should depend on
    :lol-web (full surface) or a specific :lol-web/<sub> (focused boundary).")
  (:use :cl
        :lol-web/sanitize
        :lol-web/core
        :lol-web/css
        :lol-web/html
        :lol-web/parenscript
        :lol-web/server
        :lol-web/extractors
        :lol-web/jschema
        :lol-web/openapi
        :lol-web/htmx
        :lol-web/realtime
        :lol-web/realtime-htmx
        :lol-web/wizards
        :lol-web/devtools
        :lol-web/fullstack
        :lol-web/optimization
        :lol-web/forms
        :lol-web/rendering
        :lol-web/resources
        :lol-web/client-runtime)
  (:export
   ;; — :lol-web/sanitize —
   #:sanitize-html #:sanitize-attribute #:sanitize-url
   ;; — :lol-web/core —
   #:*current-effect* #:make-signal #:make-effect #:make-computed #:batch
   #:with-lol-web-thread-safety #:make-pandoric-signal
   #:make-store #:make-evolving-component #:make-component-factory
   #:*factory-registry* #:make-reactive-list
   #:defcomponent #:with-component-state
   #:register-component #:unregister-component #:find-component
   #:generate-component-id #:*components*
   #:defcomponent-with-props #:with-props #:validate-props
   #:defcontext #:defcontext-signal #:list-contexts #:get-context-info
   #:inspect-context #:inspect-all-contexts
   ;; — :lol-web/css —
   #:*component-css-registry* #:*css-load-order*
   #:make-css-module #:get-css-module #:get-component-css
   #:generate-all-component-css #:defcss
   #:clear-css-registry #:list-registered-css-components #:inspect-css-registry
   #:css-rule #:css-rules #:css-section #:css-keyframes #:css-media
   #:css-var #:css-var-definition
   #:*colors* #:*typography* #:*spacing* #:*effects*
   #:*default-colors* #:*default-typography* #:*default-spacing* #:*default-effects*
   #:get-color #:get-font #:get-spacing #:get-effect
   #:validate-token #:levenshtein-distance #:find-closest-match
   #:generate-css-variables
   #:tw-color #:tw-spacing #:tw-bg #:tw-text #:tw-border #:tw-arbitrary
   #:tw-bg-value #:tw-text-value #:tw-border-value
   #:classes #:null-or-empty-p #:tailwind-config
   ;; — :lol-web/html —
   #:htm #:htm-str #:html-attrs #:render-component #:component->html
   #:*component-render-hook* #:highlight-sexp
   #:html-page #:reactive-runtime-js
   #:escape-html #:safe-str #:safe-fmt
   ;; — :lol-web/parenscript —
   #:reactive-script #:on-click #:on-change
   ;; — :lol-web/server —
   #:*env* #:*response-headers*
   #:request-path #:request-method #:request-query-string
   #:request-header #:request-content-type #:request-content-length
   #:request-body #:request-body-json
   #:query-param #:query-params #:post-param #:post-params #:param
   #:parse-request-json #:encode-json-string #:decode-json-string
   #:response #:html-response #:json-response #:text-response
   #:redirect-response #:error-response
   #:with-response-headers #:add-response-header #:get-response-headers
   #:http-status-text
   #:session-get #:session-set #:session-delete #:session-clear #:session-keys
   #:csrf-token
   #:add-security-headers #:add-csp-header #:with-security
   #:generate-csrf-token #:get-csrf-token #:validate-csrf-token
   #:csrf-token-input #:with-csrf-validation #:constant-time-string=
   #:check-rate-limit #:get-client-ip #:with-rate-limit #:*rate-limit-store*
   #:http-error #:http-error-status #:http-error-body
   #:client-error #:server-error
   #:http-bad-request #:http-unauthorized #:http-forbidden
   #:http-not-found #:http-unprocessable-entity
   #:*debug-mode* #:*error-log-path*
   #:with-error-handling #:log-error
   #:render-error-page #:render-404-page #:render-500-page
   #:enable-debug-mode #:disable-debug-mode
   #:*path-params* #:path-param
   #:*routes* #:clear-routes #:list-routes #:route-handler #:make-app
   #:*server* #:*before-handler-hook* #:*before-server-start-hook*
   #:start-server #:stop-server
   #:defstreaming-route
   #:defroute
   ;; — :lol-web/extractors —
   #:extractor-spec #:make-extractor-spec #:extractor-spec-p
   #:extractor-spec-name #:extractor-spec-kind #:extractor-spec-type
   #:extractor-spec-required-p #:extractor-spec-default
   #:extractor-spec-source-string #:extractor-spec-custom-resolver
   #:resolve-extractor #:*handler-metadata* #:handler-metadata
   #:extractor-error #:extractor-error-name #:extractor-error-kind
   #:missing-extractor-input
   #:extractor-coercion-error #:extractor-coercion-error-raw-value
   #:extractor-coercion-error-target-type
   #:extractor-not-registered
   #:defhandler
   ;; — :lol-web/jschema —
   #:parse #:validate #:clear-registry #:get-schema
   #:json-schema #:json-schema-p
   #:invalid-schema #:invalid-schema-error-message
   #:invalid-schema-base-uri #:invalid-schema-json-pointer
   #:unparsable-json #:unparsable-json-error #:not-implemented
   #:invalid-json #:invalid-json-errors
   #:invalid-json-value #:invalid-json-value-error-message
   #:invalid-json-value-json-pointer
   ;; — :lol-web/openapi —
   #:lisp-type-to-openapi-schema #:kind-to-openapi-location
   #:build-openapi-spec #:emit-openapi-json
   ;; — :lol-web/htmx —
   #:htmx-runtime-js #:hx-get #:hx-post #:hx-put #:hx-delete
   #:htmx-indicator-css
   #:render-autocomplete #:render-autocomplete-results #:autocomplete-css
   #:oob-swap #:oob-content #:with-oob-swaps
   #:htmx-request-p #:htmx-boosted-p #:htmx-history-restore-request-p
   #:htmx-target #:htmx-trigger #:htmx-trigger-name
   #:htmx-current-url #:htmx-prompt
   #:with-htmx-response
   #:set-htmx-trigger #:set-htmx-redirect #:set-htmx-location
   #:render-with-oob #:render-oob-only
   #:htmx-or-redirect #:htmx-or-full-page
   #:*idiomorph-version* #:idiomorph-js-path #:include-idiomorph
   #:htmx-morph-extension-js #:htmx-runtime-with-morph-js
   #:include-htmx-with-morph #:hx-morph
   ;; — :lol-web/realtime —
   #:*ws-connections* #:ws-connection-count #:ws-channels
   #:make-ws-handler #:defws
   #:ws-send #:ws-send-text #:ws-send-binary #:ws-send-json #:ws-close
   #:ws-broadcast #:ws-broadcast-json #:ws-broadcast-all
   #:ws-broadcast-html #:ws-broadcast-oob #:ws-broadcast-trigger
   #:*sse-connections* #:sse-connection-count #:sse-channels
   #:make-sse-handler #:defsse #:format-sse-event
   #:sse-send #:sse-send-comment #:sse-ping-all
   #:sse-broadcast #:sse-broadcast-all
   #:sse-broadcast-html #:sse-broadcast-oob #:sse-broadcast-trigger
   ;; — :lol-web/realtime-htmx —
   #:ws-client-js #:sse-client-js #:optimistic-js
   ;; — :lol-web/wizards —
   #:defwizard #:register-wizard #:get-wizard-spec #:list-wizards
   #:inspect-wizard
   #:start-wizard #:get-wizard-session #:remove-wizard-session
   #:cleanup-stale-sessions #:list-active-wizard-sessions
   #:process-wizard-submission #:render-wizard-step #:render-wizard-complete
   #:wizard-text-field #:wizard-select-field #:wizard-radio-group
   ;; — :lol-web/devtools —
   #:capture-snapshot #:restore-snapshot #:list-snapshots #:clear-snapshots
   #:component-state-tree
   #:surgery-get-state #:surgery-set-state
   #:surgery-eval-in-context #:surgery-dispatch
   #:xray-wrapper-html #:surgery-panel-html
   #:enable-surgery-mode #:disable-surgery-mode #:surgery-mode-p
   #:surgery-runtime-js #:surgery-css
   #:push-undo #:surgery-undo #:surgery-redo
   #:register-component-metadata
   ;; — :lol-web/fullstack —
   #:defisomorphic-component #:render-isomorphic #:isomorphic-page
   #:hydration-runtime-js #:include-hydration-runtime #:client-action-attr
   #:serialize-state #:deserialize-state
   #:defcomponent-with-api
   #:register-api-component #:find-api-component
   #:list-api-components #:list-api-routes #:inspect-api-component
   #:generate-api-client-js #:api-client-script-tag
   ;; — :lol-web/optimization —
   #:analyze-dependencies #:reactive-let #:with-reactive-bindings
   #:defvalidated-template #:validate-css-class
   #:*registered-css-classes* #:*registered-css-prefixes*
   #:register-css-class #:register-css-prefix
   #:register-tailwind-classes
   ;; — :lol-web/client-runtime —
   #:lol-reactive-runtime-js))

(defpackage :lol-reactive
  (:documentation
   "Deprecation shim for the legacy :lol-reactive package. Re-exports every
    external symbol of :lol-web. New code should use :lol-web (umbrella) or
    a specific :lol-web/<sub> sub-package.")
  (:use :cl :lol-web)
  (:export
   #:sanitize-html #:sanitize-attribute #:sanitize-url
   #:*current-effect* #:make-signal #:make-effect #:make-computed #:batch
   #:with-lol-web-thread-safety #:make-pandoric-signal
   #:make-store #:make-evolving-component #:make-component-factory
   #:*factory-registry* #:make-reactive-list
   #:defcomponent #:with-component-state
   #:register-component #:unregister-component #:find-component
   #:generate-component-id #:*components*
   #:defcomponent-with-props #:with-props #:validate-props
   #:defcontext #:defcontext-signal #:list-contexts #:get-context-info
   #:inspect-context #:inspect-all-contexts
   #:*component-css-registry* #:*css-load-order*
   #:make-css-module #:get-css-module #:get-component-css
   #:generate-all-component-css #:defcss
   #:clear-css-registry #:list-registered-css-components #:inspect-css-registry
   #:css-rule #:css-rules #:css-section #:css-keyframes #:css-media
   #:css-var #:css-var-definition
   #:*colors* #:*typography* #:*spacing* #:*effects*
   #:*default-colors* #:*default-typography* #:*default-spacing* #:*default-effects*
   #:get-color #:get-font #:get-spacing #:get-effect
   #:validate-token #:levenshtein-distance #:find-closest-match
   #:generate-css-variables
   #:tw-color #:tw-spacing #:tw-bg #:tw-text #:tw-border #:tw-arbitrary
   #:tw-bg-value #:tw-text-value #:tw-border-value
   #:classes #:null-or-empty-p #:tailwind-config
   #:htm #:htm-str #:html-attrs #:render-component #:component->html
   #:*component-render-hook* #:highlight-sexp
   #:html-page #:reactive-runtime-js
   #:escape-html #:safe-str #:safe-fmt
   #:reactive-script #:on-click #:on-change
   #:*env* #:*response-headers*
   #:request-path #:request-method #:request-query-string
   #:request-header #:request-content-type #:request-content-length
   #:request-body #:request-body-json
   #:query-param #:query-params #:post-param #:post-params #:param
   #:parse-request-json #:encode-json-string #:decode-json-string
   #:response #:html-response #:json-response #:text-response
   #:redirect-response #:error-response
   #:with-response-headers #:add-response-header #:get-response-headers
   #:http-status-text
   #:session-get #:session-set #:session-delete #:session-clear #:session-keys
   #:csrf-token
   #:add-security-headers #:add-csp-header #:with-security
   #:generate-csrf-token #:get-csrf-token #:validate-csrf-token
   #:csrf-token-input #:with-csrf-validation #:constant-time-string=
   #:check-rate-limit #:get-client-ip #:with-rate-limit #:*rate-limit-store*
   #:http-error #:http-error-status #:http-error-body
   #:client-error #:server-error
   #:http-bad-request #:http-unauthorized #:http-forbidden
   #:http-not-found #:http-unprocessable-entity
   #:*debug-mode* #:*error-log-path*
   #:with-error-handling #:log-error
   #:render-error-page #:render-404-page #:render-500-page
   #:enable-debug-mode #:disable-debug-mode
   #:*path-params* #:path-param
   #:*routes* #:clear-routes #:list-routes #:route-handler #:make-app
   #:*server* #:*before-handler-hook* #:*before-server-start-hook*
   #:start-server #:stop-server
   #:defstreaming-route
   #:defroute
   #:extractor-spec #:make-extractor-spec #:extractor-spec-p
   #:extractor-spec-name #:extractor-spec-kind #:extractor-spec-type
   #:extractor-spec-required-p #:extractor-spec-default
   #:extractor-spec-source-string #:extractor-spec-custom-resolver
   #:resolve-extractor #:*handler-metadata* #:handler-metadata
   #:extractor-error #:extractor-error-name #:extractor-error-kind
   #:missing-extractor-input
   #:extractor-coercion-error #:extractor-coercion-error-raw-value
   #:extractor-coercion-error-target-type
   #:extractor-not-registered
   #:defhandler
   #:parse #:validate #:clear-registry #:get-schema
   #:json-schema #:json-schema-p
   #:invalid-schema #:invalid-schema-error-message
   #:invalid-schema-base-uri #:invalid-schema-json-pointer
   #:unparsable-json #:unparsable-json-error #:not-implemented
   #:invalid-json #:invalid-json-errors
   #:invalid-json-value #:invalid-json-value-error-message
   #:invalid-json-value-json-pointer
   #:lisp-type-to-openapi-schema #:kind-to-openapi-location
   #:build-openapi-spec #:emit-openapi-json
   #:htmx-runtime-js #:hx-get #:hx-post #:hx-put #:hx-delete
   #:htmx-indicator-css
   #:render-autocomplete #:render-autocomplete-results #:autocomplete-css
   #:oob-swap #:oob-content #:with-oob-swaps
   #:htmx-request-p #:htmx-boosted-p #:htmx-history-restore-request-p
   #:htmx-target #:htmx-trigger #:htmx-trigger-name
   #:htmx-current-url #:htmx-prompt
   #:with-htmx-response
   #:set-htmx-trigger #:set-htmx-redirect #:set-htmx-location
   #:render-with-oob #:render-oob-only
   #:htmx-or-redirect #:htmx-or-full-page
   #:*idiomorph-version* #:idiomorph-js-path #:include-idiomorph
   #:htmx-morph-extension-js #:htmx-runtime-with-morph-js
   #:include-htmx-with-morph #:hx-morph
   #:*ws-connections* #:ws-connection-count #:ws-channels
   #:make-ws-handler #:defws
   #:ws-send #:ws-send-text #:ws-send-binary #:ws-send-json #:ws-close
   #:ws-broadcast #:ws-broadcast-json #:ws-broadcast-all
   #:ws-broadcast-html #:ws-broadcast-oob #:ws-broadcast-trigger
   #:*sse-connections* #:sse-connection-count #:sse-channels
   #:make-sse-handler #:defsse #:format-sse-event
   #:sse-send #:sse-send-comment #:sse-ping-all
   #:sse-broadcast #:sse-broadcast-all
   #:sse-broadcast-html #:sse-broadcast-oob #:sse-broadcast-trigger
   #:ws-client-js #:sse-client-js #:optimistic-js
   #:defwizard #:register-wizard #:get-wizard-spec #:list-wizards
   #:inspect-wizard
   #:start-wizard #:get-wizard-session #:remove-wizard-session
   #:cleanup-stale-sessions #:list-active-wizard-sessions
   #:process-wizard-submission #:render-wizard-step #:render-wizard-complete
   #:wizard-text-field #:wizard-select-field #:wizard-radio-group
   #:capture-snapshot #:restore-snapshot #:list-snapshots #:clear-snapshots
   #:component-state-tree
   #:surgery-get-state #:surgery-set-state
   #:surgery-eval-in-context #:surgery-dispatch
   #:xray-wrapper-html #:surgery-panel-html
   #:enable-surgery-mode #:disable-surgery-mode #:surgery-mode-p
   #:surgery-runtime-js #:surgery-css
   #:push-undo #:surgery-undo #:surgery-redo
   #:register-component-metadata
   #:defisomorphic-component #:render-isomorphic #:isomorphic-page
   #:hydration-runtime-js #:include-hydration-runtime #:client-action-attr
   #:serialize-state #:deserialize-state
   #:defcomponent-with-api
   #:register-api-component #:find-api-component
   #:list-api-components #:list-api-routes #:inspect-api-component
   #:generate-api-client-js #:api-client-script-tag
   #:analyze-dependencies #:reactive-let #:with-reactive-bindings
   #:defvalidated-template #:validate-css-class
   #:*registered-css-classes* #:*registered-css-prefixes*
   #:register-css-class #:register-css-prefix
   #:register-tailwind-classes
   #:lol-reactive-runtime-js))

;;; Once-per-image deprecation warning. Triggers on first load only; further
;;; loads in the same image (e.g., re-compile during REPL development) are
;;; silent.
(defvar lol-reactive::*shim-warned* nil)
(unless lol-reactive::*shim-warned*
  (cl:warn
   "Package :lol-reactive is a deprecation shim for :lol-web. Update consumers ~
    to use :lol-web (umbrella) or :lol-web/<sub> (focused).")
  (setf lol-reactive::*shim-warned* t))
