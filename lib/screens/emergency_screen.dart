import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../services/db_service.dart';
import '../services/sync_service.dart';
import '../providers/providers.dart';
import '../utils/currency.dart';
import '../models/emergency_fund.dart';

class EmergencyScreen extends ConsumerWidget {
  const EmergencyScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final efAsync = ref.watch(emergencyProvider);
    return efAsync.when(
      data: (ef) {
        if (ef == null) return const Text('loading');
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFCC5C64), Color(0xFF8E3B46)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: const Color(0xFFCC5C64).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.health_and_safety, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      const Text('Dana Darurat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                      const Spacer(),
                      _pct(context, ef),
                    ]),
                    const SizedBox(height: 14),
                    Text(
                      '${fmt(ef.terkumpul)} / ${fmt(ef.target)}',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: ef.progress.clamp(0, 1),
                        minHeight: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      ef.autoPercent > 0
                          ? 'Auto ${ef.autoPercent}% dari pemasukan • Idealnya 3x pengeluaran bulanan'
                          : 'Dikelola manual • Idealnya 3x pengeluaran bulanan',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => _edit(context, ref, ef, true),
                      child: const Text('Nabung'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _edit(context, ref, ef, false),
                      child: const Text('Pakai'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _setting(context, ref, ef),
                  icon: const Icon(Icons.tune),
                  label: const Text('Atur Target & Auto %'),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Text('$e'),
    );
  }

  Widget _pct(BuildContext context, ef) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
      child: Text('${(ef.progress * 100).toStringAsFixed(0)}%',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }

  void _edit(BuildContext ctx, WidgetRef ref, ef, bool add) {
    final c = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(add ? 'Tambah Dana' : 'Pakai Dana'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Nominal'),
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              final v = int.tryParse(c.text) ?? 0;
              final db = await DbService.isar;
              await db.writeTxn(() async {
                ef.terkumpul = add
                    ? ef.terkumpul + v
                    : (ef.terkumpul - v).clamp(0, 1 << 62);
                await db.emergencyFunds.put(ef);
              });
              SyncService.syncSoon();
              ref.invalidate(emergencyProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _setting(BuildContext ctx, WidgetRef ref, ef) {
    final t = TextEditingController(text: ef.target.toString());
    final p = TextEditingController(text: ef.autoPercent.toString());
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Atur Dana Darurat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: t,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target Rp'),
            ),
            TextField(
              controller: p,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Auto %'),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              final db = await DbService.isar;
              await db.writeTxn(() async {
                ef.target = int.tryParse(t.text) ?? ef.target;
                ef.autoPercent = int.tryParse(p.text) ?? ef.autoPercent;
                await db.emergencyFunds.put(ef);
              });
              SyncService.syncSoon();
              ref.invalidate(emergencyProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
