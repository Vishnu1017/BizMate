import 'dart:io' show Platform;
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';

/// Helper class for generating cross-platform UPI payment links, QR code data,
/// and deep links for PDF invoices and mobile interactions.
///
/// Accounts for platform-specific URL scheme registrations (Android vs iOS),
/// NPCI UPI specifications, and mobile PDF viewer sandboxing restrictions.
class UpiPaymentHelper {
  /// Validates standard Indian UPI ID (VPA) format.
  /// E.g. merchant@upi, user.name@oksbi, 9876543210@paytm
  static bool isValidUpiId(String? upiId) {
    if (upiId == null) return false;
    final trimmed = upiId.trim();
    if (trimmed.isEmpty) return false;
    final regex = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$');
    return regex.hasMatch(trimmed);
  }

  /// Fetches the currently authenticated User from Hive session.
  static Future<User?> getCurrentUser() async {
    try {
      final sessionBox = Hive.box('session');
      final currentUserEmail = sessionBox.get('currentUserEmail')?.toString();
      if (currentUserEmail != null && currentUserEmail.trim().isNotEmpty) {
        final usersBox = Hive.box<User>('users');
        for (final user in usersBox.values) {
          if (user.email.trim().toLowerCase() ==
              currentUserEmail.trim().toLowerCase()) {
            return user;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Builds the Google Pay deep link.
  ///
  /// - On iOS: Uses `gpay://upi/pay` registered by Google Pay iOS.
  /// - On Android: Uses `tez://upi/pay` registered by Google Pay Android.
  static String buildGooglePayLink({
    required String upiId,
    required String payeeName,
    double? amount,
    String? transactionNote,
    String? transactionRef,
  }) {
    final query = _buildQueryString(
      upiId: upiId,
      payeeName: payeeName,
      amount: amount,
      transactionNote: transactionNote,
      transactionRef: transactionRef,
    );

    if (Platform.isIOS) {
      return 'gpay://upi/pay?$query';
    } else {
      return 'tez://upi/pay?$query';
    }
  }

  /// Builds the PhonePe deep link.
  ///
  /// Uses `phonepe://pay`, which is supported on both Android and iOS.
  static String buildPhonePeLink({
    required String upiId,
    required String payeeName,
    double? amount,
    String? transactionNote,
    String? transactionRef,
  }) {
    final query = _buildQueryString(
      upiId: upiId,
      payeeName: payeeName,
      amount: amount,
      transactionNote: transactionNote,
      transactionRef: transactionRef,
    );
    return 'phonepe://pay?$query';
  }

  /// Builds the Paytm deep link.
  ///
  /// - On iOS: Uses `paytm://upi/pay`.
  /// - On Android: Uses `paytmmp://pay` registered by Paytm Android.
  static String buildPaytmLink({
    required String upiId,
    required String payeeName,
    double? amount,
    String? transactionNote,
    String? transactionRef,
  }) {
    final query = _buildQueryString(
      upiId: upiId,
      payeeName: payeeName,
      amount: amount,
      transactionNote: transactionNote,
      transactionRef: transactionRef,
    );

    if (Platform.isIOS) {
      return 'paytm://upi/pay?$query';
    } else {
      return 'paytmmp://pay?$query';
    }
  }

  /// Builds the BHIM deep link.
  ///
  /// Uses `bhim://upi/pay`, which is registered on both iOS and Android.
  static String buildBhimLink({
    required String upiId,
    required String payeeName,
    double? amount,
    String? transactionNote,
    String? transactionRef,
  }) {
    final query = _buildQueryString(
      upiId: upiId,
      payeeName: payeeName,
      amount: amount,
      transactionNote: transactionNote,
      transactionRef: transactionRef,
    );
    return 'bhim://upi/pay?$query';
  }

  /// Builds the standard direct NPCI UPI URI (`upi://pay`).
  ///
  /// Encodes dynamic parameters:
  /// - `pa`: Payee VPA / UPI ID
  /// - `pn`: Payee Name
  /// - `am`: Exact amount formatted to 2 decimals
  /// - `cu`: Currency (INR)
  /// - `tn`: Transaction note
  /// - `tr`: Transaction reference / Order ID
  static String buildDirectUpiUri({
    required String upiId,
    required String payeeName,
    double? amount,
    String? transactionNote,
    String? transactionRef,
  }) {
    final query = _buildQueryString(
      upiId: upiId,
      payeeName: payeeName,
      amount: amount,
      transactionNote: transactionNote,
      transactionRef: transactionRef,
    );
    return 'upi://pay?$query';
  }

  /// Builds the universal cross-platform payment link for the primary PDF action.
  ///
  /// - On iOS: Apple's PDFKit/QuickLook directly opens custom schemes, so it
  ///   uses standard `upi://pay` to launch the native UPI app chooser.
  /// - On Android: Most 3rd-party PDF viewers (Google Drive, Adobe Acrobat, Files)
  ///   strictly filter out custom URI schemes like `upi://` or `tez://`.
  ///   Using a reliable HTTPS gateway (`https://upi.pe/...`) ensures that
  ///   clicking the link opens the browser, which immediately triggers the
  ///   Android UPI intent to open the user's installed payment apps.
  static String buildUniversalPaymentLink({
    required String upiId,
    required String payeeName,
    double? amount,
    String? transactionNote,
    String? transactionRef,
  }) {
    if (Platform.isIOS) {
      return buildDirectUpiUri(
        upiId: upiId,
        payeeName: payeeName,
        amount: amount,
        transactionNote: transactionNote,
        transactionRef: transactionRef,
      );
    } else {
      return buildHttpsGatewayLink(
        upiId: upiId,
        payeeName: payeeName,
        amount: amount,
        transactionNote: transactionNote,
        transactionRef: transactionRef,
      );
    }
  }

  /// Builds an HTTPS gateway link that works in any web or PDF viewer environment.
  static String buildHttpsGatewayLink({
    required String upiId,
    required String payeeName,
    double? amount,
    String? transactionNote,
    String? transactionRef,
  }) {
    final encodedPn = Uri.encodeComponent(payeeName.trim());
    final hasAmount = amount != null && amount > 0;
    final amountFormatted = hasAmount ? amount.toStringAsFixed(2) : null;

    final queryParams = <String, String>{
      'pn': encodedPn,
      'cu': 'INR',
    };
    if (transactionNote != null && transactionNote.trim().isNotEmpty) {
      queryParams['tn'] = Uri.encodeComponent(transactionNote.trim());
    }
    if (transactionRef != null && transactionRef.trim().isNotEmpty) {
      queryParams['tr'] = Uri.encodeComponent(transactionRef.trim());
    }

    final queryString = queryParams.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');

    if (hasAmount && amountFormatted != null) {
      return 'https://upi.pe/$upiId/$amountFormatted?$queryString';
    } else {
      return 'https://upi.pe/?pa=$upiId&$queryString';
    }
  }

  /// Builds standard NPCI-compliant dynamic QR code data.
  static String buildQrData({
    required String upiId,
    required String payeeName,
    double? amount,
    String? transactionNote,
    String? transactionRef,
  }) {
    return buildDirectUpiUri(
      upiId: upiId,
      payeeName: payeeName,
      amount: amount,
      transactionNote: transactionNote,
      transactionRef: transactionRef,
    );
  }

  /// Helper to launch a UPI payment URI using the system application chooser.
  static Future<bool> launchUpiPayment({required String upiUri}) async {
    final parsed = Uri.tryParse(upiUri);
    if (parsed == null) return false;
    try {
      return await launchUrl(parsed, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Helper to URL-encode parameters and assemble query string.
  static String _buildQueryString({
    required String upiId,
    required String payeeName,
    double? amount,
    String? transactionNote,
    String? transactionRef,
  }) {
    final params = <String>[
      'pa=$upiId',
      'pn=${Uri.encodeComponent(payeeName.trim())}',
    ];

    if (amount != null && amount > 0) {
      params.add('am=${amount.toStringAsFixed(2)}');
    }

    params.add('cu=INR');

    if (transactionNote != null && transactionNote.trim().isNotEmpty) {
      params.add('tn=${Uri.encodeComponent(transactionNote.trim())}');
    }

    if (transactionRef != null && transactionRef.trim().isNotEmpty) {
      params.add('tr=${Uri.encodeComponent(transactionRef.trim())}');
    }

    return params.join('&');
  }
}
