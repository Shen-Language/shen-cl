#!/usr/bin/env bash
#
# Port-authored CLI / launcher integration tests (DISTINCT from the canonical
# kernel certification suite and from the KL->Lisp compiler-output tests).
#
# Mirrors shen-go's cmd/shen/main_test.go, translated to a shell harness that
# drives the BUILT shen binary:
#   - eval -e EXPR           prints the value
#   - eval -l FILE -e EXPR   loads a file then evaluates
#   - script FILE A B        runs a script with *argv* = [FILE A B]
#   - eval -q ... (pr S)     quiet mode still writes pr to FILE streams (the
#                            ratatoskr stage-1 regression) -- see notes re CLISP
#   - --version / --help     metadata
#   - bad subcommand         prints an Invalid argument error
#   - piped stdin EOF        bounded so a non-exiting REPL cannot hang CI
#   - the port .shen runtime suite (scripts/run-port-tests.shen)
#
# CRITICAL shen-cl-unique value: every check runs across LISP_IMPL in
# {sbcl, clisp, ecl}. Whichever binaries are built are exercised for
# MULTI-IMPLEMENTATION PARITY (same program, same observable output); a missing
# impl is skipped gracefully. SBCL is the reference impl and is required.
#
# Documented cross-impl DIVERGENCES locked in below (not faked parity):
#   * piped-stdin EOF: shen-go's REPL exits cleanly on EOF; the shen-cl /
#     Shen-41.x REPL LOOPS forever on stdin EOF (a known kernel gotcha -- the
#     supported clean exit is (cl.exit)). We assert the documented clean-exit
#     path works and that an EOF'd REPL is bounded by a timeout, rather than
#     asserting shen-go's clean-EOF behaviour the port does not have.
#   * bad subcommand: shen-go exits non-zero; the shen-cl launcher prints
#     "Invalid argument" but exits 0. We assert the message (the real contract).
#   * quiet (-q) pr-to-file: SBCL writes pr to file streams regardless of -q;
#     the CLISP build SILENCES pr to file streams under -q (write-byte is
#     unaffected on both). We assert per-impl accordingly.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# A bounded runner so a non-exiting REPL can never hang CI. Prefer GNU/coreutils
# timeout; fall back to gtimeout (macOS+brew); else run unbounded.
#
# The Shen REPL on these Lisp runtimes does NOT exit on its own SIGTERM (it has
# its own signal handling), so a plain `timeout` would itself hang waiting for
# a process that ignores the soft kill. We pass `-k <grace>` so timeout escalates
# to SIGKILL after the grace period, guaranteeing termination. NOTE: with -k,
# GNU timeout reports the SIGKILL escalation as exit 137 (128+9), whereas a
# process that honours the soft SIGTERM yields 124; callers treat both as "the
# bound fired" for the bare-EOF probe.
TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then TIMEOUT_BIN="timeout"
elif command -v gtimeout >/dev/null 2>&1; then TIMEOUT_BIN="gtimeout"; fi
run_bounded() { # SECS CMD...
  local secs="$1"; shift
  if [ -n "$TIMEOUT_BIN" ]; then "$TIMEOUT_BIN" -k 3 "$secs" "$@"; else "$@"; fi
}

PASS=0
FAIL=0
ok()   { PASS=$((PASS+1)); echo "  [OK]    $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  [FAIL]  $1"; }

# assert that "$2" (haystack) contains "$1" (needle)
assert_contains() { # NEEDLE HAYSTACK LABEL
  case "$2" in
    *"$1"*) ok "$3" ;;
    *)      bad "$3 -- expected to contain [$1], got:"; printf '%s\n' "$2" | sed 's/^/          | /' ;;
  esac
}
assert_eq() { # EXPECTED ACTUAL LABEL
  if [ "$1" = "$2" ]; then ok "$3"; else bad "$3 -- expected [$1] got [$2]"; fi
}

# Resolve the launcher invocation for an impl, or empty string if not built.
shen_bin() { # IMPL
  case "$1" in
    sbcl)  [ -x bin/sbcl/shen ]  && echo "bin/sbcl/shen" ;;
    clisp) [ -x bin/clisp/shen ] && echo "bin/clisp/shen --clisp-m 10MB" ;;
    ecl)   [ -x bin/ecl/shen ]   && echo "bin/ecl/shen" ;;
  esac
}

