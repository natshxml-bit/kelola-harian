import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../services/db_service.dart';
import '../providers/providers.dart';
import '../utils/currency.dart';

class EmergencyScreen extends ConsumerWidget{
  const EmergencyScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref){
    final efAsync=ref.watch(emergencyProvider);
    return efAsync.when(
        data: (ef){
          if(ef==null) return const Text('loading');
          return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Dana Darurat', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${fmt(ef.terkumpul)} / ${fmt(ef.target)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: ef.progress.clamp(0,1), minHeight: 10, color: Colors.red),
              Text('${(ef.progress*100).toStringAsFixed(1)}% • Auto ${ef.autoPercent}% dari pemasukan'),
              const SizedBox(height: 8),
              const Text('Ideal: 3x pengeluaran bulanan. Atur target manual atau biarkan auto hitung.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]))),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: ElevatedButton(onPressed: ()=> _edit(context, ref, ef, true), child: const Text('Nabung'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: ()=> _edit(context, ref, ef, false), child: const Text('Pakai'))),
            ]),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: ()=> _setting(context, ref, ef), child: const Text('Atur Target & Auto %')),
          ]));
        },
        loading: ()=> const Center(child: CircularProgressIndicator()),
        error: (e,s)=> Text('$e'),
      );
  }
    );
  }
  void _edit(BuildContext ctx, WidgetRef ref, ef, bool add){
    final c=TextEditingController();
    showDialog(context: ctx, builder: (_)=> AlertDialog(
      title: Text(add?'Tambah Dana':'Pakai Dana'),
      content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal')),
      actions: [FilledButton(onPressed: () async {
        final v=int.tryParse(c.text)??0;
        final db=await DbService.isar;
        await db.writeTxn(() async { ef.terkumpul = add? ef.terkumpul+v : (ef.terkumpul - v).clamp(0, 1<<62); await db.emergencyFunds.put(ef); });
        ref.invalidate(emergencyProvider);
        if(ctx.mounted) Navigator.pop(ctx);
      }, child: const Text('OK'))],
    ));
  }
  void _setting(BuildContext ctx, WidgetRef ref, ef){
    final t=TextEditingController(text: ef.target.toString());
    final p=TextEditingController(text: ef.autoPercent.toString());
    showDialog(context: ctx, builder: (_)=> AlertDialog(
      title: const Text('Atur Dana Darurat'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: t, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target Rp')),
        TextField(controller: p, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Auto %')),
      ]),
      actions: [FilledButton(onPressed: () async {
        final db=await DbService.isar;
        await db.writeTxn(() async { ef.target=int.tryParse(t.text)??ef.target; ef.autoPercent=int.tryParse(p.text)??ef.autoPercent; await db.emergencyFunds.put(ef); });
        ref.invalidate(emergencyProvider);
        if(ctx.mounted) Navigator.pop(ctx);
      }, child: const Text('Simpan'))],
    ));
  }
}
