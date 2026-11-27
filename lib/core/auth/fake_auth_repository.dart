import 'dart:async';
import 'auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  final StreamController<AuthStatus> _controller =
      StreamController<AuthStatus>.broadcast();

  AuthStatus _status = const AuthSignedOut();
  final Map<String, ({String id, String password, AuthUser user, bool confirmed})>
      _usersByEmail = {};
  bool requireEmailConfirmation = false;
  bool simulateSmtpRestriction = false;
  bool simulateOAuthCancel = false;

  @override
  Stream<AuthStatus> get authStateChanges => _controller.stream;

  @override
  AuthStatus get currentStatus => _status;

  void _emit(AuthStatus next) {
    _status = next;
    _controller.add(next);
  }

  @override
  Future<void> signUpWithUsername({
    required String fullName,
    required String username,
    required String password,
    required String layout,
  }) async {
    final err = UsernameHelper.validate(username);
    if (err != null) throw AuthFriendlyException(err);
    if (password.length < 8) {
      throw const AuthFriendlyException('Password must be at least 8 characters.');
    }
    final norm = UsernameHelper.normalize(username);
    final syntheticEmail = UsernameHelper.toSyntheticEmail(norm);
    if (_usersByEmail.containsKey(syntheticEmail)) {
      throw const AuthFriendlyException('That username is taken');
    }
    final user = AuthUser(
      id: 'uid_$norm',
      displayName: fullName.trim(),
      username: norm,
      email: null,
      provider: AuthProviderKind.passwordUsername,
      lastLoginAtMs: DateTime.now().millisecondsSinceEpoch,
      layout: layout,
      isNewProfile: true,
    );
    _usersByEmail[syntheticEmail] = (
      id: user.id,
      password: password,
      user: user,
      confirmed: true,
    );
    _emit(AuthSignedIn(user));
  }

  @override
  Future<void> signUpWithEmail({
    required String fullName,
    required String email,
    required String password,
    required String layout,
  }) async {
    if (password.length < 8) {
      throw const AuthFriendlyException('Password must be at least 8 characters.');
    }
    if (simulateSmtpRestriction) {
      throw const AuthFriendlyException(
        'Email delivery is restricted in this project setup. Use Google or a username account.',
      );
    }
    final normEmail = email.trim().toLowerCase();
    if (_usersByEmail.containsKey(normEmail)) {
      throw const AuthFriendlyException('An account with this email already exists.');
    }
    final user = AuthUser(
      id: 'uid_${normEmail.hashCode}',
      displayName: fullName.trim(),
      username: null,
      email: normEmail,
      provider: AuthProviderKind.passwordEmail,
      lastLoginAtMs: DateTime.now().millisecondsSinceEpoch,
      layout: layout,
      isNewProfile: true,
    );
    final confirmed = !requireEmailConfirmation;
    _usersByEmail[normEmail] = (
      id: user.id,
      password: password,
      user: user,
      confirmed: confirmed,
    );
    if (!confirmed) {
      _emit(
        AuthConfirmationPending(
          email: normEmail,
          message: 'Check $normEmail to confirm your account before signing in.',
        ),
      );
    } else {
      _emit(AuthSignedIn(user));
    }
  }

  @override
  Future<void> signInWithUsername({
    required String username,
    required String password,
  }) async {
    final norm = UsernameHelper.normalize(username);
    final syntheticEmail = UsernameHelper.toSyntheticEmail(norm);
    final record = _usersByEmail[syntheticEmail];
    if (record == null || record.password != password) {
      throw const AuthFriendlyException('Username or password is incorrect');
    }
    final updated = AuthUser(
      id: record.user.id,
      displayName: record.user.displayName,
      username: record.user.username,
      email: null,
      provider: AuthProviderKind.passwordUsername,
      lastLoginAtMs: DateTime.now().millisecondsSinceEpoch,
      layout: record.user.layout,
    );
    _emit(AuthSignedIn(updated));
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final normEmail = email.trim().toLowerCase();
    final record = _usersByEmail[normEmail];
    if (record == null || record.password != password) {
      throw const AuthFriendlyException('Username or password is incorrect');
    }
    if (!record.confirmed) {
      throw const AuthFriendlyException(
        'Please confirm your email address before signing in.',
      );
    }
    _emit(AuthSignedIn(record.user));
  }

  @override
  Future<void> signInWithGoogle({required String layout}) async {
    if (simulateOAuthCancel) return;
    final user = AuthUser(
      id: 'uid_google_demo',
      displayName: 'Google User',
      email: 'user@gmail.com',
      provider: AuthProviderKind.google,
      lastLoginAtMs: DateTime.now().millisecondsSinceEpoch,
      layout: layout,
    );
    _emit(AuthSignedIn(user));
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    if (simulateSmtpRestriction) {
      throw const AuthFriendlyException(
        'Email delivery is restricted in this project setup. Use Google or a username account.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    _emit(const AuthSignedOut());
  }

  @override
  Future<void> deleteAccount({String? password}) async {
    final status = _status;
    if (status is AuthSignedIn) {
      _usersByEmail.removeWhere((_, v) => v.id == status.user.id);
    }
    _emit(const AuthSignedOut());
  }

  @override
  Future<void> markOnboarded() async {
    final status = _status;
    if (status is AuthSignedIn) {
      final u = status.user;
      final updated = AuthUser(
        id: u.id,
        displayName: u.displayName,
        username: u.username,
        email: u.email,
        provider: u.provider,
        lastLoginAtMs: u.lastLoginAtMs,
        layout: u.layout,
        onboarded: true,
        upiId: u.upiId,
        schemaVersion: u.schemaVersion,
        profileWarning: u.profileWarning,
        isNewProfile: false,
      );
      _emit(AuthSignedIn(updated));
    }
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return;
    final status = _status;
    if (status is AuthSignedIn) {
      final u = status.user;
      final updated = AuthUser(
        id: u.id,
        displayName: trimmed,
        username: u.username,
        email: u.email,
        provider: u.provider,
        lastLoginAtMs: u.lastLoginAtMs,
        layout: u.layout,
        onboarded: u.onboarded,
        upiId: u.upiId,
        schemaVersion: u.schemaVersion,
        profileWarning: u.profileWarning,
        isNewProfile: u.isNewProfile,
      );
      _emit(AuthSignedIn(updated));
    }
  }

  void dispose() {
    _controller.close();
  }
}
