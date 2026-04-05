# Changelog

All notable changes to `check_bash` are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).  
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [2.0.0] — 2026-03-31

### Added
- `--code` / `-c` flag: pass student code as a string for structural analysis
- `--requires` / `-r`: assert that a command is present in the code (repeatable)
- `--forbid` / `-F`: assert that a command is absent from the code (repeatable)
- `--pipeline` / `-p`: assert exact number of top-level pipeline stages
- `--pipeline-min` / `--pipeline-max`: flexible pipeline stage bounds
- `--requires-flag`: assert a flag/option string is present (repeatable)
- `--forbid-flag`: assert a flag/option string is absent (repeatable)
- Combined mode: output hash checking and code structure checking in one call
- Code-only mode: structure checks without an output hash
- Per-rule `[PASS]`/`[FAIL]` detail lines in all code-check output
- Two-line summary (`Output: CORRECT/INCORRECT` + `Code: CORRECT/INCORRECT`) in combined mode
- Pipeline counter correctly excludes pipes inside `$(...)` subshells and quoted strings
- Comment stripping before command extraction (prevents `# grep` from satisfying `--requires grep`)
- `--make-key` in code-only mode prints the spec summary for instructor KEY notebooks

### Changed
- Version header updated to 2.0
- Help text expanded to cover all new options and usage patterns

---

## [1.0.0] — 2026-03-24

### Added
- Initial release
- SHA-256 output checking via pipe pattern (`cmd | check_bash HASH`)
- SHA-256 output checking via capture pattern (`check_bash "$answer" HASH`)
- File byte-level checking (`--file path HASH`)
- `--make-key` for instructor hash generation
- `--normalize` / `-n` for whitespace-tolerant hashing
- `--quiet` / `-q` to suppress answer echo
- Auto-detection of `sha256sum` (Linux/WSL2) vs `shasum -a 256` (macOS)
- Student installer script (`install_check_bash.sh`)
- `~/bin` PATH management in `.bashrc` / `.zshrc` / `.bash_profile`
