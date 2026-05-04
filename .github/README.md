# `.github/` — GitHub Configuration

This folder is special: GitHub itself reads everything inside it when you push
to `github.com`. It holds CI workflows, security scans, dependency-update
rules, and the auto-rename machinery used when this repo is forked as a
GitHub template.

## Quick map

| Path | What it is |
| --- | --- |
| `workflows/ci.yml` | Main build/test matrix (Linux + macOS × gcc + clang × Debug + Release). |
| `workflows/codeql-analysis.yml` | GitHub CodeQL — static security scan for C++. |
| `workflows/clang-format-check.yml` | Fails a PR if any C++ file isn't clang-formatted. |
| `workflows/template-janitor.yml` | One-shot auto-rename when you use this repo as a GitHub template. |
| `actions/setup_cache/` | Reusable composite action — caches `~/.ccache` between CI runs. |
| `template/` | Inputs used only by the janitor workflow (placeholders, removal list, identity). |
| `constants.env` | One-line file: `PROJECT_NAME=myproject`. Sourced by workflows. |
| `dependabot.yml` | Tells Dependabot to weekly-bump action versions. |

## Workflows — what runs and when

### `ci.yml` — the main CI

**Runs on:** every pull request, every push to `main` / `develop` / tags,
every published release.

**Matrix:** ubuntu-latest × macos-latest × gcc-14 + llvm-19.1.1 × Debug +
Release × packaging-maintainer-mode ON + OFF.

**What each job does:** installs the toolchain via
[aminya/setup-cpp](https://github.com/aminya/setup-cpp), restores `~/.ccache`
from cache (see `actions/setup_cache`), configures with CMake, builds, runs
`ctest`, computes coverage with `gcovr`, then `cpack` on tagged releases.

**To add a build step**: edit the `Test.steps:` list — each step runs
sequentially in the runner shell.

**To skip a matrix combination**: add it to `strategy.matrix.exclude:`.

### `codeql-analysis.yml` — security scan

**Runs on:** PRs against `main`/`develop`, pushes to `main`, plus a weekly
schedule.

**What it does:** GitHub's [CodeQL](https://codeql.github.com/) statically
analyzes your C++ for known vulnerability patterns. Findings show up under
the repo's **Security** tab.

**Setup:** none — works out of the box for public repos.

### `clang-format-check.yml` — formatting gate

**Runs on:** every pull request.

**What it does:** invokes `clang-format-19` with your `.clang-format` config.
If any file would be modified by clang-format, the workflow fails the PR
check. **It does not auto-fix.**

**To clear a failure:** locally run `clang-format -i <files>` (or use
format-on-save in your editor) and push the formatted version.

### `template-janitor.yml` — template auto-rename

**Runs on:** every PR / push / release — but it skips itself when the repo's
identity still matches the upstream (i.e., you haven't actually used this as
a template yet).

**What it does** the *first* time you push from a fresh clone-from-template:

1. Replaces every `myproject` occurrence across `src/`, `include/`, `test/`,
   `fuzz_test/`, `cmake/` (which now also contains `ProjectOptions.cmake`
   and `Dependencies.cmake`), `CMakeLists.txt`,
   `configured_files/config.hpp.in`, `.github/constants.env`,
   `.github/workflows/ci.yml`, `.github/workflows/codeql-analysis.yml`.
2. Renames `include/myproject/` → `include/<your-project>/`.
3. Fills `%%myorg%%` / `%%myproject%%` placeholders in
   `.github/template/README.md`, then promotes that file to the repo root
   `README.md`.
4. Deletes files listed in `.github/template/removal-list` (currently just
   the upstream `LICENSE`).
5. Commits the changes back to your branch.

**To use:** click **Use this template** on the GitHub UI of this repo, name
your new repo, and push something. The next CI run does the rename.

**Caveats:** janitor handles the bulk of the rename, but a few sites still
handle the rename. Or run `./rename.sh <new-name>` locally to do it
yourself.

## Other config

### `actions/setup_cache/`

A reusable composite action — like a snippet other workflows can import.
Caches `~/.ccache` between CI runs so consecutive builds don't recompile
the world. Cache key is `os-compiler-build_type-generator-pkgmaint-<hash of
all CMakeLists.txt>`.

Used by `ci.yml` and `template-janitor.yml`.

### `constants.env`

Single line: `PROJECT_NAME=myproject`. Loaded into the workflow env via
`aarcangeli/load-dotenv` so workflows refer to `${{ env.PROJECT_NAME }}`
instead of hardcoding the name. Update this when you rename the project.

### `dependabot.yml`

Tells [Dependabot](https://docs.github.com/en/code-security/dependabot) to
scan `.github/workflows/*.yml` once a week and open PRs that bump action
versions (e.g. `actions/checkout@v6` → `@v7`). Just review and merge.

### `template/`

Inputs read only by `template-janitor.yml`:

- **`template_name`** (`cmake_template`) and **`template_repository`**
  (`cpp-best-practices/cmake_template`) — janitor checks the running repo
  against these to decide "am I still upstream? skip" vs. "fresh clone, run
  rename."
- **`README.md`** — the placeholder README that becomes the repo root README
  after rename, with `%%myorg%%` / `%%myproject%%` filled in.
- **`removal-list`** — newline-separated file paths the janitor `rm`s on a
  fresh clone (upstream-specific stuff).

## Common tasks

**"My PR's clang-format check is failing":**
run `clang-format-19 -i <changed files>`, commit, push.

**"A CI job is red — where do I look?":**
GitHub → **Actions** tab → click the run → expand the failing step. Every
shell line is logged.

**"I want to disable a workflow temporarily":**
GitHub → **Actions** tab → click the workflow → ⋯ → **Disable workflow**.
No code changes needed.

**"I want to skip CI on doc-only changes":**
add `paths-ignore:` to the `on:` block of `ci.yml`:

```yaml
on:
  pull_request:
    paths-ignore:
      - '**/*.md'
```

**"I want to bump the LLVM version":**
update `LLVM_VERSION` in `.devcontainer/Dockerfile` *and*
`.devcontainer/devcontainer.json`, then `CLANG_TIDY_VERSION` /
`compiler: llvm-X.Y.Z` in `ci.yml` and `clangFormatVersion` in
`clang-format-check.yml`.

**"How do I add a new repo-wide setting (e.g. issue templates)?":**
that goes in `.github/` too — e.g., `.github/ISSUE_TEMPLATE/bug.md`. See
[GitHub's docs on community-health files](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions).
