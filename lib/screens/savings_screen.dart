import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../services/db_service.dart';
import '../services/sync_service.dart';
import '../providers/providers.dart';
import '../models/savings_goal.dart';
import '../models/general_fund.dart';
import '../utils/currency.dart';
import '../theme.dart';

class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(savingsProvider);
    final fundAsync = ref.watch(generalFundProvider);
    final dashAsync = ref.watch(dashboardProvider);
    final monthIn = dashAsync.valueOrNull?['monthIn'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        fundAsync.when(
          data: (f) => _FundCard(f: f),
          loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator())),
          error: (e, s) => Text('$e'),
        ),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Tabungan Goal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: context.ap.text)),
          FilledButton.icon(
            onPressed: () => _addGoal(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Buat Goal'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
          ),
        ]),
        const SizedBox(height: 12),
        goals.when(
          data: (list) {
            if (list.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    Icon(Icons.mode_standby, size: 40, color: context.ap.textMuted),
                    const SizedBox(height: 10),
                    Text('Belum ada goal', style: TextStyle(color: context.ap.textMuted, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Buat rencana seperti "Motor" atau "Laptop"', style: TextStyle(color: context.ap.textMuted, fontSize: 12)),
                  ]),
                ),
              );
            }
            return Column(
              children: [
                for (var g in list) _GoalCard(g: g, monthIn: monthIn),
              ],
            );
          },
          loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
          error: (e, s) => Text('$e'),
        ),
      ],
    );
  }

  void _addGoal(BuildContext ctx, WidgetRef ref) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _GoalSheet(),
    );
  }
}

