;;;; Regression tests for effect/computed disposers (src/core/signals.lisp).
;;;;
;;;; make-effect's disposer must remove the effect from every signal it
;;;; tracked, not just nullify the local effect-fn binding. make-computed
;;;; must retain the disposer returned by its internal make-effect and
;;;; expose it as the second return value, so callers can detach computed
;;;; values from their source signals.

(in-package :lol-web/core/test)
(in-suite :lol-web/core/test)

(test regression-effect-dispose-unsubscribes
  "make-effect's disposer removes the effect from every signal it tracked"
  (let ((calls 0))
    (multiple-value-bind (getter setter) (make-signal 0)
      (let ((dispose (make-effect
                      (lambda ()
                        (funcall getter)
                        (incf calls)
                        nil))))
        (is (= 1 calls) "effect runs once on creation to record dependencies")
        (funcall setter 1)
        (funcall setter 2)
        (is (= 3 calls) "effect runs on each signal update before dispose")
        (funcall dispose)
        (funcall setter 3)
        (funcall setter 4)
        (funcall setter 5)
        (is (= 3 calls)
            "disposed effect must not run on subsequent signal updates (~D extra runs)"
            (- calls 3))))))

(test regression-effect-dispose-runs-cleanup-once
  "disposer runs the latest cleanup function and does not run it again"
  (let ((cleanups 0))
    (multiple-value-bind (getter setter) (make-signal 0)
      (let ((dispose (make-effect
                      (lambda ()
                        (funcall getter)
                        (lambda () (incf cleanups))))))
        (funcall setter 1)
        (is (= 1 cleanups) "cleanup runs before each re-execution")
        (funcall dispose)
        (is (= 2 cleanups) "cleanup runs once on dispose")
        (funcall setter 2)
        (is (= 2 cleanups)
            "after dispose, no further cleanup runs (effect is detached)")))))

(test regression-computed-returns-dispose
  "make-computed returns (values getter dispose) and dispose stops recompute"
  (let ((computes 0))
    (multiple-value-bind (a set-a) (make-signal 1)
      (multiple-value-bind (computed dispose-computed)
          (make-computed
           (lambda ()
             (incf computes)
             (* 10 (funcall a))))
        (is (functionp computed) "first return value is the getter")
        (is (functionp dispose-computed) "second return value is the disposer")
        (is (= 10 (funcall computed)) "initial computed value")
        (funcall set-a 2)
        (funcall set-a 3)
        (is (= 30 (funcall computed)) "computed updates on dependency change")
        (let ((before-dispose computes))
          (funcall dispose-computed)
          (funcall set-a 4)
          (funcall set-a 5)
          (is (= before-dispose computes)
              "after dispose, source-signal updates must not trigger recompute (~D extra)"
              (- computes before-dispose)))))))
