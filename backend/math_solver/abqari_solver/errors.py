"""Errors the engine reports to the user. Every one carries a stable code."""
from __future__ import annotations


class MathInputError(Exception):
    """The text could not be understood as a mathematical problem."""

    def __init__(self, code: str, *, position: int | None = None, detail: str | None = None):
        super().__init__(code if detail is None else f"{code}: {detail}")
        self.code = code
        self.position = position
        self.detail = detail


class MathDomainError(Exception):
    """The problem is well-formed but has no defined value (e.g. division by zero)."""

    def __init__(self, code: str, *, detail: str | None = None):
        super().__init__(code if detail is None else f"{code}: {detail}")
        self.code = code
        self.detail = detail


class UnsupportedProblem(Exception):
    """The problem is understood but this engine version cannot solve it."""

    def __init__(self, code: str, *, detail: str | None = None):
        super().__init__(code if detail is None else f"{code}: {detail}")
        self.code = code
        self.detail = detail
