# Implements: REQ-200, REQ-201, REQ-202 (docs/specs/2026-05-28-demo-greeting-design.md)
def greet(name: str) -> str:
    if name == "":
        raise ValueError("name must be non-empty")
    return f"Hello, {name}!"
