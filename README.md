# cmake_template

[![ci](https://github.com/cpp-best-practices/cmake_template/actions/workflows/ci.yml/badge.svg)](https://github.com/cpp-best-practices/cmake_template/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/cpp-best-practices/cmake_template/branch/main/graph/badge.svg)](https://codecov.io/gh/cpp-best-practices/cmake_template)
[![CodeQL](https://github.com/cpp-best-practices/cmake_template/actions/workflows/codeql-analysis.yml/badge.svg)](https://github.com/cpp-best-practices/cmake_template/actions/workflows/codeql-analysis.yml)

A C++ Best Practices GitHub template for getting up and running with C++
quickly.

## At a glance

By default (when building as the top-level project):

 * Address Sanitizer and Undefined Behavior Sanitizer enabled where possible
 * Warnings as errors
 * clang-tidy and cppcheck static analysis
 * CPM for dependencies (vcpkg / Conan also supported — see [Dependency manager](#dependency-manager))

It includes:

 * a minimal CLI starter (`src/app/`)
 * a tiny example library (`src/sample_library/`)
 * unit and constexpr tests (Google Test by default, Catch2 optional)
 * a libFuzzer harness
 * microbenchmarks (Google Benchmark, opt-in via `ENABLE_BENCHMARKS`)
 * Doxygen API docs (opt-in via `ENABLE_DOXYGEN`)
 * a polyglot dev container (LLVM, Python, Rust, Node-based LSPs)
 * a large GitHub Actions testing matrix
 * `.editorconfig`, `.pre-commit-config.yaml`, and a commitlint workflow for
   local + CI hygiene checks
 * community files: `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`,
   issue templates, PR template, and a Keep-a-Changelog `CHANGELOG.md`

It requires:

 * cmake (≥ 3.29)
 * a C++20 compiler (gcc or clang)

## Getting Started

### Use the GitHub template

Click the green **Use this template** button at the top of the repo to
generate your own copy on GitHub. After the cleanup workflow finishes (the
`template-janitor` action handles the rename), clone the result locally:

    git clone https://github.com/<user>/<your_new_repo>.git

### Renaming locally

If you cloned the template directly (no GitHub-template flow) — or you'd
rather rename it yourself — run the bundled one-shot script with the new
name as a valid C++ identifier:

    ./rename.sh my_cool_project

It rewrites the CMake `project()` declaration, `git mv`s the public include
directory, fixes the `<myproject/...>` `#include` paths, and updates the
`myproject::cmake` namespace usages. Then reconfigure:

    cmake -B build -S .

The script is a one-shot — delete `rename.sh` once you're done.

### Quick build & test

    cmake --preset clang-debug
    cmake --build out/build/clang-debug
    ctest --test-dir out/build/clang-debug --output-on-failure

If `clang` isn't installed, swap `clang-debug` for `gcc-debug`. The full
set of presets is `gcc-debug`, `gcc-release`, `clang-debug`, `clang-release`
— run `cmake --list-presets` to see them.

## Project layout

| Path | What it is |
| --- | --- |
| `CMakeLists.txt` | The top-level build script — wires everything together. |
| `CMakePresets.json` | Build presets (`gcc-debug`, `clang-release`, …). Run `cmake --list-presets`. |
| `rename.sh` | One-shot script to rename the project from `myproject` to your choice. Delete after first use. |
| `gcovr.cfg` | Coverage tool config — filters the source tree, sets HTML + Cobertura output paths. |
| `LICENSE` | MIT. |
| `.clang-format` / `.clang-tidy` / `.clangd` | C++ tooling: formatter style, linter check selection, language-server config. |
| `.cmake-format.yaml` | cmake-format style. |
| `.editorconfig` | Cross-editor whitespace + encoding baseline (indent, EOL, charset). |
| `.pre-commit-config.yaml` | [pre-commit](https://pre-commit.com) hooks: clang-format, cmake-format, file hygiene, conventional commits. |
| `commitlint.config.js` | Conventional Commits rule set, enforced by `.github/workflows/commitlint.yml`. |
| `.prettierrc` / `tsconfig.json` | JS/TS tooling defaults — only relevant if you add web/script tooling alongside the C++. |
| `.gitignore` / `.gitattributes` | Git config (build dirs, IDE state, line endings). |
| `vcpkg.json` / `conanfile.txt` | Dependency manifests for the alternate `DEPENDENCY_MANAGER=VCPKG\|CONAN` modes. |
| `CHANGELOG.md` | Project changelog ([Keep a Changelog](https://keepachangelog.com/) format). |
| `CONTRIBUTING.md` / `CODE_OF_CONDUCT.md` / `SECURITY.md` | Community / contribution guidelines. |
| `bench/` | Microbenchmarks (Google Benchmark) — built when `ENABLE_BENCHMARKS=ON`. |
| `.devcontainer/` | VS Code dev container — see [`.devcontainer/README.md`](.devcontainer/README.md). |
| `.github/` | GitHub Actions / Dependabot / template-rename automation — see [`.github/README.md`](.github/README.md). |
| `cmake/` | Build-system modules (warnings, sanitizers, hardening, dependencies, …) — see [`cmake/README.md`](cmake/README.md). |
| `src/sample_library/` | A toy library exposing `factorial(int)`. Replace with your real library. |
| `src/app/` | The minimal `app` CLI executable (with `--message`, `--version`). |
| `include/<projectname>/` | Public headers — exposed to consumers of the library. |
| `test/` | Unit tests in Google Test (default) or Catch2 — `tests_*.cpp` (runtime), `constexpr_tests_*.cpp` (compile-time). |
| `fuzz_test/` | libFuzzer harness — auto-built when sanitizers + libFuzzer are available. |
| `configured_files/` | `config.hpp.in` template — gets project name/version baked in at configure time, exposed as `<projectname>::cmake::project_name` etc. |

## Tutorials

### Build the project

The repo ships [CMake presets](https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html),
so the fastest path is:

    cmake --preset clang-debug          # configure (creates out/build/clang-debug)
    cmake --build out/build/clang-debug # build

Without presets:

    cmake -B build -S . -DCMAKE_BUILD_TYPE=Debug
    cmake --build build

The default build type (when neither preset nor `-DCMAKE_BUILD_TYPE` is set)
is `RelWithDebInfo` — debuggable and optimized.

### Run the tests

    ctest --test-dir out/build/clang-debug --output-on-failure

Or with a matching test preset:

    ctest --preset test-clang-debug

To run a single test by name:

    ctest --test-dir out/build/clang-debug -R 'Factorial' --output-on-failure

### Enable quality checks

Most knobs are CMake `option()`s — top-level builds turn safety checks on
by default. To toggle, pass `-D<NAME>=ON|OFF` at configure time:

    cmake -B build -S . -DENABLE_CLANG_TIDY=OFF -DENABLE_CPPCHECK=OFF

For coverage:

    cmake -B build -S . -DENABLE_COVERAGE=ON -DCMAKE_BUILD_TYPE=Debug
    cmake --build build
    ctest --test-dir build
    gcovr      # uses gcovr.cfg defaults — writes HTML + Cobertura XML to out/

For ThreadSanitizer (mutually exclusive with ASan/LSan):

    cmake -B build -S . \
        -DENABLE_SANITIZER_ADDRESS=OFF \
        -DENABLE_SANITIZER_LEAK=OFF \
        -DENABLE_SANITIZER_THREAD=ON

See the [CMake options reference](#cmake-options-reference) below for the
full list.

### Format your code

C++ formatting (uses `.clang-format`):

    clang-format -i src/**/*.cpp include/**/*.hpp

CMake formatting (uses `.cmake-format.yaml`):

    cmake-format -i CMakeLists.txt cmake/*.cmake

CI enforces clang-format on every PR via the `clang-format-check.yml`
workflow — PRs with unformatted C++ will fail the check.

### Add a new unit test

Edit `test/tests_gtest.cpp` (Google Test) or `test/tests_catch2.cpp`
(Catch2). Tests are auto-discovered, so no CMake change is needed:

```cpp
TEST(MySuite, MyCase)
{
  EXPECT_EQ(my_function(42), expected_value);
}
```

For a compile-time check, add a `static_assert` to
`test/constexpr_tests_gtest.cpp`. A failure becomes a build error — the bug
never reaches a CI run.

### Add a new dependency

Edit `cmake/Dependencies.cmake` and add a new `cpmaddpackage(...)` block:

```cmake
if(NOT TARGET nlohmann_json::nlohmann_json)
  cpmaddpackage(
    NAME
    nlohmann_json
    VERSION
    3.11.3
    GITHUB_REPOSITORY
    "nlohmann/json"
    SYSTEM
    YES)
endif()
```

Then link it from the target that uses it:

```cmake
target_link_libraries(app PRIVATE nlohmann_json::nlohmann_json)
```

The `if(NOT TARGET ...)` guard means a parent project that already supplies
this dependency won't double-fetch.

### Switch compilers

Use the matching preset:

    cmake --preset gcc-debug

Or override directly:

    CC=gcc CXX=g++ cmake -B build -S .

### Generate API docs (Doxygen)

Set `ENABLE_DOXYGEN=ON` and build the `docs` target:

    cmake -B build -S . -DENABLE_DOXYGEN=ON
    cmake --build build --target docs
    open build/docs/html/index.html        # macOS; xdg-open on Linux

Defaults are configured in [`cmake/Doxygen.cmake`](cmake/Doxygen.cmake) —
HTML output, dot graphs, public headers + sources scanned, build/test/dep
directories excluded. The README is used as the main page.

### Run microbenchmarks

The `bench/` directory holds Google Benchmark microbenchmarks, off by default:

    cmake -B build -S . -DENABLE_BENCHMARKS=ON
    cmake --build build --target bench_factorial
    ./build/bench/bench_factorial

Benchmarks aren't registered with CTest — they're timing-sensitive and shouldn't
share a run with correctness tests.

### Run cpplint or include-what-you-use

Both are off by default — they're noisy and most projects only run them
on demand. Install the tool, then turn the option on:

    pip install cpplint
    cmake -B build -S . -DENABLE_CPPLINT=ON
    cmake --build build

    # IWYU — separate package, e.g. `brew install include-what-you-use`
    cmake -B build -S . -DENABLE_IWYU=ON
    cmake --build build

When a tool is requested but not installed, configure prints a `WARNING`
and skips the integration — the build keeps going.

### Run under Valgrind

CTest has a built-in memcheck driver. Once `valgrind` is installed:

    cmake -B build -S . -DCMAKE_BUILD_TYPE=Debug \
        -DENABLE_SANITIZER_ADDRESS=OFF -DENABLE_SANITIZER_UNDEFINED=OFF
    cmake --build build
    ctest --test-dir build -T memcheck --output-on-failure

The memcheck options (`--leak-check=full`, `--error-exitcode=1`, …) are
set in [`CMakeLists.txt`](CMakeLists.txt). Sanitizers and Valgrind don't
mix — turn ASan/UBSan off for the memcheck run.

### Run scan-build (Clang static analyzer)

`scan-build` is a wrapper from the `clang-tools-extra` package. It works
with any preset — wrap the build invocation:

    scan-build cmake -B build -S . -DENABLE_CLANG_TIDY=OFF
    scan-build -o scan-results cmake --build build
    scan-view scan-results/<timestamp>     # opens HTML report

This is independent of `clang-tidy`; the two tools have overlapping but
distinct check sets.

## Dependency manager

The default is **CPM**: `cmake/Dependencies.cmake` fetches sources at
configure time. To switch:

| Manager | Manifest | Configure command |
| --- | --- | --- |
| `CPM` (default) | none | `cmake --preset clang-debug` |
| `VCPKG` | [`vcpkg.json`](vcpkg.json) | `cmake --preset clang-debug -DDEPENDENCY_MANAGER=VCPKG --toolchain=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake` |
| `CONAN` | [`conanfile.txt`](conanfile.txt) | `conan install . --output-folder=build --build=missing` then `cmake --preset clang-debug -DDEPENDENCY_MANAGER=CONAN --toolchain=build/conan_toolchain.cmake` |

Internally each dependency goes through `_resolve_dependency()` — when
`DEPENDENCY_MANAGER` is `CPM` it calls `cpmaddpackage(...)`; otherwise
it falls back to `find_package()` (which works because the vcpkg/Conan
toolchain file pre-populates the registry).

The set of libraries (fmt, spdlog, GoogleTest, CLI11, Catch2, Google
Benchmark) is identical across all three managers — but version pins
differ slightly because each ecosystem ships different snapshots.

## Local hygiene with pre-commit

Install pre-commit once:

    pip install pre-commit       # or: brew install pre-commit
    pre-commit install           # registers .git/hooks/pre-commit
    pre-commit install --hook-type commit-msg   # for conventional-commit checks

After that, every `git commit` runs:

- `clang-format` on changed C/C++ files (matches `.clang-format`).
- `cmake-format` + `cmake-lint` on CMake files.
- File hygiene: trailing-whitespace fix, EOL normalization, large-file
  guard, YAML/JSON/TOML syntax checks.
- `shellcheck` on shell scripts.
- `prettier` on Markdown / YAML / JSON.
- Conventional Commits check on the commit message.

See [`.pre-commit-config.yaml`](.pre-commit-config.yaml). Hooks run on
*staged* files only; force a full sweep with `pre-commit run --all-files`.

## Commit message style

This repo uses [Conventional Commits](https://www.conventionalcommits.org/):

    feat(cmake): add cpplint integration as opt-in ENABLE_CPPLINT option
    fix(sanitizers): skip leak sanitizer on Apple platforms
    docs: clarify how DEPENDENCY_MANAGER selects vcpkg vs Conan

The rules live in [`commitlint.config.js`](commitlint.config.js). CI
enforces them via [`.github/workflows/commitlint.yml`](.github/workflows/commitlint.yml)
on PR titles and on every commit pushed to a PR.

## CMake options reference

All toggles are passed at configure time as `-D<NAME>=ON|OFF`.

| Option | Purpose | Default (top-level) |
| --- | --- | --- |
| `WARNINGS_AS_ERRORS` | Promote warnings to errors (`-Werror`) | ON |
| `ENABLE_CLANG_TIDY` | Run clang-tidy on every TU | ON |
| `ENABLE_CPPCHECK` | Run cppcheck on every TU | ON |
| `ENABLE_CPPLINT` | Run cpplint (Google C++ style linter) on every TU | OFF |
| `ENABLE_IWYU` | Run include-what-you-use on every TU | OFF |
| `ENABLE_DOXYGEN` | Generate API docs — adds `docs` build target | OFF |
| `ENABLE_BENCHMARKS` | Build microbenchmarks under `bench/` (Google Benchmark) | OFF |
| `ENABLE_HARDENING` | `_FORTIFY_SOURCE=3`, stack/CF protectors | ON |
| `ENABLE_GLOBAL_HARDENING` | Apply hardening to dependencies too | ON (when hardening is on) |
| `ENABLE_IPO` | Link-time optimization (LTO) | ON |
| `ENABLE_SANITIZER_ADDRESS` | AddressSanitizer | ON if supported |
| `ENABLE_SANITIZER_UNDEFINED` | UndefinedBehaviorSanitizer | ON if supported |
| `ENABLE_SANITIZER_LEAK` | LeakSanitizer (Linux only) | OFF |
| `ENABLE_SANITIZER_THREAD` | ThreadSanitizer | OFF |
| `ENABLE_SANITIZER_MEMORY` | MemorySanitizer (Clang only) | OFF |
| `ENABLE_COVERAGE` | gcov / llvm-cov instrumentation | OFF |
| `ENABLE_PCH` | Precompiled headers | OFF |
| `ENABLE_CACHE` | ccache / sccache compiler launcher | ON |
| `ENABLE_UNITY_BUILD` | Combine TUs to speed up builds | OFF |
| `ENABLE_GTEST` | Build Google Test test executables | ON |
| `ENABLE_CATCH2` | Build Catch2 test executables | OFF |
| `BUILD_FUZZ_TESTS` | Build the libFuzzer harness | auto¹ |
| `USER_LINKER_OPTION` | Linker selection (`DEFAULT/LLD/MOLD/...`) | `DEFAULT` |
| `CACHE_OPTION` | Compiler cache backend (`ccache`/`sccache`) | `ccache` |
| `FUZZ_RUNTIME` | Seconds the fuzz test runs during ctest | `10` |
| `DEPENDENCY_MANAGER` | Source for third-party libs (`CPM`/`VCPKG`/`CONAN`) — see [Dependency manager](#dependency-manager) | `CPM` |

¹ `BUILD_FUZZ_TESTS` defaults to ON only when libFuzzer **and** a sanitizer
(asan/tsan/ubsan) are both available; otherwise OFF.

## Test framework details

The default is [Google Test](https://google.github.io/googletest/).
[Catch2](https://github.com/catchorg/Catch2) is also wired up and can be
enabled alongside or instead of gtest:

    cmake -B build -S . -DENABLE_GTEST=ON -DENABLE_CATCH2=ON

Each enabled framework builds two executables — `tests_<framework>` (runtime
checks) and `constexpr_tests_<framework>` (compile-time checks) — and
registers them with CTest under a framework-prefixed name (`gtest.unittests.*`,
`catch2.constexpr.*`, etc.) so the two test sets coexist without clashes.

The fuzz harness (`fuzz_test/`) is framework-independent. It uses libFuzzer
directly and only builds when sanitizers + libFuzzer are both available. See
the [libFuzzer tutorial](https://github.com/google/fuzzing/blob/master/tutorial/libFuzzerTutorial.md).

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

## Design choices

The template starts a C++ project with safe, modern defaults. Each choice
below explains *why*, so you can keep it, swap it, or turn it off.

### Goals

1. Catch bugs at compile time, not in production.
2. Stay portable across GCC and Clang on Linux/macOS.
3. Work the same way as a top-level project or as a subdirectory dependency.

### Layout

| File | Role |
| --- | --- |
| `CMakeLists.txt` | Top-level wiring. |
| `cmake/ProjectOptions.cmake` | All options and setup macros. |
| `cmake/Dependencies.cmake` | CPM package fetch, gated by `if(NOT TARGET ...)`. |
| `cmake/*.cmake` (other) | One concern per file (warnings, sanitizers, hardening, ...). |

`PROJECT_IS_TOP_LEVEL` flips defaults: strict when you own the build, quiet
when you are a dependency.

### C++ standard

C++20, set only if a parent project has not chosen one. `CMAKE_CXX_EXTENSIONS`
is off so the standard flag is `-std=c++20`, not `-std=gnu++20`. This avoids
`-Wpedantic` conflicts with precompiled headers.

### Warnings

`cmake/CompilerWarnings.cmake` enables a curated set per compiler:
`-Wall -Wextra -Wshadow -Wconversion -Wpedantic ...` on GCC/Clang, with a few
extra GCC-only checks. Top-level builds add `-Werror`. Source:
[cppbestpractices](https://github.com/lefticus/cppbestpractices/blob/master/02-Use_the_Tools_Available.md).

### Sanitizers

ASan and UBSan are on by default for top-level GCC/Clang builds when a link
probe shows them working. TSan, LSan, and MSan are off — they conflict with
each other and MSan needs an instrumented standard library.

### Hardening

`cmake/Hardening.cmake` adds `_FORTIFY_SOURCE=3` (release builds),
`_GLIBCXX_ASSERTIONS`, `-fstack-protector-strong`, `-fcf-protection`, and
`-fstack-clash-protection` when supported. When no full sanitizer is active,
the UBSan minimal runtime is layered on top.

### Static analysis

clang-tidy and cppcheck run as part of the build, on by default at top level.
They are separate options because one tool may not be installed in every
environment.

### Link-time optimization

IPO/LTO is on by default at top level. It is gated through
`check_ipo_supported` so unsupported toolchains skip it.

### Dependencies

[CPM](https://github.com/cpm-cmake/CPM.cmake) fetches sources at configure
time. Each package is gated by `if(NOT TARGET ...)`, so a parent project can
supply its own version. `SYSTEM YES` silences warnings from third-party
headers. Default set: fmt, spdlog, GoogleTest, CLI11. Catch2 is fetched only
when `ENABLE_CATCH2=ON`.

### Targets and packaging

`options` and `warnings` are `INTERFACE` libraries that hold flags. Real
targets link them via the alias targets `${PROJECT_NAME}::options` /
`${PROJECT_NAME}::warnings` to inherit the configuration without touching
global state. `CPack` package names embed compiler, version, and short Git
SHA, so a binary maps to one build.

### Defaults for daily use

The default build type is `RelWithDebInfo` — debuggable and fast.
`compile_commands.json` is always exported, for editors and clang tooling.

## More Details

 * [Docker / Dev Container](.devcontainer/README.md)
 * [GitHub Configuration](.github/README.md)
 * [CMake Modules](cmake/README.md)
 * [Build the template from scratch (tutorial)](dummy_cpp_dev.md)
 * [Contributing guide](CONTRIBUTING.md)
 * [Code of Conduct](CODE_OF_CONDUCT.md)
 * [Security policy](SECURITY.md)
 * [Changelog](CHANGELOG.md)
