// lib/services/backup_scheduler.dart
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
// Constants
// ─────────────────────────────────────────────────────────────────────────────
const String kBackupTaskName = 'bizmate_auto_backup';
const String kBackupTaskTag  = 'bizmate_backup_tag';

const String kPrefEmail       = 'wa_backup_account';
const String kPrefFrequency   = 'wa_backup_frequency';
const String kPrefLastAuto    = 'wa_last_auto_backup';
const String kPrefAutoEnabled = 'wa_auto_backup_enabled';

// Frequency index mapping (must match WhatsAppBackupFrequency enum order)
// 0=never, 1=manualOnly, 2=daily, 3=weekly, 4=monthly
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
// Auto-backup logic (runs inside workmanager background isolate)
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _performAutoBackup(Map<String, dynamic>? inputData) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(kPrefEmail) ?? '';
    if (email.isEmpty) return;

    // Init Hive in background isolate
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);

    // Register adapters matching main.dart (re-register is safe)
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(SaleAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(ProductAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(PaymentAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(RentalItemAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(CustomerModelAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(RentalSaleModelAdapter());

    final safeEmail = email.replaceAll('.', '_').replaceAll('@', '_');
    final box = await Hive.openBox('userdata_$safeEmail');

    final sales    = List<Sale>.from(box.get('sales', defaultValue: <Sale>[]));
    final products = List<Product>.from(box.get('products', defaultValue: <Product>[]));
    final customers = List<CustomerModel>.from(box.get('customers', defaultValue: <CustomerModel>[]));
    final rentalItems = List<RentalItem>.from(box.get('rental_items', defaultValue: <RentalItem>[]));
    final rentalSales = List<RentalSaleModel>.from(box.get('rental_sales', defaultValue: <RentalSaleModel>[]));

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
        'name': c.name, 'phone': c.phone,
        'createdAt': c.createdAt.toIso8601String(),
        'rentals': c.rentals.map((r) => {
          'from': r.from.toIso8601String(), 'to': r.to.toIso8601String(),
        }).toList(),
      }).toList(),
      'rentalItems': rentalItems.map((r) => {
        'name': r.name, 'brand': r.brand, 'category': r.category,
        'price': r.price, 'availability': r.availability,
        'imagePath': r.imagePath, 'condition': r.condition,
      }).toList(),
      'rentalSales': rentalSales.map((rs) => {
        'id': rs.id, 'customerName': rs.customerName,
        'customerPhone': rs.customerPhone, 'itemName': rs.itemName,
        'ratePerDay': rs.ratePerDay, 'numberOfDays': rs.numberOfDays,
        'totalCost': rs.totalCost, 'amountPaid': rs.amountPaid,
        'paymentMode': rs.paymentMode,
        'fromDateTime': rs.fromDateTime.toIso8601String(),
        'toDateTime': rs.toDateTime.toIso8601String(),
        'tax': rs.safeTax,
      }).toList(),
    };

    // Save local file
    final backupDir = Directory('${dir.path}/BizMate_Backups');
    if (!backupDir.existsSync()) backupDir.createSync(recursive: true);

    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(now);
    final backupFile = File('${backupDir.path}/BizMate_AutoBackup_$dateStr.json');
    await backupFile.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));

    // Update last auto-backup timestamp
    await prefs.setString(kPrefLastAuto, now.toIso8601String());

    // Try uploading to Drive (silently)
    await DriveBackupService.signInSilently();
    if (DriveBackupService.isSignedIn) {
      await DriveBackupService.uploadBackupFile(backupFile);
    }

    // Show local notification
    await _showBackupNotification(sales.length + products.length + customers.length);
  } catch (_) {
    // Background isolate — silently fail
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification helper
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _showBackupNotification(int recordCount) async {
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
    title: '✅ BizMate Auto Backup',
    body: '$recordCount records backed up to Drive',
    notificationDetails: details,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// BackupScheduler — call from UI
// ─────────────────────────────────────────────────────────────────────────────
class BackupScheduler {
  /// Initialise workmanager. Call once in main().
  static Future<void> init() async {
    try {
      await Workmanager().initialize(callbackDispatcher);
    } catch (e) {
      debugPrint('BackupScheduler: WorkManager not initialized yet: $e');
    }
  }

  /// Schedule / re-schedule automatic backup based on frequency index.
  /// frequencyIndex: 0=never, 1=manual, 2=daily, 3=weekly, 4=monthly
  static Future<void> schedule(
    int frequencyIndex,
    String userEmail, {
    bool wifiOnly = false,
  }) async {
    // Cancel any existing task first
    await cancel();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kPrefFrequency, frequencyIndex);
    await prefs.setString(kPrefEmail, userEmail);

    final duration = kFrequencyDurations[frequencyIndex];
    if (duration == null) {
      // 0=never or 1=manual — don't schedule
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
    } catch (e) {
      debugPrint('BackupScheduler: registerPeriodicTask error: $e');
    }
  }

  /// Run background auto-backup routine immediately on demand
  static Future<void> runAutoBackupNow(String userEmail) async {
    await _performAutoBackup({'email': userEmail});
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
    return str != null ? DateTime.tryParse(str) : null;
  }
}
