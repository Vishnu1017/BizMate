// lib/screens/sale_detail_screen.dart
import 'package:bizmate/models/payment.dart';
import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';

class SaleDetailScreen extends StatefulWidget {
  final Sale sale;
  final int index;

  const SaleDetailScreen({super.key, required this.sale, required this.index});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  late TextEditingController customerController;
  late TextEditingController phoneController;
  late TextEditingController productController;
  late TextEditingController amountController;
  late TextEditingController totalAmountController;
  bool isFullyPaid = false;
  String _selectedMode = 'Cash';
  double scale = 1.0;

  final List<String> _paymentModes = [
    'Cash',
    'UPI',
    'Card',
    'Bank Transfer',
    'Cheque',
    'Wallet',
  ];

  final _formKey = GlobalKey<FormState>();

  IconData _getIconForMode(String mode) {
    switch (mode) {
      case 'Cash':
        return Icons.money;
      case 'UPI':
        return Icons.qr_code_scanner;
      case 'Card':
        return Icons.credit_card;
      case 'Bank Transfer':
        return Icons.account_balance;
      case 'Cheque':
        return Icons.receipt_long;
      case 'Wallet':
        return Icons.account_balance_wallet;
      default:
        return Icons.payments;
    }
  }

  @override
  void initState() {
    super.initState();
    customerController = TextEditingController(text: widget.sale.customerName);
    phoneController = TextEditingController(text: widget.sale.phoneNumber);
    productController = TextEditingController(text: widget.sale.productName);
    amountController = TextEditingController(
      text: widget.sale.amount.toString(),
    );
    totalAmountController = TextEditingController(
      text: widget.sale.totalAmount.toString(),
    );
    _selectedMode =
        (widget.sale.paymentMode.isNotEmpty) ? widget.sale.paymentMode : 'Cash';
    isFullyPaid = (widget.sale.amount >= widget.sale.totalAmount);
  }

  @override
  void dispose() {
    customerController.dispose();
    phoneController.dispose();
    productController.dispose();
    amountController.dispose();
    totalAmountController.dispose();
    super.dispose();
  }

