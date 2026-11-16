import 'dart:math';

import 'bilingual.dart';
import 'model.dart';
import 'practice.dart';

const Bilingual _solve = Bilingual('حل المعادلة', 'Solve the equation');
const Bilingual _calculate =
    Bilingual('احسب، واكتب الناتج في أبسط صورة', 'Calculate; give the answer in simplest form');
const Bilingual _fractionHint =
    Bilingual('اكتب الكسر هكذا: ٣/٤', 'Type a fraction like this: 3/4');
const Bilingual _solutionsHint = Bilingual(
  'إن كان للمعادلة حلّان فافصل بينهما بفاصلة: ٢، ٣',
  'If there are two solutions, separate them with a comma: 2, 3',
);

// ── linear equations ────────────────────────────────────────────────────────

String _oneStepAdd(Random r) {
  final x = pick(r, -10, 15);
  final a = pick(r, 1, 20);
  return r.nextBool() ? 'x + $a = ${x + a}' : 'x - $a = ${x - a}';
}

String _oneStepMultiply(Random r) {
  final x = pick(r, -10, 12);
  final a = pick(r, -9, 9, except: {-1, 0, 1});
  return '${coefficient(a)} = ${a * x}';
}

String _twoStep(Random r) {
  final x = pick(r, -10, 12);
  final a = pick(r, 2, 9);
  final b = pick(r, -20, 20, except: {0});
  return '${coefficient(a)}${signed(b)} = ${a * x + b}';
}

String _brackets(Random r) {
  final x = pick(r, -9, 9);
  final a = pick(r, 2, 6);
  final b = pick(r, -9, 9, except: {0});
  return '$a(x${signed(b)}) = ${a * (x + b)}';
}

String _bothSides(Random r) {
  final x = pick(r, -9, 9);
  final a = pick(r, 2, 9);
  final c = pick(r, 1, 9, except: {a});
  final b = pick(r, -15, 15, except: {0});
  final d = a * x + b - c * x;
  return '${coefficient(a)}${signed(b)} = ${coefficient(c)}${signed(d)}';
}

const LearningPath linearEquations = LearningPath(
  id: 'linear-equations',
  title: Bilingual('المعادلات الخطية', 'Linear equations'),
  description: Bilingual(
    'من معادلة بخطوة واحدة إلى معادلات بالمتغير في الطرفين.',
    'From one-step equations to equations with the variable on both sides.',
  ),
  skills: [
    Skill(
      id: 'one-step-add',
      title: Bilingual('معادلات الجمع والطرح', 'Adding and subtracting'),
      instruction: _solve,
      form: ExpectedForm.solutions,
      maker: _oneStepAdd,
      lesson: [
        Explanation(Bilingual(
          'المعادلة ميزان متوازن: ما نفعله بأحد الطرفين نفعله بالطرف الآخر، فيبقى الميزان متوازنًا.',
          'An equation is a balanced scale: whatever we do to one side we do to the other, so it stays balanced.',
        )),
        Explanation(Bilingual(
          'إذا أُضيف عدد إلى المتغير فاطرحه من الطرفين، وإذا طُرح منه عدد فأضفه إلى الطرفين.',
          'If a number is added to the variable, subtract it from both sides; if it is subtracted, add it to both sides.',
        )),
        WorkedExample('x + 5 = 12'),
      ],
    ),
    Skill(
      id: 'one-step-multiply',
      title: Bilingual('معادلات الضرب والقسمة', 'Multiplying and dividing'),
      instruction: _solve,
      form: ExpectedForm.solutions,
      maker: _oneStepMultiply,
      prerequisites: ['one-step-add'],
      lesson: [
        Explanation(Bilingual(
          'إذا ضُرب المتغير في عدد فاقسم الطرفين على ذلك العدد.',
          'If the variable is multiplied by a number, divide both sides by that number.',
        )),
        Explanation(Bilingual(
          'انتبه للإشارة: قسمة عدد موجب على عدد سالب تعطي عددًا سالبًا.',
          'Watch the sign: a positive number divided by a negative number is negative.',
        )),
        WorkedExample('3x = 21'),
      ],
    ),
    Skill(
      id: 'two-step',
      title: Bilingual('معادلات بخطوتين', 'Two-step equations'),
      instruction: _solve,
      form: ExpectedForm.solutions,
      maker: _twoStep,
      prerequisites: ['one-step-multiply'],
      lesson: [
        Explanation(Bilingual(
          'ابدأ بالتخلص من العدد المضاف أو المطروح، ثم اقسم على معامل المتغير.',
          'First remove the number added or subtracted, then divide by the coefficient of the variable.',
        )),
        WorkedExample('2x + 3 = 11'),
      ],
    ),
    Skill(
      id: 'brackets',
      title: Bilingual('معادلات فيها أقواس', 'Equations with brackets'),
      instruction: _solve,
      form: ExpectedForm.solutions,
      maker: _brackets,
      prerequisites: ['two-step'],
      lesson: [
        Explanation(Bilingual(
          'استخدم خاصية التوزيع لفك الأقواس، ثم حل المعادلة الناتجة بخطوتين.',
          'Use the distributive property to remove the brackets, then solve the two-step equation that results.',
        )),
        WorkedExample('3(x - 2) = 12'),
      ],
    ),
    Skill(
      id: 'both-sides',
      title: Bilingual('المتغير في الطرفين', 'Variable on both sides'),
      instruction: _solve,
      form: ExpectedForm.solutions,
      maker: _bothSides,
      prerequisites: ['two-step'],
      lesson: [
        Explanation(Bilingual(
          'اجمع حدود المتغير في طرف واحد والأعداد في الطرف الآخر، ثم اقسم.',
          'Collect the variable terms on one side and the numbers on the other, then divide.',
        )),
        WorkedExample('5x - 4 = 2x + 8'),
      ],
    ),
  ],
);

