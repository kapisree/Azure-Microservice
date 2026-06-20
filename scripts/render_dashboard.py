"""Generate a static pipeline dashboard from git state and doc traceability."""
from __future__ import annotations

import argparse
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).parent.parent
IMPLEMENTS_PATTERN = re.compile(r"Implements:\s*((?:(?:REQ|TASK)-\d{3}(?:,\s*)?)+)")
TASK_REF_PATTERN = re.compile(r"#\s*Task:\s*(TASK-\d{3})")
COVERS_PATTERN = re.compile(r"#\s*Covers:\s*((?:(?:REQ|TASK)-\d{3}(?:,\s*)?)+)")
PROVES_PATTERN = re.compile(r"//\s*Proves:\s*((?:REQ-\d{3}(?:,\s*)?)+)")


def parse_requirement_ids(spec_path: Path) -> list[str]:
    text = spec_path.read_text()
    return sorted(set(re.findall(r"REQ-\d{3}", text)))


def parse_task_references(plan_path: Path) -> dict[str, list[str]]:
    text = plan_path.read_text()
    refs: dict[str, list[str]] = {}
    current_task = None
    for line in text.splitlines():
        task_match = re.search(r"(TASK-\d{3})", line)
        if task_match and line.strip().startswith("#"):
            current_task = task_match.group(1)
            refs[current_task] = []
        impl_match = IMPLEMENTS_PATTERN.search(line)
        if impl_match and current_task:
            ids = re.findall(r"(?:REQ|TASK)-\d{3}", impl_match.group(1))
            refs[current_task] = [i for i in ids if i.startswith("REQ")]
    return refs


def parse_source_references(src_dir: Path) -> dict[str, str]:
    refs: dict[str, str] = {}
    if not src_dir.exists():
        return refs
    for f in src_dir.rglob("*"):
        if f.is_file() and f.suffix in (".py", ".ts", ".tsx", ".js", ".jsx", ".go"):
            try:
                first_lines = f.read_text().splitlines()[:5]
            except (UnicodeDecodeError, PermissionError):
                continue
            for line in first_lines:
                m = TASK_REF_PATTERN.search(line)
                if m:
                    refs[str(f.relative_to(src_dir.parent))] = m.group(1)
                    break
    return refs


def parse_test_references(tests_dir: Path) -> dict[str, list[str]]:
    refs: dict[str, list[str]] = {}
    if not tests_dir.exists():
        return refs
    for f in tests_dir.rglob("*"):
        if f.is_file() and f.name.startswith("test_"):
            try:
                first_lines = f.read_text().splitlines()[:5]
            except (UnicodeDecodeError, PermissionError):
                continue
            for line in first_lines:
                m = COVERS_PATTERN.search(line)
                if m:
                    ids = re.findall(r"(?:REQ|TASK)-\d{3}", m.group(1))
                    refs[str(f.relative_to(tests_dir.parent))] = ids
                    break
    return refs


def parse_verification_status(verif_dir: Path) -> dict[str, dict]:
    """Extract Proves: REQ-NNN from .dfy files. Returns {req_id: {file, path}}."""
    status: dict[str, dict] = {}
    if not verif_dir.exists():
        return status
    for f in verif_dir.glob("*.dfy"):
        try:
            first_lines = f.read_text().splitlines()[:5]
        except (UnicodeDecodeError, PermissionError):
            continue
        for line in first_lines:
            m = PROVES_PATTERN.search(line)
            if m:
                ids = re.findall(r"REQ-\d{3}", m.group(1))
                for req_id in ids:
                    status[req_id] = {"file": f.name, "path": str(f)}
                break
    return status


def build_traceability(project_root: Path) -> dict:
    matrix: dict = {}
    specs_dir = project_root / "docs" / "specs"
    if specs_dir.exists():
        for spec in specs_dir.glob("*.md"):
            for req_id in parse_requirement_ids(spec):
                matrix[req_id] = {"source": str(spec.name), "tasks": {}, "warnings": []}

    plans_dir = project_root / "docs" / "plans"
    if plans_dir.exists():
        for plan in plans_dir.glob("*.md"):
            for task_id, req_ids in parse_task_references(plan).items():
                for req_id in req_ids:
                    if req_id in matrix:
                        matrix[req_id]["tasks"][task_id] = {"plan": str(plan.name), "source_files": [], "test_files": []}
                    else:
                        matrix.setdefault(req_id, {"source": "unknown", "tasks": {}, "warnings": []})
                        matrix[req_id]["tasks"][task_id] = {"plan": str(plan.name), "source_files": [], "test_files": []}

    src_refs = parse_source_references(project_root / "src")
    for file_path, task_id in src_refs.items():
        for req_id, data in matrix.items():
            if task_id in data["tasks"]:
                data["tasks"][task_id]["source_files"].append(file_path)

    test_refs = parse_test_references(project_root / "tests")
    for file_path, covered_ids in test_refs.items():
        for cov_id in covered_ids:
            if cov_id.startswith("TASK"):
                for req_id, data in matrix.items():
                    if cov_id in data["tasks"]:
                        data["tasks"][cov_id]["test_files"].append(file_path)
            elif cov_id.startswith("REQ") and cov_id in matrix:
                for task_data in matrix[cov_id]["tasks"].values():
                    task_data["test_files"].append(file_path)

    verif_status = parse_verification_status(project_root / "verification")
    for req_id, data in matrix.items():
        if req_id in verif_status:
            data["verification"] = verif_status[req_id]
        else:
            data["verification"] = None

    for req_id, data in matrix.items():
        if not data["tasks"]:
            data["warnings"].append(f"{req_id} has no implementing tasks")
        for task_id, task_data in data["tasks"].items():
            if not task_data["source_files"]:
                data["warnings"].append(f"{task_id} has no source files referencing it")
            if not task_data["test_files"]:
                data["warnings"].append(f"{task_id} has no test coverage")

    return matrix


