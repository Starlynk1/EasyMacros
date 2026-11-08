# Easy Macros — Development Notes

## Branches

- `develop` — active development and pre-release builds.
- `main` — CurseForge / public releases only. Push to `main` and tag only for intentional releases.

## Authorship

- Commits and GitHub history must show **Starlynk** only (`Starlynk` / `info@starlynk.net`).
- Do **not** add `Co-authored-by: Cursor` (or any Cursor / agent) trailers. Those make Cursor appear as a repo contributor.
- A local `.git/hooks/commit-msg` strips Cursor co-author lines automatically (recreate after clone).
- After any agent-assisted commit, confirm `git log -1` has no Cursor co-author line before pushing.
- Never push `main` or create release tags without explicit consent.

## Release notes

`RELEASENOTES.md` keeps **at most 3 versions** of history (newest first).

When cutting a new version:

1. Add a new `# Easy Macros X.Y.Z` section at the top with that release’s changes (bug fixes, features, client notes).
2. If the file would exceed 3 version sections, drop the oldest section.
3. Bump `## Version` in `EasyMacros.toc` and `EasyMacros.VERSION` in `Core/Init.lua` to match.

## Client notes

- Character macro slots: Classic **18**; Forever / Retail **30** (Classic + 12). Use `EasyMacros.CharacterMacroLimit()` — do not trust a Forever `MAX_CHARACTER_MACROS` of 18.
- Protected UI (`ShowUIPanel`, `CreateMacro`, `PickupMacro`, secure buttons): refuse or hide during `InCombatLockdown()`.
