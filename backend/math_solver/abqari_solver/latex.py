"""Print a parse tree as LaTeX, exactly as the user structured it.

Used to echo back "this is what I understood" before anything is solved, so it
must not simplify or reorder. Pure Python.
"""
from __future__ import annotations

from .parser import Node, Statement

_RELATION_LATEX = {"=": "=", "<": "<", ">": ">", "<=": r"\le", ">=": r"\ge", "!=": r"\ne"}
_PRECEDENCE = {"add": 1, "sub": 1, "mul": 2, "neg": 3, "pow": 4}
_ATOM = 5


def _precedence(node: Node) -> int:
    return _PRECEDENCE.get(node[0], _ATOM)


def _wrap(text: str) -> str:
    return rf"\left({text}\right)"


def _starts_with_digit(node: Node) -> bool:
    kind = node[0]
    if kind == "num":
        return True
    if kind in ("pow", "mul", "add", "sub"):
        return _starts_with_digit(node[1])
    return False


def expression_latex(node: Node) -> str:
    kind = node[0]
    if kind == "num":
        return node[1]
    if kind == "var":
        return node[1]
    if kind == "const":
        return r"\pi" if node[1] == "pi" else "e"
    if kind == "neg":
        inner = expression_latex(node[1])
        return "-" + (_wrap(inner) if _precedence(node[1]) <= 1 else inner)
    if kind in ("add", "sub"):
        left = expression_latex(node[1])
        right = expression_latex(node[2])
        if node[2][0] == "neg" or (kind == "sub" and _precedence(node[2]) == 1):
            right = _wrap(right)
        return f"{left} {'+' if kind == 'add' else '-'} {right}"
    if kind == "mul":
        left = expression_latex(node[1])
        right = expression_latex(node[2])
        if _precedence(node[1]) <= 1 or node[1][0] == "neg":
            left = _wrap(left)
        if _precedence(node[2]) <= 1 or node[2][0] == "neg":
            right = _wrap(right)
            return f"{left} {right}"
        if _starts_with_digit(node[2]):
            return rf"{left} \times {right}"
        return f"{left} {right}"
    if kind == "div":
        return rf"\frac{{{expression_latex(node[1])}}}{{{expression_latex(node[2])}}}"
    if kind == "pow":
        base = expression_latex(node[1])
        if node[1][0] not in ("num", "var", "const"):
            base = _wrap(base)
        return f"{base}^{{{expression_latex(node[2])}}}"
    if kind == "call":
        name, argument = node[1], expression_latex(node[2])
        if name == "sqrt":
            return rf"\sqrt{{{argument}}}"
        if name == "abs":
            return rf"\left|{argument}\right|"
        return rf"\{name}{_wrap(argument)}"
    raise ValueError(f"unknown node {kind!r}")


def statement_latex(statement: Statement) -> str:
    if statement.relation is None:
        return expression_latex(statement.lhs)
    return (
        f"{expression_latex(statement.lhs)} {_RELATION_LATEX[statement.relation]} "
        f"{expression_latex(statement.rhs)}"
    )