def get_branch_phases() -> dict[str, str]:
    phases = {"spec": "pending", "plan": "pending", "validate": "pending"}
    try:
        branches = subprocess.run(["git", "branch", "-a", "--list"], capture_output=True, text=True, check=True).stdout
        merged = subprocess.run(["git", "branch", "--merged", "main", "--list"], capture_output=True, text=True, check=True).stdout
    except (subprocess.CalledProcessError, FileNotFoundError):
        return phases
    branch_list = [b.strip().lstrip("* ") for b in branches.splitlines()]
    merged_list = [b.strip().lstrip("* ") for b in merged.splitlines()]
    for phase in phases:
        branch_name = f"phase/{phase}"
        if branch_name in merged_list:
            phases[phase] = "complete"
        elif branch_name in branch_list:
            phases[phase] = "active"
    return phases


def generate_html(matrix: dict, phases: dict, output_dir: Path) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    phase_rows = ""
    status_colors = {"complete": "#4caf50", "active": "#ff9800", "pending": "#666"}
    for phase, status in phases.items():
        color = status_colors.get(status, "#666")
        phase_rows += f'<tr><td>{phase}</td><td style="color:{color};font-weight:bold">{status}</td></tr>\n'

    trace_rows = ""
    all_warnings = []
    for req_id in sorted(matrix.keys()):
        data = matrix[req_id]
        tasks = ", ".join(sorted(data["tasks"].keys())) or "<em>none</em>"
        source_files = set()
        test_files = set()
        for task_data in data["tasks"].values():
            source_files.update(task_data["source_files"])
            test_files.update(task_data["test_files"])
        sources = ", ".join(sorted(source_files)) or "<em>none</em>"
        tests = ", ".join(sorted(test_files)) or "<em>none</em>"
        verif = data.get("verification")
        verif_cell = f'{verif["file"]} ✓' if verif else "<em>TDD only</em>"
        trace_rows += f"<tr><td>{req_id}</td><td>{tasks}</td><td>{sources}</td><td>{tests}</td><td>{verif_cell}</td></tr>\n"
        all_warnings.extend(data["warnings"])

    warnings_html = ""
    if all_warnings:
        warnings_html = "<h2>Traceability Warnings</h2><ul>\n"
        for w in all_warnings:
            warnings_html += f"<li>{w}</li>\n"
        warnings_html += "</ul>\n"

    html = f"""<!doctype html>
<html lang="en"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>SpecFlow Pipeline Dashboard</title>
<style>
:root {{
  --bg:#171614; --surface:#1c1b19; --text:#cdccca;
  --primary:#4f98a3; --border:#393836;
  font-family: -apple-system, BlinkMacSystemFont, "Inter", system-ui, sans-serif;
}}
body {{ background: var(--bg); color: var(--text); padding: 2rem; line-height: 1.6; max-width: 100ch; margin: auto; }}
h1 {{ border-bottom: 1px solid var(--border); padding-bottom: .5rem; }}
h2 {{ color: var(--primary); margin-top: 2rem; }}
table {{ width: 100%; border-collapse: collapse; margin: 1rem 0; }}
th, td {{ text-align: left; padding: .5rem; border-bottom: 1px solid var(--border); }}
th {{ color: var(--primary); font-size: .85rem; text-transform: uppercase; letter-spacing: .05em; }}
em {{ color: #888; }}
ul {{ padding-left: 1.5rem; }}
li {{ margin-bottom: .25rem; color: #e8af34; }}
</style>
</head><body>
<h1>Pipeline Dashboard</h1>
<h2>Phase Progress</h2>
<table><tr><th>Phase</th><th>Status</th></tr>
{phase_rows}</table>
<h2>Traceability Matrix</h2>
<table><tr><th>Requirement</th><th>Tasks</th><th>Source Files</th><th>Test Files</th><th>Verification</th></tr>
{trace_rows}</table>
{warnings_html}
<p style="color:#666;font-size:.8rem;margin-top:3rem">Generated by SpecFlow v3 dashboard</p>
</body></html>"""

    out_path = output_dir / "index.html"
    out_path.write_text(html)
    return out_path


def main():
    ap = argparse.ArgumentParser(description="Generate SpecFlow pipeline dashboard")
    ap.add_argument("--root", default=str(ROOT), help="Project root directory")
    ap.add_argument("--output", default=str(ROOT / "docs" / "dashboard"), help="Output directory")
    args = ap.parse_args()
    root = Path(args.root)
    output = Path(args.output)
    matrix = build_traceability(root)
    phases = get_branch_phases()
    out = generate_html(matrix, phases, output)
    print(f"[dashboard] Generated: {out}")
    if matrix:
        total_reqs = len(matrix)
        covered = sum(1 for d in matrix.values() if d["tasks"])
        print(f"[dashboard] {covered}/{total_reqs} requirements have implementing tasks")


if __name__ == "__main__":
    main()