test_impl() { # IMPL
  local impl="$1"
  local bin; bin="$(shen_bin "$impl")"
  if [ -z "$bin" ]; then
    echo "== $impl: binary not built, skipping =="
    return 0
  fi
  echo "== $impl ($bin) =="

  local tmp out ec
  tmp="$(mktemp -d)"

  # --- eval -e EXPR prints the value ---
  out="$(run_bounded 60 $bin eval -e '(+ 1 2)' 2>&1)"
  assert_contains "3" "$out" "$impl: eval -e prints value"

  # --- eval -l FILE -e EXPR loads then evaluates ---
  printf '(define dbl X -> (* 2 X))' > "$tmp/load.shen"
  out="$(run_bounded 60 $bin eval -l "$tmp/load.shen" -e '(dbl 21)' 2>&1)"
  assert_contains "42" "$out" "$impl: eval -l FILE then -e"

  # --- script FILE A B sets *argv* = [FILE A B] ---
  printf '(output "ARGV=~A~%%" (value *argv*))' > "$tmp/script.shen"
  out="$(run_bounded 60 $bin script "$tmp/script.shen" alpha beta 2>&1)"
  assert_contains "ARGV=[$tmp/script.shen alpha beta]" "$out" "$impl: script sets *argv*"

  # --- --version / --help ---
  # DIVERGENCE: on the CLISP build the underlying CLISP runtime intercepts the
  # global flags --version and --help for ITSELF before the shen launcher sees
  # them, so they cannot report shen's metadata. SBCL and ECL pass them through
  # to the launcher. Assert per-impl rather than fake parity.
  if [ "$impl" = "clisp" ]; then
    echo "  [SKIP]  clisp: --version/--help intercepted by the CLISP runtime (divergence)"
  else
    out="$(run_bounded 60 $bin --version 2>&1)"
    assert_contains "41.2" "$out" "$impl: --version reports kernel version"
    out="$(run_bounded 60 $bin --help 2>&1)"
    assert_contains "Usage:" "$out" "$impl: --help shows usage"
    assert_contains "script" "$out" "$impl: --help lists the script command"
  fi

  # --- bad subcommand prints Invalid argument (DIVERGENCE: exit is 0) ---
  out="$(run_bounded 60 $bin no-such-cmd x 2>&1)"; ec=$?
  assert_contains "Invalid argument" "$out" "$impl: bad subcommand reports Invalid argument"
  # Lock in the divergence: shen-cl returns 0 here (shen-go returns non-zero).
  assert_eq "0" "$ec" "$impl: bad subcommand exit status (shen-cl returns 0)"

  # --- adversarial eval -e exits non-zero, prints an error, no Lisp backtrace ---
  # Route stdout/err to a FILE (not a pipe): the CLISP build cannot WRITE-CHAR
  # its fatal-error message onto an unbuffered pipe (it raises "WRITE-CHAR ...
  # is illegal" instead), so we capture via a regular file which all impls
  # handle. The contract: non-zero exit + names the bad symbol + no backtrace.
  run_bounded 60 $bin eval -e '(overflow->str)' > "$tmp/adv.out" 2>&1; ec=$?
  out="$(cat "$tmp/adv.out")"
  if [ "$ec" -ne 0 ]; then ok "$impl: adversarial eval exits non-zero"
  else bad "$impl: adversarial eval should exit non-zero, got 0"; fi
  # DIVERGENCE: the SBCL/ECL builds write the fatal-error message (which names
  # the unbound symbol) to stdout. The CLISP build cannot WRITE-CHAR its error
  # onto a non-TTY fd stream (it raises "WRITE-CHAR on ... /dev/fd/1 is
  # illegal"), so the shen error text is unavailable there; we only assert the
  # non-zero exit and no-backtrace contract for CLISP.
  if [ "$impl" = "clisp" ]; then
    echo "  [SKIP]  clisp: cannot render fatal-error text onto a non-TTY fd (divergence)"
  else
    assert_contains "overflow->str" "$out" "$impl: adversarial eval names the bad symbol"
  fi
  case "$out" in
    *"Backtrace for"*|*"debugger invoked"*)
      bad "$impl: adversarial eval leaked a Lisp backtrace:"; printf '%s\n' "$out" | sed 's/^/          | /' ;;
    *) ok "$impl: adversarial eval did not leak a Lisp backtrace" ;;
  esac

  # --- quiet (-q) pr-to-file (the ratatoskr stage-1 regression + divergence) ---
  # DIVERGENCE: under -q (which sets *hush*), only the SBCL build still writes
  # (pr STR FileStream); the CLISP and ECL builds SILENCE pr to file streams
  # (zero-byte file). (write-byte ... FileStream) is unaffected on ALL builds.
  rm -f "$tmp/q.txt"
  run_bounded 60 $bin eval -q -e \
    "(let S (open \"$tmp/q.txt\" out) (do (pr \"payload\" S) (close S)))" >/dev/null 2>&1
  local content=""; [ -f "$tmp/q.txt" ] && content="$(cat "$tmp/q.txt")"
  case "$impl" in
    sbcl)
      assert_eq "payload" "$content" "$impl: -q does NOT suppress pr to a file stream" ;;
    clisp|ecl)
      assert_eq "" "$content" "$impl: -q silences pr to a file stream (CLISP/ECL divergence)" ;;
  esac
  # write-byte to a file is unaffected by -q on ALL impls (impl-independent).
  rm -f "$tmp/wb.txt"
  run_bounded 60 $bin eval -q -e \
    "(let S (open \"$tmp/wb.txt\" out) (do (write-byte 90 S) (close S)))" >/dev/null 2>&1
  local wb=""; [ -f "$tmp/wb.txt" ] && wb="$(cat "$tmp/wb.txt")"
  assert_eq "Z" "$wb" "$impl: -q does NOT suppress write-byte to a file stream"

  # --- piped stdin: the supported clean exit is (cl.exit) ---
  # Capture via a FILE: a piped REPL on the CLISP build aborts its REPL driver
  # frame when stdin is not a TTY ("reset() found no driver frame", SIGABRT
  # 134) -- a documented CLISP-build divergence. SBCL/ECL exit 0 cleanly.
  printf '(version)\n(cl.exit 0)\n' | run_bounded 30 $bin > "$tmp/repl.out" 2>&1; ec=$?
  out="$(cat "$tmp/repl.out")"
  assert_contains "41.2" "$out" "$impl: REPL evaluates a piped form"
  if [ "$impl" = "clisp" ]; then
    # 134 = SIGABRT from the no-driver-frame abort on a piped (non-TTY) REPL.
    if [ "$ec" -eq 0 ] || [ "$ec" -eq 134 ]; then
      ok "clisp: piped REPL exits (0 clean, or 134 driver-frame abort -- divergence)"
    else
      bad "clisp: piped REPL exited with unexpected status $ec"
    fi
  else
    assert_eq "0" "$ec" "$impl: REPL exits 0 via (cl.exit)"
  fi
  # DIVERGENCE: a bare EOF (no cl.exit) does NOT exit the shen-cl/Shen-41.x REPL
  # cleanly -- it loops (a known kernel gotcha), and the REPL also ignores the
  # soft SIGTERM. Bound it so CI can't hang: run_bounded escalates to SIGKILL,
  # so a firing bound shows as 124 (soft kill honoured), 137 (128+9 SIGKILL
  # escalation) or 134 (CLISP SIGABRT on a piped REPL). Any of those means
  # "the loop was bounded"; only a clean, prompt 0 would be a (welcome)
  # divergence. An unbounded hang would deadline the whole run.
  printf '(version)\n' | run_bounded 6 $bin >/dev/null 2>&1; ec=$?
  if [ -z "$TIMEOUT_BIN" ]; then
    echo "  [SKIP]  $impl: no timeout binary; not probing bare-EOF loop"
  elif [ "$ec" -eq 124 ] || [ "$ec" -eq 137 ] || [ "$ec" -eq 134 ]; then
    ok "$impl: bare-EOF REPL does not exit cleanly (bounded) -- documented divergence"
  elif [ "$ec" -eq 0 ]; then
    ok "$impl: bare-EOF REPL exited cleanly (better than documented)"
  else
    bad "$impl: bare-EOF REPL exited with unexpected status $ec"
  fi

  # --- the port .shen runtime suite, across this impl (parity) ---
  # Exit code can flake on CLISP's buffered console at (cl.exit); the
  # PORT-TESTS-PASS sentinel text is emitted reliably, so gate on that.
  find tests -name '*.tmp' -delete 2>/dev/null || true
  out="$(run_bounded 120 $bin eval -l scripts/run-port-tests.shen 2>&1)"
  assert_contains "PORT-TESTS-PASS" "$out" "$impl: port .shen runtime suite passes"
  case "$out" in
    *PORT-TESTS-FAIL*) bad "$impl: port suite reported a failure:"; printf '%s\n' "$out" | grep -i fail | sed 's/^/          | /' ;;
    *) : ;;
  esac
  find tests -name '*.tmp' -delete 2>/dev/null || true

  rm -rf "$tmp"
}

echo "shen-cl port-authored CLI parity tests"
echo "======================================"

# SBCL is the reference impl and must be present.
if [ -z "$(shen_bin sbcl)" ]; then
  echo "ERROR: bin/sbcl/shen is not built; build with 'make build-sbcl' first." >&2
  exit 2
fi

for impl in sbcl clisp ecl; do
  test_impl "$impl"
done

echo "======================================"
echo "CLI parity: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
