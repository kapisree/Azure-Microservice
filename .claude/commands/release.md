---
name: release
description: RELEASE phase — produce notes/migration/known-limitations, run quality gates, invoke per-stack hook, sign tag.
argument-hint: <version>
---

You are entering the RELEASE phase for `v$ARGUMENTS`.

Read `constitution.md` article `art-release-readiness`.

**Step 0 — sequential-PR-chain check** (retro 2026-05-28 proposal #4): determine
whether the current branch will be the final merge target state. If this RELEASE
sits at the end of a chain of unmerged PRs, the tag you create below lands on the
PR head commit and is **preliminary**: after the chain merges, if the merge
produced a different commit, delete and re-apply the tag on the post-merge HEAD
(`git tag -d v$ARGUMENTS && git tag -s v$ARGUMENTS <merge-sha> && git push origin v$ARGUMENTS --force`).
State this reminder explicitly in the PR description.

Produce in order:

1. `docs/releases/$ARGUMENTS-notes.md` with frontmatter (`version`, `date`, `specs`, `adrs`, `security_findings_accepted`, `security_findings_deferred`) and body organized as Added / Changed / Fixed / Security / Breaking.

2. `docs/releases/$ARGUMENTS-migration.md` with frontmatter (`version`, `from_versions`, `breaking`) and step-by-step upgrade instructions.

3. `docs/releases/$ARGUMENTS-known-limitations.md`. Auto-include every `status: accepted` and `status: deferred` finding from `docs/security/$ARGUMENTS-disposition.md` (by SEC-NNN id).

4. Run `bash scripts/run-quality-gates.sh` — must exit 0.

5. Resolve the active per-stack hook from `.stack`: `HOOK="scripts/release-$(cat .stack).sh"`. Run with env `VERSION=$ARGUMENTS DIST_DIR=$(pwd)/dist bash "$HOOK"`. Verify `dist/manifest.json` exists and every listed file's sha256 matches.

6. Transcribe the manifest content into `docs/releases/$ARGUMENTS-notes.md` under a `## Artifacts` section (filename + sha256 + size for each entry) so an auditor at the tag commit can verify checksums without re-running the hook (since `dist/` is gitignored).

7. Sign the tag (preferred): `git tag -s v$ARGUMENTS -m "Release v$ARGUMENTS"`. Verify with `git tag -v v$ARGUMENTS`. **Annotated fallback** (only if `git tag -s` fails because GPG is unavailable in the environment): `git tag -a v$ARGUMENTS -m "Release v$ARGUMENTS"` AND record the fallback in `docs/releases/$ARGUMENTS-known-limitations.md` with a follow-up to re-tag once GPG is configured.

8. Push and open PR per `.claude/rules/review-gate.md`. Include the dist manifest in the PR description.

Gate (per `art-release-readiness`):
- `run-quality-gates.sh` green.
- `dist/manifest.json` checksums verify against files on disk.
- Manifest content transcribed into release-notes.
- All three release docs exist.
- Signed tag OR annotated tag with documented fallback in known-limitations.
- Known-limitations references every accepted/deferred SEC-NNN (or notes "0 findings" if review is empty).
- Critical/high findings are all `status: fixed` (cannot be accepted/deferred).
