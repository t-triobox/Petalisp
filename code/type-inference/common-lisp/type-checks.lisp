;;;; © 2016-2021 Marco Heisig         - license: GNU AGPLv3 -*- coding: utf-8 -*-

(in-package #:petalisp.type-inference)

(defmacro define-type-check (type)
  (check-type type symbol)
  (let ((name (intern (format nil "~@:(the-~A~)" type) #.*package*)))
    `(progn
       (declaim (inline ,name))
       (defun ,name (object)
         (check-type object ,type)
         object)
       (define-differentiator ,name (object) _
         (declare (ignore object))
         1)
       (define-specializer ,name (object)
         (ntype-subtypecase (wrapper-ntype object)
           ((not ,type) (abort-specialization))
           (,type object)
           (t (wrap-default (ntype ',type))))))))

(define-type-check number)
(define-type-check real)
(define-type-check rational)
(define-type-check integer)
(define-type-check float)
(define-type-check short-float)
(define-type-check single-float)
(define-type-check double-float)
(define-type-check long-float)
(define-type-check complex)
(define-type-check complex-short-float)
(define-type-check complex-single-float)
(define-type-check complex-double-float)
(define-type-check complex-long-float)
(define-type-check function)
(define-type-check character)
(define-type-check symbol)

