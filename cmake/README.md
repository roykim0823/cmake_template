# `cmake/` — Build-System Modules

Every `.cmake` file lives here. The root holds only `CMakeLists.txt`. Two
files in this folder act as **entry points** that `CMakeLists.txt` calls
into; the rest are **utility modules** included on demand.

## How it fits together

```
CMakeLists.txt                   ← the only .cmake-related file at the root
├── include(cmake/PreventInSourceBuilds.cmake)   ← fail fast on cmake -B .
├── include(cmake/ProjectOptions.cmake)
│   ├── setup_options()          ← declare ENABLE_HARDENING / ENABLE_GTEST / ...
│   ├── global_options()         ← apply project-wide (IPO, hardening)
│   └── local_options()          ← apply per-target (warnings, sanitizers)
│       ├── include(cmake/StandardProjectSettings.cmake)
│       ├── include(cmake/CompilerWarnings.cmake)
│       ├── include(cmake/Linker.cmake)
│       ├── include(cmake/Sanitizers.cmake)
│       ├── include(cmake/StaticAnalyzers.cmake)
│       ├── include(cmake/Cache.cmake)
│       ├── include(cmake/Coverage.cmake)
│       ├── include(cmake/Hardening.cmake)
│       ├── include(cmake/InterproceduralOptimization.cmake)
│       └── include(cmake/LibFuzzer.cmake)        ← used during option resolution
├── include(cmake/Dependencies.cmake)
│   └── setup_dependencies()
│       └── include(cmake/CPM.cmake) → cpmaddpackage(fmt, spdlog, gtest, ...)
└── package_project(TARGETS ...)
    └── include(cmake/PackageProject.cmake)       ← install + CMake config files
```

