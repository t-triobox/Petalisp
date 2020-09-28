;;;; © 2016-2020 Marco Heisig         - license: GNU AGPLv3 -*- coding: utf-8 -*-

(in-package #:petalisp.ir)

;;; The purpose of IR conversion is to turn a data flow graph, whose nodes
;;; are lazy arrays, into an analogous graph, whose nodes are buffers and
;;; kernels.  Kernels and buffers alternate, such that the inputs and
;;; outputs of a kernel are always buffers, and such that the inputs and
;;; outputs of a buffer are always kernels.
;;;
;;; The main data structure IR conversion algorithm are so called dendrites
;;; that grow from the lazy arrays that are the graph roots and along their
;;; inputs.  When a dendrite reaches an immediate, its growth stops.  While
;;; growing, dendrites create the instructions of a particular kernel,
;;; while keeping track of the current transformation and shape.  When a
;;; dendrite grows over a lazy array has more than one input, the dendrite
;;; branches out into multiple dendrites.  Each dendrite has a stem that
;;; tracks the kernel being generated.  All dendrites that are the result
;;; of branching out this way share the same stem.
;;;
;;; Whenever a dendrite reaches a lazy array with a refcount larger than
;;; one, or a lazy array that follows a broadcasting reshape operation, its
;;; growth is suspended and we record that this dendrite has reached that
;;; lazy array.  The data structure that tracks which dendrites have
;;; reached a particular lazy array is called a cluster.  Once the growth
;;; of all dendrites has been suspended or stopped, we pick the cluster
;;; whose lazy array has the highest depth from a priority queue.  This
;;; cluster is now turned into one or more buffers, and each buffer is the
;;; root of a stem with a single dendrite that is grown further.  Once
;;; there are no further clusters, the IR conversion is complete.
;;;
;;; A special case occurs when a dendrite reaches a fusion node with
;;; multiple inputs that intersect with the dendrite's shape.  In such a
;;; case, we want to replace the current kernel by multiple kernels, while
;;; choosing the iteration space of each kernel such that it reaches only a
;;; single input of the fusion node.  We achieve this by deleting both the
;;; stem's kernel, and all dendrites that originate from that stem.  Then
;;; we restart with one stem and kernel for each suitable subspace of the
;;; original stem.  In doing so, we eliminate fusion nodes altogether from
;;; the IR.

(defstruct ir-converter
  ;; A priority queue of clusters, sorted by the depth of the corresponding
  ;; lazy arrays.
  (pqueue (priority-queue:make-pqueue #'>))
  ;; A hash table, mapping from lazy arrays to clusters.
  (cluster-table (make-hash-table :test #'eq) :type hash-table)
  ;; A hash table, mapping from Common Lisp arrays to buffers.
  (array-table (make-hash-table :test #'eq) :type hash-table)
  ;; A hash table, mapping from Common Lisp scalars to buffers of rank zero
  ;; containing those scalars.
  (scalar-table (make-hash-table :test #'eql) :type hash-table)
  ;; A list of lists of conses that need to be updated by writing the value
  ;; of the cdr of the first cons to the cdr of each remaining cons.
  (cons-updates '() :type list))

(defun ir-converter-next-cluster (ir-converter)
  (priority-queue:pqueue-pop
   (ir-converter-pqueue ir-converter)))

(defun ir-converter-empty-p (ir-converter)
  (priority-queue:pqueue-empty-p
   (ir-converter-pqueue ir-converter)))

(declaim (ir-converter *ir-converter*))
(defvar *ir-converter*)

(defstruct (cluster
            (:constructor make-cluster (lazy-array)))
  ;; The cluster's lazy array.
  (lazy-array nil :type lazy-array)
  ;; A list of dendrites that have reached this cluster.
  (dendrites '() :type list))

(defun ensure-cluster (lazy-array)
  (alexandria:ensure-gethash
   lazy-array
   (ir-converter-cluster-table *ir-converter*)
   (let ((cluster (make-cluster lazy-array)))
     (priority-queue:pqueue-push
      cluster
      (lazy-array-depth lazy-array)
      (ir-converter-pqueue *ir-converter*))
     cluster)))

(defun cluster-ntype (cluster)
  (declare (cluster cluster))
  (element-ntype (cluster-lazy-array cluster)))

(defun cluster-shape (cluster)
  (declare (cluster cluster))
  (lazy-array-shape (cluster-lazy-array cluster)))

(defstruct (stem
            (:constructor make-stem (cluster kernel)))
  ;; The cluster in which the stem is rooted.
  (cluster nil :type cluster)
  ;; The kernel that is grown from that stem.
  (kernel nil :type kernel)
  ;; A stem is turned invalid when one of its dendrites reaches more than
  ;; one input of a lazy fuse node.
  (validp t :type boolean))

(defstruct (dendrite
            (:constructor %make-dendrite)
            (:copier copy-dendrite))
  ;; The stem from which this dendrite originated.
  (stem nil :type stem)
  ;; The shape of the iteration space referenced by the dendrite.
  (shape nil :type shape)
  ;; A transformation from the dendrite's shape to the iteration space of
  ;; the dendrite's kernel.
  (transformation nil :type transformation)
  ;; The depth of the cluster most recently visited by this dendrite.
  (depth nil :type unsigned-byte)
  ;; The cons cell whose car is to be filled with a cons cell whose cdr is
  ;; the next instruction, and whose car is an integer denoting which of
  ;; the multiple values of the cdr is being referenced.
  (cons nil :type cons))

(defun dendrite-kernel (dendrite)
  (declare (dendrite dendrite))
  (stem-kernel (dendrite-stem dendrite)))

(defun dendrite-cluster (dendrite)
  (declare (dendrite dendrite))
  (stem-cluster (dendrite-stem dendrite)))

(defun dendrite-validp (dendrite)
  (declare (dendrite dendrite))
  (stem-validp (dendrite-stem dendrite)))

(defun make-dendrite
    (cluster shape &optional (buffer (make-buffer :shape shape :ntype (cluster-ntype cluster))))
  (declare (cluster cluster) (shape shape) (buffer buffer))
  (let* ((cons (cons 0 nil))
         (transformation (identity-transformation (shape-rank shape)))
         (store-instruction (make-store-instruction cons buffer transformation))
         (kernel (make-kernel :iteration-space shape))
         (stem (make-stem cluster kernel))
         (dendrite (%make-dendrite
                    :stem stem
                    :shape shape
                    :transformation transformation
                    :depth (lazy-array-depth (cluster-lazy-array cluster))
                    :cons cons)))
    (push store-instruction (alexandria:assoc-value (kernel-targets kernel) buffer))
    (push store-instruction (alexandria:assoc-value (buffer-writers buffer) kernel))
    dendrite))

(defun mergeable-dendrites-p (d1 d2)
  (and (eq
        (dendrite-stem d1)
        (dendrite-stem d2))
       (shape-equal
        (dendrite-shape d1)
        (dendrite-shape d2))
       (transformation-equal
        (dendrite-transformation d1)
        (dendrite-transformation d2))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; IR Conversion

(defun ir-from-lazy-arrays (lazy-arrays)
  (let ((*ir-converter* (make-ir-converter))
        (root-buffers '()))
    ;; Create and grow one dendrite for each root array.
    (loop for lazy-array in lazy-arrays do
      (let* ((cluster (make-cluster lazy-array))
             (dendrite (make-dendrite cluster (lazy-array-shape lazy-array))))
        (push (caar (kernel-targets (stem-kernel (dendrite-stem dendrite))))
              root-buffers)
        (grow-dendrite dendrite lazy-array)))
    ;; Successively convert all clusters.
    (loop until (ir-converter-empty-p *ir-converter*)
          for cluster = (ir-converter-next-cluster *ir-converter*)
          do (convert-cluster cluster (cluster-lazy-array cluster)))
    ;; Update all cons cells whose instruction couldn't be determined
    ;; immediately at cluster conversion time.
    (loop for (cons . other-conses) in (ir-converter-cons-updates *ir-converter*) do
      (let ((instruction (cdr cons)))
        (assert (instructionp instruction))
        (loop for other-cons in other-conses do
          (setf (cdr other-cons) instruction))))
    (normalize-ir root-buffers)
    (nreverse root-buffers)))

(defun normalize-ir (root-buffers)
  (map-buffers #'normalize-buffer root-buffers)
  (map-kernels #'normalize-kernel root-buffers))

(defun normalize-buffer (buffer)
  (transform-buffer buffer (collapsing-transformation (buffer-shape buffer))))

(defun normalize-kernel (kernel)
  (kernel-instruction-vector kernel)
  (transform-kernel kernel (collapsing-transformation (kernel-iteration-space kernel))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Cluster Conversion

(defgeneric convert-cluster (cluster lazy-array))

;;; Under certain circumstances, there is no need to convert the current
;;; cluster at all.  This around method handles these cases.  It also
;;; removes all dendrites that have been invalidated.
(defmethod convert-cluster :around
    ((cluster cluster)
     (non-immediate non-immediate))
  ;; Since clusters are converted in depth-first order, and since all
  ;; further lazy arrays have a depth less than the current cluster, there
  ;; is no need to keep the current cluster in the cluster table.  No new
  ;; dendrites will ever reach it.
  (remhash non-immediate (ir-converter-cluster-table *ir-converter*))
  ;; Now we remove all invalid dendrites.  Recall that dendrites can become
  ;; invalid if they, or another dendrite with the same stem, reach more
  ;; than one input of a lazy fuse array.
  (let ((valid-dendrites (remove-if-not #'dendrite-validp (cluster-dendrites cluster))))
    (setf (cluster-dendrites cluster) valid-dendrites)
    (cond
      ;; If there are zero valid dendrites, the cluster can be ignored
      ((null valid-dendrites)
       (values))
      ;; If all dendrites have the same stem, shape, and transformation,
      ;; there is no need to convert this cluster at all.  We can simply
      ;; continue growing from here.
      ((and (petalisp.utilities:identical valid-dendrites :test #'mergeable-dendrites-p)
            (transformation-invertiblep (dendrite-transformation (first valid-dendrites))))
       (let* ((dendrite (first valid-dendrites))
              (other-dendrites (rest valid-dendrites))
              (cons (dendrite-cons dendrite)))
         (setf (dendrite-depth dendrite)
               (lazy-array-depth non-immediate))
         (grow-dendrite dendrite non-immediate)
         (unless (null other-dendrites)
           (if (instructionp (cdr cons))
               (loop for other-dendrite in other-dendrites do
                 (setf (cdr (dendrite-cons other-dendrite))
                       (cdr cons)))
               (push (list* cons (mapcar #'dendrite-cons other-dendrites))
                     (ir-converter-cons-updates *ir-converter*))))))
      ;; Otherwise, actually convert the cluster.
      (t (call-next-method)))))

(defmethod convert-cluster
    ((cluster cluster)
     (non-immediate non-immediate))
  (let ((dendrites (cluster-dendrites cluster))
        (alist '())
        (buffers '()))
    ;; Compute an alist from shapes to dendrites that will write into a
    ;; buffer of that shape.
    (loop for dendrite in dendrites do
      (block convert-one-dendrite
        (let ((dshape (dendrite-shape dendrite)))
          (loop for entry in alist do
            (let* ((eshape (car entry))
                   (cover (fuse-shapes eshape dshape)))
              (when (<= (* (shape-size cover) 0.75)
                        (+ (shape-size dshape)
                           (shape-size eshape)))
                (setf (car entry) cover)
                (push dendrite (cdr entry))
                (return-from convert-one-dendrite)))
                finally (push `(,dshape ,dendrite) alist)))))
    ;; Create one buffer per alist entry and insert the corresponding load
    ;; instructions.
    (loop for (shape . mergeable-dendrites) in alist do
      (let ((buffer (make-buffer :shape shape :ntype (cluster-ntype cluster))))
        (push buffer buffers)
        (loop for dendrite in mergeable-dendrites do
          (with-accessors ((cons dendrite-cons)
                           (kernel dendrite-kernel)
                           (transformation dendrite-transformation)) dendrite
            (let ((load-instruction (make-load-instruction buffer transformation)))
              (setf (cdr cons) load-instruction)
              (push load-instruction (alexandria:assoc-value (kernel-sources kernel) buffer))
              (push load-instruction (alexandria:assoc-value (buffer-readers buffer) kernel)))))))
    (setf buffers (nreverse buffers))
    ;; Now subdivide the space of all buffers and emit one kernel per
    ;; resulting fragment, plus some copy kernels if the fragment is part
    ;; of the shapes of several buffers.
    (let ((fragments (subdivide-shapes (mapcar #'first alist))))
      (loop for (shape . bitmask) in fragments do
        (let ((target-buffers
                (loop for buffer in buffers
                      for index from 0
                      when (logbitp index bitmask)
                        collect buffer)))
          (let ((main-buffer (first target-buffers)))
            (grow-dendrite (make-dendrite cluster shape main-buffer) non-immediate)
            ;; Finally, emit copy kernels from the main buffer to all the
            ;; other buffers.
            (loop for target-buffer in (rest target-buffers) do
              (insert-copy-kernel shape target-buffer main-buffer))))))))

(defun insert-copy-kernel (iteration-space target-buffer source-buffer)
  (let* ((rank (shape-rank iteration-space))
         (transformation (identity-transformation rank))
         (load (make-load-instruction source-buffer transformation))
         (store (make-store-instruction
                 (cons 0 load)
                 target-buffer
                 (identity-transformation (shape-rank iteration-space))))
         (kernel
           (make-kernel
            :iteration-space iteration-space
            :sources `((,source-buffer ,load))
            :targets `((,target-buffer ,store)))))
    (push `(,kernel ,load) (buffer-readers source-buffer))
    (push `(,kernel ,store) (buffer-writers target-buffer))
    kernel))

(defmethod convert-cluster
    ((cluster cluster)
     (lazy-multiple-value-map lazy-multiple-value-map))
  (convert-lazy-multiple-value-map
   lazy-multiple-value-map
   (cluster-dendrites cluster)))

(defun convert-lazy-multiple-value-map
    (lazy-multiple-value-map dendrites)
  (let ((inputs (inputs lazy-multiple-value-map))
        (mergeable-dendrites-list '()))
    (loop for dendrite in dendrites do
      (let ((entry (find dendrite mergeable-dendrites-list
                         :key #'car
                         :test #'mergeable-dendrites-p)))
        (if (not entry)
            (push (list dendrite) mergeable-dendrites-list)
            (push dendrite (cdr entry)))))
    (loop for mergeable-dendrites in mergeable-dendrites-list do
      (let* ((input-conses (loop for input in inputs collect (cons 0 input)))
             (instruction
               (make-call-instruction
                (number-of-values lazy-multiple-value-map)
                (operator lazy-multiple-value-map)
                input-conses)))
        (loop for dendrite in mergeable-dendrites do
          (setf (cdr (dendrite-cons dendrite))
                instruction))
        (loop for input in inputs
              for input-cons in input-conses
              for input-dendrite = (copy-dendrite (first mergeable-dendrites))
              for depth = (lazy-array-depth lazy-multiple-value-map)
              do (setf (dendrite-cons input-dendrite) input-cons)
              do (grow-dendrite input-dendrite input))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Dendrite Growing

(defgeneric grow-dendrite (dendrite lazy-array))

(defmethod grow-dendrite :around
    ((dendrite dendrite)
     (non-immediate non-immediate))
  (if (and (< (lazy-array-depth non-immediate)
              (dendrite-depth dendrite))
           (> (lazy-array-refcount non-immediate) 1))
      (push dendrite (cluster-dendrites (ensure-cluster non-immediate)))
      (call-next-method)))

(defmethod grow-dendrite
    ((dendrite dendrite)
     (lazy-fuse lazy-fuse))
  (with-accessors ((shape dendrite-shape)
                   (transformation dendrite-transformation)
                   (stem dendrite-stem)
                   (cons dendrite-cons)) dendrite
    (let* ((inputs (inputs lazy-fuse))
           (intersections
             (loop for input in inputs
                   for intersection = (shape-intersection shape (lazy-array-shape input))
                   collect intersection)))
      (case (count-if-not #'empty-shape-p intersections)
        (0 (error "Erroneous fusion."))
        (1 (let ((input (nth (position-if-not #'empty-shape-p intersections) inputs)))
             (grow-dendrite dendrite input)))
        (otherwise
         (let* ((kernel (dendrite-kernel dendrite))
                (buffer (caar (kernel-targets kernel))))
           (setf (stem-validp stem) nil)
           (delete-kernel kernel)
           ;; Invalidate the current kernel and its dendrites.  Try growing
           ;; from the cluster again, but with one stem for each reachable
           ;; fusion input.
           (loop for input in inputs
                 for intersection in intersections
                 unless (empty-shape-p intersection)
                   do (grow-dendrite
                       (make-dendrite
                        (stem-cluster stem)
                        (transform intersection (invert-transformation transformation))
                        buffer)
                       (cluster-lazy-array (stem-cluster stem))))))))))

(defmethod grow-dendrite
    ((dendrite dendrite)
     (lazy-reshape lazy-reshape))
  (with-accessors ((shape dendrite-shape)
                   (transformation dendrite-transformation)) dendrite
    (setf shape (transform
                 (shape-intersection shape (lazy-array-shape lazy-reshape))
                 (transformation lazy-reshape)))
    (setf transformation (compose-transformations
                          (transformation lazy-reshape)
                          transformation))
    (grow-dendrite dendrite (input lazy-reshape))))

(defmethod grow-dendrite
    ((dendrite dendrite)
     (lazy-map lazy-map))
  (with-accessors ((shape dendrite-shape)
                   (transformation dendrite-transformation)
                   (cons dendrite-cons)) dendrite
    (let* ((inputs (inputs lazy-map))
           (input-conses (loop for input in inputs collect (cons 0 input))))
      (setf (cdr cons)
            (make-call-instruction 1 (operator lazy-map) input-conses))
      ;; If our function has zero inputs, we are done.  Otherwise we create
      ;; one dendrite for each input (except the first one, for which we
      ;; can reuse the current dendrite) and continue growing.
      (unless (null inputs)
        (loop for input in inputs
              for input-cons in input-conses do
                (let ((new-dendrite (copy-dendrite dendrite)))
                  (setf (dendrite-cons new-dendrite) input-cons)
                  (grow-dendrite new-dendrite input)))))))

(defmethod grow-dendrite
    ((dendrite dendrite)
     (lazy-multiple-value-map lazy-multiple-value-map))
  (convert-lazy-multiple-value-map lazy-multiple-value-map (list dendrite)))

(defmethod grow-dendrite
    ((dendrite dendrite)
     (lazy-multiple-value-ref lazy-multiple-value-ref))
  (with-accessors ((cons dendrite-cons)) dendrite
    (setf (car cons)
          (value-n lazy-multiple-value-ref)))
  (grow-dendrite dendrite (input lazy-multiple-value-ref)))

(defmethod grow-dendrite
    ((dendrite dendrite)
     (array-immediate array-immediate))
  (with-accessors ((shape dendrite-shape)
                   (transformation dendrite-transformation)
                   (stem dendrite-stem)
                   (cons dendrite-cons)) dendrite
    (let* ((kernel (stem-kernel stem))
           (shape (lazy-array-shape array-immediate))
           (ntype (element-ntype array-immediate))
           (storage (storage array-immediate))
           (buffer
             (if (zerop (shape-rank shape))
                 (alexandria:ensure-gethash
                  (aref (storage array-immediate))
                  (ir-converter-scalar-table *ir-converter*)
                  (make-buffer :shape shape :ntype ntype :storage storage))
                 (alexandria:ensure-gethash
                  (storage array-immediate)
                  (ir-converter-array-table *ir-converter*)
                  (make-buffer :shape shape :ntype ntype :storage storage))))
           (load-instruction (make-load-instruction buffer transformation)))
      (push load-instruction (alexandria:assoc-value (kernel-sources kernel) buffer))
      (push load-instruction (alexandria:assoc-value (buffer-readers buffer) kernel))
      (setf (cdr cons) load-instruction))))

(defmethod grow-dendrite
    ((dendrite dendrite)
     (range-immediate range-immediate))
  (with-accessors ((cons dendrite-cons)
                   (transformation dendrite-transformation)) dendrite
    (setf (cdr cons)
          (make-iref-instruction transformation))))
