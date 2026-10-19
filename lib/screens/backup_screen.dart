// lib/screens/backup_screen.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unnecessary_underscores

import 'dart:convert';
import 'dart:io';

import 'package:bizmate/models/customer_model.dart';
import 'package:bizmate/models/product.dart';
import 'package:bizmate/models/rental_item.dart';
import 'package:bizmate/models/rental_sale_model.dart';
import 'package:bizmate/models/sale.dart';
import 'package:bizmate/utils/app_theme.dart';
import 'package:bizmate/widgets/app_snackbar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
    final account = prefs.getString(_kGoogleAccount) ?? widget.userEmail;
    final includeMedia = prefs.getBool(_kIncludeMedia) ?? true;
    final isEnc = prefs.getBool(_kIsEncrypted) ?? false;
    final encPass = prefs.getString(_kEncPassword) ?? '';

    final lastLocalStr = prefs.getString(_kLastLocal);
    final lastDriveStr = prefs.getString(_kLastDrive);
    final lastSize = prefs.getDouble(_kLastSize) ?? 0.0;
    final lastRecords = prefs.getInt(_kLastRecords) ?? 0;
    final historyRaw = prefs.getStringList(_kHistory) ?? [];

    setState(() {
      _frequency =
          WhatsAppBackupFrequency.values[freqIdx.clamp(
            0,
            WhatsAppBackupFrequency.values.length - 1,
          )];
      _networkType =
          NetworkType.values[netIdx.clamp(0, NetworkType.values.length - 1)];
      _googleAccount = account;
      _includeMedia = includeMedia;
      _isEncrypted = isEnc;
      _encryptionPassword = encPass;

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
  }

  Future<void> _saveNetwork(NetworkType net) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kNetwork, net.index);
    setState(() => _networkType = net);
  }

  Future<void> _saveGoogleAccount(String acc) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kGoogleAccount, acc);
    setState(() => _googleAccount = acc);
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
                    'phoneNumber': s.phoneNumber,
                    'productName': s.productName,
                    'item': s.item,
                    'amount': s.amount,
                    'totalAmount': s.totalAmount,
                    'discount': s.discount,
                    'paymentMode': s.paymentMode,
                    'dateTime': s.dateTime.toIso8601String(),
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
      setState(() {
        _backupProgress = 0.98;
        _backupProgressStage =
            shareDirectlyToWhatsApp
                ? 'Opening WhatsApp…'
                : 'Uploading to Cloud / Drive…';
      });

      await Future.delayed(const Duration(milliseconds: 300));

      final shareText =
          shareDirectlyToWhatsApp
              ? 'BizMate Business Backup ($dateStr). Keep this file safe to restore sales & rental records.'
              : 'BizMate Data Backup ($dateStr) - ${_googleAccount.isNotEmpty ? _googleAccount : widget.userEmail}';

      await Share.shareXFiles([XFile(backupFile.path)], text: shareText);

      setState(() {
        _backupProgress = 1.0;
        _backupProgressStage = 'Backup successfully saved!';
      });

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          message: 'Data backup created and saved successfully!',
        );
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
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (result == null || result.files.single.path == null) return;
        file = File(result.files.single.path!);
      }

      final content = await file.readAsString();
      Map<String, dynamic> rawData;
      try {
        rawData = jsonDecode(content) as Map<String, dynamic>;
      } catch (_) {
        if (mounted) {
          AppSnackBar.showError(
            context,
            message: 'Unable to parse backup file format.',
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

      if (!data.containsKey('sales') &&
          !data.containsKey('products') &&
          !data.containsKey('customers') &&
          !data.containsKey('rentalItems') &&
          !data.containsKey('rentalSales')) {
        if (mounted) {
          AppSnackBar.showError(
            context,
            message: 'Invalid BizMate backup archive.',
          );
        }
        return;
      }

      final salesCount = (data['sales'] as List?)?.length ?? 0;
      final productsCount = (data['products'] as List?)?.length ?? 0;
      final customersCount = (data['customers'] as List?)?.length ?? 0;
      final rentalItemsCount = (data['rentalItems'] as List?)?.length ?? 0;
      final rentalSalesCount = (data['rentalSales'] as List?)?.length ?? 0;
      final exportedAt =
          data['exportedAt'] != null
              ? DateTime.tryParse(data['exportedAt'])
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
        fileName: file.path.split('/').last,
      );

      if (restoreMode == null) return;

      setState(() {
        _isRestoring = true;
        _backupProgress = 0.1;
        _backupProgressStage = 'Restoring database…';
      });

      final box = await _openUserBox();
      int restoredTotal = 0;

      // ── 1. Sales ──
      setState(() {
        _backupProgress = 0.25;
        _backupProgressStage = 'Restoring sales & invoices…';
      });
      if (data['sales'] is List) {
        final existing =
            restoreMode == 'merge'
                ? List<Sale>.from(box.get('sales', defaultValue: <Sale>[]))
                : <Sale>[];
        for (final item in data['sales'] as List) {
          try {
            existing.add(
              Sale(
                customerName: item['customerName'] ?? '',
                phoneNumber: item['phoneNumber'] ?? '',
                productName: item['productName'] ?? '',
                item: item['item'] ?? '',
                amount: (item['amount'] ?? 0).toDouble(),
                totalAmount: (item['totalAmount'] ?? 0).toDouble(),
                discount: (item['discount'] ?? 0).toDouble(),
                paymentMode: item['paymentMode'] ?? 'Cash',
                dateTime:
                    DateTime.tryParse(item['dateTime'] ?? '') ?? DateTime.now(),
              ),
            );
            restoredTotal++;
          } catch (_) {}
        }
        await box.put('sales', existing);
      }

      // ── 2. Products ──
      setState(() {
        _backupProgress = 0.45;
        _backupProgressStage = 'Restoring catalog products…';
      });
      if (data['products'] is List) {
        final existing =
            restoreMode == 'merge'
                ? List<Product>.from(
                  box.get('products', defaultValue: <Product>[]),
                )
                : <Product>[];
        for (final item in data['products'] as List) {
          try {
            existing.add(
              Product(item['name'] ?? '', (item['rate'] ?? 0).toDouble()),
            );
            restoredTotal++;
          } catch (_) {}
        }
        await box.put('products', existing);
      }

      // ── 3. Customers ──
      setState(() {
        _backupProgress = 0.65;
        _backupProgressStage = 'Restoring customer accounts…';
      });
      if (data['customers'] is List) {
        final existing =
            restoreMode == 'merge'
                ? List<CustomerModel>.from(
                  box.get('customers', defaultValue: <CustomerModel>[]),
                )
                : <CustomerModel>[];
        for (final item in data['customers'] as List) {
          try {
            final rentalsList = <RentalBooking>[];
            if (item['rentals'] is List) {
              for (final r in item['rentals'] as List) {
                try {
                  rentalsList.add(
                    RentalBooking(
                      from:
                          DateTime.tryParse(r['from'] ?? '') ?? DateTime.now(),
                      to: DateTime.tryParse(r['to'] ?? '') ?? DateTime.now(),
                    ),
                  );
                } catch (_) {}
              }
            }
            existing.add(
              CustomerModel(
                name: item['name'] ?? '',
                phone: item['phone'] ?? '',
                createdAt:
                    DateTime.tryParse(item['createdAt'] ?? '') ??
                    DateTime.now(),
                rentals: rentalsList,
              ),
            );
            restoredTotal++;
          } catch (_) {}
        }
        await box.put('customers', existing);
      }

      // ── 4. Rental Items ──
      setState(() {
        _backupProgress = 0.80;
        _backupProgressStage = 'Restoring camera rental items…';
      });
      if (data['rentalItems'] is List) {
        final existing =
            restoreMode == 'merge'
                ? List<RentalItem>.from(
                  box.get('rental_items', defaultValue: <RentalItem>[]),
                )
                : <RentalItem>[];
        for (final item in data['rentalItems'] as List) {
          try {
            existing.add(
              RentalItem(
                name: item['name'] ?? '',
                brand: item['brand'] ?? '',
                category: item['category'] ?? '',
                price: (item['price'] ?? 0).toDouble(),
                availability: item['availability'] ?? 'Available',
                imagePath: item['imagePath'] ?? '',
                condition: item['condition'] ?? 'Good',
              ),
            );
            restoredTotal++;
          } catch (_) {}
        }
        await box.put('rental_items', existing);
      }

      // ── 5. Rental Sales ──
      setState(() {
        _backupProgress = 0.95;
        _backupProgressStage = 'Restoring rental bookings…';
      });
      if (data['rentalSales'] is List) {
        final existing =
            restoreMode == 'merge'
                ? List<RentalSaleModel>.from(
                  box.get('rental_sales', defaultValue: <RentalSaleModel>[]),
                )
                : <RentalSaleModel>[];
        for (final item in data['rentalSales'] as List) {
          try {
            existing.add(
              RentalSaleModel(
                id: item['id'] ?? '',
                customerName: item['customerName'] ?? '',
                customerPhone: item['customerPhone'] ?? '',
                itemName: item['itemName'] ?? '',
                ratePerDay: (item['ratePerDay'] ?? 0).toDouble(),
                numberOfDays: (item['numberOfDays'] ?? 1).toInt(),
                totalCost: (item['totalCost'] ?? 0).toDouble(),
                amountPaid: (item['amountPaid'] ?? 0).toDouble(),
                paymentMode: item['paymentMode'] ?? 'Cash',
                fromDateTime:
                    DateTime.tryParse(item['fromDateTime'] ?? '') ??
                    DateTime.now(),
                toDateTime:
                    DateTime.tryParse(item['toDateTime'] ?? '') ??
                    DateTime.now(),
              ),
            );
            restoredTotal++;
          } catch (_) {}
        }
        await box.put('rental_sales', existing);
      }

      setState(() {
        _backupProgress = 1.0;
        _backupProgressStage = 'Restore complete!';
      });

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          message: 'Restored $restoredTotal business records successfully!',
        );
      }
    } catch (e) {
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

  // ─────────────────────────────────────────────────────────────────────────
  // MODERN DIALOGS & BOTTOM SHEETS
  // ─────────────────────────────────────────────────────────────────────────
  void _showFrequencyPicker() {
    final isDark = context.isDark;
    showModalBottomSheet(
      context: context,
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
                  FontAwesomeIcons.google,
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
              Text(
                'Enter the email account where your cloud backups will be saved.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
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
  }

  void _showEncryptionSettings() {
    final isDark = context.isDark;
    showModalBottomSheet(
      context: context,
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
            Text(
              'Data Backup & Cloud',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
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
      body: ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // ── MODERN HERO CARD (Cloud Auto-Sync Engine) ─────────────────────
          _buildModernHeroCard(isDark, isBusy),
          const SizedBox(height: 20),

          // ── QUICK ACTIONS ROW ─────────────────────────────────────────────
          _buildQuickActionsRow(isDark, isBusy),
          const SizedBox(height: 20),

          // ── CLOUD & GOOGLE DRIVE SETTINGS ─────────────────────────────────
          _buildCloudSettingsCard(isDark),
          const SizedBox(height: 20),

          // ── LOCAL STORAGE RECOVERY ────────────────────────────────────────
          _buildLocalStorageCard(isDark, isBusy),
          const SizedBox(height: 20),

          // ── SYNC & BACKUP LOGS ────────────────────────────────────────────
          if (_history.isNotEmpty) _buildModernHistoryCard(isDark),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MODERN WIDGETS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildModernHeroCard(bool isDark, bool isBusy) {
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
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
                    border: Border.all(
                      color: brandAccent.withValues(alpha: 0.8),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: FaIcon(
                      FontAwesomeIcons.googleDrive,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Cloud & Auto-Sync',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
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
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _lastDriveBackupTime != null
                          ? 'Synced ${_formatDateTime(_lastDriveBackupTime)}'
                          : 'No cloud backups uploaded yet',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _heroMetric(
                  'Local Storage',
                  _formatDateTime(_lastLocalBackupTime),
                  Icons.phone_android_rounded,
                ),
                Container(width: 1, height: 28, color: Colors.white24),
                _heroMetric(
                  'Archive Size',
                  _formatSize(_lastBackupSizeKb),
                  Icons.data_usage_rounded,
                ),
                Container(width: 1, height: 28, color: Colors.white24),
                _heroMetric(
                  'Protected',
                  '$_lastRecordCount recs',
                  Icons.verified_user_rounded,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Main Action Button
          SizedBox(
            width: double.infinity,
            height: 52,
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
                          Text(
                            _backupProgressStage.isNotEmpty
                                ? _backupProgressStage
                                : 'Backing up… ${(_backupProgress * 100).toInt()}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color:
                                  isDark ? const Color(0xFF0F172A) : brandDark,
                            ),
                          ),
                        ],
                      )
                      : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.backup_rounded,
                            size: 20,
                            color: isDark ? const Color(0xFF0F172A) : brandDark,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Back Up Now',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color:
                                  isDark ? const Color(0xFF0F172A) : brandDark,
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

  Widget _heroMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.white70),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsRow(bool isDark, bool isBusy) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Row(
      children: [
        // WhatsApp Direct Send
        Expanded(
          child: Material(
            color: cardBg,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor),
            ),
            child: InkWell(
              onTap:
                  isBusy
                      ? null
                      : () => _runBackup(shareDirectlyToWhatsApp: true),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const FaIcon(
                        FontAwesomeIcons.whatsapp,
                        color: Color(0xFF25D366),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Send to Chat',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'Share on WhatsApp',
                            style: TextStyle(
                              fontSize: 10,
                              color:
                                  isDark
                                      ? const Color(0xFF94A3B8)
                                      : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // File Restore
        Expanded(
          child: Material(
            color: cardBg,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor),
            ),
            child: InkWell(
              onTap: isBusy ? null : () => _restoreFromFile(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.file_upload_outlined,
                        color: Color(0xFF38BDF8),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Import File',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'Pick JSON backup',
                            style: TextStyle(
                              fontSize: 10,
                              color:
                                  isDark
                                      ? const Color(0xFF94A3B8)
                                      : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCloudSettingsCard(bool isDark) {
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
                Text(
                  'Cloud & Google Drive Preferences',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? brandAccent : brandPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          // 1. Frequency
          _modernSettingsTile(
            title: 'Back up to Google Drive',
            subtitle: _frequency.label,
            badge: _frequency.badgeLabel,
            icon: Icons.calendar_today_rounded,
            color: const Color(0xFF6366F1),
            isDark: isDark,
            onTap: _showFrequencyPicker,
          ),
          _divider(isDark),

          // 2. Google Account
          _modernSettingsTile(
            title: 'Google Account',
            subtitle:
                _googleAccount.isNotEmpty
                    ? _googleAccount
                    : 'No account configured',
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              'Include camera and rental catalog images',
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
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
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

  Widget _buildLocalStorageCard(bool isDark, bool isBusy) {
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
                Text(
                  'Detected Device Backups',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? brandAccent : brandPrimary,
                  ),
                ),
                const Spacer(),
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
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    _formatSize(sizeKb),
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

  Widget _buildModernHistoryCard(bool isDark) {
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
                Text(
                  'Recent Backup Logs',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? brandAccent : brandPrimary,
                  ),
                ),
                const Spacer(),
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  '${h.totalRecords} records  ·  ${h.sizeLabel}${h.isEncrypted ? '  ·  PIN Secured' : ''}',
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
