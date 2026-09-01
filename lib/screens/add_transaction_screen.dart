import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../services/db_service.dart';
import '../services/sync_service.dart';
import '../models/transaction.dart';
import '../models/savings_goal.dart';
import '../models/emergency_fund.dart';
import '../providers/providers.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});
  @override
  ConsumerState<AddTransactionScreen> createState()=> _State();
}
class _State extends ConsumerState<AddTransactionScreen>{
  String tipe='pengeluaran';
  String? catId;
  String catName='';
  final nominalC=TextEditingController();
  final catatanC=TextEditingController();
  DateTime tanggal=DateTime.now();
  @override
  Widget build(BuildContext context){
    final catsAsync=ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Transaksi')),
      body: catsAsync.when(
        data: (cats){
          final filtered=cats.where((c)=>c.tipe==tipe).toList();
          if(catId==null && filtered.isNotEmpty){catId=filtered.first.id.toString(); catName=filtered.first.nama;}
          return ListView(padding: const EdgeInsets.all(16), children: [
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'pengeluaran', label: Text('Keluar'), icon: Icon(Icons.arrow_upward)), ButtonSegment(value: 'pemasukan', label: Text('Masuk'), icon: Icon(Icons.arrow_downward))],
              selected: {tipe},
              onSelectionChanged: (s){setState((){tipe=s.first; catId=null;});},
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: catId,
              decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
              items: filtered.map((c)=>DropdownMenuItem(value: c.id.toString(), child: Text(c.nama))).toList(),
              onChanged: (v){setState((){catId=v; catName=cats.firstWhere((e)=>e.id.toString()==v).nama;});},
            ),
            const SizedBox(height: 12),
            TextField(controller: nominalC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal (Rp)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: catatanC, decoration: const InputDecoration(labelText: 'Catatan', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            ListTile(title: Text('Tanggal: ${tanggal.day}/${tanggal.month}/${tanggal.year}'), trailing: const Icon(Icons.calendar_today), onTap: () async {
              final d=await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2030), initialDate: tanggal);
              if(d!=null) setState(()=>tanggal=d);
            }),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                if(catId==null || nominalC.text.isEmpty) return;
                final uid=await ref.read(userIdProvider.future);
                final db=await DbService.isar;
                final nominal=int.tryParse(nominalC.text.replaceAll(RegExp(r'[^0-9]'), ''))??0;
                await db.writeTxn(() async {
                  await db.transactionModels.put(TransactionModel()
                    ..userId=uid
                    ..categoryId=catId!
                    ..categoryName=catName
                    ..tipe=tipe
                    ..nominal=nominal
                    ..tanggal=tanggal
                    ..catatan=catatanC.text
                    ..createdAt=DateTime.now());
                  if(tipe=='pemasukan' && nominal>0){
                    final goals=await db.savingsGoals.filter().userIdEqualTo(uid).findAll();
                    for(var g in goals.where((e)=>e.autoPercent>0)){
                      final add=(nominal*g.autoPercent~/100);
                      g.terkumpul+=add;
                      await db.savingsGoals.put(g);
                    }
                    final ef=await db.emergencyFunds.filter().userIdEqualTo(uid).findFirst();
                    if(ef!=null && ef.autoPercent>0){
                      ef.terkumpul+= nominal*ef.autoPercent~/100;
                      await db.emergencyFunds.put(ef);
                    }
                  }
                });
                if(context.mounted) Navigator.pop(context);
              },
              child: const Text('Simpan'),
            )
          ]);
        },
        loading: ()=> const Center(child: CircularProgressIndicator()),
        error: (e,s)=> Text('$e'),
      ),
    );
  }
}
