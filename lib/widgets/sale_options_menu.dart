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

  String generateGooglePayLink(String upiUri) {
    final encoded = Uri.encodeComponent(upiUri);
    return "tez://upi/pay?url=$encoded";
  }

  String generatePhonePeLink(String upiUri) {
    final encoded = Uri.encodeComponent(upiUri);
    return "phonepe://upi/pay?url=$encoded";
  }

  String generatePaytmLink(String upiUri) {
    final encoded = Uri.encodeComponent(upiUri);
    return "paytm://upi/pay?url=$encoded";
  }

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

  void _handleDeliveryTracker(BuildContext context) async {
    final box = await Hive.openBox<Sale>('sales');

    // If sale is already in box → good
    if (sale.isInBox) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => DeliveryTrackerPage(
                sale: sale,
                phoneWithCountryCode: sale.phoneNumber,
                phoneWithoutCountryCode: sale.phoneNumber,
              ),
        ),
      );
      return;
    }

    // Otherwise, find the Hive version of this sale
    final hiveSale = box.values.firstWhere(
      (s) =>
          s.customerName == sale.customerName &&
          s.phoneNumber == sale.phoneNumber &&
          s.dateTime == sale.dateTime,
      orElse: () => sale,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => DeliveryTrackerPage(
              sale: hiveSale, // ✔ now always inBox
              phoneWithCountryCode: hiveSale.phoneNumber,
              phoneWithoutCountryCode: hiveSale.phoneNumber,
            ),
      ),
    );
  }

  Future<void> _handlePaymentReminder(BuildContext context) async {
    final double balanceAmount = sale.totalAmount - sale.amount;

    // ✅ Normalize phone number
    String rawPhone = sale.phoneNumber.trim();
    rawPhone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');

    String phone;
    if (rawPhone.startsWith('+')) {
      phone = rawPhone.substring(1);
    } else if (rawPhone.length == 10) {
      phone = '91$rawPhone';
    } else {
      phone = rawPhone;
    }

    if (phone.length < 10) {
      AppSnackBar.showError(
        context,
        message: "Phone number not available or invalid",
        duration: const Duration(seconds: 2),
      );
      return;
    }

    final usersBox = Hive.box<User>('users');
    final currentUser = await _getCurrentUser(usersBox);

    if (currentUser == null || currentUser.upiId.isEmpty) {
      AppSnackBar.showWarning(
        context,
        message: "Please set your UPI ID in your profile first",
        duration: const Duration(seconds: 2),
      );
      return;
    }

    final String sender =
        currentUserName.isNotEmpty ? currentUserName : 'Accounts Team';

    /// ✅ STEP 1: Build UPI intent (RAW)
    final String upiIntent =
        "upi://pay"
        "?pa=${currentUser.upiId}"
        "&pn=$sender"
        "&am=${balanceAmount.toStringAsFixed(2)}"
        "&cu=INR";

    /// ✅ STEP 2: Encode UPI link fully (THIS FIXES AMOUNT ISSUE)
    final String encodedUpiLink = Uri.encodeFull(upiIntent);

    /// ✅ STEP 3: WhatsApp message
    final String message =
        "Dear ${sale.customerName},\n\n"
        "Payment reminder from $sender 👋\n\n"
        "📅 Due Date: ${DateFormat('dd MMM yyyy').format(sale.dateTime)}\n"
        "💰 Amount Due: ₹${balanceAmount.toStringAsFixed(2)}\n"
        "${invoiceNumber != null ? "📋 Invoice #: $invoiceNumber\n" : ""}\n"
        "✅ Tap below to pay via UPI:\n"
        "${currentUser.upiId}\n\n"
        "Please confirm once payment is completed.\n\n"
        "Regards,\n$sender";

    try {
      final String encodedMessage = Uri.encodeComponent(message);
      final Uri whatsappUri = Uri.parse(
        "https://wa.me/$phone?text=$encodedMessage",
      );

      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      AppSnackBar.showError(
        context,
        message: "Unable to open WhatsApp on this device",
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
    final gpayIcon =
        (await rootBundle.load("assets/icons/Gpay.png")).buffer.asUint8List();
    final phonePeIcon =
        (await rootBundle.load(
          "assets/icons/Phonepe.png",
        )).buffer.asUint8List();
    final paytmIcon =
        (await rootBundle.load("assets/icons/Paytm.png")).buffer.asUint8List();

    // NOW generate UPI link (correct order)

    final rupeeFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );

    final enteredAmount = await _showAmountDialog(
      context,
      balanceAmount.toDouble(),
    );

    final usersBox = Hive.box<User>('users');
    final currentUser = await _getCurrentUser(usersBox);

    // Now generate QR code
    final qrData = _generateQrData(enteredAmount, currentUser!);

    final googlePayLink =
        "gpay://upi/pay?pa=${currentUser.upiId}&pn=${Uri.encodeComponent(currentUser.name)}&am=${enteredAmount?.toStringAsFixed(2)}&cu=INR";

    final phonePeLink =
        "phonepe://pay?pa=${currentUser.upiId}&pn=${Uri.encodeComponent(currentUser.name)}&am=${enteredAmount?.toStringAsFixed(2)}&cu=INR";

    final paytmLink =
        "paytm://upi/pay?pa=${currentUser.upiId}&pn=${Uri.encodeComponent(currentUser.name)}&am=${enteredAmount?.toStringAsFixed(2)}&cu=INR";

    if (currentUser.upiId.isEmpty) {
      AppSnackBar.showWarning(
        context,
        message: "Please set your UPI ID in your profile first",
        duration: Duration(seconds: 2),
      );
      return;
    }

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
              googlePayLink,
              phonePeLink,
              paytmLink,
              pw.MemoryImage(gpayIcon),
              pw.MemoryImage(phonePeIcon),
              pw.MemoryImage(paytmIcon),
            ),
      ),
    );

    final output = await getTemporaryDirectory();

    // Generate long filename
    final formattedDate = DateFormat('dd-MM-yyyy').format(sale.dateTime);
    final safeCustomerName = sale.customerName.replaceAll(" ", "_");

    final longFileName =
        "Invoice_${invoiceNumber}_${safeCustomerName}_${formattedDate}_₹${sale.totalAmount.toStringAsFixed(0)}.pdf";

    // Create file
    final file = File("${output.path}/$longFileName");

    // Save file
    await file.writeAsBytes(await pdf.save());
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

                      /// ✅ ACTIONS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          /// ✅ CANCEL → JUST CLOSE DIALOG
                          TextButton(
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop(); // ✅ CLOSE ONLY
                            },
                          ),
                          const SizedBox(width: 10),

                          /// ✅ GENERATE QR
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

                              // ❌ EMPTY → close dialog, DO NOTHING
                              if (input.isEmpty) {
                                Navigator.of(context).pop();
                                return;
                              }

                              final parsed = double.tryParse(input);

                              // ❌ INVALID or ZERO → close dialog, DO NOTHING
                              if (parsed == null || parsed <= 0) {
                                Navigator.of(context).pop();
                                return;
                              }

                              // ✅ VALID AMOUNT
                              Navigator.of(context).pop(parsed);
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

  pw.Widget _upiOption(String title, pw.MemoryImage icon, String url) {
    const double fontSize = 11.0;
    const double iconSize = 16.0;
    const double horizontalPadding = 14.0;
    const double verticalPadding = 10.0;
    const double gap = 8.0;

    return pw.UrlLink(
      destination: url,
      child: pw.Container(
        margin: pw.EdgeInsets.only(right: 11), // spacing between items
        padding: pw.EdgeInsets.symmetric(
          vertical: verticalPadding,
          horizontal: horizontalPadding,
        ),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey200, // ⭐ Background color for each button
          borderRadius: pw.BorderRadius.circular(14),
        ),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Image(icon, width: iconSize, height: iconSize),
            pw.SizedBox(width: gap),
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: fontSize, color: PdfColors.black),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildPdfPage(
    double balanceAmount,
    pw.Font rupeeFont,
    String qrData,
    Uint8List? profileImageBytes,
    User currentUser,
    String googlePayLink,
    String phonePeLink,
    String paytmLink,
    pw.MemoryImage gpayIcon,
    pw.MemoryImage phonePeIcon,
    pw.MemoryImage paytmIcon,
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
                    // Payment Section (QR + Link)
                    if (balanceAmount > 0) ...[
                      pw.Center(
                        child: pw.BarcodeWidget(
                          data: qrData,
                          barcode: pw.Barcode.qrCode(),
                          width: 150,
                          height: 150,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Center(
                        child: pw.Text(
                          "Scan & Pay via UPI",
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 7),

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
                                _upiOption(
                                  "Google Pay",
                                  gpayIcon,
                                  googlePayLink,
                                ),
                                _upiOption("PhonePe", phonePeIcon, phonePeLink),
                                _upiOption("Paytm", paytmIcon, paytmLink),
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

                      pw.SizedBox(height: 16),
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
          pw.SizedBox(height: 8),
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
