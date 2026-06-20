# Covers: REQ-200, REQ-201, REQ-202
import pytest
from src.demo_greeting.greeting import greet


def test_greet_world():
    assert greet("World") == "Hello, World!"


def test_greet_empty_raises():
    with pytest.raises(ValueError):
        greet("")
