import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../utils/currency.dart';
import 'add_transaction_screen.dart';
import 'analysis_screen.dart';
import 'savings_screen.dart';
import 'emergency_screen.dart';
import 'category_screen.dart';
import 'main_shell.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    final txs = ref.watch(transactionsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(dashboardProvider),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: dash.when(
                data: (d) => _SaldoCard(d: d),
                loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
                error: (e, s) => Text('Error $e'),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverToBoxAdapter(
              child: dash.when(
                data: (d) => Row(children: [
                  Expanded(child: _StatCard(label: 'Hari Ini', income: d['todayIn']!, expense: d['todayOut']!, icon: Icons.today, color: const Color(0xFF57758A))),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(label: 'Bulan Ini', income: d['monthIn']!, expense: d['monthOut']!, icon: Icons.calendar_month, color: const Color(0xFF3E3B49))),
                ]),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Row(children: [
                _QuickAction(
                  icon: Icons.savings,
                  label: 'Tabung',
                  color: const Color(0xFF4CAF50),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PushScreen(title: 'Tabung Goal', child: SavingsScreen()))),
                ),
                const SizedBox(width: 12),
                _QuickAction(
                  icon: Icons.health_and_safety,
                  label: 'Darurat',
                  color: const Color(0xFFCC5C64),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PushScreen(title: 'Dana Darurat', child: EmergencyScreen()))),
                ),
                const SizedBox(width: 12),
                _QuickAction(
                  icon: Icons.category,
                  label: 'Kategori',
                  color: const Color(0xFFFF9800),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryScreen())),
                ),
                const SizedBox(width: 12),
                _QuickAction(
                  icon: Icons.analytics,
                  label: 'Analisis',
                  color: const Color(0xFF2196F3),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PushScreen(title: 'Analisis', child: AnalysisScreen()))),
                ),
              ]),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text('Transaksi Terbaru', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF3E3B49))),
            ),
          ),
          txs.when(
            data: (list) {
              if (list.isEmpty) {
                return const SliverPadding(
                  padding: EdgeInsets.all(32),
                  sliver: SliverToBoxAdapter(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Column(children: [
                          Icon(Icons.receipt_long, size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('Belum ada transaksi', style: TextStyle(color: Colors.grey, fontSize: 14)),
                          SizedBox(height: 4),
                          Text('Tap + untuk mulai catat', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ])),
                      ),
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final t = list[i];
                      final isIn = t.tipe == 'pemasukan';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: (isIn ? const Color(0xFF4CAF50) : const Color(0xFFCC5C64)).withValues(alpha: 0.15),
                              child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, color: isIn ? const Color(0xFF4CAF50) : const Color(0xFFCC5C64), size: 18),
                            ),
                            title: Text(t.categoryName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(
                              '${t.tanggal.day}/${t.tanggal.month}/${t.tanggal.year}${t.catatan.isNotEmpty ? ' • ${t.catatan}' : ''}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                            trailing: Text(
                              '${isIn ? '+' : '-'}${fmt(t.nominal)}',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isIn ? const Color(0xFF4CAF50) : const Color(0xFFCC5C64)),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: list.length > 15 ? 15 : list.length,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
            error: (e, s) => SliverToBoxAdapter(child: Text('$e')),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }
}

class _SaldoCard extends StatelessWidget {
  final Map<String, int> d;
  const _SaldoCard({required this.d});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF57758A), Color(0xFF3E3B49)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF57758A).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Total Saldo', style: TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 4),
        Text(fmt(d['saldo']!), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28)),
        const SizedBox(height: 16),
        Row(children: [
          _ChipMini(icon: Icons.arrow_downward, label: 'Masuk', val: fmt(d['totalIn']!), color: const Color(0xFF81C784)),
          const SizedBox(width: 12),
          _ChipMini(icon: Icons.arrow_upward, label: 'Keluar', val: fmt(d['totalOut']!), color: const Color(0xFFEF9A9A)),
        ]),
      ]),
    );
  }
}

class _ChipMini extends StatelessWidget {
  final IconData icon;
  final String label, val;
  final Color color;
  const _ChipMini({required this.icon, required this.label, required this.val, required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
            Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12), overflow: TextOverflow.ellipsis),
          ])),
        ]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int income, expense;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.income, required this.expense, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: color)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.arrow_downward, size: 12, color: Colors.green.shade600),
            const SizedBox(width: 4),
            Text(fmt(income), style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.arrow_upward, size: 12, color: Colors.red.shade400),
            const SizedBox(width: 4),
            Text(fmt(expense), style: TextStyle(fontSize: 12, color: Colors.red.shade400, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}
