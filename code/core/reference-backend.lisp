;;;; © 2016-2021 Marco Heisig         - license: GNU AGPLv3 -*- coding: utf-8 -*-

(in-package #:petalisp.core)

;;; The purpose of the reference backend is to compute reference solutions
;;; for automated testing. It is totally acceptable that this
;;; implementation is slow or eagerly consing, as long as it is obviously
;;; correct.

(defclass reference-backend (backend)
  ())

(defun make-reference-backend ()
  (make-instance 'reference-backend))

(defvar *table*)

(defvar *lazy-array*)

(defmethod backend-compute
    ((backend reference-backend)
     (lazy-arrays list))
  (let ((*table* (make-hash-table :test #'eq)))
    (mapcar #'compute-delayed-array lazy-arrays)))

(defun compute-delayed-array (lazy-array)
  (with-accessors ((shape lazy-array-shape)
                   (element-type lazy-array-element-type))
      lazy-array
    (let ((array (make-array (shape-dimensions shape) :element-type element-type)))
      (map-shape
       (lambda (index)
         (setf (apply #'aref array index)
               (lazy-array-value lazy-array index)))
       shape)
      array)))

(defun lazy-array-value (lazy-array index)
  (alexandria:ensure-gethash
   index
   (alexandria:ensure-gethash
    lazy-array *table*
    (make-hash-table :test #'equal))
   (let ((*lazy-array* lazy-array))
     (delayed-action-value (lazy-array-delayed-action lazy-array) index))))

(defmethod delayed-action-value
    ((delayed-map delayed-map) index)
  (apply (delayed-map-operator delayed-map)
         (mapcar
          (lambda (input)
            (lazy-array-value input index))
          (delayed-map-inputs delayed-map))))

(defmethod delayed-action-value
    ((delayed-multiple-value-map delayed-multiple-value-map) index)
  (multiple-value-list
   (apply (delayed-multiple-value-map-operator delayed-multiple-value-map)
          (mapcar
           (lambda (input)
             (lazy-array-value input index))
           (delayed-multiple-value-map-inputs delayed-multiple-value-map)))))

(defmethod delayed-action-value
    ((delayed-nth-value delayed-nth-value) index)
  (nth
   (delayed-nth-value-number delayed-nth-value)
   (lazy-array-value (delayed-nth-value-input delayed-nth-value) index)))

(defmethod delayed-action-value
    ((delayed-reshape delayed-reshape) index)
  (lazy-array-value
   (delayed-reshape-input delayed-reshape)
   (transform-sequence index (delayed-reshape-transformation delayed-reshape))))

(defmethod delayed-action-value
    ((delayed-fuse delayed-fuse) index)
  (lazy-array-value
   (loop for input in (delayed-fuse-inputs delayed-fuse)
         when (shape-contains (lazy-array-shape input) index)
           return input)
   index))

(defmethod delayed-action-value
    ((delayed-range delayed-range) index)
  (first index))

(defmethod delayed-action-value
    ((delayed-array delayed-array) index)
  (apply #'aref (delayed-array-storage delayed-array) index))

(defmethod delayed-action-value
    ((delayed-thunk delayed-thunk) index)
  (delayed-action-value (funcall (delayed-thunk-thunk delayed-thunk))))

(defmethod delayed-action-value
    ((delayed-nop delayed-nop) index)
  (error "A delayed NOP should never be executed."))

(defmethod delayed-action-value
    ((delayed-unknown delayed-unknown) index)
  (error "Attempt to evaluate a graph that contains unknowns."))
