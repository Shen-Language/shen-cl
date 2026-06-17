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
