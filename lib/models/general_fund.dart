import 'package:isar/isar.dart';
part 'general_fund.g.dart';
@collection
class GeneralFund {
  Id id = Isar.autoIncrement;
  String? remoteId;
  @Index()
  String userId = '';
  int saldo = 0;
  int autoPercent = 0;
  DateTime createdAt = DateTime.now();
}