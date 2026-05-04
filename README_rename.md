# Renaming the project

The CMake side uses `${PROJECT_NAME}` everywhere it can, so most renaming
follows automatically from one change. A handful of sites cannot (they are
coupled to filesystem paths or C++ identifiers) and must be edited by hand.

Throughout this guide, replace `mynewname` with the name you actually want.

## 1. Change the project name (CMake — automatic propagation)

Edit `CMakeLists.txt:22`:

```cmake
project(
  mynewname            # was: myproject
  VERSION 0.0.2
  DESCRIPTION ""
  LANGUAGES CXX C)
```

That single change updates every `${PROJECT_NAME}::options` /
`${PROJECT_NAME}::warnings` / `${PROJECT_NAME}::sample_library` alias used in
the top-level CMakeLists.txt, `src/`, and `fuzz_test/`. They all read
`${PROJECT_NAME}` and resolve correctly.

**Exception:** `test/CMakeLists.txt` declares its *own* `project(...)` call
(so that the test directory can be built standalone against an installed
package), which redefines `${PROJECT_NAME}` for that scope. The references
inside that file are therefore hardcoded to `myproject` and must be updated
manually:

- `find_package(myproject CONFIG REQUIRED)` (line ~12)
- `myproject::warnings`, `myproject::options`, `myproject::sample_library`
  in the `_add_framework_test_executable` helper (lines ~52-54)

## 2. Rename the public include directory

The `include/<project>/header.hpp` layout is intentional — it scopes your
headers and prevents collisions when others depend on this library. Keep the
layout, just rename the directory:

```bash
git mv include/myproject include/mynewname
```

## 3. Update the export-header path in CMake

`src/sample_library/CMakeLists.txt:30` hardcodes the include path because
`generate_export_header` writes a real file:

```cmake
# was:
generate_export_header(sample_library
  EXPORT_FILE_NAME ${PROJECT_BINARY_DIR}/include/myproject/sample_library_export.hpp)

# becomes:
generate_export_header(sample_library
  EXPORT_FILE_NAME ${PROJECT_BINARY_DIR}/include/mynewname/sample_library_export.hpp)
```

## 4. Update C++ `#include` statements

Five `#include` lines reference the old directory name:

| File | Line |
| --- | --- |
| `include/myproject/sample_library.hpp` (now `include/mynewname/...`) | `#include <myproject/sample_library_export.hpp>` |
| `src/sample_library/sample_library.cpp` | `#include <myproject/sample_library.hpp>` |
| `test/tests.cpp` | `#include <myproject/sample_library.hpp>` |
| `test/constexpr_tests.cpp` | `#include <myproject/sample_library.hpp>` |

Replace `<myproject/...>` with `<mynewname/...>` in each.

## 5. Update the C++ namespace and header guard

`configured_files/config.hpp.in` declares a namespace whose name must match
the project (`src/ftxui_sample/main.cpp` uses it as `myproject::cmake::...`):

```cpp
// configured_files/config.hpp.in
#ifndef mynewname_CONFIG_HPP        // was: myproject_CONFIG_HPP
#define mynewname_CONFIG_HPP

namespace mynewname::cmake { ... }  // was: namespace myproject::cmake
```

Then update the two call sites in `src/ftxui_sample/main.cpp`:

- Line 333: `myproject::cmake::project_name`, `myproject::cmake::project_version`
- Line 353: `myproject::cmake::project_version`

(There is also a stale comment at `main.cpp:26` mentioning the namespace name —
update it for clarity.)

## 6. Verify

Run a recursive search for the old name. Anything left over is a missed spot:

```bash
grep -rn 'myproject' \
  --include='*.cmake' --include='CMakeLists.txt' \
  --include='*.cpp' --include='*.hpp' --include='*.h' --include='*.in' \
  .
```

The only acceptable hit is the `project(...)` line you edited in step 1, which
*is* the new name.

Then reconfigure to confirm the build still wires up:

```bash
cmake -S . -B build
```
