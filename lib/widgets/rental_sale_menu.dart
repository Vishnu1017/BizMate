// rental_sale_menu.dart

import 'dart:io';

import 'package:bizmate/models/payment.dart' show Payment;
import 'package:bizmate/models/rental_sale_model.dart';
import 'package:bizmate/models/sale.dart';
import 'package:bizmate/models/user_model.dart' show User;
import 'package:bizmate/screens/payment_history_page.dart';
import 'package:bizmate/screens/rental_pdf_preview_screen.dart';
import 'package:bizmate/widgets/app_snackbar.dart';
import 'package:bizmate/widgets/confirm_delete_dialog.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;

class RentalSaleMenu extends StatelessWidget {
  /// The rental sale entry
  final RentalSaleModel sale;

  /// Index in the rentalSales list (originalIndex from your list)
  final int originalIndex;

  /// User-specific Hive box: userdata_<safeEmail>
  final Box userBox;

  /// For sizing the popup icons (like SaleOptionsMenu)
  final bool isSmallScreen;

  /// Current logged-in user details (for invoice header)
  final String currentUserName;
  final String currentUserPhone;
  final String currentUserEmail;

  /// Parent screen context for showing snackbars etc.
  final BuildContext parentContext;

  String _generateGooglePayLink(String upiId, String name, double? amount) {
    final encodedName = Uri.encodeComponent(name);

    return amount != null && amount > 0
        ? 'gpay://upi/pay?pa=$upiId&pn=$encodedName&am=${amount.toStringAsFixed(2)}&cu=INR'
        : 'gpay://upi/pay?pa=$upiId&pn=$encodedName&cu=INR';
  }

  String _generatePhonePeLink(String upiId, String name, double? amount) {
    final encodedName = Uri.encodeComponent(name);

    return amount != null && amount > 0
        ? 'phonepe://pay?pa=$upiId&pn=$encodedName&am=${amount.toStringAsFixed(2)}&cu=INR'
        : 'phonepe://pay?pa=$upiId&pn=$encodedName&cu=INR';
  }

  String _generatePaytmLink(String upiId, String name, double? amount) {
    final encodedName = Uri.encodeComponent(name);

    return amount != null && amount > 0
        ? 'paytm://upi/pay?pa=$upiId&pn=$encodedName&am=${amount.toStringAsFixed(2)}&cu=INR'
        : 'paytm://upi/pay?pa=$upiId&pn=$encodedName&cu=INR';
  }

