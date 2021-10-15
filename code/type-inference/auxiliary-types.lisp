;;;; © 2016-2021 Marco Heisig         - license: GNU AGPLv3 -*- coding: utf-8 -*-

(in-package #:petalisp.type-inference)

;;; Some objects in the Common Lisp standard have a straightforward
;;; definition, but there is no corresponding type in the CL package.
;;; Instead, we define them here.

(deftype function-name ()
  '(or
    (and symbol (not null))
    (cons (eql setf) (cons symbol nil))))

(deftype function-designator ()
  '(or (and symbol (not null)) function))

(deftype character-designator ()
  '(or (vector character 1) character))

(deftype string-designator ()
  '(or character symbol string))

(deftype package-designator ()
  '(or package string-designator))

(deftype radix ()
  '(integer 2 36))

(deftype character-code ()
  '(integer 0 (#.char-code-limit)))

(deftype arity ()
  '(integer 0 (#.call-arguments-limit)))

(deftype argument-index ()
  '(integer 0 (#.(1- call-arguments-limit))))

;; The representation of byte specifiers is implementation-dependent.
;; However, under the not-so-bold assumption that each implementation
;; consistently uses a uniform representation, we can get surprisingly far.
(deftype byte-specifier ()
  (load-time-value
   (let ((a (byte 0 0))
         (b (byte 16 253)))
     (if (equal (type-of a)
                (type-of b))
         (type-of a)
         't))))

(deftype complex-short-float ()
  '(complex short-float))

(deftype complex-single-float ()
  '(complex single-float))

(deftype complex-double-float ()
  '(complex double-float))

(deftype complex-long-float ()
  '(complex long-float))

(deftype generalized-boolean ()
  't)

(deftype multiple-value-count ()
  `(integer 0 ,multiple-values-limit))

(deftype type-specifier ()
  t)

(deftype zero ()
  '(member 0 0S0 -0S0 0F0 -0F0 0D0 -0D0 0L0 -0L0
    #C(0S0 0S0) #C(0S0 -0S0) #C(-0S0 0S0) #C(-0S0 -0S0)
    #C(0F0 0F0) #C(0F0 -0F0) #C(-0F0 0F0) #C(-0F0 -0F0)
    #C(0D0 0D0) #C(0D0 -0D0) #C(-0D0 0D0) #C(-0D0 -0D0)
    #C(0L0 0L0) #C(0L0 -0L0) #C(-0L0 0L0) #C(-0L0 -0L0)))
