# tests/unit/test_render_doc.py
import json
from pathlib import Path
from unittest.mock import patch
from scripts import render_doc

SAMPLE_MD = """---
type: capability_spec
phase: SPEC
---

# Auth Capability

## Acceptance Criteria
- AC-1: Authenticate with Auth0 (vendor lock-in risk)
- AC-2: assumed availability of refresh tokens
"""

@patch.object(render_doc, "_call_sonnet")
def test_render_writes_html(mock_call, tmp_path, monkeypatch):
    mock_call.return_value = {
        "html": "<!doctype html><html><body><h1>Auth</h1></body></html>",
        "flags": {"risks": 1, "assumptions": 1, "decisions": 0},
        "title": "Auth Capability",
        "type": "capability_spec"
    }
    src = tmp_path / "spec.md"; src.write_text(SAMPLE_MD)
    dashboard = tmp_path / "dashboard"; dashboard.mkdir()

    monkeypatch.setattr(render_doc, "OUTPUT_DIR", dashboard)

    out = render_doc.render(src)
    assert out.exists() and out.read_text().startswith("<!doctype html>")

@patch.object(render_doc, "_call_sonnet")
def test_render_skips_missing_source(mock_call, tmp_path, monkeypatch):
    src = tmp_path / "missing.md"
    dashboard = tmp_path / "dashboard"; dashboard.mkdir()
    monkeypatch.setattr(render_doc, "OUTPUT_DIR", dashboard)
    assert render_doc.render(src) is None
    mock_call.assert_not_called()
