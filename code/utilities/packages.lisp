;;;; © 2016-2020 Marco Heisig         - license: GNU AGPLv3 -*- coding: utf-8 -*-

(cl:in-package #:common-lisp-user)

(defpackage #:petalisp.utilities
  (:use #:common-lisp)
  (:export

   ;; documentation.lisp
   #:document-compiler-macro
   #:document-compiler-macros
   #:document-function
   #:document-functions
   #:document-method-combination
   #:document-method-combinations
   #:document-setf-expander
   #:document-setf-expanders
   #:document-structure
   #:document-structures
   #:document-variable
   #:document-variables

   ;; bitfield.lisp
   #:define-bitfield

   ;; defalias.lisp
   #:defalias

   ;; deque.lisp
   #:deque
   #:dequep
   #:make-deque
   #:deque-push
   #:deque-pop
   #:deque-steal

   ;; extended-euclid.lisp
   #:extended-euclid

   ;; identical.lisp
   #:float-bits
   #:+short-float-bits+
   #:+single-float-bits+
   #:+double-float-bits+
   #:+long-float-bits+

   ;; identical.lisp
   #:identical

   ;; memoization.lisp
   #:with-memoization
   #:with-multiple-value-memoization
   #:with-hash-table-memoization
   #:with-multiple-value-hash-table-memoization
   #:with-vector-memoization
   #:with-multiple-value-vector-memoization

   ;; prime-factors.lisp
   #:prime-factors
   #:primep

   ;; weak-set.lisp
   #:weak-set
   #:weak-set-p
   #:make-weak-set
   #:map-weak-set
   #:weak-set-size
   #:weak-set-add

   ;; with-collectors.lisp
   #:with-collectors

   ;; number-of-cpus.lisp
   #:number-of-cpus
   ))
