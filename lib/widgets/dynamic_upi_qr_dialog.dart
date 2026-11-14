import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/user_model.dart';
import '../utils/app_theme.dart';
import '../utils/payment_icons.dart';
import '../utils/upi_payment_helper.dart';
import 'app_snackbar.dart';

/// Interactive modal sheet/dialog for displaying dynamic, pre-filled UPI QR codes
/// for instant counter checkout, rental collections, and remote payments.
class DynamicUpiQrDialog extends StatefulWidget {
  final String payeeName;
  final String upiId;
  final double amount;
  final String? orderId;
  final String? customerName;
  final String? transactionNote;
  final ValueChanged<double>? onPaymentConfirmed;

  const DynamicUpiQrDialog({
    super.key,
    required this.payeeName,
    required this.upiId,
    required this.amount,
    this.orderId,
    this.customerName,
    this.transactionNote,
    this.onPaymentConfirmed,
  });

  /// Static helper to display the dynamic UPI QR dialog as a responsive bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String payeeName,
    required String upiId,
    required double amount,
    String? orderId,
    String? customerName,
    String? transactionNote,
    ValueChanged<double>? onPaymentConfirmed,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DynamicUpiQrDialog(
        payeeName: payeeName,
        upiId: upiId,
        amount: amount,
        orderId: orderId,
        customerName: customerName,
        transactionNote: transactionNote,
        onPaymentConfirmed: onPaymentConfirmed,
      ),
    );
  }

  @override
  State<DynamicUpiQrDialog> createState() => _DynamicUpiQrDialogState();
}

class _DynamicUpiQrDialogState extends State<DynamicUpiQrDialog> {
  late double _amount;
  late String _upiId;
  late String _payeeName;
  bool _isEditingAmount = false;
  late TextEditingController _amountController;
  late TextEditingController _upiIdController;
  Uint8List? _bhimIconBytes;

  @override
  void initState() {
    super.initState();
    _amount = widget.amount;
    _upiId = widget.upiId.trim();
    _payeeName = widget.payeeName.trim().isNotEmpty
        ? widget.payeeName.trim()
        : 'BizMate Merchant';
    _amountController = TextEditingController(
      text: _amount > 0 ? _amount.toStringAsFixed(0) : '',
    );
    _upiIdController = TextEditingController(text: _upiId);
    _loadBhimIcon();
  }

