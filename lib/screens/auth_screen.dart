import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:gotrue/gotrue.dart' show OAuthProvider;

import '../services/sync_service.dart';
import '../providers/providers.dart';

const _webClientId = '322786377406-2t0grtvjjno3buc5q3dfabcksli8uk5d.apps.googleusercontent.com';
const _androidClientId = '322786377406-okt7iik40keo6tu7o5eqj5n450s9dn5k.apps.googleusercontent.com';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _State();
}

class _State extends ConsumerState<AuthScreen> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool loading = false;
  @override
  Widget build(BuildContext context) {
    if (!SyncService.enabled)
      return Scaffold(
        appBar: AppBar(title: const Text('Login')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Supabase belum dikonfigurasi. App jalan mode lokal. Tambahkan --dart-define SUPABASE_URL & SUPABASE_ANON saat build untuk sync multi-device.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    return Scaffold(
      appBar: AppBar(title: const Text('Login Kelola Harian')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: email,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pass,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (loading)
              const CircularProgressIndicator()
            else
              Column(
                children: [
                  FilledButton(
                    onPressed: () async {
                      setState(() => loading = true);
                      try {
                        await Supabase.instance.client.auth.signInWithPassword(
                          email: email.text,
                          password: pass.text,
                        );
                        await SyncService.onLogin();
                        if (mounted) {
                          ref.invalidate(authTickProvider);
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (mounted)
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('$e')));
                      }
                      setState(() => loading = false);
                    },
                    child: const Text('Login'),
                  ),
                  TextButton(
                    onPressed: () async {
                      setState(() => loading = true);
                      try {
                        await Supabase.instance.client.auth.signUp(
                          email: email.text,
                          password: pass.text,
                        );
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cek email verifikasi'),
                            ),
                          );
                      } catch (e) {
                        if (mounted)
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('$e')));
                      }
                      setState(() => loading = false);
                    },
                    child: const Text('Daftar'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('Login Google'),
                    onPressed: () async {
                      setState(() => loading = true);
                      try {
                        final gs = GoogleSignIn(
                          clientId: _androidClientId,
                          serverClientId: _webClientId,
                        );
                        final gUser = await gs.signIn();
                        if (gUser == null) {
                          setState(() => loading = false);
                          return;
                        }
                        final gAuth = await gUser.authentication;
                        await Supabase.instance.client.auth.signInWithIdToken(
                          provider: OAuthProvider.google,
                          idToken: gAuth.idToken!,
                          accessToken: gAuth.accessToken,
                        );
                        await SyncService.onLogin();
                        if (mounted) {
                          ref.invalidate(authTickProvider);
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (mounted)
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('$e')));
                      }
                      setState(() => loading = false);
                    },
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Lanjut Offline'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
