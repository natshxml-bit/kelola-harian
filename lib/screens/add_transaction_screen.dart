import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../services/db_service.dart';
import '../services/sync_service.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/savings_goal.dart';
import '../models/emergency_fund.dart';
import '../models/general_fund.dart';
import '../providers/providers.dart';
import '../theme.dart';

void showAddTransaction(BuildContext context, {TransactionModel? edit}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddTransactionSheet(edit: edit),
  );
}

const _newCategoryColors = <int>[
  0xFF2196F3, 0xFF4CAF50, 0xFFFF9800, 0xFF9C27B0, 0xFF00BCD4,
  0xFFFF5722, 0xFF8BC34A, 0xFF3F51B5, 0xFFE91E63, 0xFF795548,
];

class _AddTransactionSheet extends ConsumerStatefulWidget {
  final TransactionModel? edit;
  const _AddTransactionSheet({this.edit});
  @override
  ConsumerState<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<_AddTransactionSheet> {
  String tipe = 'pengeluaran';
  String? catId;
  late String catName;
  final nominalC = TextEditingController();
  final catatanC = TextEditingController();
  late DateTime tanggal;
  bool saving = false;
  bool get _editing => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      tipe = e.tipe;
      catId = e.categoryId;
      catName = e.categoryName;
      nominalC.text = e.nominal.toString();
      catatanC.text = e.catatan;
      tanggal = e.tanggal;
    } else {
      catName = '';
      tanggal = DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ap = context.ap;
    final catsAsync = ref.watch(categoriesProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: ap.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottom + 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: ap.line, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(_editing ? 'Edit Transaksi' : 'Transaksi Baru',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: ap.text)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: ap.fill, borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.all(4),
            child: Row(children: [
              _typeBtn('Pengeluaran', Icons.arrow_upward, 'pengeluaran', ap.expense),
              _typeBtn('Pemasukan', Icons.arrow_downward, 'pemasukan', ap.income),
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
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Kategori', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: ap.text)),
                  TextButton(
                    onPressed: () => _addCategory(cats),
                    style: TextButton.styleFrom(foregroundColor: kSeed, padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero),
                    child: const Text('+ Kategori Baru', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                ]),
                const SizedBox(height: 4),
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
                          color: selected ? Color(c.color).withValues(alpha: 0.15) : ap.fill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? Color(c.color) : ap.line,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Text(c.nama,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: selected ? Color(c.color) : ap.text,
                            )),
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
          Text('Nominal', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: ap.text)),
          const SizedBox(height: 8),
          TextField(
            controller: nominalC,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ap.text),
            decoration: InputDecoration(
              hintText: 'Rp 0',
              prefixText: 'Rp ',
              prefixStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ap.textMuted),
            ),
          ),
          const SizedBox(height: 16),
          Text('Catatan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: ap.text)),
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
              decoration: BoxDecoration(color: ap.fill, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                const Icon(Icons.calendar_today, size: 18, color: kSeed),
                const SizedBox(width: 10),
                Text('${tanggal.day}/${tanggal.month}/${tanggal.year}',
                    style: TextStyle(fontWeight: FontWeight.w600, color: ap.text)),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          if (_editing)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: saving ? null : _delete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ap.expense,
                  side: BorderSide(color: ap.expense),
                ),
                child: const Text('Hapus Transaksi', style: TextStyle(fontSize: 15)),
              ),
            ),
          if (_editing) const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: saving ? null : _save,
              child: saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_editing ? 'Simpan Perubahan' : 'Simpan Transaksi', style: const TextStyle(fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _addCategory(List<CategoryModel> cats) async {
    final uid = await ref.read(userIdProvider.future);
    final controller = TextEditingController();
    final color0 = _newCategoryColors[cats.length % _newCategoryColors.length];
    final nama = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kategori Baru', style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nama kategori'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
    if (nama == null || nama.isEmpty) return;
    final db = await DbService.isar;
    final cat = CategoryModel()
      ..userId = uid
      ..nama = nama
      ..icon = 'category'
      ..color = color0
      ..tipe = tipe
      ..isCustom = true;
    await db.writeTxn(() async => await db.categoryModels.put(cat));
    SyncService.syncSoon();
    ref.invalidate(categoriesProvider);
    setState(() { catId = cat.id.toString(); catName = cat.nama; });
  }

  Widget _typeBtn(String label, IconData icon, String value, Color color) {
    final selected = tipe == value;
    final ap = context.ap;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { tipe = value; catId = null; }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: selected ? Border.all(color: color, width: 2) : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: selected ? color : ap.textMuted),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: selected ? color : ap.textMuted)),
          ]),
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content: const Text('Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.ap.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => saving = true);
    final db = await DbService.isar;
    await db.writeTxn(() async {
      final t = widget.edit;
      if (t != null) await db.transactionModels.delete(t.id);
    });
SyncService.syncSoon();
      _invalidate();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaksi dihapus')));
      }
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
    final old = widget.edit;
    await db.writeTxn(() async {
      final tx = old ?? TransactionModel();
      if (old == null) tx.userId = uid;
      tx.categoryId = catId!;
      tx.categoryName = catName;
      tx.tipe = tipe;
      tx.nominal = nominal;
      tx.tanggal = tanggal;
      tx.catatan = catatanC.text;
      if (old == null) tx.createdAt = DateTime.now();
      await db.transactionModels.put(tx);
      if (tipe == 'pemasukan' && nominal > 0) {
        final goals = await db.savingsGoals.filter().userIdEqualTo(uid).findAll();
        for (var g in goals.where((e) => e.autoPercent > 0)) {
          final add = nominal * g.autoPercent ~/ 100;
          g.terkumpul += old?.tipe == 'pemasukan' ? add - old!.nominal * g.autoPercent ~/ 100 : add;
          if (g.terkumpul < 0) g.terkumpul = 0;
          await db.savingsGoals.put(g);
        }
        final ef = await db.emergencyFunds.filter().userIdEqualTo(uid).findFirst();
        if (ef != null && ef.autoPercent > 0) {
          final add = nominal * ef.autoPercent ~/ 100;
          ef.terkumpul += old?.tipe == 'pemasukan' ? add - old!.nominal * ef.autoPercent ~/ 100 : add;
          if (ef.terkumpul < 0) ef.terkumpul = 0;
          await db.emergencyFunds.put(ef);
        }
        final gf = await db.generalFunds.filter().userIdEqualTo(uid).findFirst();
        if (gf != null && gf.autoPercent > 0) {
          final add = nominal * gf.autoPercent ~/ 100;
          gf.saldo += old?.tipe == 'pemasukan' ? add - old!.nominal * gf.autoPercent ~/ 100 : add;
          if (gf.saldo < 0) gf.saldo = 0;
          await db.generalFunds.put(gf);
        }
      }
    });
    SyncService.syncSoon();
    _invalidate();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editing ? 'Perubahan disimpan!' : 'Berhasil disimpan!'),
          backgroundColor: context.ap.income,
        ),
      );
    }
  }

  void _invalidate() {
    ref.invalidate(transactionsProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(savingsProvider);
    ref.invalidate(emergencyProvider);
  }
}