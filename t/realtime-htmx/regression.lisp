;;;; Regression tests for :lol-web/realtime-htmx.
;;;;
;;;; Covers: ws-client-js reconnect jitter (anti-thundering-herd) +
;;;; ws-client-js, sse-client-js, optimistic-js shape contracts.

(in-package :lol-web/realtime-htmx/test)
(in-suite :lol-web/realtime-htmx/test)

;;; ============================================================================
;;; ws-client-js — reconnect uses full jitter
;;; ============================================================================

(test regression-ws-client-reconnect-uses-jitter
  "ws-client-js generates JS whose reconnect delay is scaled by Math.random.
   Without jitter, every client that disconnects together retries at the
   same backoff edges, hammering the server. Full jitter (delay scaled by
   Math.random) spreads retries over [0, reconnectDelay)."
  (let ((js (ws-client-js)))
    (is (search "Math.random" js)
        "ws-client-js must invoke Math.random for jitter")
    (is (search "reconnectDelay" js)
        "ws-client-js must reference reconnectDelay")
    (is (search "setTimeout" js)
        "ws-client-js must schedule the reconnect via setTimeout")))

(test regression-ws-client-jitter-multiplies-delay
  "Jittered delay must be the product of reconnectDelay and Math.random,
   not Math.random alone. Catches a regression where the multiplier is
   accidentally dropped (a delay of just Math.random()*1 ≈ 0–1 ms is
   effectively no backoff at all)."
  (let ((js (ws-client-js)))
    ;; Parenscript renders (* reconnect-delay (Math.random)) — assert both
    ;; identifiers appear inside a Math.floor argument, which is the
    ;; canonical jittered-delay binding.
    (is (search "Math.floor" js)
        "jittered delay must be Math.floored to a whole-ms integer")))

;;; ============================================================================
;;; client JS generators — non-empty output, contain expected runtime hooks
;;; ============================================================================

(test regression-ws-client-js-non-empty
  "ws-client-js produces a non-empty Parenscript-compiled JS string."
  (let ((js (ws-client-js)))
    (is (stringp js))
    (is (> (length js) 100)
        "ws-client-js must compile to a substantive JS payload")
    (is (search "WebSocket" js)
        "must reference the WebSocket constructor")))

(test regression-sse-client-js-non-empty
  "sse-client-js produces a non-empty Parenscript-compiled JS string with
   EventSource handling."
  (let ((js (sse-client-js)))
    (is (stringp js))
    (is (> (length js) 100)
        "sse-client-js must compile to a substantive JS payload")
    (is (search "EventSource" js)
        "must reference the EventSource constructor")))

(test regression-optimistic-js-non-empty
  "optimistic-js produces a non-empty Parenscript-compiled JS string."
  (let ((js (optimistic-js)))
    (is (stringp js))
    (is (> (length js) 100)
        "optimistic-js must compile to a substantive JS payload")))
