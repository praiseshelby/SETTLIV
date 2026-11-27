import 'package:flutter/foundation.dart';

enum AuthProviderKind {
  google('google', 'Google'),
  passwordEmail('password-email', 'Email'),
  passwordUsername('password-username', 'Username');

  final String dbValue;
  final String displayLabel;
  const AuthProviderKind(this.dbValue, this.displayLabel);

  static AuthProviderKind fromDb(String? value) {
    switch (value) {
      case 'google':
        return AuthProviderKind.google;
      case 'password-username':
        return AuthProviderKind.passwordUsername;
      default:
        return AuthProviderKind.passwordEmail;
    }
  }
}

@immutable
class AuthUser {
  final String id;
  final String displayName;
  final String? username;
  final String? email;
  final AuthProviderKind provider;
  final int lastLoginAtMs;
  final String layout;
  final bool onboarded;
  final String? upiId;
  final int schemaVersion;
  final String? profileWarning;
  final bool isNewProfile;

  const AuthUser({
    required this.id,
    required this.displayName,
    this.username,
    this.email,
    required this.provider,
    required this.lastLoginAtMs,
    this.layout = 'web',
    this.onboarded = false,
    this.upiId,
    this.schemaVersion = 1,
    this.profileWarning,
    this.isNewProfile = false,
  });

  String get accountIdentifier => username != null ? '@$username' : (email ?? '');
}

sealed class AuthStatus {
  const AuthStatus();
}

class AuthLoading extends AuthStatus {
  const AuthLoading();
}

class AuthSignedOut extends AuthStatus {
  const AuthSignedOut();
}

class AuthGuest extends AuthStatus {
  const AuthGuest();
}

class AuthConfirmationPending extends AuthStatus {
  final String email;
  final String message;
  const AuthConfirmationPending({
    required this.email,
    required this.message,
  });
}

class AuthSignedIn extends AuthStatus {
  final AuthUser user;
  const AuthSignedIn(this.user);
}

class AuthFriendlyException implements Exception {
  final String message;
  const AuthFriendlyException(this.message);

  @override
  String toString() => message;
}

class UsernameHelper {
  UsernameHelper._();

  static final RegExp _pattern = RegExp(r'^[a-z0-9._]{3,20}$');

  static String normalize(String raw) => raw.trim().toLowerCase();

  static String? validate(String raw) {
    final norm = normalize(raw);
    if (norm.isEmpty) return 'Enter a username';
    if (norm.length < 3) return 'Username must be at least 3 characters';
    if (norm.length > 20) return 'Username must be 20 characters or fewer';
    if (!_pattern.hasMatch(norm)) {
      return 'Use only lowercase letters, digits, . and _';
    }
    return null;
  }

  static String toSyntheticEmail(String raw) => '${normalize(raw)}@u.settliv.app';

  static bool isSyntheticEmail(String? email) =>
      email != null && email.toLowerCase().endsWith('@u.settliv.app');
}

class AuthErrorMapper {
  AuthErrorMapper._();

  /// Maps backend errors to short, friendly user messages.
  /// Returns null when an OAuth flow was cancelled silently.
  static String? map(Object error, {bool isUsernameFlow = false}) {
    if (error is AuthFriendlyException) return error.message;
    final raw = error.toString().toLowerCase();

    if (raw.contains('cancel') || raw.contains('access_denied')) {
      return null;
    }
    if (raw.contains('username_taken') || raw.contains('that username is taken')) {
      return 'That username is taken';
    }
    if (raw.contains('invalid login credentials') ||
        raw.contains('invalid_credentials') ||
        raw.contains('wrong password')) {
      return 'Username or password is incorrect';
    }
    if (raw.contains('email not confirmed') || raw.contains('email_not_confirmed')) {
      return 'Please confirm your email address before signing in.';
    }
    if (raw.contains('email_address_not_authorized')) {
      return 'Email delivery is restricted in this project setup. Use Google or a username account.';
    }
    if (raw.contains('rate_limit') ||
        raw.contains('too many requests') ||
        raw.contains('over_email_send_rate_limit') ||
        raw.contains('429')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (raw.contains('user already registered') ||
        raw.contains('already been registered') ||
        raw.contains('already exists')) {
      return isUsernameFlow
          ? 'That username is taken'
          : 'An account with this email already exists.';
    }
    if (raw.contains('weak_password') ||
        raw.contains('password should be at least')) {
      return 'Password must be at least 8 characters.';
    }
    if (raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('network') ||
        raw.contains('clientexception') ||
        raw.contains('connection')) {
      return 'No connection. Check your internet and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}

abstract class AuthRepository {
  Stream<AuthStatus> get authStateChanges;
  AuthStatus get currentStatus;

  Future<void> signUpWithUsername({
    required String fullName,
    required String username,
    required String password,
    required String layout,
  });

  Future<void> signUpWithEmail({
    required String fullName,
    required String email,
    required String password,
    required String layout,
  });

  Future<void> signInWithUsername({
    required String username,
    required String password,
  });

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signInWithGoogle({required String layout});

  Future<void> sendPasswordReset({required String email});

  Future<void> signOut();

  Future<void> deleteAccount({String? password});

  Future<void> markOnboarded();

  Future<void> updateDisplayName(String displayName);
}
