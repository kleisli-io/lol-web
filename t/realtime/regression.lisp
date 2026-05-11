;;;; Regression tests for :lol-web/realtime.
;;;;
;;;; Smoke-level coverage of the SSE message formatter and connection-
;;;; registry shape. The handler creators (`make-ws-handler`,
;;;; `make-sse-handler`) and broadcast functions need a live Hunchentoot
;;;; environment to exercise meaningfully and are not covered here.

(in-package :lol-web/realtime/test)
(in-suite :lol-web/realtime/test)

;;; ============================================================================
;;; format-sse-event — SSE wire-format spec compliance
;;; ============================================================================

(test regression-format-sse-event-basic-shape
  "An event with type and string data emits `event:` and `data:` lines
   terminated by an empty line per the SSE spec."
  (let ((s (format-sse-event "update" "hello")))
    (is (search "event: update" s))
    (is (search "data: hello" s))
    (is (search (format nil "~%~%") s)
        "event must terminate with a blank line")))

(test regression-format-sse-event-multiline-data
  "Multi-line data is split and each line gets its own `data:` prefix
   per SSE spec (otherwise the client treats embedded newlines as event
   terminators)."
  (let ((s (format-sse-event "msg" (format nil "line1~%line2~%line3"))))
    (is (search "data: line1" s))
    (is (search "data: line2" s))
    (is (search "data: line3" s))))

(test regression-format-sse-event-id-and-retry
  "Optional `:id` and `:retry` keys produce `id:` and `retry:` prefix
   lines used by the client for resume and backoff."
  (let ((s (format-sse-event "tick" "1" :id "evt-7" :retry 5000)))
    (is (search "id: evt-7" s))
    (is (search "retry: 5000" s))))

(test regression-format-sse-event-non-string-data-json-encoded
  "Non-string data is JSON-encoded by `encode-json-string` so plists
   and lists become valid JSON payloads on the wire."
  (let ((s (format-sse-event "obj" '(:k 1 :v "two"))))
    ;; Don't pin the exact JSON shape — encode-json-string's output is
    ;; library-controlled. Just assert non-string data didn't get
    ;; passed through verbatim (which would emit Lisp `:K` keywords).
    (is (search "data: " s))
    (is (not (search "data: (:K 1" s))
        "non-string data must be JSON-encoded, not princ'd")))

;;; ============================================================================
;;; Connection registry — defaults are empty hash-tables, counts are 0
;;; ============================================================================

(test regression-connection-registries-default-empty
  "The connection registries are initialised to empty hash-tables and
   the count helpers return 0 with no live connections."
  (is (hash-table-p *ws-connections*))
  (is (hash-table-p *sse-connections*))
  (is (= 0 (ws-connection-count "channel-with-no-clients")))
  (is (= 0 (sse-connection-count "channel-with-no-clients"))))

(test regression-channels-listing-shape
  "`ws-channels` and `sse-channels` return a list (possibly empty) of
   active channel ids."
  (is (listp (ws-channels)))
  (is (listp (sse-channels))))