  Future<void> _loadBhimIcon() async {
    try {
      final bytes = await PaymentIcons.loadBhimIcon();
      if (mounted) {
        setState(() {
          _bhimIconBytes = bytes;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _amountController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  String _buildDynamicNote() {
    if (widget.transactionNote != null &&
        widget.transactionNote!.trim().isNotEmpty) {
      return widget.transactionNote!.trim();
    }
    final parts = <String>[];
    if (widget.orderId != null && widget.orderId!.trim().isNotEmpty) {
      parts.add('Order #${widget.orderId!.trim()}');
    }
    if (widget.customerName != null && widget.customerName!.trim().isNotEmpty) {
      parts.add(widget.customerName!.trim());
    }
    if (parts.isEmpty) {
      return 'Payment to $_payeeName';
    }
    return parts.join(' - ');
  }

  String get _qrData {
    return UpiPaymentHelper.buildQrData(
      upiId: _upiId,
      payeeName: _payeeName,
      amount: _amount,
      transactionNote: _buildDynamicNote(),
      transactionRef: widget.orderId,
    );
  }

  Future<void> _saveUpiIdToProfile(String newUpi) async {
    final trimmed = newUpi.trim();
    if (!UpiPaymentHelper.isValidUpiId(trimmed)) {
      AppSnackBar.showError(
        context,
        message: 'Please enter a valid UPI ID (e.g. yourname@okaxis)',
      );
      return;
    }

    try {
      final sessionBox = Hive.box('session');
      final email = sessionBox.get('currentUserEmail')?.toString();
      if (email != null) {
        final usersBox = Hive.box<User>('users');
        for (final user in usersBox.values) {
          if (user.email.trim().toLowerCase() == email.trim().toLowerCase()) {
            user.upiId = trimmed;
            await user.save();
            break;
          }
        }
      }
      setState(() {
        _upiId = trimmed;
      });
      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          message: 'UPI ID updated and saved to your profile!',
        );
      }
    } catch (e) {
      setState(() {
        _upiId = trimmed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final width = MediaQuery.sizeOf(context).width;
    final isSmall = width < 400;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Handle bar
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E40AF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: Color(0xFF1E40AF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dynamic UPI Payment',
                        style: TextStyle(
                          fontSize: isSmall ? 16 : 18,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        'Scan with any UPI app to pay',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: context.textSecondary,
                  ),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // If UPI ID is missing, provide quick setup
            if (_upiId.isEmpty) ...[
              _buildMissingUpiCard(isDark),
              const SizedBox(height: 16),
            ] else ...[
              // Amount Display Card
              _buildAmountCard(isDark, isSmall),
              const SizedBox(height: 16),

              // The QR Code Box
              _buildQrCard(isDark, isSmall),
              const SizedBox(height: 14),

              // Payee & Note Info
              _buildPayeeInfo(context, isDark),
              const SizedBox(height: 14),

              // Accepted Apps Row
              _buildAcceptedAppsRow(isDark),
              const SizedBox(height: 18),

              // Action Buttons Row
              _buildActionButtons(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMissingUpiCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade600, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              Text(
                'UPI ID Not Configured',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your UPI ID (VPA) below to generate instant dynamic QR codes and save it to your profile.',
            style: TextStyle(fontSize: 13, color: context.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _upiIdController,
            decoration: InputDecoration(
              hintText: 'e.g. business@okaxis or 9876543210@paytm',
              prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E40AF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _saveUpiIdToProfile(_upiIdController.text),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text(
                'Save & Generate QR',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard(bool isDark, bool isSmall) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E40AF).withValues(alpha: isDark ? 0.15 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1E40AF).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Amount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: context.textSecondary,
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _isEditingAmount = !_isEditingAmount;
                    if (!_isEditingAmount) {
                      final val = double.tryParse(_amountController.text) ?? 0.0;
                      if (val > 0) _amount = val;
                    }
                  });
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _isEditingAmount
                            ? Icons.check_circle_outline_rounded
                            : Icons.edit_rounded,
                        size: 14,
                        color: const Color(0xFF1E40AF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isEditingAmount ? 'Done' : 'Custom Amount',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_isEditingAmount)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onSubmitted: (val) {
                      final parsed = double.tryParse(val) ?? 0.0;
                      if (parsed > 0) {
                        setState(() {
                          _amount = parsed;
                          _isEditingAmount = false;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                  ),
                  icon: const Icon(Icons.check, color: Colors.white, size: 18),
                  onPressed: () {
                    final parsed =
                        double.tryParse(_amountController.text) ?? 0.0;
                    if (parsed > 0) {
                      setState(() {
                        _amount = parsed;
                        _isEditingAmount = false;
                      });
                    }
                  },
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  '₹',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E40AF),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _amount.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildQrCard(bool isDark, bool isSmall) {
    final qrSize = isSmall ? 180.0 : 210.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF1E40AF).withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E40AF).withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: QrImageView(
              data: _qrData,
              version: QrVersions.auto,
              size: qrSize,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(8),
              embeddedImage: const AssetImage(
                'assets/images/bizmate_emblem.png',
              ),
              embeddedImageStyle: const QrEmbeddedImageStyle(
                size: Size(34, 34),
              ),
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF0F172A),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'NPCI Dynamic UPI QR Code',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayeeInfo(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor, width: 0.8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'UPI ID:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        _upiId,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _upiId));
                        AppSnackBar.showSuccess(
                          context,
                          message: 'UPI ID copied to clipboard!',
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payee Name:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _payeeName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (widget.orderId != null && widget.orderId!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reference:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary,
                  ),
                ),
                Text(
                  '#${widget.orderId}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E40AF),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAcceptedAppsRow(bool isDark) {
    return Column(
      children: [
        Text(
          'ACCEPTED UPI APPS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: context.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAppIcon('assets/icons/Gpay.png', 'Google Pay'),
            const SizedBox(width: 14),
            _buildAppIcon('assets/icons/Phonepe.png', 'PhonePe'),
            const SizedBox(width: 14),
            _buildAppIcon('assets/icons/Paytm.png', 'Paytm'),
            const SizedBox(width: 14),
            _buildBhimIcon(),
          ],
        ),
      ],
    );
  }

  Widget _buildAppIcon(String assetPath, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 34,
        height: 34,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Image.asset(assetPath, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildBhimIcon() {
    return Tooltip(
      message: 'BHIM UPI',
      child: Container(
        width: 34,
        height: 34,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _bhimIconBytes != null
            ? Image.memory(_bhimIconBytes!, fit: BoxFit.contain)
            : const Icon(Icons.account_balance_wallet, size: 16),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            // Open in UPI app button
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E40AF),
                  side: const BorderSide(color: Color(0xFF1E40AF), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  final success = await UpiPaymentHelper.launchUpiPayment(
                    upiUri: _qrData,
                  );
                  if (!success && context.mounted) {
                    AppSnackBar.showWarning(
                      context,
                      message:
                          'Could not open UPI app directly. Please scan the QR code.',
                    );
                  }
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Open UPI App',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Share Payment Link button
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal.shade700,
                  side: BorderSide(color: Colors.teal.shade700, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  final text =
                      '💳 UPI Payment Request from $_payeeName\n'
                      'Amount: ₹${_amount.toStringAsFixed(2)}\n'
                      '${_buildDynamicNote()}\n\n'
                      'Pay via UPI: $_qrData';
                  try {
                    await SharePlus.instance.share(
                      ShareParams(
                        text: text,
                        subject: 'UPI Payment to $_payeeName',
                      ),
                    );
                  } catch (_) {}
                },
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Share Link',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Confirm / Mark as Received button
        if (widget.onPaymentConfirmed != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 2,
              ),
              onPressed: () {
                widget.onPaymentConfirmed!(_amount);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              label: Text(
                'Mark as Paid (₹${_amount.toStringAsFixed(2)})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

