import 'package:isar/isar.dart';
part 'transaction.g.dart';
@collection
class TransactionModel {
  Id id = Isar.autoIncrement;
  String? remoteId;
  @Index()
  String userId = '';
  @Index()
  String categoryId = '';
  String categoryName = '';
  String tipe = 'pengeluaran';
  int nominal = 0;
  DateTime tanggal = DateTime.now();
  String catatan = '';
  DateTime createdAt = DateTime.now();
}
