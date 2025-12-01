import 'dart:io';

import 'package:bizmate/models/sale.dart';
import 'package:bizmate/models/user_model.dart';
import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart'; // Add this import

enum DateRangePreset {
  today,
  thisWeek,
  thisMonth,
  thisQuarter,
  thisFinancialYear,
  custom,
}

class SalesReportPage extends StatefulWidget {
  final List<Sale> sales;

  const SalesReportPage({super.key, required this.sales});

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  DateTimeRange? selectedRange;
  DateRangePreset? selectedPreset;

  // Add this function to get current user email from Hive
  Future<String> _getCurrentUserEmailFromHive() async {
    try {
      // Open the users box if not already open
      final usersBox = await Hive.openBox<User>('users');

      // Get the current user from your session or state management
      // This depends on how you're managing the current user in your app

      // Option 1: If you have a session box with current user email
      final sessionBox = await Hive.openBox('session');
      final currentUserEmail = sessionBox.get('currentUserEmail');

      if (currentUserEmail != null) {
        return currentUserEmail;
      }

      // Option 2: If you have only one user in the box
      if (usersBox.isNotEmpty) {
        final user = usersBox.values.first;
        return user.email;
      }

      // Option 3: If you're passing user context somehow
      // You might need to modify this based on your app's architecture

      // Fallback: Return empty string if no user found
      return '';
    } catch (e) {
      debugPrint('Error getting user email from Hive: $e');
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);
    selectedRange = DateTimeRange(start: start, end: end);
    selectedPreset = DateRangePreset.thisMonth;
  }

