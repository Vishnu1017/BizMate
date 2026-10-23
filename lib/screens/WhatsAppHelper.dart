import 'package:url_launcher/url_launcher.dart';

class WhatsAppHelper {
  /// Cleans and formats phone number for WhatsApp with international country code (defaulting to +91 if 10 digits).
  static String formatPhone(String rawPhone) {
    String digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }
    if (digits.length == 10) {
      digits = '91$digits';
    }
    return digits;
  }

  static Future<bool> sendWhatsAppMessage({
    required String phone,
    required String message,
  }) async {
    final cleanedPhone = formatPhone(phone);
    if (cleanedPhone.length < 10) {
      throw Exception("Invalid phone number");
    }

    final encodedMessage = Uri.encodeComponent(message);

    // 1. Try native WhatsApp scheme directly (fastest, opens WhatsApp app directly)
    final nativeUri =
        Uri.parse("whatsapp://send?phone=$cleanedPhone&text=$encodedMessage");
    try {
      if (await canLaunchUrl(nativeUri)) {
        final launched =
            await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
        if (launched) return true;
      }
    } catch (_) {}

    // 2. Try universal wa.me link
    final waMeUri =
        Uri.parse("https://wa.me/$cleanedPhone?text=$encodedMessage");
    try {
      final launched =
          await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
      if (launched) return true;
    } catch (_) {}

    // 3. Try api.whatsapp.com link
    final apiUri = Uri.parse(
        "https://api.whatsapp.com/send?phone=$cleanedPhone&text=$encodedMessage");
    try {
      final launched =
          await launchUrl(apiUri, mode: LaunchMode.externalApplication);
      if (launched) return true;
    } catch (_) {}

    return false;
  }
}
