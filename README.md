# dsc011-check-bash

[![CI](https://github.com/dhard/dsc011-check-bash/actions/workflows/ci.yml/badge.svg)](https://github.com/dhard/dsc011-check-bash/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20WSL2%2FLinux-blue)](#installation)

**`check_bash`** is a SHA-256–based answer-checking tool for bash code chunks
in [Quarto](https://quarto.org) notebooks. It was developed for
[DSC 011: Computing and Statistical Programming](https://github.com/dhard)
at UC Merced to give students immediate feedback on both the **output** of
their shell commands and the **structure** of their code (required commands,
pipeline depth, flags used).

It is the bash companion to the R-based `print_and_check` / `dsc011_check`
system used in the same course.

---

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
  - [Recommended — clone and install with just](#recommended--clone-and-install-with-just)
  - [Quick install — no clone needed](#quick-install--no-clone-needed)
  - [Verify your install](#verify-your-install)
- [Typical workflow](#typical-workflow)
- [Usage](#usage)
  - [Pattern 1 — pipe](#pattern-1--pipe)
  - [Pattern 2 — capture](#pattern-2--capture)
  - [Pattern 3 — file checking](#pattern-3--file-checking)
  - [Pattern 4 — code structure only](#pattern-4--code-structure-only)
  - [Pattern 5 — combined output + code](#pattern-5--combined-output--code)
- [Quarto / RStudio Integration](#quarto--rstudio-integration)
- [Instructor Key Generation](#instructor-key-generation)
- [All Options](#all-options)
- [Just Recipes](#just-recipes)
- [Contributing](#contributing)
- [License](#license)

---

## Features

- **Output checking** — hash-verify the stdout of any command or pipeline
- **File checking** — hash-verify the byte contents of any output file
- **Code structure checking** — enforce required commands, forbidden commands,
  required or forbidden flags/options, and exact or bounded pipeline depth
- **Combined checking** — one call checks both output correctness and code
  structure, with separate labeled result lines
- **Instructor key generation** — `--make-key` flag produces hashes to paste
  into KEY notebooks; no separate tool needed
- **Cross-platform** — auto-detects `sha256sum` (Linux/WSL2) and
  `shasum -a 256` (macOS); produces identical hashes on both
- **Whitespace normalization** — optional `-n` flag for forgiving matching
- **Injection-safe** — `--code` strings are analyzed as text, never executed
- **Zero runtime dependencies** — pure bash, requires only coreutils

---

## Prerequisites

**Required:**

| Tool | macOS | WSL2/Ubuntu |
|------|-------|-------------|
| `just` | `brew install just` | `sudo apt install just` |
| bash 5+ | `brew install bash` | included |

**Optional** (only needed for `just check`):

| Tool | macOS | WSL2/Ubuntu |
|------|-------|-------------|
| `shellcheck` | `brew install shellcheck` | `sudo apt install shellcheck` |

**macOS only — one-time system setup:**

RStudio launched from the Dock does not see Homebrew's PATH. Fix this once:

```bash
echo /opt/homebrew/bin | sudo tee /etc/paths.d/homebrew
```

Then restart your Mac. See [Quarto / RStudio Integration](#quarto--rstudio-integration)
for details.

---

## Installation

### Recommended — clone and install with just

```bash
git clone https://github.com/dhard/dsc011-check-bash.git
cd dsc011-check-bash
just install-system    # installs to /usr/local/bin, prompts for sudo if needed
```

Or to install without sudo to `~/bin`:

```bash
just install
```

To remove a previous install before switching locations:

```bash
just uninstall         # removes from ~/bin and/or /usr/local/bin
just install-system    # then install to system
```

### Quick install — no clone needed

If you just want `check_bash` without cloning the repo:

```bash
curl -fsSL https://raw.githubusercontent.com/dhard/dsc011-check-bash/main/install_check_bash.sh | bash
```

This installs to `~/bin` and adds it to your PATH automatically.

For a system install via curl:

```bash
curl -fsSL https://raw.githubusercontent.com/dhard/dsc011-check-bash/main/install_check_bash.sh | bash -s -- --system
```

### Verify your install

```bash
check_bash --version      # check_bash 2.2
echo "hello" | check_bash --make-key   # prints a 64-char hex string
```

---

## Typical workflow

```bash
# Install just and clone the repo
brew install just                          # macOS
sudo apt install just                      # WSL2/Ubuntu

git clone https://github.com/dhard/dsc011-check-bash.git
cd dsc011-check-bash

# Read the docs in your terminal
glow README.md

# Remove any previous install
just uninstall

# Run the test suite to verify everything works
just test

# Install system-wide
just install-system
check_bash --version
```

---

## Usage

### Pattern 1 — pipe

Pipe command output directly into `check_bash`:

```bash
some_command | check_bash <HASH>
```

Example:

```bash
wc -l /etc/hosts | check_bash "a3f2..."
```

Output:

```
      12 /etc/hosts
✓ CORRECT
```

---

### Pattern 2 — capture

Assign output to a variable, then check it. This mirrors the R
`answer <- ...; print_and_check(answer, "hash")` pattern:

```bash
answer=$(some_command)
check_bash "$answer" <HASH>
```

Example:

```bash
answer=$(wc -l < /etc/hosts)
check_bash "$answer" "a3f2..."
```

---

### Pattern 3 — file checking

Check the raw byte contents of a file:

```bash
check_bash --file <path> <HASH>
```

Example:

```bash
grep "Merced" data.csv > results.txt
check_bash --file results.txt "b7c9..."
```

Output:

```
[file: results.txt]
SHA-256: b7c9...
✓ CORRECT
```

---

### Pattern 4 — code structure only

Check that student code uses required tools and pipeline structure, without
checking output. Useful when output is non-deterministic but the approach
must be specific:

```bash
MY_CODE='cat data.csv | grep "Merced" | wc -l'
check_bash --code "$MY_CODE" \
  --requires grep \
  --requires wc \
  --forbid awk \
  --pipeline 3
```

Output:

```
[code]
cat data.csv | grep "Merced" | wc -l

  ✓ requires 'grep'
  ✓ requires 'wc'
  ✓ forbids 'awk'
  ✓ pipeline has exactly 3 stage(s)

✓ CORRECT
```

For multi-line pipelines, use a heredoc:

```bash
MY_CODE=$(cat <<'EOF'
find . -name "*.csv" \
  | xargs grep "Merced" \
  | wc -l
EOF
)
check_bash --code "$MY_CODE" \
  --requires find --requires grep --requires wc \
  --pipeline 3
```

---

### Pattern 5 — combined output + code

The recommended pattern for most exercises. The student writes the command
once as `MY_CODE` — it is both executed and structure-checked in one call:

```bash
MY_CODE='ls -la | grep ".csv" | wc -l'
eval "$MY_CODE" | check_bash \
  --code "$MY_CODE" \
  --requires ls \
  --requires grep \
  --requires wc \
  --forbid cat \
  --pipeline 3 \
  "<OUTPUT_HASH>"
```

Output (both correct):

```
       4
  ✓ requires 'ls'
  ✓ requires 'grep'
  ✓ requires 'wc'
  ✓ forbids 'cat'
  ✓ pipeline has exactly 3 stage(s)

Output: ✓ CORRECT
Code:   ✓ CORRECT
```

Output (correct output, wrong structure):

```
       4
  ✗ requires 'ls' — not found in code
  ✓ requires 'grep'
  ✓ requires 'wc'
  ✓ forbids 'cat'
  ✗ pipeline has 2 stage(s), expected exactly 3

Output: ✓ CORRECT
Code:   ✗ INCORRECT
```

---

## Quarto / RStudio Integration

### Setup chunk

Add to the `setup` chunk of every bash-using notebook:

````markdown
```{r setup, include=FALSE}
knitr::opts_chunk$set(
  echo     = TRUE,
  cache    = TRUE,
  warning  = FALSE,
  message  = FALSE,
  collapse = FALSE,
  comment  = "",     # removes ## prefix from bash chunk output
  error    = TRUE    # prevents failed check_bash from killing the render
)

# Fix PATH for bash chunks on macOS (safe no-op on Linux/WSL2)
homebrew_paths <- c("/opt/homebrew/bin", "/usr/local/bin")
existing <- homebrew_paths[dir.exists(homebrew_paths)]
if (length(existing) > 0)
  Sys.setenv(PATH = paste(c(existing, Sys.getenv("PATH")), collapse = ":"))
```
````

### Bash version guard

Add this chunk immediately after setup in every bash-using notebook. It
gives students a clear, actionable error if the wrong bash is being used:

````markdown
```{bash bash-check}
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo "ERROR: bash $BASH_VERSION is too old."
    echo "Fix: launch RStudio from your terminal: open -a RStudio"
    echo "Or:  echo /opt/homebrew/bin | sudo tee /etc/paths.d/homebrew"
    exit 1
fi
echo "✓ bash $BASH_VERSION — $(which bash)"
```
````

### macOS PATH fix (one-time system setup)

RStudio launched from the Dock inherits a minimal PATH from `launchd` that
excludes `/opt/homebrew/bin`. The permanent fix uses `/etc/paths.d/`, which
macOS's `path_helper` reads for all processes including GUI apps:

```bash
echo /opt/homebrew/bin | sudo tee /etc/paths.d/homebrew
# Then restart your Mac
```

This is different from `~/.zshrc`, which only applies to interactive
terminal sessions. After this fix, RStudio launched from the Dock and
your terminal both use the same Homebrew bash 5.

WSL2/Ubuntu users do not need this fix — Ubuntu ships bash 5.x and
RStudio Server inherits the correct PATH automatically.

### Example student notebook chunk

````markdown
```{bash}
#| label: ex-pipeline
MY_CODE='cat /etc/hosts | grep "local" | wc -l'
eval "$MY_CODE" | check_bash \
  --code "$MY_CODE" \
  --requires grep \
  --requires wc \
  --pipeline 3 \
  "YOUR_HASH_HERE"
```
````

A complete setup chunk template with all recommended options is in
[`docs/DSC011_bash_setup_reference.qmd`](docs/DSC011_bash_setup_reference.qmd).

---

## Instructor Key Generation

`--make-key` is an instructor-only flag. Students should never need it.

```bash
# Output hash (pipe pattern)
echo "expected output" | check_bash --make-key

# Output hash (capture pattern)
answer=$(some_command)
check_bash --make-key "$answer"

# File hash
check_bash --file expected_output.csv --make-key

# Normalized hash (student must also use -n)
some_command | check_bash -n --make-key
```

---

## All Options

| Option | Short | Description |
|--------|-------|-------------|
| `--version` | `-V` | Print version and exit. |
| `--normalize` | `-n` | Strip and normalize whitespace before hashing. |
| `--quiet` | `-q` | Suppress printing the answer value. |
| `--file <path>` | `-f` | Hash raw bytes of a file (always exact). |
| `--code <string>` | `-c` | Student code string to analyze structurally. |
| `--requires <cmd>` | `-r` | Command that must appear in `--code`. Repeatable. |
| `--forbid <cmd>` | `-F` | Command that must NOT appear in `--code`. Repeatable. |
| `--pipeline <N>` | `-p` | Code must have exactly N pipeline stages. |
| `--pipeline-min <N>` | | Pipeline must have at least N stages. |
| `--pipeline-max <N>` | | Pipeline must have at most N stages. |
| `--requires-flag <f>` | | Flag/option that must appear (e.g. `"-r"`). Repeatable. |
| `--forbid-flag <f>` | | Flag/option that must NOT appear. Repeatable. |
| `--help` | `-h` | Show usage information. |
| `--make-key` | `-k` | **(Instructor only)** Print SHA-256 hash for KEY notebooks. |

---

## Just Recipes

From inside the cloned repo:

| Recipe | Description |
|--------|-------------|
| `just install` | Install to `~/bin` (no sudo) |
| `just install-system` | Install to `/usr/local/bin` (sudo if needed) |
| `just uninstall` | Remove from `~/bin` and/or `/usr/local/bin` |
| `just test` | Run the full test suite (89 tests) |
| `just check` | Run ShellCheck on all scripts (requires `shellcheck`) |
| `just version` | Print current `check_bash` version |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to report bugs, suggest
features, and submit pull requests.

---

## License

MIT License. Copyright (c) 2026 David Ardell.
See [LICENSE](LICENSE) for full text.

---

*Developed for DSC 011: Computing and Statistical Programming, UC Merced.*
