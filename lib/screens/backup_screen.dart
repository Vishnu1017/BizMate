// lib/screens/backup_screen.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unnecessary_underscores

import 'dart:convert';
import 'dart:io';

import 'package:bizmate/models/customer_model.dart';
import 'package:bizmate/models/payment.dart';
import 'package:bizmate/models/product.dart';
import 'package:bizmate/models/rental_item.dart';
import 'package:bizmate/models/rental_sale_model.dart';
import 'package:bizmate/models/sale.dart';
import 'package:bizmate/services/backup_scheduler.dart';
import 'package:bizmate/services/drive_backup_service.dart';
import 'package:bizmate/utils/app_theme.dart';
import 'package:bizmate/widgets/app_snackbar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS & MODELS
// ─────────────────────────────────────────────────────────────────────────────
enum WhatsAppBackupFrequency {
  never,
  manualOnly,
  daily,
  weekly,
  monthly;

  bool get isAutomatic =>
      this == WhatsAppBackupFrequency.daily ||
      this == WhatsAppBackupFrequency.weekly ||
      this == WhatsAppBackupFrequency.monthly;

  String get label {
    switch (this) {
      case WhatsAppBackupFrequency.never:
        return 'Never';
      case WhatsAppBackupFrequency.manualOnly:
        return 'Only when I tap "Back up"';
      case WhatsAppBackupFrequency.daily:
        return 'Daily';
      case WhatsAppBackupFrequency.weekly:
        return 'Weekly';
      case WhatsAppBackupFrequency.monthly:
        return 'Monthly';
    }
  }

  String get badgeLabel {
    switch (this) {
      case WhatsAppBackupFrequency.never:
        return 'Off';
      case WhatsAppBackupFrequency.manualOnly:
        return 'Manual';
      case WhatsAppBackupFrequency.daily:
        return 'Every Day';
      case WhatsAppBackupFrequency.weekly:
        return 'Every Week';
      case WhatsAppBackupFrequency.monthly:
        return 'Monthly';
    }
  }
}

enum NetworkType {
  wifiOnly,
  wifiOrCellular;

  String get label {
    switch (this) {
      case NetworkType.wifiOnly:
        return 'Wi-Fi only';
      case NetworkType.wifiOrCellular:
        return 'Wi-Fi or cellular';
    }
  }
}

class BackupHistoryEntry {
  final DateTime createdAt;
  final int salesCount;
  final int productsCount;
  final int customersCount;
  final int rentalItemsCount;
  final int rentalSalesCount;
  final double fileSizeKb;
  final String? filePath;
  final bool isEncrypted;

  BackupHistoryEntry({
    required this.createdAt,
    required this.salesCount,
    required this.productsCount,
    required this.customersCount,
    required this.rentalItemsCount,
    required this.rentalSalesCount,
    required this.fileSizeKb,
    this.filePath,
    this.isEncrypted = false,
  });

  Map<String, dynamic> toMap() => {
    'createdAt': createdAt.toIso8601String(),
    'salesCount': salesCount,
    'productsCount': productsCount,
    'customersCount': customersCount,
    'rentalItemsCount': rentalItemsCount,
    'rentalSalesCount': rentalSalesCount,
    'fileSizeKb': fileSizeKb,
    'filePath': filePath,
    'isEncrypted': isEncrypted,
  };

  factory BackupHistoryEntry.fromMap(Map<String, dynamic> m) =>
      BackupHistoryEntry(
        createdAt: DateTime.parse(m['createdAt']),
        salesCount: m['salesCount'] ?? 0,
        productsCount: m['productsCount'] ?? 0,
        customersCount: m['customersCount'] ?? 0,
        rentalItemsCount: m['rentalItemsCount'] ?? 0,
        rentalSalesCount: m['rentalSalesCount'] ?? 0,
        fileSizeKb: (m['fileSizeKb'] ?? 0).toDouble(),
        filePath: m['filePath'],
        isEncrypted: m['isEncrypted'] ?? false,
      );

  int get totalRecords =>
      salesCount +
      productsCount +
      customersCount +
      rentalItemsCount +
      rentalSalesCount;

  String get sizeLabel {
    if (fileSizeKb < 1024) return '${fileSizeKb.toStringAsFixed(1)} KB';
    return '${(fileSizeKb / 1024).toStringAsFixed(2)} MB';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class BackupScreen extends StatefulWidget {
  final String userEmail;
  const BackupScreen({super.key, required this.userEmail});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  WhatsAppBackupFrequency _frequency = WhatsAppBackupFrequency.daily;
  NetworkType _networkType = NetworkType.wifiOnly;
  String _googleAccount = '';
  bool _includeMedia = true;
  bool _isEncrypted = false;
  String _encryptionPassword = '';

  bool _isBackingUp = false;
  bool _isRestoring = false;
  double _backupProgress = 0.0;
  String _backupProgressStage = '';

  DateTime? _lastLocalBackupTime;
  DateTime? _lastDriveBackupTime;
  double _lastBackupSizeKb = 0.0;
  int _lastRecordCount = 0;

  bool _isAutoBackupSchedulerActive = false;
  DateTime? _lastAutoSchedulerBackupTime;
  bool _isGoogleDriveConnected = false;
  String _lastBackupStatus = '';
  bool _isDataDirty = false;

  List<BackupHistoryEntry> _history = [];
  List<File> _localBackupFiles = [];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // ── Prefs keys ─────────────────────────────────────────────────────────────
  static const String _kFrequency = 'wa_backup_frequency';
  static const String _kNetwork = 'wa_backup_network';
  static const String _kGoogleAccount = 'wa_backup_account';
  static const String _kIncludeMedia = 'wa_backup_include_media';
  static const String _kIsEncrypted = 'wa_backup_encrypted';
  static const String _kEncPassword = 'wa_backup_password';
  static const String _kLastLocal = 'wa_last_local_backup';
  static const String _kLastDrive = 'wa_last_drive_backup';
  static const String _kLastSize = 'wa_last_backup_size';
  static const String _kLastRecords = 'wa_last_backup_records';
  static const String _kHistory = 'wa_backup_history';

  // ── BizMate Brand Theme Palette ──────────────────────────────────────────
  static const Color brandPrimary = Color(0xFF2563EB); // Royal Blue
  static const Color brandDark = Color(0xFF1D4ED8); // Deep Cobalt
  static const Color brandNavy = Color(0xFF1E3A8A); // Dark Navy
  static const Color brandAccent = Color(0xFF38BDF8); // Sky Blue
  static const Color brandSuccess = Color(0xFF10B981); // Emerald / Active

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadPrefs();
    _scanLocalBackups();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PREFERENCES
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final freqIdx = prefs.getInt(_kFrequency) ?? 2; // daily default
    final netIdx = prefs.getInt(_kNetwork) ?? 0;
    var account = prefs.getString(_kGoogleAccount) ?? widget.userEmail;
    final includeMedia = prefs.getBool(_kIncludeMedia) ?? true;
    final isEnc = prefs.getBool(_kIsEncrypted) ?? false;
    final encPass = prefs.getString(_kEncPassword) ?? '';

    final lastLocalStr = prefs.getString(_kLastLocal);
    final lastDriveStr = prefs.getString(_kLastDrive);
    final lastSize = prefs.getDouble(_kLastSize) ?? 0.0;
    final lastRecords = prefs.getInt(_kLastRecords) ?? 0;
    final historyRaw = prefs.getStringList(_kHistory) ?? [];

    final isSchedulerActive = await BackupScheduler.isEnabled();
    final lastAutoTime = await BackupScheduler.lastAutoBackupTime();

    bool driveConnected = DriveBackupService.isSignedIn;
    if (!driveConnected) {
      try {
        final driveUser = await DriveBackupService.signInSilently();
        if (driveUser != null) {
          driveConnected = true;
          if (driveUser.email.isNotEmpty) {
            account = driveUser.email;
            await prefs.setString(_kGoogleAccount, account);
          }
        }
      } catch (_) {}
    }

    final parsedFreq =
        WhatsAppBackupFrequency.values[freqIdx.clamp(
          0,
          WhatsAppBackupFrequency.values.length - 1,
        )];

    // Ensure scheduler is initialized if frequency is automatic
    if (parsedFreq.isAutomatic && !isSchedulerActive) {
      await BackupScheduler.schedule(
        parsedFreq.index,
        account,
        wifiOnly: netIdx == 0,
      );
    }

    final lastStatus = prefs.getString(kPrefLastStatus) ?? '';
    final isDirty = await BackupScheduler.isDirty();

    setState(() {
      _frequency = parsedFreq;
      _networkType =
          NetworkType.values[netIdx.clamp(0, NetworkType.values.length - 1)];
      _googleAccount = account;
      _includeMedia = includeMedia;
      _isEncrypted = isEnc;
      _encryptionPassword = encPass;

      _isAutoBackupSchedulerActive =
          parsedFreq.isAutomatic || isSchedulerActive;
      _lastAutoSchedulerBackupTime = lastAutoTime;
      _isGoogleDriveConnected = driveConnected;
      _lastBackupStatus = lastStatus;
      _isDataDirty = isDirty;

      _lastLocalBackupTime =
          lastLocalStr != null ? DateTime.tryParse(lastLocalStr) : null;
      _lastDriveBackupTime =
          lastDriveStr != null ? DateTime.tryParse(lastDriveStr) : null;
      _lastBackupSizeKb = lastSize;
      _lastRecordCount = lastRecords;

      _history =
          historyRaw
              .map((e) {
                try {
                  return BackupHistoryEntry.fromMap(jsonDecode(e));
                } catch (_) {
                  return null;
                }
              })
              .whereType<BackupHistoryEntry>()
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  Future<void> _saveFrequency(WhatsAppBackupFrequency freq) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kFrequency, freq.index);
    setState(() => _frequency = freq);

    final targetAccount =
        _googleAccount.isNotEmpty ? _googleAccount : widget.userEmail;

    if (freq.isAutomatic) {
      await BackupScheduler.schedule(
        freq.index,
        targetAccount,
        wifiOnly: _networkType == NetworkType.wifiOnly,
      );
      setState(() => _isAutoBackupSchedulerActive = true);
      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          message:
              'Automatic scheduled backup active: ${freq.label} in background',
        );
      }
    } else {
      await BackupScheduler.cancel();
      setState(() => _isAutoBackupSchedulerActive = false);
      if (mounted) {
        AppSnackBar.showInfo(
          context,
          message: 'Automatic scheduled backup paused.',
        );
      }
    }
  }

