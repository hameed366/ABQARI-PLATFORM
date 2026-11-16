"""The ABQARI mathematics engine: understand → solve → verify → explain.

    >>> solve("٢س + ٣ = ٧")["answer"]["solutions"][0]["plain"]
    '2'

Every result states how far it was verified. A result whose verification
status is not "verified" must not be presented to a learner as confirmed.
"""
from __future__ import annotations

import sympy as sp
from sympy.polys.polyerrors import PolynomialError

from . import verify as v
from .errors import MathDomainError, MathInputError, UnsupportedProblem
from .latex import statement_latex
from .messages import message
from .normalize import TASKS, normalize
from .parser import Node, Statement, parse, variables
from .to_sympy import as_mp, ensure_defined, symbol, to_sympy
from .version import ENGINE_VERSION

MIN_SAMPLES = 3


# ── helpers ──────────────────────────────────────────────────────────────────

def _value(expression: sp.Expr) -> dict:
    """An exact value with a decimal approximation when it is not an integer."""
    out = {"latex": sp.latex(expression), "plain": sp.sstr(expression)}
    if not expression.free_symbols and not expression.is_Integer:
        out["approx"] = sp.sstr(expression.evalf(12))
    return out


def _step(rule: str, latex: str, *, operand: str | None = None) -> dict:
    """One solution step. `operand` is the quantity the rule acts with, as LaTeX."""
    step = {"rule": rule, "latex": latex, "text": message("step_" + rule)}
    if operand is not None:
        step["operand"] = operand
    return step


def _equation_latex(left: sp.Expr, right: sp.Expr) -> str:
    return f"{sp.latex(left)} = {sp.latex(right)}"


def _compare_at_samples(tree: Node, result: sp.Expr, names: list[str]) -> tuple[int, int]:
    """(agreeing, disagreeing) sample points between the typed input and `result`."""
    agree = disagree = 0
    for index in range(len(v.SAMPLE_POINTS)):
        env = v.sample_env(names, index)
        expected = v.numeric(tree, env)
        if expected is None:
            continue
        actual = as_mp(result, env)
        if actual is not None and v.close(expected, actual):
            agree += 1
        else:
            disagree += 1
    return agree, disagree


def _sampling_check(check: v.Verification, tree: Node, result: sp.Expr, names: list[str]) -> None:
    agree, disagree = _compare_at_samples(tree, result, names)
    if disagree:
        check.add("numeric_sampling", False, f"{disagree} sample point(s) disagree")
    elif agree >= MIN_SAMPLES:
        check.add("numeric_sampling", True, f"{agree} sample points agree to 25 digits")
    else:
        check.add("numeric_sampling", None, f"only {agree} usable sample point(s)")


def _pick_variable(names: list[str], requested: str | None) -> str:
    if requested is not None:
        if names and requested not in names:
            raise MathInputError("unknown_variable", detail=requested)
        return requested
    if len(names) == 1:
        return names[0]
    return "x"


# ── tasks ────────────────────────────────────────────────────────────────────

def _evaluate(tree: Node) -> dict:
    exact = v.exact_rational(tree)  # may raise division_by_zero before SymPy is involved
    value = sp.simplify(ensure_defined(to_sympy(tree)))
    ensure_defined(value)
    check = v.Verification()
    if exact is not None:
        same = value == sp.Rational(exact.numerator, exact.denominator)
        check.add("exact_fraction_arithmetic", bool(same), f"independent value {exact}")
    else:
        independent = v.numeric(tree)
        symbolic = as_mp(value)
        if independent is None or symbolic is None:
            check.add("high_precision_numeric", False, "independent evaluation is not a finite real")
        else:
            check.add(
                "high_precision_numeric",
                v.close(independent, symbolic),
                "agreement to 25 significant digits",
            )
    return {"task": "evaluate", "answer": _value(value), "steps": [], "verification": check}


def _transform(tree: Node, task: str) -> dict:
    names = sorted(variables(tree))
    if not names:
        return _evaluate(tree)
    expression = ensure_defined(to_sympy(tree))
    operation = {"simplify": sp.simplify, "expand": sp.expand, "factor": sp.factor}[task]
    result = operation(expression)

    check = v.Verification()
    _sampling_check(check, tree, result, names)
    proven = sp.simplify(expression - result) == 0
    check.add(
        "symbolic_equivalence",
        True if proven else None,
        "difference simplifies to zero" if proven else "could not be confirmed symbolically",
    )

    notes = []
    if result == expression:
        notes.append(message("already_simplest"))
    return {
        "task": task,
        "answer": _value(result),
        "steps": [],
        "verification": check,
        "notes": notes,
    }


