import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  final sb.SupabaseClient _client;
  final StreamController<AuthStatus> _controller =
      StreamController<AuthStatus>.broadcast();
  late final StreamSubscription<sb.AuthState> _sub;

  @visibleForTesting
  final Future<Map<String, dynamic>?> Function(String uid)? fetchProfileOverride;
  @visibleForTesting
  final Future<void> Function(Map<String, dynamic> row)? insertProfileOverride;
  @visibleForTesting
  final Future<void> Function(String uid, int lastLoginAtMs)? updateLoginOverride;

  AuthStatus _status = const AuthLoading();
  String _pendingLayout = 'web';

  String? _inFlightUserId;
  Future<void>? _inFlightSession;
  Completer<void>? _sessionCompleter;
  String? _sessionCompleterUserId;

  SupabaseAuthRepository(
    this._client, {
    @visibleForTesting Stream<sb.AuthState>? authStateStreamOverride,
    @visibleForTesting this.fetchProfileOverride,
    @visibleForTesting this.insertProfileOverride,
    @visibleForTesting this.updateLoginOverride,
  }) {
    final initialSession = _client.auth.currentSession;
    if (initialSession != null) {
      _processSession(initialSession, updateLogin: false).catchError((_) {});
    } else {
      _status = const AuthSignedOut();
    }
    final stream = authStateStreamOverride ?? _client.auth.onAuthStateChange;
    _sub = stream.listen((data) {
      final session = data.session;
      print('[AUTH] onAuthStateChange event=${data.event.name} session=${session != null}');
      if (session == null) {
        if (_status is! AuthConfirmationPending) {
          _emit(const AuthSignedOut());
        }
      } else {
        _processSession(
          session,
          updateLogin: data.event == sb.AuthChangeEvent.signedIn,
        ).catchError((_) {});
      }
    });
  }

  @override
  Stream<AuthStatus> get authStateChanges => _controller.stream;

  @override
  AuthStatus get currentStatus => _status;

  void _emit(AuthStatus next) {
    print('[AUTH] _emit -> $next');
    _status = next;
    _controller.add(next);
  }

  @visibleForTesting
  Future<void> processSessionForTest(
    sb.Session session, {
    bool updateLogin = false,
  }) =>
      _processSession(session, updateLogin: updateLogin);

  Future<void> _processSession(
    sb.Session session, {
    required bool updateLogin,
  }) {
    if (_inFlightSession != null && _inFlightUserId == session.user.id) {
      return _inFlightSession!;
    }
    if (!updateLogin &&
        _status is AuthSignedIn &&
        (_status as AuthSignedIn).user.id == session.user.id) {
      return Future.value();
    }
    _inFlightUserId = session.user.id;
    final completer = Completer<void>();
    _sessionCompleter = completer;
    _sessionCompleterUserId = session.user.id;
    final future = _handleSession(session, updateLogin: updateLogin).whenComplete(() {
      if (!completer.isCompleted) {
        completer.complete();
      }
      if (_inFlightUserId == session.user.id) {
        _inFlightUserId = null;
        _inFlightSession = null;
      }
    });
    _inFlightSession = future;
    return future;
  }

  /// Waits for the authoritative `onAuthStateChange` listener to finish
  /// processing [session], without calling `_handleSession` manually.
  Future<void> _awaitSessionProcessed(sb.Session session) async {
    if (_status is AuthSignedIn &&
        (_status as AuthSignedIn).user.id == session.user.id &&
        _inFlightSession == null) {
      return;
    }
    if (_inFlightSession != null && _inFlightUserId == session.user.id) {
      await _inFlightSession;
      return;
    }
    if (_sessionCompleter != null &&
        _sessionCompleterUserId == session.user.id &&
        !_sessionCompleter!.isCompleted) {
      await _sessionCompleter!.future;
      return;
    }
    // Fallback only if the auth-state listener has not emitted yet.
    await Future<void>.delayed(Duration.zero);
    if (_inFlightSession != null && _inFlightUserId == session.user.id) {
      await _inFlightSession;
      return;
    }
    if (!(_status is AuthSignedIn &&
        (_status as AuthSignedIn).user.id == session.user.id)) {
      await _processSession(session, updateLogin: true);
    }
  }

  Future<void> _handleSession(
    sb.Session session, {
    required bool updateLogin,
  }) async {
    final sbUser = session.user;
    final isUsername = UsernameHelper.isSyntheticEmail(sbUser.email);
    final providerStr = sbUser.appMetadata['provider'] as String?;
    final AuthProviderKind provider;
    if (isUsername) {
      provider = AuthProviderKind.passwordUsername;
    } else if (providerStr == 'google') {
      provider = AuthProviderKind.google;
    } else {
      provider = AuthProviderKind.passwordEmail;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final metaName =
        (sbUser.userMetadata?['display_name'] as String?) ??
        (sbUser.userMetadata?['full_name'] as String?) ??
        (sbUser.userMetadata?['name'] as String?);
    final username = isUsername ? sbUser.email!.split('@').first : null;
    final realEmail = isUsername ? null : sbUser.email;
    final fallbackName = username ??
        (realEmail != null ? realEmail.split('@').first : 'Settliv User');
    final fallbackDisplayName =
        (metaName != null && metaName.trim().isNotEmpty)
            ? metaName.trim()
            : fallbackName;
    final fallbackLayout =
        ((sbUser.userMetadata?['layout'] as String?) ?? _pendingLayout) == 'app'
            ? 'app'
            : 'web';

    try {
      final existing = fetchProfileOverride != null
          ? await fetchProfileOverride!(sbUser.id)
          : await _client
              .from('profiles')
              .select()
              .eq('id', sbUser.id)
              .maybeSingle();

      if (existing == null) {
        final row = <String, dynamic>{
          'id': sbUser.id,
          'display_name': fallbackDisplayName,
          'username': username,
          'email': realEmail,
          'provider': provider.dbValue,
          'last_login_at_ms': nowMs,
          'layout': fallbackLayout,
          'onboarded': false,
          'schema_version': 1,
        };
        if (insertProfileOverride != null) {
          await insertProfileOverride!(row);
        } else {
          await _client.from('profiles').upsert(row, onConflict: 'id');
        }
        _emit(
          AuthSignedIn(
            AuthUser(
              id: sbUser.id,
              displayName: fallbackDisplayName,
              username: username,
              email: realEmail,
              provider: provider,
              lastLoginAtMs: nowMs,
              layout: fallbackLayout,
              isNewProfile: true,
            ),
          ),
        );
      } else {
        if (updateLogin) {
          if (updateLoginOverride != null) {
            await updateLoginOverride!(sbUser.id, nowMs);
          } else {
            await _client
                .from('profiles')
                .update({'last_login_at_ms': nowMs}).eq('id', sbUser.id);
          }
        }
        _emit(
          AuthSignedIn(
            AuthUser(
              id: sbUser.id,
              displayName:
                  (existing['display_name'] as String?) ?? fallbackDisplayName,
              username: existing['username'] as String? ?? username,
              email: isUsername
                  ? null
                  : (existing['email'] as String? ?? realEmail),
              provider:
                  AuthProviderKind.fromDb(existing['provider'] as String?),
              lastLoginAtMs:
                  updateLogin ? nowMs : (existing['last_login_at_ms'] as int? ?? nowMs),
              layout: (existing['layout'] as String?) ?? fallbackLayout,
              onboarded: (existing['onboarded'] as bool?) ?? false,
              upiId: existing['upi_id'] as String?,
              schemaVersion: (existing['schema_version'] as int?) ?? 1,
            ),
          ),
        );
      }
    } catch (e, st) {
      final code = e is sb.PostgrestException ? (e.code ?? 'db') : 'sync';
      if (kDebugMode) {
        debugPrint('SupabaseAuthRepository profile sync failed ($code): $e\n$st');
      }
      // Never turn a valid Supabase session into AuthSignedOut when profile sync fails.
      _emit(
        AuthSignedIn(
          AuthUser(
            id: sbUser.id,
            displayName: fallbackDisplayName,
            username: username,
            email: realEmail,
            provider: provider,
            lastLoginAtMs: nowMs,
            layout: fallbackLayout,
            profileWarning: 'profile_sync $code',
          ),
        ),
      );
    }
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
    _pendingLayout = layout;
    final norm = UsernameHelper.normalize(username);
    try {
      final res = await _client.functions.invoke(
        'account-actions',
        body: {
          'action': 'create_username_account',
          'username': norm,
          'password': password,
          'full_name': fullName.trim(),
          'layout': layout,
        },
      );
      final data = res.data;
      if (res.status == 409 ||
          (data is Map && data['error'] == 'username_taken')) {
        throw const AuthFriendlyException('That username is taken');
      }
      if (res.status >= 400) {
        throw AuthFriendlyException(
          (data is Map && data['message'] is String)
              ? data['message'] as String
              : 'Could not create account. Please try again.',
        );
      }
      final authRes = await _client.auth.signInWithPassword(
        email: UsernameHelper.toSyntheticEmail(norm),
        password: password,
      );
      if (authRes.session != null) {
        await _awaitSessionProcessed(authRes.session!);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('SupabaseAuthRepository.signUpWithUsername error: $e\n$st');
      }
      final mapped = AuthErrorMapper.map(e, isUsernameFlow: true);
      if (mapped != null) throw AuthFriendlyException(mapped);
      throw const AuthFriendlyException('Could not create account. Please try again.');
    }
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
    _pendingLayout = layout;
    final normEmail = email.trim().toLowerCase();
    try {
      final res = await _client.auth.signUp(
        email: normEmail,
        password: password,
        data: {
          'display_name': fullName.trim(),
          'layout': layout,
        },
      );
      if (res.session == null) {
        _emit(
          AuthConfirmationPending(
            email: normEmail,
            message:
                'Check $normEmail to confirm your account before signing in.',
          ),
        );
      }
    } catch (e) {
      final mapped = AuthErrorMapper.map(e);
      if (mapped != null) throw AuthFriendlyException(mapped);
    }
  }

  @override
  Future<void> signInWithUsername({
    required String username,
    required String password,
  }) async {
    final norm = UsernameHelper.normalize(username);
    try {
      final authRes = await _client.auth.signInWithPassword(
        email: UsernameHelper.toSyntheticEmail(norm),
        password: password,
      );
      if (authRes.session != null) {
        await _awaitSessionProcessed(authRes.session!);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('SupabaseAuthRepository.signUpWithUsername error: $e\n$st');
      }
      final mapped = AuthErrorMapper.map(e, isUsernameFlow: true);
      if (mapped != null) throw AuthFriendlyException(mapped);
      throw const AuthFriendlyException('Could not create account. Please try again.');
    }
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final authRes = await _client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      if (authRes.session != null) {
        await _awaitSessionProcessed(authRes.session!);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('SupabaseAuthRepository.signInWithEmail error: $e\n$st');
      }
      final mapped = AuthErrorMapper.map(e);
      if (mapped != null) throw AuthFriendlyException(mapped);
      throw const AuthFriendlyException('Could not sign in. Please try again.');
    }
  }

  @override
  Future<void> signInWithGoogle({required String layout}) async {
    _pendingLayout = layout;
    try {
      await _client.auth.signInWithOAuth(
        sb.OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : null,
      );
    } catch (e) {
      final mapped = AuthErrorMapper.map(e);
      if (mapped != null) throw AuthFriendlyException(mapped);
    }
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: kIsWeb ? '${Uri.base.origin}/signin' : null,
      );
    } catch (e) {
      final mapped = AuthErrorMapper.map(e);
      if (mapped != null) throw AuthFriendlyException(mapped);
    }
  }

  @override
  Future<void> signOut() async {
    print('[AUTH] SupabaseAuthRepository.signOut called');
    try {
      await _client.auth.signOut();
    } catch (e, st) {
      print('[AUTH] SupabaseAuthRepository.signOut error: $e\n$st');
    } finally {
      _emit(const AuthSignedOut());
    }
  }

  @override
  Future<void> deleteAccount({String? password}) async {
    print('[AUTH] SupabaseAuthRepository.deleteAccount called');
    final current = _client.auth.currentUser;
    if (current == null) {
      throw const AuthFriendlyException('You are not signed in.');
    }
    try {
      if (password != null && current.email != null) {
        await _client.auth.signInWithPassword(
          email: current.email!,
          password: password,
        );
      }
      final res = await _client.functions.invoke(
        'account-actions',
        body: {'action': 'delete_account'},
      );
      if (res.status >= 400) {
        throw const AuthFriendlyException(
          'Could not delete account. Please try again.',
        );
      }
      try {
        await _client.auth.signOut();
      } catch (e, st) {
        print('[AUTH] post-delete signOut error: $e\n$st');
      }
      _emit(const AuthSignedOut());
    } catch (e, st) {
      print('[AUTH] SupabaseAuthRepository.deleteAccount error: $e\n$st');
      final mapped = AuthErrorMapper.map(e);
      if (mapped != null) throw AuthFriendlyException(mapped);
      throw const AuthFriendlyException('Could not delete account. Please try again.');
    }
  }

  @override
  Future<void> markOnboarded() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _client.from('profiles').update({'onboarded': true}).eq('id', uid);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('SupabaseAuthRepository.markOnboarded error: $e\n$st');
      }
    }
  }

  void dispose() {
    _sub.cancel();
    _controller.close();
  }
}