class _FundCard extends ConsumerWidget {
  final GeneralFund? f;
  const _FundCard({required this.f});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ap = context.ap;
    final f = this.f;
    if (f == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2E9E5B), Color(0xFF1F6A43)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF2E9E5B).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.savings, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text('Tabungan Umum', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          const Spacer(),
          if (f.autoPercent > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
              child: Text('Auto ${f.autoPercent}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11)),
            ),
        ]),
        const SizedBox(height: 12),
        Text(fmt(f.saldo), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Dana fleksibel buat kebutuhan yang datang', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
        const SizedBox(height: 16),
        Row(children: [
          for (final q in const [10000, 25000, 50000]) ...[
            Expanded(
              child: _QuickChip(
                label: '${q ~/ 1000}rb',
                onTap: () async {
                  final db = await DbService.isar;
                  await db.writeTxn(() async {
                    f.saldo += q;
                    await db.generalFunds.put(f);
                  });
                  SyncService.syncSoon();
                  ref.invalidate(generalFundProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('+${fmt(q)} ke Tabungan Umum'),
                      backgroundColor: context.ap.income,
                    ));
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
          ],
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: FilledButton.tonal(onPressed: () => _nominal(context, ref, f, true), child: const Text('+ Nabung'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(onPressed: () => _nominal(context, ref, f, false), child: const Text('- Tarik'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(onPressed: () => _setAuto(context, ref, f), child: const Text('Auto %'))),
        ]),
      ]),
    );
  }

  Future<void> _nominal(BuildContext ctx, WidgetRef ref, GeneralFund f, bool add) async {
    final c = TextEditingController();
    await showDialog(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: Text(add ? 'Nabung ke Tabungan Umum' : 'Tarik dari Tabungan Umum'),
        content: TextField(controller: c, keyboardType: TextInputType.number, autofocus: true, decoration: const InputDecoration(labelText: 'Nominal')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              final v = int.tryParse(c.text.trim().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              if (v <= 0) return;
              final db = await DbService.isar;
              await db.writeTxn(() async {
                f.saldo = add ? f.saldo + v : (f.saldo - v).clamp(0, 1 << 62);
                await db.generalFunds.put(f);
              });
              SyncService.syncSoon();
              ref.invalidate(generalFundProvider);
              if (dctx.mounted) Navigator.pop(dctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _setAuto(BuildContext ctx, WidgetRef ref, GeneralFund f) async {
    final c = TextEditingController(text: f.autoPercent.toString());
    await showDialog(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: const Text('Auto Sisihkan'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '% dari pemasukan (0 = manual)')),
          const SizedBox(height: 8),
          Text('Contoh: 5 = otomatis sisihkan 5% tiap ada pemasukan.', style: TextStyle(fontSize: 12, color: ctx.ap.textMuted)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              final v = int.tryParse(c.text.trim()) ?? 0;
              final db = await DbService.isar;
              await db.writeTxn(() async {
                f.autoPercent = v.clamp(0, 100);
                await db.generalFunds.put(f);
              });
              SyncService.syncSoon();
              ref.invalidate(generalFundProvider);
              if (dctx.mounted) Navigator.pop(dctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickChip({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text('+${label}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  final SavingsGoal g;
  final int monthIn;
  const _GoalCard({required this.g, required this.monthIn});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ap = context.ap;
    final noTarget = g.target <= 0;
    final eta = _eta(g, monthIn);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(g.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 20, color: ap.textMuted),
                onPressed: () async {
                  final db = await DbService.isar;
                  await db.writeTxn(() async => await db.savingsGoals.delete(g.id));
                  SyncService.syncSoon();
                  ref.invalidate(savingsProvider);
                },
              ),
            ]),
            if (noTarget) ...[
              Text(fmt(g.terkumpul), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24)),
              Text('Tanpa target — nabung fleksibel', style: TextStyle(color: ap.textMuted, fontSize: 12)),
            ] else ...[
              Text('${fmt(g.terkumpul)} / ${fmt(g.target)}', style: TextStyle(color: ap.text, fontSize: 14)),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: g.progress.clamp(0, 1), minHeight: 8, borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 6),
              Row(children: [
                Text('${(g.progress * 100).clamp(0, 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                if (eta != null) ...[
                  const Spacer(),
                  Icon(Icons.schedule, size: 13, color: kSeed),
                  const SizedBox(width: 4),
                  Text(eta, style: TextStyle(fontSize: 12, color: ap.textMuted)),
                ],
              ]),
            ],
            if (g.autoPercent > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Auto sisihkan ${g.autoPercent}% dari pemasukan', style: TextStyle(color: ap.textMuted, fontSize: 11)),
              ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: FilledButton.tonal(onPressed: () => _topup(context, ref, g, true), child: const Text('+ Nabung'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () => _topup(context, ref, g, false), child: const Text('- Tarik'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () => _setAuto(context, ref, g), child: const Text('Auto %'))),
            ]),
          ]),
        ),
      ),
    );
  }

  String? _eta(SavingsGoal g, int monthIn) {
    if (g.target <= 0 || g.autoPercent <= 0 || monthIn <= 0) return null;
    final perMonth = monthIn * g.autoPercent ~/ 100;
    if (perMonth <= 0) return null;
    final sisa = g.target - g.terkumpul;
    if (sisa <= 0) return 'target tercapai';
    final bulan = (sisa / perMonth).ceil();
    return '± $bulan bulan lagi';
  }

  Future<void> _topup(BuildContext ctx, WidgetRef ref, SavingsGoal g, bool add) async {
    final c = TextEditingController();
    await showDialog(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: Text(add ? 'Nabung ke ${g.nama}' : 'Tarik dari ${g.nama}'),
        content: TextField(controller: c, keyboardType: TextInputType.number, autofocus: true, decoration: const InputDecoration(labelText: 'Nominal')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              final v = int.tryParse(c.text.trim().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              if (v <= 0) return;
              final db = await DbService.isar;
              await db.writeTxn(() async {
                g.terkumpul = add ? g.terkumpul + v : (g.terkumpul - v).clamp(0, 1 << 62);
                await db.savingsGoals.put(g);
              });
              SyncService.syncSoon();
              ref.invalidate(savingsProvider);
              if (dctx.mounted) Navigator.pop(dctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _setAuto(BuildContext ctx, WidgetRef ref, SavingsGoal g) async {
    final c = TextEditingController(text: g.autoPercent.toString());
    await showDialog(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: const Text('Auto Sisihkan'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '% dari pemasukan (0 = manual)')),
          const SizedBox(height: 8),
          Text('Contoh: 10 = otomatis sisihkan 10% tiap ada pemasukan.', style: TextStyle(fontSize: 12, color: ctx.ap.textMuted)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              final v = int.tryParse(c.text.trim()) ?? 0;
              final db = await DbService.isar;
              await db.writeTxn(() async {
                g.autoPercent = v.clamp(0, 100);
                await db.savingsGoals.put(g);
              });
              SyncService.syncSoon();
              ref.invalidate(savingsProvider);
              if (dctx.mounted) Navigator.pop(dctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _GoalSheet extends ConsumerStatefulWidget {
  const _GoalSheet();
  @override
  ConsumerState<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<_GoalSheet> {
  final _nama = TextEditingController();
  final _target = TextEditingController();
  bool _noTarget = false;
  int _auto = 0;
  bool _saving = false;

  @override
  void dispose() {
    _nama.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ap = context.ap;
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
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: ap.line, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          Text('Goal Baru', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: ap.text)),
          const SizedBox(height: 16),
          TextField(
            controller: _nama,
            decoration: const InputDecoration(labelText: 'Nama goal', hintText: 'Motor, Laptop, Liburan...'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _target,
            enabled: !_noTarget,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Target Rp', hintText: '3000000'),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tanpa Target', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Nabung fleksibel, tanpa progress bar', style: TextStyle(color: ap.textMuted, fontSize: 12)),
            value: _noTarget,
            onChanged: (v) => setState(() => _noTarget = v),
          ),
          Row(children: [
            const Text('Auto sisihkan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const Spacer(),
            Text('$_auto%', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kSeed)),
          ]),
          Slider(
            value: _auto.toDouble(),
            max: 100,
            divisions: 100,
            label: '$_auto%',
            activeColor: kSeed,
            onChanged: (v) => setState(() => _auto = v.round()),
          ),
          Text('Otomatis sisihkan $_auto% dari tiap pemasukan. 0 = atur manual', style: TextStyle(color: ap.textMuted, fontSize: 12)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Simpan Goal', style: TextStyle(fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    final nama = _nama.text.trim();
    final target = _noTarget ? 0 : int.tryParse(_target.text.trim().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (nama.isEmpty || (!_noTarget && target <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi nama & target')));
      return;
    }
    setState(() => _saving = true);
    final uid = await ref.read(userIdProvider.future);
    final db = await DbService.isar;
    await db.writeTxn(() async => await db.savingsGoals.put(SavingsGoal()
      ..userId = uid
      ..nama = nama
      ..target = target
      ..terkumpul = 0
      ..autoPercent = _auto
      ..deadline = null));
    SyncService.syncSoon();
    ref.invalidate(savingsProvider);
    if (mounted) Navigator.pop(context);
  }
}