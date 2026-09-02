import 'package:isar/isar.dart';
part 'emergency_fund.g.dart';
@collection
class EmergencyFund {
  Id id = Isar.autoIncrement;
  String? remoteId;
  @Index(unique: true)
  String userId = '';
  int target = 0;
  int terkumpul = 0;
  int autoPercent = 5;
  DateTime createdAt = DateTime.now();
  double get progress => target == 0 ? 0 : terkumpul / target;
}
