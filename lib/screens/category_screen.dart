import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';
import '../services/db_service.dart';
import '../services/sync_service.dart';
import '../providers/providers.dart';
import '../models/category.dart';
import '../models/transaction.dart';

class CategoryScreen extends ConsumerStatefulWidget{
  const CategoryScreen({super.key});
  @override
  ConsumerState<CategoryScreen> createState()=> _State();
}
class _State extends ConsumerState<CategoryScreen>{
  @override
  Widget build(BuildContext context){
    final cats=ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kategori Custom')),
      body: cats.when(
        data: (list)=> ListView(
          padding: const EdgeInsets.all(12),
          children: list.map((c)=> Card(child: ListTile(
            leading: CircleAvatar(backgroundColor: Color(c.color), child: const Icon(Icons.category, color: Colors.white)),
            title: Text('${c.nama} • ${c.tipe}'),
            subtitle: Text(c.isCustom?'Custom':'Default'),
            trailing: IconButton(icon: const Icon(Icons.delete), onPressed: c.isCustom?() async {
              final db=await DbService.isar;
              await db.writeTxn(() async {
                await db.categoryModels.delete(c.id);
                final txs = await db.transactionModels.filter().categoryIdEqualTo(c.remoteId ?? '').findAll();
                for (var t in txs) { t.categoryId = ''; await db.transactionModels.put(t); }
              });
              SyncService.deleteCategory(c.remoteId);
              SyncService.syncSoon();
              ref.invalidate(categoriesProvider);
              ref.invalidate(transactionsProvider);
            }:null),
          ))).toList(),
        ),
        loading: ()=> const Center(child: CircularProgressIndicator()),
        error: (e,s)=> Text('$e'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: ()=> _addDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
  void _addDialog(){
    final namaC=TextEditingController();
    String tipe='pengeluaran';
    showDialog(context: context, builder: (ctx)=> StatefulBuilder(builder: (ctx,setS)=> AlertDialog(
      title: const Text('Tambah Kategori'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: namaC, decoration: const InputDecoration(labelText: 'Nama kategori')),
        DropdownButton<String>(value: tipe, items: const [DropdownMenuItem(value: 'pengeluaran', child: Text('Pengeluaran')), DropdownMenuItem(value: 'pemasukan', child: Text('Pemasukan'))], onChanged: (v)=>setS(()=>tipe=v!)),
      ]),
      actions: [
        TextButton(onPressed: ()=> Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(onPressed: () async {
          if(namaC.text.trim().isEmpty) return;
          final uid=await ref.read(userIdProvider.future);
          final db=await DbService.isar;
          await db.writeTxn(() async => await db.categoryModels.put(CategoryModel()
            ..remoteId = const Uuid().v4()
            ..userId=uid
            ..nama=namaC.text.trim()
            ..tipe=tipe
            ..icon='category'
            ..color=0xFF607D8B
            ..isCustom=true));
          SyncService.syncSoon();
          ref.invalidate(categoriesProvider);
          if(context.mounted) Navigator.pop(ctx);
        }, child: const Text('Simpan')),
      ],
    )));
  }
}
