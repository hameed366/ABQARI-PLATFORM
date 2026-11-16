"""Every sentence the engine can say, in Arabic and English.

Mathematics is never embedded in these strings as digits or symbols: steps
carry their mathematics separately as LaTeX, so the client decides how numbers
and notation are displayed in each language.
"""
from __future__ import annotations

MESSAGES: dict[str, dict[str, str]] = {
    # ── input problems ──────────────────────────────────────────────────────
    "not_text": {"ar": "المدخل ليس نصًا.", "en": "The input is not text."},
    "empty": {"ar": "لم تُكتب مسألة.", "en": "No problem was entered."},
    "too_long": {"ar": "المسألة أطول من الحد المسموح.", "en": "The problem is longer than allowed."},
    "too_deep": {"ar": "الأقواس متداخلة أكثر من اللازم.", "en": "The parentheses are nested too deeply."},
    "unknown_symbol": {"ar": "رمز غير مفهوم.", "en": "Unrecognised symbol."},
    "unknown_word": {
        "ar": "كلمة غير مفهومة. هذا المحرك يقرأ العبارات الرياضية، لا المسائل اللفظية.",
        "en": "Unrecognised word. This engine reads mathematical expressions, not word problems.",
    },
    "comma_not_supported": {
        "ar": "الفاصلة غير مدعومة. استخدم النقطة للكسور العشرية.",
        "en": "Commas are not supported. Use a point for decimals.",
    },
    "bad_number": {"ar": "عدد مكتوب بصورة غير صحيحة.", "en": "A number is written incorrectly."},
    "missing_operator": {
        "ar": "ينقص رمز عملية بين عددين.",
        "en": "An operator is missing between two numbers.",
    },
    "function_needs_parentheses": {
        "ar": "ضع ما بعد الدالة بين قوسين.",
        "en": "Put the function's argument in parentheses.",
    },
    "unbalanced_parentheses": {"ar": "الأقواس غير متطابقة.", "en": "The parentheses do not match."},
    "incomplete": {"ar": "العبارة غير مكتملة.", "en": "The expression is incomplete."},
    "unexpected_token": {"ar": "رمز في غير موضعه.", "en": "A symbol is out of place."},
    "chained_relation": {
        "ar": "اكتب علاقة واحدة فقط.",
        "en": "Write a single relation only.",
    },
    "number_too_large": {"ar": "العدد أكبر من أن يُعالج.", "en": "The number is too large to process."},
    "unknown_task": {"ar": "نوع المهمة غير معروف.", "en": "Unknown task."},
    "unknown_variable": {
        "ar": "المتغير المطلوب غير موجود في المسألة.",
        "en": "The requested variable does not appear in the problem.",
    },
    # ── domain problems ─────────────────────────────────────────────────────
    "division_by_zero": {"ar": "القسمة على صفر غير معرّفة.", "en": "Division by zero is undefined."},
    "undefined": {"ar": "العبارة غير معرّفة.", "en": "The expression is undefined."},
    "not_real": {
        "ar": "الناتج ليس عددًا حقيقيًا.",
        "en": "The result is not a real number.",
    },
    # ── unsupported ─────────────────────────────────────────────────────────
    "multiple_variables": {
        "ar": "المعادلات بأكثر من متغير غير مدعومة بعد.",
        "en": "Equations in more than one variable are not supported yet.",
    },
    "inequality_not_supported": {
        "ar": "حل المتباينات غير مدعوم بعد.",
        "en": "Solving inequalities is not supported yet.",
    },
    "cannot_solve": {
        "ar": "تعذّر إيجاد حل مضبوط لهذه المعادلة.",
        "en": "No exact solution could be found for this equation.",
    },
    "cannot_integrate": {
        "ar": "تعذّر إيجاد تكامل بصيغة مغلقة.",
        "en": "No closed-form integral could be found.",
    },
    "relation_needs_solve": {
        "ar": "هذه المهمة تحتاج عبارة لا معادلة.",
        "en": "This task needs an expression, not an equation.",
    },
    "solve_needs_equation": {
        "ar": "الحل يحتاج معادلة فيها علامة يساوي.",
        "en": "Solving needs an equation with an equals sign.",
    },
    # ── notes on answers ────────────────────────────────────────────────────
    "no_real_solutions": {
        "ar": "لا توجد حلول حقيقية.",
        "en": "There are no real solutions.",
    },
    "all_real_numbers": {
        "ar": "المعادلة متطابقة: كل عدد حقيقي تكون العبارتان معرّفتين عنده حلٌّ لها.",
        "en": "The equation is an identity: every real number where both sides are defined is a solution.",
    },
    "repeated_root": {"ar": "حل واحد مكرر.", "en": "One repeated solution."},
    "approximate_roots": {
        "ar": "لا توجد صيغة مضبوطة مبسطة لهذه الحلول؛ القيم المعروضة تقريبية.",
        "en": "These solutions have no simple exact form; the values shown are approximations.",
    },
    "already_simplest": {
        "ar": "العبارة في أبسط صورة بالفعل.",
        "en": "The expression is already in its simplest form.",
    },
    "steps_not_available": {
        "ar": "خطوات الحل التفصيلية غير متاحة لهذا النوع بعد.",
        "en": "Detailed steps are not available for this type yet.",
    },
    "true_statement": {"ar": "العبارة صحيحة.", "en": "The statement is true."},
    "false_statement": {"ar": "العبارة خاطئة.", "en": "The statement is false."},
    "log_is_base_ten": {
        "ar": "الدالة log (لو) هنا للأساس عشرة، وln (لط) للأساس الطبيعي.",
        "en": "Here log is base ten and ln is the natural logarithm.",
    },
    # ── verification summaries ──────────────────────────────────────────────
    "verification_verified": {
        "ar": "تم التحقق من الناتج بطريقة مستقلة.",
        "en": "The result was verified independently.",
    },
    "verification_partial": {
        "ar": "تحقق جزئي: لم يتعارض شيء مع الناتج، لكن تعذّر إجراء بعض الفحوص. لا تعتبره مؤكدًا.",
        "en": "Partially verified: nothing contradicted the result, but some checks could not be run. Do not treat it as confirmed.",
    },
    "verification_failed": {
        "ar": "فشل التحقق: فحص مستقل تعارض مع الناتج. لا تعتمد عليه.",
        "en": "Verification failed: an independent check contradicted the result. Do not rely on it.",
    },
    # ── step explanations ───────────────────────────────────────────────────
    "step_expand_sides": {"ar": "بسّط كل طرف.", "en": "Simplify each side."},
    "step_subtract_both": {"ar": "اطرح المقدار من الطرفين.", "en": "Subtract the quantity from both sides."},
    "step_add_both": {"ar": "أضف المقدار إلى الطرفين.", "en": "Add the quantity to both sides."},
    "step_divide_both": {"ar": "اقسم الطرفين على معامل المتغير.", "en": "Divide both sides by the coefficient of the variable."},
    "step_standard_form": {
        "ar": "اكتب المعادلة على الصورة القياسية بنقل كل الحدود إلى طرف واحد.",
        "en": "Write the equation in standard form by moving every term to one side.",
    },
    "step_discriminant": {"ar": "احسب المميز.", "en": "Compute the discriminant."},
    "step_quadratic_formula": {"ar": "طبّق القانون العام.", "en": "Apply the quadratic formula."},
    "step_factorization": {"ar": "التحليل إلى عوامل.", "en": "Factorisation."},
    "step_solutions": {"ar": "الحل.", "en": "Solution."},
    "step_move_all": {"ar": "انقل كل الحدود إلى طرف واحد.", "en": "Move every term to one side."},
}


def message(code: str) -> dict[str, str]:
    """`{"code", "ar", "en"}` for a code; unknown codes are returned bare, never hidden."""
    text = MESSAGES.get(code)
    if text is None:
        return {"code": code, "ar": code, "en": code}
    return {"code": code, **text}