// ── fractions ───────────────────────────────────────────────────────────────

(int, int) _properFraction(Random r) {
  final q = pick(r, 2, 9);
  return (pick(r, 1, q - 1), q);
}

String _addFractions(Random r) {
  final (p, q) = _properFraction(r);
  final (s, t) = _properFraction(r);
  return r.nextBool() ? '$p/$q + $s/$t' : '$p/$q - $s/$t';
}

String _multiplyFractions(Random r) {
  final (p, q) = _properFraction(r);
  final (s, t) = _properFraction(r);
  return '$p/$q * $s/$t';
}

String _divideFractions(Random r) {
  final (p, q) = _properFraction(r);
  final (s, t) = _properFraction(r);
  return '($p/$q) / ($s/$t)';
}

const LearningPath fractions = LearningPath(
  id: 'fractions',
  title: Bilingual('العمليات على الكسور', 'Operations with fractions'),
  description: Bilingual(
    'جمع الكسور وطرحها وضربها وقسمتها، والناتج في أبسط صورة.',
    'Adding, subtracting, multiplying and dividing fractions, in simplest form.',
  ),
  skills: [
    Skill(
      id: 'add-fractions',
      title: Bilingual('جمع الكسور وطرحها', 'Adding and subtracting fractions'),
      instruction: _calculate,
      answerHint: _fractionHint,
      form: ExpectedForm.value,
      maker: _addFractions,
      lesson: [
        Explanation(Bilingual(
          'لجمع كسرين أو طرحهما نوحّد المقامات أولًا، ثم نجمع البسطين أو نطرحهما.',
          'To add or subtract fractions, first give them a common denominator, then add or subtract the numerators.',
        )),
        Explanation(Bilingual(
          'اختصر الناتج بقسمة البسط والمقام على العامل المشترك الأكبر.',
          'Simplify by dividing numerator and denominator by their greatest common factor.',
        )),
        WorkedExample('1/2 + 1/3'),
      ],
    ),
    Skill(
      id: 'multiply-fractions',
      title: Bilingual('ضرب الكسور', 'Multiplying fractions'),
      instruction: _calculate,
      answerHint: _fractionHint,
      form: ExpectedForm.value,
      maker: _multiplyFractions,
      prerequisites: ['add-fractions'],
      lesson: [
        Explanation(Bilingual(
          'حاصل ضرب كسرين: بسطه حاصل ضرب البسطين، ومقامه حاصل ضرب المقامين.',
          'The product of two fractions has the product of the numerators over the product of the denominators.',
        )),
        WorkedExample('2/3 * 3/4'),
      ],
    ),
    Skill(
      id: 'divide-fractions',
      title: Bilingual('قسمة الكسور', 'Dividing fractions'),
      instruction: _calculate,
      answerHint: _fractionHint,
      form: ExpectedForm.value,
      maker: _divideFractions,
      prerequisites: ['multiply-fractions'],
      lesson: [
        Explanation(Bilingual(
          'القسمة على كسر تساوي الضرب في مقلوبه.',
          'Dividing by a fraction is the same as multiplying by its reciprocal.',
        )),
        WorkedExample('(3/4) / (2/5)'),
      ],
    ),
  ],
);

