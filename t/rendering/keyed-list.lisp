(in-package :lol-web/rendering/test)
(in-suite :lol-web/rendering/test)

(test reconcile-list-identical
  "Reconciling identical lists produces no operations"
  (let ((items '((:id 1 :name "a") (:id 2 :name "b") (:id 3 :name "c"))))
    (let ((ops (lol-web/rendering::reconcile-list
                 items items
                 :key (lambda (x) (getf x :id)))))
      (is (null ops)))))

(test reconcile-list-addition
  "Reconciling with new item produces insert operation"
  (let ((old '((:id 1 :name "a") (:id 2 :name "b")))
        (new '((:id 1 :name "a") (:id 2 :name "b") (:id 3 :name "c"))))
    (let ((ops (lol-web/rendering::reconcile-list
                 old new
                 :key (lambda (x) (getf x :id)))))
      (is (not (null ops)))
      (is (member :insert ops :key #'first)))))

(test reconcile-list-removal
  "Reconciling with removed item produces remove operation"
  (let ((old '((:id 1 :name "a") (:id 2 :name "b") (:id 3 :name "c")))
        (new '((:id 1 :name "a") (:id 3 :name "c"))))
    (let ((ops (lol-web/rendering::reconcile-list
                 old new
                 :key (lambda (x) (getf x :id)))))
      (is (not (null ops)))
      (is (member :remove ops :key #'first)))))

(test reconcile-list-reorder
  "Reordered items with same keys at different positions emit remove+insert pairs"
  (let ((old '((:id 1 :name "a") (:id 2 :name "b") (:id 3 :name "c")))
        (new '((:id 3 :name "c") (:id 1 :name "a") (:id 2 :name "b"))))
    (let* ((ops (lol-web/rendering::reconcile-list
                  old new
                  :key (lambda (x) (getf x :id))))
           (n-remove (count :remove ops :key #'first))
           (n-insert (count :insert ops :key #'first)))
      (is (not (null ops))
          "reorder must produce ops — silently treating it as identical leaves the DOM stale")
      (is (= 3 n-remove) "every moved key needs a :remove (got ~D)" n-remove)
      (is (= 3 n-insert) "every moved key needs an :insert (got ~D)" n-insert)
      (is (every (lambda (op) (eq :remove (first op)))
                 (subseq ops 0 n-remove))
          "removes must come before inserts so the client can apply them in stream order"))))

(test keyed-render-exists
  "keyed-render function exists"
  (is (fboundp 'lol-web/rendering::keyed-render)))

(test for-each-macro-exists
  "for-each macro exists"
  (is (macro-function 'lol-web/rendering::for-each)))
