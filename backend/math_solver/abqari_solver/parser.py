"""A small hand-written parser for school and university mathematics.

Pure Python, no third-party imports, and **no eval**: text is tokenised and
parsed into a plain tuple tree. Nothing a user types is ever executed.

Tree nodes:
    ("num", "12.5")            ("var", "x")              ("const", "pi" | "e")
    ("neg", a)                 ("add", a, b)             ("sub", a, b)
    ("mul", a, b)              ("div", a, b)             ("pow", a, b)
    ("call", name, a)

Grammar (implicit multiplication allowed: 2x, 2(x+1), (x+1)(x-1), x sin(x)):
    statement := expr (RELOP expr)?
    expr      := ["+" | "-"] term (("+" | "-") term)*
    term      := factor (("*" | "/") factor | factor_without_sign)*
    factor    := ("+" | "-") factor | power
    power     := primary ("^" factor)?
    primary   := NUMBER | CONST | VAR | FUNC "(" expr ")" | "(" expr ")"

So  -x^2 = -(x^2),  -2x = -(2x),  2^-1 = 1/2,  2^3^2 = 2^(3^2),  1/2x = (1/2)·x.
"""
from __future__ import annotations

import re
from dataclasses import dataclass

from .errors import MathInputError

Node = tuple

FUNCTIONS = ("sqrt", "sin", "cos", "tan", "log", "ln", "exp", "abs")
CONSTANTS = ("pi", "e")
RELATIONS = ("<=", ">=", "!=", "=", "<", ">")
MAX_DEPTH = 60

_NUMBER = re.compile(r"\d+(?:\.\d+)?")
_NAMES = tuple(sorted(FUNCTIONS + ("pi",), key=len, reverse=True))


@dataclass(frozen=True)
class Statement:
    """Either a bare expression (relation is None) or `lhs relation rhs`."""

    lhs: Node
    relation: str | None = None
    rhs: Node | None = None


@dataclass(frozen=True)
class _Token:
    kind: str  # num | var | const | func | op | rel | lparen | rparen | end
    text: str
    position: int


def tokenize(text: str) -> list[_Token]:
    tokens: list[_Token] = []
    i = 0
    while i < len(text):
        char = text[i]
        if char == " ":
            i += 1
            continue
        if char.isdigit():
            match = _NUMBER.match(text, i)
            tokens.append(_Token("num", match.group(0), i))
            i = match.end()
            if i < len(text) and text[i] == ".":
                raise MathInputError("bad_number", position=i)
            continue
        if char == ".":
            raise MathInputError("bad_number", position=i)
        if "a" <= char <= "z":
            if not tokens or tokens[-1].position + len(tokens[-1].text) != i or tokens[-1].kind not in (
                "var", "const", "func"
            ):
                run_end = i
                while run_end < len(text) and "a" <= text[run_end] <= "z":
                    run_end += 1
                _check_letter_run(text[i:run_end], i)
            for name in _NAMES:
                if text.startswith(name, i):
                    tokens.append(_Token("const" if name == "pi" else "func", name, i))
                    i += len(name)
                    break
            else:
                tokens.append(_Token("const" if char == "e" else "var", char, i))
                i += 1
            continue
        for relation in RELATIONS:
            if text.startswith(relation, i):
                tokens.append(_Token("rel", relation, i))
                i += len(relation)
                break
        else:
            if char in "+-*/^":
                tokens.append(_Token("op", char, i))
            elif char == "(":
                tokens.append(_Token("lparen", char, i))
            elif char == ")":
                tokens.append(_Token("rparen", char, i))
            else:
                raise MathInputError("unknown_symbol", position=i, detail=char)
            i += 1
    tokens.append(_Token("end", "", len(text)))
    return tokens


MAX_ADJACENT_VARIABLES = 3


def _check_letter_run(run: str, position: int) -> None:
    """Reject ordinary words: "xyz" is a product of variables, "hello" is not maths."""
    remaining = run
    for name in _NAMES:
        remaining = remaining.replace(name, " ")
    if any(len(part) > MAX_ADJACENT_VARIABLES for part in remaining.split()):
        raise MathInputError("unknown_word", position=position, detail=run)


