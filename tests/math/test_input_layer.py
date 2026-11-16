"""Normaliser, parser and LaTeX echo. Pure Python: runs everywhere, no SymPy."""
from __future__ import annotations

from fractions import Fraction

import pytest

from abqari_solver.errors import MathDomainError, MathInputError
from abqari_solver.latex import statement_latex
from abqari_solver.normalize import normalize
from abqari_solver.parser import parse, variables
from abqari_solver.verify import check_size, exact_rational


def tree(text: str):
    return parse(normalize(text).text)


def latex(text: str) -> str:
    return statement_latex(tree(text))


# ── normalisation ───────────────────────────────────────────────────────────

@pytest.mark.parametrize(
    "raw,canonical",
    [
        ("٢س + ٣ = ٧", "2x + 3 = 7"),
        ("۲x", "2x"),
        ("3×4÷2−1", "3*4/2-1"),
        ("x² − 5x + 6", "x^(2) - 5x + 6"),
        ("x¹²", "x^(12)"),
        ("√9", "sqrt(9)"),
        ("√(x+1)", "sqrt(x+1)"),
        ("√س", "sqrt(x)"),
        ("جتا(س) + جا(ص)", "cos(x) + sin(y)"),
        ("ظا(ع)", "tan(z)"),
        ("لو(100) + لط(ن)", "log(100) + ln(n)"),
        ("جذر(16)", "sqrt(16)"),
        ("2π", "2pi"),
        ("3 ≤ 5", "3 <= 5"),
        ("X + Y", "x + y"),
        ("[2 + 3] × {4}", "(2 + 3) * (4)"),
        ("٣٫٥", "3.5"),
        ("  2   +   3  ", "2 + 3"),
        ("2‏+‫3", "2+3"),
        ("سَ + ١", "x + 1"),
    ],
)
def test_normalises_to_one_canonical_form(raw, canonical):
    assert normalize(raw).text == canonical


@pytest.mark.parametrize(
    "raw,task,rest",
    [
        ("حل: 2x + 3 = 7", "solve", "2x + 3 = 7"),
        ("حل المعادلة س = ١", "solve", "x = 1"),
        ("solve x^2 = 4", "solve", "x^2 = 4"),
        ("Solve for x: 2x = 4", "solve", "x: 2x = 4"),
        ("بسّط (س+١)²", "simplify", "(x+1)^(2)"),
        ("simplify 2x + 3x", "simplify", "2x + 3x"),
        ("فك (س+٢)(س−٣)", "expand", "(x+2)(x-3)"),
        ("حلل س² − ٩", "factor", "x^(2) - 9"),
        ("factorise x^2 - 9", "factor", "x^2 - 9"),
        ("اشتق جا(س)", "differentiate", "sin(x)"),
        ("derivative of x^3", "differentiate", "x^3"),
        ("تكامل جتا(س)", "integrate", "cos(x)"),
        ("integral of 1/x", "integrate", "1/x"),
        ("احسب ٢ + ٣", "evaluate", "2 + 3"),
        ("2x + 3 = 7", None, "2x + 3 = 7"),
    ],
)
def test_reads_a_leading_instruction_word(raw, task, rest):
    if ":" in rest:  # "solve for x:" leaves text the parser must reject, not guess at
        with pytest.raises(MathInputError):
            normalize(raw)
        return
    result = normalize(raw)
    assert (result.task, result.text) == (task, rest)


def test_instruction_must_be_a_whole_word():
    with pytest.raises(MathInputError) as error:
        tree("solver")
    assert error.value.code == "unknown_word"


# ── parsing: structure ──────────────────────────────────────────────────────

N = lambda value: ("num", str(value))  # noqa: E731
X = ("var", "x")


