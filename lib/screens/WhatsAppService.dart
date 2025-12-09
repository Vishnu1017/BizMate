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

    // ✅ NEW (dynamic – SAME as SaleOptionsMenu)
    required String upiId,
    required String businessName,
  }) async {
    try {
      final cleanedPhone = phone.replaceAll(RegExp(r'\D'), '');

      if (cleanedPhone.length < 10) {
        AppSnackBar.showWarning(
          context,
          message: "Please enter a valid phone number",
          duration: const Duration(seconds: 2),
        );
        return;
      }

      final customerName = name.isNotEmpty ? name : "there";

      /// ✅ Amount handling
      final amountText =
          amount != null && amount > 0 ? amount.toStringAsFixed(2) : null;

      /// ✅ UPI DEEP LINKS (same logic as PDF)
      final gpay =
          amountText != null
              ? "gpay://upi/pay?pa=$upiId&pn=${Uri.encodeComponent(businessName)}&am=$amountText&cu=INR"
              : "gpay://upi/pay?pa=$upiId&pn=${Uri.encodeComponent(businessName)}&cu=INR";

      final phonePe =
          amountText != null
              ? "phonepe://pay?pa=$upiId&pn=${Uri.encodeComponent(businessName)}&am=$amountText&cu=INR"
              : "phonepe://pay?pa=$upiId&pn=${Uri.encodeComponent(businessName)}&cu=INR";

      final paytm =
          amountText != null
              ? "paytm://upi/pay?pa=$upiId&pn=${Uri.encodeComponent(businessName)}&am=$amountText&cu=INR"
              : "paytm://upi/pay?pa=$upiId&pn=${Uri.encodeComponent(businessName)}&cu=INR";

      /// ✅ DEFAULT MESSAGE
      String message =
          "Hi $customerName!\n\nThis is $businessName. How can we help you today?";

      /// ✅ PAYMENT DUE MESSAGE
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
            "Please confirm once payment is done.\n\n"
            "Regards,\n$businessName";
      }

      final encodedMessage = Uri.encodeComponent(message);

      /// ✅ WhatsApp launch (India-safe)
      final url = Uri.parse(
        "https://wa.me/91$cleanedPhone?text=$encodedMessage",
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