def _check_statement(statement: Statement) -> dict:
    """A relation with no unknowns: is it true?"""
    left_exact = v.exact_rational(statement.lhs)
    right_exact = v.exact_rational(statement.rhs)
    left = ensure_defined(sp.simplify(ensure_defined(to_sympy(statement.lhs))))
    right = ensure_defined(sp.simplify(ensure_defined(to_sympy(statement.rhs))))
    difference = sp.simplify(left - right)
    compare = {
        "=": lambda d: d == 0, "!=": lambda d: d != 0,
        "<": lambda d: d < 0, ">": lambda d: d > 0,
        "<=": lambda d: d <= 0, ">=": lambda d: d >= 0,
    }[statement.relation]
    truth = bool(compare(difference))

    check = v.Verification()
    if left_exact is not None and right_exact is not None:
        check.add(
            "exact_fraction_arithmetic",
            bool(compare(left_exact - right_exact)) == truth,
            f"independent values {left_exact} and {right_exact}",
        )
    else:
        a, b = v.numeric(statement.lhs), v.numeric(statement.rhs)
        if a is None or b is None:
            check.add("high_precision_numeric", False, "a side is not a finite real")
        elif v.close(a, b):
            # numerically indistinguishable: consistent only with equality-type truths
            consistent = truth == (statement.relation in ("=", "<=", ">="))
            check.add("high_precision_numeric", consistent, "sides agree to 25 digits")
        else:
            check.add("high_precision_numeric", bool(compare(a - b)) == truth, "sides differ")
    return {
        "task": "check_statement",
        "answer": {
            "truth": truth,
            "latex": r"\text{true}" if truth else r"\text{false}",
            "plain": "true" if truth else "false",
            "sides": [_value(left), _value(right)],
        },
        "steps": [],
        "verification": check,
        "notes": [message("true_statement" if truth else "false_statement")],
    }


def _linear_steps(left: sp.Expr, right: sp.Expr, x: sp.Symbol) -> list[dict]:
    left_e, right_e = sp.expand(left), sp.expand(right)
    a1, b1 = left_e.coeff(x, 1), left_e.coeff(x, 0)
    a2, b2 = right_e.coeff(x, 1), right_e.coeff(x, 0)
    steps = []
    if left_e != left or right_e != right:
        steps.append(_step("expand_sides", _equation_latex(left_e, right_e)))
    a = a1 - a2
    if a2 != 0:
        rule = "add_both" if a2.is_negative else "subtract_both"
        steps.append(
            _step(rule, _equation_latex(a * x + b1, b2), operand=sp.latex(sp.Abs(a2) * x))
        )
    if b1 != 0:
        rule = "add_both" if b1.is_negative else "subtract_both"
        steps.append(_step(rule, _equation_latex(a * x, b2 - b1), operand=sp.latex(sp.Abs(b1))))
    if a != 1:
        steps.append(_step("divide_both", _equation_latex(x, (b2 - b1) / a), operand=sp.latex(a)))
    return steps


