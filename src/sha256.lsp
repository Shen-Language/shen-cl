;;;; Host SHA-256 backend for the shen.x extension API (FIPS 180-4).
;;;;
;;;; Shen code never names these functions directly. The portable API in
;;;; pyrex41/shen-extensions probes for |shen.x.sha256-octets-host| and uses it
;;;; when present, falling back to its pure Shen oracle otherwise:
;;;;
;;;;   (shen.x.sha256-hex (shen.x.string->octets "abc"))
;;;;
;;;; Why a self-contained implementation rather than Ironclad: shen-cl builds
;;;; on CLISP, CCL, ECL, and SBCL from a tarball with no ASDF or Quicklisp in
;;;; the build path, and consumers (urdr) gate on fully offline, pinned
;;;; builds. Ironclad is the right answer when a project already resolves
;;;; systems; here it would mean vendoring a ~50-file system to obtain one
;;;; primitive. This file is that one primitive, portable to all four targets.
;;;;
;;;; The digest is a byte-for-byte equal, and much faster, substitute for a
;;;; pure Shen SHA-256; it is never the semantic authority. Consumers verify
;;;; agreement against their own oracle (see urdr ADR 0003).
;;;;
;;;; Set SHEN_X_SHA256=pure to leave the backend unset so callers take their
;;;; pure path.

(in-package :shen)

