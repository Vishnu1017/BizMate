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
  }) async {
    try {
      final cleanedPhone = phone.replaceAll(RegExp(r'\D'), '');

      if (cleanedPhone.length < 10 ||
          !RegExp(r'^[0-9]+$').hasMatch(cleanedPhone)) {
        AppSnackBar.showWarning(
          context,
          message: "Please enter a valid 10-digit phone number",
          duration: Duration(seconds: 2),
        );

        return;
      }

      final customerName = name.isNotEmpty ? name : "there";

      String message =
          "Hi $customerName! This is Shutter Life Photography. How can we help you today?";

      if (purpose != null) {
        switch (purpose) {
          case 'payment_due':
            if (dueDate != null && amount != null && invoiceNumber != null) {
              message =
                  "Dear $customerName,\n\nFriendly reminder from Shutter Life Photography:\n\n"
                  "📅 Payment Due: ${DateFormat('dd MMM yyyy').format(dueDate)}\n"
                  "💰 Amount: ₹${amount.toStringAsFixed(2)}\n"
                  "📋 Invoice #: $invoiceNumber\n\n"
                  "Payment Methods:\n"
                  "• UPI: shutterlifephotography10@okaxis\n"
                  "• Bank Transfer (Details attached)\n"
                  "• Cash (At our studio)\n\n"
                  "Please confirm once payment is made. Thank you for your prompt attention!\n\n"
                  "Warm regards,\nAccounts Team\nShutter Life Photography";
            } else {
              message =
                  "Dear $customerName,\n\nThis is a friendly reminder regarding your payment. "
                  "Please contact us for invoice details.\n\n"
                  "Warm regards,\nAccounts Team\nShutter Life Photography";
            }
            break;

          default:
            message =
                "Hi $customerName! This is Shutter Life Photography. How can we help you today?";
        }
      }

      final encodedMessage = Uri.encodeComponent(message);
      final url1 = "https://wa.me/$cleanedPhone?text=$encodedMessage";
      final url2 = "https://wa.me/91$cleanedPhone?text=$encodedMessage";

      if (await canLaunchUrl(Uri.parse(url1))) {
        await launchUrl(Uri.parse(url1), mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(Uri.parse(url2))) {
        await launchUrl(Uri.parse(url2), mode: LaunchMode.externalApplication);
      } else {
        throw Exception("WhatsApp is not installed or URL can't be launched");
      }
    } catch (e) {
      AppSnackBar.showError(
        context,
        message: "Couldn't open WhatsApp",
        duration: Duration(seconds: 2),
      );
    }
  }
}
