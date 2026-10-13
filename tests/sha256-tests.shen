\\ FIPS 180-4 vectors for the shen.x host SHA-256 backend (src/sha256.lsp).
\\
\\ Run:  bin/sbcl/shen script tests/sha256-tests.shen
\\
\\ Digests are written as octet lists rather than hex so the test needs no
\\ formatting helpers of its own and cannot pass because of a bug in them.
\\ Padding boundaries are covered deliberately: 55 octets is the last that
\\ fits one block, 56 forces a second, and 64 is an exact block.

(define sha256-tests.repeat
  0 _ -> []
  N X -> [X | (sha256-tests.repeat (- N 1) X)])

(define sha256-tests.check
  Name Actual Expected ->
    (if (= Actual Expected)
        (do (output "PASS ~A~%" Name) true)
        (do (output "FAIL ~A~%  expected ~A~%  actual   ~A~%"
                    Name Expected Actual)
            false)))

(define sha256-tests.all
  [] -> true
  [true | Rest] -> (sha256-tests.all Rest)
  [_ | _] -> false)

(define sha256-tests.backend
  -> (trap-error (value shen.x.*sha256-backend*) (/. E unset)))

(define sha256-tests.batteries-feature
  -> (trap-error
       (element? shen.x/sha256-host (shen.x.features.current))
       (/. E false)))

(define sha256-tests.run
  -> (let Results
       [(sha256-tests.check "backend-is-host" (sha256-tests.backend) host)
        (sha256-tests.check "batteries-feature-is-advertised"
          (sha256-tests.batteries-feature) true)
        (sha256-tests.check "nist-empty"
          (shen.x.sha256-octets-host [])
          [227 176 196 66 152 252 28 20 154 251 244 200 153 111 185 36
           39 174 65 228 100 155 147 76 164 149 153 27 120 82 184 85])
        (sha256-tests.check "nist-abc"
          (shen.x.sha256-octets-host [97 98 99])
          [186 120 22 191 143 1 207 234 65 65 64 222 93 174 34 35
           176 3 97 163 150 23 122 156 180 16 255 97 242 0 21 173])
        (sha256-tests.check "nist-two-block"
          (shen.x.sha256-octets-host
            [97 98 99 100 98 99 100 101 99 100 101 102 100 101 102 103
             101 102 103 104 102 103 104 105 103 104 105 106 104 105 106 107
             105 106 107 108 106 107 108 109 107 108 109 110 108 109 110 111
             109 110 111 112 110 111 112 113])
          [36 141 106 97 210 6 56 184 229 192 38 147 12 62 96 57
           163 60 228 89 100 255 33 103 246 236 237 212 25 219 6 193])
        (sha256-tests.check "pad-55-octets"
          (shen.x.sha256-octets-host (sha256-tests.repeat 55 97))
          [159 67 144 248 211 12 45 217 46 201 240 149 182 94 43 154
           233 176 169 37 165 37 142 36 28 159 30 145 15 115 67 24])
        (sha256-tests.check "pad-56-octets"
          (shen.x.sha256-octets-host (sha256-tests.repeat 56 97))
          [179 84 57 164 172 111 9 72 182 214 249 227 198 175 15 95
           89 12 226 15 27 222 112 144 239 121 112 104 110 198 115 138])
        (sha256-tests.check "pad-64-octets"
          (shen.x.sha256-octets-host (sha256-tests.repeat 64 97))
          [255 224 84 254 122 224 203 109 198 92 58 249 182 29 82 9
           244 57 133 29 180 61 11 165 153 115 55 223 21 70 104 235])]
       (if (sha256-tests.all Results)
           (do (output "shen-cl sha256: ~A/~A passed~%"
                       (length Results) (length Results))
               (output "ALL PASS~%")
               true)
           (do (output "shen-cl sha256: SOME FAILED~%") false))))

(sha256-tests.run)
