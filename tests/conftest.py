"""Shared test fixtures for SpecFlow v2."""
import os
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "scripts"))

os.environ.setdefault("ANTHROPIC_API_KEY", "test-key-not-real")