def _solve_polynomial(expression: sp.Expr, left: sp.Expr, right: sp.Expr, x: sp.Symbol):
    """Returns (solutions, steps, notes, approximate)."""
    polynomial = sp.Poly(expression, x)
    degree = polynomial.degree()
    steps: list[dict] = []
    notes: list[dict] = []

    if degree == 1:
        a, b = polynomial.all_coeffs()
        if left.is_polynomial(x) and right.is_polynomial(x):
            steps = _linear_steps(left, right, x)
        else:
            steps = [_step("move_all", _equation_latex(polynomial.as_expr(), sp.Integer(0)))]
        return [sp.simplify(-b / a)], steps, notes, False

    if degree == 2:
        a, b, c = polynomial.all_coeffs()
        steps.append(_step("standard_form", _equation_latex(polynomial.as_expr(), sp.Integer(0))))
        discriminant = sp.simplify(b**2 - 4 * a * c)
        steps.append(
            _step(
                "discriminant",
                rf"\Delta = b^2 - 4ac = \left({sp.latex(b)}\right)^2 - 4\left({sp.latex(a)}\right)"
                rf"\left({sp.latex(c)}\right) = {sp.latex(discriminant)}",
            )
        )
        if discriminant.is_negative:
            notes.append(message("no_real_solutions"))
            return [], steps, notes, False
        if discriminant.is_zero:
            root = sp.simplify(-b / (2 * a))
            notes.append(message("repeated_root"))
            steps.append(_step("quadratic_formula", rf"{sp.latex(x)} = \frac{{-b}}{{2a}} = {sp.latex(root)}"))
            return [root], steps, notes, False
        if not discriminant.is_positive:
            raise UnsupportedProblem("cannot_solve", detail="sign of discriminant unknown")
        roots = [
            sp.simplify((-b - sp.sqrt(discriminant)) / (2 * a)),
            sp.simplify((-b + sp.sqrt(discriminant)) / (2 * a)),
        ]
        steps.append(
            _step(
                "quadratic_formula",
                rf"{sp.latex(x)} = \frac{{-b \pm \sqrt{{\Delta}}}}{{2a}} = \frac{{{sp.latex(-b)} \pm "
                rf"\sqrt{{{sp.latex(discriminant)}}}}}{{{sp.latex(2 * a)}}}",
            )
        )
        if all(root.is_rational for root in roots):
            steps.append(
                _step("factorization", _equation_latex(sp.factor(polynomial.as_expr()), sp.Integer(0)))
            )
        return roots, steps, notes, False

    # degree 3 and above
    factored = sp.factor(polynomial.as_expr())
    if factored != polynomial.as_expr():
        steps.append(_step("factorization", _equation_latex(factored, sp.Integer(0))))
    try:
        roots = list(dict.fromkeys(sp.real_roots(polynomial)))
    except (NotImplementedError, PolynomialError) as error:
        raise UnsupportedProblem("cannot_solve", detail=type(error).__name__) from error
    approximate = any(root.has(sp.CRootOf) for root in roots)
    if approximate:
        notes.append(message("approximate_roots"))
    else:
        roots = [sp.simplify(root) for root in roots]
    if not roots:
        notes.append(message("no_real_solutions"))
    notes.append(message("steps_not_available"))
    return roots, steps, notes, approximate


def _solve_equation(statement: Statement, requested: str | None) -> dict:
    names = sorted(variables(statement.lhs) | variables(statement.rhs))
    if not names:
        return _check_statement(statement)
    if statement.relation != "=":
        raise UnsupportedProblem("inequality_not_supported")
    if len(names) > 1:
        raise UnsupportedProblem("multiple_variables")
    name = _pick_variable(names, requested)
    x = symbol(name)

    left = ensure_defined(to_sympy(statement.lhs))
    right = ensure_defined(to_sympy(statement.rhs))
    expression = sp.expand(left - right)
    check = v.Verification()
    notes: list[dict] = []
    steps: list[dict] = []
    approximate = False
    is_polynomial = expression.is_polynomial(x)

    if sp.simplify(expression) == 0:
        # identity: confirm on the typed input, independently
        agree = disagree = 0
        for index in range(len(v.SAMPLE_POINTS)):
            env = v.sample_env(names, index)
            a, b = v.numeric(statement.lhs, env), v.numeric(statement.rhs, env)
            if a is None or b is None:
                continue
            if v.close(a, b):
                agree += 1
            else:
                disagree += 1
        check.add(
            "numeric_sampling",
            False if disagree else (True if agree >= MIN_SAMPLES else None),
            f"{agree} agree, {disagree} disagree",
        )
        return {
            "task": "solve_equation", "variable": name,
            "answer": {"kind": "all_real_numbers", "solutions": [],
                       "latex": rf"{name} \in \mathbb{{R}}", "plain": "all real numbers"},
            "steps": [], "verification": check, "notes": [message("all_real_numbers")],
        }

    if is_polynomial and sp.Poly(expression, x).degree() == 0:
        solutions: list[sp.Expr] = []
        notes.append(message("no_real_solutions"))
        steps.append(_step("move_all", _equation_latex(expression, sp.Integer(0))))
    elif is_polynomial:
        solutions, steps, notes, approximate = _solve_polynomial(expression, left, right, x)
    else:
        try:
            found = sp.solveset(left - right, x, domain=sp.S.Reals)
        except NotImplementedError as error:
            raise UnsupportedProblem("cannot_solve", detail="solveset") from error
        if found is sp.S.EmptySet:
            solutions = []
            notes.append(message("no_real_solutions"))
        elif isinstance(found, sp.FiniteSet):
            solutions = [sp.simplify(item) for item in found]
        else:
            raise UnsupportedProblem("cannot_solve", detail=type(found).__name__)
        notes.append(message("steps_not_available"))

    solutions = sorted(solutions, key=lambda s: float(s.evalf(20)))

    # 1. every solution must satisfy the equation as typed (independent evaluator)
    for solution in solutions:
        point = as_mp(solution)
        a = None if point is None else v.numeric(statement.lhs, {name: point})
        b = None if point is None else v.numeric(statement.rhs, {name: point})
        passed = a is not None and b is not None and v.close(a, b, digits=20)
        check.add("substitution", passed, f"{name} = {sp.sstr(solution)}")
        if passed and not approximate:
            # extra evidence when SymPy can also show it exactly; silence is not failure
            residual = sp.simplify(left.subs(x, solution) - right.subs(x, solution))
            if residual == 0:
                check.add("symbolic_substitution", True, f"{name} = {sp.sstr(solution)}")

    # 2. no real solution may be missing (possible to prove for rational polynomials)
    if is_polynomial:
        try:
            expected = sp.Poly(expression, x).sqf_part().count_roots()
            check.add(
                "root_count",
                int(expected) == len(solutions),
                f"Sturm's theorem gives {expected} distinct real root(s)",
            )
        except Exception as error:  # recorded, not hidden: completeness stays unproven
            check.add("root_count", None, f"not applicable: {type(error).__name__}")
    else:
        check.add("root_count", None, "completeness cannot be proven for this equation type")

    if approximate:
        rendered = [
            {"latex": rf"{name} \approx {sp.sstr(s.evalf(12))}", "plain": sp.sstr(s.evalf(12)),
             "approx": sp.sstr(s.evalf(12))}
            for s in solutions
        ]
    else:
        rendered = [_value(s) for s in solutions]
    if solutions:
        joined = r",\; ".join(
            item["latex"] if approximate else rf"{name} = {item['latex']}" for item in rendered
        )
        steps.append(_step("solutions", joined))
    else:
        joined = r"\varnothing"
    return {
        "task": "solve_equation", "variable": name,
        "answer": {
            "kind": "finite" if solutions else "no_real_solutions",
            "solutions": rendered, "latex": joined,
            "plain": ", ".join(item["plain"] for item in rendered) or "no real solutions",
        },
        "steps": steps, "verification": check, "notes": notes,
    }


