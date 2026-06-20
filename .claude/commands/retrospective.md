---
name: retrospective
description: Periodic factory retrospective — propose updates to constitution / templates / tests.
argument-hint: <topic-slug>
---

You are running a retrospective (`art-retrospective-cadence`).

Create a new branch: `phase/retro-$(date +%Y-%m-%d)` from main.

Read:
1. `docs/postmortems/` (if present) — production bugs and incidents.
2. `docs/plans/*/notes/` (if present) — recurring blockers and discoveries.
3. The last RELEASE notes and known-limitations docs.

Produce `docs/retrospectives/$(date +%Y-%m-%d)-$ARGUMENTS.md` with YAML frontmatter (`date`, `triggered_by: release | adhoc`, `release_version` if applicable, `proposes_changes_to: [<file-paths>...]`) and body sections: ## What Worked, ## What Didn't, ## Proposed Changes, ## Decisions on Prior Proposals, ## Open Questions.

The output **proposes** changes. It does not edit constitution.md or templates directly. Apply accepted proposals in a follow-up PR.

**Closing the loop (mandatory):** in `## Decisions on Prior Proposals`, walk every
proposal from the previous retrospective and record a decision line:
`accepted (landed: <PR/commit>) | accepted (target: <PR/owner>) | rejected (<why>) | deferred (<trigger>)`.
A proposal without a recorded decision carries forward and must be re-listed.
When this retrospective's own proposals are later decided, append the decisions
to THIS document in the follow-up PR rather than leaving them implicit.

Push and open PR per `.claude/rules/review-gate.md`.
