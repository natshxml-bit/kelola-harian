import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../services/db_service.dart';
import '../services/sync_service.dart';
import '../models/transaction.dart';
import '../models/savings_goal.dart';
import '../models/emergency_fund.dart';
import '../providers/providers.dart';

void showAddTransaction(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AddTransactionSheet(),
  );
}

class _AddTransactionSheet extends ConsumerStatefulWidget {
  const _AddTransactionSheet();
  @override
  ConsumerState<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<_AddTransactionSheet> {
  String tipe = 'pengeluaran';
  String? catId;
  String catName = '';
  final nominalC = TextEditingController();
  final catatanC = TextEditingController();
  DateTime tanggal = DateTime.now();
  bool saving = false;

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(categoriesProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottom + 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Transaksi Baru', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: Color(0xFF3E3B49))),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.all(4),
            child: Row(children: [
              _typeBtn('Pengeluaran', Icons.arrow_upward, 'pengeluaran', const Color(0xFFCC5C64)),
              _typeBtn('Pemasukan', Icons.arrow_downward, 'pemasukan', const Color(0xFF4CAF50)),
            ]),
          ),
          const SizedBox(height: 16),
          catsAsync.when(
            data: (cats) {
              final filtered = cats.where((c) => c.tipe == tipe).toList();
              if (catId == null && filtered.isNotEmpty) {
                catId = filtered.first.id.toString();
                catName = filtered.first.nama;
              }
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Kategori', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF3E3B49))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: filtered.map((c) {
                    final selected = catId == c.id.toString();
                    return GestureDetector(
                      onTap: () => setState(() { catId = c.id.toString(); catName = c.nama; }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? Color(c.color).withValues(alpha: 0.15) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selected ? Color(c.color) : Colors.grey.shade300, width: selected ? 2 : 1),
                        ),
                        child: Text(c.nama, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: selected ? Color(c.color) : const Color(0xFF3E3B49))),
                      ),
                    );
                  }).toList(),
                ),
              ]);
            },
            loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator())),
            error: (e, s) => Text('$e'),
          ),
          const SizedBox(height: 16),
          const Text('Nominal', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF3E3B49))),
          const SizedBox(height: 8),
          TextField(
            controller: nominalC,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: 'Rp 0',
              prefixText: 'Rp ',
              prefixStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.grey.shade500),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Catatan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF3E3B49))),
          const SizedBox(height: 8),
          TextField(controller: catatanC, decoration: const InputDecoration(hintText: 'Opsional')),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2030), initialDate: tanggal);
              if (d != null) setState(() => tanggal = d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                const Icon(Icons.calendar_today, size: 18, color: Color(0xFF57758A)),
                const SizedBox(width: 10),
                Text('${tanggal.day}/${tanggal.month}/${tanggal.year}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: saving ? null : _save,
              child: saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Simpan Transaksi', style: TextStyle(fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _typeBtn(String label, IconData icon, String value, Color color) {
    final selected = tipe == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { tipe = value; catId = null; }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: selected ? Border.all(color: color, width: 2) : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: selected ? color : Colors.grey),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: selected ? color : Colors.grey)),
          ]),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (catId == null || nominalC.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih kategori & nominal')));
      return;
    }
    setState(() => saving = true);
    final uid = await ref.read(userIdProvider.future);
    final db = await DbService.isar;
    final nominal = int.tryParse(nominalC.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    await db.writeTxn(() async {
      await db.transactionModels.put(TransactionModel()
        ..userId = uid
        ..categoryId = catId!
        ..categoryName = catName
        ..tipe = tipe
        ..nominal = nominal
        ..tanggal = tanggal
        ..catatan = catatanC.text
        ..createdAt = DateTime.now());
      if (tipe == 'pemasukan' && nominal > 0) {
        final goals = await db.savingsGoals.filter().userIdEqualTo(uid).findAll();
        for (var g in goals.where((e) => e.autoPercent > 0)) {
          g.terkumpul += nominal * g.autoPercent ~/ 100;
          await db.savingsGoals.put(g);
        }
        final ef = await db.emergencyFunds.filter().userIdEqualTo(uid).findFirst();
        if (ef != null && ef.autoPercent > 0) {
          ef.terkumpul += nominal * ef.autoPercent ~/ 100;
          await db.emergencyFunds.put(ef);
        }
      }
    });
    ref.invalidate(transactionsProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(savingsProvider);
    ref.invalidate(emergencyProvider);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berhasil disimpan!'),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}
