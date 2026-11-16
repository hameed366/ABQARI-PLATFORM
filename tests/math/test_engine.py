"""The solving engine against the hand-worked reference set. Needs SymPy."""
from __future__ import annotations

import json
from pathlib import Path

import pytest

sp = pytest.importorskip("sympy", reason="SymPy is not installed; engine tests did not run")

from abqari_solver import ENGINE_VERSION, solve  # noqa: E402
from abqari_solver import engine  # noqa: E402
from abqari_solver.messages import MESSAGES  # noqa: E402
from abqari_solver.verify import Verification  # noqa: E402

REFERENCE = json.loads(
    (Path(__file__).with_name("reference_problems.json")).read_text(encoding="utf-8")
)["problems"]
RANK = {"verified": 2, "partial": 1, "failed": 0}


def _expr(text: str):
    return sp.sympify(text)


def _same_value(a, b) -> bool:
    return sp.simplify(_expr(a) - _expr(b)) == 0


@pytest.mark.parametrize("problem", REFERENCE, ids=[p["id"] for p in REFERENCE])
def test_reference_problem(problem):
    result = solve(problem["input"], task=problem.get("task"))
    json.dumps(result)  # the whole result must be plain JSON
    kind, expect = problem["kind"], problem["expect"]

    if kind == "status":
        assert result["status"] == expect["status"], result
        assert result["error"]["code"] == expect["code"], result
        assert "answer" not in result
        return

    assert result["status"] == "solved", result
    answer = result["answer"]
    if kind == "value":
        assert _same_value(answer["plain"], expect), answer
    elif kind == "truth":
        assert answer["truth"] is expect, answer
    elif kind == "solutions":
        got = [s["plain"] for s in answer["solutions"]]
        assert len(got) == len(expect), got
        for mine, theirs in zip(got, expect):  # both are in ascending order
            assert _same_value(mine, theirs), (got, expect)
        if not expect:
            assert answer["kind"] == "no_real_solutions"
    elif kind == "all_real_numbers":
        assert answer["kind"] == "all_real_numbers"
    elif kind == "equivalent":
        assert _same_value(answer["plain"], expect), answer
    elif kind == "same_form":
        assert _expr(answer["plain"]) == _expr(expect), answer
    elif kind == "antiderivative":
        x = sp.Symbol("x")
        mine = _expr(answer["plain"].removesuffix(" + C"))
        assert answer["constant_of_integration"] is True
        assert sp.simplify(sp.diff(mine - _expr(expect), x)) == 0, answer
    else:  # pragma: no cover
        raise AssertionError(f"unknown kind {kind}")

    status = result["verification"]["status"]
    assert RANK[status] >= RANK[problem["verification"]], result["verification"]
    assert status != "failed"
    assert result["verification"]["summary"]["code"] == f"verification_{status}"


def test_reference_set_is_large_and_covers_every_domain():
    domains = {p["domain"] for p in REFERENCE}
    assert len(REFERENCE) >= 100
    assert {
        "arithmetic", "fractions", "roots_powers", "trigonometry", "logarithms", "statements",
        "linear_equations", "quadratic_equations", "polynomial_equations", "other_equations",
        "simplify", "expand", "factor", "derivatives", "integrals", "undefined", "unsupported",
    } <= domains
    assert len({p["id"] for p in REFERENCE}) == len(REFERENCE)


# ── shape of a result ───────────────────────────────────────────────────────

def test_result_echoes_what_was_understood():
    result = solve("حل: ٢س + ٣ = ٧")
    assert result["engine_version"] == ENGINE_VERSION
    assert result["input"] == {
        "raw": "حل: ٢س + ٣ = ٧", "normalized": "2x + 3 = 7", "latex": "2 x + 3 = 7",
    }
    assert result["task"] == "solve_equation"
    assert result["variable"] == "x"


def test_invalid_input_reports_code_position_and_both_languages():
    result = solve("2 + $ 3")
    assert result["status"] == "invalid_input"
    assert result["error"]["code"] == "unknown_symbol"
    assert result["error"]["position"] == 4
    assert result["error"]["ar"] and result["error"]["en"]
    assert "answer" not in result and "verification" not in result


@pytest.mark.parametrize("text", ["__import__('os')", "x.__class__", "9^9^9^9", "hello world"])
def test_hostile_or_meaningless_input_never_reaches_the_solver(text):
    result = solve(text)
    assert result["status"] == "invalid_input"


def test_every_message_code_has_both_languages():
    for code, text in MESSAGES.items():
        assert set(text) == {"ar", "en"}, code
        assert text["ar"].strip() and text["en"].strip(), code


def test_non_integer_values_carry_a_decimal_approximation():
    answer = solve("sqrt(2)")["answer"]
    assert answer["plain"] == "sqrt(2)"
    assert answer["approx"].startswith("1.41421356237")
    assert "approx" not in solve("2 + 2")["answer"]


def test_log_is_documented_as_base_ten():
    result = solve("log(100)")
    assert result["answer"]["plain"] == "2"
    assert "log_is_base_ten" in [note["code"] for note in result["notes"]]


# ── steps ───────────────────────────────────────────────────────────────────

def _rules(text: str) -> list[str]:
    return [step["rule"] for step in solve(text)["steps"]]


