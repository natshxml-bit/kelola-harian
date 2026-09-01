import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../utils/currency.dart';
import 'add_transaction_screen.dart';
import 'analysis_screen.dart';
import 'savings_screen.dart';
import 'emergency_screen.dart';
import 'category_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    final txs = ref.watch(transactionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Harian'), actions: [
        IconButton(icon: const Icon(Icons.category), onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> const CategoryScreen()))),
        IconButton(icon: const Icon(Icons.analytics), onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> const AnalysisScreen()))),
      ]),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardProvider),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            dash.when(
              data: (d)=> Column(children: [
                _card('Saldo', fmt(d['saldo']!), Colors.indigo, Icons.account_balance_wallet),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _card('Masuk Hari Ini', fmt(d['todayIn']!), Colors.green, Icons.arrow_downward)),
                  const SizedBox(width: 12),
                  Expanded(child: _card('Keluar Hari Ini', fmt(d['todayOut']!), Colors.red, Icons.arrow_upward)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _card('Masuk Bulan Ini', fmt(d['monthIn']!), Colors.teal, Icons.calendar_month)),
                  const SizedBox(width: 12),
                  Expanded(child: _card('Keluar Bulan Ini', fmt(d['monthOut']!), Colors.orange, Icons.trending_down)),
                ]),
              ]),
              loading: ()=> const LinearProgressIndicator(),
              error: (e,s)=> Text('Error $e'),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.savings), label: const Text('Tabung'), onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> const SavingsScreen())))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.health_and_safety), label: const Text('Darurat'), onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> const EmergencyScreen())))),
            ]),
            const SizedBox(height: 16),
            const Text('Transaksi Terbaru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            txs.when(
              data: (list){
                if (list.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('Belum ada transaksi'))); 
                return Column(children: list.take(10).map((t)=> Card(child: ListTile(
                  leading: CircleAvatar(backgroundColor: t.tipe=='pemasukan'?Colors.green:Colors.red, child: Icon(t.tipe=='pemasukan'?Icons.add:Icons.remove, color: Colors.white)),
                  title: Text('${t.categoryName} • ${fmt(t.nominal)}'),
                  subtitle: Text('${t.tanggal.day}/${t.tanggal.month}/${t.tanggal.year} ${t.catatan}'),
                ))).toList());
              },
              loading: ()=> const CircularProgressIndicator(),
              error: (e,s)=> Text('$e'),
            )
          ]),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_)=> const AddTransactionScreen()));
          ref.invalidate(transactionsProvider);
          ref.invalidate(dashboardProvider);
        },
        label: const Text('Tambah'),
        icon: const Icon(Icons.add),
      ),
    );
  }
  Widget _card(String title, String val, Color c, IconData icon){
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ]))
      ]),
    );
  }
}
