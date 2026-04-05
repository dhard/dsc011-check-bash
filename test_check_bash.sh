#!/usr/bin/env bash
# =============================================================================
# test_check_bash.sh  —  Unit test suite for check_bash v2.0
# DSC 011, UC Merced  |  https://github.com/dhard/dsc011-check-bash
#
# Usage:
#   bash test_check_bash.sh [path/to/check_bash]
#
# If no path is given, looks for check_bash on PATH.
# Exit code: 0 if all tests pass, 1 if any fail.
# =============================================================================

set -uo pipefail

# ---------------------------------------------------------------------------
# Locate check_bash
# ---------------------------------------------------------------------------
CB="${1:-}"
if [[ -z "$CB" ]]; then
    if command -v check_bash &>/dev/null; then
        CB=$(command -v check_bash)
    else
        echo "ERROR: check_bash not found on PATH and no path argument given." >&2
        echo "Usage: bash test_check_bash.sh [path/to/check_bash]" >&2
        exit 1
    fi
fi

[[ ! -x "$CB" ]] && chmod +x "$CB"

echo "========================================================"
echo " check_bash test suite"
echo "========================================================"
echo " Script:   $CB"
echo " Platform: $(uname -s) $(uname -m)"
echo " Bash:     $BASH_VERSION"
echo "========================================================"

# ---------------------------------------------------------------------------
# Test framework
# ---------------------------------------------------------------------------
PASS=0; FAIL=0; SKIP=0
FAILURES=()

_pass() { (( PASS++ )); printf '  [PASS] %s\n' "$1"; }
_fail() { (( FAIL++ )); printf '  [FAIL] %s\n' "$1"; FAILURES+=("$1"); }
_skip() { (( SKIP++ )); printf '  [SKIP] %s\n' "$1"; }

assert_contains() {
    local name="$1" output="$2" expected="$3"
    if printf '%s' "$output" | grep -qF "$expected"; then
        _pass "$name"
    else
        _fail "$name"
        printf '         expected to contain: %s\n' "$expected"
        printf '         actual output:\n'
        printf '%s\n' "$output" | head -6 | sed 's/^/           /'
    fi
}

assert_not_contains() {
    local name="$1" output="$2" unexpected="$3"
    if printf '%s' "$output" | grep -qF "$unexpected"; then
        _fail "$name — output should NOT contain: '$unexpected'"
        printf '%s\n' "$output" | head -4 | sed 's/^/           /'
    else
        _pass "$name"
    fi
}

# Like assert_not_contains but matches whole words only (grep -w).
# Use this when the forbidden word may appear as a substring of another word,
# e.g. 'CORRECT' inside 'INCORRECT'.
assert_not_contains_word() {
    local name="$1" output="$2" unexpected="$3"
    if printf '%s' "$output" | grep -qw "$unexpected"; then
        _fail "$name — output should NOT contain word: '$unexpected'"
        printf '%s\n' "$output" | head -4 | sed 's/^/           /'
    else
        _pass "$name"
    fi
}

assert_exact() {
    local name="$1" output="$2" expected="$3"
    if [[ "$output" == "$expected" ]]; then
        _pass "$name"
    else
        _fail "$name"
        printf '         expected: %q\n' "$expected"
        printf '         actual:   %q\n' "$output"
    fi
}

assert_exit_nonzero() {
    local name="$1"; shift
    if "$@" &>/dev/null; then
        _fail "$name — expected non-zero exit"
    else
        _pass "$name"
    fi
}

section() { printf '\n── %s ──────────────────────────────────\n' "$1"; }

# ---------------------------------------------------------------------------
# Pre-compute reference hashes
# ---------------------------------------------------------------------------
HASH_HELLO=$(echo "hello world" | "$CB" --make-key)
TMPFILE=$(mktemp -t cb_test.XXXXXX)
TMPFILE2=$(mktemp -t cb_test.XXXXXX)
trap 'rm -f "$TMPFILE" "$TMPFILE2"' EXIT
echo "file content for testing" > "$TMPFILE"
FILE_HASH=$("$CB" --file "$TMPFILE" --make-key)