def test_linear_steps_follow_the_balance_method():
    result = solve("2x + 3 = 7")
    assert [s["rule"] for s in result["steps"]] == ["subtract_both", "divide_both", "solutions"]
    subtract, divide, final = result["steps"]
    assert subtract["operand"] == "3" and subtract["latex"] == "2 x = 4"
    assert divide["operand"] == "2" and divide["latex"] == "x = 2"
    assert final["latex"] == "x = 2"
    for step in result["steps"]:
        assert step["text"]["ar"] and step["text"]["en"]


def test_linear_steps_choose_add_or_subtract_by_sign():
    assert _rules("3x - 5 = 2x + 7") == ["subtract_both", "add_both", "solutions"]
    assert _rules("7 = 2x + 3") == ["subtract_both", "subtract_both", "divide_both", "solutions"]
    assert _rules("2(x - 3) = 4(x + 1)")[0] == "expand_sides"


def test_quadratic_steps_show_discriminant_formula_and_factors():
    result = solve("x^2 - 5x + 6 = 0")
    assert [s["rule"] for s in result["steps"]] == [
        "standard_form", "discriminant", "quadratic_formula", "factorization", "solutions",
    ]
    assert result["steps"][1]["latex"].endswith("= 1")
    assert result["steps"][-1]["latex"] == r"x = 2,\; x = 3"


def test_irrational_roots_are_not_given_a_fake_factorisation():
    assert "factorization" not in _rules("x^2 - 2 = 0")


def test_negative_discriminant_reports_no_real_solutions_with_proof():
    result = solve("x^2 + 1 = 0")
    assert result["answer"]["kind"] == "no_real_solutions"
    assert "no_real_solutions" in [n["code"] for n in result["notes"]]
    checks = {c["name"]: c["passed"] for c in result["verification"]["checks"]}
    assert checks == {"root_count": True}
    assert result["verification"]["status"] == "verified"


def test_types_without_steps_say_so():
    for text in ["derivative of x^3", "integrate x^2", "x^3 = 8", "sqrt(x) = 3"]:
        assert "steps_not_available" in [n["code"] for n in solve(text)["notes"]], text


# ── verification is real ────────────────────────────────────────────────────

def test_equation_checks_include_independent_substitution_and_root_count():
    checks = solve("x^2 - 5x + 6 = 0")["verification"]["checks"]
    names = [c["name"] for c in checks]
    assert names.count("substitution") == 2
    assert "root_count" in names
    assert all(c["passed"] is True for c in checks)


def test_extraneous_root_is_excluded():
    result = solve("(x^2 - 1)/(x - 1) = 0")
    assert [s["plain"] for s in result["answer"]["solutions"]] == ["-1"]


def test_a_wrong_derivative_is_caught(monkeypatch):
    """Sabotage the symbolic step: the independent check must refuse the answer."""
    monkeypatch.setattr(engine.sp, "diff", lambda expression, *_: expression)
    result = solve("derivative of x^3")
    assert result["verification"]["status"] == "failed"
    assert result["verification"]["summary"]["code"] == "verification_failed"


def test_a_wrong_simplification_is_caught(monkeypatch):
    monkeypatch.setattr(engine.sp, "expand", lambda expression, *_, **__: expression + 1)
    result = solve("expand (x+1)^2")
    assert result["verification"]["status"] == "failed"


def test_a_wrong_arithmetic_result_is_caught(monkeypatch):
    monkeypatch.setattr(engine.sp, "simplify", lambda expression, *_, **__: expression + 1)
    result = solve("2 + 3 * 4")
    assert result["verification"]["status"] == "failed"


def test_a_missed_root_is_caught(monkeypatch):
    real = engine.sp.real_roots
    monkeypatch.setattr(engine.sp, "real_roots", lambda polynomial: real(polynomial)[:-1])
    result = solve("x^3 - 6x^2 + 11x - 6 = 0")
    assert result["verification"]["status"] == "failed"
    failed = [c["name"] for c in result["verification"]["checks"] if c["passed"] is False]
    assert failed == ["root_count"]


def test_verification_status_rules():
    check = Verification()
    assert check.status == "partial"  # nothing checked is never "verified"
    check.add("a", True)
    assert check.status == "verified"
    check.add("b", None)
    assert check.status == "partial"
    check.add("c", False)
    assert check.status == "failed"


# ── options ─────────────────────────────────────────────────────────────────

def test_explicit_task_overrides_the_default():
    assert solve("(x+1)^2", task="expand")["answer"]["plain"] == "x**2 + 2*x + 1"
    assert solve("x^2", task="differentiate")["answer"]["plain"] == "2*x"


@pytest.mark.parametrize(
    "kwargs,code",
    [
        ({"task": "teleport"}, "unknown_task"),
        ({"variable": "xy"}, "unknown_variable"),
        ({"variable": "e"}, "unknown_variable"),
    ],
)
def test_bad_options_are_rejected(kwargs, code):
    result = solve("x + 1", **kwargs)
    assert result["status"] == "invalid_input" and result["error"]["code"] == code


def test_task_and_input_must_agree():
    assert solve("x^2 = 4", task="differentiate")["error"]["code"] == "relation_needs_solve"
    assert solve("solve x^2 + 1")["error"]["code"] == "solve_needs_equation"


def test_equation_in_another_letter_solves_for_that_letter():
    result = solve("3t + 1 = 10")
    assert result["variable"] == "t"
    assert result["steps"][-1]["latex"] == "t = 3"
