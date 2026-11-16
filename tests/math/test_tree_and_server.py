"""Trees for drawing answers, and the on-device engine service. Needs SymPy."""
from __future__ import annotations

import json
import re
import secrets
import threading
import urllib.error
import urllib.request

import pytest

sp = pytest.importorskip("sympy", reason="SymPy is not installed; engine tests did not run")

from abqari_solver import solve  # noqa: E402
from abqari_solver.server import TOKEN_HEADER, make_server  # noqa: E402
from abqari_solver.tree import to_tree  # noqa: E402

NUM = re.compile(r"^\d+(\.\d+)?$")
FUNCTIONS = {"sqrt", "sin", "cos", "tan", "log", "ln", "exp", "abs"}


def well_formed(node) -> bool:
    """Only the node kinds the Dart side understands."""
    kind = node[0]
    if kind == "num":
        return len(node) == 2 and bool(NUM.match(node[1]))
    if kind == "var":
        return len(node) == 2 and len(node[1]) == 1 and "a" <= node[1] <= "z"
    if kind == "const":
        return node[1] in ("pi", "e")
    if kind == "neg":
        return well_formed(node[1])
    if kind in ("add", "sub", "mul", "div", "pow"):
        return len(node) == 3 and well_formed(node[1]) and well_formed(node[2])
    if kind == "call":
        return node[1] in FUNCTIONS and well_formed(node[2])
    return False


def back(node):
    """Rebuild a SymPy expression from a tree (test oracle)."""
    kind = node[0]
    if kind == "num":
        return sp.Rational(node[1])
    if kind == "var":
        return sp.Symbol(node[1], real=True)
    if kind == "const":
        return sp.pi if node[1] == "pi" else sp.E
    if kind == "neg":
        return -back(node[1])
    if kind == "call":
        argument = back(node[2])
        return {
            "sqrt": sp.sqrt, "sin": sp.sin, "cos": sp.cos, "tan": sp.tan, "ln": sp.log,
            "log": lambda a: sp.log(a, 10), "exp": sp.exp, "abs": sp.Abs,
        }[node[1]](argument)
    a, b = back(node[1]), back(node[2])
    return {"add": a + b, "sub": a - b, "mul": a * b, "div": a / b, "pow": a**b}[kind]


x = sp.Symbol("x", real=True)

EXPRESSIONS = [
    sp.Integer(7), sp.Rational(-3, 4), sp.sqrt(2), -sp.sqrt(2), 5 * sp.sqrt(2),
    (-1 + sp.sqrt(5)) / 2, (-1 - sp.sqrt(5)) / 2, x**2 + 2 * x + 1, x**3 / 3,
    x**2 * sp.cos(x) + 2 * x * sp.sin(x), 2 * sp.exp(2 * x), 1 / x, 1 / (2 * sp.sqrt(x)),
    sp.log(x), sp.log(x, 10), 3 * sp.log(x, 10), x / 2 - sp.sin(2 * x) / 4, sp.Abs(x - 1),
    sp.pi / 6, sp.E**2, (x - 3) * (x + 3), 2 * x * (x + 2), -x - 1, sp.Rational(1, 2) * x,
    x ** sp.Rational(1, 3), sp.tan(x) ** 2,
]


@pytest.mark.parametrize("expression", EXPRESSIONS, ids=[sp.sstr(e) for e in EXPRESSIONS])
def test_tree_is_well_formed_and_means_the_same(expression):
    tree = to_tree(expression)
    assert tree is not None
    assert well_formed(tree), tree
    assert sp.simplify(back(tree) - expression) == 0


def test_base_ten_log_is_drawn_as_log():
    assert to_tree(sp.log(x, 10)) == ["call", "log", ["var", "x"]]
    assert to_tree(sp.log(x)) == ["call", "ln", ["var", "x"]]


def test_floats_become_decimal_numbers():
    tree = to_tree(sp.Float("1.41421356237"))
    assert tree[0] == "num" and tree[1].startswith("1.41421356237")
    assert to_tree(sp.Float("-0.5")) == ["neg", ["num", "0.5"]]


def test_what_cannot_be_drawn_returns_none():
    assert to_tree(sp.asin(x)) is None
    assert to_tree(sp.Symbol("alpha")) is None
    assert to_tree(sp.CRootOf(x**5 - x - 1, 0)) is None


def test_every_answer_of_the_engine_carries_a_tree():
    for text in ["sqrt(8)", "x^2 - 2 = 0", "derivative of x^2 sin(x)", "integrate e^x",
                 "factor x^2 - 9", "sin(pi/6)", "log(1000)", "2^x = 8"]:
        result = solve(text)
        assert result["status"] == "solved", text
        answer = result["answer"]
        trees = [s["tree"] for s in answer["solutions"]] if "solutions" in answer else [answer["tree"]]
        assert trees and all(t is not None and well_formed(t) for t in trees), (text, trees)


# ── the service ─────────────────────────────────────────────────────────────

@pytest.fixture()
def service():
    token = secrets.token_hex(32)
    server = make_server(token)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    yield f"http://127.0.0.1:{server.server_address[1]}", token
    server.shutdown()
    server.server_close()


def call(url, path, token=None, body=None):
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(url + path, data=data, method="POST" if body is not None else "GET")
    if token is not None:
        request.add_header(TOKEN_HEADER, token)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status, json.loads(response.read())
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read())


def test_service_solves_with_the_right_token(service):
    url, token = service
    assert call(url, "/health", token)[1]["ready"] is True
    status, result = call(url, "/solve", token, {"text": "جا(س) = ٠"})
    assert status == 200
    assert result["status"] in ("solved", "unsupported")
    status, result = call(url, "/solve", token, {"text": "log(1000)"})
    assert result["answer"]["tree"] == ["num", "3"]


@pytest.mark.parametrize("token", [None, "", "wrong" * 10])
def test_service_refuses_without_the_token(service, token):
    url, _ = service
    assert call(url, "/health", token)[0] == 403
    assert call(url, "/solve", token, {"text": "1+1"})[0] == 403


def test_service_rejects_bad_requests(service):
    url, token = service
    assert call(url, "/solve", token, {"nope": 1})[0] == 400
    assert call(url, "/solve", token, {"text": 5})[0] == 400
    assert call(url, "/solve", token, {"text": "x" * 9000})[0] == 413
    assert call(url, "/other", token, {"text": "1"})[0] == 404


def test_service_listens_on_loopback_only_and_needs_a_strong_token():
    with pytest.raises(ValueError):
        make_server(secrets.token_hex(32), host="0.0.0.0")
    with pytest.raises(ValueError):
        make_server("short")
