;;;; Regression tests for opt-in cross-thread safety (src/core/signals.lisp).
;;;;
;;;; Single-threaded reactive use is the documented default: *current-effect* /
;;;; *batch-depth* / *pending-effects* and per-signal subscribers tables have
;;;; no internal locking. with-lol-web-thread-safety acquires a coarse lock
;;;; around its body so callers that share a signal graph across threads can
;;;; opt into atomic read-modify-write.

(in-package :lol-web/core/test)
(in-suite :lol-web/core/test)

(test regression-with-lol-web-thread-safety-is-macro
  "with-lol-web-thread-safety is exported from :lol-web/core as a macro"
  (is (macro-function 'with-lol-web-thread-safety)))

(test regression-with-lol-web-thread-safety-serialises-rmw
  "Wrapper serialises read-modify-write on a shared signal across threads"
  (multiple-value-bind (counter set-counter) (make-signal 0)
    (let* ((per-thread 200)
           (n-threads 16)
           (expected (* per-thread n-threads))
           (threads
             (loop repeat n-threads
                   collect (bordeaux-threads:make-thread
                             (lambda ()
                               (dotimes (_ per-thread)
                                 (with-lol-web-thread-safety
                                   (funcall set-counter
                                            (1+ (funcall counter))))))))))
      (dolist (th threads) (bordeaux-threads:join-thread th))
      (is (= expected (funcall counter))
          "expected ~D increments, got ~D — wrapper failed to serialise"
          expected (funcall counter)))))