def _differentiate(tree: Node, requested: str | None) -> dict:
    import mpmath as mp

    names = sorted(variables(tree))
    name = _pick_variable(names, requested)
    x = symbol(name)
    expression = ensure_defined(to_sympy(tree))
    result = sp.simplify(sp.diff(expression, x))

    all_names = sorted(set(names) | {name})
    agree = disagree = 0
    for index in range(len(v.SAMPLE_POINTS)):
        env = v.sample_env(all_names, index)

        def f(t, env=env):
            value = v.numeric(tree, {**env, name: t})
            if value is None:
                raise ArithmeticError("undefined near the sample point")
            return value

        try:
            with mp.workdps(v.PRECISION):
                point = mp.mpf(env[name].numerator) / mp.mpf(env[name].denominator)
                slope = mp.diff(f, point)
        except (ArithmeticError, ValueError, ZeroDivisionError):
            continue
        actual = as_mp(result, env)
        if actual is not None and v.close(slope, actual, digits=12):
            agree += 1
        else:
            disagree += 1
    check = v.Verification()
    check.add(
        "numerical_differentiation",
        False if disagree else (True if agree >= MIN_SAMPLES else None),
        f"{agree} agree, {disagree} disagree (finite differences on the typed input)",
    )
    return {
        "task": "differentiate", "variable": name,
        "answer": {**_value(result), "latex": rf"\frac{{d}}{{d{name}}} = {sp.latex(result)}",
                   "result_latex": sp.latex(result)},
        "steps": [], "verification": check, "notes": [message("steps_not_available")],
    }