# ===========================================================================
# SECTION 1: Hash generation
# ===========================================================================
section "1. Hash generation (--make-key)"

out=$(echo "hello world" | "$CB" --make-key)
if [[ ${#out} -eq 64 ]] && [[ "$out" =~ ^[0-9a-f]{64}$ ]]; then
    _pass "make-key: 64-char lowercase hex"
else
    _fail "make-key: 64-char lowercase hex — got: '$out'"
fi

out2=$(echo "hello world" | "$CB" --make-key)
assert_exact "make-key: deterministic"                  "$out"  "$out2"

out3=$("$CB" --make-key "hello world")
assert_exact "make-key: positional arg matches pipe"    "$out"  "$out3"

out4=$(echo "hello WORLD" | "$CB" --make-key)
if [[ "$out" != "$out4" ]]; then _pass "make-key: case-sensitive hashing"
else _fail "make-key: case-sensitive hashing — collision"; fi

out5=$(echo "hello world " | "$CB" --make-key)
if [[ "$out" != "$out5" ]]; then _pass "make-key: trailing-space sensitive"
else _fail "make-key: trailing-space sensitive — collision"; fi

# ===========================================================================
# SECTION 2: Output checking — pipe pattern
# ===========================================================================
section "2. Output checking — pipe"

out=$(echo "hello world" | "$CB" "$HASH_HELLO")
assert_contains     "pipe: prints answer"       "$out" "hello world"
assert_contains     "pipe: CORRECT on match"    "$out" "CORRECT"
assert_not_contains "pipe: no INCORRECT"        "$out" "INCORRECT"

out=$(echo "wrong" | "$CB" "$HASH_HELLO")
assert_contains          "pipe: INCORRECT on miss"   "$out" "INCORRECT"
assert_not_contains_word "pipe: no CORRECT on miss"  "$out" "CORRECT"

# ===========================================================================
# SECTION 3: Output checking — capture pattern
# ===========================================================================
section "3. Output checking — capture"

answer=$(echo "hello world")
out=$("$CB" "$answer" "$HASH_HELLO")
assert_contains     "capture: prints answer"        "$out" "hello world"
assert_contains     "capture: CORRECT on match"     "$out" "CORRECT"

out=$("$CB" "wrong" "$HASH_HELLO")
assert_contains          "capture: INCORRECT on miss"    "$out" "INCORRECT"
assert_not_contains_word "capture: no CORRECT on miss"   "$out" "CORRECT"

# ===========================================================================
# SECTION 4: Quiet flag
# ===========================================================================
section "4. Quiet flag (-q)"

out=$(echo "hello world" | "$CB" -q "$HASH_HELLO")
assert_not_contains "quiet: suppresses answer value" "$out" "hello world"
assert_contains     "quiet: still prints CORRECT"    "$out" "CORRECT"

# ===========================================================================
# SECTION 5: Normalize flag
# ===========================================================================
section "5. Normalize flag (-n)"

HASH_NORM=$(printf 'hello world' | "$CB" -n --make-key)

out=$(echo "  hello   world  " | "$CB" -n "$HASH_NORM")
assert_contains "normalize: padded input matches"    "$out" "CORRECT"

out=$(echo "hello world" | "$CB" -n "$HASH_NORM")
assert_contains "normalize: clean input matches"     "$out" "CORRECT"

out=$(echo "  hello   world  " | "$CB" "$HASH_NORM")
assert_contains "strict: padded input fails"         "$out" "INCORRECT"

HASH_NORM2=$(echo "hello   world" | "$CB" -n --make-key)
assert_exact "normalize: consistent across spacing"  "$HASH_NORM" "$HASH_NORM2"

# ===========================================================================
# SECTION 6: File checking
# ===========================================================================
section "6. File checking (--file)"

if [[ ${#FILE_HASH} -eq 64 ]]; then _pass "file make-key: 64-char hex"
else _fail "file make-key: 64-char hex — got: '$FILE_HASH'"; fi

out=$("$CB" --file "$TMPFILE" "$FILE_HASH")
assert_contains     "file: CORRECT on match"         "$out" "CORRECT"
assert_contains     "file: shows filename"            "$out" "cb_test"
assert_not_contains "file: no INCORRECT"              "$out" "INCORRECT"

out=$("$CB" --file "$TMPFILE" "0000000000000000000000000000000000000000000000000000000000000000")
assert_contains     "file: INCORRECT on wrong hash"  "$out" "INCORRECT"

# File not found error
out=$("$CB" --file /nonexistent/no_such_file_cb.txt "abc" 2>&1 || true)
assert_contains     "file: error on missing file"    "$out" "ERROR"

# File contents change → hash changes
echo "different content" > "$TMPFILE2"
HASH2=$("$CB" --file "$TMPFILE2" --make-key)
if [[ "$FILE_HASH" != "$HASH2" ]]; then _pass "file: different content → different hash"
else _fail "file: different content → different hash — collision"; fi

# ===========================================================================
# SECTION 7: Code-only checks — required/forbidden commands
# ===========================================================================
section "7. Code checks — required/forbidden commands"

MY_CODE='cat file.txt | grep foo | wc -l'

out=$("$CB" --code "$MY_CODE" --requires grep --requires wc --forbid awk --pipeline 3)
assert_contains "code: requires grep PASS"      "$out" "✓ requires 'grep'"
assert_contains "code: requires wc PASS"        "$out" "✓ requires 'wc'"
assert_contains "code: forbids awk PASS"        "$out" "✓ forbids 'awk'"
assert_contains "code: pipeline 3 PASS"         "$out" "✓ pipeline has exactly 3"
assert_contains "code: result CORRECT"            "$out" "CORRECT"

out=$("$CB" --code "$MY_CODE" --requires awk --forbid grep --pipeline 2 || true)
assert_contains "code: requires awk FAIL"       "$out" "✗ requires 'awk'"
assert_contains "code: forbids grep FAIL"       "$out" "✗ forbids 'grep'"
assert_contains "code: pipeline 2 FAIL"         "$out" "✗ pipeline has 3"
assert_contains "code: result INCORRECT"          "$out" "INCORRECT"

# ===========================================================================
# SECTION 8: Code checks — flag checking
# ===========================================================================
section "8. Code checks — flag checking"

MY_CODE='sort -r file.txt | head -5'

out=$("$CB" --code "$MY_CODE" --requires-flag "-r" --forbid-flag "-n")
assert_contains "flag: requires -r PASS"        "$out" "✓ requires flag '-r'"
assert_contains "flag: forbids -n PASS"         "$out" "✓ forbids flag '-n'"
assert_contains "flag: result CORRECT"            "$out" "CORRECT"

out=$("$CB" --code "$MY_CODE" --requires-flag "-n" --forbid-flag "-r" || true)
assert_contains "flag: requires -n FAIL"        "$out" "✗ requires flag '-n'"
assert_contains "flag: forbids -r FAIL"         "$out" "✗ forbids flag '-r'"
assert_contains "flag: result INCORRECT"          "$out" "INCORRECT"

# Long-form flags
MY_CODE='grep --ignore-case pattern file.txt'
out=$("$CB" --code "$MY_CODE" --requires-flag "--ignore-case")
assert_contains "flag: long-form flag detected" "$out" "✓ requires flag '--ignore-case'"

# ===========================================================================
# SECTION 9: Pipeline counting
# ===========================================================================
section "9. Pipeline stage counting"

out=$("$CB" --code "ls" --pipeline 1)
assert_contains "pipeline: 1 stage"             "$out" "✓ pipeline has exactly 1"

out=$("$CB" --code "ls | wc -l" --pipeline 2)
assert_contains "pipeline: 2 stages"            "$out" "✓ pipeline has exactly 2"

out=$("$CB" --code "ls | grep foo | sort | head" --pipeline 4)
assert_contains "pipeline: 4 stages"            "$out" "✓ pipeline has exactly 4"

# Subshell pipe must NOT be counted at top level
out=$("$CB" --code 'echo $(ls /tmp | wc -l) | cat' --pipeline 2)
assert_contains "pipeline: subshell pipe excluded" "$out" "✓ pipeline has exactly 2"

# Logical OR (||) must NOT be counted as pipeline
out=$("$CB" --code 'cmd1 || cmd2' --pipeline 1)
assert_contains "pipeline: || not counted"      "$out" "✓ pipeline has exactly 1"

# pipeline-min / pipeline-max
out=$("$CB" --code "ls | grep foo | sort | head" --pipeline-min 3 --pipeline-max 5)
assert_contains "pipeline-min: 4 >= 3 PASS"    "$out" "✓ pipeline has >= 3"
assert_contains "pipeline-max: 4 <= 5 PASS"    "$out" "✓ pipeline has <= 5"

out=$("$CB" --code "ls | wc" --pipeline-min 3 || true)
assert_contains "pipeline-min: 2 < 3 FAIL"     "$out" "✗ pipeline has 2"

out=$("$CB" --code "ls | grep | sort | head | tail" --pipeline-max 3 || true)
assert_contains "pipeline-max: 5 > 3 FAIL"     "$out" "✗ pipeline has 5"

# ===========================================================================
# SECTION 10: Combined output + code checks
# ===========================================================================
section "10. Combined output + code checks"

MY_CODE='echo hello | tr a-z A-Z'
OUT_HASH=$(eval "$MY_CODE" | "$CB" --make-key)

out=$(eval "$MY_CODE" | "$CB" --code "$MY_CODE" \
    --requires tr --forbid awk --pipeline 2 "$OUT_HASH")
assert_contains          "combined: Output: label present"   "$out" "Output:"
assert_contains          "combined: Code:   label present"   "$out" "Code:"
assert_contains          "combined: output result CORRECT"   "$out" "CORRECT"
assert_not_contains_word "combined: output not INCORRECT"    "$out" "INCORRECT"
# Every occurrence of CORRECT must be on a labeled Output:/Code: line
if printf '%s' "$out" | grep -w 'CORRECT' | grep -qvE '(Output|Code):.*CORRECT'; then
    _fail "combined: every CORRECT is labeled with Output: or Code:"
else
    _pass "combined: every CORRECT is labeled with Output: or Code:"
fi

# Output correct, code wrong
out=$(eval "$MY_CODE" | "$CB" --code "$MY_CODE" \
    --requires awk --pipeline 3 "$OUT_HASH" || true)
assert_contains "combined: output CORRECT, code wrong — Output label"    "$out" "Output:"
assert_contains "combined: output CORRECT, code wrong — Code label"      "$out" "Code:"
assert_contains "combined: output CORRECT, code wrong — output result"   "$out" "CORRECT"
assert_contains "combined: output CORRECT, code wrong — code result"     "$out" "INCORRECT"

# Output wrong, code correct
out=$(echo "wrong output" | "$CB" --code "$MY_CODE" \
    --requires tr --pipeline 2 "$OUT_HASH" || true)
assert_contains "combined: output wrong, code right — Output label"      "$out" "Output:"
assert_contains "combined: output wrong, code right — Code label"        "$out" "Code:"
assert_contains "combined: output wrong, code right — output result"     "$out" "INCORRECT"
assert_contains "combined: output wrong, code right — code result"       "$out" "CORRECT"

# Both wrong
out=$(echo "wrong" | "$CB" --code "$MY_CODE" \
    --requires awk --pipeline 5 "$OUT_HASH" || true)
assert_contains "combined: both wrong — Output label"     "$out" "Output:"
assert_contains "combined: both wrong — Code label"       "$out" "Code:"
assert_contains "combined: both wrong — output INCORRECT" "$out" "INCORRECT"
assert_contains "combined: both wrong — code INCORRECT"   "$out" "INCORRECT"

# ===========================================================================
# SECTION 11: Heredoc / multi-line code
# ===========================================================================
section "11. Multi-line code (heredoc pattern)"

MY_CODE=$(printf 'find /tmp -name "*.txt" |\n  xargs grep "hello" |\n  wc -l')
out=$("$CB" --code "$MY_CODE" \
    --requires find --requires grep --requires wc \
    --pipeline 3 --forbid cat)
assert_contains "heredoc: requires find PASS"   "$out" "✓ requires 'find'"
assert_contains "heredoc: requires grep PASS"   "$out" "✓ requires 'grep'"
assert_contains "heredoc: pipeline 3 PASS"      "$out" "✓ pipeline has exactly 3"
assert_contains "heredoc: result CORRECT"         "$out" "CORRECT"

# ===========================================================================
# SECTION 12: Edge cases
# ===========================================================================
section "12. Edge cases"

# Empty string input
HASH_EMPTY_STR=$("$CB" --make-key "")
out=$("$CB" "" "$HASH_EMPTY_STR")
assert_contains "edge: empty string CORRECT"    "$out" "CORRECT"

# Input with newlines
NL_INPUT=$(printf 'line1\nline2\nline3')
HASH_NL=$(printf '%s' "$NL_INPUT" | "$CB" --make-key)
out=$(printf '%s' "$NL_INPUT" | "$CB" "$HASH_NL")
assert_contains "edge: multiline input CORRECT" "$out" "CORRECT"

# Input with special shell characters
SPECIAL='$(rm -rf /); `whoami`; echo $HOME'
HASH_SPEC=$("$CB" --make-key "$SPECIAL")
out=$("$CB" "$SPECIAL" "$HASH_SPEC")
assert_contains "edge: special chars in value"  "$out" "CORRECT"

# Very long single line (1000 chars)
LONG=$(dd if=/dev/zero bs=1000 count=1 2>/dev/null | tr '\0' 'a')
HASH_LONG=$("$CB" --make-key "$LONG")
out=$("$CB" "$LONG" "$HASH_LONG")
assert_contains "edge: 1000-char input CORRECT" "$out" "CORRECT"

# Missing hash argument
out=$("$CB" 2>&1 || true)
assert_contains "edge: no args → error"         "$out" "ERROR"

# Unknown flag
out=$("$CB" --nonexistent-flag 2>&1 || true)
assert_contains "edge: unknown flag → error"    "$out" "ERROR"

# --code with no rules (no code check triggered)
out=$(echo "hello world" | "$CB" --code "ls" "$HASH_HELLO")
assert_contains "edge: --code alone no rules → output only" "$out" "CORRECT"
assert_not_contains "edge: no rules → no Code line"         "$out" "Code:"

# ===========================================================================
# SECTION 13: Security — injection attempts in --code string
# ===========================================================================
section "13. Security — injection in --code"

# Command substitution in code string should not execute during analysis
INJECT='$(echo INJECTED > /tmp/cb_inject_test.txt)'
"$CB" --code "$INJECT" --requires grep 2>/dev/null || true
if [[ ! -f /tmp/cb_inject_test.txt ]]; then
    _pass "security: \$() in --code not executed"
else
    _fail "security: \$() in --code not executed — file was created"
    rm -f /tmp/cb_inject_test.txt
fi

# Backtick injection
INJECT2='`echo INJECTED2 > /tmp/cb_inject_test2.txt`'
"$CB" --code "$INJECT2" --requires grep 2>/dev/null || true
if [[ ! -f /tmp/cb_inject_test2.txt ]]; then
    _pass "security: backtick in --code not executed"
else
    _fail "security: backtick in --code not executed — file was created"
    rm -f /tmp/cb_inject_test2.txt
fi

# Semicolon chaining in --code value
INJECT3='ls; echo INJECTED3 > /tmp/cb_inject_test3.txt'
"$CB" --code "$INJECT3" --requires ls 2>/dev/null || true
if [[ ! -f /tmp/cb_inject_test3.txt ]]; then
    _pass "security: semicolon chain in --code not executed"
else
    _fail "security: semicolon chain in --code not executed — file was created"
    rm -f /tmp/cb_inject_test3.txt
fi

# Pipe in --requires value should not execute
"$CB" --code "ls | wc" --requires 'wc; echo PWNED > /tmp/cb_inject_test4.txt' 2>/dev/null || true
if [[ ! -f /tmp/cb_inject_test4.txt ]]; then
    _pass "security: injection in --requires not executed"
else
    _fail "security: injection in --requires not executed — file was created"
    rm -f /tmp/cb_inject_test4.txt
fi

# ===========================================================================
# SECTION 14: Performance
# ===========================================================================
section "14. Performance"

# Large file (1 MB)
python3 -c "import os; sys_out = open('$TMPFILE','wb'); sys_out.write(os.urandom(1024*1024)); sys_out.close()" 2>/dev/null || \
    dd if=/dev/urandom of="$TMPFILE" bs=1024 count=1024 2>/dev/null
START=$(date +%s)
"$CB" --file "$TMPFILE" --make-key > /dev/null
END=$(date +%s)
ELAPSED=$(( END - START ))
if [[ "$ELAPSED" -lt 5 ]]; then
    _pass "perf: 1MB file hash completes in < 5s (${ELAPSED}s)"
else
    _fail "perf: 1MB file hash completes in < 5s — took ${ELAPSED}s"
fi

# Very long pipeline (20 stages)
LONG_CODE=$(printf 'cmd%s | ' $(seq 1 19); echo 'cmd20')
out=$("$CB" --code "$LONG_CODE" --pipeline 20)
assert_contains "perf: 20-stage pipeline counted correctly" "$out" "✓ pipeline has exactly 20"

# Many --requires flags (10)
MANY_REQUIRES=()
for i in $(seq 1 10); do MANY_REQUIRES+=(--requires "cmd$i"); done
MANY_CODE=$(printf 'cmd%s | ' $(seq 1 9); echo 'cmd10')
out=$("$CB" --code "$MANY_CODE" "${MANY_REQUIRES[@]}" --pipeline 10)
assert_contains "perf: 10 --requires flags all checked" "$out" "CORRECT"

# ===========================================================================
# SECTION 15: Cross-platform hash parity
# ===========================================================================
section "15. Cross-platform hash parity"

# Known SHA-256 hashes (independently verified)
# echo -n "hello world" | sha256sum  →  b94d27b9934d3e08a52e52d7da7dabfac484efe04681d8714cc940430e5fa9f
# Note: check_bash pipes through printf '%s' which omits trailing newline from $()
# but echo adds one — so we use a known string with echo for this test.

# Verify against a known reference value produced by sha256sum/shasum on both platforms
KNOWN_INPUT="dsc011checkbash"
KNOWN_HASH=$(printf '%s' "$KNOWN_INPUT" | sha256sum 2>/dev/null | awk '{print $1}' || \
             printf '%s' "$KNOWN_INPUT" | shasum -a 256 | awk '{print $1}')
CB_HASH=$("$CB" --make-key "$KNOWN_INPUT")
assert_exact "cross-platform: hash matches system sha256" "$CB_HASH" "$KNOWN_HASH"

# ===========================================================================
# Summary
# ===========================================================================
TOTAL=$(( PASS + FAIL + SKIP ))
echo ""
echo "========================================================"
printf ' Results: %d passed, %d failed, %d skipped / %d total\n' \
    "$PASS" "$FAIL" "$SKIP" "$TOTAL"
echo "========================================================"

if [[ ${#FAILURES[@]} -gt 0 ]]; then
    echo ""
    echo " Failed tests:"
    for f in "${FAILURES[@]}"; do
        printf '   • %s\n' "$f"
    done
    echo ""
fi

[[ "$FAIL" -eq 0 ]] && echo " All tests passed." && exit 0
exit 1