  const RentalSaleMenu({
    super.key,
    required this.sale,
    required this.originalIndex,
    required this.userBox,
    required this.isSmallScreen,
    required this.currentUserName,
    required this.currentUserPhone,
    required this.currentUserEmail,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: isSmallScreen ? 20 : 24),
      onSelected: (value) => _handleMenuSelection(value, context),
      itemBuilder: (context) => _buildMenuItems(),
    );
  }

  // ---------------------------------------------------------------------------
  // MENU ITEMS
  // ---------------------------------------------------------------------------

  List<PopupMenuItem<String>> _buildMenuItems() {
    return [
      PopupMenuItem(
        value: 'share_pdf',
        child: Row(
          children: [
            Icon(
              Icons.picture_as_pdf,
              color: Colors.blue,
              size: isSmallScreen ? 18 : 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Share PDF',
              style: TextStyle(fontSize: isSmallScreen ? 12 : null),
            ),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'payment_history',
        child: Row(
          children: [
            Icon(
              Icons.history,
              color: Colors.green,
              size: isSmallScreen ? 18 : 24,
            ),
            const SizedBox(width: 8),
            Text(
              'View Payment History',
              style: TextStyle(fontSize: isSmallScreen ? 12 : null),
            ),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(
              Icons.delete,
              color: Colors.red,
              size: isSmallScreen ? 18 : 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Delete',
              style: TextStyle(fontSize: isSmallScreen ? 12 : null),
            ),
          ],
        ),
      ),
    ];
  }

  Future<void> _handleMenuSelection(String value, BuildContext context) async {
    switch (value) {
      case 'delete':
        await _handleDelete(context);
        break;
      case 'share_pdf':
        await _handleSharePdf(context);
        break;
      case 'payment_history':
        _handlePaymentHistory(context);
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE RENTAL SALE
  // ---------------------------------------------------------------------------

  Future<void> _handleDelete(BuildContext context) async {
    await showConfirmDialog(
      context: context,
      title: "Delete Sale?",
      message: "This will permanently delete this rental entry. Are you sure?",
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.redAccent,
      onConfirm: () async {
        try {
          final raw = userBox.get('rental_sales', defaultValue: []);
          final List<RentalSaleModel> persisted =
              (raw as List).map((e) => e as RentalSaleModel).toList();

          final beforeCount = persisted.length;

          // 🔥 REMOVE ALL SALES BELONGING TO THIS GROUP
          persisted.removeWhere((s) {
            return s.customerName == sale.customerName &&
                s.customerPhone == sale.customerPhone &&
                s.fromDateTime == sale.fromDateTime &&
                s.toDateTime == sale.toDateTime;
          });

          final deletedCount = beforeCount - persisted.length;

          await userBox.put('rental_sales', persisted);

          AppSnackBar.showSuccess(
            parentContext,
            message:
                deletedCount > 1
                    ? "$deletedCount items deleted successfully"
                    : "Rental deleted successfully",
            duration: const Duration(seconds: 2),
          );
        } catch (e) {
          AppSnackBar.showError(
            parentContext,
            message: "Failed to delete rental: $e",
            duration: const Duration(seconds: 2),
          );
        }
      },
    );
  }

  bool _isSameSale(RentalSaleModel a, RentalSaleModel b) {
    return a.customerName == b.customerName &&
        a.itemName == b.itemName &&
        a.fromDateTime == b.fromDateTime &&
        a.toDateTime == b.toDateTime &&
        a.totalCost == b.totalCost;
  }

  // ---------------------------------------------------------------------------
  // PAYMENT HISTORY
  // ---------------------------------------------------------------------------

  void _handlePaymentHistory(BuildContext context) {
    final List<Payment> fixedPaymentHistory = <Payment>[];

    // ✅ CASE 1: already has history
    if (sale.paymentHistory.isNotEmpty) {
      fixedPaymentHistory.addAll(sale.paymentHistory.cast<Payment>());
    }

    // ✅ CASE 2: first payment missing → inject it
    if (fixedPaymentHistory.isEmpty && sale.amountPaid > 0) {
      fixedPaymentHistory.add(
        Payment(
          amount: sale.amountPaid,
          date: sale.fromDateTime,
          mode: sale.paymentMode.isNotEmpty ? sale.paymentMode : 'Cash',
        ),
      );
    }

    // ✅ Convert Rental → Sale (PaymentHistoryPage expects Sale)
    final Sale tempSale = Sale(
      customerName: sale.customerName,
      amount: sale.amountPaid,
      totalAmount: sale.totalCost,
      productName: sale.itemName,
      dateTime: sale.fromDateTime,
      phoneNumber: sale.customerPhone,
      paymentMode: sale.paymentMode.isNotEmpty ? sale.paymentMode : 'Cash',
      discount: 0,
      deliveryLink: '',
      deliveryStatus: '',
      item: sale.itemName,
      paymentHistory: fixedPaymentHistory, // ✅ GUARANTEED NON-EMPTY
      deliveryStatusHistory: const [],
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaymentHistoryPage(sale: tempSale)),
    );
  }

  Future<String?> _getCurrentUserEmailFromHive() async {
    try {
      final sessionBox = await Hive.openBox('session');
      return sessionBox.get('currentUserEmail');
    } catch (e) {
      debugPrint('Error getting current user email: $e');
      return null;
    }
  }

  Future<User?> _getCurrentUser() async {
    try {
      final usersBox = Hive.box<User>('users');
      final sessionBox = await Hive.openBox('session');
      final currentUserEmail = sessionBox.get('currentUserEmail');

      if (currentUserEmail != null) {
        final matchingUser = usersBox.values.firstWhere(
          (u) =>
              u.email.trim().toLowerCase() ==
              currentUserEmail.trim().toLowerCase(),
          orElse:
              () => User(
                name: '',
                email: '',
                phone: '',
                role: '',
                upiId: '',
                imageUrl: '',
                password: '',
              ),
        );
        return matchingUser;
      } else {
        return usersBox.values.isNotEmpty ? usersBox.values.first : null;
      }
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return null;
    }
  }

  Future<double?> _showAmountDialog(
    BuildContext context,
    double balanceAmount,
  ) async {
    return await showDialog<double?>(
      context: context,
      builder: (context) => _buildAmountDialog(context, balanceAmount),
    );
  }

  Widget _buildAmountDialog(BuildContext context, double balanceAmount) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth < 400 ? screenWidth * 0.9 : 400.0;
    final controller = TextEditingController(
      text: balanceAmount.toStringAsFixed(2),
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF2563EB),
                        Color(0xFF1E40AF),
                        Color(0xFF020617),
                      ],
                      stops: [0.0, 0.6, 1.0],
                      begin: Alignment.bottomRight,
                      end: Alignment.topLeft,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: const [
                      Icon(
                        Icons.qr_code_2_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Customize UPI Amount',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Enter the amount you want to show in the UPI QR. Leave it empty if the customer should enter manually.",
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Amount (₹)',
                          prefixIcon: const Icon(Icons.currency_rupee),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            onPressed: () => Navigator.pop(context, null),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Colors.transparent, // required for gradient
                              shadowColor: Colors.transparent,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              final input = controller.text.trim();
                              if (input.isEmpty) {
                                Navigator.pop(context, 0.0);
                                return;
                              }

                              final parsed = double.tryParse(input);
                              if (parsed == null || parsed <= 0) {
                                Navigator.pop(context, 0.0);
                                return;
                              }

                              Navigator.pop(context, parsed);
                            },
                            child: Ink(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF2563EB),
                                    Color(0xFF1E40AF),
                                    Color(0xFF020617),
                                  ],
                                  stops: [0.0, 0.6, 1.0],
                                  begin: Alignment.bottomRight,
                                  end: Alignment.topLeft,
                                ),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(10),
                                ),
                              ),
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                child: const Text(
                                  'Generate QR',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<pw.MemoryImage?> _getProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserEmail = await _getCurrentUserEmailFromHive();

      if (currentUserEmail == null) return null;

      final path = prefs.getString('${currentUserEmail}_profileImagePath');
      if (path == null || path.isEmpty) return null;

      final file = File(path);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;

      return pw.MemoryImage(bytes);
    } catch (e) {
      debugPrint('Error loading profile image: $e');
      return null;
    }
  }

  String _generateQrData(double? enteredAmount, User currentUser) {
    final upiId = currentUser.upiId;
    final name = Uri.encodeComponent(currentUser.name);

    if (enteredAmount != null && enteredAmount > 0) {
      return 'upi://pay?pa=$upiId&pn=$name&am=${enteredAmount.toStringAsFixed(2)}&cu=INR';
    } else {
      return 'upi://pay?pa=$upiId&pn=$name&cu=INR';
    }
  }

  pw.Widget _upiOptionButton(String title, pw.MemoryImage icon, String link) {
    return pw.UrlLink(
      destination: link, // ✅ now real upi://pay
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 10),
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey200,
          borderRadius: pw.BorderRadius.circular(14),
        ),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Image(icon, width: 16, height: 16),
            pw.SizedBox(width: 8),
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 11, color: PdfColors.black),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSharePdf(BuildContext context) async {
    final List<String> itemList =
        sale.itemName
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    final bool hasMultipleItems = itemList.length > 1;

    final String itemLabel = hasMultipleItems ? 'Items' : 'Item';

    final String itemDisplayValue =
        hasMultipleItems ? itemList.join(' , ') : itemList.first;

    try {
      final pdf = pw.Document();
      final ttf = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
      );

      final userName =
          currentUserName.isNotEmpty ? currentUserName : 'Unknown User';
      final customerName =
          (sale.customerName.isNotEmpty) ? sale.customerName : 'N/A';
      final customerPhone =
          (sale.customerPhone.isNotEmpty) ? sale.customerPhone : 'N/A';
      final ratePerDay = sale.ratePerDay.toStringAsFixed(2);
      final numberOfDays = sale.numberOfDays.toString();
      // ignore: unused_local_variable
      final totalCost = sale.totalCost.toStringAsFixed(2);
      final double originalTotal = sale.ratePerDay * sale.numberOfDays;
      final double discountAmount = (originalTotal - sale.totalCost).clamp(
        0,
        double.infinity,
      );
      final double finalTotal = sale.totalCost;
      final double balanceAfterDiscount =
          (finalTotal - sale.amountPaid).clamp(0, double.infinity).toDouble();
      final invoiceDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final profileImage = await _getProfileImage();

      final gpayIcon =
          (await rootBundle.load('assets/icons/Gpay.png')).buffer.asUint8List();

      final phonePeIcon =
          (await rootBundle.load(
            'assets/icons/Phonepe.png',
          )).buffer.asUint8List();

      final paytmIcon =
          (await rootBundle.load(
            'assets/icons/Paytm.png',
          )).buffer.asUint8List();

      pw.Widget? profileImageWidget;

      if (profileImage != null) {
        profileImageWidget = pw.Container(
          width: 60,
          height: 60,
          decoration: pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            border: pw.Border.all(color: PdfColors.grey, width: 1),
          ),
          child: pw.ClipOval(
            child: pw.Image(profileImage, fit: pw.BoxFit.cover),
          ),
        );
      } else {
        profileImageWidget = pw.Container(
          width: 60,
          height: 60,
          decoration: pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            color: PdfColors.grey300,
            border: pw.Border.all(color: PdfColors.grey, width: 1),
          ),
          child: pw.Center(
            child: pw.Text(
              currentUserName.isNotEmpty
                  ? currentUserName[0].toUpperCase()
                  : "U",
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
        );
      }

      final currentUser = await _getCurrentUser();

      if (currentUser == null || currentUser.upiId.isEmpty) {
        AppSnackBar.showWarning(
          context,
          message: "Please set your UPI ID in Profile first",
          duration: Duration(seconds: 2),
        );
        return;
      }

      final balanceAmount =
          (sale.totalCost - sale.amountPaid)
              .clamp(0, double.infinity)
              .toDouble();

      final enteredAmount = await _showAmountDialog(context, balanceAmount);

      final qrData = _generateQrData(enteredAmount, currentUser);

      final googlePayLink = _generateGooglePayLink(
        currentUser.upiId,
        currentUser.name,
        enteredAmount,
      );

      final phonePeLink = _generatePhonePeLink(
        currentUser.upiId,
        currentUser.name,
        enteredAmount,
      );

      final paytmLink = _generatePaytmLink(
        currentUser.upiId,
        currentUser.name,
        enteredAmount,
      );

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // HEADER
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (profileImageWidget != null) profileImageWidget,
                    if (profileImageWidget != null) pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            userName,
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            'Phone: +91 ${currentUserPhone.isNotEmpty ? currentUserPhone : "N/A"}',
                          ),
                          pw.Text(
                            'Email: ${currentUserEmail.isNotEmpty ? currentUserEmail : "N/A"}',
                          ),
                          if (currentUser.upiId.isNotEmpty)
                            pw.Text(
                              'UPI ID: ${currentUser.upiId}',
                              style: pw.TextStyle(fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Divider(),
                pw.Center(
                  child: pw.Text(
                    'Rental Invoice',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF1E40AF),
                    ),
                  ),
                ),
                pw.SizedBox(height: 12),

                // MAIN CONTENT
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // LEFT: BILL TO + QR
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Bill To',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(customerName),
                          pw.Text('Phone: +91 $customerPhone'),
                          pw.SizedBox(height: 12),

                          // ***************************************
                          //     🔥 SHOW QR ONLY IF BALANCE > 0
                          // ***************************************
                          if (balanceAmount > 0) ...[
                            pw.BarcodeWidget(
                              data: qrData,
                              barcode: pw.Barcode.qrCode(),
                              width: 120,
                              height: 120,
                            ),

                            pw.SizedBox(height: 8),

                            pw.Text(
                              'Scan or Tap to Pay',
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),

                            pw.SizedBox(height: 40),

                            // ⬇️ CLICKABLE UPI PAYMENT LINK
                            pw.Container(
                              padding: pw.EdgeInsets.all(16),
                              decoration: pw.BoxDecoration(
                                borderRadius: pw.BorderRadius.circular(8),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    "Pay with UPI",
                                    style: pw.TextStyle(
                                      fontSize: 14,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.grey900,
                                    ),
                                  ),

                                  pw.SizedBox(height: 12),

                                  pw.Row(
                                    mainAxisAlignment:
                                        pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      _upiOptionButton(
                                        "Google Pay",
                                        pw.MemoryImage(gpayIcon),
                                        googlePayLink,
                                      ),
                                      _upiOptionButton(
                                        "PhonePe",
                                        pw.MemoryImage(phonePeIcon),
                                        phonePeLink,
                                      ),
                                      _upiOptionButton(
                                        "Paytm",
                                        pw.MemoryImage(paytmIcon),
                                        paytmLink,
                                      ),
                                    ],
                                  ),

                                  pw.SizedBox(height: 10),

                                  pw.Text(
                                    "Tap any app above to pay",
                                    style: pw.TextStyle(
                                      fontSize: 10,
                                      color: PdfColors.grey600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    pw.SizedBox(width: 20),

                    // RIGHT: TABLE
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Invoice Details',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text('Invoice No.: #001'),
                          pw.Text('Date: $invoiceDate'),
                          pw.SizedBox(height: 8),
                          pw.Table(
                            border: pw.TableBorder.all(
                              color: PdfColors.grey300,
                            ),
                            columnWidths: {
                              0: const pw.FlexColumnWidth(3),
                              1: const pw.FlexColumnWidth(2),
                            },
                            children: [
                              _buildTableRow(itemLabel, itemDisplayValue, ttf),
                              _buildTableRow(
                                'Rate / Day',
                                '₹ $ratePerDay',
                                ttf,
                              ),
                              _buildTableRow('Days', numberOfDays, ttf),
                              pw.TableRow(
                                children: [
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text(
                                      'Sub Total',
                                      style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text(
                                      '₹ ${originalTotal.toStringAsFixed(2)}',
                                      style: pw.TextStyle(font: ttf),
                                    ),
                                  ),
                                ],
                              ),
                              pw.TableRow(
                                children: [
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text(
                                      'Discount',
                                      style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text(
                                      discountAmount > 0
                                          ? '- ₹ ${discountAmount.toStringAsFixed(2)}'
                                          : '₹ 0.00',
                                      style: pw.TextStyle(font: ttf),
                                    ),
                                  ),
                                ],
                              ),
                              pw.TableRow(
                                children: [
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text(
                                      'Total',
                                      style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text(
                                      '₹ ${finalTotal.toStringAsFixed(2)}',
                                      style: pw.TextStyle(font: ttf),
                                    ),
                                  ),
                                ],
                              ),
                              _buildTableRow(
                                'Paid',
                                '₹ ${sale.amountPaid.toStringAsFixed(2)}',
                                ttf,
                              ),
                              pw.TableRow(
                                children: [
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text(
                                      'Balance',
                                      style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text(
                                      '₹ ${balanceAfterDiscount.toStringAsFixed(2)}',
                                      style: pw.TextStyle(font: ttf),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 16),
                pw.Text(
                  'Terms and Conditions:',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  '1. All rented items must be returned by the agreed date and time.\n'
                  '2. The customer is responsible for any loss, theft, or damage to the rented items.\n'
                  '3. Payment must be completed in full before item delivery.\n'
                  '4. Late returns will incur additional charges as specified in the rental agreement.\n'
                  '5. Items must be returned in the same condition as received, including all accessories and packaging.\n'
                  '6. Any modification, tampering, or misuse of the rented items is strictly prohibited.\n'
                  '7. Cancellation or rescheduling may be subject to a fee as per the rental policy.\n'
                  '8. The rental provider reserves the right to refuse service for misuse or violation of terms.\n'
                  '9. Insurance or damage protection fees, if applicable, must be paid upfront.\n'
                  '10. By renting, the customer agrees to these terms and acknowledges responsibility for compliance.',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 16),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'For: $customerName',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Save file to temp dir
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${customerName}_rental.pdf');
      await file.writeAsBytes(await pdf.save());

      // Persist pdfFilePath into userBox (optional but useful)
      try {
        sale.pdfFilePath = file.path;

        final raw = userBox.get('rental_sales', defaultValue: []);
        final List<RentalSaleModel> persisted =
            (raw as List).map((e) => e as RentalSaleModel).toList();

        final int idx = persisted.indexWhere((s) => _isSameSale(s, sale));
        if (idx != -1) {
          persisted[idx] = sale;
        }

        await userBox.put('rental_sales', persisted);
      } catch (e) {
        debugPrint('Failed to persist pdfFilePath to userBox: $e');
      }

      // Open preview screen
      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => RentalPdfPreviewScreen(
                  filePath: file.path,
                  sale: sale,
                  userName: currentUserName,
                  customerName: sale.customerName,
                ),
          ),
        );
      }
    } catch (e) {
      debugPrint('PDF generation error: $e');
      AppSnackBar.showError(
        context,
        message: 'Failed to generate PDF: $e',
        duration: const Duration(seconds: 2),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // TABLE ROW (AS YOU WROTE IT)
  // ---------------------------------------------------------------------------

  pw.TableRow _buildTableRow(String title, String value, pw.Font font) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            title,
            style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value, style: pw.TextStyle(font: font)),
        ),
      ],
    );
  }
}
