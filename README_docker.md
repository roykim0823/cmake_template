## Docker Instructions

The `.devcontainer/` directory provides a Dev Container based on
`mcr.microsoft.com/devcontainers/cpp:2-ubuntu24.04`, preloaded with the LLVM 19
toolchain (clang, clang++, clangd, clang-tidy, lld, lldb) installed from
Ubuntu's universe repo, ccache, CMake, and Node.js for editor language servers.

### Using with VS Code (recommended)

Open the repository in VS Code with the **Dev Containers** extension installed,
then run `Dev Containers: Reopen in Container`. VS Code builds the image,
mounts the workspace, and connects as the `vscode` user.

The container is configured with `--cap-add=SYS_PTRACE` and
`seccomp=unconfined`, so `lldb`/`gdb` can attach to processes for debugging.

### Using with plain Docker

If you prefer to build and run the container directly:

```bash
docker build -f ./.devcontainer/Dockerfile --tag=cmake_template:latest .
docker run -it --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
    -v "$(pwd)":/workspaces/cmake_template \
    -w /workspaces/cmake_template \
    cmake_template:latest bash
```

### Build args

The Dockerfile exposes two build args:

| Arg | Default | Purpose |
|---|---|---|
| `LLVM_VERSION` | `19` | LLVM/Clang toolchain major version (must match a `clang-N` package available in Ubuntu 24.04's universe repo) |
| `NODE_VERSION` | `22` | Node.js major version (used for LSP servers) |

Override them with `--build-arg`, e.g.:

```bash
docker build -f ./.devcontainer/Dockerfile \
    --build-arg LLVM_VERSION=18 \
    --tag=cmake_template:latest .
```

### Building the project inside the container

`clang` is the default `CC`/`CXX` (set via `remoteEnv`), and ccache is wired in
through `/usr/local/bin` shims, so:

```bash
cmake -S . -B ./build -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build ./build
```

To build with GCC instead, install it inside the container or override
explicitly:

```bash
CC=gcc CXX=g++ cmake -S . -B ./build
```