  void saveChanges() async {
    // VALIDATION
    if (customerController.text.trim().isEmpty) {
      AppSnackBar.showError(context, message: "Customer name cannot be empty!");
      return;
    }

    if (phoneController.text.trim().isEmpty ||
        phoneController.text.trim().length != 10 ||
        !RegExp(r'^[0-9]+$').hasMatch(phoneController.text.trim())) {
      AppSnackBar.showError(
        context,
        message: "Enter a valid 10-digit phone number!",
      );
      return;
    }

    double total = double.tryParse(totalAmountController.text) ?? 0;
    double paid =
        double.tryParse(
          amountController.text.isEmpty ? "0" : amountController.text,
        ) ??
        0;

    if (total <= 0) {
      AppSnackBar.showError(
        context,
        message: "Total amount must be greater than 0!",
      );
      return;
    }

    if (!isFullyPaid && paid < 0) {
      AppSnackBar.showError(
        context,
        message: "Paid amount cannot be negative!",
      );
      return;
    }

    // Session load
    if (!Hive.isBoxOpen('session')) await Hive.openBox('session');
    final sessionBox = Hive.box('session');
    final email = sessionBox.get("currentUserEmail");

    if (email == null) {
      AppSnackBar.showError(
        context,
        message: "Session expired. Please login again.",
      );
      return;
    }

    final safeEmail = email
        .toString()
        .replaceAll('.', '_')
        .replaceAll('@', '_');
    final userBox = await Hive.openBox("userdata_$safeEmail");

    // Read existing sales
    List<Sale> sales = [];
    try {
      sales = List<Sale>.from(userBox.get("sales", defaultValue: []));
    } catch (_) {
      sales = [];
    }

    // === UNIQUE IDENTIFIER ===
    // DO NOT UPDATE BY INDEX.
    // Instead update sale with exact matching timestamp.
    final targetDate = widget.sale.dateTime;

    // Generate new payment record
    final newPayment = Payment(
      amount: isFullyPaid ? total : paid,
      date: DateTime.now(),
      mode: _selectedMode,
    );

    // Create updated sale object
    final updatedSale = Sale(
      customerName: customerController.text,
      phoneNumber: phoneController.text,
      productName: productController.text,
      amount: newPayment.amount,
      totalAmount: total,
      dateTime: widget.sale.dateTime,
      paymentMode: _selectedMode,
      deliveryStatus: widget.sale.deliveryStatus,
      deliveryLink: widget.sale.deliveryLink,
      paymentHistory: [newPayment, ...widget.sale.paymentHistory],
      discount: widget.sale.discount,
      item: widget.sale.item,
    );

    // === FIXED: Update ONLY the sale with matching dateTime ===
    for (int i = 0; i < sales.length; i++) {
      if (sales[i].dateTime == targetDate) {
        sales[i] = updatedSale;
        break;
      }
    }

    // Save list back
    await userBox.put("sales", sales);

    AppSnackBar.showSuccess(
      context,
      message: 'Sale updated successfully!',
      duration: Duration(seconds: 2),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(widget.sale.dateTime);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;
        final horizontalPadding = isWide ? constraints.maxWidth * 0.12 : 16.0;
        final cardPadding = isWide ? 24.0 : 16.0;
        final bodyWidth =
            isWide ? constraints.maxWidth * 0.76 : constraints.maxWidth;

        // derive values from controllers (safe)
        double total =
            double.tryParse(totalAmountController.text) ??
            widget.sale.totalAmount;
        double paid =
            double.tryParse(
              amountController.text.isEmpty ? "0" : amountController.text,
            ) ??
            widget.sale.amount;
        double balance = total - paid;

        String statusText;
        Color statusColor;
        IconData statusIcon;

        if (paid == total) {
          statusText = "Fully Paid";
          statusColor = const Color(0xFF10B981);
          statusIcon = Icons.check_circle;
        } else if (paid > total) {
          statusText = "Overpaid";
          statusColor = const Color(0xFF059669);
          statusIcon = Icons.arrow_upward;
        } else if (paid > 0) {
          statusText = "Partially Paid";
          statusColor = const Color(0xFFF59E0B);
          statusIcon = Icons.pending;
        } else {
          statusText = "Unpaid";
          statusColor = const Color(0xFFEF4444);
          statusIcon = Icons.schedule;
        }

        // adaptive text sizes
        final titleSize = 13.0 * scale;
        final subtitleSize = 9.0 * scale;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1E40AF),
            title: Text(
              "Edit Sale Details",
              style: TextStyle(
                color: const Color(0xFF1E40AF),
                fontWeight: FontWeight.w600,
                fontSize: 18 * scale,
              ),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, size: 20 * scale),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.save_rounded),
                onPressed: saveChanges,
                tooltip: 'Save Changes',
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 18,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: bodyWidth),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Card
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(cardPadding),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(6 * scale),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.receipt_long_rounded,
                                      color: Color(0xFF1E40AF),
                                      size: 20 * scale,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.sale.productName,
                                          style: TextStyle(
                                            fontSize: titleSize,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1E40AF),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          formatted,
                                          style: TextStyle(
                                            fontSize: subtitleSize,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          statusIcon,
                                          size: 10 * scale,
                                          color: statusColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          statusText,
                                          style: TextStyle(
                                            fontSize: 10 * scale,
                                            fontWeight: FontWeight.w600,
                                            color: statusColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12 * scale),
                              const Divider(height: 1),
                              SizedBox(height: 12 * scale),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildAmountItem(
                                    "Total Amount",
                                    "₹${total.toStringAsFixed(2)}",
                                    Icons.currency_rupee_rounded,
                                    const Color(0xFF1E40AF),
                                  ),
                                  _buildAmountItem(
                                    "Balance",
                                    "₹${balance.abs().toStringAsFixed(2)}",
                                    balance >= 0
                                        ? Icons.arrow_outward_rounded
                                        : Icons.arrow_downward_rounded,
                                    balance >= 0
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF10B981),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 10 * scale),

                        // Customer Information Card
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(cardPadding),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Customer Information",
                                style: TextStyle(
                                  fontSize: 14 * scale,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E40AF),
                                ),
                              ),
                              SizedBox(height: 12 * scale),
                              _buildModernTextField(
                                controller: customerController,
                                label: "Customer Name",
                                icon: Icons.person_outline_rounded,
                                isRequired: true,
                                keyboardType: TextInputType.name,
                              ),
                              const SizedBox(height: 12),
                              _buildModernTextField(
                                controller: phoneController,
                                label: "Phone Number",
                                icon: Icons.phone_iphone_rounded,
                                keyboardType: TextInputType.phone,
                                isRequired: true,
                              ),
                              const SizedBox(height: 12),
                              _buildModernTextField(
                                controller: productController,
                                label: "Product",
                                icon: Icons.shopping_bag_outlined,
                                enabled: false,
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 10 * scale),

                        // Payment Details Card
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(cardPadding),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Payment Details",
                                style: TextStyle(
                                  fontSize: 14 * scale,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E40AF),
                                ),
                              ),
                              SizedBox(height: 12 * scale),
                              // Total Amount
                              _buildPaymentRow(
                                "Total Amount",
                                "₹${total.toStringAsFixed(2)}",
                                Icons.currency_rupee_rounded,
                                const Color(0xFF1E40AF),
                              ),
                              SizedBox(height: 12 * scale),

                              // Received Amount with Toggle
                              Container(
                                padding: EdgeInsets.symmetric(
                                  vertical: 10 * scale,
                                  horizontal: 14 * scale,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isFullyPaid
                                          ? const Color(
                                            0xFF10B981,
                                          ).withOpacity(0.1)
                                          : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        isFullyPaid
                                            ? const Color(
                                              0xFF10B981,
                                            ).withOpacity(0.3)
                                            : Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(6 * scale),
                                      decoration: BoxDecoration(
                                        color:
                                            isFullyPaid
                                                ? const Color(0xFF10B981)
                                                : Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.payments_outlined,
                                        color:
                                            isFullyPaid
                                                ? Colors.white
                                                : Colors.grey.shade600,
                                        size: 20 * scale,
                                      ),
                                    ),
                                    SizedBox(width: 10 * scale),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Received Amount",
                                            style: TextStyle(
                                              fontSize: 12 * scale,
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          isFullyPaid
                                              ? Text(
                                                "₹${total.toStringAsFixed(2)}",
                                                style: TextStyle(
                                                  fontSize: 16 * scale,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF10B981),
                                                ),
                                              )
                                              : SizedBox(
                                                height: 40 * scale,
                                                child: TextFormField(
                                                  controller: amountController,
                                                  keyboardType:
                                                      const TextInputType.numberWithOptions(
                                                        decimal: true,
                                                      ),
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter.allow(
                                                      RegExp(r'^\d*\.?\d{0,2}'),
                                                    ),
                                                  ],
                                                  style: TextStyle(
                                                    fontSize: 16 * scale,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF10B981),
                                                  ),
                                                  decoration: InputDecoration(
                                                    hintText: "0.00",
                                                    hintStyle: TextStyle(
                                                      color: const Color(
                                                        0xFF10B981,
                                                      ).withOpacity(0.5),
                                                    ),
                                                    border: InputBorder.none,
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    prefixText: "₹",
                                                    prefixStyle: TextStyle(
                                                      fontSize: 16 * scale,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFF10B981),
                                                    ),
                                                  ),
                                                  onChanged:
                                                      (_) => setState(() {}),
                                                  validator: (value) {
                                                    if (!isFullyPaid &&
                                                        (value == null ||
                                                            value
                                                                .trim()
                                                                .isEmpty)) {
                                                      return null; // not required unless user toggles fully paid off
                                                    }
                                                    final val = double.tryParse(
                                                      value ?? '',
                                                    );
                                                    if (val == null) {
                                                      return 'Enter a valid amount';
                                                    }
                                                    if (val < 0) {
                                                      return 'Amount cannot be negative';
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              ),
                                        ],
                                      ),
                                    ),
                                    Transform.scale(
                                      scale: 0.75 * scale,
                                      child: Switch.adaptive(
                                        value: isFullyPaid,
                                        onChanged: (value) {
                                          setState(() {
                                            isFullyPaid = value;
                                            if (isFullyPaid) {
                                              amountController.text = total
                                                  .toStringAsFixed(2);
                                            } else {
                                              amountController.clear();
                                            }
                                          });
                                        },
                                        activeColor: const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 14 * scale),

                              // Payment Mode
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Payment Mode",
                                    style: TextStyle(
                                      fontSize: 12 * scale,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  SizedBox(height: 8 * scale),
                                  Wrap(
                                    spacing: 8 * scale,
                                    runSpacing: 8 * scale,
                                    children:
                                        _paymentModes.map((mode) {
                                          final isSelected =
                                              _selectedMode == mode;
                                          return GestureDetector(
                                            onTap:
                                                () => setState(
                                                  () => _selectedMode = mode,
                                                ),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 14 * scale,
                                                vertical: 8 * scale,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    isSelected
                                                        ? const Color(
                                                          0xFF1E40AF,
                                                        )
                                                        : Colors.grey.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color:
                                                      isSelected
                                                          ? const Color(
                                                            0xFF1E40AF,
                                                          )
                                                          : Colors
                                                              .grey
                                                              .shade200,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    _getIconForMode(mode),
                                                    size: 16 * scale,
                                                    color:
                                                        isSelected
                                                            ? Colors.white
                                                            : const Color(
                                                              0xFF1E40AF,
                                                            ),
                                                  ),
                                                  SizedBox(width: 6 * scale),
                                                  Text(
                                                    mode,
                                                    style: TextStyle(
                                                      fontSize: 12 * scale,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color:
                                                          isSelected
                                                              ? Colors.white
                                                              : const Color(
                                                                0xFF1E40AF,
                                                              ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20 * scale),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 50 * scale,
                          child: ElevatedButton(
                            onPressed: saveChanges,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E40AF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                              shadowColor: Colors.transparent,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.save_rounded,
                                  size: 18 * scale * scale,
                                ),
                                SizedBox(width: 8 * scale),
                                Text(
                                  "Save Changes",
                                  style: TextStyle(
                                    fontSize: 14 * scale,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAmountItem(
    String title,
    String amount,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12 * scale, color: color),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 10 * scale,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(
            fontSize: 14 * scale,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentRow(
    String title,
    String amount,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6 * scale),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16 * scale, color: color),
        ),
        SizedBox(width: 10 * scale),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12 * scale,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 14 * scale,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    bool enabled = true,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(fontSize: 12 * scale)),
            if (isRequired)
              Text(" *", style: TextStyle(color: Colors.red.shade400)),
          ],
        ),
        SizedBox(height: 4 * scale),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled ? Colors.grey.shade300 : Colors.grey.shade200,
            ),
            color: enabled ? Colors.white : Colors.grey.shade50,
          ),
          child: Row(
            children: [
              Padding(
                padding: EdgeInsets.only(left: 12 * scale),
                child: Icon(
                  icon,
                  size: 16 * scale,
                  color:
                      enabled ? const Color(0xFF1E40AF) : Colors.grey.shade400,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: 10 * scale),
                  child: TextFormField(
                    controller: controller,
                    enabled: enabled,
                    keyboardType: keyboardType,
                    style: TextStyle(
                      color: enabled ? Colors.black : Colors.grey.shade600,
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12 * scale,
                        vertical: 12 * scale,
                      ),
                      hintText: enabled ? "Enter $label" : label,
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                    ),
                    validator: (value) {
                      if (isRequired) {
                        if (value == null || value.trim().isEmpty) {
                          return "$label required";
                        }
                        if (label.toLowerCase().contains("phone")) {
                          final cleaned = value.trim();
                          if (!RegExp(r'^[0-9]+$').hasMatch(cleaned) ||
                              cleaned.length != 10) {
                            return "Enter a valid 10-digit phone number";
                          }
                        }
                      } else {
                        if (label.toLowerCase().contains("phone") &&
                            (value?.trim().isNotEmpty ?? false)) {
                          final cleaned = value!.trim();
                          if (!RegExp(r'^[0-9]+$').hasMatch(cleaned) ||
                              cleaned.length != 10) {
                            return "Enter a valid 10-digit phone number";
                          }
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
