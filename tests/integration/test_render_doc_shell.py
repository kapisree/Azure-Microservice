# tests/integration/test_render_doc_shell.py
import subprocess
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent

def test_render_doc_sh_exists_and_runs(tmp_path):
    script = ROOT / "scripts" / "render-doc.sh"
    assert script.exists()
    result = subprocess.run(["bash", str(script)], capture_output=True, text=True)
    assert result.returncode == 0

def test_render_doc_sh_skips_nonexistent_file(tmp_path):
    script = ROOT / "scripts" / "render-doc.sh"
    result = subprocess.run(["bash", str(script), str(tmp_path / "nope.md")], capture_output=True, text=True)
    assert result.returncode == 0
