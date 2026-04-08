# Changelog

All notable changes to `check_bash` are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [2.2.0] — 2026-04-08

### Added
- **`Justfile`** — primary interface for install, uninstall, test, and lint.
  Replaces direct use of `install_check_bash.sh` for users with a cloned repo.
  Recipes: `just install`, `just install-system`, `just uninstall`,
  `just test`, `just check`, `just version`.
- **`--user` flag** on `install_check_bash.sh` — explicit user install to
  `~/bin` (no sudo). This is the default when no flag is given.
- **`--system` flag** on `install_check_bash.sh` — system install to
  `/usr/local/bin`. Auto-detects whether sudo is needed and prompts
  for elevation only if required.
- **`--uninstall` flag** on `install_check_bash.sh` — removes `check_bash`
  from both `~/bin` and `/usr/local/bin` (whichever exist), and cleans
  the PATH entry from shell rc files.
- **Local repo detection** — when run from a cloned repo, the installer
  copies the local `check_bash` directly instead of downloading from GitHub.
  This makes `just install` work correctly offline and from feature branches.
- **Conflict detection** — `just install-system` detects an existing user
  install and offers to remove it to prevent PATH shadowing.

### Changed
- `install_check_bash.sh` is now a multi-mode script called by the Justfile.
  The curl-pipe path (`curl ... | bash`) continues to work unchanged for
  users who have not cloned the repo, defaulting to `--user` install.

---

## [2.0.0] — 2026-03-31

### Added
- **Code structure checking** via `--code <string>` with the following rules:
  - `--requires <cmd>` — command must appear in student code (repeatable)
  - `--forbid <cmd>` — command must not appear (repeatable)
  - `--pipeline <N>` — code must have exactly N pipeline stages
  - `--pipeline-min <N>` / `--pipeline-max <N>` — flexible stage bounds
  - `--requires-flag <f>` / `--forbid-flag <f>` — flag/option checking (repeatable)
- **Combined output + code checking** in a single call: pipe output into
  `check_bash --code "$MY_CODE" [rules] HASH`
- **Code-only mode**: omit the hash argument to check structure without output
- **Per-rule detailed feedback**: each rule prints `[PASS]` or `[FAIL]` with
  a description of what failed
- **Two-line summary in combined mode**: `Output: CORRECT/INCORRECT` and
  `Code: CORRECT/INCORRECT` are printed as separate labeled lines
- **Pipeline counter** correctly excludes pipes inside `$(...)` subshells,
  single-quoted strings, and double-quoted strings
- **`--make-key` for code specs**: when used with `--code` and no hash,
  prints the rule specification for pasting into KEY notebooks
- `--quiet` / `-q` flag to suppress printing the answer value

### Fixed
- Empty-string positional argument (`check_bash --make-key ""`) no longer
  hangs waiting on stdin in subshell contexts
- `--make-key` with a single positional arg now works reliably regardless of
  whether stdin is a tty (fixes unreliable `-t 0` detection in `$()`)

### Changed
- Output format in combined mode uses labeled lines (`Output:` / `Code:`)
  rather than a single `CORRECT`/`INCORRECT` to distinguish check types

---

## [1.0.0] — 2026-03-24

### Added
- Initial release of `check_bash` for DSC 011 at UC Merced
- SHA-256 output checking via pipe pattern: `cmd | check_bash <HASH>`
- SHA-256 output checking via capture pattern: `check_bash "$answer" <HASH>`
- File content checking: `check_bash --file <path> <HASH>`
- Key generation: `--make-key` flag for instructor KEY notebooks
- Whitespace normalization: `-n` / `--normalize` flag
- Auto-detection of `sha256sum` (Linux/WSL2) vs `shasum -a 256` (macOS)
- Student installer script `install_check_bash.sh`
