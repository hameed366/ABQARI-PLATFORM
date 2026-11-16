import 'bilingual.dart';
import 'practice.dart';

/// How a learner's answer must be written to count.
enum ExpectedForm {
  /// Every real solution of an equation, e.g. `3` or `2، 3`.
  solutions,

  /// One exact number, e.g. `5/6`.
  value,

  /// A polynomial with brackets multiplied out.
  expanded,

  /// A polynomial written as a product of factors.
  factored,
}

/// One paragraph or one worked example inside a lesson.
sealed class LessonBlock {
  const LessonBlock();
}

final class Explanation extends LessonBlock {
  const Explanation(this.text);
  final Bilingual text;
}

/// A problem solved live by the engine, shown with its steps.
final class WorkedExample extends LessonBlock {
  const WorkedExample(this.problem);

  /// Canonical problem text, as the engine reads it.
  final String problem;
}

/// The smallest unit that is taught, practised and mastered.
class Skill {
  const Skill({
    required this.id,
    required this.title,
    required this.instruction,
    required this.lesson,
    required this.form,
    required this.maker,
    this.prerequisites = const [],
    this.answerHint,
  });

  /// Stable identifier: lowercase latin, digits and hyphens.
  final String id;
  final Bilingual title;

  /// What the learner is asked to do with each problem ("حل المعادلة").
  final Bilingual instruction;
  final List<LessonBlock> lesson;
  final ExpectedForm form;
  final ProblemMaker maker;
  final List<String> prerequisites;

  /// How to type the answer, when that is not obvious.
  final Bilingual? answerHint;
}

/// An ordered route through related skills.
class LearningPath {
  const LearningPath({
    required this.id,
    required this.title,
    required this.description,
    required this.skills,
  });

  final String id;
  final Bilingual title;
  final Bilingual description;
  final List<Skill> skills;
}
