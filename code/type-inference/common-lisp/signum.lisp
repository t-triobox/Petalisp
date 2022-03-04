;;;; © 2016-2022 Marco Heisig         - license: GNU AGPLv3 -*- coding: utf-8 -*-

(in-package #:petalisp.type-inference)

(define-specializer signum (number)
  (let ((ntype (wrapper-ntype number)))
    (with-constant-folding (signum (ntype number))
      (ntype-subtypecase ntype
        (rational (wrap-default (ntype 'integer)))
        ((or float (complex float)) (wrap-default ntype))
        (complex (wrap-default (ntype 'complex)))
        (t (wrap-default 'number))))))

(define-differentiator signum (number) index
  (declare (ignore number))
  ;; Should I care about the discontinuity at zero?  Nah.
  0)
