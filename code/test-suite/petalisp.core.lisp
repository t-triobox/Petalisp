;;;; © 2016-2019 Marco Heisig         - license: GNU AGPLv3 -*- coding: utf-8 -*-

(in-package #:petalisp.test-suite)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Ranges

(test range-test
  ;; Range constructors
  (is (rangep (make-range 1 0 1)))
  (is (rangep (apply #'range (list 1 2 3))))
  (signals error (make-range 1 0 99))
  ;; Range operations
  (labels ((test-range (range)
             (declare (notinline range-start-step-end size-one-range-p range-end))
             (is (rangep range))
             (with-output-to-string (stream)
               (print range stream))
             (multiple-value-bind (start step end)
                 (range-start-step-end range)
               (is (= start (range-start range)))
               (is (= step (range-step range)))
               (is (= end (range-end range)))
               (is (<= (range-start range)
                       (range-end range))))
             (if (= 1 (range-size range))
                 (is (size-one-range-p range))
                 (is (not (size-one-range-p range))))
             (is (range-equal range range))
             (is (range-equal range (multiple-value-call #'make-range (range-start-step-end range))))
             (if (size-one-range-p range)
                 (is (= (range-start range)
                        (range-end range)))
                 (is (/= (range-start range)
                         (range-end range))))
             (map-range
              (lambda (index)
                (is (range-contains range index)))
              range)
             (is (not (range-contains range (1- (range-start range)))))
             (is (not (range-contains range (1+ (range-end range))))))
           (test-range-pair (range-1 range-2)
             (test-range range-1)
             (test-range range-2)
             (let ((intersection-1 (range-intersection range-1 range-2))
                   (intersection-2 (range-intersection range-1 range-2))
                   (differences-1 (range-difference-list range-1 range-2))
                   (differences-2 (range-difference-list range-2 range-1)))
               (when (range-intersectionp range-1 range-2)
                 (is (range-equal intersection-1 intersection-2))
                 (is (= (reduce #'+ differences-1 :key #'range-size)
                        (- (range-size range-1)
                           (range-size intersection-1))))
                 (is (= (reduce #'+ differences-2 :key #'range-size)
                        (- (range-size range-2)
                           (range-size intersection-2))))))))
    (test-range-pair (range 0) (range 0))
    (test-range-pair (range 0) (range 1))
    (test-range-pair (range -1) (range 1))
    (test-range-pair (range 0 2) (range 1))
    (test-range-pair (range 0 99) (range 1 100))
    (test-range-pair (range 0 2 99) (range 3 100))
    (test-range-pair (range 0 3 50) (range 55 5 100))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Full Programs

(test application-test
  (compute
   (α #'+ 2 3))
  (compute
   (α #'+ #(2 3 4) #(5 4 3)))
  (compute
   (α #'+ #2A((1 2) (3 4)) #2A((4 3) (2 1))))
  (compute
   (α #'floor #(1 2.5 1/2) 2)))

(test reduction-test
  (compute
   (β #'+ #(1 2 3)))
  (compute
   (β #'+ #2A((1 2 3) (6 5 4))))
  (compute
   (β (lambda (lmax lmin rmax rmin)
        (values (max lmax rmax) (min lmin rmin)))
      #(+1 -1 +2 -2 +3 -3)
      #(+1 -1 +2 -2 +3 -3)))
  (compute
   (β (lambda (a b) (values a b)) #(3 2 1))
   (β (lambda (a b) (values b a)) #(3 2 1))))

(test fusion-test
  (compute
   (fuse (reshape (vector 4 5 6) (τ (i) ((+ i 3))))
         (vector 1 2 3)))
  (compute
   (fuse* (reshape 0.0 (~ 2 4 ~ 2 4))
          (reshape 1.0 (~ 3 ~ 3)))))

(test reference-test
  (compute
   (reshape #(1 2 3) (τ (i) ((- i)))) #(3 2 1))
  (compute
   (fuse*
    (reshape #2A((1 2 3) (4 5 6))
             (τ (i j) ((+ 2 i) (+ 3 j))))
    (reshape 9 (τ () (3 4))))))

(test multiple-arguments
  (compute 1 2 3 4 5 6 7 8 9 (α #'+ 5 5) (β #'+ #(1 2 3 4 1))))

(test indices-test
  (compute (indices #(5 6 7)))
  (let ((a (make-array '(2 3 4))))
    (compute (indices a 1))
    (compute (α #'+ (indices a 0) (indices a 1) (indices a 2)))))


(test sum-of-pairs
  (let* ((size 10)
         (a (coerce-to-lazy-array (make-array size :initial-element 0))))
    (compute
     (β #'+ (fuse (reshape a (~ 0 (- size 2))
                           (τ (i) (0 i)))
                  (reshape a (~ 1 (- size 1))
                           (τ (i) (1 (1- i)))))))))

(test reduction-of-fusions
  (compute
   (β #'+ (fuse #(1 2 3)
                (reshape #(4 5 6) (τ (i) ((+ i 3))))))))