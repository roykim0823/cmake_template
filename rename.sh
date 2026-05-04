#!/usr/bin/env bash
#
# Rename this template project from "myproject" to a name of your choice.
# Run once after cloning the template. Idempotent: aborts if the rename has
# already happened.
#
# Usage:
#   ./rename.sh <new-name>
#   ./rename.sh my_cool_project

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <new-name>"
  echo "Example: $0 my_cool_project"
  exit 1
fi

NEW_NAME="$1"

# Must be a valid C++ identifier (also a valid CMake project name).
if ! [[ "$NEW_NAME" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]]; then
  echo "Error: '$NEW_NAME' must be a valid C++ identifier" >&2
  echo "       (letters/digits/underscores; starts with a letter)." >&2
  exit 1
fi

# Move to the repo root (the directory containing this script).
cd "$(dirname "$0")"

# Idempotency guard.
if [[ ! -d include/myproject ]]; then
  echo "Error: include/myproject/ not found — already renamed?" >&2
  exit 1
fi

# 1. The bare 'myproject' on its own line in CMakeLists.txt is the project() name.
sed -i.bak -E "s/^([[:space:]]*)myproject\$/\\1${NEW_NAME}/" CMakeLists.txt

# 2. The public include directory.
git mv include/myproject "include/${NEW_NAME}"

# 3. C++ #include <myproject/...> paths and namespace usages (myproject::cmake)
#    across all source / header / configured-file templates.
find . -type f \
  \( -name '*.cpp' -o -name '*.hpp' -o -name '*.h' -o -name '*.in' \) \
  -not -path './.git/*' \
  -not -path './build/*' \
  -not -path './out/*' \
  -exec sed -i.bak \
    -e "s|<myproject/|<${NEW_NAME}/|g" \
    -e "s|myproject::|${NEW_NAME}::|g" \
    {} +

# Clean up sed backup files.
find . -type f -name '*.bak' -not -path './.git/*' -delete

cat <<EOF

Renamed project to '${NEW_NAME}'.

Verify there are no leftovers:
  grep -rn myproject \\
    --include='*.cmake' --include='CMakeLists.txt' \\
    --include='*.cpp' --include='*.hpp' --include='*.h' --include='*.in' .

Then reconfigure:
  cmake -B build -S .

This script is a one-shot. Feel free to delete it now:
  rm rename.sh
EOF
