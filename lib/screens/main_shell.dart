import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_screen.dart';
import 'analysis_screen.dart';
import 'savings_screen.dart';
import 'emergency_screen.dart';
import 'add_transaction_screen.dart';
import '../services/sync_service.dart';
import '../providers/providers.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class PushScreen extends StatelessWidget {
  final String title;
  final Widget child;
  const PushScreen({super.key, required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: () => Navigator.pop(context))),
      body: child,
    );
  }
}

class _MainShellState extends ConsumerState<MainShell> {
  int _idx = 0;
  final _pages = const [
    DashboardScreen(),
    AnalysisScreen(),
    SavingsScreen(),
    EmergencyScreen(),
  ];
  final _titles = const ['Kelola Harian', 'Analisis', 'Tabung Goal', 'Dana Darurat'];

  Future<void> _doSync() async {
    if (!SyncService.loggedIn) {
      await Navigator.pushNamed(context, '/auth');
      if (mounted) setState(() {});
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Menyinkronkan data…')),
    );
    await SyncService.syncNow();
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selesai disinkronkan')),
      );
  }

  Future<void> _openAccount(BuildContext context) async {
    if (!SyncService.loggedIn) {
      await Navigator.pushNamed(context, '/auth');
      if (mounted) setState(() {});
      return;
    }
    final email = Supabase.instance.client.auth.currentUser?.email;
    final keluar = await showModalBottomSheet<bool>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: Text(email ?? 'Akun'),
              subtitle: const Text('Tersinkron via Supabase'),
            ),
            ListTile(
              leading: Icon(Icons.logout, color: Theme.of(c).colorScheme.error),
              title: Text('Keluar', style: TextStyle(color: Theme.of(c).colorScheme.error)),
              onTap: () => Navigator.pop(c, true),
            ),
          ],
        ),
      ),
    );
    if (keluar == true && mounted) {
      await SyncService.signOut();
      if (mounted) {
        ref.invalidate(authTickProvider);
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sudah keluar. Data tetap tersimpan di HP ini.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_idx]),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _doSync,
            tooltip: 'Sinkronkan sekarang',
          ),
          Builder(
            builder: (context) {
              final email = SyncService.loggedIn
                  ? Supabase.instance.client.auth.currentUser?.email
                  : null;
              return IconButton(
                icon: Icon(
                  email == null
                      ? Icons.account_circle_outlined
                      : Icons.account_circle,
                ),
                tooltip: email == null ? 'Login / Sinkronkan' : email,
                onPressed: () => _openAccount(context),
              );
            },
          ),
        ],
      ),
      body: _pages[_idx],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddTransaction(context),
        backgroundColor: const Color(0xFF57758A),
        foregroundColor: Colors.white,
        heroTag: 'add_transaction',
        icon: const Icon(Icons.add),
        label: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Analisis'),
          NavigationDestination(icon: Icon(Icons.savings_outlined), selectedIcon: Icon(Icons.savings), label: 'Tabung'),
          NavigationDestination(icon: Icon(Icons.health_and_safety_outlined), selectedIcon: Icon(Icons.health_and_safety), label: 'Darurat'),
        ],
      ),
    );
  }
}
