# Dummy C++ Dev — Build `cmake_template` from Scratch

A step-by-step tutorial: starting from an empty directory, recreate the
`cmake_template` project one file at a time. Each step explains *what*
you're adding and *why*.

You'll end up with the same repository you're reading this from — but the
goal is to understand every piece, not to copy it.

## Step index

**Core (build, test, quality, CI):**

1. [Dev container](#step-1--the-dev-container)
2. [Minimal CMake "Hello, world"](#step-2--minimal-cmake-hello-world)
3. [Git basics](#step-3--git-basics) — adds `.gitignore`, `.gitattributes`, `.editorconfig`
4. [CMake presets](#step-4--cmake-presets)
5. [A library and a public header](#step-5--a-library-and-a-public-header)
6. [Configured files (build metadata in C++)](#step-6--configured-files-build-metadata-in-c)
7. [Dependencies via CPM](#step-7--dependencies-via-cpm) — and how to switch to vcpkg / Conan
8. [Compiler warnings + the options/warnings pattern](#step-8--compiler-warnings--the-optionswarnings-pattern)
9. [Sanitizers](#step-9--sanitizers)
10. [Static analysis](#step-10--static-analysis) — clang-tidy, cppcheck, cpplint, IWYU, scan-build, valgrind
11. [Hardening](#step-11--hardening)
12. [Linker, IPO, ccache](#step-12--linker-ipo-ccache)
13. [Testing with Google Test](#step-13--testing-with-google-test)
14. [gmock for test doubles](#step-14--gmock-for-test-doubles)
15. [Catch2 alongside (optional alternative)](#step-15--catch2-alongside-optional-alternative)
16. [Fuzz testing with libFuzzer](#step-16--fuzz-testing-with-libfuzzer)
17. [Coverage](#step-17--coverage)
18. [Packaging and install](#step-18--packaging-and-install)
19. [GitHub Actions CI](#step-19--github-actions-ci)
20. [Template janitor + the rename script](#step-20--template-janitor--the-rename-script)
21. [Final polish](#step-21--final-polish)

**Software-engineering practices (steps 22–26):**

22. [Pre-commit hooks](#step-22--pre-commit-hooks)
23. [Commit message linting](#step-23--commit-message-linting)
24. [Doxygen / API docs](#step-24--doxygen--api-docs)
25. [Microbenchmarks (Google Benchmark)](#step-25--microbenchmarks-google-benchmark)
26. [Community files (CONTRIBUTING, SECURITY, CoC, issue/PR templates, CHANGELOG)](#step-26--community-files)

---

## Prerequisites

- **Docker Desktop** (or any Docker engine — Linux native, OrbStack on macOS, …)
- **VS Code** with the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension installed
- **Git** and a terminal
- Basic familiarity with C++ and the command line

> **Why we start with the container, not C++ code.** Compiling C++ depends
> on a toolchain — compiler version, standard library, linker, CMake,
> Ninja — that's painful to keep consistent across macOS/Linux/Windows
> hosts. We freeze the toolchain inside a Docker image first, so every
> later step works the same on every machine.

---

## Step 1 — The dev container

**Goal**: a reproducible Linux build environment with LLVM 19 (clang,
clang-format, clang-tidy, lldb, lld), CMake, Ninja, ccache, and Node.js
(for editor language servers). At the end of this step VS Code can "Reopen
in Container" and you'll be inside Ubuntu 24.04 with the toolchain ready.

**Files added in this step**

| File | Purpose |
| --- | --- |
| `.devcontainer/Dockerfile` | Recipe for the container image. Installs the toolchain. |
| `.devcontainer/devcontainer.json` | VS Code Dev Containers configuration — build args, mounts, extensions, settings. |
| `.devcontainer/.dockerignore` | Files Docker should *not* copy into the build context. |

(There's a fourth file, `devcontainer-lock.json`, that gets auto-generated
later when we add `features:` to `devcontainer.json`. Don't create it by
hand.)

### What is a "dev container"?

The [Dev Containers extension](https://containers.dev/) reads
`.devcontainer/devcontainer.json`, builds the Docker image described by
`Dockerfile`, mounts your workspace folder into the container, and
connects a VS Code server running *inside* the container. From your
host's point of view it looks like normal VS Code; from the editor's
point of view, the file system, terminal, compiler, and debugger are all
the container's.

### 1a. Create `.devcontainer/Dockerfile`

```dockerfile
FROM mcr.microsoft.com/devcontainers/cpp:2-ubuntu24.04

ARG LLVM_VERSION=19
ARG NODE_VERSION=22
ARG USERNAME=vscode

# Use bash with pipefail for all RUN commands so a piped command failing
# (e.g. `curl ... | sh`) actually fails the build instead of silently
# succeeding.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ── LLVM / Clang ─────────────────────────────────────────────────────────────
# clang-19 and friends ship in Ubuntu 24.04's universe repo, so we don't
# need a third-party apt source. update-alternatives wires the unversioned
# tool names (clang, clang++, clangd, ...) to the versioned binaries that
# apt installs (clang-19, clang++-19, ...).
RUN apt-get update && apt-get install -y --no-install-recommends \
        clang-${LLVM_VERSION} \
        clang-format-${LLVM_VERSION} \
        clang-tidy-${LLVM_VERSION} \
        clang-tools-${LLVM_VERSION} \
        clangd-${LLVM_VERSION} \
        lld-${LLVM_VERSION} \
        lldb-${LLVM_VERSION} \
        llvm-${LLVM_VERSION} \
        libc++-${LLVM_VERSION}-dev \
        libc++abi-${LLVM_VERSION}-dev \
    && for tool in clang clang++ clangd clang-format clang-tidy \
                   scan-build scan-view \
                   lldb lld ld.lld \
                   llvm-ar llvm-as llvm-cov llvm-dis llvm-dwarfdump \
                   llvm-link llvm-nm llvm-objcopy llvm-objdump \
                   llvm-profdata llvm-ranlib llvm-readelf llvm-size \
                   llvm-strings llvm-strip llvm-symbolizer; do \
         bin="/usr/bin/${tool}-${LLVM_VERSION}"; \
         [ -f "$bin" ] && update-alternatives --install "/usr/bin/${tool}" "${tool}" "${bin}" 100 || true; \
       done \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Static analyzers / runtime checkers / docs ───────────────────────────────
# Each tool here backs a CMake option or a workflow we wire up later:
#   cppcheck     → ENABLE_CPPCHECK   (Step 10)
#   iwyu         → ENABLE_IWYU       (Step 10e)
#   doxygen      → ENABLE_DOXYGEN    (Step 24) — graphviz gives `dot`
#   valgrind     → ctest -T memcheck (Step 10e)
#   shellcheck   → pre-commit hook   (Step 22)
RUN apt-get update && apt-get install -y --no-install-recommends \
        cppcheck \
        iwyu \
        doxygen \
        graphviz \
        valgrind \
        shellcheck \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── ccache ───────────────────────────────────────────────────────────────────
# ccache caches compiler output, so a rebuild after a header tweak is
# nearly instant. We symlink ccache as `clang`/`clang++`/`cc`/`c++` in
# /usr/local/bin so it transparently intercepts compilation no matter how
# CMake invokes the compiler.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ccache \
    && rm -rf /var/lib/apt/lists/* \
    && echo "max_size = 0" > /etc/ccache.conf \
    && ln -sf /usr/bin/ccache /usr/local/bin/clang \
    && ln -sf /usr/bin/ccache /usr/local/bin/clang++ \
    && ln -sf /usr/bin/ccache /usr/local/bin/cc \
    && ln -sf /usr/bin/ccache /usr/local/bin/c++

# ── Node.js (for editor language servers) ───────────────────────────────────
RUN curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# ── Editor language servers ─────────────────────────────────────────────────
RUN npm install -g \
    typescript@^5 typescript-language-server@^4 pyright@^1 \
    vscode-langservers-extracted@^4 \
    @typescript-eslint/parser@^8 @typescript-eslint/eslint-plugin@^8 \
    eslint@^9

# ── User-level setup ──────────────────────────────────────────────────────────
USER ${USERNAME}
WORKDIR /home/${USERNAME}

# uv (a fast Python package manager) and Python 3.13.
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${HOME}/.bashrc" \
    && "${HOME}/.local/bin/uv" python install 3.13

# Python-based dev tools — installed as standalone uv tools so each gets
# its own isolated environment but lands on PATH (~/.local/bin).
#   cpplint       → ENABLE_CPPLINT     (Step 10e)
#   cmake-format  → matches .cmake-format.yaml + the pre-commit hook
#   pre-commit    → .pre-commit-config.yaml runner (Step 22)
#   conan         → DEPENDENCY_MANAGER=CONAN (Step 7f)
RUN "${HOME}/.local/bin/uv" tool install cpplint \
    && "${HOME}/.local/bin/uv" tool install cmake-format \
    && "${HOME}/.local/bin/uv" tool install pre-commit \
    && "${HOME}/.local/bin/uv" tool install conan

# Rust via rustup (some C++ adjacent tools / build scripts are written in Rust).
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && echo 'source "$HOME/.cargo/env"' >> "${HOME}/.bashrc"

# vcpkg — shallow clone + bootstrap. Backs DEPENDENCY_MANAGER=VCPKG (Step 7f).
RUN git clone --depth 1 https://github.com/microsoft/vcpkg.git "${HOME}/vcpkg" \
    && "${HOME}/vcpkg/bootstrap-vcpkg.sh" -disableMetrics \
    && echo 'export VCPKG_ROOT="$HOME/vcpkg"' >> "${HOME}/.bashrc" \
    && echo 'export PATH="$VCPKG_ROOT:$PATH"' >> "${HOME}/.bashrc"

# Compiler env so plain `cmake -B build -S .` picks clang and ccache without
# extra flags.
RUN echo 'export CCACHE_CONFIGPATH=/etc/ccache.conf' >> "${HOME}/.bashrc" \
    && echo 'export CC="clang"' >> "${HOME}/.bashrc" \
    && echo 'export CXX="clang++"' >> "${HOME}/.bashrc"

# devcontainer runtime expects root as the final USER; remoteUser in
# devcontainer.json controls who VS Code connects as.
USER root
```

### 1b. Create `.devcontainer/devcontainer.json`

```jsonc
// For format details, see https://aka.ms/devcontainer.json
{
    "name": "AI Compiler Environment",
    "build": {
        "dockerfile": "Dockerfile",
        "args": { "LLVM_VERSION": "19", "NODE_VERSION": "22" }
    },

    // SYS_PTRACE + unconfined seccomp are required for lldb/gdb to attach
    // to processes inside the container.
    "runArgs": [
        "--cap-add=SYS_PTRACE",
        "--security-opt", "seccomp=unconfined"
    ],

    // Share host credentials so you don't have to re-login inside the container.
    "mounts": [
        "source=${localEnv:HOME}/.copilot,target=/home/vscode/.copilot,type=bind,consistency=cached",
        "source=${localEnv:HOME}/.gitconfig,target=/home/vscode/.gitconfig,type=bind,consistency=cached",
        "source=${localEnv:HOME}/.ssh,target=/home/vscode/.ssh,type=bind,consistency=cached"
    ],

    "remoteEnv": {
        "CC": "clang",
        "CXX": "clang++",
        "CCACHE_CONFIGPATH": "/etc/ccache.conf",
        "PATH": "${containerEnv:PATH}:/usr/lib/node_modules/.bin"
    },

    "customizations": {
        "vscode": {
            "extensions": [
                "llvm-vs-code-extensions.vscode-clangd",
                "vadimcn.vscode-lldb",
                "ms-python.python",
                "ms-python.vscode-pylance",
                "charliermarsh.ruff",
                "dbaeumer.vscode-eslint",
                "esbenp.prettier-vscode",
                "rust-lang.rust-analyzer",
                "EditorConfig.EditorConfig",
                "streetsidesoftware.code-spell-checker"
            ],
            "settings": {
                "terminal.integrated.defaultProfile.linux": "bash",
                "editor.formatOnSave": true,
                "editor.rulers": [100],
                "C_Cpp.intelliSenseEngine": "disabled",
                "clangd.path": "/usr/bin/clangd",
                "clangd.arguments": [
                    "--background-index", "--clang-tidy",
                    "--completion-style=detailed", "--header-insertion=iwyu",
                    "--cross-file-rename", "--inlay-hints=true",
                    "--pch-storage=memory"
                ]
            }
        }
    },
    "remoteUser": "vscode",
    "features": {
        "ghcr.io/devcontainers/features/git:1": {},
        "ghcr.io/devcontainers/features/node:2": {},
        "ghcr.io/devcontainer-config/features/dot-config:4": {}
    }
}
```

**Key fields:**

- `build.dockerfile` / `build.args` — point at the Dockerfile, pass build args
- `runArgs` — `SYS_PTRACE` + unconfined seccomp let lldb/gdb attach
- `mounts` — bind host `~/.gitconfig`, `~/.ssh`, `~/.copilot` into the container
- `remoteEnv` — set `CC`/`CXX` so plain `cmake` picks the right compiler
- `customizations.vscode.extensions` — auto-installed extensions; we disable
  Microsoft IntelliSense and use **clangd** instead
- `features` — reusable feature packages from
  [containers.dev](https://containers.dev/features). Adding entries auto-creates
  `devcontainer-lock.json`.

### 1c. Create `.devcontainer/.dockerignore`

```
# Build directories and binary files
build/
out/
cmake-build-*/
target/
dist/
node_modules/

# User-specific CMake state
CMakeUserPresets.json
CMakeCache.txt
CMakeFiles/

# IDE / editor / OS metadata
.vs/
.idea/
.vscode/
*.swp
*~
.DS_Store
._*

# Logs
*.log

# Git
.git/
.gitignore
```

`.dockerignore` is the Dockerfile equivalent of `.gitignore` — anything
matched here is excluded from the build context Docker sends to the daemon.

### 1d. Try it

```bash
git init
git add .devcontainer/
git commit -m "Step 1: dev container"
```

In VS Code: **Dev Containers: Reopen in Container** (Cmd/Ctrl+Shift+P).
First build: 5-15 minutes. Once connected, in a container terminal:

```bash
clang --version    # Ubuntu clang version 19.x
cmake --version    # ≥ 3.29
ninja --version
ccache --version
which cc           # → /usr/local/bin/cc → ccache
```

### Where you stand

```
.
└── .devcontainer/
    ├── .dockerignore
    ├── Dockerfile
    └── devcontainer.json
```

> **Next**: A minimal CMake project — your first buildable C++.

---

## Step 2 — Minimal CMake "Hello, world"

**Goal**: an `app` executable built with CMake. Three files of CMake glue,
one C++ source file, one command to build, one to run.

**Files added**

| File | Purpose |
| --- | --- |
| `CMakeLists.txt` | Top-level — declares the project. |
| `src/CMakeLists.txt` | Just descends into `app/`. |
| `src/app/CMakeLists.txt` | Defines the `app` executable. |
| `src/app/main.cpp` | The actual C++ entry point. |

### 2a. `CMakeLists.txt`

```cmake
cmake_minimum_required(VERSION 3.29)

if(NOT DEFINED CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 20)
endif()
set(CMAKE_CXX_EXTENSIONS OFF)

project(myproject VERSION 0.0.1 LANGUAGES CXX)

add_subdirectory(src)
```

Three lines worth highlighting:

- `cmake_minimum_required(VERSION 3.29)` — must be the first line; sets
  policy defaults to a known modern baseline.
- `CMAKE_CXX_STANDARD 20` *only if undefined* — this is what makes the
  project play nicely as a sub-dependency: a parent project can pin its
  own standard, and we won't override it.
- `CMAKE_CXX_EXTENSIONS OFF` → emits `-std=c++20`, not `-std=gnu++20`.
  Avoids `-Wpedantic` clashes with PCH later.

### 2b. `src/CMakeLists.txt`

```cmake
add_subdirectory(app)
```

One line. The `src/` directory will gain more entries (`sample_library/`)
in step 5.

### 2c. `src/app/CMakeLists.txt`

```cmake
add_executable(app main.cpp)
```

One line. `add_executable` declares a target named `app` built from
`main.cpp`.

### 2d. `src/app/main.cpp`

```cpp
#include <iostream>

int main()
{
    std::cout << "Hello, world\n";
    return 0;
}
```

### 2e. Try it

```bash
cmake -B build -S .
cmake --build build
./build/src/app/app
# → Hello, world
```

`cmake -B build -S .` configures (creates a `build/` directory).
`cmake --build build` builds. Then run the binary.

### Where you stand

```
.
├── .devcontainer/
├── CMakeLists.txt
└── src/
    ├── CMakeLists.txt
    └── app/
        ├── CMakeLists.txt
        └── main.cpp
```

> **Next**: Tell git to ignore the `build/` directory we just created.

---

## Step 3 — Git basics

**Goal**: stop tracking generated files. Two files, both small.

**Files added**

| File | Purpose |
| --- | --- |
| `.gitignore` | Patterns git won't track. |
| `.gitattributes` | Force LF line endings (avoids CRLF noise on Windows clones). |

### 3a. `.gitignore`

```
# Build directories
build/
out/
out/coverage/*
cmake-build-*/

# User specific settings
CMakeUserPresets.json

# IDE files
.vs/
.idea/
.vscode/
!.vscode/settings.json
!.vscode/tasks.json
!.vscode/launch.json
!.vscode/extensions.json
*.bak
*.swp
*~
_ReSharper*
*.log

# OS Generated Files
.DS_Store
.AppleDouble
.LSOverride
._*
.Spotlight-V100
.Trashes
.Trash-*
$RECYCLE.BIN/
.TemporaryItems
ehthumbs.db
Thumbs.db
```

The `!.vscode/<X>.json` lines re-include specific VS Code files that *are*
useful to share (settings, debug configs, recommended extensions).

### 3b. `.gitattributes`

```
* text=auto eol=lf
*.{cmd,[cC][mM][dD]} text eol=crlf
*.{bat,[bB][aA][tT]} text eol=crlf
*.{vcxproj,vcxproj.filters} text eol=crlf
```

`* text=auto eol=lf` makes every text file land with LF in the repo —
even if a Windows contributor commits CRLF on their machine.

### 3c. `.editorconfig` — cross-editor whitespace baseline

`.gitattributes` fixes line endings *at commit time*. `.editorconfig`
fixes them (and indent style, charset, final-newline, …) *as you type* —
in every editor that supports it (VS Code, Vim, JetBrains, Sublime, …
most do, the rest via a small plugin).

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 2

[*.{c,cc,cpp,cxx,h,hh,hpp,hxx,ipp,inl}]
indent_size = 2
max_line_length = 120

[{CMakeLists.txt,*.cmake,*.cmake.in}]
indent_size = 2
max_line_length = 120

[*.py]
indent_size = 4
max_line_length = 88

[*.md]
trim_trailing_whitespace = false   # Markdown uses trailing spaces for hard breaks

[{Makefile,makefile,GNUmakefile,*.mk}]
indent_style = tab                  # Make literally requires tabs
```

Why have *both* `.editorconfig` and `.clang-format`?

- `.clang-format` is C/C++-only and runs on demand (an explicit format
  command, or CI). It controls deep style — brace placement, alignment,
  line wrap.
- `.editorconfig` is editor-agnostic and runs continuously. It controls
  basic whitespace + encoding for *every* file type — CMake, YAML,
  Markdown, JSON, shell, none of which clang-format touches.

Think of `.editorconfig` as the first line of defense and `.clang-format`
(plus `cmake-format`, `prettier`, …) as the deeper formatters layered on
top.

### Try it

```bash
git status     # build/ no longer shown as untracked
```

> **Next**: Reusable build configurations via CMakePresets.

---

## Step 4 — CMake presets

**Goal**: replace `cmake -B build -S . -DCMAKE_C_COMPILER=clang …` with
`cmake --preset clang-debug`.

**Files added**: `CMakePresets.json`.

```json
{
    "version": 3,
    "cmakeMinimumRequired": { "major": 3, "minor": 29, "patch": 0 },
    "configurePresets": [
        {
            "name": "conf-common",
            "description": "Settings shared by every preset (Linux/macOS only)",
            "hidden": true,
            "generator": "Ninja",
            "binaryDir": "${sourceDir}/out/build/${presetName}",
            "installDir": "${sourceDir}/out/install/${presetName}",
            "condition": {
                "type": "inList",
                "string": "${hostSystemName}",
                "list": ["Linux", "Darwin"]
            }
        },
        {
            "name": "gcc-debug",
            "displayName": "gcc Debug",
            "inherits": "conf-common",
            "cacheVariables": {
                "CMAKE_C_COMPILER": "gcc",
                "CMAKE_CXX_COMPILER": "g++",
                "CMAKE_BUILD_TYPE": "Debug"
            }
        },
        {
            "name": "gcc-release",
            "displayName": "gcc Release",
            "inherits": "conf-common",
            "cacheVariables": {
                "CMAKE_C_COMPILER": "gcc",
                "CMAKE_CXX_COMPILER": "g++",
                "CMAKE_BUILD_TYPE": "RelWithDebInfo"
            }
        },
        {
            "name": "clang-debug",
            "displayName": "clang Debug",
            "inherits": "conf-common",
            "cacheVariables": {
                "CMAKE_C_COMPILER": "clang",
                "CMAKE_CXX_COMPILER": "clang++",
                "CMAKE_BUILD_TYPE": "Debug"
            }
        },
        {
            "name": "clang-release",
            "displayName": "clang Release",
            "inherits": "conf-common",
            "cacheVariables": {
                "CMAKE_C_COMPILER": "clang",
                "CMAKE_CXX_COMPILER": "clang++",
                "CMAKE_BUILD_TYPE": "RelWithDebInfo"
            }
        }
    ],
    "testPresets": [
        {
            "name": "test-common",
            "hidden": true,
            "output": { "outputOnFailure": true },
            "execution": { "noTestsAction": "error", "stopOnFailure": true }
        },
        { "name": "test-gcc-debug",      "inherits": "test-common", "configurePreset": "gcc-debug" },
        { "name": "test-gcc-release",    "inherits": "test-common", "configurePreset": "gcc-release" },
        { "name": "test-clang-debug",    "inherits": "test-common", "configurePreset": "clang-debug" },
        { "name": "test-clang-release",  "inherits": "test-common", "configurePreset": "clang-release" }
    ]
}
```

**The `conf-common` preset** is hidden (not directly invokable). It just
bundles common settings — generator, build/install dirs, the
Linux/Darwin guard — so the four real presets just `inherit` from it.

### Try it

```bash
cmake --list-presets
# → gcc-debug, gcc-release, clang-debug, clang-release

cmake --preset clang-debug
# → configures into out/build/clang-debug/
cmake --build out/build/clang-debug
./out/build/clang-debug/src/app/app
```

> **Next**: Split logic out of `app` into a reusable library.

---

## Step 5 — A library and a public header

**Goal**: introduce a `sample_library` with a public header. Demonstrates
the canonical "library + public include directory + alias target" pattern.

**Files added**

| File | Purpose |
| --- | --- |
| `include/myproject/sample_library.hpp` | Public header — what library consumers `#include`. |
| `src/sample_library/sample_library.cpp` | Implementation. |
| `src/sample_library/CMakeLists.txt` | Builds the library + alias target. |

**Files updated**: `src/CMakeLists.txt`, `src/app/CMakeLists.txt`,
`src/app/main.cpp`.

### 5a. The public header — `include/myproject/sample_library.hpp`

```cpp
#pragma once

#include <myproject/sample_library_export.hpp>

[[nodiscard]] SAMPLE_LIBRARY_EXPORT int factorial(int) noexcept;

[[nodiscard]] constexpr int factorial_constexpr(int input) noexcept
{
  if (input == 0) { return 1; }
  return input * factorial_constexpr(input - 1);
}
```

The `include/<projectname>/header.hpp` directory layout is intentional —
when consumers add this project as a dependency, they include
`<myproject/sample_library.hpp>` and the namespacing avoids collisions
with other libraries' headers.

`<myproject/sample_library_export.hpp>` is generated by CMake (see 5c)
and provides `SAMPLE_LIBRARY_EXPORT` — a macro that expands to
`__attribute__((visibility("default")))` (or empty on static builds), so
exported symbols are explicit when the library is shared.

### 5b. The implementation — `src/sample_library/sample_library.cpp`

```cpp
#include <myproject/sample_library.hpp>

int factorial(int input) noexcept
{
  int result = 1;
  while (input > 0) {
    result *= input;
    --input;
  }
  return result;
}
```

### 5c. `src/sample_library/CMakeLists.txt`

```cmake
include(GenerateExportHeader)

add_library(sample_library sample_library.cpp)
add_library(${PROJECT_NAME}::sample_library ALIAS sample_library)

target_include_directories(sample_library PUBLIC
  $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
  $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include>)

target_compile_features(sample_library PUBLIC cxx_std_${CMAKE_CXX_STANDARD})

set_target_properties(sample_library PROPERTIES
  VERSION ${PROJECT_VERSION}
  CXX_VISIBILITY_PRESET hidden
  VISIBILITY_INLINES_HIDDEN YES)

generate_export_header(sample_library
  EXPORT_FILE_NAME ${PROJECT_BINARY_DIR}/include/${PROJECT_NAME}/sample_library_export.hpp)

if(NOT BUILD_SHARED_LIBS)
  target_compile_definitions(sample_library PUBLIC SAMPLE_LIBRARY_STATIC_DEFINE)
endif()
```

**Key bits:**

- `add_library(${PROJECT_NAME}::sample_library ALIAS sample_library)` —
  the canonical `<namespace>::<lib>` alias target that consumers link
  against. It's an alias, so it can't be linked by accident before the
  real target exists.
- `$<BUILD_INTERFACE:…>` — these include paths apply only when *building*
  the project. (Step 18 adds the `$<INSTALL_INTERFACE:…>` counterpart so
  installed consumers find headers in the right spot.)
- `generate_export_header` — writes
  `<build>/include/${PROJECT_NAME}/sample_library_export.hpp` containing
  the `SAMPLE_LIBRARY_EXPORT` macro.
- `CXX_VISIBILITY_PRESET hidden` + `VISIBILITY_INLINES_HIDDEN YES` —
  default to hiding all symbols; only `SAMPLE_LIBRARY_EXPORT`-tagged
  symbols are exported in shared builds.

### 5d. Update `src/CMakeLists.txt`

```cmake
add_subdirectory(sample_library)
add_subdirectory(app)
```

(Library before app, so the target exists when `app` tries to link it.)

### 5e. Update `src/app/CMakeLists.txt`

```cmake
add_executable(app main.cpp)
target_link_libraries(app PRIVATE ${PROJECT_NAME}::sample_library)
```

### 5f. Update `src/app/main.cpp`

```cpp
#include <myproject/sample_library.hpp>

#include <iostream>

int main()
{
    std::cout << "10! = " << factorial(10) << '\n';
    static_assert(factorial_constexpr(10) == 3628800, "constexpr factorial broken");
    return 0;
}
```

### Try it

```bash
cmake --preset clang-debug
cmake --build out/build/clang-debug
./out/build/clang-debug/src/app/app
# → 10! = 3628800
```

The `static_assert` runs at **compile time** — if `factorial_constexpr`
ever regressed, the build would fail before any test runs.

### Where you stand

```
.
├── .devcontainer/
├── .gitignore
├── .gitattributes
├── CMakeLists.txt
├── CMakePresets.json
├── include/myproject/sample_library.hpp
└── src/
    ├── CMakeLists.txt
    ├── app/
    │   ├── CMakeLists.txt
    │   └── main.cpp
    └── sample_library/
        ├── CMakeLists.txt
        └── sample_library.cpp
```

> **Next**: Get the project name & version from CMake into C++ at runtime.

---

## Step 6 — Configured files (build metadata in C++)

**Goal**: expose `myproject::cmake::project_name` and `project_version`
as `inline constexpr` symbols, populated by CMake at configure time.

**Files added**

| File | Purpose |
| --- | --- |
| `configured_files/CMakeLists.txt` | Calls `configure_file()` once. |
| `configured_files/config.hpp.in` | Template — `@VAR@` placeholders are filled by CMake. |

**Files updated**: top-level `CMakeLists.txt`, `src/app/CMakeLists.txt`,
`src/app/main.cpp`.

### 6a. `configured_files/config.hpp.in`

```cpp
#ifndef @PROJECT_NAME@_CONFIG_HPP
#define @PROJECT_NAME@_CONFIG_HPP

#include <string_view>

namespace @PROJECT_NAME@::cmake {
inline constexpr std::string_view project_name    = "@PROJECT_NAME@";
inline constexpr std::string_view project_version = "@PROJECT_VERSION@";
inline constexpr int project_version_major { @PROJECT_VERSION_MAJOR@ };
inline constexpr int project_version_minor { @PROJECT_VERSION_MINOR@ };
inline constexpr int project_version_patch { @PROJECT_VERSION_PATCH@ };
inline constexpr int project_version_tweak { @PROJECT_VERSION_TWEAK@ };
inline constexpr std::string_view git_sha = "@GIT_SHA@";
}// namespace @PROJECT_NAME@::cmake

#endif
```

`@…@` placeholders are replaced by `configure_file(... ESCAPE_QUOTES)` —
including the namespace name itself, which becomes whatever you set in
`project()`. Renaming the project propagates to the generated header
automatically.

### 6b. `configured_files/CMakeLists.txt`

```cmake
configure_file("config.hpp.in"
  "${CMAKE_BINARY_DIR}/configured_files/include/internal_use_only/config.hpp"
  ESCAPE_QUOTES)
```

The output path is **`internal_use_only/`**, not `${PROJECT_NAME}/`, so
it's clear this header is *not* part of the public API. Consumers of the
library shouldn't include it.

### 6c. Update top-level `CMakeLists.txt`

Add this line after `add_subdirectory(src)` (or before — order doesn't
matter for `configure_file`):

```cmake
add_subdirectory(configured_files)
```

You'll also need a `GIT_SHA` cache variable so `@GIT_SHA@` resolves:

```cmake
set(GIT_SHA "Unknown" CACHE STRING "SHA this build was generated from")
string(SUBSTRING "${GIT_SHA}" 0 8 GIT_SHORT_SHA)
```

CI sets `-DGIT_SHA=$github.sha` later (step 19); locally it stays "Unknown".

### 6d. Update `src/app/CMakeLists.txt`

Add the configured-files include path:

```cmake
target_include_directories(app PRIVATE
  "${CMAKE_BINARY_DIR}/configured_files/include")
```

### 6e. Update `src/app/main.cpp`

```cpp
#include <internal_use_only/config.hpp>
#include <myproject/sample_library.hpp>

#include <iostream>

int main()
{
    std::cout << myproject::cmake::project_name
              << " v" << myproject::cmake::project_version
              << " — 10! = " << factorial(10) << '\n';
    return 0;
}
```

### Try it

```bash
cmake --preset clang-debug
cmake --build out/build/clang-debug
./out/build/clang-debug/src/app/app
# → myproject v0.0.1 — 10! = 3628800
```

> **Next**: Add a real third-party dependency via CPM.

---

## Step 7 — Dependencies via CPM

**Goal**: fetch `fmt` (a fast string-formatting library) at configure
time, with no system installs and no submodules.

**What is CPM?** [CPM.cmake](https://github.com/cpm-cmake/CPM.cmake) is a
~1000-line CMake script that wraps `FetchContent` with caching and
version pinning. You write `cpmaddpackage(NAME … GITHUB_REPOSITORY …)`
and it downloads, builds, and exposes targets.

**Files added**

| File | Purpose |
| --- | --- |
| `cmake/CPM.cmake` | Vendor stub — at configure time, downloads the real CPM script (pinned by SHA-256). |
| `cmake/Dependencies.cmake` | One `setup_dependencies()` function with `cpmaddpackage` blocks. |

**Files updated**: top-level `CMakeLists.txt`, `src/app/CMakeLists.txt`,
`src/app/main.cpp`.

### 7a. `cmake/CPM.cmake`

```cmake
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Copyright (c) 2019-2026 Lars Melchior and contributors

set(CPM_DOWNLOAD_VERSION 0.42.1)
set(CPM_HASH_SUM "f3a6dcc6a04ce9e7f51a127307fa4f699fb2bade357a8eb4c5b45df76e1dc6a5")

if(CPM_SOURCE_CACHE)
  set(CPM_DOWNLOAD_LOCATION "${CPM_SOURCE_CACHE}/cpm/CPM_${CPM_DOWNLOAD_VERSION}.cmake")
elseif(DEFINED ENV{CPM_SOURCE_CACHE})
  set(CPM_DOWNLOAD_LOCATION "$ENV{CPM_SOURCE_CACHE}/cpm/CPM_${CPM_DOWNLOAD_VERSION}.cmake")
else()
  set(CPM_DOWNLOAD_LOCATION "${CMAKE_BINARY_DIR}/cmake/CPM_${CPM_DOWNLOAD_VERSION}.cmake")
endif()

get_filename_component(CPM_DOWNLOAD_LOCATION ${CPM_DOWNLOAD_LOCATION} ABSOLUTE)

file(DOWNLOAD
     https://github.com/cpm-cmake/CPM.cmake/releases/download/v${CPM_DOWNLOAD_VERSION}/CPM.cmake
     ${CPM_DOWNLOAD_LOCATION} EXPECTED_HASH SHA256=${CPM_HASH_SUM})

include(${CPM_DOWNLOAD_LOCATION})
```

This is **vendor code** — copied verbatim from upstream's "manual install"
snippet. `EXPECTED_HASH SHA256=…` makes the download supply-chain-safe:
if upstream replaces the file, the hash mismatch aborts the build.

### 7b. `cmake/Dependencies.cmake`

```cmake
include(cmake/CPM.cmake)

# A function (not a macro) — the new variable scope prevents CMAKE_CXX_FLAGS
# mutations from inside CPM/dependencies from leaking outward.
function(setup_dependencies)
  if(NOT TARGET fmtlib::fmtlib)
    cpmaddpackage(
      NAME fmt
      GITHUB_REPOSITORY "fmtlib/fmt"
      GIT_TAG "12.1.0"
      SYSTEM YES)
  endif()
endfunction()
```

**Key choices:**

- `if(NOT TARGET …)` guards each fetch — a parent project can supply its
  own version of `fmt` and we won't re-fetch.
- `SYSTEM YES` marks the headers as system headers, so warnings from
  inside fmt don't show up in *your* build output.

### 7c. Update top-level `CMakeLists.txt`

```cmake
include(cmake/Dependencies.cmake)
setup_dependencies()
```

### 7d. Update `src/app/CMakeLists.txt`

```cmake
target_link_libraries(app PRIVATE
  ${PROJECT_NAME}::sample_library
  fmt::fmt)
```

### 7e. Update `src/app/main.cpp` — use `fmt::print`

```cpp
#include <fmt/core.h>
#include <internal_use_only/config.hpp>
#include <myproject/sample_library.hpp>

int main()
{
    fmt::print("{} v{} — 10! = {}\n",
               myproject::cmake::project_name,
               myproject::cmake::project_version,
               factorial(10));
    return 0;
}
```

### Try it

```bash
rm -rf out/
cmake --preset clang-debug   # first run downloads fmt
cmake --build out/build/clang-debug
./out/build/clang-debug/src/app/app
# → myproject v0.0.1 — 10! = 3628800
```

The first configure spends a minute downloading fmt; subsequent ones use
the local cache.

### 7f. Make the dependency manager configurable (CPM / vcpkg / Conan)

CPM is great for getting started — clone the repo, run cmake, everything
else fetches itself. But for projects that ship into wider ecosystems,
two manifest-based managers are common:

- **vcpkg** (`vcpkg.json`) — Microsoft's manifest-mode manager.
- **Conan** (`conanfile.txt`) — package versioning + binary cache server.

The trick: every dependency is gated `if(NOT TARGET …)`. So if the
toolchain file from vcpkg or Conan has already populated the registry
(via `find_package`), the matching `cpmaddpackage()` block is skipped.

We expose this as a single cache string `DEPENDENCY_MANAGER`:

```cmake
# cmake/Dependencies.cmake (top of file)
set(DEPENDENCY_MANAGER "CPM" CACHE STRING
    "Where to fetch third-party libraries: CPM | VCPKG | CONAN")
set_property(CACHE DEPENDENCY_MANAGER PROPERTY STRINGS CPM VCPKG CONAN)

if(DEPENDENCY_MANAGER STREQUAL "CPM")
  include(cmake/CPM.cmake)
endif()
```

A small dispatcher avoids duplicating each block twice:

```cmake
function(_resolve_dependency)
  cmake_parse_arguments(PARSE_ARGV 0 _ARG "" "IF_NOT_TARGET" "CPM;FIND_PACKAGE")
  if(TARGET ${_ARG_IF_NOT_TARGET})
    return()
  endif()
  if(DEPENDENCY_MANAGER STREQUAL "CPM")
    cpmaddpackage(${_ARG_CPM})
  else()
    find_package(${_ARG_FIND_PACKAGE} REQUIRED)
  endif()
endfunction()

# Each dep is now a single declarative call, working under all three managers:
_resolve_dependency(
  IF_NOT_TARGET fmt::fmt
  CPM           NAME fmt GITHUB_REPOSITORY "fmtlib/fmt" GIT_TAG 12.1.0 SYSTEM YES
  FIND_PACKAGE  fmt CONFIG)
```

Add the manifest files at the repo root (used only when the matching
manager is selected):

```jsonc
// vcpkg.json
{
  "name": "myproject",
  "version-string": "0.0.2",
  "dependencies": ["fmt", "spdlog", "cli11"],
  "features": {
    "tests":      { "dependencies": ["gtest"] },
    "catch2":     { "dependencies": ["catch2"] },
    "benchmarks": { "dependencies": ["benchmark"] }
  }
}
```

```ini
# conanfile.txt
[requires]
fmt/11.0.2
spdlog/1.15.0
cli11/2.4.2
gtest/1.15.0

[generators]
CMakeDeps
CMakeToolchain

[layout]
cmake_layout
```

Switching managers is now just a configure-time flag:

```bash
# CPM (default)
cmake --preset clang-debug

# vcpkg
cmake --preset clang-debug \
    -DDEPENDENCY_MANAGER=VCPKG \
    --toolchain=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake

# Conan
conan install . --output-folder=build --build=missing
cmake --preset clang-debug \
    -DDEPENDENCY_MANAGER=CONAN \
    --toolchain=build/conan_toolchain.cmake
```

> **Next**: Compiler warnings — and the `options` / `warnings` interface
> library pattern that scopes them to *your* code only.

---

## Step 8 — Compiler warnings + the options/warnings pattern

**Goal**: turn on `-Wall -Wextra -Wshadow -Wpedantic …` and `-Werror`
**only on your own code**, not on dependencies.

**The pattern**: two `INTERFACE` libraries — `options` and `warnings` —
that hold compile/link flags. Real targets `target_link_libraries(... options
warnings)`, inheriting flags without you having to set them on each
target one by one. Crucially, the flags don't leak to fetched dependencies.

**Files added**

| File | Purpose |
| --- | --- |
| `cmake/CompilerWarnings.cmake` | The `set_project_warnings()` function. |
| `cmake/ProjectOptions.cmake` | Skeleton — declares `WARNINGS_AS_ERRORS` option, creates the `options`/`warnings` interface libraries, applies warnings. |

**Files updated**: top-level `CMakeLists.txt`, `src/app/CMakeLists.txt`,
`src/sample_library/CMakeLists.txt`.

### 8a. `cmake/CompilerWarnings.cmake`

```cmake
function(set_project_warnings project_name WARNINGS_AS_ERRORS
                              CLANG_WARNINGS GCC_WARNINGS CUDA_WARNINGS)
  if("${CLANG_WARNINGS}" STREQUAL "")
    set(CLANG_WARNINGS
        -Wall -Wextra -Wshadow -Wnon-virtual-dtor -Wold-style-cast
        -Wcast-align -Wunused -Woverloaded-virtual -Wpedantic
        -Wconversion -Wnull-dereference -Wdouble-promotion -Wformat=2
        -Wimplicit-fallthrough)
  endif()

  if("${GCC_WARNINGS}" STREQUAL "")
    set(GCC_WARNINGS ${CLANG_WARNINGS}
        -Wmisleading-indentation -Wduplicated-cond -Wduplicated-branches
        -Wlogical-op -Wuseless-cast -Wsuggest-override)
  endif()

  if(WARNINGS_AS_ERRORS)
    list(APPEND CLANG_WARNINGS -Werror)
    list(APPEND GCC_WARNINGS -Werror)
  endif()

  if(CMAKE_CXX_COMPILER_ID MATCHES ".*Clang")
    set(PROJECT_WARNINGS_CXX ${CLANG_WARNINGS})
  elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    set(PROJECT_WARNINGS_CXX ${GCC_WARNINGS})
  endif()

  target_compile_options(${project_name} INTERFACE
    $<$<COMPILE_LANGUAGE:CXX>:${PROJECT_WARNINGS_CXX}>
    $<$<COMPILE_LANGUAGE:C>:${PROJECT_WARNINGS_CXX}>)
endfunction()
```

### 8b. `cmake/ProjectOptions.cmake` (skeleton)

```cmake
include(cmake/Dependencies.cmake)

macro(setup_project)
  option(WARNINGS_AS_ERRORS "Treat warnings as errors" ${PROJECT_IS_TOP_LEVEL})

  setup_dependencies()

  add_library(warnings INTERFACE)
  add_library(options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  set_project_warnings(warnings ${WARNINGS_AS_ERRORS} "" "" "")
endmacro()
```

This will grow over the next several steps — sanitizers, hardening,
clang-tidy, etc. all hook into `setup_project()`.

### 8c. Update top-level `CMakeLists.txt`

Replace `include(cmake/Dependencies.cmake) + setup_dependencies()` with:

```cmake
include(cmake/ProjectOptions.cmake)
setup_project()

# Make options/warnings available as namespaced aliases.
add_library(${PROJECT_NAME}::options ALIAS options)
add_library(${PROJECT_NAME}::warnings ALIAS warnings)
target_compile_features(options INTERFACE cxx_std_${CMAKE_CXX_STANDARD})
```

### 8d. Update `src/app/CMakeLists.txt` and `src/sample_library/CMakeLists.txt`

Add `${PROJECT_NAME}::options` and `${PROJECT_NAME}::warnings` to each
target's link list:

```cmake
target_link_libraries(app PRIVATE
  ${PROJECT_NAME}::options
  ${PROJECT_NAME}::warnings
  ${PROJECT_NAME}::sample_library
  fmt::fmt)
```

### Try it

```bash
cmake --preset clang-debug
cmake --build out/build/clang-debug
```

If you introduce a deliberate warning into `main.cpp`:

```cpp
int unused_variable = 42;   // -Wunused, builds fine without -Werror
```

`cmake --build` will fail with `-Werror` on (top-level builds default ON).
Comment out `WARNINGS_AS_ERRORS` to confirm — the warning still shows but
the build succeeds.

> **Next**: Add ASan/UBSan defaults that catch memory and UB bugs at runtime.

---

## Step 9 — Sanitizers

**Goal**: ASan + UBSan on by default in top-level builds. Sanitizers are
runtime instrumentation that catch memory-safety / UB bugs as the program
executes — vastly better than crashing in production.

**Files added**: `cmake/Sanitizers.cmake`.

```cmake
function(enable_sanitizers project_name
                            ENABLE_SANITIZER_ADDRESS
                            ENABLE_SANITIZER_LEAK
                            ENABLE_SANITIZER_UNDEFINED_BEHAVIOR
                            ENABLE_SANITIZER_THREAD
                            ENABLE_SANITIZER_MEMORY)
  if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR CMAKE_CXX_COMPILER_ID MATCHES ".*Clang")
    set(SANITIZERS "")

    if(${ENABLE_SANITIZER_ADDRESS})
      list(APPEND SANITIZERS "address")
    endif()
    if(${ENABLE_SANITIZER_LEAK})
      if(APPLE)
        message(WARNING "Leak sanitizer not supported on Apple; ignoring.")
      else()
        list(APPEND SANITIZERS "leak")
      endif()
    endif()
    if(${ENABLE_SANITIZER_UNDEFINED_BEHAVIOR})
      list(APPEND SANITIZERS "undefined")
    endif()
    if(${ENABLE_SANITIZER_THREAD})
      if("address" IN_LIST SANITIZERS OR "leak" IN_LIST SANITIZERS)
        message(WARNING "TSan does not work with ASan/LSan enabled.")
      else()
        list(APPEND SANITIZERS "thread")
      endif()
    endif()
    if(${ENABLE_SANITIZER_MEMORY} AND CMAKE_CXX_COMPILER_ID MATCHES ".*Clang")
      list(APPEND SANITIZERS "memory")
    endif()
  endif()

  list(JOIN SANITIZERS "," LIST_OF_SANITIZERS)

  if(LIST_OF_SANITIZERS AND NOT "${LIST_OF_SANITIZERS}" STREQUAL "")
    target_compile_options(${project_name} INTERFACE -fsanitize=${LIST_OF_SANITIZERS})
    target_link_options(${project_name} INTERFACE -fsanitize=${LIST_OF_SANITIZERS})
  endif()
endfunction()
```

**TSan, LSan, and MSan are off** by default — they conflict with each
other (TSan vs ASan/LSan) and MSan needs an instrumented standard library.

### 9a. Update `cmake/ProjectOptions.cmake`

Add a sanitizer-support probe and the option declarations + call:

```cmake
include(CheckCXXSourceCompiles)

macro(supports_sanitizers)
  if(CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*")
    set(_t "int main() { return 0; }")
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${_t}" SUPPORTS_UBSAN)
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
    check_cxx_source_compiles("${_t}" SUPPORTS_ASAN)
  endif()
endmacro()

macro(setup_project)
  supports_sanitizers()

  option(WARNINGS_AS_ERRORS "Treat warnings as errors" ${PROJECT_IS_TOP_LEVEL})
  option(ENABLE_SANITIZER_ADDRESS  "ASan"  ${SUPPORTS_ASAN})
  option(ENABLE_SANITIZER_UNDEFINED "UBSan" ${SUPPORTS_UBSAN})
  option(ENABLE_SANITIZER_LEAK     "LSan"  OFF)
  option(ENABLE_SANITIZER_THREAD   "TSan"  OFF)
  option(ENABLE_SANITIZER_MEMORY   "MSan"  OFF)

  setup_dependencies()

  add_library(warnings INTERFACE)
  add_library(options INTERFACE)
  include(cmake/CompilerWarnings.cmake)
  set_project_warnings(warnings ${WARNINGS_AS_ERRORS} "" "" "")

  include(cmake/Sanitizers.cmake)
  enable_sanitizers(options
    ${ENABLE_SANITIZER_ADDRESS} ${ENABLE_SANITIZER_LEAK}
    ${ENABLE_SANITIZER_UNDEFINED} ${ENABLE_SANITIZER_THREAD}
    ${ENABLE_SANITIZER_MEMORY})
endmacro()
```

### Try it

Introduce UB:

```cpp
int main() {
    int* p = nullptr;
    return *p;   // UBSan should catch this
}
```

```bash
cmake --build out/build/clang-debug
./out/build/clang-debug/src/app/app
# → runtime error: load of misaligned address 0x000000000000 ...
#   SUMMARY: UndefinedBehaviorSanitizer: ...
```

> **Next**: Static analysis on every translation unit.

---

## Step 10 — Static analysis

**Goal**: every `.cpp` is checked by `clang-tidy` and `cppcheck` during
the build, not just in CI.

**Files added**

| File | Purpose |
| --- | --- |
| `.clang-tidy` | Which clang-tidy checks to run, and their options. |
| `.clangd` | clangd's own config (the editor LSP). |
| `cmake/StaticAnalyzers.cmake` | `enable_clang_tidy()` and `enable_cppcheck()` macros. |

### 10a. `.clang-tidy`

```yaml
---
Checks: "*,
        -abseil-*,-altera-*,-android-*,-fuchsia-*,
        -google-*,-llvm*,-zircon-*,
        -modernize-use-trailing-return-type,
        -readability-else-after-return,
        -readability-static-accessed-through-instance,
        -readability-avoid-const-params-in-decls,
        -cppcoreguidelines-non-private-member-variables-in-classes,
        -misc-non-private-member-variables-in-classes,
        -misc-no-recursion,
        -misc-use-anonymous-namespace,
        -misc-use-internal-linkage"
WarningsAsErrors: ''
HeaderFilterRegex: ''
FormatStyle:     none
CheckOptions:
  - key: readability-identifier-length.IgnoredVariableNames
    value: 'x|y|z'
  - key: readability-identifier-length.IgnoredParameterNames
    value: 'x|y|z'
```

`Checks: "*"` enables everything, then the `-X-*` lines turn off
opinionated check families (e.g., Google's specific style rules).

### 10b. `.clangd`

```yaml
CompileFlags:
  Add: ["-std=c++20", "-Wall", "-Wextra", "-Wpedantic"]
  Compiler: clang++

Diagnostics:
  ClangTidy:
    Add: [modernize-*, performance-*, bugprone-*,
          readability-identifier-naming, cppcoreguidelines-*]
    Remove:
      - modernize-use-trailing-return-type
      - cppcoreguidelines-avoid-magic-numbers
      - cppcoreguidelines-pro-bounds-pointer-arithmetic
  UnusedIncludes: Strict

InlayHints: { Enabled: true, ParameterNames: true, DeducedTypes: true }
Hover: { ShowAKA: true }
Index: { Background: Build }
```

This configures the **clangd LSP** — the in-editor experience. It's
separate from `.clang-tidy` because clangd applies a smaller, faster
subset of checks while you type.

### 10c. `cmake/StaticAnalyzers.cmake`

```cmake
macro(enable_cppcheck WARNINGS_AS_ERRORS CPPCHECK_OPTIONS)
  find_program(CPPCHECK cppcheck)
  if(CPPCHECK)
    if("${CPPCHECK_OPTIONS}" STREQUAL "")
      set(CMAKE_CXX_CPPCHECK ${CPPCHECK}
          --template=gcc
          --enable=style,performance,warning,portability
          --inline-suppr
          --suppress=cppcheckError --suppress=internalAstError
          --suppress=unmatchedSuppression --suppress=passedByValue
          --suppress=syntaxError --suppress=preprocessorErrorDirective
          --suppress=knownConditionTrueFalse
          --inconclusive
          --suppress=*:${CMAKE_CURRENT_BINARY_DIR}/_deps/*.h)
    else()
      set(CMAKE_CXX_CPPCHECK ${CPPCHECK} --template=gcc ${CPPCHECK_OPTIONS})
    endif()
    if(NOT "${CMAKE_CXX_STANDARD}" STREQUAL "")
      set(CMAKE_CXX_CPPCHECK ${CMAKE_CXX_CPPCHECK} --std=c++${CMAKE_CXX_STANDARD})
    endif()
    if(${WARNINGS_AS_ERRORS})
      list(APPEND CMAKE_CXX_CPPCHECK --error-exitcode=2)
    endif()
  endif()
endmacro()

macro(enable_clang_tidy target WARNINGS_AS_ERRORS)
  find_program(CLANGTIDY clang-tidy)
  if(CLANGTIDY)
    set(CLANG_TIDY_OPTIONS
        ${CLANGTIDY}
        -extra-arg=-Wno-unknown-warning-option
        -extra-arg=-Wno-ignored-optimization-argument
        -extra-arg=-Wno-unused-command-line-argument
        -p)
    if(NOT "${CMAKE_CXX_STANDARD}" STREQUAL "")
      list(APPEND CLANG_TIDY_OPTIONS -extra-arg=-std=c++${CMAKE_CXX_STANDARD})
    endif()
    if(${WARNINGS_AS_ERRORS})
      list(APPEND CLANG_TIDY_OPTIONS -warnings-as-errors=*)
    endif()
    set(CMAKE_CXX_CLANG_TIDY ${CLANG_TIDY_OPTIONS})
  endif()
endmacro()
```

### 10d. Update `cmake/ProjectOptions.cmake`

Add options and call:

```cmake
option(ENABLE_CLANG_TIDY "Enable clang-tidy" ${PROJECT_IS_TOP_LEVEL})
option(ENABLE_CPPCHECK   "Enable cppcheck"   ${PROJECT_IS_TOP_LEVEL})

# … later in setup_project, after creating options/warnings:
include(cmake/StaticAnalyzers.cmake)
if(ENABLE_CLANG_TIDY)
  enable_clang_tidy(options ${WARNINGS_AS_ERRORS})
endif()
if(ENABLE_CPPCHECK)
  enable_cppcheck(${WARNINGS_AS_ERRORS} "")
endif()
```

CMake's `CMAKE_CXX_CLANG_TIDY` / `CMAKE_CXX_CPPCHECK` variables make
both tools run alongside the compiler on every TU.

### Try it

```bash
cmake --preset clang-debug   # configure picks up .clang-tidy
cmake --build out/build/clang-debug 2>&1 | head -30
```

You'll see clang-tidy diagnostics interleaved with compiler output.

### 10e. Optional extras: cpplint, IWYU, scan-build, valgrind

Beyond clang-tidy and cppcheck, four more analyzers commonly show up in
mature C++ projects. Adding them is cheap because CMake supports a
matching `CMAKE_CXX_*` hook variable for most of them.

**cpplint** — Google's style linter. Off by default since Google style
differs from this template's `.clang-format`:

```cmake
macro(enable_cpplint WARNINGS_AS_ERRORS)
  find_program(CPPLINT cpplint)
  if(CPPLINT)
    set(CPPLINT_OPTIONS ${CPPLINT}
        --linelength=120
        --filter=-legal/copyright,-build/include_subdir,-whitespace/braces,-whitespace/indent)
    set(CMAKE_CXX_CPPLINT ${CPPLINT_OPTIONS})
  else()
    message(WARNING "cpplint requested but executable not found (pip install cpplint)")
  endif()
endmacro()
```

**include-what-you-use** — header hygiene. Reports each missing /
unused `#include`. Noisy on stdlib code so usually run on demand:

```cmake
macro(enable_iwyu)
  find_program(IWYU NAMES include-what-you-use iwyu)
  if(IWYU)
    set(CMAKE_CXX_INCLUDE_WHAT_YOU_USE
        ${IWYU} -Xiwyu --no_fwd_decls -std=c++${CMAKE_CXX_STANDARD})
  else()
    message(WARNING "include-what-you-use requested but executable not found")
  endif()
endmacro()
```

Wire both behind `option(ENABLE_CPPLINT …)` / `option(ENABLE_IWYU …)`
in `ProjectOptions.cmake` (defaults OFF), call in `setup_project()`:

```cmake
if(ENABLE_CPPLINT) enable_cpplint(${WARNINGS_AS_ERRORS}) endif()
if(ENABLE_IWYU)    enable_iwyu()                          endif()
```

**scan-build (Clang Static Analyzer)** — no CMake change required;
it's a wrapper script that intercepts the compile commands:

```bash
scan-build cmake -B build -S . -DENABLE_CLANG_TIDY=OFF
scan-build -o scan-results cmake --build build
scan-view scan-results/<timestamp>     # opens HTML report
```

The `-DENABLE_CLANG_TIDY=OFF` matters — combining the two analyzers
multiplies build time without much extra signal.

**Valgrind / memcheck** — runtime check for leaks and uninitialized
reads. CTest has a built-in driver. Add the options near the
`include(CTest)` call in your top-level `CMakeLists.txt`:

```cmake
set(MEMORYCHECK_COMMAND_OPTIONS
    "--leak-check=full --show-leak-kinds=all --error-exitcode=1")
include(CTest)
```

Then run:

```bash
cmake -B build -S . -DCMAKE_BUILD_TYPE=Debug \
    -DENABLE_SANITIZER_ADDRESS=OFF -DENABLE_SANITIZER_UNDEFINED=OFF
cmake --build build
ctest --test-dir build -T memcheck --output-on-failure
```

Sanitizers + Valgrind don't mix — pick one per build.

> **Next**: Compile- and link-time hardening flags.

---

## Step 11 — Hardening

**Goal**: opt into `_FORTIFY_SOURCE=3`, `_GLIBCXX_ASSERTIONS`,
`-fstack-protector-strong`, `-fcf-protection`,
`-fstack-clash-protection` — the modern Linux-style hardening defaults.

**Files added**: `cmake/Hardening.cmake`.

```cmake
include(CheckCXXCompilerFlag)

macro(enable_hardening target global ubsan_minimal_runtime)
  if(CMAKE_CXX_COMPILER_ID MATCHES ".*Clang|GNU")
    list(APPEND NEW_CXX_DEFINITIONS -D_GLIBCXX_ASSERTIONS)

    if(NOT CMAKE_BUILD_TYPE MATCHES "Debug")
      list(APPEND NEW_COMPILE_OPTIONS -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3)
    endif()

    check_cxx_compiler_flag(-fstack-protector-strong STACK_PROTECTOR)
    if(STACK_PROTECTOR)
      list(APPEND NEW_COMPILE_OPTIONS -fstack-protector-strong)
    endif()

    check_cxx_compiler_flag(-fcf-protection CF_PROTECTION)
    if(CF_PROTECTION)
      list(APPEND NEW_COMPILE_OPTIONS -fcf-protection)
    endif()

    check_cxx_compiler_flag(-fstack-clash-protection CLASH_PROTECTION)
    if(CLASH_PROTECTION)
      if(LINUX OR CMAKE_CXX_COMPILER_ID MATCHES "GNU")
        list(APPEND NEW_COMPILE_OPTIONS -fstack-clash-protection)
      endif()
    endif()
  endif()

  # If a *full* sanitizer isn't already active, layer on the UBSan
  # minimal-runtime so we still catch obvious UB.
  if(${ubsan_minimal_runtime})
    check_cxx_compiler_flag("-fsanitize=undefined -fno-sanitize-recover=undefined -fsanitize-minimal-runtime" MIN_RT)
    if(MIN_RT)
      list(APPEND NEW_COMPILE_OPTIONS -fsanitize=undefined -fsanitize-minimal-runtime)
      list(APPEND NEW_LINK_OPTIONS    -fsanitize=undefined -fsanitize-minimal-runtime)
      if(NOT ${global})
        list(APPEND NEW_COMPILE_OPTIONS -fno-sanitize-recover=undefined)
        list(APPEND NEW_LINK_OPTIONS    -fno-sanitize-recover=undefined)
      endif()
    endif()
  endif()

  if(${global})
    add_compile_options(${NEW_COMPILE_OPTIONS})
    add_compile_definitions(${NEW_CXX_DEFINITIONS})
    add_link_options(${NEW_LINK_OPTIONS})
  else()
    target_compile_options(${target} INTERFACE ${NEW_COMPILE_OPTIONS})
    target_link_options(${target} INTERFACE ${NEW_LINK_OPTIONS})
    target_compile_definitions(${target} INTERFACE ${NEW_CXX_DEFINITIONS})
  endif()
endmacro()
```

`global=ON` applies the flags via `add_compile_options` (everything,
including dependencies). `global=OFF` scopes to one target only.

### Update `cmake/ProjectOptions.cmake`

```cmake
option(ENABLE_HARDENING        "Enable hardening" ON)
cmake_dependent_option(
  ENABLE_GLOBAL_HARDENING "Push hardening to deps too" ON ENABLE_HARDENING OFF)

# In setup_project(), before setup_dependencies() so deps inherit:
if(ENABLE_HARDENING AND ENABLE_GLOBAL_HARDENING)
  include(cmake/Hardening.cmake)
  # … pick ENABLE_UBSAN_MINIMAL_RUNTIME based on whether a full sanitizer is on …
  enable_hardening(options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
endif()
```

### Try it

```bash
cmake --preset clang-release  # _FORTIFY_SOURCE=3 only kicks in non-Debug
cmake --build out/build/clang-release
```

Hardening is silent in normal operation — a stack overflow in production
gets caught and aborted instead of silently corrupting memory.

> **Next**: Linker selection, IPO/LTO, and ccache.

---

## Step 12 — Linker, IPO, ccache

**Goal**: faster builds (ccache), faster final binaries (IPO/LTO),
configurable linker (LLD/MOLD/…).

**Files added**

| File | Purpose |
| --- | --- |
| `cmake/Linker.cmake` | `configure_linker(target)` — sets `LINKER_TYPE` from `USER_LINKER_OPTION`. |
| `cmake/InterproceduralOptimization.cmake` | `enable_ipo()` — probes via `CheckIPOSupported`. |
| `cmake/Cache.cmake` | `enable_cache()` — wires ccache/sccache as `CMAKE_CXX_COMPILER_LAUNCHER`. |

### 12a. `cmake/Linker.cmake`

```cmake
macro(configure_linker project_name)
  set(USER_LINKER_OPTION "DEFAULT" CACHE STRING "Linker to be used")
  set(USER_LINKER_OPTION_VALUES "DEFAULT" "SYSTEM" "LLD" "GOLD" "BFD" "MOLD" "SOLD" "APPLE_CLASSIC")
  set_property(CACHE USER_LINKER_OPTION PROPERTY STRINGS ${USER_LINKER_OPTION_VALUES})
  set_target_properties(${project_name} PROPERTIES LINKER_TYPE "${USER_LINKER_OPTION}")
endmacro()
```

The `LINKER_TYPE` target property is a CMake 3.29+ feature.

### 12b. `cmake/InterproceduralOptimization.cmake`

```cmake
macro(enable_ipo)
  include(CheckIPOSupported)
  check_ipo_supported(RESULT result OUTPUT output)
  if(result)
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION ON)
  else()
    message(SEND_ERROR "IPO is not supported: ${output}")
  endif()
endmacro()
```

### 12c. `cmake/Cache.cmake`

```cmake
function(enable_cache)
  set(CACHE_OPTION "ccache" CACHE STRING "Compiler cache to be used")
  set(CACHE_OPTION_VALUES "ccache" "sccache")
  find_program(CACHE_BINARY NAMES ${CACHE_OPTION_VALUES})
  if(CACHE_BINARY)
    set(CMAKE_CXX_COMPILER_LAUNCHER ${CACHE_BINARY} CACHE FILEPATH "")
    set(CMAKE_C_COMPILER_LAUNCHER   ${CACHE_BINARY} CACHE FILEPATH "")
  endif()
endfunction()
```

### Update `cmake/ProjectOptions.cmake` — add three options + their hookups

```cmake
option(ENABLE_IPO   "Enable IPO/LTO"          ${PROJECT_IS_TOP_LEVEL})
option(ENABLE_CACHE "Enable ccache / sccache" ${PROJECT_IS_TOP_LEVEL})

# In setup_project(), after fetching deps:
if(ENABLE_IPO)
  include(cmake/InterproceduralOptimization.cmake)
  enable_ipo()
endif()
if(ENABLE_CACHE)
  include(cmake/Cache.cmake)
  enable_cache()
endif()

include(cmake/Linker.cmake)  # call configure_linker(target) from each target's CMakeLists
```

### Update each target's `CMakeLists.txt`

```cmake
configure_linker(app)
configure_linker(sample_library)
```

### Try it

```bash
cmake -B build -S . -DUSER_LINKER_OPTION=LLD
cmake --build build
# → linker: ld.lld
```

> **Next**: Real unit tests with Google Test.

---

## Step 13 — Testing with Google Test

**Goal**: a runtime-test executable + a compile-time-test executable
(static_assert), wired up to ctest for one-command running.

**Files added**

| File | Purpose |
| --- | --- |
| `test/CMakeLists.txt` | Builds the test executables and registers them with CTest. |
| `test/tests_gtest.cpp` | Runtime tests of `factorial(int)`. |
| `test/constexpr_tests_gtest.cpp` | Compile-time `static_assert` tests of `factorial_constexpr`. |

**Files updated**: top-level `CMakeLists.txt`, `cmake/Dependencies.cmake`,
`cmake/ProjectOptions.cmake`.

### 13a. `cmake/Dependencies.cmake` — fetch googletest

Add inside `setup_dependencies()`:

```cmake
if(ENABLE_GTEST AND NOT TARGET GTest::gtest_main)
  cpmaddpackage(
    NAME googletest
    GITHUB_REPOSITORY "google/googletest"
    GIT_TAG "v1.15.2"
    SYSTEM YES
    OPTIONS
      "INSTALL_GTEST OFF"
      "BUILD_GMOCK ON"     # ← step 14 will use this
      "gtest_force_shared_crt ON")
endif()
```

### 13b. `cmake/ProjectOptions.cmake` — add the option

```cmake
option(ENABLE_GTEST "Enable Google Test framework" ${PROJECT_IS_TOP_LEVEL})
```

### 13c. `test/tests_gtest.cpp`

```cpp
#include <gtest/gtest.h>

#include <myproject/sample_library.hpp>


TEST(Factorial, IsComputedAtRuntime)
{
  EXPECT_EQ(factorial(0), 1);
  EXPECT_EQ(factorial(1), 1);
  EXPECT_EQ(factorial(2), 2);
  EXPECT_EQ(factorial(3), 6);
  EXPECT_EQ(factorial(10), 3628800);
}
```

### 13d. `test/constexpr_tests_gtest.cpp`

```cpp
#include <gtest/gtest.h>

#include <myproject/sample_library.hpp>


TEST(Factorial, IsComputedAtCompileTime)
{
  static_assert(factorial_constexpr(0) == 1);
  static_assert(factorial_constexpr(10) == 3628800);
}
```

`static_assert` fires at compile time — if `factorial_constexpr` ever
regresses, the build fails before any test runs. The empty `TEST` body
is just a hook so gtest registers the test name with CTest.

### 13e. `test/CMakeLists.txt`

```cmake
function(_add_framework_test_executable name source)
  add_executable(${name} ${source})
  target_link_libraries(${name} PRIVATE
    ${PROJECT_NAME}::warnings
    ${PROJECT_NAME}::options
    ${PROJECT_NAME}::sample_library
    ${ARGN})
  configure_linker(${name})
endfunction()

if(ENABLE_GTEST)
  include(GoogleTest)
  _add_framework_test_executable(tests_gtest tests_gtest.cpp GTest::gtest_main)
  gtest_discover_tests(tests_gtest TEST_PREFIX "gtest.unittests." DISCOVERY_MODE PRE_TEST)

  _add_framework_test_executable(constexpr_tests_gtest constexpr_tests_gtest.cpp GTest::gtest_main)
  gtest_discover_tests(constexpr_tests_gtest TEST_PREFIX "gtest.constexpr." DISCOVERY_MODE PRE_TEST)
endif()
```

`DISCOVERY_MODE PRE_TEST` defers test enumeration to test time, instead
of running the binary at build time (avoids cross-compilation hangs).

### 13f. Update top-level `CMakeLists.txt`

```cmake
include(CTest)
if(BUILD_TESTING)
  add_subdirectory(test)
endif()
```

### Try it

```bash
cmake --preset clang-debug
cmake --build out/build/clang-debug
ctest --test-dir out/build/clang-debug --output-on-failure
# → 100% tests passed
```

> **Next**: Mocking interfaces with gmock.

---

## Step 14 — gmock for test doubles

**Goal**: write a mock implementation of an interface, set
`EXPECT_CALL` expectations, and let gmock verify how the function under
test interacts with the dependency.

gmock is shipped as part of the googletest fetch (we set
`BUILD_GMOCK ON` already in step 13). All you need is a new test target
linked against `GTest::gmock_main`.

**Files added**: `test/mock_test_gtest.cpp`.

```cpp
#include <gmock/gmock.h>
#include <gtest/gtest.h>

#include <string_view>


class MessageSink
{
public:
  virtual ~MessageSink() = default;
  virtual void write(std::string_view message) = 0;
  virtual int flush() = 0;
};


class MockMessageSink : public MessageSink
{
public:
  MOCK_METHOD(void, write, (std::string_view message), (override));
  MOCK_METHOD(int, flush, (), (override));
};


inline void greet(MessageSink &sink, std::string_view name)
{
  sink.write("Hello, ");
  sink.write(name);
  sink.flush();
}


using ::testing::_;
using ::testing::Eq;
using ::testing::InSequence;
using ::testing::Return;


TEST(GreetTest, WritesGreetingThenName)
{
  MockMessageSink sink;
  InSequence seq;
  EXPECT_CALL(sink, write(Eq("Hello, ")));
  EXPECT_CALL(sink, write(Eq("Alice")));
  EXPECT_CALL(sink, flush()).WillOnce(Return(0));

  greet(sink, "Alice");
}


TEST(GreetTest, FlushReturnIsObservable)
{
  MockMessageSink sink;
  EXPECT_CALL(sink, write(_)).Times(2);
  EXPECT_CALL(sink, flush()).WillOnce(Return(42));

  greet(sink, "Bob");
}
```

**Anatomy:**

- `MOCK_METHOD(void, write, (std::string_view), (override))` — gmock
  generates the implementation. The four args are: return type, method
  name, parameter list (parenthesized), method qualifiers.
- `EXPECT_CALL(mock, method(matcher))` — register an expectation.
  Matchers like `Eq("...")`, `_` (any), and `HasSubstr(...)` come from
  `<gmock/gmock-matchers.h>` (included via `<gmock/gmock.h>`).
- `WillOnce(Return(...))` — programs the mock's return value for that call.
- `InSequence` — expectations placed inside an `InSequence` scope must be
  matched in declaration order.
- gmock auto-verifies all `EXPECT_CALL`s at test teardown — no explicit
  verification call is needed.

### Update `test/CMakeLists.txt`

Append inside the `if(ENABLE_GTEST)` block:

```cmake
_add_framework_test_executable(mock_test_gtest mock_test_gtest.cpp GTest::gmock_main)
gtest_discover_tests(mock_test_gtest TEST_PREFIX "gtest.mock." DISCOVERY_MODE PRE_TEST)
```

`GTest::gmock_main` is the entry point that initialises both gtest *and*
gmock.

### Try it

```bash
cmake --build out/build/clang-debug
ctest --test-dir out/build/clang-debug -R 'gtest.mock' --output-on-failure
# → gtest.mock.GreetTest.WritesGreetingThenName     Passed
# → gtest.mock.GreetTest.FlushReturnIsObservable    Passed
```

> **Next**: optional Catch2 alongside gtest.

---

## Step 15 — Catch2 alongside (optional alternative)

**Goal**: support both gtest (default) and Catch2 (opt-in). Either can
build alongside the other under a separate option.

**Files added**: `test/tests_catch2.cpp`, `test/constexpr_tests_catch2.cpp`.

### 15a. `test/tests_catch2.cpp`

```cpp
#include <catch2/catch_test_macros.hpp>

#include <myproject/sample_library.hpp>


TEST_CASE("Factorials are computed", "[factorial]")
{
  REQUIRE(factorial(0) == 1);
  REQUIRE(factorial(10) == 3628800);
}
```

### 15b. `test/constexpr_tests_catch2.cpp`

```cpp
#include <catch2/catch_test_macros.hpp>

#include <myproject/sample_library.hpp>


TEST_CASE("Factorials at compile time", "[factorial]")
{
  STATIC_REQUIRE(factorial_constexpr(0) == 1);
  STATIC_REQUIRE(factorial_constexpr(10) == 3628800);
}
```

### Update `cmake/Dependencies.cmake`

```cmake
if(ENABLE_CATCH2 AND NOT TARGET Catch2::Catch2WithMain)
  cpmaddpackage(
    NAME Catch2
    VERSION 3.12.0
    GITHUB_REPOSITORY "catchorg/Catch2"
    SYSTEM YES)
endif()
```

### Update `cmake/ProjectOptions.cmake`

```cmake
option(ENABLE_CATCH2 "Enable Catch2 framework" OFF)
```

### Update `test/CMakeLists.txt`

```cmake
if(ENABLE_CATCH2)
  include(${Catch2_SOURCE_DIR}/extras/Catch.cmake)
  _add_framework_test_executable(tests_catch2 tests_catch2.cpp Catch2::Catch2WithMain)
  catch_discover_tests(tests_catch2 TEST_PREFIX "catch2.unittests.")
  _add_framework_test_executable(constexpr_tests_catch2 constexpr_tests_catch2.cpp Catch2::Catch2WithMain)
  catch_discover_tests(constexpr_tests_catch2 TEST_PREFIX "catch2.constexpr.")
endif()
```

### Try it

```bash
cmake -B out/build/both -S . -DENABLE_GTEST=ON -DENABLE_CATCH2=ON
cmake --build out/build/both
ctest --test-dir out/build/both
# → 5 gtest.* tests + 2 catch2.* tests
```

> **Next**: Fuzz testing with libFuzzer.

---

## Step 16 — Fuzz testing with libFuzzer

**Goal**: build a fuzz harness that runs random inputs against your code
to find crashes/UB. Auto-built only when libFuzzer + a sanitizer
(asan/tsan/ubsan) are both available.

**Files added**

| File | Purpose |
| --- | --- |
| `cmake/LibFuzzer.cmake` | Probe for `-fsanitize=fuzzer` support. |
| `fuzz_test/CMakeLists.txt` | Builds the `fuzz_tester` exe with libFuzzer flags. |
| `fuzz_test/fuzz_tester.cpp` | The harness — defines `LLVMFuzzerTestOneInput`. |

### 16a. `cmake/LibFuzzer.cmake`

```cmake
function(check_libfuzzer_support var_name)
  set(LibFuzzerTestSource "
    #include <cstdint>
    extern \"C\" int LLVMFuzzerTestOneInput(const std::uint8_t *data, std::size_t size) {
      return 0;
    }
  ")
  include(CheckCXXSourceCompiles)
  set(CMAKE_REQUIRED_FLAGS "-fsanitize=fuzzer")
  set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=fuzzer")
  check_cxx_source_compiles("${LibFuzzerTestSource}" ${var_name})
endfunction()
```

### 16b. `fuzz_test/fuzz_tester.cpp`

```cpp
#include <cstddef>
#include <cstdint>
#include <fmt/base.h>
#include <iterator>


[[nodiscard]] auto sum_values(const uint8_t *Data, size_t Size)
{
  constexpr auto scale = 1000;
  int value = 0;
  for (std::size_t offset = 0; offset < Size; ++offset) {
    value += static_cast<int>(*std::next(Data, static_cast<long>(offset))) * scale;
  }
  return value;
}


// cppcheck-suppress unusedFunction symbolName=LLVMFuzzerTestOneInput
extern "C" int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size)
{
  fmt::print("Value sum: {}, len{}\n", sum_values(Data, Size), Size);
  return 0;
}
```

The signed-integer multiplication will eventually overflow given enough
input bytes — UBSan reports it.

### 16c. `fuzz_test/CMakeLists.txt`

```cmake
add_executable(fuzz_tester fuzz_tester.cpp)
target_link_libraries(fuzz_tester PRIVATE
  ${PROJECT_NAME}::options
  ${PROJECT_NAME}::warnings
  fmt::fmt
  --coverage
  -fsanitize=fuzzer)
target_compile_options(fuzz_tester PRIVATE -fsanitize=fuzzer)

configure_linker(fuzz_tester)

set(FUZZ_RUNTIME 10 CACHE STRING "Seconds to run fuzz tests during ctest")
add_test(NAME fuzz_tester_run COMMAND fuzz_tester -max_total_time=${FUZZ_RUNTIME})
```

### Update `cmake/ProjectOptions.cmake`

```cmake
include(cmake/LibFuzzer.cmake)
check_libfuzzer_support(LIBFUZZER_SUPPORTED)
if(LIBFUZZER_SUPPORTED AND (ENABLE_SANITIZER_ADDRESS OR ENABLE_SANITIZER_THREAD OR ENABLE_SANITIZER_UNDEFINED))
  set(_default_fuzzer ON)
else()
  set(_default_fuzzer OFF)
endif()
option(BUILD_FUZZ_TESTS "Build the libFuzzer harness" ${_default_fuzzer})
```

### Update `src/sample_library/CMakeLists.txt`

So the library code is also fuzz-instrumented:

```cmake
if(BUILD_FUZZ_TESTS)
  target_link_libraries(sample_library PRIVATE -fsanitize=fuzzer-no-link)
  target_compile_options(sample_library PRIVATE -fsanitize=fuzzer-no-link)
endif()
```

### Update top-level `CMakeLists.txt`

```cmake
if(BUILD_FUZZ_TESTS)
  add_subdirectory(fuzz_test)
endif()
```

### Try it

```bash
cmake --build out/build/clang-debug
ctest --test-dir out/build/clang-debug -R 'fuzz' --output-on-failure
# Runs for 10 seconds (FUZZ_RUNTIME), reports UBSan if it finds overflow.
```

> **Next**: Coverage reporting.

---

## Step 17 — Coverage

**Goal**: instrument the build with `--coverage`, run the tests, and
generate HTML + Cobertura XML reports.

**Files added**

| File | Purpose |
| --- | --- |
| `gcovr.cfg` | gcovr config — what to filter, exclude, where to write reports. |
| `cmake/Coverage.cmake` | `enable_coverage(target)` — adds `--coverage -g`. |

### 17a. `gcovr.cfg`

```
root = .
search-path = out

filter = src/*
filter = include/*

exclude-directories = install
exclude-directories = out/*/*/_deps
exclude-directories = test
exclude-directories = fuzz_test

gcov-ignore-parse-errors = all
print-summary = yes

html-details = ./out/coverage/index.html

cobertura-pretty = yes
cobertura = out/cobertura.xml
```

### 17b. `cmake/Coverage.cmake`

```cmake
function(enable_coverage project_name)
  if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR CMAKE_CXX_COMPILER_ID MATCHES ".*Clang")
    target_compile_options(${project_name} INTERFACE --coverage -g)
    target_link_libraries(${project_name} INTERFACE --coverage)
  endif()
endfunction()
```

### Update `cmake/ProjectOptions.cmake`

```cmake
option(ENABLE_COVERAGE "Enable coverage reporting" OFF)

# In setup_project(), per-target section:
if(ENABLE_COVERAGE)
  include(cmake/Coverage.cmake)
  enable_coverage(options)
endif()
```

### Try it

```bash
cmake -B out/build/coverage -S . \
  -DENABLE_COVERAGE=ON -DCMAKE_BUILD_TYPE=Debug \
  -DENABLE_SANITIZER_ADDRESS=OFF -DENABLE_SANITIZER_UNDEFINED=OFF
cmake --build out/build/coverage
ctest --test-dir out/build/coverage
gcovr   # writes out/coverage/index.html + out/cobertura.xml
open out/coverage/index.html  # macOS; xdg-open on Linux
```

(Sanitizers off because gcov can't co-exist with ASan/UBSan in the
same build.)

> **Next**: Install rules and binary packaging.

---

## Step 18 — Packaging and install

**Goal**: `make install` copies your library + public headers + a
generated `myproject-config.cmake` into the install prefix, so consumers
can `find_package(myproject)`. `cpack` builds tarballs/zips.

**Files added**: `cmake/PackageProject.cmake` (vendor — implements
`package_project()`).

This file is from `lefticus/cppbestpractices` — ~180 lines that wrap
CMake's install/export machinery. Treat it as a black box: `cpack`
distribution tooling works the same regardless.

The full file is too long to inline; copy it from the upstream template
([here](https://github.com/cpp-best-practices/cmake_template/blob/main/cmake/PackageProject.cmake)).

### Update top-level `CMakeLists.txt`

```cmake
include(cmake/PackageProject.cmake)
package_project(
  TARGETS
  app
  options
  warnings)

# Embed compiler/version/SHA in package names for traceability.
set(CPACK_PACKAGE_FILE_NAME
    "${CMAKE_PROJECT_NAME}-${CMAKE_PROJECT_VERSION}-${GIT_SHORT_SHA}-${CMAKE_SYSTEM_NAME}-${CMAKE_BUILD_TYPE}-${CMAKE_CXX_COMPILER_ID}-${CMAKE_CXX_COMPILER_VERSION}")
include(CPack)
```

### Try it

```bash
cmake --build out/build/clang-release
cpack -C RelWithDebInfo --config out/build/clang-release/CPackConfig.cmake
# → produces e.g. myproject-0.0.1-Unknown-Linux-RelWithDebInfo-Clang-19.0.0.tar.gz
```

`cmake --install out/build/clang-release --prefix /tmp/install` copies
the install layout to `/tmp/install/`.

> **Next**: GitHub Actions CI to do all of this on every push/PR.

---

## Step 19 — GitHub Actions CI

**Goal**: every push and PR runs the full matrix (Ubuntu/macOS × gcc/clang
× Debug/Release) on GitHub-hosted runners, with coverage and CodeQL
security scanning.

**Files added**

| File | Purpose |
| --- | --- |
| `.github/workflows/ci.yml` | The build/test matrix. |
| `.github/workflows/codeql-analysis.yml` | GitHub CodeQL security scan. |
| `.github/workflows/clang-format-check.yml` | Fails PRs with unformatted C++. |
| `.github/dependabot.yml` | Weekly bumps of GitHub Actions versions. |
| `.github/constants.env` | One line: `PROJECT_NAME=myproject`. Sourced by `ci.yml`. |
| `.github/actions/setup_cache/action.yml` | Reusable composite action — caches `~/.ccache`. |

### 19a. `.github/constants.env`

```
PROJECT_NAME=myproject
```

### 19b. `.github/actions/setup_cache/action.yml`

```yaml
name: 'setup_cache'
description: 'sets up the shared cache'
inputs:
  compiler:               { required: true, type: string }
  build_type:             { required: true, type: string }
  generator:              { required: true, type: string }
  packaging_maintainer_mode: { required: true, type: string }

runs:
  using: "composite"
  steps:
    - name: Cache
      uses: actions/cache@v4
      with:
        path: ~/.ccache
        key: ${{ runner.os }}-${{ inputs.compiler }}-${{ inputs.build_type }}-${{ inputs.generator }}-${{ inputs.packaging_maintainer_mode }}-${{ hashFiles('**/CMakeLists.txt') }}
        restore-keys: |
          ${{ runner.os }}-${{ inputs.compiler }}-${{ inputs.build_type }}
```

### 19c. `.github/dependabot.yml`

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

### 19d. `.github/workflows/clang-format-check.yml`

```yaml
name: clang-format-check
on: [pull_request]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v6
    - uses: DoozyX/clang-format-lint-action@v0.20
      with:
        source: '.'
        exclude: './third_party ./external'
        extensions: 'h,cpp,hpp'
        clangFormatVersion: 19
        inplace: False   # check-only; PR fails if files would be reformatted
```

### 19e. `.github/workflows/codeql-analysis.yml`

The standard CodeQL setup-and-analyze pair, configured for C/C++.
Generated by GitHub's "Set up code scanning" UI; copy from the upstream
template if you'd rather not click through the wizard.

### 19f. `.github/workflows/ci.yml`

The big one — too long to fully inline. Skeleton:

```yaml
name: ci
on:
  pull_request:
  push: { branches: [main, develop], tags: } 
  release: { types: [published] }

env:
  CLANG_TIDY_VERSION: "19.1.1"
  VERBOSE: 1

jobs:
  Test:
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest]
        compiler: [llvm-19.1.1, gcc-14]
        generator: ["Ninja Multi-Config"]
        build_type: [Release, Debug]
        packaging_maintainer_mode: [ON, OFF]
        # ... coverage tool overrides via "include:" entries ...

    steps:
      - uses: actions/checkout@v6
      - uses: ./.github/actions/setup_cache
        with: { compiler: ${{ matrix.compiler }}, ... }
      - name: Setup Cpp
        uses: aminya/setup-cpp@v1
        with:
          compiler: ${{ matrix.compiler }}
          cmake: true
          ninja: true
          ccache: true
          clangtidy: ${{ env.CLANG_TIDY_VERSION }}
          cppcheck: true
          gcovr: true
      - name: Configure
        run: cmake -S . -B ./build -G "${{ matrix.generator }}" \
               -DCMAKE_BUILD_TYPE:STRING=${{ matrix.build_type }} \
               -DGIT_SHA:STRING=${{ github.sha }}
      - name: Build
        run: cmake --build ./build --config ${{ matrix.build_type }}
      - name: Test
        working-directory: ./build
        run: |
          ctest -C ${{ matrix.build_type }}
          gcovr --root ../ --print-summary --xml-pretty --xml coverage.xml .
      - name: CPack
        if: matrix.package_generator != ''
        run: cpack -C ${{ matrix.build_type }} -G ${{ matrix.package_generator }}
```

### Try it

```bash
git add .github/
git commit -m "Step 19: GitHub Actions CI"
git push
```

Open the **Actions** tab on GitHub — the workflows run automatically. A
green check on every preset means CI is healthy.

> **Next**: Make this a GitHub template + a one-shot rename script for
> non-template clones.

---

## Step 20 — Template janitor + the rename script

**Goal**: when someone clicks "Use this template" on GitHub, an
auto-rename workflow rewrites every `myproject` to their chosen name,
fills in their org/repo URLs, and removes upstream-specific files. For
local clones (no template flow), a `rename.sh` script does the same.

**Files added**

| File | Purpose |
| --- | --- |
| `.github/workflows/template-janitor.yml` | Auto-rename when this repo is forked-as-template. |
| `.github/template/template_name` | `cmake_template` — janitor compares against this to detect "still upstream, skip". |
| `.github/template/template_repository` | `cpp-best-practices/cmake_template` — same idea. |
| `.github/template/README.md` | Replacement README installed post-rename, with `%%myorg%%` / `%%myproject%%` placeholders. |
| `.github/template/removal-list` | Files janitor `rm`s on rename. |
| `rename.sh` | One-shot script for local clones. |

The janitor workflow is ~270 lines; copy from upstream
([here](https://github.com/cpp-best-practices/cmake_template/blob/main/.github/workflows/template-janitor.yml))
and read through the steps if you're curious. Key idea: it diffs
`.github/template/template_name` against the repo's actual name, and
only runs on a mismatch (i.e., a fresh fork).

### `rename.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <new-name>"; exit 1
fi
NEW_NAME="$1"

if ! [[ "$NEW_NAME" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]]; then
  echo "Error: '$NEW_NAME' must be a valid C++ identifier" >&2; exit 1
fi

cd "$(dirname "$0")"

if [[ ! -d include/myproject ]]; then
  echo "Error: include/myproject/ not found — already renamed?" >&2; exit 1
fi

# 1. project() declaration
sed -i.bak -E "s/^([[:space:]]*)myproject\$/\\1${NEW_NAME}/" CMakeLists.txt

# 2. public include directory
git mv include/myproject "include/${NEW_NAME}"

# 3. C++ #include paths and namespace usages
find . -type f \( -name '*.cpp' -o -name '*.hpp' -o -name '*.h' -o -name '*.in' \) \
  -not -path './.git/*' -not -path './build/*' -not -path './out/*' \
  -exec sed -i.bak \
    -e "s|<myproject/|<${NEW_NAME}/|g" \
    -e "s|myproject::|${NEW_NAME}::|g" \
    {} +

find . -type f -name '*.bak' -not -path './.git/*' -delete

echo "Renamed project to '${NEW_NAME}'."
echo "Verify: grep -rn myproject ."
echo "Then:   cmake -B build -S ."
```

`chmod +x rename.sh`.

### Try it

In a throwaway clone:

```bash
./rename.sh my_new_name
grep -rn myproject .   # should show only project(myproject) → wait, that's now my_new_name
cmake -B build -S .    # should configure cleanly
```

> **Next**: Editor configs, license, and project READMEs.

---

## Step 21 — Final polish

**Goal**: editor configs, license, project READMEs.

**Files added**

| File | Purpose |
| --- | --- |
| `.clang-format` | clang-format style. |
| `.cmake-format.yaml` | cmake-format style. |
| `LICENSE` | MIT (or whatever you choose). |
| `README.md` | The project landing page. |
| `cmake/README.md`, `.devcontainer/README.md`, `.github/README.md` | Folder-level documentation. |

### 21a. `.clang-format` and `.cmake-format.yaml`

Copy from the upstream template — they're long config files, not worth
inlining here. The choice of style isn't important; what matters is that
the team agrees on *one* style and CI enforces it (which `clang-format-check.yml`
does).

### 21b. `LICENSE`

```
MIT License

Copyright (c) 2026 your-name-here

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction ...
```

(The full MIT text — use `git clone https://github.com/cpp-best-practices/cmake_template`
for the verbatim version, or generate one via GitHub's "Add LICENSE"
button.)

### 21c. README files

Each folder gets a `README.md` so visitors browsing GitHub see context:

- `README.md` (root) — project description, getting started, design choices, links to other READMEs
- `.devcontainer/README.md` — what each devcontainer file does
- `.github/README.md` — workflows, dependabot, template-janitor explained
- `cmake/README.md` — call chain (`setup_project` → utility modules), per-module reference

### Try it (full repo verification)

```bash
cmake --preset clang-debug
cmake --build out/build/clang-debug
ctest --test-dir out/build/clang-debug --output-on-failure
# → All tests passed
```

### Where you stand

You now have a complete C++ project template:

```
.
├── .clang-format        ← formatting style
├── .clang-tidy
├── .clangd
├── .cmake-format.yaml
├── .devcontainer/       ← dev container (step 1)
├── .github/             ← CI, dependabot, template-janitor (steps 19-20)
├── .gitignore
├── .gitattributes
├── CMakeLists.txt       ← top-level wiring (steps 2, 5-12, 18)
├── CMakePresets.json    ← step 4
├── LICENSE              ← step 21
├── README.md            ← step 21
├── cmake/               ← build-system modules (steps 7-12, 16-18)
│   ├── Cache.cmake
│   ├── Coverage.cmake
│   ├── CompilerWarnings.cmake
│   ├── CPM.cmake
│   ├── Dependencies.cmake
│   ├── Hardening.cmake
│   ├── InterproceduralOptimization.cmake
│   ├── LibFuzzer.cmake
│   ├── Linker.cmake
│   ├── PackageProject.cmake
│   ├── PreventInSourceBuilds.cmake
│   ├── ProjectOptions.cmake
│   ├── Sanitizers.cmake
│   ├── StandardProjectSettings.cmake
│   └── StaticAnalyzers.cmake
├── configured_files/    ← step 6
├── fuzz_test/           ← step 16
├── gcovr.cfg            ← step 17
├── include/myproject/   ← step 5
├── rename.sh            ← step 20
├── src/                 ← step 2 + 5
│   ├── app/
│   └── sample_library/
└── test/                ← steps 13-15
```

### What you can do with it

| Task | Command |
| --- | --- |
| Fresh build | `cmake --preset clang-debug && cmake --build out/build/clang-debug` |
| Run tests | `ctest --test-dir out/build/clang-debug --output-on-failure` |
| Coverage report | `cmake -B build -S . -DENABLE_COVERAGE=ON && cmake --build build && ctest --test-dir build && gcovr` |
| Format check | `clang-format -i src/**/*.cpp include/**/*.hpp` |
| Use the template | Click "Use this template" on GitHub, or `./rename.sh my_new_name` |

---

## Step 22 — Pre-commit hooks

**Goal**: catch formatting + hygiene errors *before* a commit lands,
so CI is not the first place a contributor sees a failed format check.

**Files added**: `.pre-commit-config.yaml`.

[`pre-commit`](https://pre-commit.com) is a Python tool that wires a set
of hooks into `.git/hooks/pre-commit`. Each hook is a small repo of its
own (versioned by `rev:`), keeping setup reproducible across machines.

```yaml
# .pre-commit-config.yaml — minimal, mirrors the formatters CI runs
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
        exclude: \.md$
      - id: end-of-file-fixer
      - id: mixed-line-ending
        args: ["--fix=lf"]
      - id: check-yaml
      - id: check-merge-conflict
      - id: check-added-large-files
        args: ["--maxkb=512"]

  - repo: https://github.com/pre-commit/mirrors-clang-format
    rev: v19.1.7
    hooks:
      - id: clang-format
        types_or: [c++, c]

  - repo: https://github.com/cheshirekow/cmake-format-precommit
    rev: v0.6.13
    hooks:
      - id: cmake-format
      - id: cmake-lint
```

### Try it

```bash
pip install pre-commit          # or: brew install pre-commit
pre-commit install              # registers .git/hooks/pre-commit
pre-commit run --all-files      # one-time sweep across the repo
```

After this, `git commit` runs the hooks on staged files and refuses the
commit if anything fails.

> **Next**: enforce a commit message style.

---

## Step 23 — Commit message linting

**Goal**: enforce [Conventional Commits](https://www.conventionalcommits.org/)
on PR titles and on every commit pushed to a PR. Conventional Commits
(`feat: …`, `fix(scope): …`, `docs: …`, …) are machine-readable, so
release-note generators and changelog tools can use them directly.

**Files added**

| File | Purpose |
| --- | --- |
| `commitlint.config.js` | The rule set (extends `@commitlint/config-conventional`). |
| `.github/workflows/commitlint.yml` | CI workflow that runs `commitlint` on PR titles + commit ranges. |

```js
// commitlint.config.js
module.exports = {
  extends: ["@commitlint/config-conventional"],
  rules: {
    "type-enum": [2, "always", [
      "build", "chore", "ci", "docs", "feat", "fix", "perf",
      "refactor", "revert", "style", "test",
    ]],
    "header-max-length": [2, "always", 100],
  },
};
```

```yaml
# .github/workflows/commitlint.yml
name: Commitlint
on:
  pull_request: { types: [opened, edited, reopened, synchronize] }
  push:         { branches: [main] }
permissions: { contents: read, pull-requests: read }
jobs:
  commitlint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: actions/setup-node@v4
        with: { node-version: 22 }
      - run: npm install --no-save @commitlint/cli@19 @commitlint/config-conventional@19
      - if: github.event_name == 'pull_request'
        env: { PR_TITLE: "${{ github.event.pull_request.title }}" }
        run: echo "$PR_TITLE" | npx commitlint
```

Local enforcement is provided by the `conventional-pre-commit` hook in
`.pre-commit-config.yaml` (Step 22).

> **Next**: API docs with Doxygen.

---

## Step 24 — Doxygen / API docs

**Goal**: an HTML reference for your public headers, generated from
`///` and `/** ... */` comments. Useful as soon as your library has more
than a handful of types.

**Files added**: `cmake/Doxygen.cmake`.

```cmake
macro(enable_doxygen)
  find_package(Doxygen REQUIRED dot OPTIONAL_COMPONENTS mscgen dia)
  if(DOXYGEN_FOUND)
    set(DOXYGEN_PROJECT_NAME    ${PROJECT_NAME})
    set(DOXYGEN_PROJECT_NUMBER  ${PROJECT_VERSION})
    set(DOXYGEN_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/docs)
    set(DOXYGEN_GENERATE_HTML   YES)
    set(DOXYGEN_GENERATE_LATEX  NO)
    set(DOXYGEN_HAVE_DOT        YES)
    set(DOXYGEN_RECURSIVE       YES)
    set(DOXYGEN_EXTRACT_ALL     YES)
    set(DOXYGEN_USE_MDFILE_AS_MAINPAGE README.md)
    set(DOXYGEN_EXCLUDE_PATTERNS */build/* */out/* */test/* */bench/* */_deps/*)

    doxygen_add_docs(
      docs
      ${PROJECT_SOURCE_DIR}/include
      ${PROJECT_SOURCE_DIR}/src
      ${PROJECT_SOURCE_DIR}/README.md
      WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
      COMMENT "Generating API documentation with Doxygen")
  endif()
endmacro()
```

In `cmake/ProjectOptions.cmake` add `option(ENABLE_DOXYGEN ...)` (default
OFF) and call `enable_doxygen()` at the end of `setup_project()`.

### Try it

```bash
cmake -B build -S . -DENABLE_DOXYGEN=ON
cmake --build build --target docs
open build/docs/html/index.html      # macOS; xdg-open on Linux
```

> **Next**: microbenchmarks.

---

## Step 25 — Microbenchmarks (Google Benchmark)

**Goal**: a `bench/` directory holding [Google Benchmark](https://github.com/google/benchmark)
microbenchmarks. Off by default — they're timing-sensitive and shouldn't
share a CTest run with correctness tests.

**Files added**

| File | Purpose |
| --- | --- |
| `bench/CMakeLists.txt` | Wires benchmark executables to project options. |
| `bench/bench_factorial.cpp` | One example benchmark. |

In `cmake/Dependencies.cmake`, add a CPM block gated on the option:

```cmake
if(ENABLE_BENCHMARKS AND NOT TARGET benchmark::benchmark)
  cpmaddpackage(NAME benchmark VERSION 1.9.0
                GITHUB_REPOSITORY "google/benchmark" SYSTEM YES
                OPTIONS "BENCHMARK_ENABLE_TESTING OFF" "BENCHMARK_ENABLE_INSTALL OFF")
endif()
```

In top-level `CMakeLists.txt`, after the `BUILD_FUZZ_TESTS` block:

```cmake
if(ENABLE_BENCHMARKS)
  add_subdirectory(bench)
endif()
```

A minimal benchmark:

```cpp
// bench/bench_factorial.cpp
#include <benchmark/benchmark.h>
#include <myproject/sample_library.hpp>

static void BM_Factorial(benchmark::State& state) {
  const auto n = static_cast<int>(state.range(0));
  for (auto _ : state) {
    benchmark::DoNotOptimize(factorial(n));
  }
}
BENCHMARK(BM_Factorial)->Arg(5)->Arg(10)->Arg(15);
```

### Try it

```bash
cmake -B build -S . -DENABLE_BENCHMARKS=ON
cmake --build build --target bench_factorial
./build/bench/bench_factorial
# → BM_Factorial/5    5.77 ns ...
```

> **Next**: community files — the last layer for a public-facing repo.

---

## Step 26 — Community files

**Goal**: the GitHub-standard files that signal "this project welcomes
contributions and handles security responsibly".

**Files added**

| File | Purpose |
| --- | --- |
| `CONTRIBUTING.md` | How to build, test, format, submit a PR. |
| `CODE_OF_CONDUCT.md` | A short stub pointing to the Contributor Covenant 2.1. |
| `SECURITY.md` | How to report vulnerabilities (private GitHub advisory). |
| `.github/ISSUE_TEMPLATE/bug_report.yml` | Structured bug-report form. |
| `.github/ISSUE_TEMPLATE/feature_request.yml` | Structured feature-request form. |
| `.github/ISSUE_TEMPLATE/config.yml` | Disables blank issues; routes Discussions/security separately. |
| `.github/PULL_REQUEST_TEMPLATE.md` | PR description scaffold + checklist. |
| `CHANGELOG.md` | Keep-a-Changelog format with an `Unreleased` section. |

GitHub picks these up automatically — no workflow wiring needed:

- `CONTRIBUTING.md` is linked from the **New issue** / **New PR** screens.
- Issue templates appear when a user clicks **New issue**.
- `SECURITY.md` adds a **Security** tab CTA.
- `CODE_OF_CONDUCT.md` is shown on the community-standards page.

For `CHANGELOG.md`, the [Keep a Changelog](https://keepachangelog.com/)
format is the de-facto standard:

```markdown
# Changelog

## [Unreleased]

### Added
- Initial release of the cmake_template project.

[Unreleased]: https://github.com/<org>/<repo>/compare/HEAD
```

When you cut a release, rename `Unreleased` to the new version + date and
start a fresh `Unreleased` section above it.

### Try it

```bash
gh repo view --web        # check the repo's "Community standards" tab
```

You should see green check-marks for Description, README, Code of Conduct,
Contributing, License, Security policy, Issue templates, Pull request
template.

---

## Where you stand (with all extras)

You now have not just a working build but the surrounding
**software-engineering practices** layer that mature C++ projects ship
with:

| Layer | What it gives you |
| --- | --- |
| Build / test (Steps 1–18) | Reproducible build, sanitizers, fuzzing, coverage, install. |
| CI (Step 19) | Cross-compiler matrix, codecov, codeql. |
| Distribution (Step 20) | Template janitor for "Use this template", `rename.sh` for clones. |
| Polish (Step 21) | License, formatters, READMEs. |
| Local hygiene (Step 22) | pre-commit catches format/whitespace issues before push. |
| Commit conventions (Step 23) | commitlint enforces Conventional Commits. |
| Docs (Step 24) | Doxygen `docs` target. |
| Performance (Step 25) | Google Benchmark `bench/` directory. |
| Community (Step 26) | Contributing/SecPolicy/CoC/issue+PR templates/Changelog. |

The build core (Steps 1–21) is "what compiles your code". Steps 22–26
are "what makes the project good to live with" — the difference between
a one-developer scratchpad and a public-facing OSS project.
