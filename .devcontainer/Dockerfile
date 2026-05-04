FROM mcr.microsoft.com/devcontainers/cpp:2-ubuntu24.04

ARG LLVM_VERSION=19
ARG NODE_VERSION=22
ARG USERNAME=vscode

# Use bash with pipefail for all RUN commands
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ── LLVM / Clang ─────────────────────────────────────────────────────────────
# clang-19 and friends ship in Ubuntu 24.04's universe repo, so no third-party
# apt source is needed. update-alternatives wires the unversioned tool names
# (clang, clang++, clangd, ...) to the versioned binaries.
RUN apt-get update && apt-get install -y --no-install-recommends \
        clang-${LLVM_VERSION} \
        clang-format-${LLVM_VERSION} \
        clang-tidy-${LLVM_VERSION} \
        clangd-${LLVM_VERSION} \
        lld-${LLVM_VERSION} \
        lldb-${LLVM_VERSION} \
        llvm-${LLVM_VERSION} \
        libc++-${LLVM_VERSION}-dev \
        libc++abi-${LLVM_VERSION}-dev \
    && for tool in clang clang++ clangd clang-format clang-tidy \
                   lldb lld ld.lld \
                   llvm-ar llvm-as llvm-cov llvm-dis llvm-dwarfdump \
                   llvm-link llvm-nm llvm-objcopy llvm-objdump \
                   llvm-profdata llvm-ranlib llvm-readelf llvm-size \
                   llvm-strings llvm-strip llvm-symbolizer; do \
         bin="/usr/bin/${tool}-${LLVM_VERSION}"; \
         [ -f "$bin" ] && update-alternatives --install "/usr/bin/${tool}" "${tool}" "${bin}" 100 || true; \
       done \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── ccache ───────────────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        ccache \
    && rm -rf /var/lib/apt/lists/* \
    && echo "max_size = 0" > /etc/ccache.conf \
    && ln -sf /usr/bin/ccache /usr/local/bin/clang \
    && ln -sf /usr/bin/ccache /usr/local/bin/clang++ \
    && ln -sf /usr/bin/ccache /usr/local/bin/cc \
    && ln -sf /usr/bin/ccache /usr/local/bin/c++

# ── Node.js ───────────────────────────────────────────────────────────────────
RUN curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# ── LSP servers (TypeScript / JavaScript / Python) ───────────────────────────
# Major versions are pinned to keep image rebuilds reproducible while still
# picking up patch/minor fixes. Bump the majors deliberately when needed.
RUN npm install -g \
    typescript@^5 \
    typescript-language-server@^4 \
    pyright@^1 \
    vscode-langservers-extracted@^4 \
    @typescript-eslint/parser@^8 \
    @typescript-eslint/eslint-plugin@^8 \
    eslint@^9

# ── User-level setup ──────────────────────────────────────────────────────────
USER ${USERNAME}
WORKDIR /home/${USERNAME}

# uv — single quotes intentional: $HOME must expand at shell runtime, not build time
# hadolint ignore=SC2016
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${HOME}/.bashrc" \
    && "${HOME}/.local/bin/uv" python install 3.13

# Rust via rustup — single quotes intentional: expands at shell runtime
# hadolint ignore=SC2016
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && echo 'source "$HOME/.cargo/env"' >> "${HOME}/.bashrc"

# ccache / compiler env
RUN echo 'export CCACHE_CONFIGPATH=/etc/ccache.conf' >> "${HOME}/.bashrc" \
    && echo 'export CC="clang"' >> "${HOME}/.bashrc" \
    && echo 'export CXX="clang++"' >> "${HOME}/.bashrc"

# devcontainer runtime expects root as the final USER; remoteUser in
# devcontainer.json controls the actual connected user (vscode).
# hadolint ignore=DL3002
USER root
