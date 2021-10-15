;;;; © 2016-2021 Marco Heisig         - license: GNU AGPLv3 -*- coding: utf-8 -*-

(cl:in-package #:common-lisp-user)

(defpackage #:petalisp.multicore-backend
  (:use
   #:common-lisp
   #:petalisp.core)
  (:export
   #:make-multicore-backend))
