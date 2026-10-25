// lib/services/backup_scheduler.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bizmate/models/customer_model.dart';
import 'package:bizmate/models/payment.dart';
import 'package:bizmate/models/product.dart';
import 'package:bizmate/models/rental_item.dart';
import 'package:bizmate/models/rental_sale_model.dart';
import 'package:bizmate/models/sale.dart';
import 'package:bizmate/models/user_model.dart';
import 'package:bizmate/services/drive_backup_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants & SharedPreferences Keys (Shared across Scheduler & UI)
// ─────────────────────────────────────────────────────────────────────────────
const String kBackupTaskName = 'bizmate_auto_backup';
const String kBackupTaskTag  = 'bizmate_backup_tag';

const String kPrefEmail       = 'wa_backup_account';
const String kPrefFrequency   = 'wa_backup_frequency';
const String kPrefLastAuto    = 'wa_last_auto_backup';
const String kPrefAutoEnabled = 'wa_auto_backup_enabled';
const String kPrefDirty       = 'wa_backup_dirty';
const String kPrefDirtyTime   = 'wa_backup_dirty_time';
const String kPrefLastDrive   = 'wa_last_drive_backup';
const String kPrefLastLocal   = 'wa_last_local_backup';
const String kPrefLastSize    = 'wa_last_backup_size';
const String kPrefLastRecords = 'wa_last_backup_records';
const String kPrefLastStatus  = 'wa_last_backup_status';
const String kPrefNetwork     = 'wa_backup_network';

// Frequency index mapping (0=never, 1=manualOnly, 2=daily, 3=weekly, 4=monthly)
const Map<int, Duration> kFrequencyDurations = {
  2: Duration(hours: 24),
  3: Duration(days: 7),
  4: Duration(days: 30),
};

