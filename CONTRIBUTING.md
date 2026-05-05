# Contributing

Thanks for your interest in contributing! This template's goal is to make
new C++ projects start with safe, modern defaults — every change should
move that goal forward without making the template harder to consume.

## Quick start

```bash
# 1. Configure & build
cmake --preset clang-debug          # or gcc-debug
cmake --build out/build/clang-debug

# 2. Run tests
ctest --test-dir out/build/clang-debug --output-on-failure
```

If `clang` isn't available locally, swap `clang-debug` for `gcc-debug`.

## Local quality gate

Before opening a PR, please run the same checks CI runs:

```bash
# Format C++ and CMake
clang-format -i $(git diff --name-only --diff-filter=AM HEAD~1 -- '*.cpp' '*.hpp')
cmake-format -i $(git diff --name-only --diff-filter=AM HEAD~1 -- 'CMakeLists.txt' '*.cmake')

# Run the full test suite with sanitizers (default at top level)
ctest --test-dir out/build/clang-debug --output-on-failure
```

Or — easier — install pre-commit and let it run on every commit:

```bash
pip install pre-commit   # or: brew install pre-commit
pre-commit install
```

See [`.pre-commit-config.yaml`](.pre-commit-config.yaml) for the hooks
that get run.

## Commit messages

This repo uses [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>[optional scope]: <description>

[optional body]

[optional footer]
```

Common types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`,
`build`, `perf`. Examples:

```
feat(cmake): add cpplint integration as opt-in ENABLE_CPPLINT option
fix(sanitizers): skip leak sanitizer on Apple platforms
docs: clarify how DEPENDENCY_MANAGER selects vcpkg vs Conan
```

`commitlint` (run in CI via `.github/workflows/commitlint.yml`) will fail
on non-conforming PR titles.

## Pull request checklist

- [ ] Tests added or updated (`test/tests_*.cpp` or `test/constexpr_tests_*.cpp`).
- [ ] No new compiler warnings (`-Werror` is on at top level).
- [ ] clang-tidy and cppcheck pass locally if you have them installed.
- [ ] If you added a CMake option, document it in `README.md`'s
  *CMake options reference* table.
- [ ] If you added a new piece of tooling, add a corresponding step to
  `dummy_cpp_dev.md` so the tutorial stays in sync with the repo.
- [ ] If your change is user-visible, add a line to the `Unreleased`
  section of `CHANGELOG.md`.

## Reporting bugs

Please use the **Bug report** issue template. Include:

- The configure command (or preset name) you ran.
- Compiler + version (`clang --version` / `g++ --version`).
- CMake version (`cmake --version`).
- The full error output, in a fenced code block.

## Reporting security issues

See [`SECURITY.md`](SECURITY.md) — please do **not** open a public issue
for security vulnerabilities.

## Code of conduct

Participation in this project is governed by the
[Code of Conduct](CODE_OF_CONDUCT.md).
