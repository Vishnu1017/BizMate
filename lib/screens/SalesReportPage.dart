// lib/screens/sales_report_page.dart
import 'dart:io';
import 'package:bizmate/models/sale.dart';
import 'package:bizmate/models/user_model.dart';
import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:bizmate/widgets/modern_calendar_range.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';

enum DateRangePreset {
  today,
  thisWeek,
  thisMonth,
  thisQuarter,
  thisFinancialYear,
  custom,
}

// ✅ ADD THIS JUST BELOW (OR ABOVE) IT
enum DownloadType { pdf, xls }

class SalesReportPage extends StatefulWidget {
  final List<Sale> sales;

  const SalesReportPage({super.key, required this.sales});

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  DateTimeRange? selectedRange;
  DateRangePreset? selectedPreset;
  bool _isLoadingPdf = false;
  bool _isLoadingCsv = false;
  double scale = 1.0;
  double _downloadButtonWidth = 0;

  // Overlay & target
  final GlobalKey _filterKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _isDropdownOpen = false;

  // Scroll controller to close overlay on scroll
  final ScrollController _scrollController = ScrollController();
  LinearGradient getProgressGradient(double percentage) {
    if (percentage <= 20) {
      return LinearGradient(colors: [Color(0xFFE53935), Color(0xFFD32F2F)]);
    } else if (percentage <= 50) {
      return LinearGradient(colors: [Color(0xFFE53935), Color(0xFFFFA726)]);
    } else if (percentage <= 75) {
      return LinearGradient(
        colors: [Color(0xFFFFA726), Color(0xFFFFEB3B), Color(0xFF66BB6A)],
      );
    } else {
      return LinearGradient(colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)]);
    }
  }

  void _showDownloadMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(Offset.zero);
    final Size buttonSize = button.size;

    final RelativeRect position = RelativeRect.fromLTRB(
      buttonPosition.dx,
      buttonPosition.dy + buttonSize.height, // 👈 BELOW the button
      buttonPosition.dx + buttonSize.width,
      0,
    );

    showMenu<DownloadType>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        _compactDownloadItem(value: DownloadType.pdf, label: "PDF"),
        _compactDownloadItem(value: DownloadType.xls, label: "XLS"),
      ],
    ).then((value) async {
      if (value == null) return;

      final sales = getFilteredSales();

      if (value == DownloadType.pdf) {
        await _generateAndSavePdf(context, sales);
      } else if (value == DownloadType.xls) {
        await _exportToCSV(context);
      }
    });
  }

  PopupMenuItem<DownloadType> _compactDownloadItem({
    required DownloadType value,
    required String label,
  }) {
    return PopupMenuItem<DownloadType>(
      value: value,
      height: 32 * scale,
      child: SizedBox(
        width: _downloadButtonWidth, // 🔥 SAME AS BUTTON
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedDownload01,
              color: Colors.black87,
              size: 12 * scale,
            ),
            SizedBox(width: 6 * scale),
            Text(
              label,
              style: TextStyle(
                fontSize: 11 * scale,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    selectedRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
    selectedPreset = DateRangePreset.thisMonth;

    _scrollController.addListener(() {
      if (_isDropdownOpen) _removeOverlay();
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    _scrollController.dispose();
    super.dispose();
  }

  // --------------------
  // Overlay helpers
  // --------------------
  void _showOverlay() {
    if (_overlayEntry != null) return;

    // overlay width responsive
    final screenWidth = MediaQuery.of(context).size.width;
    final overlayWidth = screenWidth < 420 ? screenWidth * 0.8 : 320.0;
    const verticalOffset = 8.0;
    const sidePadding = 8.0;

    // Try to get position of the filter button
    RenderBox? renderBox;
    Offset targetGlobal = Offset.zero;
    Size targetSize = Size.zero;

    try {
      if (_filterKey.currentContext != null) {
        renderBox = _filterKey.currentContext!.findRenderObject() as RenderBox;
        targetGlobal = renderBox.localToGlobal(Offset.zero);
        targetSize = renderBox.size;
      }
    } catch (e) {
      renderBox = null;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) {
        // If we could calculate the button pos, position overlay so its right aligns with the button's right.
        if (renderBox != null) {
          double left = targetGlobal.dx + targetSize.width - overlayWidth;
          // clamp to screen
          if (left < sidePadding) left = sidePadding;
          if (left + overlayWidth > screenWidth - sidePadding) {
            left = (screenWidth - sidePadding) - overlayWidth;
          }

          final top = targetGlobal.dy + targetSize.height + verticalOffset;

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _removeOverlay,
            child: Stack(
              children: [
                // intercept taps outside overlay
                Positioned.fill(child: Container(color: Colors.transparent)),
                Positioned(
                  left: left,
                  top: top,
                  child: Material(
                    elevation: 12,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: overlayWidth,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children:
                            DateRangePreset.values.map((preset) {
                              final isSelected = selectedPreset == preset;
                              return _buildDropdownItem(preset, isSelected);
                            }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // fallback: center under top area
        return GestureDetector(
          onTap: _removeOverlay,
          child: Container(
            color: Colors.transparent,
            child: Center(
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: overlayWidth,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        DateRangePreset.values.map((preset) {
                          final isSelected = selectedPreset == preset;
                          return _buildDropdownItem(preset, isSelected);
                        }).toList(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isDropdownOpen = true);
  }

  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    if (mounted) setState(() => _isDropdownOpen = false);
  }

  Widget _buildDropdownItem(DateRangePreset preset, bool isSelected) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _handlePresetSelection(preset);
          _removeOverlay();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.shade600 : Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    _getPresetIcon(preset),
                    color: isSelected ? Colors.white : Colors.grey[700],
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getPresetLabel(preset),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected
                                ? Colors.blue.shade800
                                : Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getPresetDescription(preset),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: Colors.blue.shade600, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------
  // Date range selection
  // --------------------
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
        _showCustomDateRange(context);
        return;
    }

    setState(() {
      selectedRange = DateTimeRange(start: startDate, end: endDate);
      selectedPreset = preset;
    });
  }

  Future<void> _showCustomDateRange(BuildContext context) async {
    _removeOverlay();

    final DateTimeRange? result = await showModalBottomSheet<DateTimeRange?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tap outside closes the sheet
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(color: Colors.transparent),
                ),
              ),

              // ------------------------------
              // YOUR ModernCalendarRange widget
              // ------------------------------
              ModernCalendarRange(
                selectedStartDate: selectedRange?.start,
                selectedEndDate: selectedRange?.end,

                onRangeSelected: (start, end) {
                  if (start != null && end != null) {
                    // RETURN selected range back to parent page
                    Navigator.of(
                      context,
                    ).pop(DateTimeRange(start: start, end: end));
                  }
                },
              ),
            ],
          ),
        );
      },
    );

    // ------------------------------
    // RESULT HANDLING (IMPORTANT)
    // ------------------------------
    if (result != null && mounted) {
      setState(() {
        selectedRange = result;
        selectedPreset = DateRangePreset.custom;
      });
    }
  }

  // --------------------
  // PDF/CSV generation (kept mostly as in your original)
  // --------------------
  Future<String> _getCurrentUserEmailFromHive() async {
    try {
      final usersBox = await Hive.openBox<User>('users');
      final sessionBox = await Hive.openBox('session');
      final currentUserEmail = sessionBox.get('currentUserEmail');
      return currentUserEmail ??
          (usersBox.isNotEmpty ? usersBox.values.first.email : '');
    } catch (e) {
      debugPrint('Error getting user email from Hive: $e');
      return '';
    }
  }

  Future<User?> _getCurrentUser() async {
    try {
      final usersBox = await Hive.openBox<User>('users');
      final sessionBox = await Hive.openBox('session');
      final email = sessionBox.get('currentUserEmail');

      if (email == null) return null;

      for (final user in usersBox.values) {
        if (user.email == email) {
          return user;
        }
      }

      return null;
    } catch (e) {
      debugPrint('User fetch failed: $e');
      return null;
    }
  }

  Future<pw.Document> _generateSalesReportPdf(List<Sale> sales) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'en_IN');

    final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final ttf = pw.Font.ttf(fontData.buffer.asByteData());

    final prefs = await SharedPreferences.getInstance();
    final currentUserEmail = await _getCurrentUserEmailFromHive();
    final currentUser = await _getCurrentUser();

    final displayName =
        currentUser?.name.isNotEmpty == true ? currentUser!.name : "User";

    final phone =
        currentUser?.phone.isNotEmpty == true ? currentUser!.phone : "";

    final email =
        currentUser?.email.isNotEmpty == true ? currentUser!.email : "";

    final address =
        currentUser?.address?.trim().isNotEmpty == true
            ? currentUser!.address!
            : '';

    final profileImagePath = prefs.getString(
      '${currentUserEmail}_profileImagePath',
    );

    pw.MemoryImage? headerImage;

    if (profileImagePath != null && profileImagePath.isNotEmpty) {
      final file = File(profileImagePath);

      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        headerImage = pw.MemoryImage(bytes);
      } else {
        debugPrint("❌ Profile image file missing: $profileImagePath");
      }
    } else {
      debugPrint("❌ No saved profile image path for $currentUserEmail");
    }

    final totalSales = sales.fold(0.0, (sum, s) => sum + s.totalAmount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build:
            (context) => [
              // ---------- HEADER CARD ----------
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#E0F7FA'),
                  border: pw.Border.all(color: PdfColors.grey),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // PROFILE IMAGE BOX
                    pw.Container(
                      width: 55,
                      height: 55,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColors.grey600),
                      ),
                      child:
                          headerImage != null
                              ? pw.ClipRRect(
                                horizontalRadius: 8,
                                verticalRadius: 8,
                                child: pw.Image(
                                  headerImage,
                                  fit: pw.BoxFit.cover,
                                ),
                              )
                              : pw.Center(
                                child: pw.Text(
                                  "No Image",
                                  style: pw.TextStyle(font: ttf, fontSize: 10),
                                ),
                              ),
                    ),

                    pw.SizedBox(width: 12),

                    // BRAND DETAILS
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            displayName,
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.indigo800,
                            ),
                          ),
                          if (phone.isNotEmpty)
                            pw.Text(
                              "Phone: $phone",
                              style: pw.TextStyle(font: ttf),
                            ),
                          if (email.isNotEmpty)
                            pw.Text(
                              "Email: $email",
                              style: pw.TextStyle(font: ttf),
                            ),
                          if (address.trim().isNotEmpty)
                            pw.Text(
                              "Address: $address",
                              style: pw.TextStyle(font: ttf),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // ---------- TITLE ----------
              pw.Center(
                child: pw.Text(
                  "Sales Report",
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              ),

              pw.SizedBox(height: 10),
              pw.Text("Username: All Users", style: pw.TextStyle(font: ttf)),
              pw.Text(
                "Duration: From ${getFormattedRange()}",
                style: pw.TextStyle(font: ttf),
              ),
              pw.SizedBox(height: 20),

              // ---------- SALES TABLE ----------
              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  font: ttf,
                ),
                cellStyle: pw.TextStyle(font: ttf, fontSize: 10),
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
                data:
                    sales.map((s) {
                      final balance = s.totalAmount - s.amount;

                      return [
                        dateFormat.format(s.dateTime),
                        "-",
                        s.customerName,
                        s.phoneNumber,
                        "Sale",
                        balance <= 0 ? "Paid" : "Unpaid",
                        s.paymentMode,
                        currencyFormat.format(s.amount),
                        currencyFormat.format(balance),
                      ];
                    }).toList(),
              ),

              pw.SizedBox(height: 20),

              // ---------- SUMMARY ----------
              pw.Container(
                alignment: pw.Alignment.centerRight,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  color: PdfColors.indigo50,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  "Total Sale: ${currencyFormat.format(totalSales)}",
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo900,
                  ),
                ),
              ),

              pw.SizedBox(height: 30),
              pw.Divider(),

              pw.Text(
                "Generated on: ${DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now())}",
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],
      ),
    );

    return pdf;
  }

  Future<void> _generateAndSavePdf(
    BuildContext context,
    List<Sale> sales,
  ) async {
    try {
      setState(() => _isLoadingPdf = true);
      final pdf = await _generateSalesReportPdf(sales);
      final directory = await getApplicationDocumentsDirectory();
      final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final fileName = 'Sale report $currentDate.pdf';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(await pdf.save());

      final result = await OpenFilex.open(file.path);

      if (!mounted) return;

      if (result.type != ResultType.done) {
        AppSnackBar.showInfo(
          context,
          message: 'PDF saved but could not open: $fileName',
          duration: const Duration(seconds: 2),
        );
      } else {
        AppSnackBar.showSuccess(
          context,
          message: 'PDF generated successfully',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(
        context,
        message: 'Failed to generate PDF: ${e.toString()}',
        duration: const Duration(seconds: 2),
      );
    } finally {
      if (mounted) setState(() => _isLoadingPdf = false);
    }
  }

  Future<void> _exportToCSV(BuildContext context) async {
    try {
      setState(() => _isLoadingCsv = true);
      final sales = getFilteredSales();

      if (sales.isEmpty) {
        AppSnackBar.showInfo(
          context,
          message: 'No sales data to export',
          duration: const Duration(seconds: 2),
        );
        return;
      }

      final dateFormat = DateFormat('dd/MM/yyyy');
      final buffer = StringBuffer();

      buffer.write('\uFEFF');

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

      final directory = await getApplicationDocumentsDirectory();
      final currentDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final path = '${directory.path}/Sale report $currentDate.csv';

      final file = File(path);
      await file.writeAsString(buffer.toString());

      if (!await file.exists()) throw Exception('Failed to create CSV file');

      final result = await OpenFilex.open(path);

      if (!mounted) return;

      if (result.type != ResultType.done) {
        AppSnackBar.showError(
          context,
          message: 'Failed to open file: ${result.message}',
          duration: const Duration(seconds: 2),
        );
      } else {
        AppSnackBar.showSuccess(
          context,
          message: 'CSV file exported successfully',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(
        context,
        message: 'Error: ${e.toString()}',
        duration: const Duration(seconds: 2),
      );
      debugPrint('CSV Export Error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCsv = false);
    }
  }

  // --------------------
  // Helpers / UI builders
  // --------------------
  String _getPresetLabel(DateRangePreset preset) {
    switch (preset) {
      case DateRangePreset.today:
        return 'Today';
      case DateRangePreset.thisWeek:
        return 'This Week';
      case DateRangePreset.thisMonth:
        return 'This Month';
      case DateRangePreset.thisQuarter:
        return 'This Quarter';
      case DateRangePreset.thisFinancialYear:
        return 'Financial Year';
      case DateRangePreset.custom:
        return 'Custom Range';
    }
  }

  String _getPresetDescription(DateRangePreset preset) {
    final now = DateTime.now();
    switch (preset) {
      case DateRangePreset.today:
        return DateFormat('MMM dd, yyyy').format(now);
      case DateRangePreset.thisWeek:
        final start = DateTime(now.year, now.month, now.day - now.weekday + 1);
        final end = DateTime(now.year, now.month, now.day - now.weekday + 7);
        return '${DateFormat('MMM dd').format(start)} - ${DateFormat('MMM dd').format(end)}';
      case DateRangePreset.thisMonth:
        return DateFormat('MMMM yyyy').format(now);
      case DateRangePreset.thisQuarter:
        final quarter = (now.month - 1) ~/ 3 + 1;
        return 'Q$quarter ${now.year}';
      case DateRangePreset.thisFinancialYear:
        return 'Apr ${now.month >= 4 ? now.year : now.year - 1} - Mar ${now.month >= 4 ? now.year + 1 : now.year}';
      case DateRangePreset.custom:
        return 'Select specific dates';
    }
  }

  IconData _getPresetIcon(DateRangePreset preset) {
    switch (preset) {
      case DateRangePreset.today:
        return Icons.today;
      case DateRangePreset.thisWeek:
        return Icons.view_week;
      case DateRangePreset.thisMonth:
        return Icons.calendar_month;
      case DateRangePreset.thisQuarter:
        return Icons.bar_chart;
      case DateRangePreset.thisFinancialYear:
        return Icons.account_balance;
      case DateRangePreset.custom:
        return Icons.date_range;
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
            selectedRange!.start.subtract(const Duration(days: 1)),
          ) &&
          sale.dateTime.isBefore(
            selectedRange!.end.add(const Duration(days: 1)),
          );
    }).toList();
  }

  // NEW: Create a unique key for each customer using name + phone
  String _createCustomerKey(Sale sale) {
    return '${sale.customerName}_${sale.phoneNumber}';
  }

  // MODIFIED: Group sales by name + phone combination
  Map<String, List<Sale>> _groupSalesByCustomer(List<Sale> sales) {
    final customerMap = <String, List<Sale>>{};

    for (final sale in sales) {
      final customerKey = _createCustomerKey(sale);
      customerMap.putIfAbsent(customerKey, () => []).add(sale);
    }

    return customerMap;
  }

  // NEW: Extract display name from the customer key
  String _getDisplayName(String customerKey) {
    // customerKey is in format "name_phone"
    final parts = customerKey.split('_');
    if (parts.length >= 2) {
      return parts[0]; // Return just the name part
    }
    return customerKey;
  }

  // NEW: Extract phone number from the customer key
  String _getPhoneNumber(String customerKey) {
    // customerKey is in format "name_phone"
    final parts = customerKey.split('_');
    if (parts.length >= 2) {
      return parts
          .sublist(1)
          .join('_'); // Join back in case phone has underscores
    }
    return '';
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      floating: false,
      expandedHeight: 160,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final isCollapsed = constraints.biggest.height <= kToolbarHeight + 40;

          return Stack(
            children: [
              // ------------------------------
              // Background GRADIENT
              // ------------------------------
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2BC0E4), Color(0xFFEAECC6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

              // ------------------------------
              // Centered Title (Animated)
              // ------------------------------
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                bottom: isCollapsed ? 14 : 26,
                left: isCollapsed ? 76 : 40,
                child: Text(
                  "Sale Report",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCollapsed ? 18 : 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // ------------------------------
              // Back Button (Floating Style)
              // ------------------------------
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                child: _modernCircleButton(
                  customIcon: Icon(Icons.arrow_back, size: 18 * scale),
                  onTap: () => Navigator.pop(context),
                ),
              ),

              // ------------------------------
              // ACTION BUTTONS (Modern Capsule)
              // ------------------------------
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 14,
                child: Builder(
                  builder: (btnContext) {
                    final isLoading = _isLoadingPdf || _isLoadingCsv;

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        _downloadButtonWidth =
                            constraints.maxWidth; // 👈 capture width

                        return _modernActionButton(
                          loading: isLoading,
                          onTap:
                              isLoading
                                  ? null
                                  : () => _showDownloadMenu(btnContext),
                          customChild: HugeIcon(
                            icon: HugeIcons.strokeRoundedDownload01,
                            color: Colors.white,
                            size: 20 * scale,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopFiltersSection(
    Map<String, List<Sale>> customerMap,
    NumberFormat currencyFormat,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    // ignore: unused_local_variable
    final isCompact = screenWidth < 520;

    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.all(12 * scale),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(18 * scale),
            bottomRight: Radius.circular(18 * scale),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => _showCustomDateRange(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8 * scale,
                      vertical: 6 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12 * scale,
                          color: Colors.blue[800],
                        ),
                        SizedBox(width: 4 * scale),
                        Text(
                          getFormattedRange(),
                          style: TextStyle(
                            color: Colors.blue[800],
                            fontSize: 8 * scale,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // Filter button (target for overlay)
                GestureDetector(
                  key: _filterKey,
                  onTap: _isDropdownOpen ? _removeOverlay : _showOverlay,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8 * scale,
                      vertical: 6 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          color: Colors.blue[800],
                          size: 12 * scale,
                        ),
                        Icon(
                          _isDropdownOpen
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                          color: Colors.blue[800],
                          size: 12 * scale,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _statTile(
                  value: widget.sales.length.toString(),
                  label: 'Transactions',
                  icon: Icons.receipt_long,
                  color: Colors.blue,
                ),
                const SizedBox(width: 12),
                _statTile(
                  value: currencyFormat.format(
                    customerMap.values
                        .expand((e) => e)
                        .fold(0.0, (p, s) => p + s.totalAmount),
                  ),
                  label: 'Total Sales',
                  icon: Icons.currency_rupee,
                  color: Colors.indigo,
                ),
                const SizedBox(width: 12),
                _statTile(
                  value: currencyFormat.format(
                    customerMap.values
                            .expand((e) => e)
                            .fold(0.0, (p, s) => p + s.totalAmount) -
                        customerMap.values
                            .expand((e) => e)
                            .fold(0.0, (p, s) => p + s.amount),
                  ),
                  label: 'Balance',
                  icon: Icons.account_balance_wallet,
                  color: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerHeader(Map<String, List<Sale>> customerMap) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: Row(
          children: [
            Text(
              'CUSTOMER TRANSACTIONS',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10 * scale,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            Text(
              '${customerMap.length} records',
              style: TextStyle(color: Colors.grey[500], fontSize: 10 * scale),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(
    String customerKey,
    List<Sale> transactions,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    final sale = transactions.first;
    final total = transactions.fold(0.0, (sum, s) => sum + s.totalAmount);
    final paid = transactions.fold(0.0, (sum, s) => sum + s.amount);
    final balance = total - paid;
    final paidPercentage = total == 0 ? 0 : ((paid / total) * 100).round();

    // Extract name and phone from the customer key
    final customerName = _getDisplayName(customerKey);
    final phoneNumber = _getPhoneNumber(customerKey);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 12 * scale,
        vertical: 6 * scale,
      ),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!, width: 1),
          ),
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  radius: 16 * scale, // 👈 controls background size
                  backgroundColor: Colors.blue[50],
                  child: Icon(
                    Icons.person,
                    color: Colors.blue[800],
                    size: 14 * scale,
                  ),
                ),
                title: Text(
                  customerName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14 * scale,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${transactions.length} transactions',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10 * scale,
                      ),
                    ),
                    if (phoneNumber.isNotEmpty)
                      Text(
                        phoneNumber,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10 * scale,
                        ),
                      ),
                  ],
                ),
                trailing: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 6 * scale,
                    vertical: 2 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: balance > 0 ? Colors.red[50] : Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    balance < 0
                        ? "+${currencyFormat.format(balance.abs())}"
                        : currencyFormat.format(balance),
                    style: TextStyle(
                      color: balance > 0 ? Colors.red[800] : Colors.green[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 10 * scale,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14 * scale),
                child: _gradientProgressBar(paid: paid, total: total),
              ),

              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$paidPercentage% Paid',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10 * scale,
                      ),
                    ),
                    Text(
                      DateFormat('dd MMM, yy').format(sale.dateTime),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10 * scale,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10 * scale),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14 * scale),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL AMOUNT',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 8 * scale,
                            ),
                          ),
                          SizedBox(height: 4 * scale),
                          Text(
                            currencyFormat.format(total),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14 * scale,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'LAST PAYMENT',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 8 * scale,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currencyFormat.format(paid),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14 * scale,
                              color: Colors.green[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
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
        padding: EdgeInsets.all(8 * scale),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // ✅ key
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(4 * scale),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 12 * scale, color: color),
                ),
                const Spacer(),
              ],
            ),
            SizedBox(height: 6 * scale),
            Text(
              value,
              style: TextStyle(
                fontSize: 10 * scale,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: Colors.grey[800], fontSize: 6 * scale),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // prepare data
    final filteredSales = getFilteredSales();
    // MODIFIED: Use the new grouping function that considers name + phone
    final customerMap = _groupSalesByCustomer(filteredSales);

    final currencyFormat = NumberFormat.simpleCurrency(
      locale: 'en_IN',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('dd MMM, yy');

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(),
          _buildTopFiltersSection(customerMap, currencyFormat),
          _buildCustomerHeader(customerMap),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final customerKey = customerMap.keys.elementAt(index);
              final transactions = customerMap[customerKey]!;
              return _buildCustomerCard(
                customerKey,
                transactions,
                currencyFormat,
                dateFormat,
              );
            }, childCount: customerMap.length),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _modernCircleButton({
    IconData? icon,
    Widget? customIcon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        splashColor: Colors.black.withOpacity(0.08),
        highlightColor: Colors.black.withOpacity(0.05),
        child: Container(
          width: 30 * scale,
          height: 30 * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,

            // ✅ subtle border (same as your reference)
            border: Border.all(color: Colors.black.withOpacity(0.08), width: 1),

            // ✅ soft elevation
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child:
                customIcon ?? Icon(icon, color: Colors.black, size: 20 * scale),
          ),
        ),
      ),
    );
  }

  Widget _modernActionButton({
    Widget? customChild,
    required bool loading,
    required VoidCallback? onTap,
    Color background = const Color(0xFF1A237E),
  }) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 30 * scale,
        padding: EdgeInsets.symmetric(horizontal: 6 * scale),
        decoration: BoxDecoration(
          color: background.withOpacity(0.26),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white54, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child:
              loading
                  ? SizedBox(
                    height: 20 * scale,
                    width: 20 * scale,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : (customChild ??
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedPdf01,
                        color: Colors.white,
                        size: 20 * scale,
                      )),
        ),
      ),
    );
  }

  Widget _gradientProgressBar({required double paid, required double total}) {
    final double progress = total == 0 ? 0 : (paid / total).clamp(0.0, 1.0);

    final double percentage = progress * 100;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        children: [
          // Background
          Container(height: 6, width: double.infinity, color: Colors.grey[200]),

          // Gradient progress
          LayoutBuilder(
            builder: (context, constraints) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                height: 6,
                width: constraints.maxWidth * progress,
                decoration: BoxDecoration(
                  gradient: getProgressGradient(percentage),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
