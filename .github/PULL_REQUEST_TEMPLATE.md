<!--
Thanks for the PR! A few notes before you submit:

- The PR title must follow Conventional Commits (commitlint enforces this).
  Examples: `feat(cmake): add cpplint option`, `fix(ci): pin codeql action`.
- See CONTRIBUTING.md for the local quality gate.
-->

## Summary

<!-- 1–3 bullets: what changes, and why. -->

-
-

## Test plan

<!-- How did you verify this works? Reviewers will run these too. -->

- [ ] `cmake --preset clang-debug && cmake --build out/build/clang-debug`
- [ ] `ctest --test-dir out/build/clang-debug --output-on-failure`
- [ ]

## Checklist

- [ ] Title follows [Conventional Commits](https://www.conventionalcommits.org/).
- [ ] Tests added or updated, where applicable.
- [ ] If a CMake option was added, `README.md`'s options table is updated.
- [ ] If a tool was added, a corresponding step exists in `dummy_cpp_dev.md`.
- [ ] If user-visible, `CHANGELOG.md` (Unreleased) has an entry.
- [ ] No new compiler warnings (`-Werror` is on at top level).
