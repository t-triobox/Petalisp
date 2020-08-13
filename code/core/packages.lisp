;;;; © 2016-2020 Marco Heisig         - license: GNU AGPLv3 -*- coding: utf-8 -*-

(cl:in-package #:common-lisp-user)

(defpackage #:petalisp.core
  (:use #:common-lisp)

  (:import-from
   #:petalisp.utilities
   #:document-compiler-macro
   #:document-function
   #:document-functions
   #:document-method-combination
   #:document-setf-expander
   #:document-structure
   #:document-type
   #:document-variable
   #:document-variables)

  (:export

   ;; Ranges
   #:range
   #:rangep
   #:size-one-range-p
   #:split-range
   #:map-range
   #:range-equal
   #:range-contains
   #:range-intersection
   #:range-intersectionp
   #:range-difference-list
   #:range-start-step-end
   #:range-start
   #:range-step
   #:range-end
   #:range-size
   #:subrangep
   #:fuse-ranges

   ;; Shapes
   #:~
   #:~l
   #:~s
   #:~r
   #:shape
   #:shapep
   #:shape-rank
   #:shape-ranges
   #:shape-dimensions
   #:shape-size
   #:shape-equal
   #:shape-difference-list
   #:shape-intersection
   #:shape-intersectionp
   #:map-shape
   #:shape-contains
   #:shrink-shape
   #:enlarge-shape
   #:subdivide
   #:subshapep
   #:fuse-shapes

   ;; Transformations
   #:τ
   #:transformation
   #:transformationp
   #:transform
   #:transform-axis
   #:identity-transformation-p
   #:transformation-input-rank
   #:transformation-output-rank
   #:transformation-input-mask
   #:transformation-output-mask
   #:transformation-offsets
   #:transformation-scalings
   #:transformation-invertiblep
   #:make-transformation
   #:identity-transformation
   #:invert-transformation
   #:transformation-equal
   #:transformation-similar
   #:compose-transformations
   #:collapsing-transformation
   #:normalizing-transformation
   #:enlarge-transformation
   #:map-transformation-inputs
   #:map-transformation-outputs

   ;; Lazy Arrays
   #:lazy-array-p
   #:empty-array-p
   #:immediatep
   #:reusablep
   #:lazy-array
   #:parameter
   #:optional-parameter
   #:optional-parameter-value
   #:replace-lazy-array
   #:total-size
   #:element-type
   #:element-ntype
   #:rank
   #:input
   #:inputs
   #:value-n
   #:number-of-values
   #:operator
   #:storage
   #:refcount
   #:depth
   #:lazy-array
   #:lazy-map
   #:single-value-lazy-map
   #:multiple-value-lazy-map
   #:lazy-reshape
   #:lazy-fuse
   #:immediate
   #:non-immediate
   #:empty-array
   #:empty-arrays
   #:non-empty-array
   #:non-empty-immediate
   #:non-empty-non-immediate
   #:array-immediate
   #:range-immediate
   #:move-axis-to-front
   #:empty-array
   #:make-array-immediate
   #:make-range-immediate
   #:indices
   #:broadcast
   #:broadcast-arrays
   #:broadcast-list-of-arrays
   #:copy-arrays
   #:substitute-arrays

   ;; Machine Model
   #:memory
   #:memory-name
   #:memory-parent
   #:memory-children
   #:memory-processors
   #:memory-size
   #:memory-granularity
   #:memory-latency
   #:memory-bandwidth
   #:memory-parent-bandwidth
   #:processor
   #:processor-name
   #:processor-memory
   #:machine
   #:machine-name
   #:machine-processors
   #:machine-main-memory
   #:host-machine

   ;; Backend
   #:*backend*
   #:backend-machine
   #:compute-on-backend
   #:schedule-on-backend
   #:compile-network-on-backend
   #:compute-immediates
   #:lisp-datum-from-immediate
   #:backend
   #:asynchronous-backend
   #:delete-backend
   #:compute
   #:schedule))
