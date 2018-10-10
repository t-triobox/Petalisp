;;;; © 2016-2018 Marco Heisig - licensed under AGPLv3, see the file COPYING     -*- coding: utf-8 -*-

(in-package :petalisp-native-backend)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Generic Functions

(defgeneric immediate-from-buffer (buffer backend))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Classes

(defclass buffer (petalisp-ir:buffer)
  ())

(defclass non-immediate-buffer (buffer)
  ((%storage :initarg :storage :accessor storage)))

(defclass immediate-buffer (buffer)
  ())

(defclass array-buffer (immediate-buffer)
  ((%storage :initarg :storage :reader storage)))

(defclass scalar-buffer (immediate-buffer)
  ((%storage :initarg :storage :reader storage)))

(defclass range-buffer (immediate-buffer)
  ((%axis :initarg :axis :reader axis)))

(defclass kernel (petalisp-ir:kernel)
  ((%buffers :initarg :buffers :accessor buffers)
   (%executedp :initarg :executedp :accessor executedp
               :initform nil)))

(defclass simple-kernel (petalisp-ir:simple-kernel kernel)
  ())

(defclass reduction-kernel (petalisp-ir:reduction-kernel kernel)
  ())

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Methods

(defmethod immediate-from-buffer
    ((buffer buffer)
     (native-backend native-backend))
  (make-array-immediate
   (storage buffer)))

(defmethod petalisp-ir:make-buffer
    ((array-immediate array-immediate)
     (native-backend native-backend))
  (make-instance 'array-buffer
    :shape (shape array-immediate)
    :element-type (element-type array-immediate)
    :storage (storage array-immediate)))

(defmethod petalisp-ir:make-buffer
    ((scalar-immediate scalar-immediate)
     (native-backend native-backend))
  (make-instance 'scalar-buffer
    :shape (shape scalar-immediate)
    :element-type (element-type scalar-immediate)
    :storage (storage scalar-immediate)))

(defmethod petalisp-ir:make-buffer
    ((range-immediate range-immediate)
     (native-backend native-backend))
  (make-instance 'range-buffer
    :shape (shape range-immediate)
    :element-type (element-type range-immediate)
    :axis (axis range-immediate)))

(defmethod petalisp-ir:make-buffer
    ((strided-array strided-array)
     (native-backend native-backend))
  (make-instance 'non-immediate-buffer
    :shape (shape strided-array)
    :element-type (element-type strided-array)))

(defmethod petalisp-ir:make-simple-kernel
    ((backend native-backend) &rest args)
  (apply #'make-instance 'simple-kernel args))

(defmethod petalisp-ir:make-reduction-kernel
    ((backend native-backend) &rest args)
  (apply #'make-instance 'reduction-kernel args))

(defmethod shared-initialize :after ((kernel kernel) slot-names &rest args)
  (declare (ignore slot-names args))
  (let ((buffers '()))
    (loop for (buffer . nil) in (petalisp-ir:loads kernel) do
      (pushnew buffer buffers))
    (loop for (buffer . nil) in (petalisp-ir:stores kernel) do
      (pushnew buffer buffers))
    (setf (buffers kernel) buffers)))
