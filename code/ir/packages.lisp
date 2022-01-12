;;;; © 2016-2022 Marco Heisig         - license: GNU AGPLv3 -*- coding: utf-8 -*-

(cl:in-package #:common-lisp-user)

(defpackage #:petalisp.ir
  (:use
   #:common-lisp
   #:petalisp.core)

  (:import-from
   #:petalisp.utilities
   #:document-variable
   #:document-function)

  (:export
   ;; IR Conversion
   #:ir-from-lazy-arrays

   ;; Structs
   #:instruction
   #:buffer
   #:kernel
   #:task
   #:instruction
   #:iterating-instruction
   #:call-instruction
   #:load-instruction
   #:store-instruction
   #:iref-instruction

   ;; Predicates
   #:bufferp
   #:leaf-buffer-p
   #:root-buffer-p
   #:interior-buffer-p
   #:kernelp
   #:taskp
   #:instructionp
   #:call-instruction-p
   #:iterating-instruction-p
   #:iref-instruction-p
   #:load-instruction-p
   #:store-instruction-p

   ;; Constructors
   #:make-kernel
   #:make-buffer
   #:make-task

   ;; Mapping
   #:map-buffers-and-kernels
   #:map-kernels
   #:map-buffers
   #:map-buffer-inputs
   #:map-buffer-outputs
   #:map-buffer-load-instructions
   #:map-buffer-store-instructions
   #:map-kernel-store-instructions
   #:map-kernel-load-instructions
   #:map-kernel-inputs
   #:map-kernel-outputs
   #:map-kernel-instructions
   #:map-instruction-inputs
   #:map-task-kernels
   #:map-task-defined-buffers

   ;; Accessors
   #:buffer-shape
   #:buffer-size
   #:buffer-ntype
   #:buffer-depth
   #:buffer-storage
   #:buffer-data
   #:buffer-number-of-inputs
   #:buffer-number-of-outputs
   #:buffer-number-of-loads
   #:buffer-number-of-stores
   #:kernel-iteration-space
   #:kernel-blueprint
   #:kernel-instruction-vector
   #:kernel-number-of-inputs
   #:kernel-number-of-outputs
   #:kernel-number-of-loads
   #:kernel-number-of-stores
   #:kernel-cost
   #:kernel-data
   #:task-predecessors
   #:task-successors
   #:task-kernels
   #:task-defined-buffers
   #:task-live-buffers
   #:instruction-number
   #:instruction-inputs
   #:instruction-transformation
   #:call-instruction-operator
   #:store-instruction-buffer
   #:load-instruction-buffer

   ;; Devices, Workers, and Memory
   #:device
   #:device-name
   #:device-memory
   #:device-workers
   #:host-device
   #:worker
   #:worker-name
   #:worker-memory
   #:memory
   #:memory-name
   #:memory-parent
   #:memory-children
   #:memory-workers
   #:memory-size
   #:memory-granularity
   #:memory-latency
   #:memory-bandwidth
   #:memory-parent-bandwidth

   ;; Miscellaneous
   #:make-ir-backend
   #:check-ir
   #:interpret-kernel
   #:compile-kernel
   #:translate-blueprint))
