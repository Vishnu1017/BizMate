import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// ----------------------------------------------------------------
/// DATABASE MAINTENANCE SERVICE
/// Automatic compaction & disk optimization for Hive storage
/// Runs during app startup and app pause/background shutdown
/// ----------------------------------------------------------------
class DatabaseMaintenance with WidgetsBindingObserver {
  static final DatabaseMaintenance _instance = DatabaseMaintenance._internal();

  factory DatabaseMaintenance() => _instance;

  DatabaseMaintenance._internal();

  static bool _observerRegistered = false;

  /// Register lifecycle listener for background auto-compaction
  static void initLifecycleListener() {
    if (_observerRegistered) return;
    WidgetsBinding.instance.addObserver(_instance);
    _observerRegistered = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app goes into background, paused, or detached state, compact boxes
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      performCompaction();
    }
  }

  /// Compact all open Hive boxes (global & user-specific) to keep disk space minimal
  static Future<void> performCompaction() async {
    try {
      final List<String> globalBoxes = [
        'session',
        'users',
        'sales',
        'products',
        'payments',
        'rental_items',
        'customers',
        'rental_sales',
      ];

      for (final boxName in globalBoxes) {
        if (Hive.isBoxOpen(boxName)) {
          final box = Hive.box(boxName);
          await box.compact();
          debugPrint('Compacted global Hive box: $boxName');
        }
      }

      // Also compact open user-specific data boxes (userdata_...)
      if (Hive.isBoxOpen('session')) {
        final sessionBox = Hive.box('session');
        final email = sessionBox.get('currentUserEmail');
        if (email != null && email.toString().isNotEmpty) {
          final safeEmail = email.toString().replaceAll('.', '_').replaceAll('@', '_');
          final userBoxName = 'userdata_$safeEmail';
          if (Hive.isBoxOpen(userBoxName)) {
            final userBox = Hive.box(userBoxName);
            await userBox.compact();
            debugPrint('Compacted user-specific Hive box: $userBoxName');
          }
        }
      }
    } catch (e) {
      debugPrint('Database compaction error: $e');
    }
  }
}
