import 'package:bizmate/models/customer_model.dart';
import 'package:bizmate/models/payment.dart';
import 'package:bizmate/models/product.dart';
import 'package:bizmate/models/rental_item.dart';
import 'package:bizmate/models/rental_sale_model.dart';
import 'package:bizmate/models/sale.dart';
import 'package:bizmate/models/user_model.dart';
import 'package:bizmate/services/backup_scheduler.dart';
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

  /// Register lifecycle listener for background auto-compaction and auto-backup
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
    } else if (state == AppLifecycleState.resumed) {
      // Check if scheduled auto-backup is due when user re-opens/resumes BizMate
      BackupScheduler.checkAndRunDueBackup();
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
        try {
          if (Hive.isBoxOpen(boxName)) {
            BoxBase? box;
            switch (boxName) {
              case 'users':
                box = Hive.box<User>(boxName);
                break;
              case 'sales':
                box = Hive.box<Sale>(boxName);
                break;
              case 'products':
                box = Hive.box<Product>(boxName);
                break;
              case 'payments':
                box = Hive.box<Payment>(boxName);
                break;
              case 'rental_items':
                box = Hive.box<RentalItem>(boxName);
                break;
              case 'customers':
                box = Hive.box<CustomerModel>(boxName);
                break;
              case 'rental_sales':
                box = Hive.box<RentalSaleModel>(boxName);
                break;
              default:
                box = Hive.box(boxName);
            }
            await box.compact();
            debugPrint('Compacted global Hive box: $boxName');
          }
        } catch (boxError) {
          debugPrint('Notice: box $boxName compaction skip: $boxError');
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
