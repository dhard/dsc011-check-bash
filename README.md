# dsc011-check-bash

[![CI](https://github.com/dhard/dsc011-check-bash/actions/workflows/ci.yml/badge.svg)](https://github.com/dhard/dsc011-check-bash/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Platform: macOS | Linux | WSL2](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL2-blue)

`check_bash` is a lightweight bash script for immediate answer feedback in
Quarto and RStudio notebooks. It is the bash equivalent of the `print_and_check`
system used for R chunks in DSC 011 at UC Merced. Students write a command or
pipeline once, execute it, and receive an immediate `CORRECT` or `INCORRECT`
based on a SHA-256 hash embedded in the notebook by the instructor.

It supports:
- **Output checking** — hash-verify stdout from any command or pipeline
- **File checking** — hash-verify raw bytes of any file a student writes
- **Code structure checking** — verify required commands, forbidden commands,
  pipeline length, and required/forbidden flags
- **Combined checking** — output and code structure in a single call

---

## Installation

### Students: one-time setup

Open a Terminal (macOS) or WSL2 bash shell (Windows 11) and run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/dhard/dsc011-check-bash/main/install_check_bash.sh)
```

This will:
1. Create `~/bin/` if it does not exist
2. Download `check_bash` into `~/bin/`
3. Add `~/bin` to your `PATH` in `.bashrc`, `.zshrc`, or `.bash_profile`
4. Run a smoke test to confirm the installation works

After installation, open a new terminal window (or run `source ~/.bashrc`) and
verify with:

```bash
check_bash --help
```

### Instructors: manual installation

```bash
curl -fsSL https://raw.githubusercontent.com/dhard/dsc011-check-bash/main/check_bash \
  -o ~/bin/check_bash
chmod +x ~/bin/check_bash
```

---

## Quick Start

### Output checking — pipe pattern

```bash
ls /tmp | wc -l | check_bash "HASH_FROM_INSTRUCTOR"
```

### Output checking — capture pattern

```bash
answer=$(ls /tmp | wc -l)
check_bash "$answer" "HASH_FROM_INSTRUCTOR"
```

### Code structure checking

```bash
MY_CODE='ls /tmp | grep ".txt" | wc -l'
check_bash --code "$MY_CODE" \
  --requires grep \
  --forbid awk \
  --pipeline 3
```

### Combined: output + code structure in one call

```bash
MY_CODE='ls /tmp | grep ".txt" | wc -l'
eval "$MY_CODE" | check_bash \
  --code "$MY_CODE" \
  --requires grep \
  --forbid awk \
  --pipeline 3 \
  "HASH_FROM_INSTRUCTOR"
```

Output:
```
       5
  [PASS] requires 'grep'
  [PASS] forbids 'awk'
  [PASS] pipeline has exactly 3 stage(s)

Output: CORRECT
Code:   CORRECT
```

### Multi-line pipelines (heredoc pattern)

For multi-line commands, assign to a variable using a heredoc:

```bash
MY_CODE=$(cat <<'EOF'
find . -name "*.csv" \
  | xargs grep "Merced" \
  | wc -l
EOF
)
eval "$MY_CODE" | check_bash \
  --code "$MY_CODE" \
  --requires find \
  --requires grep \
  --requires wc \
  --pipeline 3 \
  "HASH_FROM_INSTRUCTOR"
```

---

## Using check_bash in Quarto Notebooks

### Setup chunk

Add the following to your notebook's setup chunk. The key setting is
`comment = ""`, which removes the `##` prefix that knitr adds to bash output
by default.

````r
```{r setup, include=FALSE}
knitr::opts_chunk$set(
  echo    = TRUE,
  cache   = TRUE,
  warning = FALSE,
  message = FALSE,
  collapse = TRUE,
  comment = ""        # removes ## prefix from all chunk output
)
```
````

### Plain bash chunk (most demonstrations)

````bash
```{bash}
MY_CODE='ls /tmp | grep "txt" | wc -l'
eval "$MY_CODE" | check_bash \
  --code "$MY_CODE" \
  --requires grep \
  --pipeline 3 \
  "HASH_FROM_INSTRUCTOR"
```
````

### Styled-bash chunk (stderr visually distinguished in rendered HTML)

For demonstrations where you want stderr shown in red and stdout in green in
the rendered HTML output, use the `styled-bash` custom knitr engine. Add this
to your setup chunk alongside the standard options:

````r
```{r setup, include=FALSE}
# ... standard options above ...

knitr::knit_engines$set(`styled-bash` = function(options) {
  code <- paste(options$code, collapse = "\n")
  tmp_out <- tempfile(); tmp_err <- tempfile()
  on.exit({ unlink(tmp_out); unlink(tmp_err) })
  system2("bash", args = c("-c", shQuote(code)), stdout = tmp_out, stderr = tmp_err)
  stdout_txt <- paste(readLines(tmp_out, warn = FALSE), collapse = "\n")
  stderr_txt <- paste(readLines(tmp_err, warn = FALSE), collapse = "\n")
  html_parts <- character(0)
  if (nzchar(stdout_txt)) {
    s <- gsub("^CORRECT$",   '<span style="color:#2e7d32;font-weight:bold">CORRECT</span>',   stdout_txt)
    s <- gsub("^INCORRECT$", '<span style="color:#c62828;font-weight:bold">INCORRECT</span>', s)
    html_parts <- c(html_parts, paste0('<pre style="background:#f8f8f8;border-left:3px solid #4caf50;padding:.5em 1em">', s, '</pre>'))
  }
  if (nzchar(stderr_txt)) {
    html_parts <- c(html_parts, paste0('<pre style="background:#fff3f3;border-left:3px solid #e53935;color:#b71c1c;padding:.5em 1em"><strong>[stderr]</strong>\n', htmltools::htmlEscape(stderr_txt), '</pre>'))
  }
  knitr::engine_output(options, options$code, out = list(
    structure(list(src = paste(html_parts, collapse = "\n")), class = c("knit_asis","knit_asis_url"))
  ))
})
```
````

Then use it in chunks where stderr matters:

````
```{styled-bash}
ls /nonexistent/path
echo "This goes to stdout"
```
````

---

## Instructor: Generating Hashes for KEY Notebooks

### Output hash

```bash
# From a command:
echo "expected answer" | check_bash --make-key

# From a captured value:
answer=$(some_command)
check_bash --make-key "$answer"

# From a file:
check_bash --file expected_output.csv --make-key
```

### Normalized hash (whitespace-tolerant)

Use `-n` on both the instructor side and the student side:

```bash
some_command | check_bash -n --make-key
```

Students then run:

```bash
some_command | check_bash -n "HASH"
```

### Code structure spec (no hash needed)

Code structure checks don't require a hash — the flags themselves are the
specification. Print a summary of the spec for pasting into a KEY notebook:

```bash
check_bash --code "$MY_CODE" \
  --requires grep --forbid awk --pipeline 3 \
  --make-key
```

---

## All Options

| Flag | Short | Description |
|---|---|---|
| `--normalize` | `-n` | Strip/normalize whitespace before hashing |
| `--file <path>` | `-f` | Hash raw bytes of a file |
| `--make-key` | `-k` | Print hash instead of checking |
| `--quiet` | `-q` | Suppress printing the answer value |
| `--code <string>` | `-c` | Student code to analyze structurally |
| `--requires <cmd>` | `-r` | Command that must appear (repeatable) |
| `--forbid <cmd>` | `-F` | Command that must not appear (repeatable) |
| `--pipeline <N>` | `-p` | Exactly N top-level pipeline stages |
| `--pipeline-min <N>` | | At least N pipeline stages |
| `--pipeline-max <N>` | | At most N pipeline stages |
| `--requires-flag <f>` | | Option string that must appear (repeatable) |
| `--forbid-flag <f>` | | Option string that must not appear (repeatable) |
| `--help` | `-h` | Show help |

---

## Running the Tests

```bash
git clone https://github.com/dhard/dsc011-check-bash.git
cd dsc011-check-bash
bash test_check_bash.sh ./check_bash
```

The test suite covers: hash generation, pipe and capture patterns, normalize,
file checking, code structure rules, pipeline counting (including subshell
exclusion), combined mode, edge cases, injection resistance, performance, and
cross-platform hash consistency.

---

## Compatibility

| Platform | Shell | SHA-256 tool |
|---|---|---|
| macOS 13+ | bash 3.2+, zsh | `shasum -a 256` |
| Ubuntu 20.04+ | bash 5+ | `sha256sum` |
| WSL2 (Ubuntu) | bash 5+ | `sha256sum` |

---

## License

MIT — see [LICENSE](LICENSE).  
Copyright © 2026 David Ardell, UC Merced.
