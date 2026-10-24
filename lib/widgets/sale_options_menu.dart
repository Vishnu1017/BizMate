// sale_options_menu.dart
// ignore_for_file: unnecessary_null_comparison

import 'package:bizmate/screens/DeliveryTrackerPage.dart'
    show DeliveryTrackerPage;
import 'package:flutter/material.dart';
import 'package:bizmate/utils/app_theme.dart';
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
import '../utils/payment_icons.dart';
import '../utils/upi_payment_helper.dart';

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

  String generateBhimLink(String upiUri) {
    final encoded = Uri.encodeComponent(upiUri);
    return "bhim://upi/pay?url=$encoded";
  }

  const SaleOptionsMenu({
    super.key,
    required this.sale,
    required this.originalIndex,
    required this.box,
    required this.isSmallScreen,
    required this.invoiceNumber,
    required this.currentUserName,
    required this.currentUserPhone,
    required this.currentUserEmail,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getUserRole(),
      builder: (context, snapshot) {
        final role = (snapshot.data ?? '').trim().toLowerCase();
        final is3DPrinting =
            role == '3d printing brand' ||
            role.contains('3d print') ||
            role.contains('printing');
        final isPhotographer = role == 'photographer' || role.contains('photo');

        return PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: isSmallScreen ? 16 : 20),
          onSelected:
              (value) => _handleMenuSelection(
                value,
                context,
                role: snapshot.data ?? '',
              ),
          itemBuilder: (context) {
            final items = _buildMenuItems(
              is3DPrinting: is3DPrinting,
              isPhotographer: isPhotographer,
            );

            // ❌ Remove tracker if neither photographer nor 3D printing
            if (!isPhotographer && !is3DPrinting) {
              items.removeWhere((item) => item.value == 'delivery_tracker');
            }

            return items;
          },
        );
      },
    );
  }

  List<PopupMenuItem<String>> _buildMenuItems({
    bool is3DPrinting = false,
    bool isPhotographer = false,
  }) {
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
              is3DPrinting
                  ? Icons.local_shipping_rounded
                  : Icons.delivery_dining_rounded,
              color: is3DPrinting ? Colors.teal : Colors.purple,
              size: isSmallScreen ? 18 : 24,
            ),
            const SizedBox(width: 8),
            Text(
              is3DPrinting
                  ? '3D Print Delivery Tracker'
                  : 'Photo Delivery Tracker',
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

  Future<String> _getUserRole() async {
    try {
      final sessionBox =
          Hive.isBoxOpen('session')
              ? Hive.box('session')
              : await Hive.openBox('session');
      final sessionRole = sessionBox.get('currentUserRole')?.toString().trim();
      if (sessionRole != null && sessionRole.isNotEmpty) {
        return sessionRole;
      }

      final email =
          currentUserEmail.isNotEmpty
              ? currentUserEmail
              : (sessionBox.get('currentUserEmail')?.toString().trim() ?? '');
      if (email.isNotEmpty) {
        final safeEmail = email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        final userdataBoxName = 'userdata_$safeEmail';
        if (Hive.isBoxOpen(userdataBoxName)) {
          final uBox = Hive.box(userdataBoxName);
          final role = uBox.get('role')?.toString().trim();
          if (role != null && role.isNotEmpty) return role;
        }

        final usersBox =
            Hive.isBoxOpen('users')
                ? Hive.box<User>('users')
                : await Hive.openBox<User>('users');
        final user = usersBox.values.firstWhere(
          (u) => u.email.trim().toLowerCase() == email.trim().toLowerCase(),
          orElse:
              () => User(
                name: '',
                email: '',
                phone: '',
                password: '',
                role: '',
                upiId: '',
                imageUrl: '',
              ),
        );
        if (user.role.trim().isNotEmpty) {
          return user.role.trim();
        }
      }
    } catch (_) {}
    return '';
  }

  Future<void> _handleMenuSelection(
    String value,
    BuildContext context, {
    String role = '',
  }) async {
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
        _handleDeliveryTracker(context, role: role);
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
          if (!parentContext.mounted) return;
          AppSnackBar.showSuccess(
            parentContext,
            message: "Sale deleted successfully.",
            duration: Duration(seconds: 2),
          );
        } catch (e) {
          if (!parentContext.mounted) return;
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

  void _handleDeliveryTracker(BuildContext context, {String role = ''}) async {
    final box = await Hive.openBox<Sale>('sales');
    if (!context.mounted) return;

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
                userRole: role,
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
              userRole: role,
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

    if (!context.mounted) return;
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

    final String message =
        "Dear ${sale.customerName},\n\n"
        "Payment reminder from $sender 👋\n\n"
        "📅 Due Date: ${DateFormat('dd MMM yyyy').format(sale.dateTime)}\n"
        "💰 Amount Due: ₹${balanceAmount.toStringAsFixed(2)}\n"
        "${invoiceNumber != null ? "📋 Invoice #: $invoiceNumber\n" : ""}\n"
        "UPI ID: ${currentUser.upiId}\n\n"
        "Please confirm once payment is completed.\n\n"
        "Regards,\n$sender";

    try {
      final String encodedMessage = Uri.encodeComponent(message);
      final Uri whatsappUri = Uri.parse(
        "https://wa.me/$phone?text=$encodedMessage",
      );

      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!context.mounted) return;
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
    final bhimIcon = await PaymentIcons.loadBhimIcon();

    // NOW generate UPI link (correct order)

    final rupeeFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );

    if (!context.mounted) return;
    final enteredAmount = await _showAmountDialog(
      context,
      balanceAmount.toDouble(),
    );

    final usersBox = Hive.box<User>('users');
    final currentUser = await _getCurrentUser(usersBox);

    if (currentUser == null || currentUser.upiId.isEmpty) {
      if (context.mounted) {
        AppSnackBar.showWarning(
          context,
          message: "Please set your UPI ID in your profile first",
          duration: const Duration(seconds: 2),
        );
      }
      return;
    }

    // Now generate QR code and cross-platform UPI links
    final qrData = UpiPaymentHelper.buildQrData(
      upiId: currentUser.upiId,
      payeeName: currentUser.name,
      amount: enteredAmount,
    );

    final googlePayLink = UpiPaymentHelper.buildGooglePayLink(
      upiId: currentUser.upiId,
      payeeName: currentUser.name,
      amount: enteredAmount,
    );

    final phonePeLink = UpiPaymentHelper.buildPhonePeLink(
      upiId: currentUser.upiId,
      payeeName: currentUser.name,
      amount: enteredAmount,
    );

    final paytmLink = UpiPaymentHelper.buildPaytmLink(
      upiId: currentUser.upiId,
      payeeName: currentUser.name,
      amount: enteredAmount,
    );

    final bhimLink = UpiPaymentHelper.buildBhimLink(
      upiId: currentUser.upiId,
      payeeName: currentUser.name,
      amount: enteredAmount,
    );

    final upiUniversalLink = UpiPaymentHelper.buildUniversalPaymentLink(
      upiId: currentUser.upiId,
      payeeName: currentUser.name,
      amount: enteredAmount,
    );

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
              bhimLink: bhimLink,
              bhimIcon: pw.MemoryImage(bhimIcon),
              upiUniversalLink: upiUniversalLink,
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
      barrierDismissible: false,
      builder: (context) => _buildAmountDialog(context, balanceAmount),
    );
  }

  Widget _buildAmountDialog(BuildContext context, double balanceAmount) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth < 400 ? screenWidth * 0.9 : 400.0;

    final controller = TextEditingController(
      text: balanceAmount.toStringAsFixed(2),
    );

    return PopScope(
      canPop: false,
      child: Dialog(
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
                      gradient:
                          context.isDark
                              ? const LinearGradient(
                                colors: [
                                  Color(0xFF38BDF8),
                                  Color(0xFF60A5FA),
                                  Color(0xFFBAE6FD),
                                ],
                                stops: [0.0, 0.6, 1.0],
                                begin: Alignment.bottomRight,
                                end: Alignment.topLeft,
                              )
                              : const LinearGradient(
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
                        // Description
                        Text(
                          "Enter the amount you want to show in the UPI QR. Leave it empty if the customer should enter manually.",
                          style: TextStyle(
                            fontSize: 14,
                            color: context.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: controller,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(color: context.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Amount (₹)',
                            labelStyle: TextStyle(color: context.textSecondary),
                            prefixIcon: Icon(
                              Icons.currency_rupee,
                              color:
                                  context.isDark
                                      ? Colors.blue.shade300
                                      : Colors.blue.shade700,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: context.borderColor,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: context.borderColor,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color:
                                    context.isDark
                                        ? Colors.blue.shade300
                                        : Colors.blue.shade700,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor:
                                context.isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.grey[100],
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
                                style: TextStyle(
                                  color:
                                      context.isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade700,
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            const SizedBox(width: 10),

                            /// ✅ GENERATE QR
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.transparent, // IMPORTANT
                                shadowColor: Colors.transparent,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
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
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient:
                                      context.isDark
                                          ? const LinearGradient(
                                            colors: [
                                              Color(0xFF38BDF8),
                                              Color(0xFF60A5FA),
                                              Color(0xFFBAE6FD),
                                            ],
                                            stops: [0.0, 0.6, 1.0],
                                            begin: Alignment.bottomRight,
                                            end: Alignment.topLeft,
                                          )
                                          : const LinearGradient(
                                            colors: [
                                              Color(0xFF2563EB),
                                              Color(0xFF1E40AF),
                                              Color(0xFF020617),
                                            ],
                                            stops: [0.0, 0.6, 1.0],
                                            begin: Alignment.bottomRight,
                                            end: Alignment.topLeft,
                                          ),
                                  borderRadius: const BorderRadius.all(
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
      ),
    );
  }

  String _generateQrData(double? enteredAmount, User currentUser) {
    return UpiPaymentHelper.buildQrData(
      upiId: currentUser.upiId,
      payeeName: currentUser.name,
      amount: enteredAmount,
    );
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

  pw.Widget _appIconBadge(pw.MemoryImage icon) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3.5),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.8),
      ),
      child: pw.Image(icon, width: 22, height: 22),
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
    pw.MemoryImage paytmIcon, {
    String? bhimLink,
    pw.MemoryImage? bhimIcon,
    String? upiUniversalLink,
  }) {
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
                    if (currentUser.address != null &&
                        currentUser.address!.trim().isNotEmpty)
                      pw.Text('Address: ${currentUser.address!.trim()}'),
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
              'Tax Invoice',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF1E40AF),
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
                    if (sale.customerAddress != null &&
                        sale.customerAddress!.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text('Address: ${sale.customerAddress!.trim()}'),
                    ],
                    pw.SizedBox(height: 12),
                    // Payment Section (Modern Integrated Card)
                    if (balanceAmount > 0) ...[
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFFF8FAFC),
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(
                            color: PdfColor.fromInt(0xFFCBD5E1),
                            width: 1,
                          ),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            // 1. Sleek Header Bar
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: const pw.BoxDecoration(
                                color: PdfColor.fromInt(0xFF0F172A),
                                borderRadius: pw.BorderRadius.only(
                                  topLeft: pw.Radius.circular(7),
                                  topRight: pw.Radius.circular(7),
                                ),
                              ),
                              child: pw.Row(
                                mainAxisAlignment:
                                    pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Row(
                                    mainAxisSize: pw.MainAxisSize.min,
                                    children: [
                                      pw.Container(
                                        width: 5,
                                        height: 5,
                                        decoration: const pw.BoxDecoration(
                                          color: PdfColor.fromInt(0xFF10B981),
                                          shape: pw.BoxShape.circle,
                                        ),
                                      ),
                                      pw.SizedBox(width: 5),
                                      pw.Text(
                                        "Pay with UPI",
                                        style: pw.TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: pw.FontWeight.bold,
                                          color: PdfColors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 4.5,
                                      vertical: 1.5,
                                    ),
                                    decoration: pw.BoxDecoration(
                                      color: PdfColor.fromInt(0xFF1E293B),
                                      borderRadius: pw.BorderRadius.circular(3),
                                      border: pw.Border.all(
                                        color: PdfColor.fromInt(0xFF334155),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: pw.Text(
                                      "FAST & SECURE",
                                      style: pw.TextStyle(
                                        fontSize: 5.5,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColor.fromInt(0xFF38BDF8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 2. Card Content
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(7),
                              child: pw.Column(
                                crossAxisAlignment:
                                    pw.CrossAxisAlignment.center,
                                children: [
                                  // Amount Row
                                  pw.Row(
                                    mainAxisAlignment:
                                        pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text(
                                        "Total Payable",
                                        style: const pw.TextStyle(
                                          fontSize: 7.5,
                                          color: PdfColor.fromInt(0xFF64748B),
                                        ),
                                      ),
                                      pw.Text(
                                        "INR ${balanceAmount.toStringAsFixed(2)}",
                                        style: pw.TextStyle(
                                          fontSize: 9,
                                          fontWeight: pw.FontWeight.bold,
                                          color: PdfColor.fromInt(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  pw.SizedBox(height: 5),

                                  // QR Code Container
                                  pw.Container(
                                    padding: const pw.EdgeInsets.all(5),
                                    decoration: pw.BoxDecoration(
                                      color: PdfColors.white,
                                      borderRadius: pw.BorderRadius.circular(6),
                                      border: pw.Border.all(
                                        color: PdfColor.fromInt(0xFFE2E8F0),
                                        width: 1,
                                      ),
                                    ),
                                    child: pw.BarcodeWidget(
                                      data: qrData,
                                      barcode: pw.Barcode.qrCode(),
                                      width: 130,
                                      height: 130,
                                    ),
                                  ),
                                  pw.SizedBox(height: 3.5),
                                  pw.Text(
                                    "Scan with any UPI QR App",
                                    style: const pw.TextStyle(
                                      fontSize: 7,
                                      color: PdfColor.fromInt(0xFF64748B),
                                    ),
                                  ),

                                  pw.SizedBox(height: 6),

                                  // Subtle Divider
                                  pw.Row(
                                    children: [
                                      pw.Expanded(
                                        child: pw.Container(
                                          height: 0.5,
                                          color: PdfColor.fromInt(0xFFE2E8F0),
                                        ),
                                      ),
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.symmetric(
                                          horizontal: 5,
                                        ),
                                        child: pw.Text(
                                          "ACCEPTED UPI APPS",
                                          style: pw.TextStyle(
                                            fontSize: 5.5,
                                            fontWeight: pw.FontWeight.bold,
                                            color: PdfColor.fromInt(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                      pw.Expanded(
                                        child: pw.Container(
                                          height: 0.5,
                                          color: PdfColor.fromInt(0xFFE2E8F0),
                                        ),
                                      ),
                                    ],
                                  ),

                                  pw.SizedBox(height: 5),

                                  // App Images Only
                                  pw.Row(
                                    mainAxisAlignment:
                                        pw.MainAxisAlignment.center,
                                    children: [
                                      _appIconBadge(gpayIcon),
                                      pw.SizedBox(width: 5),
                                      _appIconBadge(phonePeIcon),
                                      pw.SizedBox(width: 5),
                                      _appIconBadge(paytmIcon),
                                      if (bhimIcon != null) ...[
                                        pw.SizedBox(width: 5),
                                        _appIconBadge(bhimIcon),
                                      ],
                                    ],
                                  ),

                                  if (currentUser.upiId.isNotEmpty) ...[
                                    pw.SizedBox(height: 4),
                                    pw.Row(
                                      mainAxisAlignment:
                                          pw.MainAxisAlignment.center,
                                      children: [
                                        pw.Text(
                                          "UPI ID: ",
                                          style: const pw.TextStyle(
                                            fontSize: 6.5,
                                            color: PdfColor.fromInt(0xFF94A3B8),
                                          ),
                                        ),
                                        pw.Text(
                                          currentUser.upiId,
                                          style: pw.TextStyle(
                                            fontSize: 6.5,
                                            fontWeight: pw.FontWeight.bold,
                                            color: PdfColor.fromInt(0xFF475569),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
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
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                'Package Name',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                sale.productName.isNotEmpty
                                    ? sale.productName
                                    : 'N/A',
                              ),
                            ),
                          ],
                        ),

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
                              child: pw.Text(
                                'Tax',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                '₹ ${sale.safeTax.toStringAsFixed(2)}',
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
          ..._buildTermsAndConditions(currentUser.role),
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

  List<pw.Widget> _buildTermsAndConditions([String? role]) {
    final cleanRole = (role ?? '').trim().toLowerCase();

    // ── 1. 3D Printing Brand Terms ──────────────────────────────────────────
    if (cleanRole == '3d printing brand' || cleanRole.contains('3d print')) {
      final widgets = <pw.Widget>[
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Text(
            'The following terms apply to the manufacture and sale of 3D-printed products and related services. They supplement the full Terms and Conditions published by the seller.',
            style: pw.TextStyle(
              fontSize: 8,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey700,
            ),
          ),
        ),
      ];

      final terms = [
        '1. Product Characteristics: Additively manufactured products may exhibit variations in surface finish, texture, colour, dimensions, and appearance arising from the manufacturing process, materials, and finishing methods. Products will be assessed against their disclosed specifications and agreed tolerances.',
        '2. Material Limitations: Products may have specific limitations relating to strength, flexibility, heat resistance, chemical resistance, weather exposure, durability, and other performance characteristics. Customers should use products in accordance with their stated specifications and intended purpose.',
        '3. Custom Orders and Approvals: Customers are responsible for reviewing and approving applicable designs, dimensions, colours, text, materials, and other specifications before manufacture. Changes requested after approval may affect pricing, production schedules, and delivery timelines.',
        '4. Functional Applications: Unless expressly specified, tested, and appropriately certified where required, products must not be assumed suitable for safety-critical, medical, structural, load-bearing, or other regulated applications. Customers must verify suitability for their intended use where applicable.',
        '5. Inspection and Complaints: Customers should inspect delivered products and report damage, missing items, discrepancies, or suspected defects promptly, providing supporting information where reasonably requested. Any applicable statutory rights remain unaffected.',
        '6. Returns, Refunds, and Replacements: Requests concerning defective, damaged, incorrect, or non-conforming products will be handled in accordance with the seller\'s applicable policies and governing law. Customized or made-to-order products remain subject to any remedies required by applicable law.',
        '7. Production and Delivery: Production and delivery timelines are estimates unless expressly confirmed otherwise. Delays may arise from manufacturing requirements, material availability, design changes, or shipping conditions. Material delays and applicable remedies will be communicated as appropriate.',
        '8. Designs and Intellectual Property: Ownership, licensing, reproduction rights, and permitted use of digital design files, models, drawings, and other intellectual property are governed by the applicable agreement, quotation, or licence.',
        '9. Full Terms and Policies: The complete Terms and Conditions, applicable return policy, warranty information, and Privacy Policy are available upon request.',
        '10. Customer Rights: Nothing in these terms excludes, restricts, or waives any right, remedy, warranty, or protection that cannot legally be excluded or restricted under applicable law.',
      ];

      widgets.addAll(
        terms.map(
          (term) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(term, style: const pw.TextStyle(fontSize: 7.8)),
          ),
        ),
      );

      return widgets;
    }

    // ── 2. Photography Terms ────────────────────────────────────────────────
    if (cleanRole == 'photographer' || cleanRole.contains('photo')) {
      final businessName =
          currentUserName.isNotEmpty ? currentUserName : 'the photographer';
      final terms = [
        '1. All photographs remain the property of $businessName and are protected by copyright law.',
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
              padding: const pw.EdgeInsets.only(bottom: 2.5),
              child: pw.Text(term, style: const pw.TextStyle(fontSize: 8.5)),
            ),
          )
          .toList();
    }

    // ── 3. Marketing Specialist Terms ───────────────────────────────────────
    if (cleanRole.contains('marketing')) {
      final terms = [
        '1. Scope of Work: Services and deliverables are executed in accordance with agreed project briefs and proposals.',
        '2. Client Approvals: Client is responsible for timely review and sign-off on creative assets, ad copies, and campaigns before launch.',
        '3. Third-Party Expenses: Platform ad spends, media buys, tools, and third-party software fees are excluded from service charges and payable in advance.',
        '4. Intellectual Property: Final approved deliverables transfer to the client upon full settlement; preparatory drafts and internal strategies remain proprietary.',
        '5. Revisions: Included revisions are limited to the scope specified. Out-of-scope alterations will be invoiced additionally.',
        '6. Performance Disclaimers: Marketing reach and conversion metrics depend on market trends, algorithm shifts, and audience dynamics; specific ROI cannot be guaranteed.',
        '7. Confidentiality: Both parties agree to maintain strict confidentiality of proprietary data, strategies, and business intelligence.',
        '8. Payment Terms: Invoices are payable on presentation or per the milestone schedule. Overdue accounts may cause active campaigns to be paused.',
        '9. Cancellation & Termination: Early termination requires written notice as agreed; work completed up to the date of notice remains billable.',
        '10. Legal & Compliance: The client certifies that all provided promotional materials and claims comply with applicable advertising laws and regulatory guidelines.',
      ];

      return terms
          .map(
            (term) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(term, style: const pw.TextStyle(fontSize: 8)),
            ),
          )
          .toList();
    }

    // ── 4. General / Commercial Invoice Terms (All Other Roles) ─────────────
    final terms = [
      '1. Payment Terms: Payment must be cleared by the due date specified on this invoice. Outstanding balances must be settled as agreed.',
      '2. Inspection & Discrepancies: The customer must inspect all goods/services upon receipt and report any shortages, defects, or damages within 48 hours.',
      '3. Title & Risk: Risk of loss or damage passes to the customer upon delivery. Ownership and title to goods remain with the seller until full payment is received.',
      '4. Returns & Exchanges: Returns or exchanges must be accompanied by the original invoice and items in original, unused condition within the authorized return period.',
      '5. Custom & Special Orders: Customized, personalized, or specially ordered items/services cannot be cancelled or returned once production or fulfillment has commenced.',
      '6. Delivery & Lead Times: Delivery dates are estimated in good faith. The seller is not liable for transit delays caused by carriers or events beyond reasonable control.',
      '7. Pricing & Taxes: All prices, applicable taxes, and authorized discounts are reflected on this invoice. Disputes must be raised before final settlement.',
      '8. Warranty & Limitations: Standard manufacturer warranty applies where applicable. The seller is not liable for incidental or consequential damages arising from misuse.',
      '9. Governing Law & Jurisdiction: All sales transactions and agreements are governed by the local laws and jurisdiction of the seller\'s registered business location.',
      '10. Acceptance of Terms: Acceptance of this invoice or receipt of the billed items/services constitutes full acceptance of these terms and conditions.',
    ];

    return terms
        .map(
          (term) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(term, style: const pw.TextStyle(fontSize: 8)),
          ),
        )
        .toList();
  }
}
