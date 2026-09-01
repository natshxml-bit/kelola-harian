import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://gyvtqjhpbjbqizevavjw.supabase.co');
const supabaseAnon = String.fromEnvironment('SUPABASE_ANON', defaultValue: 'sb_publishable_BtwSwFNniis6CWOy4AykKg_agwLv3Cw');

class SyncService {
  static bool get enabled => supabaseUrl.isNotEmpty && supabaseAnon.isNotEmpty;
  static Future<void> init() async {
    if (!enabled) return;
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnon);
  }
  static SupabaseClient? get client => enabled ? Supabase.instance.client : null;
  static String get uid {
    final c = client;
    if (c == null) return 'local';
    return c.auth.currentUser?.id ?? 'local';
  }
  static Future<void> setLocalUid(String id) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('local_uid', id);
  }
  static Future<String> getLocalUid() async {
    final p = await SharedPreferences.getInstance();
    var id = p.getString('local_uid');
    if (id == null) {
      id = 'local_${DateTime.now().millisecondsSinceEpoch}';
      await p.setString('local_uid', id);
    }
    return id;
  }
}
