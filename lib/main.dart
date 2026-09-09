import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'pages/login_page.dart';
import 'pages/shell_page.dart';
import 'services/supabase_repository.dart';
import 'services/wesley_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.isSupabaseConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );

  final WesleyRepository repository =
      SupabaseWesleyRepository(Supabase.instance.client);
  runApp(WesleyHallApp(repository: repository));
}

class WesleyHallApp extends StatelessWidget {
  const WesleyHallApp({super.key, required this.repository});

  final WesleyRepository repository;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E5D45),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'Wesley Hall',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF5F7F6),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
        cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
      ),
      home: AuthGate(repository: repository),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.repository});
  final WesleyRepository repository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) return const LoginPage();
        return ShellPage(repository: repository);
      },
    );
  }
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Wesley Hall Supabase configuration is missing.'),
        ),
      ),
    );
  }
}
