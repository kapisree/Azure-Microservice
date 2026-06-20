"""Tests for render_dashboard.py."""
from pathlib import Path
import pytest


@pytest.fixture
def dashboard_project(tmp_path):
    """Create a minimal project structure for dashboard testing."""
    specs = tmp_path / "docs" / "specs"
    specs.mkdir(parents=True)
    (specs / "design.md").write_text(
        "---\ntype: spec\nphase: SPEC\nstatus: approved\n---\n"
        "# Design Spec\n\n"
        "### REQ-001: User can log in\n"
        "Users must be able to authenticate.\n\n"
        "### REQ-002: User can view dashboard\n"
        "Authenticated users see their dashboard.\n"
    )

    plans = tmp_path / "docs" / "plans"
    plans.mkdir(parents=True)
    (plans / "plan-1.md").write_text(
        "---\ntype: plan\nphase: PLAN\nstatus: approved\n---\n"
        "# Plan 1: Auth\n\n"
        "### TASK-001: Implement login endpoint\n"
        "Implements: REQ-001\n\n"
        "### TASK-002: Build dashboard page\n"
        "Implements: REQ-002\n"
    )

    src = tmp_path / "src"
    src.mkdir()
    (src / "auth.py").write_text("# Task: TASK-001\ndef login(): pass\n")
    (src / "dashboard.py").write_text("# Task: TASK-002\ndef render(): pass\n")

    tests = tmp_path / "tests"
    tests.mkdir()
    (tests / "test_auth.py").write_text("# Covers: TASK-001\ndef test_login(): pass\n")

    (tmp_path / "docs" / "dashboard").mkdir(parents=True)
    return tmp_path


def test_parse_ids_from_spec(dashboard_project):
    """Should extract REQ-NNN IDs from spec files."""
    from scripts.render_dashboard import parse_requirement_ids
    ids = parse_requirement_ids(dashboard_project / "docs" / "specs" / "design.md")
    assert "REQ-001" in ids
    assert "REQ-002" in ids


def test_parse_task_implements(dashboard_project):
    """Should extract Implements: references from plan files."""
    from scripts.render_dashboard import parse_task_references
    refs = parse_task_references(dashboard_project / "docs" / "plans" / "plan-1.md")
    assert refs["TASK-001"] == ["REQ-001"]
    assert refs["TASK-002"] == ["REQ-002"]


def test_parse_source_task_refs(dashboard_project):
    """Should extract Task: references from source files."""
    from scripts.render_dashboard import parse_source_references
    refs = parse_source_references(dashboard_project / "src")
    assert any("auth.py" in k for k in refs)


def test_build_traceability_matrix(dashboard_project):
    """Should build a complete traceability matrix."""
    from scripts.render_dashboard import build_traceability
    matrix = build_traceability(dashboard_project)
    assert "REQ-001" in matrix
    assert "TASK-001" in matrix["REQ-001"]["tasks"]


def test_parse_dafny_proves(dashboard_project):
    """Should extract Proves: REQ-NNN from .dfy files."""
    verif = dashboard_project / "verification"
    verif.mkdir()
    (verif / "auth.dfy").write_text(
        "// verification/auth.dfy\n"
        "// Proves: REQ-001\n"
        "predicate ValidToken(token: string) { |token| >= 32 }\n"
    )
    from scripts.render_dashboard import parse_verification_status
    status = parse_verification_status(dashboard_project / "verification")
    assert "REQ-001" in status
    assert status["REQ-001"]["file"] == "auth.dfy"


def test_traceability_includes_verification(dashboard_project):
    """Traceability matrix should include verification status."""
    verif = dashboard_project / "verification"
    verif.mkdir()
    (verif / "auth.dfy").write_text(
        "// verification/auth.dfy\n"
        "// Proves: REQ-001\n"
        "predicate ValidToken(token: string) { |token| >= 32 }\n"
    )
    from scripts.render_dashboard import build_traceability
    matrix = build_traceability(dashboard_project)
    assert "REQ-001" in matrix
    assert matrix["REQ-001"]["verification"] is not None
    assert matrix["REQ-001"]["verification"]["file"] == "auth.dfy"
    assert matrix["REQ-002"]["verification"] is None
