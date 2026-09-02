import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'analysis_screen.dart';
import 'savings_screen.dart';
import 'emergency_screen.dart';
import 'add_transaction_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
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

class _MainShellState extends State<MainShell> {
  int _idx = 0;
  final _pages = const [
    DashboardScreen(),
    AnalysisScreen(),
    SavingsScreen(),
    EmergencyScreen(),
  ];
  final _titles = const ['Kelola Harian', 'Analisis', 'Tabung Goal', 'Dana Darurat'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_idx]),
        actions: [
          if (_idx == 0)
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: () {},
              tooltip: 'Sync',
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
