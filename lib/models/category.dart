import 'package:isar/isar.dart';
part 'category.g.dart';
@collection
class CategoryModel {
  Id id = Isar.autoIncrement;
  String? remoteId;
  @Index()
  String userId = '';
  String nama = '';
  String icon = 'category';
  int color = 0xFF2196F3;
  String tipe = 'pengeluaran';
  bool isCustom = true;
}
