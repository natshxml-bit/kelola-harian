import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../services/db_service.dart';
import '../services/sync_service.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/savings_goal.dart';
import '../models/emergency_fund.dart';
import '../models/general_fund.dart';

final authTickProvider = StateProvider<int>((ref) => 0);

final userIdProvider = FutureProvider<String>((ref) async {
  ref.watch(authTickProvider);
  if (SyncService.enabled && SyncService.client?.auth.currentUser != null) {
    return SyncService.uid;
  }
  return await SyncService.getLocalUid();
});

final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final uid = await ref.watch(userIdProvider.future);
  final db = await DbService.isar;
  await DbService.seedCategories(uid);
  SyncService.syncSoon();
  return await db.categoryModels.filter().userIdEqualTo(uid).findAll();
});

final transactionsProvider = FutureProvider<List<TransactionModel>>((ref) async {
  final uid = await ref.watch(userIdProvider.future);
  final db = await DbService.isar;
  return await db.transactionModels.filter().userIdEqualTo(uid).sortByTanggalDesc().findAll();
});

final savingsProvider = FutureProvider<List<SavingsGoal>>((ref) async {
  final uid = await ref.watch(userIdProvider.future);
  final db = await DbService.isar;
  return await db.savingsGoals.filter().userIdEqualTo(uid).findAll();
});

final emergencyProvider = FutureProvider<EmergencyFund?>((ref) async {
  final uid = await ref.watch(userIdProvider.future);
  final db = await DbService.isar;
  var f = await db.emergencyFunds.filter().userIdEqualTo(uid).findFirst();
  if (f == null) {
    f = EmergencyFund()..userId = uid..target = 3000000..terkumpul = 0..autoPercent = 0;
    await db.writeTxn(() async => await db.emergencyFunds.put(f!));
    SyncService.syncSoon();
  }
  return f;
});

final generalFundProvider = FutureProvider<GeneralFund?>((ref) async {
  final uid = await ref.watch(userIdProvider.future);
  final db = await DbService.isar;
  var f = await db.generalFunds.filter().userIdEqualTo(uid).findFirst();
  if (f == null) {
    f = GeneralFund()..userId = uid..saldo = 0..autoPercent = 0;
    await db.writeTxn(() async => await db.generalFunds.put(f!));
    SyncService.syncSoon();
  }
  return f;
});

final dashboardProvider = FutureProvider<Map<String,int>>((ref) async {
  final txs = await ref.watch(transactionsProvider.future);
  final now = DateTime.now();
  int todayPemasukan = 0, todayPengeluaran = 0, monthPemasukan = 0, monthPengeluaran = 0, totalPemasukan = 0, totalPengeluaran = 0;
  for (var t in txs) {
    if (t.tipe == 'pemasukan') {
      totalPemasukan += t.nominal;
      if (t.tanggal.year == now.year && t.tanggal.month == now.month) monthPemasukan += t.nominal;
      if (t.tanggal.year == now.year && t.tanggal.month == now.month && t.tanggal.day == now.day) todayPemasukan += t.nominal;
    } else {
      totalPengeluaran += t.nominal;
      if (t.tanggal.year == now.year && t.tanggal.month == now.month) monthPengeluaran += t.nominal;
      if (t.tanggal.year == now.year && t.tanggal.month == now.month && t.tanggal.day == now.day) todayPengeluaran += t.nominal;
    }
  }
  return {
    'saldo': totalPemasukan - totalPengeluaran,
    'todayIn': todayPemasukan,
    'todayOut': todayPengeluaran,
    'monthIn': monthPemasukan,
    'monthOut': monthPengeluaran,
    'totalIn': totalPemasukan,
    'totalOut': totalPengeluaran,
  };
});