// ─────────────────────────────────────────────────────────────────────────────
// Workmanager callback dispatcher (top-level, required by workmanager)
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == kBackupTaskName) {
      await _performAutoBackup(inputData);
    }
    return true;
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Background isolate execution
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _performAutoBackup(Map<String, dynamic>? inputData) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(kPrefEmail) ?? inputData?['email'] ?? '';
    if (email.isEmpty) return;

    // Check if auto backup is enabled
    final isEnabled = prefs.getBool(kPrefAutoEnabled) ?? false;
    if (!isEnabled) return;

    // Change detection check: if data is not dirty and a previous backup exists, skip
    final isDirty = prefs.getBool(kPrefDirty) ?? true;
    final lastDrive = prefs.getString(kPrefLastDrive);
    if (!isDirty && lastDrive != null) {
      debugPrint('BackupScheduler (Background): No records modified since last backup. Skipping.');
      return;
    }

    // Init Hive in background isolate
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);

    // Register all adapters (0-6)
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(SaleAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(ProductAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(PaymentAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(RentalItemAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(CustomerModelAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(RentalSaleModelAdapter());

    final safeEmail = email.replaceAll('.', '_').replaceAll('@', '_');
    final box = await Hive.openBox('userdata_$safeEmail');

    final sales = List<Sale>.from(box.get('sales', defaultValue: <Sale>[]));
    final products = List<Product>.from(box.get('products', defaultValue: <Product>[]));
    final customers = List<CustomerModel>.from(box.get('customers', defaultValue: <CustomerModel>[]));
    final rentalItems = List<RentalItem>.from(box.get('rental_items', defaultValue: <RentalItem>[]));
    final rentalSales = List<RentalSaleModel>.from(box.get('rental_sales', defaultValue: <RentalSaleModel>[]));

    final totalRecords = sales.length + products.length + customers.length + rentalItems.length + rentalSales.length;
    final now = DateTime.now();

    final payload = {
      'appName': 'BizMate',
      'format': 'AutoBackup',
      'version': 3,
      'exportedAt': now.toIso8601String(),
      'userEmail': email,
      'isEncrypted': false,
      'sales': sales.map((s) => {
        'customerName': s.customerName,
        'customerAddress': s.customerAddress ?? '',
        'phoneNumber': s.phoneNumber,
        'productName': s.productName,
        'item': s.item,
        'amount': s.amount,
        'totalAmount': s.totalAmount,
        'discount': s.discount,
        'paymentMode': s.paymentMode,
        'dateTime': s.dateTime.toIso8601String(),
        'deliveryStatus': s.deliveryStatus,
        'deliveryLink': s.deliveryLink,
        'deliveryStatusHistory': s.deliveryStatusHistory ?? [],
        'eventDates': (s.eventDates ?? []).map((d) => d.toIso8601String()).toList(),
        'completedEventDates': (s.completedEventDates ?? []).map((d) => d.toIso8601String()).toList(),
        'paymentHistory': s.paymentHistory.map((p) => {
          'amount': p.amount,
          'date': p.date.toIso8601String(),
          'mode': p.mode,
        }).toList(),
      }).toList(),
      'products': products.map((p) => {'name': p.name, 'rate': p.rate}).toList(),
      'customers': customers.map((c) => {
        'name': c.name,
        'phone': c.phone,
        'createdAt': c.createdAt.toIso8601String(),
        'rentals': c.rentals.map((r) => {
          'from': r.from.toIso8601String(),
          'to': r.to.toIso8601String(),
        }).toList(),
      }).toList(),
      'rentalItems': rentalItems.map((r) => {
        'name': r.name,
        'brand': r.brand,
        'category': r.category,
        'price': r.price,
        'availability': r.availability,
        'imagePath': r.imagePath,
        'condition': r.condition,
      }).toList(),
      'rentalSales': rentalSales.map((rs) => {
        'id': rs.id,
        'customerName': rs.customerName,
        'customerPhone': rs.customerPhone,
        'itemName': rs.itemName,
        'ratePerDay': rs.ratePerDay,
        'numberOfDays': rs.numberOfDays,
        'totalCost': rs.totalCost,
        'amountPaid': rs.amountPaid,
        'paymentMode': rs.paymentMode,
        'fromDateTime': rs.fromDateTime.toIso8601String(),
        'toDateTime': rs.toDateTime.toIso8601String(),
        'tax': rs.safeTax,
      }).toList(),
    };

    // Save local backup file
    final backupDir = Directory('${dir.path}/BizMate_Backups');
    if (!backupDir.existsSync()) backupDir.createSync(recursive: true);

    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(now);
    final backupFile = File('${backupDir.path}/BizMate_AutoBackup_$dateStr.json');
    await backupFile.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    final sizeKb = backupFile.lengthSync() / 1024.0;

    await prefs.setString(kPrefLastLocal, now.toIso8601String());

    // Upload to Google Drive (silently in background)
    await DriveBackupService.signInSilently();
    if (DriveBackupService.isSignedIn) {
      final driveFileId = await DriveBackupService.uploadBackupFile(backupFile);
      if (driveFileId != null && driveFileId.isNotEmpty) {
        // Success: update cloud timestamp, size, status, and clear dirty flag
        await prefs.setString(kPrefLastDrive, now.toIso8601String());
        await prefs.setString(kPrefLastAuto, now.toIso8601String());
        await prefs.setDouble(kPrefLastSize, sizeKb);
        await prefs.setInt(kPrefLastRecords, totalRecords);
        await prefs.setString(kPrefLastStatus, 'Success');
        await prefs.setBool(kPrefDirty, false);

        await _showBackupNotification(totalRecords);
      } else {
        final err = DriveBackupService.lastUploadError ?? 'Upload failed';
        await prefs.setString(kPrefLastStatus, 'Pending upload ($err)');
      }
    } else {
      await prefs.setString(kPrefLastStatus, 'Pending Google Drive connection');
    }
  } catch (e) {
    debugPrint('BackupScheduler background error: $e');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification helper
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _showBackupNotification(int recordCount) async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
    );

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'bizmate_backup_channel',
        'BizMate Backups',
        channelDescription: 'Automatic backup notifications',
        importance: Importance.low,
        priority: Priority.low,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await plugin.show(
      id: 99,
      title: '✅ BizMate Auto Backup Complete',
      body: '$recordCount records synced to Google Drive',
      notificationDetails: details,
    );
  } catch (_) {}
}

// ─────────────────────────────────────────────────────────────────────────────
// BackupScheduler Service (Centralized Controller)
// ─────────────────────────────────────────────────────────────────────────────
class BackupScheduler {
  static bool _isBackingUpBusy = false;
  static bool get isBackingUpBusy => _isBackingUpBusy;

  static StreamSubscription? _boxSubscription;

  /// Initialise workmanager. Call once in main().
  static Future<void> init() async {
    try {
      await Workmanager().initialize(callbackDispatcher);
    } catch (e) {
      debugPrint('BackupScheduler: WorkManager initialization: $e');
    }
  }

  /// Attach automatic change detection to Hive box.
  /// When sales, products, customers, or rentals change, marks backup as dirty.
  static void startWatchingBox(Box box) {
    _boxSubscription?.cancel();
    _boxSubscription = box.watch().listen((event) {
      markDirty();
    });
  }

  /// Stop watching changes (e.g. on logout)
  static void stopWatchingBox() {
    _boxSubscription?.cancel();
    _boxSubscription = null;
  }

  /// Mark local database as having pending changes that need backup
  static Future<void> markDirty() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kPrefDirty, true);
      await prefs.setString(kPrefDirtyTime, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Returns whether records have changed since the last backup
  static Future<bool> isDirty() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kPrefDirty) ?? true;
  }

  /// Clear dirty state after successful backup
  static Future<void> clearDirty() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefDirty, false);
  }

  /// Check whether an automatic backup is due (called on app open & app resume)
  static Future<bool> checkAndRunDueBackup({String? userEmail}) async {
    if (_isBackingUpBusy) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool(kPrefAutoEnabled) ?? false;
      if (!isEnabled) return false;

      final freqIdx = prefs.getInt(kPrefFrequency) ?? 2; // default daily
      final duration = kFrequencyDurations[freqIdx];
      if (duration == null) return false;

      final email = userEmail ?? prefs.getString(kPrefEmail) ?? '';
      if (email.isEmpty) return false;

      final lastDriveStr = prefs.getString(kPrefLastDrive);
      final lastDriveTime = lastDriveStr != null ? DateTime.tryParse(lastDriveStr) : null;
      final now = DateTime.now();

      bool isDue = false;
      if (lastDriveTime == null) {
        isDue = true;
      } else {
        final diff = now.difference(lastDriveTime);
        if (diff >= duration) {
          isDue = true;
        }
      }

      if (!isDue) return false;

      final dirty = await isDirty();
      if (!dirty && lastDriveTime != null) {
        debugPrint('BackupScheduler: Backup interval elapsed, but no records changed. Skipping upload.');
        return false;
      }

      debugPrint('BackupScheduler: Backup is due (${duration.inHours}h, dirty=$dirty). Running auto-backup...');
      final success = await runAutoBackupNow(email);
      return success;
    } catch (e) {
      debugPrint('BackupScheduler checkAndRunDueBackup error: $e');
      return false;
    }
  }

  /// Schedule / re-schedule automatic backup based on frequency index.
  /// frequencyIndex: 0=never, 1=manual, 2=daily, 3=weekly, 4=monthly
  static Future<void> schedule(
    int frequencyIndex,
    String userEmail, {
    bool wifiOnly = false,
  }) async {
    await cancel();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kPrefFrequency, frequencyIndex);
    await prefs.setString(kPrefEmail, userEmail);

    final duration = kFrequencyDurations[frequencyIndex];
    if (duration == null) {
      await prefs.setBool(kPrefAutoEnabled, false);
      return;
    }

    await prefs.setBool(kPrefAutoEnabled, true);

    try {
      await Workmanager().registerPeriodicTask(
        kBackupTaskTag,
        kBackupTaskName,
        frequency: duration,
        initialDelay: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
        constraints: Constraints(
          networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
        inputData: {'email': userEmail},
      );
      debugPrint('BackupScheduler: Registered WorkManager task with frequency: ${duration.inHours}h');
    } catch (e) {
      debugPrint('BackupScheduler: registerPeriodicTask error: $e');
    }
  }

  /// Run background auto-backup routine immediately on demand
  static Future<bool> runAutoBackupNow(String userEmail) async {
    if (_isBackingUpBusy) return false;
    _isBackingUpBusy = true;
    try {
      await _performAutoBackup({'email': userEmail});
      return true;
    } finally {
      _isBackingUpBusy = false;
    }
  }

  /// Create a local pre-restore safety copy of current records before restoring
  static Future<File?> createSafetySnapshot(String userEmail) async {
    try {
      final safeEmail = userEmail.replaceAll('.', '_').replaceAll('@', '_');
      final userBoxName = 'userdata_$safeEmail';
      Box box;
      if (Hive.isBoxOpen(userBoxName)) {
        box = Hive.box(userBoxName);
      } else {
        box = await Hive.openBox(userBoxName);
      }

      final sales = List<Sale>.from(box.get('sales', defaultValue: <Sale>[]));
      final products = List<Product>.from(box.get('products', defaultValue: <Product>[]));
      final customers = List<CustomerModel>.from(box.get('customers', defaultValue: <CustomerModel>[]));
      final rentalItems = List<RentalItem>.from(box.get('rental_items', defaultValue: <RentalItem>[]));
      final rentalSales = List<RentalSaleModel>.from(box.get('rental_sales', defaultValue: <RentalSaleModel>[]));

      final now = DateTime.now();
      final payload = {
        'appName': 'BizMate',
        'format': 'PreRestoreSafetyCopy',
        'version': 3,
        'createdAt': now.toIso8601String(),
        'userEmail': userEmail,
        'sales': sales.map((s) => {'customerName': s.customerName, 'amount': s.amount, 'dateTime': s.dateTime.toIso8601String()}).toList(),
        'products': products.map((p) => {'name': p.name, 'rate': p.rate}).toList(),
        'customers': customers.map((c) => {'name': c.name, 'phone': c.phone}).toList(),
        'rentalItems': rentalItems.map((r) => {'name': r.name, 'price': r.price}).toList(),
        'rentalSales': rentalSales.map((rs) => {'id': rs.id, 'customerName': rs.customerName}).toList(),
      };

      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/BizMate_Backups/SafetySnapshots');
      if (!backupDir.existsSync()) backupDir.createSync(recursive: true);

      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(now);
      final file = File('${backupDir.path}/BizMate_SafetyCopy_$dateStr.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
      debugPrint('BackupScheduler: Safety snapshot created at: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('BackupScheduler createSafetySnapshot error: $e');
      return null;
    }
  }

  /// Cancel the scheduled backup task.
  static Future<void> cancel() async {
    try {
      await Workmanager().cancelByTag(kBackupTaskTag);
    } catch (e) {
      debugPrint('BackupScheduler: cancel error: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefAutoEnabled, false);
  }

  /// Returns true if auto-backup is currently active.
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kPrefAutoEnabled) ?? false;
  }

  /// Returns the last auto-backup DateTime, or null.
  static Future<DateTime?> lastAutoBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(kPrefLastAuto);
    return str != null ? DateTime.tryParse(str)?.toLocal() : null;
  }

  /// Returns the last Google Drive backup DateTime, or null.
  static Future<DateTime?> lastDriveBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(kPrefLastDrive);
    return str != null ? DateTime.tryParse(str)?.toLocal() : null;
  }
}