(defparameter |shen-cl.sha256-k|
  (make-array
    64
    :element-type '(unsigned-byte 32)
    :initial-contents
    '(#x428a2f98 #x71374491 #xb5c0fbcf #xe9b5dba5
      #x3956c25b #x59f111f1 #x923f82a4 #xab1c5ed5
      #xd807aa98 #x12835b01 #x243185be #x550c7dc3
      #x72be5d74 #x80deb1fe #x9bdc06a7 #xc19bf174
      #xe49b69c1 #xefbe4786 #x0fc19dc6 #x240ca1cc
      #x2de92c6f #x4a7484aa #x5cb0a9dc #x76f988da
      #x983e5152 #xa831c66d #xb00327c8 #xbf597fc7
      #xc6e00bf3 #xd5a79147 #x06ca6351 #x14292967
      #x27b70a85 #x2e1b2138 #x4d2c6dfc #x53380d13
      #x650a7354 #x766a0abb #x81c2c92e #x92722c85
      #xa2bfe8a1 #xa81a664b #xc24b8b70 #xc76c51a3
      #xd192e819 #xd6990624 #xf40e3585 #x106aa070
      #x19a4c116 #x1e376c08 #x2748774c #x34b0bcb5
      #x391c0cb3 #x4ed8aa4a #x5b9cca4f #x682e6ff3
      #x748f82ee #x78a5636f #x84c87814 #x8cc70208
      #x90befffa #xa4506ceb #xbef9a3f7 #xc67178f2))
  "FIPS 180-4 round constants: cube roots of the first 64 primes.")

(defmacro |shen-cl.u32| (form)
  "Truncate FORM to 32 bits."
  `(logand #xffffffff ,form))

(declaim (inline |shen-cl.rotr32|))
(defun |shen-cl.rotr32| (x n)
  (declare (type (unsigned-byte 32) x)
           (type (integer 1 31) n)
           (optimize (speed 3) (safety 0)))
  (|shen-cl.u32| (logior (ash x (- n)) (ash x (- 32 n)))))

(defun |shen-cl.sha256-digest| (bytes length)
  "SHA-256 of the first LENGTH octets of BYTES; returns a fresh 32-octet vector."
  (declare (type (simple-array (unsigned-byte 8) (*)) bytes)
           (type fixnum length)
           (optimize (speed 3) (safety 0)))
  (let* ((k |shen-cl.sha256-k|)
         ;; One 0x80 byte, then zero padding to 56 mod 64, then a 64-bit
         ;; big-endian bit count.
         (padded-length (* 64 (ceiling (+ length 9) 64)))
         (block (make-array padded-length :element-type '(unsigned-byte 8)
                                          :initial-element 0))
         (w (make-array 64 :element-type '(unsigned-byte 32)))
         (h0 #x6a09e667) (h1 #xbb67ae85) (h2 #x3c6ef372) (h3 #xa54ff53a)
         (h4 #x510e527f) (h5 #x9b05688c) (h6 #x1f83d9ab) (h7 #x5be0cd19))
    (declare (type (simple-array (unsigned-byte 32) (64)) k w)
             (type (unsigned-byte 32) h0 h1 h2 h3 h4 h5 h6 h7))
    (replace block bytes :end2 length)
    (setf (aref block length) #x80)
    (let ((bits (* length 8)))
      (dotimes (i 8)
        (setf (aref block (- padded-length 1 i))
              (ldb (byte 8 (* 8 i)) bits))))
    (do ((base 0 (+ base 64)))
        ((>= base padded-length))
      (declare (type fixnum base))
      (dotimes (t- 16)
        (declare (type fixnum t-))
        (let ((j (+ base (* t- 4))))
          (declare (type fixnum j))
          (setf (aref w t-)
                (logior (ash (aref block j) 24)
                        (ash (aref block (+ j 1)) 16)
                        (ash (aref block (+ j 2)) 8)
                        (aref block (+ j 3))))))
      (do ((t- 16 (1+ t-)))
          ((>= t- 64))
        (declare (type fixnum t-))
        (let* ((w15 (aref w (- t- 15)))
               (w2 (aref w (- t- 2)))
               (s0 (logxor (|shen-cl.rotr32| w15 7)
                           (|shen-cl.rotr32| w15 18)
                           (ash w15 -3)))
               (s1 (logxor (|shen-cl.rotr32| w2 17)
                           (|shen-cl.rotr32| w2 19)
                           (ash w2 -10))))
          (declare (type (unsigned-byte 32) w15 w2 s0 s1))
          (setf (aref w t-)
                (|shen-cl.u32| (+ (aref w (- t- 16)) s0 (aref w (- t- 7)) s1)))))
      (let ((a h0) (b h1) (c h2) (d h3) (e h4) (f h5) (g h6) (h h7))
        (declare (type (unsigned-byte 32) a b c d e f g h))
        (dotimes (t- 64)
          (declare (type fixnum t-))
          (let* ((big1 (logxor (|shen-cl.rotr32| e 6)
                               (|shen-cl.rotr32| e 11)
                               (|shen-cl.rotr32| e 25)))
                 (ch (logxor (logand e f) (logand (logxor e #xffffffff) g)))
                 (t1 (|shen-cl.u32| (+ h big1 ch (aref k t-) (aref w t-))))
                 (big0 (logxor (|shen-cl.rotr32| a 2)
                               (|shen-cl.rotr32| a 13)
                               (|shen-cl.rotr32| a 22)))
                 (maj (logxor (logand a b) (logand a c) (logand b c)))
                 (t2 (|shen-cl.u32| (+ big0 maj))))
            (declare (type (unsigned-byte 32) big1 ch t1 big0 maj t2))
            (setf h g g f f e
                  e (|shen-cl.u32| (+ d t1))
                  d c c b b a
                  a (|shen-cl.u32| (+ t1 t2)))))
        (setf h0 (|shen-cl.u32| (+ h0 a)) h1 (|shen-cl.u32| (+ h1 b))
              h2 (|shen-cl.u32| (+ h2 c)) h3 (|shen-cl.u32| (+ h3 d))
              h4 (|shen-cl.u32| (+ h4 e)) h5 (|shen-cl.u32| (+ h5 f))
              h6 (|shen-cl.u32| (+ h6 g)) h7 (|shen-cl.u32| (+ h7 h)))))
    (let ((out (make-array 32 :element-type '(unsigned-byte 8))))
      (loop for word of-type (unsigned-byte 32)
              in (list h0 h1 h2 h3 h4 h5 h6 h7)
            for i of-type fixnum from 0 by 4
            do (setf (aref out i) (ldb (byte 8 24) word)
                     (aref out (+ i 1)) (ldb (byte 8 16) word)
                     (aref out (+ i 2)) (ldb (byte 8 8) word)
                     (aref out (+ i 3)) (ldb (byte 8 0) word)))
      out)))

(defun |shen.x.sha256-octets-host| (bs)
  "Shen list of octets 0..255 -> Shen list of the 32 digest octets."
  (let ((length 0))
    (declare (type fixnum length))
    (do ((cur bs (cdr cur)))
        ((not (consp cur))
         (unless (null cur)
           (error "shen.x.sha256-octets-host: improper list")))
      (incf length))
    (let ((bytes (make-array length :element-type '(unsigned-byte 8)))
          (i 0))
      (declare (type fixnum i))
      (dolist (b bs)
        (unless (and (integerp b) (<= 0 b 255))
          (error "shen.x.sha256-octets-host: ~S is not an octet" b))
        (setf (aref bytes i) b)
        (incf i))
      (coerce (|shen-cl.sha256-digest| bytes length) 'list))))

(defun |shen-cl.getenv| (name)
  (declare (ignorable name))
  #+sbcl (sb-ext:posix-getenv name)
  #+clisp (ext:getenv name)
  #+ccl (ccl:getenv name)
  #+ecl (ext:getenv name)
  #-(or sbcl clisp ccl ecl) nil)

(defun |shen-cl.install-sha256-host| ()
  "Advertise the host backend unless SHEN_X_SHA256=pure.

Called at startup rather than at image-dump time so the environment variable
is read from the running process, not from whoever built the image."
  (handler-case
      (if (equal (|shen-cl.getenv| "SHEN_X_SHA256") "pure")
          (|set| '|shen.x.*sha256-backend*| '|pure|)
          (progn
            (|put| '|shen.x.sha256-octets-host| '|arity| 1 |*property-vector*|)
            ;; The feature registry is a kernel extension loaded after this
            ;; file, so reach it late and treat its absence as non-fatal.
            (let ((add (find-symbol "shen.x.features.add" :shen)))
              (when (and add (fboundp add))
                ;; Shen Batteries uses slash-qualified feature names. Keep
                ;; this registration in the same namespace as the extension
                ;; module (shen.x/sha256-host), so library.shen can satisfy a
                ;; (requires-features ...) declaration via
                ;; shen.x.features.current.
                (funcall add '|shen.x/sha256-host|)))
            (|set| '|shen.x.*sha256-backend*| '|host|)))
    (error (e)
      (format *error-output* "shen-cl: host sha256 unavailable: ~A~%" e)
      nil)))
