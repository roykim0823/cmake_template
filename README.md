# cmake_template

[![ci](https://github.com/cpp-best-practices/cmake_template/actions/workflows/ci.yml/badge.svg)](https://github.com/cpp-best-practices/cmake_template/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/cpp-best-practices/cmake_template/branch/main/graph/badge.svg)](https://codecov.io/gh/cpp-best-practices/cmake_template)
[![CodeQL](https://github.com/cpp-best-practices/cmake_template/actions/workflows/codeql-analysis.yml/badge.svg)](https://github.com/cpp-best-practices/cmake_template/actions/workflows/codeql-analysis.yml)

## About cmake_template

This is a C++ Best Practices GitHub template for getting up and running with C++ quickly.

By default (when building as the top-level project)

 * Address Sanitizer and Undefined Behavior Sanitizer enabled where possible
 * Warnings as errors
 * clang-tidy and cppcheck static analysis
 * CPM for dependencies

It includes

 * a basic CLI example
 * examples for fuzz, unit, and constexpr testing
 * large GitHub action testing matrix

It requires

 * cmake
 * a compiler


This project gets you started with a simple example of using FTXUI, which happens to also be a game.


## Getting Started

### Use the GitHub template
First, click the green `Use this template` button near the top of this page.
This will take you to GitHub's ['Generate Repository'](https://github.com/cpp-best-practices/cmake_template/generate)
page.
Fill in a repository name and short description, and click 'Create repository from template'.
This will allow you to create a new repository in your GitHub account,
prepopulated with the contents of this project.

After creating the project please wait until the cleanup workflow has finished 
setting up your project and committed the changes.

Now you can clone the project locally and get to work!

    git clone https://github.com/<user>/<your_new_repo>.git

## More Details

 * [Docker](README_docker.md)
 * [Renaming the Project](README_rename.md)

## Testing

The default test framework is [Google Test](https://google.github.io/googletest/).
[Catch2](https://github.com/catchorg/Catch2) is also wired up and can be enabled
alongside or instead of gtest. Toggle frameworks with CMake options:

    cmake -B build -S . -DENABLE_GTEST=ON -DENABLE_CATCH2=ON

`ENABLE_GTEST` defaults to ON; `ENABLE_CATCH2` defaults to OFF. Each enabled
framework builds its own `tests_*`, `constexpr_tests_*`, and
`relaxed_constexpr_tests_*` executables and registers them with CTest under a
framework-prefixed name (`gtest.unittests.*`, `catch2.unittests.*`, etc.).

## Fuzz testing

See [libFuzzer Tutorial](https://github.com/google/fuzzing/blob/master/tutorial/libFuzzerTutorial.md)

## Dev container scope

The `.devcontainer/` image is a polyglot environment. Beyond the C++ toolchain
(LLVM 19: clang, clangd, clang-tidy, lld, lldb, llvm-cov, etc.; CMake; Ninja;
ccache), it also bundles:

- **Python** — `uv` (installed in the image) plus a default Python 3.13
  managed by uv.
- **Rust** — installed via `rustup` (cargo, rustc).
- **Node.js 22** — used to host editor language servers globally:
  `typescript`, `typescript-language-server`, `pyright`,
  `vscode-langservers-extracted` (HTML/CSS/JSON), `eslint`, and
  `@typescript-eslint/*`.

The Python and Rust toolchains support C++ adjacent workflows (build scripts,
code generators, native bindings); the Node-based LSPs let the same container
host editor tooling for any web/script files that live alongside the C++.
