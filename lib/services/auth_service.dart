import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  Stream<User?> authStateChanges() async* {
    yield _client.auth.currentUser;
    yield* _client.auth.onAuthStateChange.map((state) => state.session?.user);
  }

  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> register({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(email: email.trim(), password: password);
  }

  Future<void> logout() => _client.auth.signOut();
}
