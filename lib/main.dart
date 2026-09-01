import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/sync_service.dart';
import 'app.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SyncService.init();
  runApp(const ProviderScope(child: App()));
}
