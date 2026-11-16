import 'dart:convert';

import 'model.dart';

enum MasteryLevel { notStarted, learning, practising, mastered }

/// A learner's record on one skill. Mastery looks at the most recent
/// [window] answers, so it rises with practice and falls when forgotten.
class SkillProgress {
  const SkillProgress({this.recent = const [], this.attempts = 0, this.correct = 0});

  static const int window = 5;
  static const int masteredAt = 80;
  static const int practisingAt = 60;

  final List<bool> recent;
  final int attempts;
  final int correct;

  int get masteryPercent =>
      recent.isEmpty ? 0 : (recent.where((r) => r).length * 100 / recent.length).round();

  MasteryLevel get level {
    if (attempts == 0) return MasteryLevel.notStarted;
    if (recent.length >= window && masteryPercent >= masteredAt) return MasteryLevel.mastered;
    if (masteryPercent >= practisingAt) return MasteryLevel.practising;
    return MasteryLevel.learning;
  }

  SkillProgress record(bool isCorrect) {
    final updated = [...recent, isCorrect];
    return SkillProgress(
      recent: updated.length > window ? updated.sublist(updated.length - window) : updated,
      attempts: attempts + 1,
      correct: correct + (isCorrect ? 1 : 0),
    );
  }

  Map<String, Object> toJson() => {'recent': recent, 'attempts': attempts, 'correct': correct};

  /// Tolerant: anything unreadable becomes an empty record, never a crash.
  static SkillProgress fromJson(Object? json) {
    if (json is! Map) return const SkillProgress();
    final recent = json['recent'];
    final attempts = json['attempts'];
    final correct = json['correct'];
    if (recent is! List || attempts is! int || correct is! int) return const SkillProgress();
    final flags = [for (final r in recent) if (r is bool) r];
    if (attempts < 0 || correct < 0 || correct > attempts || flags.length > window) {
      return const SkillProgress();
    }
    return SkillProgress(recent: flags, attempts: attempts, correct: correct);
  }
}

/// Everything a learner has done, keyed by skill id. Immutable.
class LearnerProgress {
  const LearnerProgress([this.skills = const {}]);

  final Map<String, SkillProgress> skills;

  SkillProgress of(String skillId) => skills[skillId] ?? const SkillProgress();

  LearnerProgress record(String skillId, bool isCorrect) =>
      LearnerProgress({...skills, skillId: of(skillId).record(isCorrect)});

  /// Open when every prerequisite is mastered.
  bool isUnlocked(Skill skill) =>
      skill.prerequisites.every((id) => of(id).level == MasteryLevel.mastered);

  /// The first open skill of [path] that is not mastered yet.
  Skill? recommendedNext(LearningPath path) {
    for (final skill in path.skills) {
      if (isUnlocked(skill) && of(skill.id).level != MasteryLevel.mastered) return skill;
    }
    return null;
  }

  int pathPercent(LearningPath path) {
    if (path.skills.isEmpty) return 0;
    final total = path.skills.fold<int>(0, (sum, s) => sum + of(s.id).masteryPercent);
    return (total / path.skills.length).round();
  }

  String encode() => jsonEncode({
        'version': 1,
        'skills': {for (final e in skills.entries) e.key: e.value.toJson()},
      });

  static LearnerProgress decode(String? text) {
    if (text == null || text.isEmpty) return const LearnerProgress();
    try {
      final json = jsonDecode(text);
      if (json is! Map || json['version'] != 1 || json['skills'] is! Map) {
        return const LearnerProgress();
      }
      return LearnerProgress({
        for (final e in (json['skills'] as Map).entries)
          if (e.key is String) e.key as String: SkillProgress.fromJson(e.value),
      });
    } on FormatException {
      return const LearnerProgress();
    }
  }
}
