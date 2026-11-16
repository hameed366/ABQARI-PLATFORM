"""Independent evaluation of a parse tree, used to check the symbolic engine.

Two evaluators that share no code with SymPy's symbolic machinery:

* `exact_rational` — Python integers and `fractions.Fraction` only. Exact.
* `numeric` — mpmath arbitrary-precision floating point at 40 digits.

Both read the *parse tree of what the user typed*, not the SymPy expression,
so they also catch mistakes in the tree → SymPy conversion.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from fractions import Fraction

from .errors import MathDomainError, MathInputError
from .parser import Node

MAX_EXPONENT = 1000
MAX_BITS = 40_000
MAX_DIGITS = 40
PRECISION = 40


def exact_rational(node: Node) -> Fraction | None:
    """Exact value, or None if the tree is not plain rational arithmetic.

    Raises MathDomainError for division by zero and MathInputError when a
    power would produce an unreasonably large number.
    """
    kind = node[0]
    if kind == "num":
        if len(node[1].replace(".", "")) > MAX_DIGITS:
            raise MathInputError("number_too_large", detail=node[1][:12] + "…")
        return Fraction(node[1])
    if kind in ("var", "const", "call"):
        if kind == "call":
            exact_rational(node[2])  # still surface size/zero problems inside
        return None
    if kind == "neg":
        value = exact_rational(node[1])
        return None if value is None else -value
    left = exact_rational(node[1])
    right = exact_rational(node[2])
    if kind == "div" and right == 0:
        raise MathDomainError("division_by_zero")
    if kind == "pow" and right is not None and abs(right) > MAX_EXPONENT:
        raise MathInputError("number_too_large", detail=f"exponent {right}")
    if left is None or right is None:
        return None
    if kind == "add":
        return left + right
    if kind == "sub":
        return left - right
    if kind == "mul":
        return left * right
    if kind == "div":
        return left / right
    if kind == "pow":
        if right.denominator != 1:
            return None
        exponent = right.numerator
        if left == 0 and exponent < 0:
            raise MathDomainError("division_by_zero")
        bits = max(left.numerator.bit_length(), left.denominator.bit_length())
        if bits * abs(exponent) > MAX_BITS:
            raise MathInputError("number_too_large", detail="power")
        return left**exponent
    raise ValueError(f"unknown node {kind!r}")


def check_size(node: Node) -> None:
    """Walk the whole tree so oversized constants are rejected before SymPy sees them."""
    exact_rational(node)


def numeric(node: Node, env: dict[str, object] | None = None):
    """Real value at `env` as an mpmath number, or None if undefined / not real there."""
    import mpmath as mp

    env = env or {}

    def real(value):
        if isinstance(value, mp.mpc):
            if value.imag != 0:
                raise _NotReal
            value = value.real
        if not mp.isfinite(value):
            raise _NotReal
        return value

    def to_mp(value):
        if isinstance(value, Fraction):
            return mp.mpf(value.numerator) / mp.mpf(value.denominator)
        return mp.mpf(value)

    def walk(n: Node):
        kind = n[0]
        if kind == "num":
            return to_mp(Fraction(n[1]))
        if kind == "var":
            if n[1] not in env:
                raise KeyError(n[1])
            return to_mp(env[n[1]])
        if kind == "const":
            return mp.pi if n[1] == "pi" else mp.e
        if kind == "neg":
            return -walk(n[1])
        if kind == "call":
            argument = walk(n[2])
            function = {
                "sqrt": mp.sqrt, "sin": mp.sin, "cos": mp.cos, "tan": mp.tan,
                "log": mp.log10, "ln": mp.log, "exp": mp.exp, "abs": mp.fabs,
            }[n[1]]
            return real(function(argument))
        left, right = walk(n[1]), walk(n[2])
        if kind == "add":
            return left + right
        if kind == "sub":
            return left - right
        if kind == "mul":
            return left * right
        if kind == "div":
            return real(left / right)
        if kind == "pow":
            return real(mp.power(left, right))
        raise ValueError(f"unknown node {kind!r}")

    # Never lower the precision: mpmath's differentiation and quadrature raise it
    # on purpose while calling back into this function.
    with mp.workdps(max(mp.mp.dps, PRECISION)):
        try:
            return +real(walk(node))
        except (_NotReal, ZeroDivisionError, ValueError, OverflowError):
            return None


class _NotReal(Exception):
    pass


def close(a, b, *, digits: int = 25) -> bool:
    """True when two mpmath values agree to `digits` significant digits."""
    import mpmath as mp

    with mp.workdps(PRECISION):
        return abs(a - b) <= mp.mpf(10) ** (-digits) * (1 + abs(a) + abs(b))


# Fixed, non-special sample points: reproducible results, no accidental zeros.
SAMPLE_POINTS = (
    Fraction(3, 7), Fraction(-5, 3), Fraction(11, 4), Fraction(-2, 9),
    Fraction(17, 5), Fraction(13, 10), Fraction(-7, 2), Fraction(29, 6),
)


def sample_env(names: list[str], index: int) -> dict[str, Fraction]:
    """A different sample point for every variable at each index."""
    return {
        name: SAMPLE_POINTS[(index + 3 * offset) % len(SAMPLE_POINTS)]
        for offset, name in enumerate(names)
    }


@dataclass
class Check:
    name: str
    passed: bool | None  # None = could not be carried out
    detail: str = ""

    def as_dict(self) -> dict:
        return {"name": self.name, "passed": self.passed, "detail": self.detail}


@dataclass
class Verification:
    """Outcome of checking an answer.

    verified — every applicable independent check passed.
    partial  — nothing failed, but something could not be checked.
    failed   — at least one check contradicted the answer. Do not trust it.
    """

    checks: list[Check] = field(default_factory=list)

    def add(self, name: str, passed: bool | None, detail: str = "") -> None:
        self.checks.append(Check(name, passed, detail))

    @property
    def status(self) -> str:
        if any(check.passed is False for check in self.checks):
            return "failed"
        if not self.checks or any(check.passed is None for check in self.checks):
            return "partial"
        return "verified"

    def as_dict(self) -> dict:
        return {"status": self.status, "checks": [check.as_dict() for check in self.checks]}
