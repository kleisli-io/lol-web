(in-package :lol-web/html/test)
(in-suite :lol-web/html/test)

(test reactive-runtime-js-exists
  "reactive-runtime-js function exists"
  (is (fboundp 'reactive-runtime-js)))

(test reactive-runtime-js-generates-code
  "reactive-runtime-js generates JavaScript"
  (let ((js (reactive-runtime-js)))
    (is (stringp js))
    (is (> (length js) 100))))
