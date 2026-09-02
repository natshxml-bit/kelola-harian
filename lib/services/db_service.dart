import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart' as pp;
import 'package:uuid/uuid.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/savings_goal.dart';
import '../models/emergency_fund.dart';
import '../models/general_fund.dart';

class DbService {
  static Isar? _isar;
  static Future<Isar> get isar async {
    if (_isar != null) return _isar!;
    final dir = await pp.getApplicationDocumentsDirectory();
    _isar = await Isar.open([
      CategoryModelSchema,
      TransactionModelSchema,
      SavingsGoalSchema,
      EmergencyFundSchema,
      GeneralFundSchema,
    ], directory: dir.path);
    return _isar!;
  }

  static Future<bool> seedCategories(String userId) async {
    final db = await isar;
    final count = await db.categoryModels.filter().userIdEqualTo(userId).count();
    if (count > 0) return false;
    final defaults = [
      {'nama': 'Makan', 'icon': 'restaurant', 'tipe': 'pengeluaran', 'color': 0xFFE91E63},
      {'nama': 'Transport', 'icon': 'directions_bus', 'tipe': 'pengeluaran', 'color': 0xFF2196F3},
      {'nama': 'Belanja', 'icon': 'shopping_bag', 'tipe': 'pengeluaran', 'color': 0xFFFF9800},
      {'nama': 'Tagihan', 'icon': 'receipt', 'tipe': 'pengeluaran', 'color': 0xFFF44336},
      {'nama': 'Hiburan', 'icon': 'movie', 'tipe': 'pengeluaran', 'color': 0xFF9C27B0},
      {'nama': 'Kesehatan', 'icon': 'local_hospital', 'tipe': 'pengeluaran', 'color': 0xFF4CAF50},
      {'nama': 'Gaji', 'icon': 'payments', 'tipe': 'pemasukan', 'color': 0xFF009688},
      {'nama': 'Bonus', 'icon': 'card_giftcard', 'tipe': 'pemasukan', 'color': 0xFF00BCD4},
    ];
    await db.writeTxn(() async {
      for (var d in defaults) {
        // uuid v5 deterministik per user+kategori -> dua device untuk user yang
        // sama memakai id sama, sehingga upsert server tidak membuat duplikat.
        await db.categoryModels.put(CategoryModel()
          ..remoteId = const Uuid().v5(Uuid.NAMESPACE_URL, 'kelola-harian:$userId:${d['tipe']!}:${d['nama']!}')
          ..userId = userId
          ..nama = d['nama'] as String
          ..icon = d['icon'] as String
          ..tipe = d['tipe'] as String
          ..color = d['color'] as int
          ..isCustom = false);
      }
    });
    return true;
  }
}
