import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController(text: 'Admin');
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  String _emailForUsername(String username) {
    final normalized = username.trim().toLowerCase();
    if (normalized == 'admin') return 'admin@wesleyhall.local';
    if (normalized.contains('@')) return normalized;
    return '$normalized@wesleyhall.local';
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailForUsername(_username.text),
        password: _password.text,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthException('Unable to sign in.');
      }

      final staff = await Supabase.instance.client
          .from('wesley_staff_users')
          .select('role, active')
          .eq('user_id', user.id)
          .maybeSingle();

      if (staff == null || staff['active'] != true) {
        await Supabase.instance.client.auth.signOut();
        throw const AuthException('This account is not authorized for Wesley Hall.');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to sign in.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 420,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.church_outlined,
                      size: 48, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 14),
                  Text('WESLEY HALL',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('GMCT Hall Booking & Planning',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _username,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      hintText: 'Admin',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    onSubmitted: (_) => _signIn(),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _busy ? null : _signIn,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.login),
                    label: const Text('Sign In'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