def _integrate(tree: Node, requested: str | None) -> dict:
    import mpmath as mp

    names = sorted(variables(tree))
    name = _pick_variable(names, requested)
    x = symbol(name)
    expression = ensure_defined(to_sympy(tree))
    result = sp.integrate(expression, x)
    if result.has(sp.Integral):
        raise UnsupportedProblem("cannot_integrate")
    result = sp.simplify(result)

    check = v.Verification()
    proven = sp.simplify(sp.diff(result, x) - expression) == 0
    check.add(
        "differentiate_back",
        True if proven else None,
        "derivative of the answer equals the integrand"
        if proven
        else "could not be confirmed symbolically",
    )
    all_names = sorted(set(names) | {name})
    agree = disagree = 0
    quarter = sp.Rational(1, 4)
    for index in range(len(v.SAMPLE_POINTS)):
        env = v.sample_env(all_names, index)
        start = sp.Rational(env[name].numerator, env[name].denominator)
        probes = [start + quarter * sp.Rational(k, 8) for k in range(9)]
        if any(v.numeric(tree, {**env, name: as_mp(p)}) is None for p in probes):
            continue  # integrand undefined somewhere on this interval

        def f(t, env=env):
            value = v.numeric(tree, {**env, name: t})
            if value is None:
                raise ArithmeticError("undefined inside the interval")
            return value

        upper = as_mp(result, {**env, name: start + quarter})
        lower = as_mp(result, {**env, name: start})
        if upper is None or lower is None:
            continue  # the antiderivative is not real here (e.g. log of a negative)
        try:
            with mp.workdps(v.PRECISION):
                area = mp.quad(f, [as_mp(start), as_mp(start + quarter)])
        except (ArithmeticError, ValueError, ZeroDivisionError):
            continue
        if v.close(area, upper - lower, digits=12):
            agree += 1
        else:
            disagree += 1
    check.add(
        "numerical_quadrature",
        False if disagree else (True if agree >= MIN_SAMPLES else None),
        f"{agree} agree, {disagree} disagree (definite integrals of the typed input)",
    )
    return {
        "task": "integrate", "variable": name,
        "answer": {"latex": sp.latex(result) + " + C", "plain": sp.sstr(result) + " + C",
                   "result_latex": sp.latex(result), "constant_of_integration": True},
        "steps": [], "verification": check, "notes": [message("steps_not_available")],
    }


# ── public entry point ───────────────────────────────────────────────────────

def _uses_log(node: Node | None) -> bool:
    if node is None or node[0] in ("num", "var", "const"):
        return False
    if node[0] == "call":
        return node[1] == "log" or _uses_log(node[2])
    return any(_uses_log(child) for child in node[1:])


def _dispatch(statement: Statement, task: str | None, variable: str | None) -> dict:
    v.check_size(statement.lhs)
    if statement.rhs is not None:
        v.check_size(statement.rhs)

    if statement.relation is not None:
        if task not in (None, "solve", "evaluate"):
            raise MathInputError("relation_needs_solve")
        return _solve_equation(statement, variable)
    if task == "solve":
        raise MathInputError("solve_needs_equation")
    if task == "differentiate":
        return _differentiate(statement.lhs, variable)
    if task == "integrate":
        return _integrate(statement.lhs, variable)
    if task in ("expand", "factor"):
        return _transform(statement.lhs, task)
    if task == "evaluate" or not variables(statement.lhs):
        if variables(statement.lhs):
            return _transform(statement.lhs, "simplify")
        return _evaluate(statement.lhs)
    return _transform(statement.lhs, "simplify")


def solve(text: str, *, task: str | None = None, variable: str | None = None) -> dict:
    """Solve one problem written as text. Always returns a JSON-serialisable dict.

    status:
      solved        — `answer`, `steps`, `verification` are present
      invalid_input — the text is not a readable problem (`error` says why/where)
      undefined     — readable, but has no defined real value
      unsupported   — readable, but beyond this engine version
    """
    base: dict = {"engine_version": ENGINE_VERSION, "input": {"raw": text}}
    try:
        if task is not None and task not in TASKS:
            raise MathInputError("unknown_task", detail=str(task))
        if variable is not None and not (len(variable) == 1 and "a" <= variable <= "z" and variable != "e"):
            raise MathInputError("unknown_variable", detail=str(variable))
        normalized = normalize(text)
        statement = parse(normalized.text)
        base["input"].update(normalized=normalized.text, latex=statement_latex(statement))
        outcome = _dispatch(statement, task or normalized.task, variable)
    except MathInputError as error:
        return {**base, "status": "invalid_input",
                "error": {**message(error.code), "position": error.position, "detail": error.detail}}
    except MathDomainError as error:
        return {**base, "status": "undefined", "error": {**message(error.code), "detail": error.detail}}
    except UnsupportedProblem as error:
        return {**base, "status": "unsupported", "error": {**message(error.code), "detail": error.detail}}

    verification: v.Verification = outcome.pop("verification")
    notes = outcome.pop("notes", [])
    if _uses_log(statement.lhs) or _uses_log(statement.rhs):
        notes.append(message("log_is_base_ten"))
    return {
        **base, "status": "solved", **outcome, "notes": notes,
        "verification": {**verification.as_dict(),
                         "summary": message("verification_" + verification.status)},
    }
