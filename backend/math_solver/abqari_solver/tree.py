"""Convert a SymPy result into the expression tree the apps draw.

The tree uses exactly the node kinds of the on-device engine (Dart `Node`):

    ["num", "12"]  ["num", "1.4142"]  ["var", "x"]  ["const", "pi" | "e"]
    ["neg", t]  ["add", a, b]  ["sub", a, b]  ["mul", a, b]  ["div", a, b]
    ["pow", a, b]  ["call", name, t]   name ∈ sqrt sin cos tan log ln exp abs

so an answer from the full engine is drawn with the same Arabic or Latin
notation as one from the device engine. Anything outside this vocabulary
returns None, and the app falls back to the plain text form.
"""
from __future__ import annotations

import re

import sympy as sp

_FUNCTIONS = {sp.sin: "sin", sp.cos: "cos", sp.tan: "tan", sp.exp: "exp", sp.Abs: "abs"}
_DECIMAL = re.compile(r"^\d+(\.\d+)?$")
_LOG10 = sp.log(10)
MAX_NODES = 400


class _Unsupported(Exception):
    pass


def to_tree(expression) -> list | None:
    """The tree for a SymPy expression, or None if it cannot be drawn."""
    counter = [0]
    try:
        return _tree(expression, counter)
    except (_Unsupported, RecursionError):
        return None


def _count(counter: list) -> None:
    counter[0] += 1
    if counter[0] > MAX_NODES:
        raise _Unsupported("too large to draw")


def _num(value: int) -> list:
    return ["num", str(value)]


def _rational(value: sp.Rational) -> list:
    p, q = int(value.p), int(value.q)
    node = _num(abs(p)) if q == 1 else ["div", _num(abs(p)), _num(q)]
    return ["neg", node] if p < 0 else node


def _float(value: sp.Float) -> list:
    text = sp.sstr(value, full_prec=False)
    negative = text.startswith("-")
    text = text.lstrip("-")
    if not _DECIMAL.match(text):
        raise _Unsupported(f"float {text}")
    if "." in text:
        text = text.rstrip("0").rstrip(".")
    return ["neg", ["num", text]] if negative else ["num", text]


def _fold(kind: str, nodes: list[list]) -> list:
    node = nodes[0]
    for other in nodes[1:]:
        node = [kind, node, other]
    return node


def _tree(e, counter: list) -> list:
    _count(counter)
    if e.is_Integer or e.is_Rational:
        return _rational(e)
    if e.is_Float:
        return _float(e)
    if e.is_Symbol:
        if len(e.name) != 1 or not ("a" <= e.name <= "z") or e.name == "e":
            raise _Unsupported(f"symbol {e.name}")
        return ["var", e.name]
    if e is sp.pi:
        return ["const", "pi"]
    if e is sp.E:
        return ["const", "e"]
    if e.is_Add:
        terms = e.as_ordered_terms()
        node = _tree(terms[0], counter)
        for term in terms[1:]:
            if term.could_extract_minus_sign():
                node = ["sub", node, _tree(-term, counter)]
            else:
                node = ["add", node, _tree(term, counter)]
        return node
    if e.could_extract_minus_sign():
        return ["neg", _tree(-e, counter)]
    if e.is_Mul or e.is_Pow:
        numerator, denominator = sp.fraction(e)
        if denominator == _LOG10:
            return _base_ten_log(numerator, counter)
        if denominator != 1:
            return ["div", _product(numerator, counter), _product(denominator, counter)]
        return _product(e, counter)
    if isinstance(e, sp.log):
        return ["call", "ln", _tree(e.args[0], counter)]
    function = _FUNCTIONS.get(e.func)
    if function is not None:
        return ["call", function, _tree(e.args[0], counter)]
    raise _Unsupported(type(e).__name__)


def _base_ten_log(numerator, counter: list) -> list:
    """log(u)/log(10) is the base-ten logarithm the apps write as log (لو)."""
    coefficient, rest = numerator.as_coeff_Mul()
    if not isinstance(rest, sp.log):
        return ["div", _product(numerator, counter), ["call", "ln", _num(10)]]
    call = ["call", "log", _tree(rest.args[0], counter)]
    if coefficient == 1:
        return call
    return ["mul", _tree(coefficient, counter), call]


def _product(e, counter: list) -> list:
    if e.is_Pow:
        return _power(e, counter)
    if not e.is_Mul:
        return _tree(e, counter)
    coefficient, factors = e.as_coeff_mul()
    ordered = sp.Mul(*factors).as_ordered_factors() if factors else []
    nodes = [] if coefficient == 1 else [_tree(coefficient, counter)]
    nodes += [_power(f, counter) if f.is_Pow else _tree(f, counter) for f in ordered]
    return _fold("mul", nodes) if nodes else _num(1)


def _power(e, counter: list) -> list:
    _count(counter)
    base, exponent = e.as_base_exp()
    if exponent == sp.Rational(1, 2):
        return ["call", "sqrt", _tree(base, counter)]
    return ["pow", _tree(base, counter), _tree(exponent, counter)]
