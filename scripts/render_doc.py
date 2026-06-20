"""Render a Markdown spec/plan file to a styled HTML page using Claude."""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

from anthropic import Anthropic

ROOT = Path(__file__).parent.parent
SKILL_PATH = ROOT / ".claude" / "skills" / "doc-render" / "SKILL.md"
TEMPLATE_PATH = ROOT / "scripts" / "render_template.html"
OUTPUT_DIR = ROOT / "docs" / "dashboard"
MODEL = "claude-sonnet-4-6"


def _model():
    return MODEL


def _skill_body():
    text = SKILL_PATH.read_text()
    return re.sub(r"^---\n.*?\n---\n", "", text, count=1, flags=re.S).strip()


def _slug(p):
    try:
        rel = p.relative_to(ROOT)
    except ValueError:
        rel = p
    return str(rel).replace("/", "-").rsplit(".", 1)[0]


def _call_sonnet(system, user):
    client = Anthropic()
    resp = client.messages.create(
        model=_model(),
        max_tokens=8000,
        system=[{"type": "text", "text": system, "cache_control": {"type": "ephemeral"}}],
        messages=[{"role": "user", "content": user}],
    )
    text = resp.content[0].text
    m = re.search(r"\{.*\}", text, re.S)
    return json.loads(m.group(0))


def render(source):
    src = Path(source)
    if not src.exists():
        return None
    md = src.read_text()
    template = TEMPLATE_PATH.read_text()

    user_prompt = json.dumps({
        "source_path": str(src),
        "markdown": md,
        "template": template,
    })
    result = _call_sonnet(_skill_body(), user_prompt)

    out_path = OUTPUT_DIR / f"{_slug(src)}.html"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = out_path.with_suffix(".html.tmp")
    tmp.write_text(result["html"])
    os.replace(tmp, out_path)

    return out_path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True)
    args = ap.parse_args()
    out = render(Path(args.source))
    if out:
        print(f"[render] {args.source} -> {out}")
    else:
        print(f"[render] source missing: {args.source}", file=sys.stderr)


if __name__ == "__main__":
    main()
