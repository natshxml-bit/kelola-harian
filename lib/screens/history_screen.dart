import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../utils/currency.dart';
import '../models/transaction.dart';
import '../theme.dart';
import 'add_transaction_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(transactionsProvider);
    return txsAsync.when(
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Card(
              margin: const EdgeInsets.all(32),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(children: [
                    Icon(Icons.receipt_long, size: 48, color: context.ap.textMuted),
                    const SizedBox(height: 12),
                    Text('Belum ada transaksi', style: TextStyle(color: context.ap.textMuted, fontSize: 14)),
                  ]),
                ),
              ),
            ),
          );
        }
        final groups = _groupByDay(list);
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: groups.length,
          itemBuilder: (ctx, i) => _DayGroup(group: groups[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('$e')),
    );
  }

  List<({DateTime day, List<TransactionModel> items})> _groupByDay(List<TransactionModel> list) {
    final map = <DateTime, List<TransactionModel>>{};
    for (final t in list) {
      final day = DateTime(t.tanggal.year, t.tanggal.month, t.tanggal.day);
      map.putIfAbsent(day, () => []).add(t);
    }
    final days = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final d in days) (day: d, items: map[d]!)];
  }
}

class _DayGroup extends StatelessWidget {
  final ({DateTime day, List<TransactionModel> items}) group;
  const _DayGroup({required this.group});

  @override
  Widget build(BuildContext context) {
    final ap = context.ap;
    final items = group.items;
    int masuk = 0, keluar = 0;
    for (final t in items) {
      if (t.tipe == 'pemasukan') masuk += t.nominal;
      else keluar += t.nominal;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmtDay(group.day),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: ap.text),
              ),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (masuk > 0) ...[
                  Icon(Icons.arrow_downward, size: 12, color: ap.income),
                  Text(fmt(masuk), style: TextStyle(fontSize: 11, color: ap.income, fontWeight: FontWeight.w600)),
                ],
                if (masuk > 0 && keluar > 0) const SizedBox(width: 8),
                if (keluar > 0) ...[
                  Icon(Icons.arrow_upward, size: 12, color: ap.expense),
                  Text(fmt(keluar), style: TextStyle(fontSize: 11, color: ap.expense, fontWeight: FontWeight.w600)),
                ],
              ]),
            ],
          ),
          const SizedBox(height: 8),
          for (final t in items) _txTile(t),
        ],
      ),
    );
  }

  String _fmtDay(DateTime d) {
    const hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const bulan = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return '${hari[d.weekday - 1]}, ${d.day} ${bulan[d.month - 1]} ${d.year}';
  }
}

class _txTile extends StatelessWidget {
  final TransactionModel t;
  const _txTile(this.t);

  @override
  Widget build(BuildContext context) {
    final ap = context.ap;
    final isIn = t.tipe == 'pemasukan';
    final c = isIn ? ap.income : ap.expense;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          onTap: () => showAddTransaction(context, edit: t),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: c.withValues(alpha: 0.15),
            child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, color: c, size: 18),
          ),
          title: Text(t.categoryName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: t.catatan.isNotEmpty
              ? Text(t.catatan, style: TextStyle(color: ap.textMuted, fontSize: 12))
              : null,
          trailing: Text(
            '${isIn ? '+' : '-'}${fmt(t.nominal)}',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: c),
          ),
        ),
      ),
    );
  }
}
