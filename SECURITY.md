# Security Policy

## Supported versions

Only the `main` branch is actively maintained. Tagged releases are
supported on a best-effort basis.

## Reporting a vulnerability

**Please do not open public GitHub issues for security vulnerabilities.**

Instead, use GitHub's private vulnerability reporting:

1. Go to the repository's **Security** tab.
2. Click **Report a vulnerability**.
3. Fill in the form — you'll get a private channel with the maintainers.

Direct link:
<https://github.com/cpp-best-practices/cmake_template/security/advisories/new>

## What to include

- A clear description of the issue and its impact.
- Steps to reproduce, or a proof-of-concept.
- Affected versions / commits.
- Any suggested mitigation, if you have one.

## Response expectations

- **Acknowledgement** within 7 days.
- **Initial assessment** within 14 days.
- **Fix or mitigation** timeline depends on severity; we aim for 30 days
  on high-severity issues.
- **Disclosure**: coordinated. We'll credit reporters who want credit
  in the release notes (`CHANGELOG.md`).

## Scope

This template ships build-system scaffolding and a tiny sample library.
Security-relevant areas:

- The CMake build does **not** download arbitrary code at build time
  except via [CPM](https://github.com/cpm-cmake/CPM.cmake) — package URLs
  and Git tags are pinned in `cmake/Dependencies.cmake`.
- The dev container (`.devcontainer/Dockerfile`) installs OS packages
  from official Ubuntu repositories; please report any unexpected
  third-party fetches.
- The GitHub Actions workflows in `.github/workflows/` use only
  pinned action versions; report any unpinned action references.

Out of scope: vulnerabilities in third-party dependencies (`fmt`,
`spdlog`, `googletest`, etc.) — please report those upstream.
