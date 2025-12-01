// sale_options_menu.dart
// ignore_for_file: unnecessary_null_comparison

import 'package:bizmate/screens/DeliveryTrackerPage.dart'
    show DeliveryTrackerPage;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:typed_data'; // Add this import for Uint8List

// Import your models and screens
import '../models/sale.dart';
import '../models/user_model.dart';
import '../screens/pdf_preview_screen.dart';
import '../screens/payment_history_page.dart';
// import '../screens/delivery_tracker_page.dart'; // Comment out if file doesn't exist
import '../widgets/app_snackbar.dart';
import '../widgets/confirm_delete_dialog.dart';

class SaleOptionsMenu extends StatelessWidget {
  final Sale sale;
  final int originalIndex;
  final Box box; // accepts any Hive box
  final bool isSmallScreen;
  final String invoiceNumber;
  final String currentUserName;
  final String currentUserPhone;
  final String currentUserEmail;
  final BuildContext parentContext;

  const SaleOptionsMenu({
    Key? key,
    required this.sale,
    required this.originalIndex,
    required this.box,
    required this.isSmallScreen,
    required this.invoiceNumber,
    required this.currentUserName,
    required this.currentUserPhone,
    required this.currentUserEmail,
    required this.parentContext,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: isSmallScreen ? 20 : 24),
      onSelected: (value) => _handleMenuSelection(value, context),
      itemBuilder: (context) => _buildMenuItems(),
    );
  }

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
        value: 'delivery_tracker',
        child: Row(
          children: [
            Icon(
              Icons.delivery_dining_rounded,
              color: Colors.purple,
              size: isSmallScreen ? 18 : 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Photo Delivery Tracker',
              style: TextStyle(fontSize: isSmallScreen ? 12 : null),
            ),
          ],
        ),
      ),
      if (sale.amount < sale.totalAmount)
        PopupMenuItem(
          value: 'payment_reminder',
          child: Row(
            children: [
              Icon(
                Icons.notifications_active,
                color: Colors.orange,
                size: isSmallScreen ? 18 : 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Send Payment Reminder',
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
      case 'delivery_tracker':
        _handleDeliveryTracker(context);
        break;
      case 'payment_reminder':
        await _handlePaymentReminder(context);
        break;
    }
  }

  Future<void> _handleDelete(BuildContext context) async {
    await showConfirmDialog(
      context: context,
      title: "Confirm Deletion",
      message:
          "Are you sure you want to delete this sale? This action cannot be undone.",
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.redAccent,
      onConfirm: () async {
        try {
          // 1. Load sales list
          List<Sale> sales = List<Sale>.from(
            box.get("sales", defaultValue: []),
          );

          // 2. Remove this sale from list
          sales.remove(sale);

          // 3. Write list back to Hive
          await box.put("sales", sales);

          // 4. Update UI
          AppSnackBar.showSuccess(
            parentContext,
            message: "Sale deleted successfully.",
            duration: Duration(seconds: 2),
          );
        } catch (e) {
          AppSnackBar.showError(
            parentContext,
            message: "Failed to delete sale: $e",
            duration: Duration(seconds: 2),
          );
        }
      },
    );
  }

  void _handlePaymentHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaymentHistoryPage(sale: sale)),
    );
  }

  void _handleDeliveryTracker(BuildContext context) {
    String rawNumber = '+91 ${sale.phoneNumber}';
    String phoneWithCountryCode =
        rawNumber.startsWith('+91') ? rawNumber : '+91$rawNumber';
    String phoneWithoutCountryCode = rawNumber.replaceFirst('+91', '');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => DeliveryTrackerPage(
              sale: sale,
              phoneWithCountryCode: phoneWithCountryCode,
              phoneWithoutCountryCode: phoneWithoutCountryCode,
            ),
      ),
    );
  }

  Future<void> _handlePaymentReminder(BuildContext context) async {
    final balanceAmount = sale.totalAmount - sale.amount;
    final phone =
        sale.phoneNumber.replaceAll('+91', '').replaceAll(' ', '').trim();

    if (phone.isEmpty || phone.length < 10) {
      AppSnackBar.showError(
        context,
        message: "Phone number not available or invalid",
        duration: const Duration(seconds: 2),
      );
      return;
    }

    final usersBox = Hive.box<User>('users');
    final currentUser = await _getCurrentUser(usersBox);

    if (currentUser?.upiId.isEmpty ?? true) {
      AppSnackBar.showWarning(
        context,
        message: "Please set your UPI ID in your profile first",
        duration: Duration(seconds: 2),
      );
      return;
    }

    String message;
    if (sale.dateTime != null &&
        balanceAmount != null &&
        invoiceNumber != null) {
      message =
          "Dear ${sale.customerName},\n\nFriendly reminder from ${currentUserName.isNotEmpty ? currentUserName : ''}:\n\n"
          "📅 Payment Due: ${DateFormat('dd MMM yyyy').format(sale.dateTime)}\n"
          "💰 Amount: ₹${balanceAmount.toStringAsFixed(2)}\n"
          "📋 Invoice #: $invoiceNumber\n\n"
          "Payment Methods:\n"
          "• UPI: ${currentUser!.upiId}\n"
          "• Bank Transfer (Details attached)\n"
          "• Cash (At our studio)\n\n"
          "Please confirm once payment is made. Thank you for your prompt attention!\n\n"
          "Warm regards,\nAccounts Team\n${currentUserName.isNotEmpty ? currentUserName : ''}";
    } else {
      message =
          "Dear ${sale.customerName},\n\nThis is a friendly reminder regarding your payment. "
          "Please contact us for invoice details.\n\n"
          "Warm regards,\nAccounts Team\n${currentUserName.isNotEmpty ? currentUserName : ''}";
    }

    try {
      final encodedMessage = Uri.encodeComponent(message);
      final url1 = "https://wa.me/$phone?text=$encodedMessage";
      final url2 = "https://wa.me/91$phone?text=$encodedMessage";

      canLaunchUrl(Uri.parse(url1)).then((canLaunch) {
        if (canLaunch) {
          launchUrl(Uri.parse(url1), mode: LaunchMode.externalApplication);
        } else {
          launchUrl(Uri.parse(url2), mode: LaunchMode.externalApplication);
        }
      });
    } catch (e) {
      AppSnackBar.showError(
        context,
        message: "Couldn't open WhatsApp",
        duration: const Duration(seconds: 2),
      );
    }
  }

  Future<void> _handleSharePdf(BuildContext context) async {
    final pdf = pw.Document();
    final balanceAmount = (sale.totalAmount - sale.amount).clamp(
      0,
      double.infinity,
    );
    final rupeeFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );

    final enteredAmount = await _showAmountDialog(
      context,
      balanceAmount.toDouble(),
    );

    final usersBox = Hive.box<User>('users');
    final currentUser = await _getCurrentUser(usersBox);

    if (currentUser?.upiId.isEmpty ?? true) {
      AppSnackBar.showWarning(
        context,
        message: "Please set your UPI ID in your profile first",
        duration: Duration(seconds: 2),
      );
      return;
    }

    final qrData = _generateQrData(enteredAmount, currentUser!);

    final profileImageBytes = await _getProfileImageBytes();

    pdf.addPage(
      pw.Page(
        build:
            (pw.Context context) => _buildPdfPage(
              balanceAmount.toDouble(),
              rupeeFont,
              qrData,
              profileImageBytes,
              currentUser,
            ),
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/invoice_$invoiceNumber.pdf");
    await file.writeAsBytes(await pdf.save());

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(filePath: file.path, sale: sale),
        ),
      );
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
                    color: Colors.deepPurple,
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
                              backgroundColor: Colors.deepPurple,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
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
                            child: const Text(
                              'Generate QR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
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

  String _generateQrData(double? enteredAmount, User currentUser) {
    if (enteredAmount != null && enteredAmount > 0) {
      return 'upi://pay?pa=${currentUser.upiId}&pn=${Uri.encodeComponent(currentUser.name)}&am=${enteredAmount.toStringAsFixed(2)}&cu=INR';
    } else {
      return 'upi://pay?pa=${currentUser.upiId}&pn=${Uri.encodeComponent(currentUser.name)}&cu=INR';
    }
  }

  Future<User?> _getCurrentUser(Box<User> usersBox) async {
    try {
      final sessionBox = await Hive.openBox('session');
      final currentUserEmail = sessionBox.get('currentUserEmail');

      if (currentUserEmail != null) {
        // ✅ Always fetch the latest saved user data by email from Hive
        final matchingUser = usersBox.values.firstWhere(
          (user) =>
              user.email.trim().toLowerCase() ==
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

        // Return only if user exists
        if (matchingUser.upiId.isNotEmpty) {
          return matchingUser;
        } else {
          debugPrint('UPI ID is empty for the current user in Hive.');
          return matchingUser;
        }
      } else {
        debugPrint('No current user email found in session.');
        return usersBox.values.isNotEmpty ? usersBox.values.first : null;
      }
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return usersBox.values.isNotEmpty ? usersBox.values.first : null;
    }
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

  Future<Uint8List?> _getProfileImageBytes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserEmail = await _getCurrentUserEmailFromHive();

      debugPrint('=== DEBUG PROFILE IMAGE LOADING ===');
      debugPrint('Current User Email: $currentUserEmail');

      if (currentUserEmail != null) {
        final profileImagePath = prefs.getString(
          '${currentUserEmail}_profileImagePath',
        );

        debugPrint(
          'Profile Image Path from SharedPreferences: $profileImagePath',
        );

        if (profileImagePath != null && profileImagePath.isNotEmpty) {
          final profileFile = File(profileImagePath);
          final fileExists = await profileFile.exists();
          debugPrint('Profile file exists: $fileExists');

          if (fileExists) {
            final imageBytes = await profileFile.readAsBytes();
            debugPrint(
              'Image bytes loaded successfully. Size: ${imageBytes.length} bytes',
            );

            if (imageBytes.isNotEmpty) {
              debugPrint('=== PROFILE IMAGE LOADED SUCCESSFULLY ===');
              return Uint8List.fromList(imageBytes);
            } else {
              debugPrint('ERROR: Image bytes are empty');
            }
          } else {
            debugPrint(
              'ERROR: Profile image file does not exist at path: $profileImagePath',
            );
            // Remove invalid path from shared preferences
            await prefs.remove('${currentUserEmail}_profileImagePath');
          }
        } else {
          debugPrint('ERROR: No profile image path found in SharedPreferences');
        }
      } else {
        debugPrint('ERROR: No current user email found in Hive session');
      }
    } catch (e) {
      debugPrint('ERROR loading profile image: $e');
    }

    debugPrint('=== PROFILE IMAGE LOADING FAILED ===');
    return null;
  }

  pw.Widget _buildPdfPage(
    double balanceAmount,
    pw.Font rupeeFont,
    String qrData,
    Uint8List? profileImageBytes,
    User currentUser,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 2),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      padding: const pw.EdgeInsets.all(16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header with Profile Image
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Profile Image - Circular with proper styling
              if (profileImageBytes != null && profileImageBytes.isNotEmpty)
                pw.Container(
                  width: 60,
                  height: 60,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    border: pw.Border.all(color: PdfColors.grey, width: 1),
                  ),
                  child: pw.ClipOval(
                    child: pw.Image(
                      pw.MemoryImage(profileImageBytes),
                      fit: pw.BoxFit.cover,
                    ),
                  ),
                )
              else
                // Fallback when no profile image
                pw.Container(
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
                          : currentUser.name.isNotEmpty
                          ? currentUser.name[0].toUpperCase()
                          : 'U',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ),

              pw.SizedBox(width: 16),

              // User Information
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      currentUserName.isNotEmpty
                          ? currentUserName
                          : currentUser.name,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Phone: +91 ${currentUserPhone.isNotEmpty ? currentUserPhone : currentUser.phone}',
                    ),
                    pw.Text(
                      'Email: ${currentUserEmail.isNotEmpty ? currentUserEmail : currentUser.email}',
                    ),
                    if (currentUser.upiId.isNotEmpty)
                      pw.Text(
                        'UPI ID: ${currentUser.upiId}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
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
              'Tax Invoice',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.indigo,
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Bill To',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(sale.customerName),
                    pw.Text('Contact No.: +91 ${sale.phoneNumber}'),
                    pw.SizedBox(height: 12),
                    if (balanceAmount > 0) ...[
                      // QR Code
                      pw.Center(
                        child: pw.BarcodeWidget(
                          data: qrData,
                          barcode: pw.Barcode.qrCode(),
                          width: 120,
                          height: 120,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Center(
                        child: pw.Text(
                          "Scan to Pay UPI",
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Invoice Details',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text('Invoice No.: #$invoiceNumber'),
                    pw.Text(
                      'Date: ${DateFormat('dd-MM-yyyy').format(sale.dateTime)}',
                    ),
                    pw.SizedBox(height: 8),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(3),
                        1: const pw.FlexColumnWidth(2),
                      },
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: PdfColors.indigo100,
                          ),
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
                                '₹ ${(sale.totalAmount + sale.discount).toStringAsFixed(2)}',
                                style: pw.TextStyle(font: rupeeFont),
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
                                '₹ ${sale.discount.toStringAsFixed(2)}',
                                style: pw.TextStyle(font: rupeeFont),
                              ),
                            ),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text('Received'),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                '₹ ${sale.amount.toStringAsFixed(2)}',
                                style: pw.TextStyle(font: rupeeFont),
                              ),
                            ),
                          ],
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
                                '₹ ${balanceAmount.toStringAsFixed(2)}',
                                style: pw.TextStyle(font: rupeeFont),
                              ),
                            ),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text('Payment Mode'),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(sale.paymentMode),
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
          // Terms and Conditions
          pw.Text(
            'Terms and Conditions:',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ..._buildTermsAndConditions(),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'For: ${sale.customerName}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildTermsAndConditions() {
    final terms = [
      '1. All photographs remain the property of $currentUserName and are protected by copyright law.',
      '2. Client is granted personal use license for the photographs, not for commercial purposes.',
      '3. Delivery timelines are estimates and may vary based on workload and complexity.',
      '4. Rush delivery services may incur additional charges.',
      '5. Once delivered, client is responsible for backup and storage of digital files.',
      '6. Re-shoots may be requested within 7 days of delivery if quality issues are found.',
      '7. Payments are non-refundable once services have been rendered.',
      '8. Balance amount must be paid in full before final delivery of photographs.',
      '9. If advance payment is made, the photo shoot will be considered officially booked and reserved.',
      '10. If the program takes extra hours beyond the agreed timeframe, additional charges will apply.',
      '11. Weather conditions may affect outdoor shoots and may require rescheduling.',
      '12. Client must provide access to suitable locations for the shoot as agreed upon.',
      '13. Raw files are not included in the package unless specified in writing.',
      '14. The photographer retains the right to use images for portfolio and marketing purposes.',
      '15. Client cooperation is essential for achieving desired results.',
    ];

    return terms
        .map(
          (term) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(term, style: const pw.TextStyle(fontSize: 10)),
          ),
        )
        .toList();
  }
}
