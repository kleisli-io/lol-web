;;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: LOL-WEB/HTML; Base: 10 -*-
;;;; HTML page template using cl-who
;;;;
;;;; GENERIC INFRASTRUCTURE - NO hardcoded colors, fonts, or theme styles.
;;;; Apps provide their own visual identity by setting *colors*, *typography*, etc.
;;;;
;;;; Shared macros (htm, htm-str), component rendering (render-component,
;;;; component->html), highlight-sexp, and cl-who config live in html/elements.lisp.
;;;; This file provides only the full-page template and client-side runtime.

(in-package :lol-web/html)

;;; ============================================================================
;;; PAGE TEMPLATE (GENERIC)
;;;
;;; Provides infrastructure only. Apps define aesthetics via:
;;; - Setting *colors*, *typography*, etc. before rendering
;;; - Registering CSS modules via defcss
;;; - Passing custom head-extra content
;;; ============================================================================

(defun html-page (&key (title "LOL-REACTIVE")
                       (lang "en")
                       (body-class "")
                       head-extra
                       body
                       css-href
                       (include-tailwind t)
                       (include-htmx t)
                       (include-surgery nil)
                       tailwind-script
                       base-css
                       component-css
                       htmx-indicator-css
                       csrf-token
                       reactive-runtime
                       htmx-runtime
                       surgery-css
                       surgery-runtime
                       description
                       canonical
                       (og-type "website")
                       og-title
                       og-description
                       og-url
                       og-image
                       og-image-alt
                       og-site-name)
  "Generate a complete HTML page with token-driven CSS variables.

   NO hardcoded colors, fonts, or styles - apps provide their own theme.

   Asset strings — each, when non-NIL, is emitted verbatim into the page;
   NIL means the corresponding asset block is omitted. There are no
   internal helper fallbacks: this file stays decoupled from the css/htmx/
   server/devtools sub-systems, so callers must pre-compute and pass:
   - TAILWIND-SCRIPT: Tailwind config JS
   - BASE-CSS: token-derived CSS variables
   - COMPONENT-CSS: registered component CSS
   - HTMX-INDICATOR-CSS: HTMX indicator CSS (only honoured when INCLUDE-HTMX)
   - CSRF-TOKEN: CSRF token string for the meta tag (only when INCLUDE-HTMX)
   - REACTIVE-RUNTIME: Parenscript reactive runtime JS
   - HTMX-RUNTIME: Parenscript HTMX runtime JS (only when INCLUDE-HTMX)
   - SURGERY-CSS, SURGERY-RUNTIME: surgery panel assets (only when INCLUDE-SURGERY)

   This contract lets the html sub-system build standalone — it depends
   only on :lol-web/sanitize and cl-who, never on css/htmx/server/devtools.

   Other options:
   - TITLE: Page title
   - LANG: HTML lang attribute (default \"en\")
   - BODY-CLASS: Additional body CSS classes
   - HEAD-EXTRA: Custom head content (string)
   - BODY: Page body content (string)
   - CSS-HREF: Compiled CSS stylesheet path (when provided, suppresses CDN)
   - INCLUDE-TAILWIND: Include Tailwind CDN (default t, ignored when CSS-HREF set)
   - INCLUDE-HTMX: Include HTMX-style runtime (default t)
   - INCLUDE-SURGERY: Include surgery panel runtime (default nil)
   - DESCRIPTION: <meta name=description> for search snippets
   - CANONICAL: <link rel=canonical> URL (always set on public pages)
   - OG-TYPE: og:type (default \"website\")
   - OG-TITLE / OG-DESCRIPTION / OG-URL / OG-IMAGE / OG-IMAGE-ALT / OG-SITE-NAME:
     OpenGraph fields for social cards (LinkedIn, Slack, Discord, iMessage).
     OG-TITLE/OG-DESCRIPTION default to TITLE/DESCRIPTION when nil."
  (cl-who:with-html-output-to-string (s nil :prologue t)
    (:html :lang lang
      (:head
       (:meta :charset "utf-8")
       (:meta :name "viewport" :content "width=device-width, initial-scale=1")
       (:title (cl-who:str title))

       (when description
         (cl-who:htm (:meta :name "description" :content description)))
       (when canonical
         (cl-who:htm (:link :rel "canonical" :href canonical)))

       ;; OpenGraph — emitted when any og-* is set or canonical/description
       ;; give us enough to populate the minimum quad.
       (let ((og-t  (or og-title title))
             (og-d  (or og-description description))
             (og-u  (or og-url canonical)))
         (when (or og-image og-t og-d og-u og-site-name)
           (cl-who:htm
            (:meta :property "og:type"        :content og-type)
            (when og-t (cl-who:htm (:meta :property "og:title"       :content og-t)))
            (when og-d (cl-who:htm (:meta :property "og:description" :content og-d)))
            (when og-u (cl-who:htm (:meta :property "og:url"         :content og-u)))
            (when og-site-name
              (cl-who:htm (:meta :property "og:site_name" :content og-site-name)))
            (when og-image
              (cl-who:htm
               (:meta :property "og:image"        :content og-image)
               (:meta :property "og:image:width"  :content "1200")
               (:meta :property "og:image:height" :content "630")
               (when og-image-alt
                 (cl-who:htm (:meta :property "og:image:alt" :content og-image-alt))))))))

       ;; Compiled CSS (when provided, replaces CDN)
       (when css-href
         (cl-who:htm
          (:link :rel "stylesheet" :href css-href)))

       ;; Tailwind CDN (only when no compiled CSS)
       (when (and include-tailwind (not css-href))
         (cl-who:htm
          (:script :src "https://cdn.tailwindcss.com")
          (when tailwind-script
            (cl-who:htm (:script (cl-who:str tailwind-script))))))

       ;; CSS variables from tokens — caller pre-computes via :lol-web/css.
       (when base-css
         (cl-who:htm (:style (cl-who:str base-css))))

       ;; Registered component CSS — caller pre-computes via :lol-web/css.
       (when component-css
         (cl-who:htm (:style (cl-who:str component-css))))

       ;; HTMX indicator styles — caller pre-computes via :lol-web/htmx.
       (when (and include-htmx htmx-indicator-css)
         (cl-who:htm (:style (cl-who:str htmx-indicator-css))))

       ;; CSRF meta tag for HTMX runtime — caller passes the session token
       ;; (e.g., (lol-web/server:get-csrf-token)).
       (when (and include-htmx csrf-token)
         (cl-who:htm (:meta :name "csrf-token" :content csrf-token)))

       ;; App-provided head content
       (cl-who:str (or head-extra "")))

      (:body :class body-class
        ;; Main content
        (cl-who:str (or body ""))

        ;; Reactive runtime script (Parenscript). Same-package fallback —
        ;; reactive-runtime-js is defined below in :lol-web/html.
        (:script (cl-who:str (or reactive-runtime (reactive-runtime-js))))

        ;; HTMX runtime — caller pre-computes via :lol-web/htmx.
        (when (and include-htmx htmx-runtime)
          (cl-who:htm (:script (cl-who:str htmx-runtime))))

        ;; Surgery panel — caller pre-computes via :lol-web/devtools.
        (when (and include-surgery surgery-css)
          (cl-who:htm (:style (cl-who:str surgery-css))))
        (when (and include-surgery surgery-runtime)
          (cl-who:htm (:script (cl-who:str surgery-runtime))))))))

;;; ============================================================================
;;; REACTIVE RUNTIME (Parenscript)
;;;
;;; Client-side reactivity. ALL JavaScript generated via Parenscript.
;;; ============================================================================

(defun reactive-runtime-js ()
  "Generate the client-side reactive runtime via Parenscript.
   NO raw JavaScript strings."
  (parenscript:ps
    ;; LOL-REACTIVE Runtime
    (defvar *lol-reactive*
      (ps:create
       :components (ps:new (-Map))

       :register (lambda (id handlers)
                   (ps:chain (ps:@ this components) (set id handlers)))

       :dispatch (lambda (component-id action &rest args)
                   (ps:chain
                    (fetch "/api/dispatch"
                           (ps:create :method "POST"
                                      :headers (ps:create "Content-Type" "application/json")
                                      :body (ps:chain -j-s-o-n (stringify
                                             (ps:create :component-id component-id
                                                        :action action
                                                        :args args)))))
                    (then (lambda (r) (ps:chain r (json))))
                    (then (lambda (data)
                            (when (ps:@ data html)
                              (let ((el (ps:chain document (query-selector
                                         (+ "[data-component-id=\"" component-id "\"]")))))
                                (when el
                                  (setf (ps:@ el inner-h-t-m-l) (ps:@ data html)))))))))

       :set-state (lambda (component-id key value)
                    (ps:chain
                     (fetch "/api/set-state"
                            (ps:create :method "POST"
                                       :headers (ps:create "Content-Type" "application/json")
                                       :body (ps:chain -j-s-o-n (stringify
                                              (ps:create :component-id component-id
                                                         :key key
                                                         :value value)))))
                     (then (lambda (r) (ps:chain r (json))))
                     (then (lambda (data)
                             (when (ps:@ data html)
                               (let ((el (ps:chain document (query-selector
                                          (+ "[data-component-id=\"" component-id "\"]")))))
                                 (when el
                                   (setf (ps:@ el inner-h-t-m-l) (ps:@ data html)))))))))))

    ;; Shorthand - only set if LOL-REACTIVE exists
    (defvar dispatch
      (when *lol-reactive*
        (ps:chain (ps:@ *lol-reactive* dispatch) (bind *lol-reactive*))))
    (defvar set-state
      (when *lol-reactive*
        (ps:chain (ps:getprop *lol-reactive* "set-state") (bind *lol-reactive*))))

    (ps:chain console (log "(LOL-REACTIVE :status :loaded)"))))
