# CLAUDE.md — Maintainer Context for dsc011-check-bash

This file provides context for AI-assisted maintenance of this repository.
Read it before making changes to `check_bash`, `test_check_bash.sh`, or
`install_check_bash.sh`. It documents not just what the code does but why
it is written the way it is, including decisions made during development
and bugs caught during pre-release testing.

---

## What This Project Is

`check_bash` is a SHA-256–based answer-checking tool for bash code chunks
in Quarto notebooks. It was built for DSC 011: Computing and Statistical
Programming at UC Merced (instructor: David Ardell, GitHub: dhard).

It is the **bash companion to the R `print_and_check` / `dsc011_check`
system** used in the same course. The design mirrors that system's idioms
as closely as bash allows:

| R system | bash system |
|---|---|
| `answer <- expr` | `MY_CODE='...'` |
| `print_and_check(answer, "hash")` | `eval "$MY_CODE" \| check_bash --code "$MY_CODE" "hash"` |
| `quote()` captures expression once | `MY_CODE` variable used for both eval and `--code` |
| SHA-256 via `digest` package | SHA-256 via `sha256sum` / `shasum -a 256` |

The core design principle: **students write their code expression once**,
and that single expression is both executed and structure-checked.

---

## Target Environment

- **Bash version:** 4.2+ required. Do not attempt to support bash 3.2.
- **macOS:** Ships bash 3.2 (GPL v2; Apple won't update it). Students must
  install bash 5 via `brew install bash` and ensure `/opt/homebrew/bin`
  appears before `/bin` on their PATH. Add `export PATH="/opt/homebrew/bin:$PATH"`
  at the **bottom** of `~/.zshrc` so it wins over Apple's `path_helper`.
- **Windows:** WSL2/Ubuntu ships bash 5.x — no action needed.
- **Shebang:** `#!/usr/bin/env bash` throughout — picks up Homebrew bash 5
  on macOS when PATH is correctly configured.
- **Shell discipline:** `set -euo pipefail` is set at the top of all three
  scripts. See the section below on what this means for arrays and expected
  failures.

---

## Key Design Decisions

### 1. `printf '%s'` not `echo`

`echo` behaves differently across platforms with flags like `-n` and `-e`.
`printf '%s'` is used throughout for portable, predictable output with no
implicit newline. Do not replace `printf '%s' "$var"` with `echo "$var"` —
it will break hash consistency on some platforms because `echo` may add or
interpret escape sequences.

### 2. Dual SHA-256 tool detection

macOS provides `shasum` (Perl); Linux/WSL2 provides `sha256sum` (GNU
coreutils). Both produce identical hashes for the same input. The
`_sha256()` helper auto-detects which is available:

```bash
_sha256() {
    if command -v sha256sum &>/dev/null; then
        sha256sum | awk '{print $1}'
    elif command -v shasum &>/dev/null; then
        shasum -a 256 | awk '{print $1}'
    fi
}
```

Any change to how input is fed into `_sha256()` must preserve hash parity
across platforms. Section 15 of the test suite verifies this against a
known reference value. Cross-platform parity was confirmed during
pre-release testing on Darwin arm64 (bash 5.3.9) and Linux x86_64
(bash 5.2.21), and subsequently verified on both ubuntu-latest and
macos-latest via GitHub Actions CI.

### 3. Empty array guarding under `set -euo pipefail`

Under `set -u`, iterating `"${arr[@]}"` when `arr=()` crashes on bash 3.2
with `unbound variable`. Although we now require bash 4.2+, all four array
iterations in `_run_code_checks()` are guarded with `[[ ${#arr[@]} -gt 0 ]]`
for robustness. This pattern documents the historical failure mode and
prevents regressions if the bash version requirement is ever relaxed:

```bash
if [[ ${#REQUIRES[@]} -gt 0 ]]; then
    for cmd in "${REQUIRES[@]}"; do ...
fi
```

If you add new array arguments, guard them the same way.

### 4. `set -euo pipefail` and expected failures

`set -e` exits on any non-zero return. Commands that are expected to
sometimes fail must be handled explicitly:
- Use `|| true` to suppress expected non-zero exits
- Use `2>/dev/null` to suppress expected error output
- The installer uses both patterns extensively when checking PATH and
  shell rc files

When the installer or `check_bash` exits unexpectedly, a `set -e`
interaction with a failing `grep` or `test` is usually the first thing
to investigate.

### 5. Pipeline counter subshell exclusion

`_count_pipeline_stages()` counts top-level `|` characters only — pipes
inside `$(...)` subshells or quoted strings are excluded. This is
implemented as a character-by-character state machine tracking quote depth
and `$(` nesting depth. Section 9 of the test suite verifies the subshell
exclusion and `||` (logical OR) exclusion.

**Do not simplify this to a `grep -o '|' | wc -l` count** — that would
count pipes inside subshells and break section 9 tests.

### 6. Code analysis is text-only, never executed

The `--code` string is **analyzed as text only** — it is never passed to
`eval`, `bash -c`, or any execution context. The `_strip_comments`,
`_extract_commands`, and `_count_pipeline_stages` functions operate purely
on the string value. Section 13 of the test suite verifies that `$()`,
backticks, and semicolon-chained commands in `--code` strings are not
executed. Do not change the code analysis functions in any way that causes
string content to be evaluated.

### 7. Comment stripping before code analysis

`_strip_comments()` removes `# ...` comments before command extraction and
pipeline counting. This prevents comment text from being matched as command
names — e.g. `# use grep here` must not satisfy `--requires grep`. Section
12 of the test suite has an edge case verifying this.

### 8. `mktemp` portability

macOS and Linux handle `mktemp` templates differently:
- macOS: `mktemp -t prefix.XXXXXX` works; full path templates with
  suffixes may collide
- Linux: requires at least 3 X's even with `-t`

**Always use** `mktemp -t prefix.XXXXXX` in both `check_bash` and
`test_check_bash.sh`. This was discovered during pre-release testing when
`mktemp -t cb_test` failed on Linux with "too few X's in template".

### 9. Emoji result signals

Result lines use `✓` (U+2713) and `✗` (U+2717) defined as variables at
the top of the argument-parsing section:

```bash
SIG_PASS="✓"
SIG_FAIL="✗"
```

These are used via a `_rule()` helper inside `_run_code_checks()` and
directly in final result lines. Using variables rather than hardcoded
emoji means the signal characters can be changed in one place if needed
(e.g. for an `--ascii` flag in a future version).

The emoji render correctly in macOS Terminal, iTerm2, WSL2 terminals, and
rendered Quarto HTML output. They were confirmed during pre-release
installer testing on Darwin arm64.

### 10. Exit codes

`check_bash` exits 0 on full pass, 1 on any failure, in all three modes
(output-only, code-only, combined). This enables use in scripts and
Makefile targets:

```bash
eval "$MY_CODE" | check_bash --code "$MY_CODE" --requires grep "HASH" \
    && echo "All checks passed" \
    || echo "Something failed"
```

Prior to v2.1 the script always exited 0, which made scripted use
impossible.

### 11. `--make-key` is instructor-only

The `--make-key` flag is listed under "INSTRUCTOR ONLY" in the `--help`
output. Students should never need it. It generates the SHA-256 hash for
pasting into KEY notebooks. It is intentionally not hidden — instructors
need to discover and use it — but it is annotated so students who read
the help know to ignore it.

---

## Result Output Format

### Output-only mode
```
<answer value>
✓ CORRECT
```
or
```
<answer value>
✗ INCORRECT
```

### Code-only mode
```
[code]
<code string>

  ✓ requires 'grep'
  ✗ pipeline has 2 stage(s), expected exactly 3

✓ CORRECT
```

### Combined mode
```
<answer value>

  ✓ requires 'grep'
  ✓ pipeline has exactly 3 stage(s)

Output: ✓ CORRECT
Code:   ✗ INCORRECT
```

Note: `Code:` and `Output:` labels **only appear in combined mode**. In
code-only mode the final line is bare `✓ CORRECT` / `✗ INCORRECT`.
This distinction matters for test assertions — do not assert `"Code:"` in
code-only mode tests.

---

## Test Suite Structure (`test_check_bash.sh`)

Run as: `bash test_check_bash.sh ./check_bash`
Or against installed copy: `bash test_check_bash.sh "$(which check_bash)"`

The suite has 15 sections and 89 tests. All 89 passed on:
- Darwin arm64, bash 5.3.9, shasum — verified locally during pre-release
- Linux x86_64, ubuntu-latest, sha256sum — verified via GitHub Actions CI
- macOS, macos-latest, shasum — verified via GitHub Actions CI

GitHub Actions CI runs on every push to main. The workflow file is at
`.github/workflows/ci.yml`. The `actions/checkout@v4` step will produce
a Node.js 20 deprecation warning until updated to `@v5` before June 2026,
but this does not affect test correctness.

| Section | What it covers |
|---|---|
| 1 | Hash generation and determinism |
| 2 | Output checking — pipe pattern |
| 3 | Output checking — capture pattern |
| 4 | Quiet flag (-q) |
| 5 | Normalize flag (-n) |
| 6 | File checking (--file) |
| 7 | Code structure — required/forbidden commands |
| 8 | Code structure — flag checking |
| 9 | Pipeline stage counting (subshell and \|\| exclusion) |
| 10 | Combined output + code checking |
| 11 | Multi-line heredoc pattern |
| 12 | Edge cases |
| 13 | Security — injection in --code strings |
| 14 | Performance |
| 15 | Cross-platform hash parity |

### Test framework helpers

| Helper | Use when |
|---|---|
| `assert_contains` | Output must contain a substring |
| `assert_not_contains` | Output must not contain a substring (exact match) |
| `assert_not_contains_word` | Output must not contain a **word** — use when the forbidden word may appear inside another word, e.g. `CORRECT` inside `INCORRECT` |
| `assert_exact` | Output must exactly equal a string |
| `assert_exit_nonzero` | Command must exit non-zero |

**Why `assert_not_contains_word` exists:** `assert_not_contains "CORRECT"`
false-fails when output contains `INCORRECT` because `CORRECT` is a
substring of `INCORRECT`. `assert_not_contains_word` uses `grep -w`
(whole-word matching). Always use it when asserting the absence of
`CORRECT` or `INCORRECT`.

### Timing tests

Section 14 uses `date +%s` (second resolution) rather than `date +%s%N`
(nanosecond resolution). The `%N` format is Linux-only — macOS `date`
does not support it. Second resolution is sufficient for the 5-second
performance threshold.

---

## Bugs Found During Pre-Release Testing

These were caught by the test suite and cross-platform testing. Documented
here so future maintainers understand why the code looks the way it does.

**Empty-string positional arg hang (`check_bash --make-key ""`)**
In subshell contexts, `-t 0` (stdin terminal check) returns false even
when no pipe is present, causing the script to wait on stdin forever.
Fixed by detecting `--make-key` with a single positional arg before the
`-t 0` check and treating the positional arg as the value directly.

**bash 3.2 empty array crash**
`"${arr[@]}"` with `set -u` crashes bash 3.2 when the array is empty.
Discovered when the macOS system bash (3.2) was used instead of Homebrew
bash 5. Fixed by guarding all array iterations. Resolved by requiring
bash 4.2+ and documenting the Homebrew install requirement.

**`mktemp -t cb_test` fails on Linux**
Linux `mktemp` requires at least 3 X's in the template even with `-t`.
Fixed by using `mktemp -t cb_test.XXXXXX` throughout.

**`[PASS]`/`[FAIL]` bracket notation replaced by emoji**
Originally the code used `[PASS]` and `[FAIL]` bracket notation for rule
results. Changed to `✓`/`✗` emoji in v2.1 for visual clarity in terminals
and rendered Quarto HTML. The test suite required a global update of all
expected substrings after this change.

**`date +%s%N` not portable to macOS**
The performance timing test used nanosecond resolution (`%N`) which is
Linux-only. Fixed by using second resolution (`%s`) throughout.

---

## Relationship to the R System

The R-based `print_and_check` / `dsc011_check` system (v2.2) lives in a
separate repository. The two systems share:
- SHA-256 as the hash algorithm
- The "enter once, check twice" design principle
- `✓ CORRECT` / `✗ INCORRECT` as the result vocabulary

---

## Distribution and Installation

Students install via:
```bash
curl -fsSL https://raw.githubusercontent.com/dhard/dsc011-check-bash/main/install_check_bash.sh | bash
```

The installer:
- Downloads `check_bash` to `~/bin/`
- Makes it executable
- Adds `~/bin` to PATH in the appropriate shell rc file
- Runs a smoke test to verify the install

The installer was end-to-end tested on Darwin arm64 (macOS Sequoia,
bash 5.3.9) during pre-release. The installed copy passed all 89 tests.

---

## Release Checklist

Before releasing a new version:

1. Update `VERSION="X.Y"` in `check_bash`
2. Add a `CHANGELOG.md` entry
3. Run `bash test_check_bash.sh ./check_bash` — all tests must pass
4. Run `shellcheck -S warning check_bash test_check_bash.sh install_check_bash.sh`
5. Test on macOS with Homebrew bash 5 and on Linux/WSL2
6. Test the installer end-to-end in a fresh terminal
7. Commit, then: `git tag vX.Y && git push origin vX.Y`
8. Create a GitHub Release from the tag
