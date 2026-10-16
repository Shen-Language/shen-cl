;;; Copyright (c) 2026 Bruno Deferrari. BSD 3-Clause License.
(in-package :shen)

(declaim (inline |shen-cl.dict-entry| |shen-cl.dict-store|
                 |shen-cl.dict-remove| |shen-cl.dict-size|))
(declaim (inline |shen-cl.hash-mix|))
(defun |shen-cl.hash-mix| (hash value)
  (declare (type (unsigned-byte 32) hash) (type integer value))
  (logand #xffffffff (logxor (* hash 33) value)))

(defun |shen-cl.number-hash| (number)
  ;; Canonicalise cross-representation numeric equality: 1 and 1.0 must
  ;; select the same bucket, including when nested in a list or vector.
  (if (realp number)
      (sxhash (rational number))
      (if (zerop (imagpart number))
          (sxhash (rational (realpart number)))
          (|shen-cl.hash-mix|
           (logand #xffffffff (sxhash (rational (realpart number))))
           (sxhash (rational (imagpart number)))))))

(defun |shen-cl.structural-hash| (value)
  "Hash with Shen's case-sensitive strings and numeric equality.
The traversal is bounded, so long/deep keys cannot exhaust the host stack."
  ;; Property-store and ordinary atomic keys should avoid the traversal's
  ;; cons stack, including numeric keys with cross-representation equality.
  (when (integerp value) (return-from |shen-cl.structural-hash| (sxhash value)))
  (when (numberp value) (return-from |shen-cl.structural-hash| (|shen-cl.number-hash| value)))
  (unless (or (consp value) (and (vectorp value) (not (stringp value))))
    (return-from |shen-cl.structural-hash| (sxhash value)))
  (let ((stack (list value)) (hash 5381) (budget 256))
    (declare (type (unsigned-byte 32) hash) (type fixnum budget))
    (loop while (and stack (plusp budget))
          for node = (pop stack)
          do (decf budget)
             (cond
               ((numberp node)
                (setf hash (|shen-cl.hash-mix| hash (|shen-cl.number-hash| node))))
               ((consp node)
                (setf hash (|shen-cl.hash-mix| hash 17))
                (push (cdr node) stack)
                (push (car node) stack))
               ((and (vectorp node) (not (stringp node)))
                (setf hash (|shen-cl.hash-mix| hash (length node)))
                ;; Only this prefix can be visited within the remaining
                ;; budget; don't allocate a stack proportional to the array.
                (loop for i downfrom (1- (min budget (length node))) to 0
                      do (push (aref node i) stack)))
               (t (setf hash (|shen-cl.hash-mix| hash (sxhash node))))))
    hash))

#+sbcl
(sb-ext:define-hash-table-test |shen-cl.absequal| |shen-cl.structural-hash|)

;; Other CL implementations do not share SBCL's custom hash-table tests.
;; Keep native hash buckets there, with Shen equality inside each bucket.
#-sbcl
(defvar |shen-cl.dict-state-key| (make-symbol "SHEN-DICT-STATE"))

(defun |shen-cl.make-dict| (size)
  (unless (and (integerp size) (plusp size))
    (error "invalid initial dict size: ~S" size))
  #+sbcl (make-hash-table :test '|shen-cl.absequal| :size size)
  #-sbcl (let ((dict (make-hash-table :test 'eql :size size)))
           (setf (gethash |shen-cl.dict-state-key| dict) (list 0))
           dict))

(defun |shen-cl.dict-entry| (dict key)
  #+sbcl (gethash key dict)
  #-sbcl (if (gethash |shen-cl.dict-state-key| dict)
             (let ((entry (assoc key (gethash (|shen-cl.structural-hash| key) dict)
                                 :test #'|shen-cl.absequal|)))
               (values (cdr entry) (not (null entry))))
             (gethash key dict)))

(defun |shen-cl.dict-store| (dict key value)
  #+sbcl (setf (gethash key dict) value)
  #-sbcl
  (let ((state (gethash |shen-cl.dict-state-key| dict)))
    (if state
        (let* ((hash (|shen-cl.structural-hash| key))
               (entry (assoc key (gethash hash dict) :test #'|shen-cl.absequal|)))
          (if entry
              (setf (cdr entry) value)
              (progn (push (cons key value) (gethash hash dict))
                     (incf (car state)))))
        (setf (gethash key dict) value)))
  value)

(defun |shen-cl.dict-remove| (dict key)
  #+sbcl (remhash key dict)
  #-sbcl
  (let ((state (gethash |shen-cl.dict-state-key| dict)))
    (if state
        (let* ((hash (|shen-cl.structural-hash| key))
               (bucket (gethash hash dict))
               (entry (assoc key bucket :test #'|shen-cl.absequal|)))
          (when entry
            (let ((rest (remove entry bucket :test #'eq)))
              (if rest (setf (gethash hash dict) rest) (remhash hash dict)))
            (decf (car state))))
        (remhash key dict)))
  key)

(defun |shen-cl.dict-size| (dict)
  #+sbcl (hash-table-count dict)
  #-sbcl (let ((state (gethash |shen-cl.dict-state-key| dict)))
           (if state (car state) (hash-table-count dict))))

(defun |shen-cl.map-dict| (function dict)
  #+sbcl (maphash function dict)
  #-sbcl
  (if (gethash |shen-cl.dict-state-key| dict)
      (maphash (lambda (hash bucket)
                 (unless (eq hash |shen-cl.dict-state-key|)
                   (dolist (entry bucket) (funcall function (car entry) (cdr entry)))))
               dict)
      (maphash function dict)))
