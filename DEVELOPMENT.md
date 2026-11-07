# Easy Macros — Development Notes

## Branches

- `develop` — active development and pre-release builds.
- `main` — CurseForge / public releases only. Do not push to `main` until the CurseForge project is approved and a release is intentional.

## Release notes

`RELEASENOTES.md` keeps **at most 3 versions** of history (newest first).

When cutting a new version:

1. Add a new `# Easy Macros X.Y.Z` section at the top with that release’s changes (bug fixes, features, client notes).
2. If the file would exceed 3 version sections, drop the oldest section.
3. Bump `## Version` in `EasyMacros.toc` and `EasyMacros.VERSION` in `Core/Init.lua` to match.
