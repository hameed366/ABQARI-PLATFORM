enum AccountRole { student, teacher, admin }

AccountRole? accountRoleFromName(Object? name) {
  for (final role in AccountRole.values) {
    if (role.name == name) return role;
  }
  return null;
}

/// The signed-in user as the server sees them.
class Account {
  const Account({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.locale,
    this.email = '',
  });

  final String userId;
  final String displayName;
  final AccountRole role;
  final String locale;
  final String email;
}

/// The result of creating an account.
sealed class SignUpResult {
  const SignUpResult();
}

/// The account is ready and signed in.
class SignedUp extends SignUpResult {
  const SignedUp(this.account);

  final Account account;
}

/// The server sent a confirmation email; sign in after confirming.
class ConfirmationSent extends SignUpResult {
  const ConfirmationSent(this.email);

  final String email;
}

/// One skill's progress, as uploaded from the app.
class ProgressItem {
  const ProgressItem({
    required this.path,
    required this.skill,
    required this.mastery,
    required this.attempts,
    required this.mastered,
  });

  /// Learning-path id (the topic slug on the server).
  final String path;

  /// Skill id (the skill slug on the server).
  final String skill;
  final int mastery;
  final int attempts;
  final bool mastered;

  Map<String, Object> toJson() => {
        'path': path,
        'skill': skill,
        'mastery': mastery,
        'attempts': attempts,
        'mastered': mastered,
      };
}

class SchoolClass {
  const SchoolClass({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.isMine,
  });

  final String id;
  final String name;

  /// The code students type to join.
  final String joinCode;

  /// True when the signed-in user is the class's teacher.
  final bool isMine;
}

/// One student's record on one skill in a class (skill fields are null for a
/// student with no uploaded progress yet).
class ClassProgressRow {
  const ClassProgressRow({
    required this.studentId,
    required this.displayName,
    this.path,
    this.skill,
    this.mastery,
    this.attempts,
    this.mastered,
  });

  final String studentId;
  final String displayName;
  final String? path;
  final String? skill;
  final int? mastery;
  final int? attempts;
  final bool? mastered;
}