// ── quadratics ──────────────────────────────────────────────────────────────

String _expandBinomials(Random r) {
  final a = pick(r, -9, 9, except: {0});
  final b = pick(r, -9, 9, except: {0});
  return 'expand (x${signed(a)})(x${signed(b)})';
}

(int, int) _roots(Random r) => (pick(r, -9, 9, except: {0}), pick(r, -9, 9, except: {0}));

String _factorTrinomial(Random r) {
  final (m, n) = _roots(r);
  return 'factor ${quadraticText(-(m + n), m * n)}';
}

String _solveQuadratic(Random r) {
  final (m, n) = _roots(r);
  return '${quadraticText(-(m + n), m * n)} = 0';
}

const LearningPath quadratics = LearningPath(
  id: 'quadratics',
  title: Bilingual('العبارات والمعادلات التربيعية', 'Quadratic expressions and equations'),
  description: Bilingual(
    'فك الأقواس، والتحليل إلى عوامل، وحل المعادلة التربيعية.',
    'Expanding brackets, factorising, and solving quadratic equations.',
  ),
  skills: [
    Skill(
      id: 'expand-binomials',
      title: Bilingual('ضرب ذات الحدين', 'Multiplying binomials'),
      instruction: Bilingual('فك الأقواس وبسّط', 'Expand and simplify'),
      form: ExpectedForm.expanded,
      maker: _expandBinomials,
      answerHint: Bilingual('اكتب الأس بالرمز ^ مثل: س^٢ + ٥س + ٦',
          'Write powers with ^, for example: x^2 + 5x + 6'),
      lesson: [
        Explanation(Bilingual(
          'اضرب كل حد في القوس الأول في كل حد في القوس الثاني، ثم اجمع الحدود المتشابهة.',
          'Multiply every term in the first bracket by every term in the second, then collect like terms.',
        )),
        WorkedExample('expand (x + 2)(x + 3)'),
      ],
    ),
    Skill(
      id: 'factor-trinomials',
      title: Bilingual('تحليل ثلاثي الحدود', 'Factorising trinomials'),
      instruction: Bilingual('حلّل إلى عوامل', 'Factorise'),
      form: ExpectedForm.factored,
      maker: _factorTrinomial,
      prerequisites: ['expand-binomials'],
      answerHint: Bilingual('مثال: (س + ٢)(س + ٣)', 'For example: (x + 2)(x + 3)'),
      lesson: [
        Explanation(Bilingual(
          'لتحليل س٢ + ب س + جـ ابحث عن عددين حاصل ضربهما جـ ومجموعهما ب.',
          'To factorise x² + bx + c, look for two numbers whose product is c and whose sum is b.',
        )),
        WorkedExample('factor x^2 + 5x + 6'),
      ],
    ),
    Skill(
      id: 'solve-quadratic',
      title: Bilingual('حل المعادلة التربيعية', 'Solving quadratic equations'),
      instruction: _solve,
      answerHint: _solutionsHint,
      form: ExpectedForm.solutions,
      maker: _solveQuadratic,
      prerequisites: ['factor-trinomials'],
      lesson: [
        Explanation(Bilingual(
          'إذا كان حاصل ضرب عددين صفرًا فأحدهما على الأقل صفر. لذلك نحلل ثم نساوي كل عامل بالصفر.',
          'If a product is zero, at least one factor is zero. So we factorise, then set each factor equal to zero.',
        )),
        Explanation(Bilingual(
          'ويمكن دائمًا استخدام القانون العام، وهو ما يعرضه المثال.',
          'The quadratic formula always works too; the example shows it.',
        )),
        WorkedExample('x^2 - 5x + 6 = 0'),
      ],
    ),
  ],
);

/// Every learning path, in the order they are offered.
const List<LearningPath> catalog = [linearEquations, fractions, quadratics];
