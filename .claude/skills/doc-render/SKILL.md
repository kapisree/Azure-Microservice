---
name: doc-render
description: Convert spec/plan markdown to a styled HTML page. Highlight risks (red), assumptions (gold), decisions (blue). Output to docs/dashboard/.
model: claude-sonnet-4-6
---

# DocRender Skill

You receive one markdown document. Produce a complete styled HTML page using the provided template, and return both the HTML and a structured count of flagged items.

## Inputs
- Source markdown path
- Source markdown content
- Template HTML (with title and content placeholders)

## Steps
1. Identify document type from front-matter `type:` field or path prefix. Allowed types: `idea`, `spec`, `plan`, `tasks`.
2. Convert the markdown body to HTML preserving headings, lists, tables, code blocks.
3. For each phrase indicating a risk (words such as "risk", "danger", "concern", "vendor lock-in", "single point of failure", "no fallback"), wrap with a span carrying the `risk` class.
4. For each implicit assumption ("assumed", "TBD", "TODO", "unclear", "likely"), wrap with a span carrying the `assumption` class.
5. For each unresolved decision ("decision required", "either A or B", "TBD: choose"), wrap with a span carrying the `decision` class.
6. Aggregate counts under the keys `risks`, `assumptions`, `decisions`.
7. Substitute the title (first H1) and content (HTML body) placeholders in the template.
8. Return JSON with keys `html`, `flags`, `title`, `type`.

## Output Contract
- Never modify the source markdown.
- The HTML must be a complete document.
- The flag counts must equal the number of inserted wrappers.
- Never fabricate risks. Only flag prose that genuinely signals one.