@pytest.mark.parametrize(
    "text,expected",
    [
        ("2 + 3 * 4", ("add", N(2), ("mul", N(3), N(4)))),
        ("(2 + 3) * 4", ("mul", ("add", N(2), N(3)), N(4))),
        ("10 - 2 - 3", ("sub", ("sub", N(10), N(2)), N(3))),
        ("100 / 10 / 2", ("div", ("div", N(100), N(10)), N(2))),
        ("2^3^2", ("pow", N(2), ("pow", N(3), N(2)))),
        ("-x^2", ("neg", ("pow", X, N(2)))),
        ("(-x)^2", ("pow", ("neg", X), N(2))),
        ("-2x + 3", ("add", ("neg", ("mul", N(2), X)), N(3))),
        ("2^-1", ("pow", N(2), ("neg", N(1)))),
        ("2 * -3", ("mul", N(2), ("neg", N(3)))),
        ("2x", ("mul", N(2), X)),
        ("2(x + 1)", ("mul", N(2), ("add", X, N(1)))),
        ("(x + 1)(x - 1)", ("mul", ("add", X, N(1)), ("sub", X, N(1)))),
        ("x sin(x)", ("mul", X, ("call", "sin", X))),
        ("1/2x", ("mul", ("div", N(1), N(2)), X)),
        ("2x^2", ("mul", N(2), ("pow", X, N(2)))),
        ("pi r^2", ("mul", ("const", "pi"), ("pow", ("var", "r"), N(2)))),
        ("e^x", ("pow", ("const", "e"), X)),
        ("12.5", ("num", "12.5")),
        ("((x))", X),
        ("+x", X),
    ],
)
def test_parses_with_standard_precedence(text, expected):
    statement = tree(text)
    assert statement.relation is None
    assert statement.lhs == expected


@pytest.mark.parametrize("relation", ["=", "<", ">", "<=", ">=", "!="])
def test_parses_relations(relation):
    statement = tree(f"2x + 1 {relation} 7")
    assert statement.relation == relation
    assert statement.rhs == N(7)
    assert variables(statement.lhs) == {"x"}


def test_collects_variables_but_not_constants_or_functions():
    statement = tree("a sin(b) + pi e^c = x")
    assert variables(statement.lhs) | variables(statement.rhs) == {"a", "b", "c", "x"}


# ── parsing: rejections ─────────────────────────────────────────────────────

@pytest.mark.parametrize(
    "text,code",
    [
        ("", "empty"),
        ("   ", "empty"),
        ("solve", "empty"),
        ("2 +", "incomplete"),
        ("x = ", "incomplete"),
        ("= 3", "unexpected_token"),
        ("2 3", "missing_operator"),
        ("x2", "missing_operator"),
        ("sinx", "function_needs_parentheses"),
        ("(2 + 3", "unbalanced_parentheses"),
        ("2 + 3)", "unbalanced_parentheses"),
        ("1,5", "comma_not_supported"),
        ("2..3", "bad_number"),
        ("2.", "bad_number"),
        (".5", "bad_number"),
        ("2 = 3 = 4", "chained_relation"),
        ("2 ** 3", "unexpected_token"),
        ("5!", "unknown_symbol"),
        ("a$b", "unknown_symbol"),
        ("hello", "unknown_word"),
        ("مرحبا", "unknown_word"),
        ("x" * 501, "too_long"),
        ("(" * 100 + "1" + ")" * 100, "too_deep"),
    ],
)
def test_rejects_what_it_cannot_read(text, code):
    with pytest.raises(MathInputError) as error:
        tree(text)
    assert error.value.code == code


def test_error_points_at_the_offending_character():
    with pytest.raises(MathInputError) as error:
        tree("2 + $ 3")
    assert error.value.position == 4
    assert error.value.detail == "$"


