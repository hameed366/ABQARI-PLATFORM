/// Why a cloud call did not succeed. The apps turn each kind into a message
/// in the user's language; [detail] is for logs only, never shown.
enum CloudErrorKind {
  /// No connection, DNS failure, timeout.
  offline,

  /// Wrong email or password.
  invalidCredentials,

  /// The account exists but its email address is not confirmed yet.
  emailNotConfirmed,

  /// Sign-up refused: the email is already registered.
  emailTaken,

  /// Sign-up refused: the password is too weak or too short.
  weakPassword,

  /// The session ended (signed out elsewhere, or the refresh token expired).
  signedOut,

  /// The join code does not match any open class.
  unknownClassCode,

  /// The server refused because of the user's role or ownership.
  notAllowed,

  /// Anything else: an unexpected status or an unreadable reply.
  unexpected,
}

class CloudException implements Exception {
  const CloudException(this.kind, [this.detail = '']);

  final CloudErrorKind kind;
  final String detail;

  @override
  String toString() => 'CloudException(${kind.name}: $detail)';
}
