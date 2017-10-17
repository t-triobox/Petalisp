;;; © 2016-2017 Marco Heisig - licensed under AGPLv3, see the file COPYING

(in-package :petalisp)

(define-task-queue global-evaluator-thread)

(defun schedule-asynchronously (data-structures)
  (assert (every #'strided-array? data-structures))
  (let* ((recipes (map 'vector #'shallow-copy data-structures))
         (targets (map 'vector (λ x (change-class x 'intermediate-result)) data-structures))
         (request (make-request)))
    (run-in-global-evaluator-thread
     (λ
      (labels ((evaluate (intermediate-result)
                 (iterate
                   (for kernel in (kernels intermediate-result))
                   (iterate (for binding in-vector (bindings kernel))
                            (when (and (intermediate-result? binding)
                                       (not (storage binding)))
                              (evaluate binding))))
                 (evaluate-intermediate-result intermediate-result)))
        (iterate (for item in-sequence (kernelize recipes))
                 (for index from 0)
                 (setf (storage (aref targets index))
                       (storage (evaluate item))))
        (complete request))))
    request))

(defun evaluate-intermediate-result (intermediate-result)
  ;; allocate memory
  (bind-memory intermediate-result)
  (setf (refcount intermediate-result)
        (count-if #'intermediate-result? (users intermediate-result)))
  ;; compute all kernels
  (iterate
    (for kernel in (kernels intermediate-result))
    (evaluate-kernel kernel)
    ;; potentially free predecessor memory
    (iterate
      (for binding in-vector (bindings kernel))
      (when (intermediate-result? binding)
        (when (= 0 (decf (refcount binding)))
          (free-memory binding)))))
  intermediate-result)
