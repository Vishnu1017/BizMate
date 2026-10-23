import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class WhatsAppService {
  final BuildContext context;

  WhatsAppService(this.context);

  void openWhatsApp(
    String phone,
    String name, {
    String? purpose,
    DateTime? dueDate,
    double? amount,
    String? invoiceNumber,
    required String upiId,
    required String businessName,
  }) async {
    try {
      // ✅ NORMALIZE PHONE NUMBER (SAFE)
      String rawPhone = phone.trim();

      // Keep digits and +
      rawPhone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');

      late String whatsappPhone;

      if (rawPhone.startsWith('+')) {
        // +91xxxxxxx → 91xxxxxxxxxx
        whatsappPhone = rawPhone.substring(1);
      } else if (rawPhone.length == 10) {
        // Local Indian number
        whatsappPhone = '91$rawPhone';
      } else {
        // Already contains country code
        whatsappPhone = rawPhone;
      }

      if (whatsappPhone.length < 10) {
        AppSnackBar.showWarning(
          context,
          message: "Please enter a valid phone number",
          duration: const Duration(seconds: 2),
        );
        return;
      }

      final customerName = name.isNotEmpty ? name : "there";

      final amountText =
          amount != null && amount > 0 ? amount.toStringAsFixed(2) : null;

      /// ✅ UPI LINKS
      final gpay =
          amountText != null
              ? "gpay://upi/pay?pa=$upiId&pn=${Uri.encodeComponent(businessName)}&am=$amountText&cu=INR"
              : "gpay://upi/pay?pa=$upiId&pn=${Uri.encodeComponent(businessName)}&cu=INR";

      final phonePe =
          amountText != null
              ? "phonepe://pay?pa=$upiId&pn=${Uri.encodeComponent(businessName)}&am=$amountText&cu=INR"
              : "phonepe://pay?pa=$upiId&pn=${Uri.encodeComponent(businessName)}&cu=INR";

      // paytmmp://pay works on both iOS and Android
      final paytm =
          amountText != null
              ? "paytmmp://pay?pa=$upiId&pn=${Uri.encodeComponent(businessName)}&am=$amountText&cu=INR"
              : "paytmmp://pay?pa=$upiId&pn=${Uri.encodeComponent(businessName)}&cu=INR";

      final upiUniversal =
          amountText != null
              ? "upi://pay?pa=$upiId&pn=${Uri.encodeComponent(businessName)}&am=$amountText&cu=INR"
              : "upi://pay?pa=$upiId&pn=${Uri.encodeComponent(businessName)}&cu=INR";

      /// ✅ MESSAGE
      String message =
          "Hi $customerName!\n\nThis is $businessName. How can we help you today?";

      if (purpose == 'payment_due' && amountText != null) {
        message =
            "Dear $customerName,\n\n"
            "Friendly reminder from $businessName:\n\n"
            "📅 Due Date: ${dueDate != null ? DateFormat('dd MMM yyyy').format(dueDate) : '-'}\n"
            "💰 Amount: ₹$amountText\n"
            "${invoiceNumber != null ? "📋 Invoice #: $invoiceNumber\n" : ""}\n"
            "Tap to Pay securely:\n\n"
            "👉 Google Pay:\n$gpay\n\n"
            "👉 PhonePe:\n$phonePe\n\n"
            "👉 Paytm:\n$paytm\n\n"
            "👉 Any UPI App:\n$upiUniversal\n\n"
            "UPI ID: $upiId\n\n"
            "Please confirm once payment is done.\n\n"
            "Regards,\n$businessName";
      }

      final encodedMessage = Uri.encodeComponent(message);

      final url = Uri.parse(
        "https://wa.me/$whatsappPhone?text=$encodedMessage",
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw Exception("WhatsApp not available");
      }
    } catch (e) {
      AppSnackBar.showError(
        context,
        message: "Couldn't open WhatsApp",
        duration: const Duration(seconds: 2),
      );
    }
  }
}