  Future<void> _saveNetwork(NetworkType net) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kNetwork, net.index);
    setState(() => _networkType = net);

    if (_frequency.isAutomatic) {
      final targetAccount =
          _googleAccount.isNotEmpty ? _googleAccount : widget.userEmail;
      await BackupScheduler.schedule(
        _frequency.index,
        targetAccount,
        wifiOnly: net == NetworkType.wifiOnly,
      );
    }
  }

  Future<void> _saveGoogleAccount(String acc) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kGoogleAccount, acc);
    setState(() => _googleAccount = acc);

    if (_frequency.isAutomatic) {
      await BackupScheduler.schedule(
        _frequency.index,
        acc,
        wifiOnly: _networkType == NetworkType.wifiOnly,
      );
    }
  }

  Future<void> _saveIncludeMedia(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIncludeMedia, val);
    setState(() => _includeMedia = val);
  }

  Future<void> _saveEncryption(bool enabled, String pass) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsEncrypted, enabled);
    await prefs.setString(_kEncPassword, pass);
    setState(() {
      _isEncrypted = enabled;
      _encryptionPassword = pass;
    });
  }

  Future<void> _recordBackup(BackupHistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final nowIso = entry.createdAt.toIso8601String();
    await prefs.setString(_kLastLocal, nowIso);
    await prefs.setString(_kLastDrive, nowIso);
    await prefs.setDouble(_kLastSize, entry.fileSizeKb);
    await prefs.setInt(_kLastRecords, entry.totalRecords);

    final current = prefs.getStringList(_kHistory) ?? [];
    current.insert(0, jsonEncode(entry.toMap()));
    final trimmed = current.take(15).toList();
    await prefs.setStringList(_kHistory, trimmed);

    setState(() {
      _lastLocalBackupTime = entry.createdAt;
      _lastDriveBackupTime = entry.createdAt;
      _lastBackupSizeKb = entry.fileSizeKb;
      _lastRecordCount = entry.totalRecords;
      _history.insert(0, entry);
      if (_history.length > 15) _history = _history.take(15).toList();
    });

    _scanLocalBackups();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DIRECTORY & LOCAL BACKUP SCAN
  // ─────────────────────────────────────────────────────────────────────────
  Future<Directory> _getBackupDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${docDir.path}/BizMate_Backups');
    if (!backupDir.existsSync()) {
      backupDir.createSync(recursive: true);
    }
    return backupDir;
  }

  Future<void> _scanLocalBackups() async {
    try {
      final dir = await _getBackupDirectory();
      final files =
          dir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.json'))
              .toList()
            ..sort(
              (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
            );
      if (mounted) {
        setState(() => _localBackupFiles = files);
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  // USER HIVE BOX
  // ─────────────────────────────────────────────────────────────────────────
  Future<Box> _openUserBox() async {
    final safeEmail = widget.userEmail
        .replaceAll('.', '_')
        .replaceAll('@', '_');
    final boxName = 'userdata_$safeEmail';
    if (Hive.isBoxOpen(boxName)) return Hive.box(boxName);
    return Hive.openBox(boxName);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BACKUP EXECUTION
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _runBackup({bool shareDirectlyToWhatsApp = false}) async {
    if (_isBackingUp || _isRestoring) return;

    setState(() {
      _isBackingUp = true;
      _backupProgress = 0.05;
      _backupProgressStage = 'Initializing secure backup…';
    });

    try {
      await Future.delayed(const Duration(milliseconds: 250));
      final box = await _openUserBox();

      // Stage 1: Load records
      setState(() {
        _backupProgress = 0.20;
        _backupProgressStage = 'Gathering sales & invoices…';
      });
      final sales = List<Sale>.from(box.get('sales', defaultValue: <Sale>[]));

      setState(() {
        _backupProgress = 0.35;
        _backupProgressStage = 'Gathering products & inventory…';
      });
      final products = List<Product>.from(
        box.get('products', defaultValue: <Product>[]),
      );

      setState(() {
        _backupProgress = 0.50;
        _backupProgressStage = 'Gathering customer directory…';
      });
      final customers = List<CustomerModel>.from(
        box.get('customers', defaultValue: <CustomerModel>[]),
      );

      setState(() {
        _backupProgress = 0.65;
        _backupProgressStage = 'Gathering rental items & bookings…';
      });
      final rentalItems = List<RentalItem>.from(
        box.get('rental_items', defaultValue: <RentalItem>[]),
      );
      final rentalSales = List<RentalSaleModel>.from(
        box.get('rental_sales', defaultValue: <RentalSaleModel>[]),
      );

      // Stage 2: Create payload
      setState(() {
        _backupProgress = 0.78;
        _backupProgressStage = 'Packaging business database…';
      });

      final now = DateTime.now();
      final backupPayload = {
        'appName': 'BizMate',
        'format': 'WhatsApp_Style_Backup',
        'version': 3,
        'exportedAt': now.toIso8601String(),
        'userEmail': widget.userEmail,
        'googleAccount': _googleAccount,
        'includeMedia': _includeMedia,
        'isEncrypted': _isEncrypted,
        'sales':
            sales
                .map(
                  (s) => {
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
                  },
                )
                .toList(),
        'products':
            products.map((p) => {'name': p.name, 'rate': p.rate}).toList(),
        'customers':
            customers
                .map(
                  (c) => {
                    'name': c.name,
                    'phone': c.phone,
                    'createdAt': c.createdAt.toIso8601String(),
                    'rentals':
                        c.rentals
                            .map(
                              (r) => {
                                'from': r.from.toIso8601String(),
                                'to': r.to.toIso8601String(),
                              },
                            )
                            .toList(),
                  },
                )
                .toList(),
        'rentalItems':
            rentalItems
                .map(
                  (r) => {
                    'name': r.name,
                    'brand': r.brand,
                    'category': r.category,
                    'price': r.price,
                    'availability': r.availability,
                    'imagePath': _includeMedia ? r.imagePath : '',
                    'condition': r.condition,
                  },
                )
                .toList(),
        'rentalSales':
            rentalSales
                .map(
                  (rs) => {
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
                  },
                )
                .toList(),
      };

      String finalJsonContent;
      if (_isEncrypted && _encryptionPassword.isNotEmpty) {
        setState(() {
          _backupProgress = 0.85;
          _backupProgressStage = 'Applying end-to-end PIN encryption…';
        });
        final rawJson = jsonEncode(backupPayload);
        final encryptedData = _encryptString(rawJson, _encryptionPassword);
        final envelope = {
          'appName': 'BizMate',
          'isEncrypted': true,
          'version': 3,
          'exportedAt': now.toIso8601String(),
          'userEmail': widget.userEmail,
          'encryptedPayload': encryptedData,
        };
        finalJsonContent = const JsonEncoder.withIndent('  ').convert(envelope);
      } else {
        finalJsonContent = const JsonEncoder.withIndent(
          '  ',
        ).convert(backupPayload);
      }

      // Stage 3: Save to persistent directory
      setState(() {
        _backupProgress = 0.90;
        _backupProgressStage = 'Saving to device archive…';
      });

      final backupDir = await _getBackupDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(now);
      final backupFile = File('${backupDir.path}/BizMate_Backup_$dateStr.json');
      await backupFile.writeAsString(finalJsonContent);
      final sizeKb = backupFile.lengthSync() / 1024;

      // Stage 4: Record history entry
      final entry = BackupHistoryEntry(
        createdAt: now,
        salesCount: sales.length,
        productsCount: products.length,
        customersCount: customers.length,
        rentalItemsCount: rentalItems.length,
        rentalSalesCount: rentalSales.length,
        fileSizeKb: sizeKb,
        filePath: backupFile.path,
        isEncrypted: _isEncrypted,
      );
      await _recordBackup(entry);

      // Stage 5: Upload & Share Sheet
      String? driveFileId;
      bool driveUploaded = false;

      if (!shareDirectlyToWhatsApp) {
        setState(() {
          _backupProgress = 0.93;
          _backupProgressStage = 'Connecting to Google Drive…';
        });

        // Ensure Drive session
        if (!DriveBackupService.isSignedIn) {
          await DriveBackupService.signInSilently();
        }

        if (!DriveBackupService.isSignedIn) {
          setState(() {
            _backupProgressStage = 'Prompting Google Drive sign-in…';
          });
          try {
            await DriveBackupService.signIn();
          } catch (_) {}
        }

        if (DriveBackupService.isSignedIn) {
          setState(() {
            _backupProgress = 0.96;
            _backupProgressStage =
                'Uploading to Drive folder "BizMate Backups"…';
          });
          driveFileId = await DriveBackupService.uploadBackupFile(backupFile);
          if (driveFileId != null && driveFileId.isNotEmpty) {
            driveUploaded = true;
            final nowIso = now.toIso8601String();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_kLastDrive, nowIso);
            await prefs.setString(kPrefLastAuto, nowIso);
            await prefs.setDouble(kPrefLastSize, sizeKb);
            await prefs.setInt(kPrefLastRecords, entry.totalRecords);
            await prefs.setString(kPrefLastStatus, 'Success');
            await BackupScheduler.clearDirty();
            setState(() {
              _lastDriveBackupTime = now;
              _lastBackupSizeKb = sizeKb;
              _lastRecordCount = entry.totalRecords;
              _isGoogleDriveConnected = true;
              _lastBackupStatus = 'Success';
              _isDataDirty = false;
            });
          } else {
            final err = DriveBackupService.lastUploadError ?? 'Google Drive upload failed';
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(kPrefLastStatus, err);
            setState(() {
              _lastBackupStatus = err;
            });
          }
        }
      }

      setState(() {
        _backupProgress = 1.0;
        _backupProgressStage = 'Backup successfully completed!';
      });

      if (mounted) {
        if (shareDirectlyToWhatsApp) {
          final shareText =
              'BizMate Business Backup ($dateStr). Keep this file safe to restore sales & rental records.';
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(backupFile.path)],
              text: shareText,
            ),
          );
        } else if (driveUploaded) {
          AppSnackBar.showSuccess(
            context,
            message:
                '✅ Backed up & uploaded to Google Drive ("BizMate Backups")!',
          );
        } else {
          AppSnackBar.showSuccess(
            context,
            message: 'Data backup saved to device storage!',
          );
          final shareText =
              'BizMate Data Backup ($dateStr) - ${_googleAccount.isNotEmpty ? _googleAccount : widget.userEmail}';
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(backupFile.path)],
              text: shareText,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: 'Backup failed: $e');
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() {
          _isBackingUp = false;
          _backupProgress = 0.0;
          _backupProgressStage = '';
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ENCRYPTION
  // ─────────────────────────────────────────────────────────────────────────
  String _encryptString(String text, String key) {
    final textBytes = utf8.encode(text);
    final keyBytes = utf8.encode(key);
    final encryptedBytes = List<int>.generate(textBytes.length, (i) {
      return textBytes[i] ^ keyBytes[i % keyBytes.length];
    });
    return base64.encode(encryptedBytes);
  }

  String _decryptString(String base64Text, String key) {
    final encryptedBytes = base64.decode(base64Text);
    final keyBytes = utf8.encode(key);
    final decryptedBytes = List<int>.generate(encryptedBytes.length, (i) {
      return encryptedBytes[i] ^ keyBytes[i % keyBytes.length];
    });
    return utf8.decode(decryptedBytes);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RESTORE EXECUTION
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _restoreFromFile([File? targetFile]) async {
    if (_isBackingUp || _isRestoring) return;

    try {
      File? file = targetFile;
      if (file == null) {
        FilePickerResult? result;
        try {
          result = await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['json'],
          );
        } catch (_) {
          result = await FilePicker.pickFiles(type: FileType.any);
        }
        if (result == null || result.files.single.path == null) return;
        file = File(result.files.single.path!);
      }

      final content = await file.readAsString();
      Map<String, dynamic> rawData;
      try {
        rawData = jsonDecode(content) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Restore JSON parse error: $e');
        if (mounted) {
          AppSnackBar.showError(
            context,
            message: 'Unable to parse backup file format: Invalid JSON.',
          );
        }
        return;
      }

      Map<String, dynamic> data = rawData;
      if (rawData['isEncrypted'] == true &&
          rawData.containsKey('encryptedPayload')) {
        final password = await _promptPasswordDialog(
          context,
          title: 'Encrypted Backup',
          message:
              'This backup is protected with end-to-end encryption. Enter your secret PIN to restore.',
        );
        if (password == null || password.isEmpty) return;

        try {
          final decrypted = _decryptString(
            rawData['encryptedPayload'],
            password,
          );
          data = jsonDecode(decrypted) as Map<String, dynamic>;
        } catch (_) {
          if (mounted) {
            AppSnackBar.showError(
              context,
              message: 'Incorrect PIN! Decryption failed.',
            );
          }
          return;
        }
      }

      final salesRaw = data['sales'] ?? data['Sales'];
      final productsRaw = data['products'] ?? data['Products'];
      final customersRaw = data['customers'] ?? data['Customers'];
      final rentalItemsRaw =
          data['rentalItems'] ?? data['rental_items'] ?? data['RentalItems'];
      final rentalSalesRaw =
          data['rentalSales'] ?? data['rental_sales'] ?? data['RentalSales'];

      if (salesRaw == null &&
          productsRaw == null &&
          customersRaw == null &&
          rentalItemsRaw == null &&
          rentalSalesRaw == null) {
        if (mounted) {
          AppSnackBar.showError(
            context,
            message: 'Invalid BizMate backup archive: No recognizable records found.',
          );
        }
        return;
      }

      final salesCount = (salesRaw as List?)?.length ?? 0;
      final productsCount = (productsRaw as List?)?.length ?? 0;
      final customersCount = (customersRaw as List?)?.length ?? 0;
      final rentalItemsCount = (rentalItemsRaw as List?)?.length ?? 0;
      final rentalSalesCount = (rentalSalesRaw as List?)?.length ?? 0;
      final exportedAt =
          data['exportedAt'] != null
              ? DateTime.tryParse(data['exportedAt'].toString())
              : null;

      if (!mounted) return;

      final restoreMode = await _showModernRestoreDialog(
        context,
        exportedAt: exportedAt,
        salesCount: salesCount,
        productsCount: productsCount,
        customersCount: customersCount,
        rentalItemsCount: rentalItemsCount,
        rentalSalesCount: rentalSalesCount,
        fileName: file.path.split(Platform.pathSeparator).last,
      );

      if (restoreMode == null) {
        if (mounted) {
          AppSnackBar.showInfo(context, message: 'Restore cancelled.');
        }
        return;
      }

      setState(() {
        _isRestoring = true;
        _backupProgress = 0.05;
        _backupProgressStage = 'Creating pre-restore safety copy…';
      });

      // Create a safety snapshot of current local records before modifying database
      await BackupScheduler.createSafetySnapshot(widget.userEmail);

      setState(() {
        _backupProgress = 0.1;
        _backupProgressStage = 'Opening database…';
      });

      final box = await _openUserBox();
      int restoredTotal = 0;

      double safeToDouble(dynamic val) {
        if (val == null) return 0.0;
        if (val is num) return val.toDouble();
        return double.tryParse(val.toString()) ?? 0.0;
      }

      int safeToInt(dynamic val) {
        if (val == null) return 0;
        if (val is num) return val.toInt();
        return int.tryParse(val.toString()) ?? 0;
      }

      // ── 1. Sales ──
      setState(() {
        _backupProgress = 0.25;
        _backupProgressStage = 'Restoring sales & invoices…';
      });
      if (salesRaw is List) {
        final existing =
            restoreMode == 'merge'
                ? List<Sale>.from(box.get('sales', defaultValue: <Sale>[]))
                : <Sale>[];
        for (final raw in salesRaw) {
          try {
            if (raw is! Map) continue;
            final item = Map<String, dynamic>.from(raw);
            final payments = <Payment>[];
            if (item['paymentHistory'] is List) {
              for (final p in item['paymentHistory'] as List) {
                try {
                  if (p is Map) {
                    payments.add(Payment(
                      amount: safeToDouble(p['amount']),
                      date: DateTime.tryParse(p['date']?.toString() ?? '') ??
                          DateTime.now(),
                      mode: p['mode']?.toString() ?? 'Cash',
                    ));
                  }
                } catch (_) {}
              }
            }

            final evDates = <DateTime>[];
            if (item['eventDates'] is List) {
              for (final d in item['eventDates'] as List) {
                final parsed = DateTime.tryParse(d.toString());
                if (parsed != null) evDates.add(parsed);
              }
            }

            final compEvDates = <DateTime>[];
            if (item['completedEventDates'] is List) {
              for (final d in item['completedEventDates'] as List) {
                final parsed = DateTime.tryParse(d.toString());
                if (parsed != null) compEvDates.add(parsed);
              }
            }

            List<String>? delHist;
            if (item['deliveryStatusHistory'] is List) {
              delHist = (item['deliveryStatusHistory'] as List)
                  .map((e) => e.toString())
                  .toList();
            }

            existing.add(
              Sale(
                customerName: item['customerName']?.toString() ?? '',
                customerAddress:
                    item['customerAddress']?.toString() ??
                    item['address']?.toString() ??
                    '',
                phoneNumber: item['phoneNumber']?.toString() ?? '',
                productName: item['productName']?.toString() ?? '',
                item: item['item']?.toString() ?? '',
                amount: safeToDouble(item['amount']),
                totalAmount: safeToDouble(item['totalAmount']),
                discount: safeToDouble(item['discount']),
                paymentMode: item['paymentMode']?.toString() ?? 'Cash',
                dateTime:
                    DateTime.tryParse(item['dateTime']?.toString() ?? '') ??
                    DateTime.now(),
                paymentHistory: payments,
                deliveryStatus:
                    item['deliveryStatus']?.toString() ??
                    'All Non Editing Images',
                deliveryLink: item['deliveryLink']?.toString() ?? '',
                deliveryStatusHistory: delHist,
                eventDates: evDates,
                completedEventDates: compEvDates,
                tax: safeToDouble(item['tax']),
              ),
            );
            restoredTotal++;
          } catch (e) {
            debugPrint('Error restoring sale record: $e');
          }
        }
        await box.put('sales', existing);
      }

      // ── 2. Products ──
      setState(() {
        _backupProgress = 0.45;
        _backupProgressStage = 'Restoring catalog products…';
      });
      if (productsRaw is List) {
        final existing =
            restoreMode == 'merge'
                ? List<Product>.from(
                  box.get('products', defaultValue: <Product>[]),
                )
                : <Product>[];
        for (final raw in productsRaw) {
          try {
            if (raw is! Map) continue;
            final item = Map<String, dynamic>.from(raw);
            existing.add(
              Product(
                item['name']?.toString() ?? '',
                safeToDouble(item['rate']),
              ),
            );
            restoredTotal++;
          } catch (e) {
            debugPrint('Error restoring product record: $e');
          }
        }
        await box.put('products', existing);
      }

      // ── 3. Customers ──
      setState(() {
        _backupProgress = 0.65;
        _backupProgressStage = 'Restoring customer accounts…';
      });
      if (customersRaw is List) {
        final existing =
            restoreMode == 'merge'
                ? List<CustomerModel>.from(
                  box.get('customers', defaultValue: <CustomerModel>[]),
                )
                : <CustomerModel>[];
        for (final raw in customersRaw) {
          try {
            if (raw is! Map) continue;
            final item = Map<String, dynamic>.from(raw);
            final rentalsList = <RentalBooking>[];
            if (item['rentals'] is List) {
              for (final r in item['rentals'] as List) {
                try {
                  if (r is Map) {
                    rentalsList.add(
                      RentalBooking(
                        from:
                            DateTime.tryParse(r['from']?.toString() ?? '') ??
                            DateTime.now(),
                        to:
                            DateTime.tryParse(r['to']?.toString() ?? '') ??
                            DateTime.now(),
                      ),
                    );
                  }
                } catch (_) {}
              }
            }
            existing.add(
              CustomerModel(
                name: item['name']?.toString() ?? '',
                phone: item['phone']?.toString() ?? '',
                createdAt:
                    DateTime.tryParse(item['createdAt']?.toString() ?? '') ??
                    DateTime.now(),
                rentals: rentalsList,
              ),
            );
            restoredTotal++;
          } catch (e) {
            debugPrint('Error restoring customer record: $e');
          }
        }
        await box.put('customers', existing);
      }

      // ── 4. Rental Items ──
      setState(() {
        _backupProgress = 0.80;
        _backupProgressStage = 'Restoring camera rental items…';
      });
      if (rentalItemsRaw is List) {
        final existing =
            restoreMode == 'merge'
                ? List<RentalItem>.from(
                  box.get('rental_items', defaultValue: <RentalItem>[]),
                )
                : <RentalItem>[];
        for (final raw in rentalItemsRaw) {
          try {
            if (raw is! Map) continue;
            final item = Map<String, dynamic>.from(raw);
            existing.add(
              RentalItem(
                name: item['name']?.toString() ?? '',
                brand: item['brand']?.toString() ?? '',
                category: item['category']?.toString() ?? '',
                price: safeToDouble(item['price']),
                availability:
                    item['availability']?.toString() ?? 'Available',
                imagePath: item['imagePath']?.toString() ?? '',
                condition: item['condition']?.toString() ?? 'Good',
              ),
            );
            restoredTotal++;
          } catch (e) {
            debugPrint('Error restoring rental item record: $e');
          }
        }
        await box.put('rental_items', existing);
      }

      // ── 5. Rental Sales ──
      setState(() {
        _backupProgress = 0.95;
        _backupProgressStage = 'Restoring rental bookings…';
      });
      if (rentalSalesRaw is List) {
        final existing =
            restoreMode == 'merge'
                ? List<RentalSaleModel>.from(
                  box.get('rental_sales', defaultValue: <RentalSaleModel>[]),
                )
                : <RentalSaleModel>[];
        for (final raw in rentalSalesRaw) {
          try {
            if (raw is! Map) continue;
            final item = Map<String, dynamic>.from(raw);
            final payments = <Payment>[];
            if (item['paymentHistory'] is List) {
              for (final p in item['paymentHistory'] as List) {
                try {
                  if (p is Map) {
                    payments.add(Payment(
                      amount: safeToDouble(p['amount']),
                      date:
                          DateTime.tryParse(p['date']?.toString() ?? '') ??
                          DateTime.now(),
                      mode: p['mode']?.toString() ?? 'Cash',
                    ));
                  }
                } catch (_) {}
              }
            }
            existing.add(
              RentalSaleModel(
                id:
                    item['id']?.toString() ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                customerName: item['customerName']?.toString() ?? '',
                customerPhone: item['customerPhone']?.toString() ?? '',
                itemName: item['itemName']?.toString() ?? '',
                ratePerDay: safeToDouble(item['ratePerDay']),
                numberOfDays: safeToInt(item['numberOfDays']).clamp(1, 9999),
                totalCost: safeToDouble(item['totalCost']),
                amountPaid: safeToDouble(item['amountPaid']),
                paymentMode: item['paymentMode']?.toString() ?? 'Cash',
                fromDateTime:
                    DateTime.tryParse(item['fromDateTime']?.toString() ?? '') ??
                    DateTime.now(),
                toDateTime:
                    DateTime.tryParse(item['toDateTime']?.toString() ?? '') ??
                    DateTime.now(),
                paymentHistory: payments,
                tax: safeToDouble(item['tax']),
              ),
            );
            restoredTotal++;
          } catch (e) {
            debugPrint('Error restoring rental booking record: $e');
          }
        }
        await box.put('rental_sales', existing);
      }

      setState(() {
        _backupProgress = 1.0;
        _backupProgressStage = 'Restore complete!';
        _lastRecordCount = restoredTotal;
      });

      // Refresh preferences, scan local backup files, and update UI
      await _scanLocalBackups();
      await _loadPrefs();

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          message: 'Restored $restoredTotal business records successfully!',
        );
      }
    } catch (e, st) {
      debugPrint('Restore execution error: $e\n$st');
      if (mounted) {
        AppSnackBar.showError(context, message: 'Restore failed: $e');
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() {
          _isRestoring = false;
          _backupProgress = 0.0;
          _backupProgressStage = '';
        });
      }
    }
  }

  Future<void> _connectGoogleDrive() async {
    try {
      final resp = await DriveBackupService.signInDetailed();
      if (resp.isSuccess && resp.account != null) {
        await _saveGoogleAccount(resp.account!.email);
        setState(() {
          _isGoogleDriveConnected = true;
        });
        if (mounted) {
          AppSnackBar.showSuccess(
            context,
            message: 'Connected to Google Drive as ${resp.account!.email}',
          );
        }
        return;
      }

      if (resp.isCanceled) {
        if (mounted) {
          AppSnackBar.showInfo(context, message: 'Google Sign-In was canceled');
        }
        return;
      }

      if (resp.isMissingPlugin) {
        if (mounted) {
          _showMissingPluginDialog();
        }
        return;
      }

      if (resp.isDeveloperError) {
        if (mounted) {
          _showGoogleCloudConfigDialog();
        }
        return;
      }

      if (mounted) {
        AppSnackBar.showError(
          context,
          message: 'Sign-in error: ${resp.errorMessage ?? "Could not connect to Google"}',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: 'Google Sign-In failed: $e');
      }
    }
  }

  void _showMissingPluginDialog() {
    final isDark = context.isDark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.restart_alt_rounded, color: Colors.amber, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Full Restart Required',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Native plugins for Google Drive & WorkManager were recently added.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Flutter hot-restart cannot load newly added native Android libraries.\n\n'
                '👉 Please stop the app completely (press "q" in terminal or click Stop ⏹) and run "flutter run".',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: brandPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showGoogleCloudConfigDialog() {
    final isDark = context.isDark;
    final fallbackController = TextEditingController(
      text: _googleAccount.isNotEmpty ? _googleAccount : widget.userEmail,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4285F4).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const FaIcon(FontAwesomeIcons.googleDrive, color: Color(0xFF4285F4), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Google Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your Google account email to link with BizMate for cloud backup storage and notifications:',
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: fallbackController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Google Account Email',
                hintText: 'name@gmail.com',
                prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final email = fallbackController.text.trim();
              if (email.isNotEmpty) {
                _saveGoogleAccount(email);
                setState(() => _isGoogleDriveConnected = true);
              }
              Navigator.pop(ctx);
              AppSnackBar.showSuccess(
                context,
                message: 'Account configured: $email',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save Account'),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialCopyTile({
    required bool isDark,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16),
            color: const Color(0xFF4285F4),
            tooltip: 'Copy $title',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              AppSnackBar.showSuccess(context, message: 'Copied $title to clipboard!');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _disconnectGoogleDrive() async {
    await DriveBackupService.signOut();
    setState(() {
      _isGoogleDriveConnected = false;
    });
    if (mounted) {
      AppSnackBar.showInfo(context, message: 'Google Drive disconnected');
    }
  }

  /// Exports the latest backup file directly to the Google Drive app via system share
  /// without requiring Firebase or Google Cloud API setup.
  Future<void> _exportToGoogleDriveApp() async {
    try {
      File? targetFile;
      if (_localBackupFiles.isNotEmpty) {
        targetFile = _localBackupFiles.first;
      }

      if (targetFile == null || !targetFile.existsSync()) {
        await _runBackup();
        if (_localBackupFiles.isNotEmpty) {
          targetFile = _localBackupFiles.first;
        }
      }

      if (targetFile != null && targetFile.existsSync()) {
        final fileName = targetFile.path.split('/').last;
        final xFile = XFile(
          targetFile.path,
          mimeType: 'application/json',
          name: fileName,
        );
        await SharePlus.instance.share(
          ShareParams(
            files: [xFile],
            subject: 'BizMate Backup - Save to Google Drive',
            text:
                'BizMate Data Backup ($fileName). Save this to your Google Drive folder.',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: 'Could not open Google Drive: $e');
      }
    }
  }

  Future<void> _testAutoBackupNow() async {
    if (_isBackingUp || _isRestoring) return;
    setState(() {
      _isBackingUp = true;
      _backupProgress = 0.4;
      _backupProgressStage = 'Testing background scheduler…';
    });
    try {
      final account =
          _googleAccount.isNotEmpty ? _googleAccount : widget.userEmail;
      await BackupScheduler.runAutoBackupNow(account);
      await _loadPrefs();
      await _scanLocalBackups();
      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          message:
              '✅ Background auto-backup task executed & notification sent!',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: 'Auto-backup test failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
          _backupProgress = 0.0;
          _backupProgressStage = '';
        });
      }
    }
  }

  Future<void> _restoreFromGoogleDrive() async {
    if (_isBackingUp || _isRestoring) return;

    if (!DriveBackupService.isSignedIn) {
      final silent = await DriveBackupService.signInSilently();
      if (silent != null) {
        await _saveGoogleAccount(silent.email);
        setState(() => _isGoogleDriveConnected = true);
      }
    }

    if (!DriveBackupService.isSignedIn) {
      final resp = await DriveBackupService.signInDetailed();
      if (!resp.isSuccess || resp.account == null) {
        // Do not block the user with technical developer dialogs.
        // Seamlessly open the file picker so they can select their backup from Google Drive or device storage!
        if (mounted) {
          AppSnackBar.showInfo(
            context,
            message: 'Select your backup file from Google Drive or Downloads…',
          );
          await _restoreFromFile();
        }
        return;
      }
      await _saveGoogleAccount(resp.account!.email);
      setState(() => _isGoogleDriveConnected = true);
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Reading Google Drive ("BizMate Backups")…',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    List<DriveBackupFile> driveFiles = [];
    try {
      driveFiles = await DriveBackupService.listDriveBackups();
    } catch (_) {}

    if (mounted) Navigator.pop(context); // Close dialog

    if (!mounted) return;

    if (driveFiles.isEmpty) {
      _showEmptyDriveBackupsSheet();
      return;
    }

    final isDark = context.isDark;

    showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: 640),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4285F4).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const FaIcon(
                        FontAwesomeIcons.googleDrive,
                        color: Color(0xFF4285F4),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Google Drive Backups',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Found ${driveFiles.length} cloud backup(s) in "BizMate Backups":',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: driveFiles.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (c, idx) {
                      final f = driveFiles[idx];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: const Icon(
                          Icons.cloud_download_rounded,
                          color: Color(0xFF2563EB),
                        ),
                        title: Text(
                          f.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          '${DateFormat('dd MMM yyyy, hh:mm a').format(f.createdAt)} • ${f.sizeLabel}',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                isDark
                                    ? const Color(0xFF94A3B8)
                                    : Colors.grey[600],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(ctx);

                                if (!mounted) return;
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => Center(
                                    child: Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 20,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const CircularProgressIndicator(),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Downloading ${f.name} from Google Drive…',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            const Text(
                                              'Please wait, do not close the app…',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );

                                File? downloaded;
                                try {
                                  final tempDir = await getTemporaryDirectory();
                                  final targetFile =
                                      File('${tempDir.path}/${f.name}');
                                  downloaded =
                                      await DriveBackupService.downloadBackupFile(
                                        f.id,
                                        targetFile,
                                      );
                                } catch (e) {
                                  debugPrint('Drive download error: $e');
                                }

                                if (mounted) {
                                  Navigator.of(context, rootNavigator: true)
                                      .pop();
                                }

                                if (downloaded != null &&
                                    await downloaded.exists() &&
                                    await downloaded.length() > 0) {
                                  await _restoreFromFile(downloaded);
                                } else {
                                  if (mounted) {
                                    AppSnackBar.showError(
                                      context,
                                      message:
                                          'Failed to download ${f.name} from Google Drive. Please verify your internet connection or Drive permissions.',
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Restore',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              tooltip: 'Delete from Drive',
                              onPressed: () async {
                                final confirm =
                                    await _showDeleteDriveBackupConfirmation(f.name);
                                if (confirm == true) {
                                  final ok = await DriveBackupService.deleteDriveBackup(f.id);
                                  if (ok && mounted) {
                                    Navigator.pop(ctx);
                                    _restoreFromGoogleDrive();
                                    AppSnackBar.showSuccess(
                                      context,
                                      message: 'Deleted ${f.name} from Google Drive.',
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _restoreFromFile();
                  },
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text('Browse Files from Device / Drive App'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    minimumSize: const Size.fromHeight(42),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEmptyDriveBackupsSheet() {
    final isDark = context.isDark;
    showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: 640),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const FaIcon(
                  FontAwesomeIcons.googleDrive,
                  color: Color(0xFF4285F4),
                  size: 26,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'No Drive Backups Found',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No backup files were found under account ($_googleAccount) in "BizMate Backups". You can create a new backup now or pick an existing JSON file from your device/cloud storage.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _runBackup();
                },
                icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                label: const Text('Back Up to Drive Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _restoreFromFile();
                },
                icon: const Icon(Icons.file_open_rounded, size: 18),
                label: const Text('Select File from Device / Files App'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDriveRestoreFallbackSheet([String? errorReason]) {
    final isDark = context.isDark;
    showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: 640),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4285F4).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.googleDrive,
                      color: Color(0xFF4285F4),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Restore from Cloud / Drive',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                errorReason != null && errorReason.isNotEmpty
                    ? errorReason
                    : 'Select a BizMate backup file directly from your Google Drive app or local storage:',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.file_open_rounded, color: Color(0xFF2563EB)),
                ),
                title: const Text('Select File from Google Drive / Files',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text(
                  'Pick any .json backup saved in Google Drive or Downloads',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _restoreFromFile();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.refresh_rounded, color: Colors.green),
                ),
                title: const Text('Retry Google Sign-In',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Attempt connecting Google account again',
                    style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _restoreFromGoogleDrive();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteDriveBackupConfirmation(String fileName) {
    final isDark = context.isDark;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Cloud Backup?'),
        content: Text(
          'Are you sure you want to permanently delete "$fileName" from your Google Drive?',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MODERN DIALOGS & BOTTOM SHEETS
  // ─────────────────────────────────────────────────────────────────────────
  void _showFrequencyPicker() {
    final isDark = context.isDark;
    showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: 640),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isDark ? brandAccent : brandPrimary)
                              .withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.schedule_rounded,
                          color: isDark ? brandAccent : brandPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Back up to Google Drive',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'Choose automatic sync frequency',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark
                                      ? const Color(0xFF94A3B8)
                                      : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...WhatsAppBackupFrequency.values.map((f) {
                  final isSelected = _frequency == f;
                  final itemBg =
                      isSelected
                          ? (isDark
                              ? brandAccent.withValues(alpha: 0.15)
                              : brandPrimary.withValues(alpha: 0.08))
                          : Colors.transparent;
                  return Material(
                    color: itemBg,
                    child: InkWell(
                      onTap: () {
                        _saveFrequency(f);
                        Navigator.pop(ctx);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked,
                              color:
                                  isSelected
                                      ? (isDark ? brandAccent : brandPrimary)
                                      : (isDark
                                          ? Colors.grey[600]
                                          : Colors.grey[400]),
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                f.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                  color:
                                      isSelected
                                          ? (isDark
                                              ? brandAccent
                                              : brandPrimary)
                                          : (isDark
                                              ? Colors.white
                                              : Colors.black87),
                                ),
                              ),
                            ),
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: (isDark ? brandAccent : brandPrimary)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Active',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? brandAccent : brandPrimary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNetworkPicker() {
    final isDark = context.isDark;
    showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: 640),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF38BDF8,
                          ).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.wifi_rounded,
                          color: Color(0xFF38BDF8),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Back up over network',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'Control cellular data consumption',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark
                                      ? const Color(0xFF94A3B8)
                                      : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...NetworkType.values.map((net) {
                  final isSelected = _networkType == net;
                  final itemBg =
                      isSelected
                          ? (isDark
                              ? brandAccent.withValues(alpha: 0.15)
                              : brandPrimary.withValues(alpha: 0.08))
                          : Colors.transparent;
                  return Material(
                    color: itemBg,
                    child: InkWell(
                      onTap: () {
                        _saveNetwork(net);
                        Navigator.pop(ctx);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked,
                              color:
                                  isSelected
                                      ? (isDark ? brandAccent : brandPrimary)
                                      : (isDark
                                          ? Colors.grey[600]
                                          : Colors.grey[400]),
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                net.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                  color:
                                      isSelected
                                          ? (isDark
                                              ? brandAccent
                                              : brandPrimary)
                                          : (isDark
                                              ? Colors.white
                                              : Colors.black87),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showGoogleAccountDialog() {
    final isDark = context.isDark;
    final controller = TextEditingController(text: _googleAccount);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isSignedIn = DriveBackupService.isSignedIn;
            final currentUser = DriveBackupService.currentUser;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4285F4).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.googleDrive,
                      color: Color(0xFF4285F4),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Google Drive Account',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSignedIn && currentUser != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentUser.displayName ?? 'Google Drive Active',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                Text(
                                  currentUser.email,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _disconnectGoogleDrive();
                        setDialogState(() {});
                      },
                      icon: const Icon(Icons.logout_rounded, size: 16),
                      label: const Text('Disconnect Account'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    _GoogleSignInButton(
                      isDark: isDark,
                      onSuccess: (email) async {
                        await _saveGoogleAccount(email);
                        setState(() => _isGoogleDriveConnected = true);
                        if (mounted) {
                          AppSnackBar.showSuccess(
                            context,
                            message: 'Connected to Google Drive as $email',
                          );
                        }
                      },
                      onMissingPlugin: () => _showMissingPluginDialog(),
                      onDeveloperError: () => _showGoogleCloudConfigDialog(),
                      onError: (msg) {
                        if (mounted) {
                          AppSnackBar.showError(context, message: 'Sign-in error: $msg');
                        }
                      },
                      onCanceled: () {
                        if (mounted) {
                          AppSnackBar.showInfo(context, message: 'Sign-in canceled');
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _exportToGoogleDriveApp();
                      },
                      icon: const FaIcon(FontAwesomeIcons.googleDrive, size: 14, color: Color(0xFF4285F4)),
                      label: const Text('Save to Google Drive App (No Setup)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4285F4),
                        side: const BorderSide(color: Color(0xFF4285F4)),
                        minimumSize: const Size.fromHeight(40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Or configure account email for scheduled backups:',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Account Email',
                      prefixIcon: const Icon(
                        Icons.alternate_email_rounded,
                        size: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : Colors.grey[700],
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isNotEmpty) {
                      _saveGoogleAccount(text);
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Save Account'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEncryptionSettings() {
    final isDark = context.isDark;
    showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: 640),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors:
                          _isEncrypted
                              ? [brandPrimary, brandAccent]
                              : [Colors.grey.shade400, Colors.grey.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isEncrypted ? brandPrimary : Colors.grey)
                            .withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.shield_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'End-to-End Encrypted Backup',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Protect your revenue, transactions, customer phone numbers, and rental assets with password encryption. No one can open the backup file without your secret PIN.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                if (!_isEncrypted)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final pass = await _promptPasswordDialog(
                          context,
                          title: 'Set Backup PIN / Password',
                          message:
                              'Create a 4-6 digit PIN or secret password. You will need it to restore your backup.',
                          isCreate: true,
                        );
                        if (pass != null && pass.length >= 4) {
                          await _saveEncryption(true, pass);
                          AppSnackBar.showSuccess(
                            context,
                            message: 'End-to-end encryption activated!',
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Turn On Protection',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final pass = await _promptPasswordDialog(
                          context,
                          title: 'Disable Encryption',
                          message:
                              'Enter your current backup PIN to disable encryption.',
                        );
                        if (pass == _encryptionPassword) {
                          await _saveEncryption(false, '');
                          AppSnackBar.showSuccess(
                            context,
                            message: 'Encryption turned off.',
                          );
                        } else if (pass != null) {
                          AppSnackBar.showError(
                            context,
                            message: 'Incorrect PIN! Action cancelled.',
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Turn Off Encryption'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _promptPasswordDialog(
    BuildContext context, {
    required String title,
    required String message,
    bool isCreate = false,
  }) {
    final isDark = context.isDark;
    final controller = TextEditingController();
    bool obscure = true;

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.lock_rounded,
                    color: isDark ? brandAccent : brandPrimary,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: obscure,
                    autofocus: true,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          isCreate ? 'New PIN / Password' : 'PIN / Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed:
                            () => setDialogState(() => obscure = !obscure),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : Colors.grey,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _showModernRestoreDialog(
    BuildContext context, {
    DateTime? exportedAt,
    required int salesCount,
    required int productsCount,
    required int customersCount,
    required int rentalItemsCount,
    required int rentalSalesCount,
    required String fileName,
  }) {
    final isDark = context.isDark;
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => Dialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF008069), Color(0xFF10B981)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.cloud_download_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Restore Backup Data',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    exportedAt != null
                        ? 'Created on ${fmt.format(exportedAt)}'
                        : fileName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _metricRow(
                    'Sales & Billing',
                    salesCount,
                    Icons.receipt_long_rounded,
                    const Color(0xFF2563EB),
                    isDark,
                  ),
                  _metricRow(
                    'Products Catalog',
                    productsCount,
                    Icons.inventory_2_rounded,
                    const Color(0xFF7C3AED),
                    isDark,
                  ),
                  _metricRow(
                    'Customer Accounts',
                    customersCount,
                    Icons.people_rounded,
                    const Color(0xFF059669),
                    isDark,
                  ),
                  _metricRow(
                    'Rental Equipment',
                    rentalItemsCount,
                    Icons.camera_alt_rounded,
                    const Color(0xFFD97706),
                    isDark,
                  ),
                  _metricRow(
                    'Rental Bookings',
                    rentalSalesCount,
                    Icons.handshake_rounded,
                    const Color(0xFFDC2626),
                    isDark,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF008069).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF008069).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFF008069),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Merge combines backup with current records safely.',
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  isDark
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFF008069),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, 'replace'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Replace All',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, 'merge'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Merge & Restore',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _metricRow(
    String label,
    int count,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Never';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60 && diff.inMinutes >= 0) {
      if (diff.inMinutes == 0) return 'Just now';
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24 && dt.day == now.day) {
      return 'Today, ${DateFormat('hh:mm a').format(dt)}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.day == yesterday.day &&
        dt.month == yesterday.month &&
        dt.year == yesterday.year) {
      return 'Yesterday, ${DateFormat('hh:mm a').format(dt)}';
    }
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  String _formatSize(double kb) {
    if (kb <= 0) return '0 KB';
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(2)} MB';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final isBusy = _isBackingUp || _isRestoring;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (isDark ? brandAccent : brandPrimary).withValues(
                  alpha: 0.12,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_sync_rounded,
                color: isDark ? brandAccent : brandPrimary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Data Backup & Cloud',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Import from file',
            icon: Icon(
              Icons.file_open_rounded,
              size: 20,
              color: isDark ? brandAccent : brandPrimary,
            ),
            onPressed: isBusy ? null : () => _restoreFromFile(),
          ),
        ],
        bottom:
            isBusy
                ? PreferredSize(
                  preferredSize: const Size.fromHeight(4),
                  child: LinearProgressIndicator(
                    value: _backupProgress > 0 ? _backupProgress : null,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(brandAccent),
                  ),
                )
                : null,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isWide = width >= 900;
          final isTabletPortrait = width >= 600 && width < 900;
          final isVeryCompact = width < 360;

          if (isWide) {
            // ── TABLET / iPAD LANDSCAPE / DESKTOP 2-COLUMN ADAPTIVE DASHBOARD ───────
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1140),
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column (Hero Sync + Quick Actions + Local Storage)
                        Expanded(
                          flex: 11,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildModernHeroCard(isDark, isBusy),
                              const SizedBox(height: 20),
                              _buildQuickActionsRow(isDark, isBusy),
                              const SizedBox(height: 20),
                              _buildLocalStorageCard(isDark, isBusy),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right Column (Cloud Preferences + History Logs)
                        Expanded(
                          flex: 10,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildCloudSettingsCard(isDark),
                              if (_history.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                _buildModernHistoryCard(isDark),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          }

          // ── PHONE & iPAD PORTRAIT RESPONSIVE DASHBOARD ───────────────────
          final maxContentWidth = isTabletPortrait ? 720.0 : 620.0;
          final horizontalPadding =
              isTabletPortrait
                  ? 24.0
                  : (isVeryCompact ? 12.0 : 16.0);

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 16,
                ),
                children: [
                  _buildModernHeroCard(
                    isDark,
                    isBusy,
                    isVeryCompact: isVeryCompact,
                    isTablet: isTabletPortrait,
                  ),
                  const SizedBox(height: 20),
                  _buildQuickActionsRow(
                    isDark,
                    isBusy,
                    isVeryCompact: isVeryCompact,
                    isTablet: isTabletPortrait,
                  ),
                  const SizedBox(height: 20),
                  _buildCloudSettingsCard(
                    isDark,
                    isVeryCompact: isVeryCompact,
                  ),
                  const SizedBox(height: 20),
                  _buildLocalStorageCard(
                    isDark,
                    isBusy,
                    isVeryCompact: isVeryCompact,
                  ),
                  if (_history.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildModernHistoryCard(
                      isDark,
                      isVeryCompact: isVeryCompact,
                    ),
                  ],
                  const SizedBox(height: 36),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MODERN WIDGETS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildModernHeroCard(
    bool isDark,
    bool isBusy, {
    bool isVeryCompact = false,
    bool isTablet = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [brandNavy, brandPrimary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : brandPrimary).withValues(
              alpha: isDark ? 0.35 : 0.25,
            ),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: EdgeInsets.all(isVeryCompact ? 16 : (isTablet ? 26 : 22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: isVeryCompact ? 44 : 50,
                  height: isVeryCompact ? 44 : 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
                    border: Border.all(
                      color: brandAccent.withValues(alpha: 0.8),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.googleDrive,
                      color: Colors.white,
                      size: isVeryCompact ? 20 : 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Cloud & Auto-Sync',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isVeryCompact ? 14 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: brandAccent.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: brandAccent.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Text(
                            _isEncrypted ? 'E2E Encrypted' : 'Active',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_isDataDirty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.6),
                              ),
                            ),
                            child: const Text(
                              'Unsaved Changes',
                              style: TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _lastDriveBackupTime != null
                          ? 'Synced ${_formatDateTime(_lastDriveBackupTime)}'
                          : (_lastLocalBackupTime != null
                              ? 'Local backup ${_formatDateTime(_lastLocalBackupTime)}'
                              : 'No cloud backups uploaded yet'),
                      softWrap: true,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: isVeryCompact ? 11 : 12,
                      ),
                    ),
                    if (_lastBackupStatus.isNotEmpty &&
                        _lastBackupStatus != 'Success')
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Last notice: $_lastBackupStatus',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Metric Grid
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isVeryCompact ? 8 : 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _heroMetric(
                    'Local Storage',
                    _formatDateTime(_lastLocalBackupTime),
                    Icons.phone_android_rounded,
                    isVeryCompact: isVeryCompact,
                  ),
                ),
                Container(width: 1, height: 28, color: Colors.white24),
                Expanded(
                  child: _heroMetric(
                    'Archive Size',
                    _formatSize(_lastBackupSizeKb),
                    Icons.data_usage_rounded,
                    isVeryCompact: isVeryCompact,
                  ),
                ),
                Container(width: 1, height: 28, color: Colors.white24),
                Expanded(
                  child: _heroMetric(
                    'Protected',
                    '$_lastRecordCount recs',
                    Icons.verified_user_rounded,
                    isVeryCompact: isVeryCompact,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Main Action Button
          SizedBox(
            width: double.infinity,
            height: isVeryCompact ? 48 : 52,
            child: ElevatedButton(
              onPressed: isBusy ? null : () => _runBackup(),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? brandAccent : Colors.white,
                foregroundColor: isDark ? const Color(0xFF0F172A) : brandDark,
                elevation: 4,
                shadowColor: (isDark ? brandAccent : Colors.black).withValues(
                  alpha: 0.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child:
                  isBusy
                      ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color:
                                  isDark ? const Color(0xFF0F172A) : brandDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              _backupProgressStage.isNotEmpty
                                  ? _backupProgressStage
                                  : 'Backing up… ${(_backupProgress * 100).toInt()}%',
                              textAlign: TextAlign.center,
                              softWrap: true,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isVeryCompact ? 13 : 14,
                                color:
                                    isDark
                                        ? const Color(0xFF0F172A)
                                        : brandDark,
                              ),
                            ),
                          ),
                        ],
                      )
                      : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.backup_rounded,
                            size: isVeryCompact ? 18 : 20,
                            color: isDark ? const Color(0xFF0F172A) : brandDark,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Back Up Now',
                              textAlign: TextAlign.center,
                              softWrap: true,
                              style: TextStyle(
                                fontSize: isVeryCompact ? 14 : 15,
                                fontWeight: FontWeight.bold,
                                color:
                                    isDark
                                        ? const Color(0xFF0F172A)
                                        : brandDark,
                              ),
                            ),
                          ),
                        ],
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(
    String label,
    String value,
    IconData icon, {
    bool isVeryCompact = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: isVeryCompact ? 11 : 12, color: Colors.white70),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                softWrap: true,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isVeryCompact ? 9 : 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          softWrap: true,
          style: TextStyle(
            color: Colors.white,
            fontSize: isVeryCompact ? 10.5 : 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionTile({
    required bool isDark,
    required bool isBusy,
    required Widget icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required Color borderColor,
    required Color cardBg,
    bool isVeryCompact = false,
  }) {
    return Material(
      color: cardBg,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        onTap: isBusy ? null : onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: isVeryCompact ? 10 : 13,
            horizontal: isVeryCompact ? 8 : 12,
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isVeryCompact ? 7 : 8),
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: icon,
              ),
              SizedBox(width: isVeryCompact ? 8 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      softWrap: true,
                      style: TextStyle(
                        fontSize: isVeryCompact ? 12 : 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      softWrap: true,
                      style: TextStyle(
                        fontSize: isVeryCompact ? 9.5 : 10.5,
                        color:
                            isDark
                                ? const Color(0xFF94A3B8)
                                : Colors.grey[600],
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsRow(
    bool isDark,
    bool isBusy, {
    bool isVeryCompact = false,
    bool isTablet = false,
  }) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final item1 = _buildQuickActionTile(
      isDark: isDark,
      isBusy: isBusy,
      isVeryCompact: isVeryCompact,
      cardBg: cardBg,
      borderColor: borderColor,
      icon: const FaIcon(
        FontAwesomeIcons.whatsapp,
        color: Color(0xFF25D366),
        size: 18,
      ),
      iconBg: const Color(0xFF25D366).withValues(alpha: 0.15),
      title: 'Send to Chat',
      subtitle: 'Share on WhatsApp',
      onTap: () => _runBackup(shareDirectlyToWhatsApp: true),
    );

    final item2 = _buildQuickActionTile(
      isDark: isDark,
      isBusy: isBusy,
      isVeryCompact: isVeryCompact,
      cardBg: cardBg,
      borderColor: borderColor,
      icon: const FaIcon(
        FontAwesomeIcons.googleDrive,
        color: Color(0xFF4285F4),
        size: 18,
      ),
      iconBg: const Color(0xFF4285F4).withValues(alpha: 0.15),
      title: 'Drive Restore',
      subtitle: 'Fetch from Cloud',
      onTap: _restoreFromGoogleDrive,
    );

    final item3 = _buildQuickActionTile(
      isDark: isDark,
      isBusy: isBusy,
      isVeryCompact: isVeryCompact,
      cardBg: cardBg,
      borderColor: borderColor,
      icon: const Icon(
        Icons.file_upload_outlined,
        color: Color(0xFF38BDF8),
        size: 18,
      ),
      iconBg: const Color(0xFF38BDF8).withValues(alpha: 0.15),
      title: 'Import File',
      subtitle: 'Pick JSON file',
      onTap: () => _restoreFromFile(),
    );

    final item4 = _buildQuickActionTile(
      isDark: isDark,
      isBusy: isBusy,
      isVeryCompact: isVeryCompact,
      cardBg: cardBg,
      borderColor: borderColor,
      icon: const Icon(
        Icons.schedule_send_rounded,
        color: Color(0xFF6366F1),
        size: 18,
      ),
      iconBg: const Color(0xFF6366F1).withValues(alpha: 0.15),
      title: 'Test Auto-Sync',
      subtitle: 'Run scheduler now',
      onTap: _testAutoBackupNow,
    );

    final spacing = isVeryCompact ? 8.0 : 12.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: item1),
            SizedBox(width: spacing),
            Expanded(child: item2),
          ],
        ),
        SizedBox(height: isVeryCompact ? 8 : 10),
        Row(
          children: [
            Expanded(child: item3),
            SizedBox(width: spacing),
            Expanded(child: item4),
          ],
        ),
      ],
    );
  }

  Widget _buildCloudSettingsCard(bool isDark, {bool isVeryCompact = false}) {
    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_sync_rounded,
                  size: 20,
                  color: isDark ? brandAccent : brandPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cloud & Google Drive Preferences',
                    softWrap: true,
                    style: TextStyle(
                      fontSize: isVeryCompact ? 13 : 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? brandAccent : brandPrimary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 1. Frequency (Auto Scheduled Backup)
          _modernSettingsTile(
            title: 'Back up to Google Drive',
            subtitle: _frequency.label,
            badge: _frequency.badgeLabel,
            badgeColor:
                _frequency.isAutomatic
                    ? brandSuccess
                    : (isDark ? brandAccent : brandPrimary),
            icon: Icons.calendar_today_rounded,
            color: const Color(0xFF6366F1),
            isDark: isDark,
            onTap: _showFrequencyPicker,
          ),
          _divider(isDark),

          // 2. Google Account (with active status indicator)
          _modernSettingsTile(
            title: 'Google Drive Account',
            subtitle:
                _isGoogleDriveConnected
                    ? 'Connected: $_googleAccount'
                    : (_googleAccount.isNotEmpty
                        ? _googleAccount
                        : 'Tap to connect Google Drive'),
            badge: _isGoogleDriveConnected ? 'Connected' : 'Connect',
            badgeColor:
                _isGoogleDriveConnected
                    ? brandSuccess
                    : const Color(0xFF4285F4),
            icon: Icons.account_circle_rounded,
            color: const Color(0xFF4285F4),
            isDark: isDark,
            onTap: _showGoogleAccountDialog,
          ),
          _divider(isDark),

          // 3. Network Selection
          _modernSettingsTile(
            title: 'Back up over network',
            subtitle: _networkType.label,
            icon: Icons.wifi_rounded,
            color: const Color(0xFF0EA5E9),
            isDark: isDark,
            onTap: _showNetworkPicker,
          ),
          _divider(isDark),

          // 4. Media & Photos Toggle
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 2,
            ),
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.photo_library_rounded,
                size: 18,
                color: Color(0xFFF59E0B),
              ),
            ),
            title: Text(
              'Include Equipment Photos',
              softWrap: true,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              'Include camera and rental catalog images',
              softWrap: true,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
              ),
            ),
            activeColor: isDark ? brandAccent : brandPrimary,
            value: _includeMedia,
            onChanged: _saveIncludeMedia,
          ),
          _divider(isDark),

          // 5. End-to-End Encryption
          _modernSettingsTile(
            title: 'End-to-End Encrypted Backup',
            subtitle:
                _isEncrypted
                    ? 'Locked with secret PIN'
                    : 'Off (Standard protection)',
            badge: _isEncrypted ? 'ON' : 'OFF',
            badgeColor: _isEncrypted ? brandSuccess : Colors.grey,
            icon: _isEncrypted ? Icons.shield_rounded : Icons.lock_open_rounded,
            color: _isEncrypted ? brandSuccess : Colors.grey,
            isDark: isDark,
            onTap: _showEncryptionSettings,
          ),
          _divider(isDark),

          // 6. Automatic Background Scheduler Status
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                    _isAutoBackupSchedulerActive
                        ? (isDark
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : const Color(0xFFE8F5E9))
                        : (isDark
                            ? Colors.black.withValues(alpha: 0.2)
                            : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      _isAutoBackupSchedulerActive
                          ? const Color(0xFF10B981).withValues(alpha: 0.3)
                          : (isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isAutoBackupSchedulerActive
                        ? Icons.schedule_rounded
                        : Icons.pause_circle_outline_rounded,
                    color:
                        _isAutoBackupSchedulerActive
                            ? const Color(0xFF10B981)
                            : Colors.grey,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isAutoBackupSchedulerActive
                              ? 'Auto-Backup Scheduler: Active'
                              : 'Auto-Backup Scheduler: Paused',
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isAutoBackupSchedulerActive
                              ? (_lastAutoSchedulerBackupTime != null
                                  ? 'Last run: ${_formatDateTime(_lastAutoSchedulerBackupTime)} • Runs ${_frequency.label.toLowerCase()} (${_networkType.label})'
                                  : 'WorkManager background task active ${_frequency.label.toLowerCase()} (${_networkType.label})')
                              : 'Select Daily, Weekly, or Monthly above to enable background auto-backups',
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                isDark
                                    ? const Color(0xFF94A3B8)
                                    : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernSettingsTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    final effectiveBadgeColor =
        badgeColor ?? (isDark ? brandAccent : brandPrimary);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(
        title,
        softWrap: true,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        softWrap: true,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: effectiveBadgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: effectiveBadgeColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 13,
            color: Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildLocalStorageCard(
    bool isDark,
    bool isBusy, {
    bool isVeryCompact = false,
  }) {
    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Row(
              children: [
                Icon(
                  Icons.folder_special_rounded,
                  size: 20,
                  color: isDark ? brandAccent : brandPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Detected Device Backups',
                    softWrap: true,
                    style: TextStyle(
                      fontSize: isVeryCompact ? 13 : 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? brandAccent : brandPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (isDark ? brandAccent : brandPrimary).withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_localBackupFiles.length} files',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? brandAccent : brandPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_localBackupFiles.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No local archives found.\nTap "Back Up Now" to save your records on this device.',
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _localBackupFiles.take(4).length,
              separatorBuilder: (_, __) => _divider(isDark),
              itemBuilder: (ctx, i) {
                final file = _localBackupFiles[i];
                final lastMod = file.lastModifiedSync();
                final sizeKb = file.lengthSync() / 1024;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 2,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDark ? brandAccent : brandPrimary).withValues(
                        alpha: 0.12,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.storage_rounded,
                      color: isDark ? brandAccent : brandPrimary,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(lastMod),
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    _formatSize(sizeKb),
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
                    ),
                  ),
                  trailing: ElevatedButton(
                    onPressed: isBusy ? null : () => _restoreFromFile(file),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Restore',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildModernHistoryCard(bool isDark, {bool isVeryCompact = false}) {
    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 20,
                  color: isDark ? brandAccent : brandPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Recent Backup Logs',
                    softWrap: true,
                    style: TextStyle(
                      fontSize: isVeryCompact ? 13 : 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? brandAccent : brandPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Last 5',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _history.take(5).length,
            separatorBuilder: (_, __) => _divider(isDark),
            itemBuilder: (ctx, i) {
              final h = _history[i];
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 2,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: (isDark ? brandAccent : brandPrimary).withValues(
                      alpha: 0.12,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    h.isEncrypted ? Icons.lock_rounded : Icons.check_rounded,
                    color: isDark ? brandAccent : brandPrimary,
                    size: 16,
                  ),
                ),
                title: Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(h.createdAt),
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  '${h.totalRecords} records  ·  ${h.sizeLabel}${h.isEncrypted ? '  ·  PIN Secured' : ''}',
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(
      height: 1,
      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Interactive Google Sign-In button with state & diagnostics
// ─────────────────────────────────────────────────────────────────────────────
class _GoogleSignInButton extends StatefulWidget {
  final bool isDark;
  final ValueChanged<String> onSuccess;
  final VoidCallback onMissingPlugin;
  final VoidCallback onDeveloperError;
  final ValueChanged<String> onError;
  final VoidCallback onCanceled;

  const _GoogleSignInButton({
    required this.isDark,
    required this.onSuccess,
    required this.onMissingPlugin,
    required this.onDeveloperError,
    required this.onError,
    required this.onCanceled,
  });

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> {
  bool _isLoading = false;

  Future<void> _handleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final resp = await DriveBackupService.signInDetailed();
      if (!mounted) return;

      setState(() => _isLoading = false);

      if (resp.isSuccess && resp.account != null) {
        Navigator.of(context).pop();
        widget.onSuccess(resp.account!.email);
      } else if (resp.isCanceled) {
        widget.onCanceled();
      } else if (resp.isMissingPlugin) {
        Navigator.of(context).pop();
        widget.onMissingPlugin();
      } else if (resp.isDeveloperError) {
        Navigator.of(context).pop();
        widget.onDeveloperError();
      } else {
        widget.onError(resp.errorMessage ?? 'Could not complete sign-in');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        widget.onError(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _handleSignIn,
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const FaIcon(FontAwesomeIcons.google, size: 16),
      label: Text(
        _isLoading ? 'Signing in to Google…' : 'Sign in with Google Drive',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4285F4),
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
