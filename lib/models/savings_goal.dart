import 'package:isar/isar.dart';
part 'savings_goal.g.dart';
@collection
class SavingsGoal {
  Id id = Isar.autoIncrement;
  String? remoteId;
  @Index()
  String userId = '';
  String nama = '';
  int target = 0;
  int terkumpul = 0;
  int autoPercent = 0;
  DateTime? deadline;
  DateTime createdAt = DateTime.now();
  double get progress => target == 0 ? 0 : terkumpul / target;
}