`ProjectOptions.cmake` `include(...)`s a utility module from this folder
only when its corresponding option is on. Defaults are *strict when
top-level*, *quiet when consumed as a subdirectory* — see
[`../README.md#design-choices`](../README.md#design-choices) for the rationale.

## Quick map

### Entry points (called from `CMakeLists.txt`)

| Module | LoC | What it does |
| --- | --- | --- |
| `ProjectOptions.cmake` | ~155 | Declares all `option(ENABLE_… )` toggles, probes sanitizer support, then orchestrates the utility modules per target. |
| `Dependencies.cmake` | ~90 | One `setup_dependencies()` function that fetches all third-party libraries via CPM. Each fetch is gated by `if(NOT TARGET …)` so a parent project can supply its own version. |

### Utility modules (included on demand)

| Module | LoC | What it does |
| --- | --- | --- |
| `StandardProjectSettings.cmake` | 28 | Default `RelWithDebInfo`, exports `compile_commands.json`, color compiler diagnostics. |
| `PreventInSourceBuilds.cmake` | 19 | Hard-fail if you run `cmake -B .` (in-source build). Self-invoking on include. |
| `CompilerWarnings.cmake` | 82 | The `-Wall -Wextra -Wshadow -Wconversion -Wpedantic …` set, dispatched per compiler. |
| `Hardening.cmake` | 95 | `_FORTIFY_SOURCE=3`, stack & CF protectors, optional UBSan minimal runtime. |
| `Sanitizers.cmake` | 69 | Composes `-fsanitize=address,undefined,thread,leak,memory` flags from option toggles. |
| `StaticAnalyzers.cmake` | ~100 | `enable_clang_tidy` and `enable_cppcheck` macros — auto-run during the build. |
| `Coverage.cmake` | 6 | `enable_coverage(target)` → adds `--coverage -g` (gcc/clang). |
| `Linker.cmake` | 20 | Lets the user pick a linker via `-DUSER_LINKER_OPTION=LLD/MOLD/...`. |
| `Cache.cmake` | 33 | Detect `ccache`/`sccache`, wire as `CMAKE_*_COMPILER_LAUNCHER`. |
| `InterproceduralOptimization.cmake` | 9 | Probe IPO/LTO support and enable globally. |
| `LibFuzzer.cmake` | 17 | Probe whether `-fsanitize=fuzzer` works — gates `BUILD_FUZZ_TESTS` defaults. |
| `PackageProject.cmake` | 186 | Implements `package_project()` — install + CMake config-file packaging used at the end of `CMakeLists.txt`. |
| `CPM.cmake` | 24 | Vendor stub that downloads CPM.cmake at configure time. |

## Module reference

### Entry points

#### `ProjectOptions.cmake`
Three macros split by *when* they should run, all called from `CMakeLists.txt`:

- **`setup_options()`** — declares every `ENABLE_*` / `WARNINGS_AS_ERRORS` /
  `BUILD_FUZZ_TESTS` `option()`. Defaults flip based on `PROJECT_IS_TOP_LEVEL`
  (strict when this is the top project, quiet when consumed as a
  subdirectory). Also probes `SUPPORTS_ASAN` / `SUPPORTS_UBSAN` via test
  programs.
- **`global_options()`** — applies project-wide settings: IPO/LTO and global
  hardening flags. Runs *before* `setup_dependencies()` so dependencies
  inherit the global compile flags.
- **`local_options()`** — creates the `options` and `warnings` interface
  libraries and wires them up: warnings, linker, sanitizers, PCH, ccache,
  clang-tidy, cppcheck, coverage. These are scoped to *your* code via the
  alias targets `${PROJECT_NAME}::options` / `${PROJECT_NAME}::warnings`,
  so dependencies aren't subjected to your strict checks.

#### `Dependencies.cmake`
A single `function(setup_dependencies)` that calls `cpmaddpackage(...)` for
each third-party lib (fmt, spdlog, googletest, CLI11, optionally Catch2).
Each block is gated by `if(NOT TARGET …)` so a parent project can supply
its own version.

It's a `function()` (not `macro()`) on purpose — the new variable scope
prevents `CMAKE_CXX_FLAGS` mutations from inside CPM from leaking out.

### Utility modules

#### `StandardProjectSettings.cmake`
Sets a sensible default `CMAKE_BUILD_TYPE=RelWithDebInfo` if none is given,
turns on `CMAKE_EXPORT_COMPILE_COMMANDS` (so clangd / clang-tidy can find
files), and adds `-fcolor-diagnostics` / `-fdiagnostics-color=always`.
Included unconditionally for top-level builds.

#### `PreventInSourceBuilds.cmake`
Defines `assure_out_of_source_builds()` and immediately calls it. If
`CMAKE_SOURCE_DIR == CMAKE_BINARY_DIR`, configuration aborts with
`FATAL_ERROR`. The intent: keep the source tree clean of CMake artifacts.

#### `CompilerWarnings.cmake`
`set_project_warnings(target ON_AS_ERRORS CLANG GCC CUDA)` populates an
`INTERFACE` library with per-compiler warning flags. Pass `""` for the
last three to use the curated default lists. Top-level builds enable
`-Werror`.

#### `Hardening.cmake`
`enable_hardening(target global ubsan_minimal_runtime)`:
- `-D_GLIBCXX_ASSERTIONS` always
- `-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3` in non-Debug builds
- `-fstack-protector-strong`, `-fcf-protection`, `-fstack-clash-protection`
  (probed per-flag — silently skipped if unsupported)
- The UBSan minimal runtime when no full sanitizer is already active.

If `global=ON`, options apply via `add_compile_options`/`add_link_options`
to *everything* in the build (including dependencies). Otherwise scoped to
the named target.

#### `Sanitizers.cmake`
`enable_sanitizers(target ASAN LEAK UBSAN TSAN MSAN)` builds a
`-fsanitize=…` list from the boolean inputs and applies it via
`target_compile_options` + `target_link_options`. Notable:
- LSan is filtered out on Apple (linker rejects `-fsanitize=leak`).
- TSan/MSan refuse to combine with ASan/LSan.
- MSan only honoured under Clang.

#### `StaticAnalyzers.cmake`
Two macros, both wire CMake's per-target hooks:
- `enable_cppcheck(WARN_AS_ERR OPTIONS)` → sets `CMAKE_CXX_CPPCHECK` so
  cppcheck runs alongside the compiler on every TU.
- `enable_clang_tidy(target WARN_AS_ERR)` → sets `CMAKE_CXX_CLANG_TIDY`.
  Refuses to combine with PCH on non-Clang compilers (gcc PCH breaks
  clang-tidy).

#### `Coverage.cmake`
`enable_coverage(target)` → adds `--coverage -g` to compile + link.
Used by `gcovr` in CI to produce `coverage.xml`.

#### `Linker.cmake`
`configure_linker(target)` exposes `USER_LINKER_OPTION` (cache string,
default `DEFAULT`) with values `DEFAULT|SYSTEM|LLD|GOLD|BFD|MOLD|SOLD|APPLE_CLASSIC`.
Sets the `LINKER_TYPE` target property — CMake 3.29+ feature.

Override on the command line:
```bash
cmake -B build -DUSER_LINKER_OPTION=MOLD
```

#### `Cache.cmake`
`enable_cache()` exposes `CACHE_OPTION` (default `ccache`, also `sccache`),
calls `find_program`, and wires `CMAKE_CXX_COMPILER_LAUNCHER`.

> Inside the dev container, ccache is *also* wired via PATH shims in
> `/usr/local/bin` (see `.devcontainer/Dockerfile`). The module is here as
> a fallback when building outside the container.

#### `InterproceduralOptimization.cmake`
`enable_ipo()` probes via CMake's bundled `CheckIPOSupported` module and
sets `CMAKE_INTERPROCEDURAL_OPTIMIZATION=ON` if available. Enabled by
default at top level.

#### `LibFuzzer.cmake`
`check_libfuzzer_support(<var>)` writes a tiny `LLVMFuzzerTestOneInput`
program and tries to compile + link with `-fsanitize=fuzzer`. The result
sets the default for `BUILD_FUZZ_TESTS` — fuzz tests are auto-enabled
when libFuzzer + a sanitizer (asan/tsan/ubsan) are both available.

#### `PackageProject.cmake`
Implements `package_project(TARGETS … PUBLIC_DEPENDENCIES …)` — produces
the install rules, the CMake config file (so downstream consumers can use
`find_package(...)`), and the `package-config.cmake` exports. Drives the
`cpack` step at the end of CI.

This file is essentially upstream library code from
[cppbestpractices](https://github.com/lefticus/cppbestpractices); you
shouldn't normally need to edit it.

#### `CPM.cmake`
Bootstrap stub that downloads the real CPM (`v0.42.1` pinned with SHA-256)
into the build directory and `include()`s it. After this runs,
`cpmaddpackage(...)` is available — see `Dependencies.cmake` for usage.

This is also upstream vendor code; treat it as opaque.

## Common tasks

**"I want to add a new compiler warning":**
edit `CLANG_WARNINGS` and/or `GCC_WARNINGS` in `CompilerWarnings.cmake`.

**"clang-tidy is too strict / too noisy":**
edit `.clang-tidy` at the repo root (the rule list there). The CMake
plumbing here just *invokes* the tool with that config.

**"I want to disable a hardening flag":**
either gate it in `Hardening.cmake`, or pass `-DENABLE_HARDENING=OFF` /
`-DENABLE_GLOBAL_HARDENING=OFF` to skip the module entirely.

**"I want to switch to mold":**
`cmake -B build -DUSER_LINKER_OPTION=MOLD` (no source change needed).

**"My CI complains `cmake` is too old":**
bump `cmake_minimum_required` in `CMakeLists.txt:1` *and*
`cmakeMinimumRequired` in `CMakePresets.json`.

**"I want to add a new dependency":**
add a `cpmaddpackage(NAME … GIT_TAG … SYSTEM YES)` block to
`cmake/Dependencies.cmake`, gated by `if(NOT TARGET <namespace>::<lib>)`.

**"I want to add a new option":**
add `option(ENABLE_FOO …)` inside `setup_options()` in
`cmake/ProjectOptions.cmake`, then act on it inside `local_options()` /
`global_options()` as appropriate.

**"How do I add a new utility module here?":**
1. Drop `MyThing.cmake` in this folder defining a function/macro.
2. `include(cmake/MyThing.cmake)` from `cmake/ProjectOptions.cmake`
   (typically inside `local_options()` or `global_options()`).
3. Wire it behind an `option(ENABLE_MYTHING …)` toggle if it's optional.
