"""ABQARI mathematics engine.

    from abqari_solver import solve
    solve("٢س + ٣ = ٧")

SymPy is imported only when `solve` is first called, so the input layer
(normalize, parser, latex) stays usable and testable without it.
"""
from .version import ENGINE_VERSION


def solve(text: str, *, task: str | None = None, variable: str | None = None) -> dict:
    from .engine import solve as _solve

    return _solve(text, task=task, variable=variable)


__all__ = ["ENGINE_VERSION", "solve"]
