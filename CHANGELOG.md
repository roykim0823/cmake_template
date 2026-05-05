# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `.editorconfig` — cross-editor whitespace/encoding baseline.
- `cpplint` integration as opt-in `ENABLE_CPPLINT` CMake option.
- `include-what-you-use` integration as opt-in `ENABLE_IWYU` CMake option.
- Doxygen support via `cmake/Doxygen.cmake` and `ENABLE_DOXYGEN` option.
- Google Benchmark scaffolding under `bench/`, gated by `ENABLE_BENCHMARKS`.
- Valgrind memcheck wiring through CTest (`ctest -T memcheck`).
- Configurable dependency manager: `DEPENDENCY_MANAGER=CPM|VCPKG|CONAN`
  with manifest files `vcpkg.json` and `conanfile.txt`.
- `.pre-commit-config.yaml` for local clang-format / cmake-format / hygiene hooks.
- `commitlint.config.js` + `.github/workflows/commitlint.yml` to enforce
  Conventional Commits.
- `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md` community files.
- Issue templates (`.github/ISSUE_TEMPLATE/`) and PR template.
- This `CHANGELOG.md`.

[Unreleased]: https://github.com/cpp-best-practices/cmake_template/compare/HEAD
