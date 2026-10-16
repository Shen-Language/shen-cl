\* Copyright (c) 2026 shen-cl port authors.                          *\
\* BSD 3-Clause License: http://opensource.org/licenses/BSD-3-Clause *\

\\ Port-authored IO regression suite. Mirrors shen-go's kl/io_coverage_test.go:
\\ open (in/out), close, a write-byte -> close -> read-byte round trip,
\\ read-byte at EOF returning -1, read-file-as-string and read-file-as-bytelist.
\\
\\ Files are written under a repo-relative path so the run is self-contained;
\\ *home-directory* is "" in the built image, so the path passes through open
\\ unchanged. Loaded after tests/test-harness.shen by run-port-tests.shen.
\\
\\ CROSS-IMPL *hush* DIVERGENCE (verified, locked in below): with *hush* = true,
\\ (pr STR FileStream) is SILENCED on the CLISP build (it produces a zero-byte
\\ file) but written on the SBCL build. (write-byte ... FileStream) is written
\\ on BOTH regardless of *hush*. The port test runner loads under *hush* = true
\\ for quiet output, so these pr-based round trips explicitly clear *hush*
\\ first; otherwise the CLISP run would read back empty files.

(set *hush* false)

\\ --- write-byte -> close -> read-byte round trip + EOF (-1) ---
\\ Mirrors shen-go's TestStreamRoundTrip: write "Hi" (72 105), read back the
\\ two bytes then -1 at EOF.
(define io-roundtrip
  Path -> (let Out (open Path out)
               _ (write-byte 72 Out)
               _ (write-byte 105 Out)
               _ (close Out)
               In (open Path in)
               B1 (read-byte In)
               B2 (read-byte In)
               Eof (read-byte In)
               _ (close In)
            (@p B1 (@p B2 Eof))))

(assert= "stream round trip + EOF"
         (@p 72 (@p 105 -1))
         (io-roundtrip "tests/io-roundtrip.tmp"))

\\ --- read-file-as-string + read-file-as-bytelist against a real file ---
\\ Mirrors shen-go's TestFileReadPrimitives ("AB" -> "AB" and (65 66)).
(define io-write-text
  Path Text -> (let Out (open Path out)
                    _ (pr Text Out)
                 (close Out)))

(assert= "read-file-as-string"
         "AB"
         (do (io-write-text "tests/io-readfile.tmp" "AB")
             (read-file-as-string "tests/io-readfile.tmp")))

(assert= "read-file-as-bytelist"
         [65 66]
         (read-file-as-bytelist "tests/io-readfile.tmp"))

\\ --- close on a fresh out-stream then reading it back is consistent ---
\\ (open out truncates; an immediately-closed empty stream reads EOF first).
(assert= "empty stream reads EOF"
         -1
         (let Out (open "tests/io-empty.tmp" out)
              _ (close Out)
              In (open "tests/io-empty.tmp" in)
              B (read-byte In)
              _ (close In)
           B))

(assert= "public character stream arities" [1 1 2]
  (map (fn arity) [char-stream? read-unit-string write-string]))

(assert= "public character stream functions are exported and typed"
  [[true true] [true true] [true true]]
  (map (/. F [(element? F (external shen))
              (not (empty? (assoc F (value shen.*sigf*))))])
       [char-stream? read-unit-string write-string]))

(assert= "higher-order character input preserves Unicode, NUL and EOF"
  [true "A" (n->string 0) (n->string 955) ""]
  (let Stream (shen-cl.eval-lisp
                "(make-string-input-stream (coerce (list (code-char 65) (code-char 0) (code-char 955)) 'string))")
       Result [((fn char-stream?) Stream)
               ((fn read-unit-string) Stream) ((fn read-unit-string) Stream)
               ((fn read-unit-string) Stream) ((fn read-unit-string) Stream)]
       Closed (close Stream)
    Result))

(assert= "higher-order character output returns and writes its string under hush"
  [(cn "A" (n->string 955)) (cn "A" (n->string 955))]
  (let Stream (set io-test.*public-output*
                  (shen-cl.eval-lisp "(make-string-output-stream)"))
       Result ((fn write-string) (cn "A" (n->string 955)) Stream)
       Text (shen-cl.eval-lisp
              "(get-output-stream-string (symbol-value 'shen::|io-test.*public-output*|))")
       Closed (close Stream)
    [Result Text]))

