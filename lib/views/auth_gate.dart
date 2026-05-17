import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import 'home_shell.dart';
import 'login_page.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) => user == null ? const LoginPage() : const HomeShell(),
      loading: () =>
          const Scaffold(body: LoadingView(message: 'Memeriksa sesi...')),
      error: (error, _) => Scaffold(
        body: ErrorView(message: 'Gagal membaca sesi login: $error'),
      ),
    );
  }
}
