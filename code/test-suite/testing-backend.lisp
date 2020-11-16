;;;; © 2016-2020 Marco Heisig         - license: GNU AGPLv3 -*- coding: utf-8 -*-

(in-package #:petalisp.test-suite)

(defclass testing-backend (backend)
  ((%reference-backend
    :reader reference-backend
    :initform (make-reference-backend))
   (%ir-backend-interpreted
    :reader ir-backend-interpreted
    :initform (make-ir-backend :mode :interpreted))
   (%ir-backend-compiled
    :reader ir-backend-compiled
    :initform (make-ir-backend :mode :compiled))
   (%native-backend
    :reader native-backend
    :initform
    (make-native-backend))))

(defun make-testing-backend ()
  (make-instance 'testing-backend))

(defmethod backend-compute
    ((testing-backend testing-backend)
     (data-structures list))
  (with-accessors ((reference-backend reference-backend)
                   (ir-backend-interpreted ir-backend-interpreted)
                   (ir-backend-compiled ir-backend-compiled)
                   (native-backend native-backend)) testing-backend
    (let ((reference-solutions
            (backend-compute reference-backend data-structures))
          (ir-backend-interpreted-solutions
            (backend-compute ir-backend-interpreted data-structures))
          (ir-backend-compiled-solutions
            (backend-compute ir-backend-compiled data-structures))
          (native-backend-solutions
            (backend-compute native-backend data-structures)))
      (compare-solutions reference-solutions ir-backend-interpreted-solutions)
      (compare-solutions reference-solutions ir-backend-compiled-solutions)
      (compare-solutions reference-solutions native-backend-solutions)
      reference-solutions)))

(defun compare-solutions (solutions-1 solutions-2)
  (loop for immediate-1 in solutions-1
        for immediate-2 in solutions-2 do
          (is (approximately-equal
               (lisp-datum-from-immediate immediate-1)
               (lisp-datum-from-immediate immediate-2)))))

(defmethod delete-backend ((testing-backend testing-backend))
  (delete-backend (reference-backend testing-backend))
  (delete-backend (ir-backend-interpreted testing-backend))
  (delete-backend (ir-backend-compiled testing-backend))
  (delete-backend (native-backend testing-backend))
  (call-next-method))

(defun call-with-testing-backend (thunk)
  (let ((*backend* (make-testing-backend)))
    (unwind-protect (funcall thunk)
      (delete-backend *backend*))))

(defmacro with-testing-backend (&body body)
  `(call-with-testing-backend (lambda () ,@body)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Equality

(defgeneric approximately-equal (a b))

(defmethod approximately-equal ((a t) (b t))
  (eql a b))

(defmethod approximately-equal ((array-1 array) (array-2 array))
  (and (equal (array-dimensions array-1)
              (array-dimensions array-2))
       (loop for index below (array-total-size array-1)
             always (approximately-equal
                     (row-major-aref array-1 index)
                     (row-major-aref array-2 index)))))

(defmethod approximately-equal ((a single-float) (b single-float))
  (< (abs (- a b)) (* 64 single-float-epsilon)))

(defmethod approximately-equal ((a double-float) (b double-float))
  (< (abs (- a b)) (* 64 double-float-epsilon)))
