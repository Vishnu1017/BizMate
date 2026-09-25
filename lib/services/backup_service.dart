import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/product.dart';
import '../models/rental_item.dart';
import '../models/rental_sale_model.dart';
import '../models/sale.dart';
import '../widgets/app_snackbar.dart';

/// ----------------------------------------------------------------
/// BACKUP, RESTORE & CSV EXPORT SERVICE
/// Complete data safety, JSON export/import & CSV reports
/// ----------------------------------------------------------------
class BackupService {
  /// Export all user business data (Sales, Products, Customers, Rentals) to a JSON file
  static Future<void> exportBackupToJson(
    BuildContext context,
    String userEmail,
  ) async {
    try {
      final safeEmail = userEmail.replaceAll('.', '_').replaceAll('@', '_');
      final userBoxName = 'userdata_$safeEmail';

      Box userBox;
      if (Hive.isBoxOpen(userBoxName)) {
        userBox = Hive.box(userBoxName);
      } else {
        userBox = await Hive.openBox(userBoxName);
      }

      final List<Sale> sales = List<Sale>.from(
        userBox.get("sales", defaultValue: <Sale>[]),
      );
      final List<Product> products = List<Product>.from(
        userBox.get("products", defaultValue: <Product>[]),
      );
      final List<RentalItem> rentalItems = List<RentalItem>.from(
        userBox.get("rental_items", defaultValue: <RentalItem>[]),
      );
      final List<RentalSaleModel> rentalSales = List<RentalSaleModel>.from(
        userBox.get("rental_sales", defaultValue: <RentalSaleModel>[]),
      );

      final Map<String, dynamic> backupData = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'userEmail': userEmail,
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
            products
                .map(
                  (p) => {
                    'name': p.name,
                    'rate': p.rate,
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
                    'imagePath': r.imagePath,
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

      final String jsonString = const JsonEncoder.withIndent(
        '  ',
      ).convert(backupData);
      final tempDir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${tempDir.path}/BizMate_Backup_$dateStr.json');
      await file.writeAsString(jsonString);

      // ignore: deprecated_member_use
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'BizMate Data Backup ($dateStr)');

      if (context.mounted) {
        AppSnackBar.showSuccess(
          context,
          message: 'Data backup created successfully!',
        );
      }
    } catch (e) {
      debugPrint('Export backup error: $e');
      if (context.mounted) {
        AppSnackBar.showError(
          context,
          message: 'Failed to create backup: ${e.toString()}',
        );
      }
    }
  }

  /// Restore user business data from a selected JSON backup file
  static Future<void> importBackupFromJson(
    BuildContext context,
    String userEmail,
  ) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) return;

      final File file = File(result.files.single.path!);
      final String content = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(content);

      if (!data.containsKey('sales') && !data.containsKey('products')) {
        if (context.mounted) {
          AppSnackBar.showError(
            context,
            message: 'Invalid BizMate backup file format.',
          );
        }
        return;
      }

      final safeEmail = userEmail.replaceAll('.', '_').replaceAll('@', '_');
      final userBoxName = 'userdata_$safeEmail';

      Box userBox;
      if (Hive.isBoxOpen(userBoxName)) {
        userBox = Hive.box(userBoxName);
      } else {
        userBox = await Hive.openBox(userBoxName);
      }

      int restoredCount = 0;

      if (data.containsKey('sales') && data['sales'] is List) {
        final List salesData = data['sales'];
        final List<Sale> currentSales = List<Sale>.from(
          userBox.get('sales', defaultValue: <Sale>[]),
        );
        for (var item in salesData) {
          try {
            final sale = Sale(
              customerName: item['customerName'] ?? '',
              phoneNumber: item['phoneNumber'] ?? '',
              productName: item['productName'] ?? '',
              item: item['item'] ?? '',
              amount: (item['amount'] ?? 0.0).toDouble(),
              totalAmount: (item['totalAmount'] ?? 0.0).toDouble(),
              discount: (item['discount'] ?? 0.0).toDouble(),
              paymentMode: item['paymentMode'] ?? 'Cash',
              dateTime:
                  DateTime.tryParse(item['dateTime'] ?? '') ?? DateTime.now(),
            );
            currentSales.add(sale);
            restoredCount++;
          } catch (_) {}
        }
        await userBox.put('sales', currentSales);
      }

      if (data.containsKey('products') && data['products'] is List) {
        final List productsData = data['products'];
        final List<Product> currentProducts = List<Product>.from(
          userBox.get('products', defaultValue: <Product>[]),
        );
        for (var item in productsData) {
          try {
            final product = Product(
              item['name'] ?? '',
              (item['rate'] ?? 0.0).toDouble(),
            );
            currentProducts.add(product);
            restoredCount++;
          } catch (_) {}
        }
        await userBox.put('products', currentProducts);
      }

      if (context.mounted) {
        AppSnackBar.showSuccess(
          context,
          message: 'Successfully restored $restoredCount items from backup!',
        );
      }
    } catch (e) {
      debugPrint('Import backup error: $e');
      if (context.mounted) {
        AppSnackBar.showError(
          context,
          message: 'Failed to restore backup: ${e.toString()}',
        );
      }
    }
  }

  /// Export Sales Report to CSV File
  static Future<void> exportSalesToCsv(
    BuildContext context,
    List<Sale> sales,
  ) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln(
        'Customer Name,Phone Number,Product Name,Item,Amount,Discount,Total Amount,Payment Mode,Date',
      );

      for (var sale in sales) {
        final row = [
          sale.customerName,
          sale.phoneNumber,
          sale.productName,
          sale.item,
          sale.amount,
          sale.discount,
          sale.totalAmount,
          sale.paymentMode,
          DateFormat('yyyy-MM-dd HH:mm').format(sale.dateTime),
        ];
        buffer.writeln(
          row
              .map((e) => '"${e.toString().replaceAll('"', '""')}"')
              .join(','),
        );
      }

      final tempDir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
      final file = File('${tempDir.path}/SalesReport_$dateStr.csv');
      await file.writeAsString(buffer.toString());

      // ignore: deprecated_member_use
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'BizMate Sales Report ($dateStr)');

      if (context.mounted) {
        AppSnackBar.showSuccess(
          context,
          message: 'CSV Sales Report generated successfully!',
        );
      }
    } catch (e) {
      debugPrint('CSV Export error: $e');
      if (context.mounted) {
        AppSnackBar.showError(
          context,
          message: 'Failed to export CSV: ${e.toString()}',
        );
      }
    }
  }
}
