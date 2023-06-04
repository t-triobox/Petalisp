;;;; © 2016-2023 Marco Heisig         - license: GNU AGPLv3 -*- coding: utf-8 -*-

(in-package #:petalisp.codegen)

(defparameter *function-cpp-info-table*
  (alexandria:alist-hash-table
   '(;; coerce
     (typo:coerce-to-short-float "float" "(float)" :prefix)
     (typo:coerce-to-single-float "float" "(float)" :prefix)
     (typo:coerce-to-double-float "double" "(double)" :prefix)
     (typo:coerce-to-long-float "double" "(double)" :prefix)
     ;; short-float
     (typo:two-arg-short-float+ "float" "+" :infix)
     (typo:two-arg-short-float- "float" "-" :infix)
     (typo:two-arg-short-float* "float" "*" :infix)
     (typo:two-arg-short-float/ "float" "/" :infix)
     (typo:two-arg-short-float-max "float" "fmax" :prefix)
     (typo:two-arg-short-float-min "float" "fmin" :prefix)
     (typo:short-float-abs "float" "fabs" :prefix)
     (typo:short-float-from-single-float "float" "(float)" :prefix)
     (typo:short-float-from-double-float "float" "(float)" :prefix)
     (typo:short-float-from-long-float "float" "(float)" :prefix)
     (typo:short-float-cos "float" "cos" :prefix)
     (typo:short-float-exp "float" "exp" :prefix)
     (typo:short-float-ln "float" "ln" :prefix)
     (typo:short-float-sin "float" "sin" :prefix)
     (typo:short-float-sqrt "float" "sqrt" :prefix)
     (typo:short-float-tan "float" "tan" :prefix)
     (typo:one-arg-short-float- "float" "-" :prefix)
     ;; single-float
     (typo:two-arg-single-float+ "float" "+" :infix)
     (typo:two-arg-single-float- "float" "-" :infix)
     (typo:two-arg-single-float* "float" "*" :infix)
     (typo:two-arg-single-float/ "float" "/" :infix)
     (typo:two-arg-single-float-max "float" "fmax" :prefix)
     (typo:two-arg-single-float-min "float" "fmin" :prefix)
     (typo:single-float-abs "float" "fabs" :prefix)
     (typo:single-float-from-short-float "float" "(float)" :prefix)
     (typo:single-float-from-double-float "float" "(float)" :prefix)
     (typo:single-float-from-long-float "float" "(float)" :prefix)
     (typo:single-float-cos "float" "cos" :prefix)
     (typo:single-float-exp "float" "exp" :prefix)
     (typo:single-float-ln "float" "ln" :prefix)
     (typo:single-float-sin "float" "sin" :prefix)
     (typo:single-float-sqrt "float" "sqrt" :prefix)
     (typo:single-float-tan "float" "tan" :prefix)
     (typo:one-arg-single-float- "float" "-" :prefix)
     ;; double-float
     (typo:two-arg-double-float+ "double" "+" :infix)
     (typo:two-arg-double-float- "double" "-" :infix)
     (typo:two-arg-double-float* "double" "*" :infix)
     (typo:two-arg-double-float/ "double" "/" :infix)
     (typo:two-arg-double-float-max "double" "fmax" :prefix)
     (typo:two-arg-double-float-min "double" "fmin" :prefix)
     (typo:double-float-abs "double" "fabs" :prefix)
     (typo:double-float-from-short-float "double" "(double)" :prefix)
     (typo:double-float-from-single-float "double" "(double)" :prefix)
     (typo:double-float-from-long-float "double" "(double)" :prefix)
     (typo:double-float-cos "double" "cos" :prefix)
     (typo:double-float-exp "double" "exp" :prefix)
     (typo:double-float-ln "double" "ln" :prefix)
     (typo:double-float-sin "double" "sin" :prefix)
     (typo:double-float-sqrt "double" "sqrt" :prefix)
     (typo:double-float-tan "double" "tan" :prefix)
     (typo:one-arg-double-float- "double" "-" :prefix)
     ;; long-float
     (typo:two-arg-long-float+ "double" "+" :infix)
     (typo:two-arg-long-float- "double" "-" :infix)
     (typo:two-arg-long-float* "double" "*" :infix)
     (typo:two-arg-long-float/ "double" "/" :infix)
     (typo:two-arg-long-float-max "double" "fmax" :prefix)
     (typo:two-arg-long-float-min "double" "fmin" :prefix)
     (typo:long-float-abs "double" "fabs" :prefix)
     (typo:long-float-from-short-float "double" "(double)" :prefix)
     (typo:long-float-from-single-float "double" "(double)" :prefix)
     (typo:long-float-from-double-float "double" "(double)" :prefix)
     (typo:long-float-cos "double" "cos" :prefix)
     (typo:long-float-exp "double" "exp" :prefix)
     (typo:long-float-ln "double" "ln" :prefix)
     (typo:long-float-sin "double" "sin" :prefix)
     (typo:long-float-sqrt "double" "sqrt" :prefix)
     (typo:long-float-tan "double" "tan" :prefix)
     (typo:one-arg-long-float- "double" "-" :prefix))))

(defun function-cpp-translatable-p (function-name)
  (nth-value 1 (gethash function-name *function-cpp-info-table*)))

(defun function-cpp-info (function-name)
  "Returns the C++ type, function name, and kind (:infix or :prefix) of the supplied Lisp function name.
Signals an error if no equivalent C++ function exists."
  (values-list
   (or (gethash function-name *function-cpp-info-table*)
       (error "Cannot create C++ kernels that call ~S." function-name))))

(defun ntype-cpp-translatable-p (ntype)
  (ntype-cpp-info ntype nil))

(defun ntype-cpp-info (ntype &optional (errorp t))
  (typo:ntype-subtypecase ntype
    (short-float "float")
    (single-float "float")
    (double-float "double")
    (long-float "double")
    ((signed-byte 8) "int8_t")
    ((unsigned-byte 8) "uint8_t")
    ((signed-byte 16) "int16_t")
    ((unsigned-byte 16) "uint16_t")
    ((signed-byte 32) "int32_t")
    ((unsigned-byte 32) "uint32_t")
    ((signed-byte 64) "int64_t")
    ((unsigned-byte 64) "uint64_t")
    (t
     (when errorp
       (error "Cannot create C++ kernels operating on values of type ~S."
              (typo:ntype-type-specifier ntype))))))

(defun blueprint-cpp-translatable-p (blueprint)
  "Returns whether the supplied blueprint can be translated to C++.  This is the
case when each array element type has a C++ equivalent, and when all function
calls therein have a C++ equivalent."
  (let ((targets (ucons:unth 1 blueprint))
        (sources (ucons:unth 2 blueprint))
        (instructions (ucons:unthcdr 3 blueprint)))
    (flet ((check-ref (ref)
             (unless (ntype-cpp-translatable-p (ucons:unth 0 ref))
               (return-from blueprint-cpp-translatable-p nil)))
           (check-fn (fn)
             (when (eq fn :any)
               (return-from blueprint-cpp-translatable-p nil))
             (unless (function-cpp-translatable-p fn)
               (return-from blueprint-cpp-translatable-p nil))))
      (ucons:do-ulist (target targets) (check-ref target))
      (ucons:do-ulist (source sources) (check-ref source))
      (ucons:do-ulist (instruction-blueprint instructions)
        (trivia:match instruction-blueprint
          ((ucons:ulist* :call 1 function-name _)
           (check-fn function-name))))))
  t)
