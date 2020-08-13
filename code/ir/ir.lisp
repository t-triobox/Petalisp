;;;; © 2016-2020 Marco Heisig         - license: GNU AGPLv3 -*- coding: utf-8 -*-

(in-package #:petalisp.ir)

;;; A buffer represents a set of memory locations big enough to hold one
;;; element of type ELEMENT-TYPE for each index of the buffer's shape.
;;; Each buffer is written to by zero or more kernels and read from zero or
;;; more kernels.
(defstruct (buffer
            (:predicate bufferp)
            (:constructor make-buffer))
  ;; The shape of the buffer.
  (shape nil :type shape)
  ;; The type code of all elements stored in the buffer.
  (ntype nil)
  ;; An alist whose keys are kernels writing to this buffer, and whose
  ;; values are all store instructions from that kernel into this buffer.
  (writers '() :type list)
  ;; An alist whose keys are kernels reading from this buffer, and whose
  ;; values are all load instructions from that kernel into this buffer.
  (readers '() :type list)
  ;; Whether the buffer can be reused after its last use.
  (reusablep nil :type boolean)
  ;; An opaque object, representing the allocated memory.
  (storage nil))

;;; A kernel represents a computation that, for each element in its
;;; iteration space, reads from some buffers and writes to some buffers.
(defstruct (kernel
            (:predicate kernelp)
            (:constructor make-kernel))
  (iteration-space nil :type shape)
  ;; An alist whose keys are buffers, and whose values are all load
  ;; instructions referencing that buffer.
  (sources '() :type list)
  ;; An alist whose keys are buffers, and whose values are all store
  ;; instructions referencing that buffer.
  (targets '() :type list))

;;; This function is a very ad-hoc approximation of the cost of executing
;;; the kernel.
(defun kernel-cost (kernel)
  (* (shape-size (kernel-iteration-space kernel))
     (kernel-highest-instruction-number kernel)))

;;; The behavior of a kernel is described by its iteration space and its
;;; instructions.  The instructions form a DAG, whose leaves are load
;;; instructions or references to iteration variables, and whose roots are
;;; store instructions.
;;;
;;; The instruction number of an instruction is an integer that is unique
;;; among all instructions of the current kernel.  Instruction numbers are
;;; handed out in depth first order of instruction dependencies, such that
;;; the roots (store instructions) have the highest numbers and that the
;;; leaf nodes (load and iref instructions) have the lowest numbers.  After
;;; modifications to the instruction graph, the numbers have to be
;;; recomputed.
;;;
;;; Each instruction input is a cons cell, whose cdr is another
;;; instruction, and whose car is an integer describing which of the
;;; multiple values of the cdr is referenced.
(defstruct (instruction
            (:predicate instructionp)
            (:constructor nil))
  (number 0 :type fixnum)
  (inputs '() :type list))

;;; A call instruction represents the application of a function to a set of
;;; values that are the result of other instructions.
(defstruct (call-instruction
            (:include instruction)
            (:predicate call-instruction-p))
  (operator nil :type (or function symbol)))

(defstruct (single-value-call-instruction
            (:include call-instruction)
            (:constructor make-single-value-call-instruction
                (operator inputs))))

(defstruct (multiple-value-call-instruction
            (:include call-instruction)
            (:constructor make-multiple-value-call-instruction
                (number-of-values operator inputs)))
  (number-of-values nil :type (integer 0 (#.multiple-values-limit))))

;;; We call an instruction an iterating instruction, if its behavior
;;; directly depends on the current element of the iteration space.
(defstruct (iterating-instruction
            (:include instruction)
            (:predicate iterating-instruction-p)
            (:constructor nil)
            (:conc-name instruction-))
  (transformation nil :type transformation))

;;; An iref instruction represents an access to elements of the iteration
;;; space itself.  Its transformation is a mapping from the iteration space
;;; to a rank one space.  Its value is the single integer that is the
;;; result of applying the transformation to the current iteration space.
(defstruct (iref-instruction
            (:include iterating-instruction)
            (:predicate iref-instruction-p)
            (:constructor make-iref-instruction
                (transformation))))

;;; A load instruction represents a read from main memory.  It returns a
;;; single value --- the entry of the buffer storage at the location
;;; specified by the current element of the iteration space and the load's
;;; transformation.
(defstruct (load-instruction
            (:include iterating-instruction)
            (:predicate load-instruction-p)
            (:constructor make-load-instruction
                (buffer transformation)))
  (buffer nil :type buffer))

;;; A store instruction represents a write to main memory.  It stores its
;;; one and only input at the entry of the buffer storage specified by the
;;; current element of the iteration space and the store instruction's
;;; transformation.  A store instruction returns zero values.
(defstruct (store-instruction
            (:include iterating-instruction)
            (:predicate store-instruction-p)
            (:constructor make-store-instruction
                (value buffer transformation
                 &aux (inputs (list value)))))
  (buffer nil :type buffer))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Printing

(defmethod print-object ((buffer buffer) stream)
  (print-unreadable-object (buffer stream :type t :identity t)
    (format stream "~S ~S"
            (petalisp.type-inference:type-specifier
             (buffer-ntype buffer))
            (buffer-shape buffer))))

(defmethod print-object ((kernel kernel) stream)
  (print-unreadable-object (kernel stream :type t :identity t)
    (format stream "~S"
            (kernel-iteration-space kernel))))

;;; This function is used during printing, to avoid excessive circularity.
(defun simplify-input (input)
  (destructuring-bind (value-n . instruction) input
    (cons value-n (instruction-number instruction))))

(defmethod print-object ((call-instruction call-instruction) stream)
  (print-unreadable-object (call-instruction stream :type t)
    (format stream "~S ~S ~S"
            (instruction-number call-instruction)
            (call-instruction-operator call-instruction)
            (mapcar #'simplify-input (instruction-inputs call-instruction)))))

(defmethod print-object ((load-instruction load-instruction) stream)
  (print-unreadable-object (load-instruction stream :type t)
    (format stream "~S ~S ~S"
            (instruction-number load-instruction)
            :buffer ;(load-instruction-buffer load-instruction)
            (instruction-transformation load-instruction))))

(defmethod print-object ((store-instruction store-instruction) stream)
  (print-unreadable-object (store-instruction stream :type t)
    (format stream "~S ~S ~S ~S"
            (instruction-number store-instruction)
            (simplify-input (first (instruction-inputs store-instruction)))
            :buffer ;(store-instruction-buffer store-instruction)
            (instruction-transformation store-instruction))))

(defmethod print-object ((iref-instruction iref-instruction) stream)
  (print-unreadable-object (iref-instruction stream :type t)
    (format stream "~S ~S"
            (instruction-number iref-instruction)
            (instruction-transformation iref-instruction))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Mapping Functions

(declaim (inline map-buffer-inputs))
(defun map-buffer-inputs (function buffer)
  (declare (function function)
           (buffer buffer))
  (loop for (kernel . nil) in (buffer-writers buffer) do
    (funcall function kernel))
  buffer)

(declaim (inline map-buffer-outputs))
(defun map-buffer-outputs (function buffer)
  (declare (function function)
           (buffer buffer))
  (loop for (kernel . nil) in (buffer-readers buffer) do
    (funcall function kernel))
  buffer)

(declaim (inline map-buffer-load-instructions))
(defun map-buffer-load-instructions (function buffer)
  (declare (function function)
           (buffer buffer))
  (loop for (nil . load-instructions) in (buffer-readers buffer) do
    (loop for load-instruction in load-instructions do
      (funcall function load-instruction)))
  buffer)

(declaim (inline map-buffer-store-instructions))
(defun map-buffer-store-instructions (function buffer)
  (declare (function function)
           (buffer buffer))
  (loop for (nil . store-instructions) in (buffer-writers buffer) do
    (loop for store-instruction in store-instructions do
      (funcall function store-instruction)))
  buffer)

(declaim (inline map-kernel-store-instructions))
(defun map-kernel-store-instructions (function kernel)
  (declare (function function)
           (kernel kernel))
  (loop for (nil . store-instructions) in (kernel-targets kernel) do
    (loop for store-instruction in store-instructions do
      (funcall function store-instruction)))
  kernel)

(declaim (inline map-kernel-load-instructions))
(defun map-kernel-load-instructions (function kernel)
  (declare (function function)
           (kernel kernel))
  (loop for (nil . load-instructions) in (kernel-sources kernel) do
    (loop for load-instruction in load-instructions do
      (funcall function load-instruction)))
  kernel)

(declaim (inline map-kernel-inputs))
(defun map-kernel-inputs (function kernel)
  (declare (function function)
           (kernel kernel))
  (loop for (buffer . nil) in (kernel-sources kernel) do
    (funcall function buffer))
  kernel)

(declaim (inline map-kernel-outputs))
(defun map-kernel-outputs (function kernel)
  (declare (function function)
           (kernel kernel))
  (map-kernel-store-instructions
   (lambda (store-instruction)
     (funcall function (store-instruction-buffer store-instruction)))
   kernel))

(declaim (inline map-instruction-inputs))
(defun map-instruction-inputs (function instruction)
  (declare (function function)
           (instruction instruction))
  (loop for (nil . input) in (instruction-inputs instruction) do
    (funcall function input)))

(defun map-buffers-and-kernels (buffer-fn kernel-fn root-buffers)
  (let ((table (make-hash-table :test #'eq)))
    (labels ((process-buffer (buffer)
               (unless (gethash buffer table)
                 (setf (gethash buffer table) t)
                 (funcall buffer-fn buffer)
                 (map-buffer-inputs #'process-kernel buffer)))
             (process-kernel (kernel)
               (funcall kernel-fn kernel)
               (map-kernel-inputs #'process-buffer kernel)))
      (mapc #'process-buffer root-buffers))))

(defun map-buffers (function root-buffers)
  (map-buffers-and-kernels function #'identity root-buffers))

(defun map-kernels (function root-buffers)
  (map-buffers-and-kernels #'identity function root-buffers))

(defun map-instructions (function kernel)
  (map-kernel-store-instructions
   (lambda (store-instruction)
     (map-instruction-tree function store-instruction))
   kernel))

(defun map-instruction-tree (function root-instruction)
  (labels ((process-node (instruction n)
             (let ((new-n (instruction-number instruction)))
               (when (< new-n n)
                 (funcall function instruction)
                 (map-instruction-inputs
                  (lambda (next) (process-node next new-n))
                  instruction)))))
    (process-node root-instruction most-positive-fixnum)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Transforming Kernels and Buffers

(defgeneric transform-instruction-input (instruction transformation)
  (:method ((instruction instruction)
            (transformation transformation))
    (values))
  (:method ((instruction iterating-instruction)
            (transformation transformation))
    (setf (instruction-transformation instruction)
          (compose-transformations
           (instruction-transformation instruction)
           transformation))))

(defgeneric transform-instruction-output (instruction transformation)
  (:method ((instruction instruction)
            (transformation transformation))
    (values))
  (:method ((instruction iterating-instruction)
            (transformation transformation))
    (setf (instruction-transformation instruction)
          (compose-transformations
           transformation
           (instruction-transformation instruction)))))

(defun transform-buffer (buffer transformation)
  (declare (buffer buffer)
           (transformation transformation))
  (setf (buffer-shape buffer)
        (transform (buffer-shape buffer) transformation))
  ;; After rotating a buffer, rotate all loads and stores referencing the
  ;; buffer to preserve the semantics of the IR.
  (map-buffer-store-instructions
   (lambda (store-instruction)
     (transform-instruction-output store-instruction transformation))
   buffer)
  (map-buffer-load-instructions
   (lambda (load-instruction)
     (transform-instruction-output load-instruction transformation))
   buffer)
  buffer)

(defun transform-kernel (kernel transformation)
  (declare (kernel kernel)
           (transformation transformation))
  (unless (identity-transformation-p transformation)
    (setf (kernel-iteration-space kernel)
          (transform (kernel-iteration-space kernel) transformation))
    (let ((inverse (invert-transformation transformation)))
      (map-instructions
       (lambda (instruction)
         (transform-instruction-input instruction inverse))
       kernel))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Miscellaneous

(defun kernel-number-of-loads (kernel)
  (declare (kernel kernel))
  (let ((counter 0))
    (declare (fixnum counter))
    (map-kernel-load-instructions
     (lambda (_) (declare (ignore _))
       (incf counter))
     kernel)
    counter))

(defun kernel-number-of-stores (kernel)
  (declare (kernel kernel))
  (let ((counter 0))
    (declare (fixnum counter))
    (map-kernel-store-instructions
     (lambda (_) (declare (ignore _))
       (incf counter))
     kernel)
    counter))

(defun kernel-highest-instruction-number (kernel)
  (declare (kernel kernel))
  (let ((max 0))
    ;; This function exploits that the numbers are handed out in
    ;; depth-first order, starting from the leaf instructions.  So we know
    ;; that the highest instruction number must be somewhere among the
    ;; store instructions.
    (map-kernel-store-instructions
     (lambda (store-instruction)
       (alexandria:maxf max (instruction-number store-instruction)))
     kernel)
    max))

(defun kernel-buffers (kernel)
  (let ((buffers '()))
    (map-kernel-load-instructions
     (lambda (load-instruction)
       (pushnew (load-instruction-buffer load-instruction) buffers))
     kernel)
    (map-kernel-store-instructions
     (lambda (store-instruction)
       (pushnew (store-instruction-buffer store-instruction) buffers))
     kernel)
    (nreverse buffers)))

(defun delete-kernel (kernel)
  ;; Only kernels with zero store instructions can be deleted without
  ;; changing semantics.
  (assert (null (kernel-targets kernel)))
  (let ((obsolete-buffers '()))
    (map-kernel-inputs
     (lambda (buffer)
       (let ((new-readers (remove kernel (buffer-readers buffer) :key #'car)))
         (setf (buffer-readers buffer)
               new-readers)
         ;; A buffer that is never read from is obsolete.
         (when (null new-readers)
           (pushnew buffer obsolete-buffers))))
     kernel)
    (mapc #'delete-buffer obsolete-buffers)
    (values)))

(defun delete-buffer (buffer)
  ;; Only buffers with zero readers can be deleted without changing
  ;; semantics.
  (assert (null (buffer-readers buffer)))
  (setf (buffer-storage buffer) nil)
  (let ((obsolete-kernels '()))
    (map-buffer-inputs
     (lambda (kernel)
       (let ((targets (remove buffer (kernel-targets kernel) :key #'car)))
         (setf (kernel-targets kernel)
               targets)
         ;; A kernel with zero store instructions is obsolete.
         (when (null targets)
           (pushnew kernel obsolete-kernels))))
     buffer)
    (mapc #'delete-kernel obsolete-kernels)
    (values)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Assigning Instruction Numbers

(defun assign-instruction-numbers (kernel)
  ;; Step 1 - set all instruction numbers to -1.
  (labels ((clear-instruction-numbers (instruction)
             (unless (= -1 (instruction-number instruction))
               (map-instruction-inputs #'clear-instruction-numbers instruction)
               (setf (instruction-number instruction) -1))))
    (map-kernel-store-instructions #'clear-instruction-numbers kernel))
  ;; Step 2 - assign new instruction numbers.
  (let ((n -1))
    (labels ((assign-instruction-numbers (instruction)
               (when (= -1 (instruction-number instruction))
                 (setf (instruction-number instruction) -2)
                 (map-instruction-inputs #'assign-instruction-numbers instruction)
                 (setf (instruction-number instruction) (incf n)))))
      (map-kernel-store-instructions #'assign-instruction-numbers kernel))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; IR Normalization
;;;
;;; The IR consists of buffers of arbitrary shape, and of kernels that
;;; reference some buffers via arbitrary affine linear transformations.  A
;;; downside of this representation is that it includes a useless degree of
;;; freedom.  We can reshape each buffer with another affine-linear
;;; transformation, as long as we also update the transformations of all
;;; references to the buffer.
;;;
;;; The purpose of this IR transformation is to get rid of this useless
;;; degree of freedom.  To do so, we reshape each buffer such that all
;;; ranges of its shape have a start of zero and a step size of one.  Of
;;; course, we also update all references to each buffer, such that the
;;; semantics is preserved.

(defun normalize-ir (root-buffers)
  (map-buffers #'normalize-buffer root-buffers)
  (map-kernels #'normalize-kernel root-buffers))

(defun normalize-buffer (buffer)
  (transform-buffer buffer (collapsing-transformation (buffer-shape buffer))))

(defun normalize-kernel (kernel)
  (transform-kernel kernel (collapsing-transformation (kernel-iteration-space kernel))))
