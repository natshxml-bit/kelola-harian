import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../services/db_service.dart';
import '../providers/providers.dart';
import '../models/savings_goal.dart';
import '../utils/currency.dart';
import '../theme.dart';

class SavingsScreen extends ConsumerWidget{
  const SavingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref){
    final goals=ref.watch(savingsProvider);
    return goals.when(
        data: (list){
          if(list.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.savings_outlined, size: 48, color: context.ap.textMuted),
            const SizedBox(height: 12),
            Text('Belum ada tabungan', style: TextStyle(color: context.ap.textMuted)),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: ()=> _addGoal(context, ref), icon: const Icon(Icons.add), label: const Text('Buat Goal')),
          ]));
          return ListView(padding: const EdgeInsets.all(12), children: list.map((g)=> Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('${fmt(g.terkumpul)} / ${fmt(g.target)}', style: TextStyle(color: context.ap.textMuted, fontSize: 13)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: g.progress.clamp(0,1), minHeight: 8, borderRadius: BorderRadius.circular(4)),
            Text('${(g.progress*100).toStringAsFixed(1)}% • Auto ${g.autoPercent}%', style: TextStyle(color: context.ap.textMuted, fontSize: 12)),
            const SizedBox(height: 8),
            Row(children: [
              ElevatedButton(onPressed: ()=> _topup(context, ref, g, true), child: const Text('+ Nabung')),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: ()=> _topup(context, ref, g, false), child: const Text('- Tarik')),
              const Spacer(),
              IconButton(icon: const Icon(Icons.delete), onPressed: () async {
                final db=await DbService.isar;
                await db.writeTxn(() async => await db.savingsGoals.delete(g.id));
                ref.invalidate(savingsProvider);
              })
            ])
          ])))).toList());
        },
        loading: ()=> const Center(child: CircularProgressIndicator()),
        error: (e,s)=> Text('$e'),
      );
  }
  void _addGoal(BuildContext ctx, WidgetRef ref){
    final nama=TextEditingController();
    final target=TextEditingController();
    final auto=TextEditingController(text: '10');
    showDialog(context: ctx, builder: (_)=> AlertDialog(
      title: const Text('Goal Baru'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nama, decoration: const InputDecoration(labelText: 'Nama (Motor, Rumah)')),
        TextField(controller: target, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target Rp')),
        TextField(controller: auto, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Auto % dari pemasukan (0-100)')),
      ]),
      actions: [
        FilledButton(onPressed: () async {
          final uid=await ref.read(userIdProvider.future);
          final db=await DbService.isar;
          await db.writeTxn(() async => await db.savingsGoals.put(SavingsGoal()
            ..userId=uid
            ..nama=nama.text
            ..target=int.tryParse(target.text)??0
            ..terkumpul=0
            ..autoPercent=int.tryParse(auto.text)??0));
          ref.invalidate(savingsProvider);
          if(ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('Simpan'))
      ],
    ));
  }
  void _topup(BuildContext ctx, WidgetRef ref, SavingsGoal g, bool add){
    final c=TextEditingController();
    showDialog(context: ctx, builder: (_)=> AlertDialog(
      title: Text(add?'Nabung ke ${g.nama}':'Tarik dari ${g.nama}'),
      content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal')),
      actions: [
        FilledButton(onPressed: () async {
          final v=int.tryParse(c.text)??0;
          final db=await DbService.isar;
          await db.writeTxn(() async {
            g.terkumpul = add? g.terkumpul+v : (g.terkumpul - v).clamp(0, 1<<62);
            await db.savingsGoals.put(g);
          });
          ref.invalidate(savingsProvider);
          if(ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('OK'))
      ],
    ));
  }
}