@pytest.mark.parametrize(
    "hostile",
    [
        "__import__('os').system('id')",
        "x.__class__",
        "().__class__.__bases__",
        "lambda x: x",
        "exec('1')",
        "open('/etc/passwd')",
        "[1, 2, 3]",
        "'a' + 'b'",
        '"a"',
        "x; y",
        "x\\ny",
        "os.system",
        "1 if 2 else 3",
        "eval",
        "print(1)",
        "\u0000",
    ],
)
def test_code_is_never_accepted_as_mathematics(hostile):
    """Nothing is ever evaluated: text that is not mathematics is simply rejected."""
    with pytest.raises(MathInputError):
        tree(hostile)


def test_not_text_is_rejected():
    with pytest.raises(MathInputError) as error:
        normalize(42)  # type: ignore[arg-type]
    assert error.value.code == "not_text"


# ── LaTeX echo ──────────────────────────────────────────────────────────────

@pytest.mark.parametrize(
    "text,expected",
    [
        ("٢س + ٣ = ٧", "2 x + 3 = 7"),
        ("1/2 + 1/3", r"\frac{1}{2} + \frac{1}{3}"),
        ("(x+1)^2", r"\left(x + 1\right)^{2}"),
        ("x^2 - 5x + 6 = 0", "x^{2} - 5 x + 6 = 0"),
        ("-x^2", "-x^{2}"),
        ("2^3^2", "2^{3^{2}}"),
        ("2 * 3^2", r"2 \times 3^{2}"),
        ("3 * 4", r"3 \times 4"),
        ("a - (b - c)", r"a - \left(b - c\right)"),
        ("a - (b + c)", r"a - \left(b + c\right)"),
        ("a + (b - c)", "a + b - c"),
        ("(a + b) c", r"\left(a + b\right) c"),
        ("√(x+1)", r"\sqrt{x + 1}"),
        ("abs(x - 1)", r"\left|x - 1\right|"),
        ("sin(x)^2", r"\left(\sin\left(x\right)\right)^{2}"),
        ("2 pi r", r"2 \pi r"),
        ("x <= 3", r"x \le 3"),
        ("x != 3", r"x \ne 3"),
        ("(x+1)/(x-1)", r"\frac{x + 1}{x - 1}"),
    ],
)
def test_latex_echo_preserves_what_was_typed(text, expected):
    assert latex(text) == expected


# ── exact rational arithmetic (the independent checker) ─────────────────────

@pytest.mark.parametrize(
    "text,value",
    [
        ("2 + 3 * 4", Fraction(14)),
        ("1/2 + 1/3", Fraction(5, 6)),
        ("0.1 + 0.2", Fraction(3, 10)),
        ("-3^2", Fraction(-9)),
        ("(-3)^2", Fraction(9)),
        ("2^-3", Fraction(1, 8)),
        ("2^3^2", Fraction(512)),
        ("(2/3)^2", Fraction(4, 9)),
        ("12.5 * 4", Fraction(50)),
        ("0^0", Fraction(1)),
    ],
)
def test_exact_rational_values(text, value):
    assert exact_rational(tree(text).lhs) == value


@pytest.mark.parametrize("text", ["x + 1", "sqrt(4)", "2^(1/2)", "pi", "e", "sin(0)"])
def test_exact_rational_declines_anything_beyond_fractions(text):
    assert exact_rational(tree(text).lhs) is None


@pytest.mark.parametrize("text", ["1/0", "5/(3-3)", "0^-1", "2 + 1/(4 - 2*2)", "sin(1/0)"])
def test_division_by_zero_is_a_domain_error(text):
    with pytest.raises(MathDomainError) as error:
        exact_rational(tree(text).lhs)
    assert error.value.code == "division_by_zero"


@pytest.mark.parametrize(
    "text", ["9^9^9", "2^100000", "x^(9^9)", "(2^1000)^1000", "1" * 41, "sin(7^7^7)"]
)
def test_oversized_numbers_are_refused_before_any_heavy_work(text):
    with pytest.raises(MathInputError) as error:
        check_size(tree(text).lhs)
    assert error.value.code == "number_too_large"


def test_ordinary_large_powers_are_fine():
    assert exact_rational(tree("2^1000").lhs) == Fraction(2**1000)