(assert= "character stream dispatch preserves Unicode, NUL and EOF"
  [true 65 0 955 -1 -1]
  (shen-cl.eval-lisp
    "(with-input-from-string (stream (coerce (list (code-char 65) (code-char 0) (code-char 955)) 'string))
       (list (shen::|char-stream?| stream)
             (shen::|shen.my-read-byte| stream) (shen::|shen.my-read-byte| stream)
             (shen::|shen.my-read-byte| stream) (shen::|shen.my-read-byte| stream)
             (shen::|shen.my-read-byte| stream)))"))
(assert= "byte stream dispatch preserves bytes and EOF" [false 0 255 -1]
  (do (set io-test.*dispatch-path* "tests/io-dispatch.tmp")
    (shen-cl.eval-lisp
    "(progn (with-open-file (stream (symbol-value 'shen::|io-test.*dispatch-path*|) :direction :output
                             :element-type '(unsigned-byte 8) :if-exists :supersede)
       (write-byte 0 stream) (write-byte 255 stream))
     (with-open-file (stream (symbol-value 'shen::|io-test.*dispatch-path*|) :element-type '(unsigned-byte 8))
       (list (shen::|char-stream?| stream)
             (shen::|shen.my-read-byte| stream) (shen::|shen.my-read-byte| stream)
             (shen::|shen.my-read-byte| stream))))")))
(assert= "wider byte streams retain the subtype fallback" [false 8192 -1]
  (shen-cl.eval-lisp
    "(progn (with-open-file (stream (symbol-value 'shen::|io-test.*dispatch-path*|) :direction :output
                             :element-type '(unsigned-byte 16) :if-exists :supersede)
       (write-byte 8192 stream))
     (with-open-file (stream (symbol-value 'shen::|io-test.*dispatch-path*|) :element-type '(unsigned-byte 16))
       (list (shen::|char-stream?| stream)
             (shen::|shen.my-read-byte| stream) (shen::|shen.my-read-byte| stream))))"))

\\ SBCL's native file-stream type shortcut must preserve decoding and the
\\ ordinary protocol when a stream is closed or has a different handler.
(if (shen-cl.eval-lisp "#+sbcl 'shen::|true| #-sbcl 'shen::|false|")
  (do
    (assert= "SBCL native stream preserves mixed byte and Unicode reads"
      [true 65 955 66 -1]
      (shen-cl.eval-lisp
        "(let ((path (symbol-value 'shen::|io-test.*dispatch-path*|)))
           (with-open-file (s path :direction :output :element-type 'character
                                  :external-format :utf-8 :if-exists :supersede)
             (write-string (coerce (list (code-char 65) (code-char 955) (code-char 66)) 'string) s))
           (with-open-file (s path :element-type :default :external-format :utf-8)
             (list (shen::|char-stream?| s)
                   (read-byte s) (shen::|shen.my-read-byte| s)
                   (read-byte s) (shen::|shen.my-read-byte| s))))"))
    (assert= "SBCL closed native streams retain protocol errors" true
      (shen-cl.eval-lisp
        "(let ((s (open (symbol-value 'shen::|io-test.*dispatch-path*|) :element-type :default)))
           (close s)
           (if (every (lambda (f) (handler-case (progn (funcall f s) nil)
                                   (stream-error () t)))
                      (list #'shen::|char-stream?|
                            #'shen::|shen.my-read-byte|))
               'shen::|true| 'shen::|false|))"))
    (assert= "SBCL native stream respects a changed type handler" true
      (shen-cl.eval-lisp
        "(with-open-file (s (symbol-value 'shen::|io-test.*dispatch-path*|) :element-type :default)
           (let ((handler (sb-impl::ansi-stream-misc s)))
             (unwind-protect
                 (progn
                   (setf (sb-impl::ansi-stream-misc s)
                         (lambda (&rest args) (declare (ignore args)) (error (string 'custom-type-handler))))
                   (handler-case (progn (shen::|char-stream?| s) 'shen::|false|)
                     (simple-error (e) (if (string= (princ-to-string e) (string 'custom-type-handler))
                                           'shen::|true| 'shen::|false|))))
               (setf (sb-impl::ansi-stream-misc s) handler))))")))
  skipped)

\\ Lock in the *hush*/pr-to-file divergence as an explicit assertion:
\\ under *hush* = true, (pr ... FileStream) writes on SBCL but is silenced on
\\ CLISP; (write-byte ... FileStream) writes on BOTH. We assert only the
\\ impl-independent fact -- write-byte is never silenced by *hush* -- so this
\\ holds across SBCL/CLISP/ECL.
(assert= "write-byte ignores *hush*"
         [88]
         (let _ (set *hush* true)
              Out (open "tests/io-hush.tmp" out)
              _ (write-byte 88 Out)
              _ (close Out)
              _ (set *hush* false)
           (read-file-as-bytelist "tests/io-hush.tmp")))

\\ Restore the quiet flag the runner relies on for the remaining suites.
(set *hush* true)