class _Parser:
    def __init__(self, tokens: list[_Token]):
        self._tokens = tokens
        self._index = 0
        self._depth = 0

    @property
    def _current(self) -> _Token:
        return self._tokens[self._index]

    def _advance(self) -> _Token:
        token = self._current
        self._index += 1
        return token

    def _is_op(self, *symbols: str) -> bool:
        return self._current.kind == "op" and self._current.text in symbols

    def statement(self) -> Statement:
        lhs = self._expr()
        if self._current.kind == "rel":
            relation = self._advance().text
            rhs = self._expr()
            if self._current.kind == "rel":
                raise MathInputError("chained_relation", position=self._current.position)
            self._expect_end()
            return Statement(lhs, relation, rhs)
        self._expect_end()
        return Statement(lhs)

    def _expect_end(self) -> None:
        token = self._current
        if token.kind == "rparen":
            raise MathInputError("unbalanced_parentheses", position=token.position)
        if token.kind != "end":
            raise MathInputError("unexpected_token", position=token.position, detail=token.text)

    def _expr(self) -> Node:
        self._depth += 1
        if self._depth > MAX_DEPTH:
            raise MathInputError("too_deep", position=self._current.position)
        if self._is_op("-"):
            self._advance()
            node: Node = ("neg", self._term())
        else:
            if self._is_op("+"):
                self._advance()
            node = self._term()
        while self._is_op("+", "-"):
            kind = "add" if self._advance().text == "+" else "sub"
            node = (kind, node, self._term())
        self._depth -= 1
        return node

    def _term(self) -> Node:
        node = self._factor()
        while True:
            if self._is_op("*", "/"):
                kind = "mul" if self._advance().text == "*" else "div"
                node = (kind, node, self._factor())
            elif self._current.kind in ("var", "const", "func", "lparen"):
                node = ("mul", node, self._power())
            elif self._current.kind == "num":
                # "2 3" or "x2" is far more likely a typo than a product.
                raise MathInputError("missing_operator", position=self._current.position)
            else:
                return node

    def _factor(self) -> Node:
        if self._is_op("-"):
            self._advance()
            return ("neg", self._factor())
        if self._is_op("+"):
            self._advance()
            return self._factor()
        return self._power()

    def _power(self) -> Node:
        base = self._primary()
        if self._is_op("^"):
            self._advance()
            return ("pow", base, self._factor())
        return base

    def _primary(self) -> Node:
        token = self._advance()
        if token.kind == "num":
            return ("num", token.text)
        if token.kind == "var":
            return ("var", token.text)
        if token.kind == "const":
            return ("const", token.text)
        if token.kind == "func":
            if self._current.kind != "lparen":
                raise MathInputError(
                    "function_needs_parentheses", position=token.position, detail=token.text
                )
            self._advance()
            argument = self._expr()
            self._close(token.position)
            return ("call", token.text, argument)
        if token.kind == "lparen":
            inner = self._expr()
            self._close(token.position)
            return inner
        if token.kind == "end":
            raise MathInputError("incomplete", position=token.position)
        if token.kind == "rparen":
            raise MathInputError("unbalanced_parentheses", position=token.position)
        raise MathInputError("unexpected_token", position=token.position, detail=token.text)

    def _close(self, opened_at: int) -> None:
        if self._current.kind != "rparen":
            raise MathInputError("unbalanced_parentheses", position=opened_at)
        self._advance()


def parse(text: str) -> Statement:
    """Parse canonical text (see normalize.py) into a Statement."""
    return _Parser(tokenize(text)).statement()


def variables(node: Node | None) -> set[str]:
    if node is None:
        return set()
    kind = node[0]
    if kind == "var":
        return {node[1]}
    if kind in ("num", "const"):
        return set()
    if kind == "call":
        return variables(node[2])
    found: set[str] = set()
    for child in node[1:]:
        found |= variables(child)
    return found
