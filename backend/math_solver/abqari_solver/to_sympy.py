"""Convert a parse tree into a SymPy expression. The only bridge to SymPy."""
from __future__ import annotations

from fractions import Fraction

import sympy as sp

from .errors import MathDomainError
from .parser import Node

_FUNCTIONS = {
    "sqrt": sp.sqrt,
    "sin": sp.sin,
    "cos": sp.cos,
    "tan": sp.tan,
    "ln": sp.log,
    "log": lambda argument: sp.log(argument, 10),
    "exp": sp.exp,
    "abs": sp.Abs,
}


def symbol(name: str) -> sp.Symbol:
    """All unknowns are real: the engine works over the real numbers."""
    return sp.Symbol(name, real=True)


def to_sympy(node: Node) -> sp.Expr:
    kind = node[0]
    if kind == "num":
        return sp.Rational(node[1])
    if kind == "var":
        return symbol(node[1])
    if kind == "const":
        return sp.pi if node[1] == "pi" else sp.E
    if kind == "neg":
        return -to_sympy(node[1])
    if kind == "call":
        return _FUNCTIONS[node[1]](to_sympy(node[2]))
    left, right = to_sympy(node[1]), to_sympy(node[2])
    if kind == "add":
        return left + right
    if kind == "sub":
        return left - right
    if kind == "mul":
        return left * right
    if kind == "div":
        if right == 0:
            raise MathDomainError("division_by_zero")
        return left / right
    if kind == "pow":
        return left**right
    raise ValueError(f"unknown node {kind!r}")


def ensure_defined(expression: sp.Expr) -> sp.Expr:
    """Reject values that are infinite, undefined, or not real."""
    if expression.has(sp.zoo, sp.nan, sp.oo, -sp.oo):
        raise MathDomainError("undefined")
    if expression.has(sp.I):
        raise MathDomainError("not_real")
    return expression


def as_mp(expression: sp.Expr, env: dict | None = None):
    """Numeric value of a SymPy expression as mpmath, or None if not a finite real."""
    import mpmath as mp

    from .verify import PRECISION

    substitutions = {
        symbol(name): sp.Rational(value.numerator, value.denominator)
        if isinstance(value, Fraction)
        else value
        for name, value in (env or {}).items()
    }
    value = expression.subs(substitutions).evalf(PRECISION + 5)
    if value.free_symbols or value.is_real is not True or value.is_finite is not True:
        return None
    with mp.workdps(PRECISION):
        return mp.mpf(str(value))
