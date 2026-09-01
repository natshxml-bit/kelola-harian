import 'package:intl/intl.dart';
final idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
String fmt(int v) => idr.format(v);