  void _handlePresetSelection(DateRangePreset preset) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (preset) {
      case DateRangePreset.today:
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day);
        break;
      case DateRangePreset.thisWeek:
        startDate = DateTime(now.year, now.month, now.day - now.weekday + 1);
        endDate = DateTime(now.year, now.month, now.day - now.weekday + 7);
        break;
      case DateRangePreset.thisMonth:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0);
        break;
      case DateRangePreset.thisQuarter:
        final quarter = (now.month - 1) ~/ 3 + 1;
        startDate = DateTime(now.year, (quarter - 1) * 3 + 1, 1);
        endDate = DateTime(now.year, quarter * 3 + 1, 0);
        break;
      case DateRangePreset.thisFinancialYear:
        // Assuming financial year starts in April
        startDate =
            now.month >= 4
                ? DateTime(now.year, 4, 1)
                : DateTime(now.year - 1, 4, 1);
        endDate =
            now.month >= 4
                ? DateTime(now.year + 1, 3, 31)
                : DateTime(now.year, 3, 31);
        break;
      case DateRangePreset.custom:
        _selectDateRange(context);
        return;
    }

    setState(() {
      selectedRange = DateTimeRange(start: startDate, end: endDate);
      selectedPreset = preset;
    });
  }

  Future<void> _generateAndSavePdf(
    BuildContext context,
    List<Sale> sales,
  ) async {
    try {
      final pdf = await _generateSalesReportPdf(sales);
      final directory = await getApplicationDocumentsDirectory();
      final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final fileName =
          'Sale report $currentDate.pdf'; // Changed file name format
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(await pdf.save());

      final result = await OpenFilex.open(file.path);

      if (!mounted) return;

      if (result.type != ResultType.done) {
        AppSnackBar.showInfo(
          context,
          message: 'PDF saved but could not open: $fileName',
          duration: Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(
        context,
        message: 'Failed to generate PDF: ${e.toString()}',
        duration: Duration(seconds: 2),
      );
    }
  }

  // The EXACT same function as before - no changes made
  Future<pw.Document> _generateSalesReportPdf(List<Sale> sales) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'en_IN');

    // ✅ Load Roboto font for ₹ support
    final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final ttf = pw.Font.ttf(fontData.buffer.asByteData());
    final prefs = await SharedPreferences.getInstance();

    // Get current user email from Hive
    final currentUserEmail = await _getCurrentUserEmailFromHive();

    // Use email-specific key for profile image
    final profileImagePath = prefs.getString(
      '${currentUserEmail}_profileImagePath',
    );

    pw.MemoryImage? headerImage;

    if (profileImagePath != null) {
      final profileFile = File(profileImagePath);
      if (await profileFile.exists()) {
        final imageBytes = await profileFile.readAsBytes();
        headerImage = pw.MemoryImage(imageBytes);
      }
    }

    final totalSales = sales.fold(0.0, (sum, s) => sum + s.totalAmount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build:
            (context) => [
              // Header with brand
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey600),
                  borderRadius: pw.BorderRadius.circular(6),
                  color: PdfColor.fromHex('#E0F7FA'),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 55,
                      height: 55,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColors.grey),
                      ),
                      child: pw.Center(
                        child: pw.Container(
                          height: 50,
                          child:
                              headerImage != null
                                  ? pw.Image(headerImage)
                                  : pw.SizedBox(), // Empty when no image
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Shutter Life Photography',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              font: ttf,
                              color: PdfColors.indigo800,
                            ),
                          ),
                          pw.Text(
                            'Phone: +91 63601 20253',
                            style: pw.TextStyle(font: ttf),
                          ),
                          pw.Text(
                            'Email: shutterlifephotography10@gmail.com',
                            style: pw.TextStyle(font: ttf),
                          ),
                          pw.Text(
                            'State: Karnataka - 61',
                            style: pw.TextStyle(font: ttf),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // Report Title
              pw.Center(
                child: pw.Text(
                  'Sales Report',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    decoration: pw.TextDecoration.underline,
                    font: ttf,
                    color: PdfColors.deepPurple,
                  ),
                ),
              ),

              pw.SizedBox(height: 8),

              pw.Text('Username: All Users', style: pw.TextStyle(font: ttf)),
              pw.Text(
                'Duration: From ${getFormattedRange()}',
                style: pw.TextStyle(font: ttf),
              ),

              pw.SizedBox(height: 16),

              // Table
              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  font: ttf,
                ),
                headers: [
                  'Date',
                  'Order No.',
                  'Party Name',
                  'Phone No.',
                  'Txn Type',
                  'Status',
                  'Payment Type',
                  'Paid Amount',
                  'Balance',
                ],
                cellStyle: pw.TextStyle(fontSize: 10, font: ttf),
                columnWidths: {
                  0: pw.FixedColumnWidth(50),
                  1: pw.FixedColumnWidth(40),
                  2: pw.FixedColumnWidth(80),
                  3: pw.FixedColumnWidth(65),
                  4: pw.FixedColumnWidth(40),
                  5: pw.FixedColumnWidth(40),
                  6: pw.FixedColumnWidth(70),
                  7: pw.FixedColumnWidth(60),
                  8: pw.FixedColumnWidth(65),
                },
                data:
                    sales.map((s) {
                      final balance = s.totalAmount - s.amount;
                      return [
                        dateFormat.format(s.dateTime),
                        '-',
                        s.customerName,
                        s.phoneNumber,
                        'Sale',
                        balance <= 0 ? 'Paid' : 'Unpaid',
                        s.paymentMode,
                        currencyFormat.format(s.amount),
                        balance < 0
                            ? "+${currencyFormat.format(balance.abs())}"
                            : currencyFormat.format(balance),
                      ];
                    }).toList(),
              ),

              pw.SizedBox(height: 20),

              // Total Summary Box
              pw.Container(
                alignment: pw.Alignment.centerRight,
                padding: pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  borderRadius: pw.BorderRadius.circular(6),
                  color: PdfColors.indigo50,
                ),
                child: pw.Text(
                  'Total Sale: ${currencyFormat.format(totalSales)}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                    font: ttf,
                    color: PdfColors.indigo900,
                  ),
                ),
              ),
              pw.Spacer(),
              // Footer
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated on: ${DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now())}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                      font: ttf,
                    ),
                  ),
                ],
              ),
            ],
      ),
    );

    return pdf;
  }

  Future<void> _exportToCSV(BuildContext context) async {
    try {
      if (!mounted) return;

      // final scaffoldMessenger = ScaffoldMessenger.of(context);
      final sales = getFilteredSales();

      if (sales.isEmpty) {
        AppSnackBar.showInfo(
          context,
          message: 'No sales data to export',
          duration: Duration(seconds: 2),
        );
        return;
      }

      // Show loading indicator
      AppSnackBar.showLoading(
        context,
        message: 'Generating CSV file...',
        duration: const Duration(seconds: 2),
      );

      final dateFormat = DateFormat('dd/MM/yyyy');
      final buffer = StringBuffer();

      // Add UTF-8 BOM for Excel compatibility
      buffer.write('\uFEFF');

      // Header row
      buffer.writeln(
        [
          'Date',
          'Order No',
          'Party Name',
          'Phone No',
          'Txn Type',
          'Status',
          'Payment Type',
          'Paid Amount',
          'Balance',
        ].map((e) => '"$e"').join(','),
      );

      // Data rows
      for (var s in sales) {
        final balance = s.totalAmount - s.amount;
        buffer.writeln(
          [
            dateFormat.format(s.dateTime),
            '-',
            s.customerName,
            s.phoneNumber,
            'Sale',
            balance <= 0 ? 'Paid' : 'Unpaid',
            s.paymentMode,
            s.amount.toStringAsFixed(2),
            balance.toStringAsFixed(2),
          ].map((e) => '"${e.toString().replaceAll('"', '""')}"').join(','),
        );
      }

      // Get directory
      final directory = await getApplicationDocumentsDirectory();
      final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final path = '${directory.path}/Sale report $currentDate.csv';

      // Write file
      final file = File(path);
      await file.writeAsString(buffer.toString());

      // Verify file was created
      if (!await file.exists()) {
        throw Exception('Failed to create CSV file');
      }

      // Open file
      final result = await OpenFilex.open(path);

      if (!mounted) return;

      if (result.type != ResultType.done) {
        AppSnackBar.showError(
          context,
          message: 'Failed to open file: ${result.message}',
          duration: Duration(seconds: 2),
        );
      } else {
        AppSnackBar.showSuccess(
          context,
          message: 'CSV file exported successfully',
          duration: Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(
        context,
        message: 'Error: ${e.toString()}',
        duration: Duration(seconds: 2),
      );

      debugPrint('CSV Export Error: $e');
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: selectedRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        selectedRange = picked;
        selectedPreset = null;
      });
    }
  }

  String getFormattedRange() {
    if (selectedRange == null) return '';
    final start = DateFormat('dd/MM/yyyy').format(selectedRange!.start);
    final end = DateFormat('dd/MM/yyyy').format(selectedRange!.end);
    return "$start TO $end";
  }

  List<Sale> getFilteredSales() {
    if (selectedRange == null) return widget.sales;
    return widget.sales.where((sale) {
      return sale.dateTime.isAfter(
            selectedRange!.start.subtract(Duration(days: 1)),
          ) &&
          sale.dateTime.isBefore(selectedRange!.end.add(Duration(days: 1)));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.simpleCurrency(
      locale: 'en_IN',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('dd MMM, yy');

    final filteredSales = getFilteredSales();
    final customerMap = <String, List<Sale>>{};
    for (final sale in filteredSales) {
      customerMap.putIfAbsent(sale.customerName, () => []).add(sale);
    }

    final totalTxns = filteredSales.length;
    final totalSales = filteredSales.fold(
      0.0,
      (sum, sale) => sum + sale.totalAmount,
    );
    final totalPaid = filteredSales.fold(0.0, (sum, sale) => sum + sale.amount);
    final totalBalance = totalSales - totalPaid;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF00BCD4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: BackButton(color: Colors.white),
        title: Text("Sale Report", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: Colors.white, size: 25),
            onPressed: () async {
              final sales = getFilteredSales(); // Your sales data
              await _generateAndSavePdf(context, sales);
            },
          ),
          Stack(
            children: [
              IconButton(
                icon: CustomXlsIcon(),
                onPressed: () => _exportToCSV(context),
              ),
              Positioned(
                right: 8,
                top: 10,
                child: CircleAvatar(radius: 4, backgroundColor: Colors.red),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _selectDateRange(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.blue[800],
                            ),
                            SizedBox(width: 8),
                            Text(
                              getFormattedRange(),
                              style: TextStyle(
                                color: Colors.blue[800],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Spacer(),
                    PopupMenuButton<DateRangePreset>(
                      icon: Icon(Icons.tune_rounded, color: Colors.blue[800]),
                      onSelected: _handlePresetSelection,
                      itemBuilder:
                          (BuildContext context) =>
                              <PopupMenuEntry<DateRangePreset>>[
                                PopupMenuItem<DateRangePreset>(
                                  value: DateRangePreset.today,
                                  child: Text('Today'),
                                ),
                                PopupMenuItem<DateRangePreset>(
                                  value: DateRangePreset.thisWeek,
                                  child: Text('This Week'),
                                ),
                                PopupMenuItem<DateRangePreset>(
                                  value: DateRangePreset.thisMonth,
                                  child: Text('This Month'),
                                ),
                                PopupMenuItem<DateRangePreset>(
                                  value: DateRangePreset.thisQuarter,
                                  child: Text('This Quarter'),
                                ),
                                PopupMenuItem<DateRangePreset>(
                                  value: DateRangePreset.thisFinancialYear,
                                  child: Text('This Financial Year'),
                                ),
                                PopupMenuItem<DateRangePreset>(
                                  value: DateRangePreset.custom,
                                  child: Text('Custom Range'),
                                ),
                              ],
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    _statTile(
                      value: totalTxns.toString(),
                      label: "Transactions",
                      icon: Icons.receipt_long,
                      color: Colors.blue,
                    ),
                    SizedBox(width: 12),
                    _statTile(
                      value: currencyFormat.format(totalSales),
                      label: "Total Sales",
                      icon: Icons.currency_rupee,
                      color: Colors.indigo,
                    ),
                    SizedBox(width: 12),
                    _statTile(
                      value: currencyFormat.format(totalBalance),
                      label: "Balance",
                      icon: Icons.account_balance_wallet,
                      color:
                          totalBalance > 0 ? Colors.red : Colors.green.shade700,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              children: [
                Text(
                  "CUSTOMER TRANSACTIONS",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Spacer(),
                Text(
                  "${customerMap.length} records",
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: customerMap.length,
                    separatorBuilder: (_, __) => SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final name = customerMap.keys.elementAt(index);
                      final transactions = customerMap[name]!;
                      final sale = transactions.first;
                      final total = transactions.fold(
                        0.0,
                        (sum, s) => sum + s.totalAmount,
                      );
                      final paid = transactions.fold(
                        0.0,
                        (sum, s) => sum + s.amount,
                      );
                      final balance = total - paid;
                      final paidPercentage = (paid / total * 100)
                          .toStringAsFixed(0);

                      return Material(
                        borderRadius: BorderRadius.circular(16),
                        elevation: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey[200]!,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue[50],
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.blue[800],
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  "${transactions.length} transactions",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        balance > 0
                                            ? Colors.red[50]
                                            : Colors.green[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    balance < 0
                                        ? "+${currencyFormat.format(balance.abs())}"
                                        : currencyFormat.format(balance),

                                    style: TextStyle(
                                      color:
                                          balance > 0
                                              ? Colors.red[800]
                                              : Colors.green[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: LinearProgressIndicator(
                                  value: paid / total,
                                  backgroundColor: Colors.grey[200],
                                  color:
                                      balance > 0
                                          ? Colors.orange
                                          : Colors.green,
                                  minHeight: 6,
                                ),
                              ),
                              SizedBox(height: 4),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "$paidPercentage% Paid",
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      dateFormat.format(sale.dateTime),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 12),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "TOTAL AMOUNT",
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 10,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            currencyFormat.format(total),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            "LAST PAYMENT",
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 10,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            currencyFormat.format(paid),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.green[800],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                Spacer(),
              ],
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomXlsIcon extends StatelessWidget {
  const CustomXlsIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 27,
      height: 27,
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white, width: 1.4),
      ),
      child: Center(
        child: Text(
          'XLS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
