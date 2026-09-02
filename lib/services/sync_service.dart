import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';
import 'db_service.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/savings_goal.dart';
import '../models/emergency_fund.dart';
import '../models/general_fund.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://gyvtqjhpbjbqizevavjw.supabase.co');
const supabaseAnon = String.fromEnvironment('SUPABASE_ANON', defaultValue: 'sb_publishable_BtwSwFNniis6CWOy4AykKg_agwLv3Cw');

class SyncService {
  static bool get enabled => supabaseUrl.isNotEmpty && supabaseAnon.isNotEmpty;
  static bool get loggedIn => enabled && Supabase.instance.client.auth.currentUser != null;
  static String? get authUid => loggedIn ? Supabase.instance.client.auth.currentUser?.id : null;

  static Timer? _debounce;
  static bool _syncing = false;
  static String _localUid = 'local';

  static Future<void> init() async {
    if (!enabled) return;
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnon);
    _localUid = await getLocalUid();
    _subscribeRealtime();
    if (loggedIn) syncNow();
  }

  static SupabaseClient? get client => enabled ? Supabase.instance.client : null;
  static String get uid {
    final c = client;
    if (c == null) return 'local';
    return c.auth.currentUser?.id ?? _localUid;
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

  // Debounced full sync. Safe to call after any local mutation.
  static void syncSoon() {
    if (!loggedIn) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => syncNow());
  }

  static bool _subscribed = false;
  static RealtimeChannel? _channel;
  static Future<void> _subscribeRealtime() async {
    if (!enabled || _subscribed) return;
    final c = client!;
    final uid = authUid;
    if (uid == null) {
      _subscriptionNeedsResub = true;
      return;
    }
    _subscribed = true;
    try {
      final ch = c.channel('kelola-harian-sync');
      _channel = ch;
      for (final t in _tables) {
        ch.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: t,
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.delete) {
              _removeLocalByRemoteId(t, payload.oldRecord['id'] as String?);
            }
            syncSoon();
          },
        );
      }
      await ch.subscribe();
    } catch (_) {
      // tabel belum ada di server / realtime belum aktif — biarkan, sync via syncSoon tetap jalan
      _subscribed = false;
    }
  }

  /// Panggil setelah proses login sukses.
  static Future<void> onLogin() async {
    if (!enabled) return;
    _subscribed = false;
    _subscriptionNeedsResub = true;
    _localUid = await getLocalUid();
    syncNow();
  }

  /// Keluar dari akun: batalkan channel realtime & reset state sync.
  static Future<void> signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    try {
      await _channel?.unsubscribe();
    } catch (_) {}
    _channel = null;
    _subscribed = false;
    _subscriptionNeedsResub = true;
  }

  /// Push semua data lokal user ke Supabase, lalu tarik data server masuk ke lokal.
  static Future<void> syncNow() async {
    if (!loggedIn) {
      _subscriptionNeedsResub = true;
      return;
    }
    if (_syncing) return;
    _syncing = true;
    try {
      if (_subscriptionNeedsResub) {
        _subscriptionNeedsResub = false;
        _subscribed = false;
        await _subscribeRealtime();
      }
      final db = await DbService.isar;
      final uidUser = authUid!;

      await _adoptLocalData(db, uidUser);
      await _safe(() => _pushCategories(db, uidUser));
      await _safe(() => _pushGoals(db, uidUser));
      await _safe(() => _pushEmergency(db, uidUser));
      await _safe(() => _pushGeneral(db, uidUser));
      await _safe(() => _pushTransactions(db, uidUser));

      await _safe(() => _pullTransactions(db, uidUser));
      await _safe(() => _pullGoals(db, uidUser));
      await _safe(() => _pullEmergency(db, uidUser));
      await _safe(() => _pullGeneral(db, uidUser));
      await _safe(() => _pullCategories(db, uidUser));
    } catch (e) {
      // sync gagal (mis. tabel belum dibuat / offline) — app tetap jalan lokal
    } finally {
      _syncing = false;
    }
  }

  static Future<void> _safe(Future<void> Function() f) async {
    try {
      await f();
    } catch (_) {
      // tabel/kolom belum ada di server — lewati, koleksi lain tetap sinkron
    }
  }

  /// Data yang dibuat saat mode offline (userId "local_xxx") diadopsi ke akun saat login.
  static Future<void> _adoptLocalData(Isar db, String uid) async {
    await db.writeTxn(() async {
      final txs = await db.transactionModels.where().findAll();
      for (var t in txs) {
        if (t.userId.startsWith('local_')) {
          t.userId = uid;
          await db.transactionModels.put(t);
        }
      }
      final goals = await db.savingsGoals.where().findAll();
      for (var g in goals) {
        if (g.userId.startsWith('local_')) {
          g.userId = uid;
          await db.savingsGoals.put(g);
        }
      }
      final cats = await db.categoryModels.where().findAll();
      for (var c in cats) {
        if (c.userId.startsWith('local_')) {
          c.userId = uid;
          await db.categoryModels.put(c);
        }
      }
      // Emergency & general bersifat singleton (unique userId): adopsi hanya jika belum ada milik akun.
      final efs = await db.emergencyFunds.where().findAll();
      if (!efs.any((e) => e.userId == uid)) {
        for (var e in efs) {
          if (e.userId.startsWith('local_')) {
            e.userId = uid;
            await db.emergencyFunds.put(e);
            break;
          }
        }
      }
      final gfs = await db.generalFunds.where().findAll();
      if (!gfs.any((g) => g.userId == uid)) {
        for (var g in gfs) {
          if (g.userId.startsWith('local_')) {
            g.userId = uid;
            await db.generalFunds.put(g);
            break;
          }
        }
      }
    });
  }

  static bool _subscriptionNeedsResub = false;

  // ---------------- PUSH ----------------

  static Future<void> _pushCategories(Isar db, String uidUser) async {
    final rows = await db.categoryModels.filter().userIdEqualTo(uidUser).findAll();
    if (rows.isEmpty) return;
    final payload = <Map<String, dynamic>>[];
    for (var r in rows) {
      r.remoteId ??= _uuid();
      payload.add({
        'id': r.remoteId,
        'user_id': uidUser,
        'nama': r.nama,
        'icon': r.icon,
        'color': r.color,
        'tipe': r.tipe,
        'is_custom': r.isCustom,
      });
    }
    await client!.from('categories').upsert(payload, onConflict: 'id');
    await db.writeTxn(() async {
      for (var r in rows) {
        if (r.remoteId != null) await db.categoryModels.put(r);
      }
    });
  }

  static Future<void> _pushGoals(Isar db, String uidUser) async {
    final rows = await db.savingsGoals.filter().userIdEqualTo(uidUser).findAll();
    if (rows.isEmpty) return;
    final payload = <Map<String, dynamic>>[];
    for (var r in rows) {
      r.remoteId ??= _uuid();
      payload.add({
        'id': r.remoteId,
        'user_id': uidUser,
        'nama': r.nama,
        'target': r.target,
        'terkumpul': r.terkumpul,
        'auto_percent': r.autoPercent,
        if (r.deadline != null) 'deadline': r.deadline!.toUtc().toIso8601String(),
        'created_at': r.createdAt.toUtc().toIso8601String(),
      });
    }
    await client!.from('savings_goals').upsert(payload, onConflict: 'id');
    await db.writeTxn(() async {
      for (var r in rows) {
        if (r.remoteId != null) await db.savingsGoals.put(r);
      }
    });
  }

  static Future<void> _pushEmergency(Isar db, String uidUser) async {
    final r = await db.emergencyFunds.filter().userIdEqualTo(uidUser).findFirst();
    if (r == null) return;
    r.remoteId ??= _uuid();
    await client!.from('emergency_fund').upsert({
      'id': r.remoteId,
      'user_id': uidUser,
      'target': r.target,
      'terkumpul': r.terkumpul,
      'auto_percent': r.autoPercent,
      'created_at': r.createdAt.toUtc().toIso8601String(),
    }, onConflict: 'id');
    await db.writeTxn(() async => await db.emergencyFunds.put(r));
  }

  static Future<void> _pushGeneral(Isar db, String uidUser) async {
    final r = await db.generalFunds.filter().userIdEqualTo(uidUser).findFirst();
    if (r == null) return;
    r.remoteId ??= _uuid();
    await client!.from('general_fund').upsert({
      'id': r.remoteId,
      'user_id': uidUser,
      'saldo': r.saldo,
      'auto_percent': r.autoPercent,
      'created_at': r.createdAt.toUtc().toIso8601String(),
    }, onConflict: 'id');
    await db.writeTxn(() async => await db.generalFunds.put(r));
  }

  static Future<void> _pushTransactions(Isar db, String uidUser) async {
    final rows = await db.transactionModels.filter().userIdEqualTo(uidUser).findAll();
    if (rows.isEmpty) return;
    final payload = <Map<String, dynamic>>[];
    for (var r in rows) {
      r.remoteId ??= _uuid();
      payload.add({
        'id': r.remoteId,
        'user_id': uidUser,
        'category_id': r.categoryId.isEmpty ? null : r.categoryId,
        'category_name': r.categoryName,
        'tipe': r.tipe,
        'nominal': r.nominal,
        'tanggal': r.tanggal.toUtc().toIso8601String(),
        'catatan': r.catatan,
        'created_at': r.createdAt.toUtc().toIso8601String(),
      });
    }
    await client!.from('transactions').upsert(payload, onConflict: 'id');
    await db.writeTxn(() async {
      for (var r in rows) {
        if (r.remoteId != null) await db.transactionModels.put(r);
      }
    });
  }

  // ---------------- PULL ----------------

  static Future<List<Map<String, dynamic>>> _fetchRows(String table, String uidUser) async {
    return await client!.from(table).select().eq('user_id', uidUser);
  }

  static Future<void> _pullCategories(Isar db, String uidUser) async {
    final rows = await _fetchRows('categories', uidUser);
    final local = await db.categoryModels.filter().userIdEqualTo(uidUser).findAll();
    final byRemote = {for (var e in local) if (e.remoteId != null) e.remoteId!: e};
    await db.writeTxn(() async {
      for (var row in rows) {
        final rid = row['id'] as String;
        final c = byRemote[rid] ?? CategoryModel();
        c
          ..remoteId = rid
          ..userId = uidUser
          ..nama = (row['nama'] as String?) ?? ''
          ..icon = (row['icon'] as String?) ?? 'category'
          ..color = (row['color'] as int?) ?? 0xFF2196F3
          ..tipe = (row['tipe'] as String?) ?? 'pengeluaran'
          ..isCustom = (row['is_custom'] as bool?) ?? true;
        await db.categoryModels.put(c);
      }
    });
  }

  static Future<void> _pullGoals(Isar db, String uidUser) async {
    final rows = await _fetchRows('savings_goals', uidUser);
    final local = await db.savingsGoals.filter().userIdEqualTo(uidUser).findAll();
    final byRemote = {for (var e in local) if (e.remoteId != null) e.remoteId!: e};
    await db.writeTxn(() async {
      for (var row in rows) {
        final rid = row['id'] as String;
        final g = byRemote[rid] ?? SavingsGoal();
        g
          ..remoteId = rid
          ..userId = uidUser
          ..nama = (row['nama'] as String?) ?? ''
          ..target = (row['target'] as int?) ?? 0
          ..terkumpul = (row['terkumpul'] as int?) ?? 0
          ..autoPercent = (row['auto_percent'] as int?) ?? 0;
        final dl = row['deadline'] as String?;
        g.deadline = dl == null ? null : DateTime.parse(dl).toLocal();
        final ct = row['created_at'] as String?;
        if (ct != null) g.createdAt = DateTime.parse(ct).toLocal();
        await db.savingsGoals.put(g);
      }
    });
  }

  static Future<void> _pullEmergency(Isar db, String uidUser) async {
    final rows = await _fetchRows('emergency_fund', uidUser);
    final local = await db.emergencyFunds.filter().userIdEqualTo(uidUser).findFirst();
    await db.writeTxn(() async {
      for (var row in rows) {
        final rid = row['id'] as String;
        final f = (local != null && local.remoteId == rid) ? local : EmergencyFund();
        f
          ..remoteId = rid
          ..userId = uidUser
          ..target = (row['target'] as int?) ?? 0
          ..terkumpul = (row['terkumpul'] as int?) ?? 0
          ..autoPercent = (row['auto_percent'] as int?) ?? 0;
        final ct = row['created_at'] as String?;
        if (ct != null) f.createdAt = DateTime.parse(ct).toLocal();
        await db.emergencyFunds.put(f);
      }
    });
  }

  static Future<void> _pullGeneral(Isar db, String uidUser) async {
    final rows = await _fetchRows('general_fund', uidUser);
    final local = await db.generalFunds.filter().userIdEqualTo(uidUser).findFirst();
    await db.writeTxn(() async {
      for (var row in rows) {
        final rid = row['id'] as String;
        final f = (local != null && local.remoteId == rid) ? local : GeneralFund();
        f
          ..remoteId = rid
          ..userId = uidUser
          ..saldo = (row['saldo'] as int?) ?? 0
          ..autoPercent = (row['auto_percent'] as int?) ?? 0;
        final ct = row['created_at'] as String?;
        if (ct != null) f.createdAt = DateTime.parse(ct).toLocal();
        await db.generalFunds.put(f);
      }
    });
  }

  static Future<void> _pullTransactions(Isar db, String uidUser) async {
    final rows = await _fetchRows('transactions', uidUser);
    final local = await db.transactionModels.filter().userIdEqualTo(uidUser).findAll();
    final byRemote = {for (var e in local) if (e.remoteId != null) e.remoteId!: e};
    await db.writeTxn(() async {
      for (var row in rows) {
        final rid = row['id'] as String;
        final t = byRemote[rid] ?? TransactionModel();
        t
          ..remoteId = rid
          ..userId = uidUser
          ..categoryId = (row['category_id'] as String?) ?? ''
          ..categoryName = (row['category_name'] as String?) ?? ''
          ..tipe = (row['tipe'] as String?) ?? 'pengeluaran'
          ..nominal = (row['nominal'] as int?) ?? 0
          ..catatan = (row['catatan'] as String?) ?? '';
        final tg = row['tanggal'] as String?;
        if (tg != null) t.tanggal = DateTime.parse(tg).toLocal();
        final ct = row['created_at'] as String?;
        if (ct != null) t.createdAt = DateTime.parse(ct).toLocal();
        await db.transactionModels.put(t);
      }
    });
  }

  // ---------------- DELETE (dari realtime device lain) ----------------

  static final _tables = {
    'transactions', 'savings_goals', 'emergency_fund', 'general_fund', 'categories',
  };

  static Future<void> _removeLocalByRemoteId(String table, String? remoteId) async {
    if (remoteId == null) return;
    try {
      final db = await DbService.isar;
      await db.writeTxn(() async {
        switch (table) {
          case 'transactions':
            final r = await db.transactionModels.filter().remoteIdEqualTo(remoteId).findFirst();
            if (r != null) await db.transactionModels.delete(r.id);
            break;
          case 'savings_goals':
            final r = await db.savingsGoals.filter().remoteIdEqualTo(remoteId).findFirst();
            if (r != null) await db.savingsGoals.delete(r.id);
            break;
          case 'categories':
            final r = await db.categoryModels.filter().remoteIdEqualTo(remoteId).findFirst();
            if (r != null) await db.categoryModels.delete(r.id);
            break;
          case 'emergency_fund':
            final r = await db.emergencyFunds.filter().remoteIdEqualTo(remoteId).findFirst();
            if (r != null) await db.emergencyFunds.delete(r.id);
            break;
          case 'general_fund':
            final r = await db.generalFunds.filter().remoteIdEqualTo(remoteId).findFirst();
            if (r != null) await db.generalFunds.delete(r.id);
            break;
        }
      });
    } catch (_) {}
  }

  static String _uuid() => const Uuid().v4();
}