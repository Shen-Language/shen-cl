; Copyright (c) 2010-2015, Mark Tarver

; All rights reserved.

; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are met:
; 1. Redistributions of source code must retain the above copyright
;    notice, this list of conditions and the following disclaimer.
; 2. Redistributions in binary form must reproduce the above copyright
;    notice, this list of conditions and the following disclaimer in the
;    documentation and/or other materials provided with the distribution.
; 3. The name of Mark Tarver may not be used to endorse or promote products
;    derived from this software without specific prior written permission.

; THIS SOFTWARE IS PROVIDED BY Mark Tarver ''AS IS'' AND ANY
; EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
; DISCLAIMED. IN NO EVENT SHALL Mark Tarver BE LIABLE FOR ANY
; DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
; (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
; ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

(IN-PACKAGE :SHEN)

(DEFVAR |shen-cl.kernel-sysfunc?| (FDEFINITION '|shen.sysfunc?|))

(DEFUN |shen.sysfunc?| (Symbol)
  (or
    (APPLY |shen-cl.kernel-sysfunc?| (LIST Symbol))
    (|shen-cl.lisp-prefixed?| Symbol)))

(DEFUN shen.pvar? (X)
  (IF (AND (ARRAYP X) (NOT (STRINGP X)) (EQ (SVREF X 0) '|shen.pvar|))
    '|true|
    '|false|))

(DEFUN |shen.lazyderef| (X ProcessN)
  (IF (AND (ARRAYP X) (NOT (STRINGP X)) (EQ (SVREF X 0) '|shen.pvar|))
    (LET ((Value (|shen.valvector| X ProcessN)))
      (IF (EQ Value '|shen.-null-|)
        X
        (|shen.lazyderef| Value ProcessN)))
    X))

(DEFUN |shen.valvector| (Var ProcessN)
  (SVREF (SVREF |shen.*prologvectors*| ProcessN) (SVREF Var 1)))

(DEFUN |shen.unbindv| (Var N)
  (LET ((Vector (SVREF |shen.*prologvectors*| N)))
    (SETF (SVREF Vector (SVREF Var 1)) '|shen.-null-|)))

(DEFUN |shen.bindv| (Var Val N)
  (LET ((Vector (SVREF |shen.*prologvectors*| N)))
    (SETF (SVREF Vector (SVREF Var 1)) Val)))

(DEFUN |shen.copy-vector-stage-1| (Count Vector BigVector Max)
  (IF (= Max Count)
    BigVector
    (|shen.copy-vector-stage-1|
      (1+ Count)
      Vector
      (|address->| BigVector Count (|<-address| Vector Count))
      Max)))

(DEFUN |shen.copy-vector-stage-2| (Count Max Fill BigVector)
  (IF (= Max Count)
    BigVector
    (|shen.copy-vector-stage-2|
      (1+ Count)
      Max
      Fill
      (|address->| BigVector Count Fill))))

(DEFUN |shen.newpv| (N)
  (LET ((Count+1 (1+ (THE INTEGER (SVREF |shen.*varcounter*| N))))
        (Vector (SVREF |shen.*prologvectors*| N)))
    (SETF (SVREF |shen.*varcounter*| N) Count+1)
    (IF (= (THE INTEGER Count+1) (THE INTEGER (|limit| Vector)))
      (|shen.resizeprocessvector| N Count+1)
      '|skip|)
    (|shen.mk-pvar| Count+1)))

(DEFUN |vector->| (Vector N X)
  (IF (ZEROP N)
    (ERROR "cannot access 0th element of a vector~%")
    (|address->| Vector N X)))

(DEFUN |<-vector| (Vector N)
  (IF (ZEROP N)
    (ERROR "cannot access 0th element of a vector~%")
    (|let| VectorElement (SVREF Vector N)
      (IF (EQ VectorElement (|fail|))
        (ERROR "vector element not found~%")
        VectorElement))))

(DEFUN |variable?| (X)
  (IF (AND (SYMBOLP X) (NOT (NULL X)) (UPPER-CASE-P (CHAR (SYMBOL-NAME X) 0)))
    '|true|
    '|false|))

(DEFUN |shen.+string?| (X)
  (IF (AND (STRINGP X) (NOT (STRING-EQUAL X "")))
    '|true|
    '|false|))

(DEFUN |thaw| (F)
  (FUNCALL F))

(DEFUN |hash| (Val Bound)
  (MOD (SXHASH Val) Bound))

(DEFUN |shen.dict| (Size)
  (MAKE-HASH-TABLE :SIZE Size))

(DEFUN |shen.dict?| (Dict)
  (IF (HASH-TABLE-P Dict) '|true| '|false|))

(DEFUN |shen.dict-count| (Dict)
  (HASH-TABLE-COUNT Dict))

(DEFUN |shen.dict->| (Dict Key Value)
 (SETF (GETHASH Key Dict) Value))

(DEFUN |shen.<-dict| (Dict Key)
  (MULTIPLE-VALUE-BIND (Result Found) (GETHASH Key Dict)
    (IF Found
        Result
        (ERROR "value ~A not found in dict~%" Key))))

(DEFUN |shen.dict-rm| (Dict Key)
  (PROGN (REMHASH Key Dict) Key))

(DEFUN |shen.dict-fold| (F Dict Init)
  (LET ((Acc Init))
    (MAPHASH #'(LAMBDA (K V) (SETF Acc (FUNCALL F K V Acc))) Dict)
    Acc))

#+CLISP
(DEFUN |cl.exit| (Code)
  (EXT:EXIT Code))

#+(AND CCL (NOT WINDOWS))
(DEFUN |cl.exit| (Code)
  (CCL:QUIT Code))

#+(AND CCL WINDOWS)
(CCL::EVAL (CCL::READ-FROM-STRING "(DEFUN |cl.exit| (Code) (#__exit Code))"))

#+ECL
(DEFUN |cl.exit| (Code)
  (SI:QUIT Code))

#+SBCL
(DEFUN |cl.exit| (Code)
  (ALIEN-FUNCALL (EXTERN-ALIEN "exit" (FUNCTION VOID INT)) Code))

(DEFUN |shen-cl.exit| (Code)
  (|cl.exit| Code))

(DEFUN |shen-cl.initialise| ()
  (PROGN
    (|shen-cl.initialise-compiler|)

    (|put|      '|cl.exit| '|arity| 1 |*property-vector*|)
    (|put| '|shen-cl.exit| '|arity| 1 |*property-vector*|)

    (|declare|      '|cl.exit| (LIST '|number| '--> '|unit|))
    (|declare| '|shen-cl.exit| (LIST '|number| '--> '|unit|))

    (|shen-cl.read-eval| "(defmacro      cl.exit-macro      [cl.exit] -> [cl.exit 0])")
    (|shen-cl.read-eval| "(defmacro shen-cl.exit-macro [shen-cl.exit] -> [cl.exit 0])")))

#+(OR CCL SBCL)
(DEFUN |shen.read-char-code| (S)
  (LET ((C (READ-CHAR S NIL -1)))
    (IF (EQ C -1)
      -1
      (CHAR-INT C))))

#+(OR CCL SBCL)
(DEFUN |pr| (X S)
  (WRITE-STRING X S)
  (WHEN (OR (EQ S |*stoutput*|) (EQ S |*stinput*|))
    (FORCE-OUTPUT S))
  X)

; Amend the REPL credits message to explain exit command
(SETF (SYMBOL-FUNCTION '|shen-cl.original-credits|) #'|shen.credits|)

(DEFUN |shen.credits| ()
  (|shen-cl.original-credits|)
  (FORMAT T "exit REPL with (cl.exit)"))

;; Compiler functions

(DEFUN |shen-cl.cl| (Symbol)
  (LET* ((Str (SYMBOL-NAME Symbol))
         (LispName (STRING-UPCASE Str)))
    (|intern| LispName)))

(DEFUN |shen-cl.lisp-prefixed?| (Symbol)
  (|shen-cl.lisp-true?|
    (AND (NOT (NULL Symbol))
         (SYMBOLP Symbol)
         (|shen-cl.prefix?| (|str| Symbol) "lisp."))))

(DEFUN |shen-cl.remove-lisp-prefix| (Symbol)
  (|intern| (SUBSEQ (SYMBOL-NAME Symbol) 5)))
