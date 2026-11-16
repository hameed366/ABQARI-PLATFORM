/// The text could not be understood as a mathematical problem.
class MathInputError implements Exception {
  const MathInputError(this.code, {this.position, this.detail});

  final String code;
  final int? position;
  final String? detail;

  @override
  String toString() =>
      'MathInputError($code, position: $position, detail: $detail)';
}

/// The problem is well-formed but has no defined real value.
class MathDomainError implements Exception {
  const MathDomainError(this.code, {this.detail});

  final String code;
  final String? detail;

  @override
  String toString() => 'MathDomainError($code, detail: $detail)';
}

/// The problem is understood but the on-device engine cannot solve it.
class UnsupportedProblem implements Exception {
  const UnsupportedProblem(this.code, {this.detail});

  final String code;
  final String? detail;

  @override
  String toString() => 'UnsupportedProblem($code, detail: $detail)';
}
