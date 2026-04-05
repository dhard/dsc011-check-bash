# Contributing to dsc011-check-bash

Thank you for your interest in improving `check_bash`. Contributions from
students, instructors, and the broader open-source community are welcome.

## Reporting Bugs

Open an issue at https://github.com/dhard/dsc011-check-bash/issues and include:

1. Your operating system and version (macOS 14, Ubuntu 22.04, WSL2, etc.)
2. Your bash version (`bash --version`)
3. The exact command you ran
4. The output you received
5. The output you expected

## Suggesting Features

Open an issue with the label `enhancement`. Describe the pedagogical use case
— what would students be checking that isn't currently supported?

## Submitting a Pull Request

1. Fork the repository and create a branch from `main`.
2. Make your changes to `check_bash`.
3. Run the full test suite and confirm it passes:
   ```bash
   bash test_check_bash.sh ./check_bash
   ```
4. Run ShellCheck and fix any warnings:
   ```bash
   shellcheck -S warning check_bash
   ```
5. Add tests to `test_check_bash.sh` that cover your change.
6. Update `CHANGELOG.md` under an `[Unreleased]` section.
7. Open a pull request with a clear description of the change.

## Code Style

- Pure bash only — no Python, Perl, or awk in the main script.
- All functions prefixed with `_` are internal.
- New flags must be documented in the header comment block and in `README.md`.
- Prefer `printf` over `echo` for portable output.
- Always quote variables: `"$VAR"` not `$VAR`.

## Compatibility Requirements

All changes must pass CI on both `ubuntu-latest` and `macos-latest`.
The script must work with bash 3.2+ (the macOS system bash version).

## Versioning

This project uses [Semantic Versioning](https://semver.org/):
- **Patch** (1.0.x): bug fixes that don't change behavior
- **Minor** (1.x.0): new flags or features, backward compatible
- **Major** (x.0.0): breaking changes to existing flags or output format
