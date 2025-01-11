;;;; © 2016-2023 Marco Heisig         - license: GNU AGPLv3 -*- coding: utf-8 -*-

(in-package #:petalisp.codegen)

(deftype index () 'fixnum)

(defparameter *index-ntype* (typo:type-specifier-ntype 'index))

(defun index+ (&rest indices)
  (apply #'+ indices))

(defun index* (&rest indices)
  (apply #'* indices))

(define-compiler-macro index+ (&rest forms)
  `(the index (+ ,@(loop for form in forms collect `(the index ,form)))))

(define-compiler-macro index* (&rest forms)
  `(the index (* ,@(loop for form in forms collect `(the index ,form)))))
