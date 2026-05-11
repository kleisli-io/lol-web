(in-package :lol-web/core/test)
(in-suite :lol-web/core/test)

(test component-register-and-find
  "Components can be registered and found by ID"
  (let ((test-component (lambda () "test")))
    (register-component "test-comp-1" test-component)
    (is (eq test-component (find-component "test-comp-1")))
    (unregister-component "test-comp-1")
    (is (null (find-component "test-comp-1")))))

(test component-find-nonexistent
  "Finding nonexistent component returns NIL"
  (is (null (find-component "nonexistent-comp-xyz"))))

(test defcomponent-creates-function
  "defcomponent macro is available"
  (is (fboundp 'defcomponent)))

(test generate-component-id-unique-sequential
  "generate-component-id returns distinct IDs in sequence (atomic-incf monotonic)"
  (let* ((n 200)
         (ids (loop repeat n
                    collect (lol-web/core::generate-component-id 'test-comp))))
    (is (= n (length ids)))
    (is (= n (length (remove-duplicates ids :test #'string=)))
        "duplicate IDs: counter is not monotonic")))

(test generate-component-id-unique-concurrent
  "generate-component-id stays unique across threads (atomic-incf race-free)"
  (let* ((n-threads 8)
         (per-thread 250)
         (ids-by-thread (make-array n-threads :initial-element nil))
         (threads
           (loop for tid from 0 below n-threads
                 collect (let ((tid tid))
                           (bordeaux-threads:make-thread
                            (lambda ()
                              (setf (aref ids-by-thread tid)
                                    (loop repeat per-thread
                                          collect (lol-web/core::generate-component-id 'race-comp)))))))))
    (mapc #'bordeaux-threads:join-thread threads)
    (let* ((all-ids (loop for v across ids-by-thread append v))
           (unique  (remove-duplicates all-ids :test #'string=)))
      (is (= (* n-threads per-thread) (length all-ids)))
      (is (= (length all-ids) (length unique))
          "concurrent generation produced colliding IDs"))))
