// lib/screens/rental/rental_sale_detail_screen.dart

import 'package:bizmate/models/payment.dart';
import 'package:bizmate/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../../../models/rental_sale_model.dart';

class RentalSaleDetailScreen extends StatefulWidget {
  final RentalSaleModel sale;
  final int index;
  final String userEmail;

  const RentalSaleDetailScreen({
    super.key,
    required this.sale,
    required this.index,
    required this.userEmail,
  });

  @override
  State<RentalSaleDetailScreen> createState() => _RentalSaleDetailScreenState();
}

class _RentalSaleDetailScreenState extends State<RentalSaleDetailScreen> {
  late TextEditingController customerController;
  late TextEditingController phoneController;
  late TextEditingController itemController;
  late TextEditingController rateController;
  late TextEditingController daysController;
  late TextEditingController totalController;
  late TextEditingController amountController;
  double scale = 1.0;

  bool isFullyPaid = false;

  String _selectedMode = 'Cash';

  final List<String> _paymentModes = [
    'Cash',
    'UPI',
    'Card',
    'Bank Transfer',
    'Cheque',
    'Wallet',
  ];

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
    phoneController = TextEditingController(text: widget.sale.customerPhone);
    itemController = TextEditingController(text: widget.sale.itemName);
    rateController = TextEditingController(
      text: widget.sale.ratePerDay.toString(),
    );
    daysController = TextEditingController(
      text: widget.sale.numberOfDays.toString(),
    );
    totalController = TextEditingController(
      text: widget.sale.totalCost.toString(),
    );
    amountController = TextEditingController(
      text: widget.sale.amountPaid.toString(),
    );

    _selectedMode =
        widget.sale.paymentMode.isNotEmpty ? widget.sale.paymentMode : "Cash";

    isFullyPaid = widget.sale.amountPaid >= widget.sale.totalCost;
  }

  // SAME saveChanges()
  void saveChanges() async {
    if (customerController.text.trim().isEmpty) {
      AppSnackBar.showError(
        context,
        message: "Customer name cannot be empty!",
        duration: Duration(seconds: 2),
      );
      return;
    }

    if (phoneController.text.trim().length != 10 ||
        !RegExp(r'^[0-9]+$').hasMatch(phoneController.text)) {
      AppSnackBar.showError(
        context,
        message: "Enter a valid 10-digit phone!",
        duration: Duration(seconds: 2),
      );
      return;
    }

    double total = double.tryParse(totalController.text) ?? 0;
    double paid =
        double.tryParse(
          amountController.text.isEmpty ? "0" : amountController.text,
        ) ??
        0;

    if (total <= 0) {
      AppSnackBar.showError(
        context,
        message: "Total must be more than 0",
        duration: Duration(seconds: 2),
      );
      return;
    }

    final newPayment = Payment(
      amount: isFullyPaid ? total : paid,
      date: DateTime.now(),
      mode: _selectedMode,
    );

    final updatedSale = RentalSaleModel(
      id: widget.sale.id,
      customerName: customerController.text.trim(),
      customerPhone: phoneController.text.trim(),
      itemName: itemController.text.trim(),
      imageUrl: widget.sale.imageUrl,
      ratePerDay:
          double.tryParse(rateController.text) ?? widget.sale.ratePerDay,
      numberOfDays:
          int.tryParse(daysController.text) ?? widget.sale.numberOfDays,
      totalCost: total,
      fromDateTime: widget.sale.fromDateTime,
      toDateTime: widget.sale.toDateTime,
      pdfFilePath: widget.sale.pdfFilePath,
      paymentMode: _selectedMode,
      amountPaid: newPayment.amount,
      rentalDateTime: widget.sale.rentalDateTime,
      paymentHistory: [newPayment, ...widget.sale.paymentHistory],
    );

    final safeEmail = widget.userEmail
        .replaceAll('.', '_')
        .replaceAll('@', '_');
    final box = Hive.box("userdata_$safeEmail");

    List<RentalSaleModel> originalList = List<RentalSaleModel>.from(
      box.get("rental_sales", defaultValue: []),
    );

    int realIndex = originalList.length - 1 - widget.index;

    if (realIndex >= 0 && realIndex < originalList.length) {
      originalList[realIndex] = updatedSale;
    }

    await box.put("rental_sales", originalList);

    AppSnackBar.showSuccess(
      context,
      message: "Rental sale updated!",
      duration: Duration(seconds: 2),
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(widget.sale.rentalDateTime);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        final padding = isWide ? 120.0 : 16.0;
        final cardPad = isWide ? 24.0 : 16.0;

        double total =
            double.tryParse(totalController.text) ?? widget.sale.totalCost;
        double paid =
            double.tryParse(amountController.text) ?? widget.sale.amountPaid;

        String statusText;
        Color statusColor;
        IconData statusIcon;

        if (paid == total) {
          statusText = "Fully Paid";
          statusColor = const Color(0xFF10B981);
          statusIcon = Icons.check_circle;
        } else if (paid > 0) {
          statusText = "Partially Paid";
          statusColor = const Color(0xFFF59E0B);
          statusIcon = Icons.pending;
        } else {
          statusText = "Unpaid";
          statusColor = const Color(0xFFEF4444);
          statusIcon = Icons.schedule;
        }

        final titleSize = isWide ? 20.0 : 18.0;
        // ignore: unused_local_variable
        final subtitleSize = isWide ? 14.0 : 13.0;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1E40AF),
            title: Text(
              "Rental Sale Details",
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E40AF),
              ),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.save_rounded),
                onPressed: saveChanges,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: 20),
            child: Column(
              children: [
                // HEADER CARD -------------------------------------------
                Container(
                  padding: EdgeInsets.all(cardPad),
                  decoration: _cardDecoration(),
                  child: Row(
                    children: [
                      _iconBox(Icons.receipt_long_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.sale.itemName,
                              style: TextStyle(
                                fontSize: 13 * scale,
                                color: Color(0xFF1E40AF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatted,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 9 * scale,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _statusBadge(statusText, statusColor, statusIcon),
                    ],
                  ),
                ),

                SizedBox(height: 10 * scale),

                // CUSTOMER INFO CARD -----------------------------------
                Container(
                  padding: EdgeInsets.all(cardPad),
                  decoration: _cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle("Customer Information"),
                      SizedBox(height: 12 * scale),
                      _modernField(
                        controller: customerController,
                        label: "Customer Name",
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 12),
                      _modernField(
                        controller: phoneController,
                        label: "Phone Number",
                        icon: Icons.phone_iphone_rounded,
                        keyboard: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      _modernField(
                        controller: itemController,
                        label: "Item Name",
                        enabled: false,
                        icon: Icons.shopping_bag_outlined,
                      ),
                      const SizedBox(height: 12),
                      _modernField(
                        controller: rateController,
                        label: "Rate Per Day",
                        enabled: false,
                        icon: Icons.currency_rupee,
                      ),
                      const SizedBox(height: 12),
                      _modernField(
                        controller: daysController,
                        label: "Number of Days",
                        enabled: false,
                        icon: Icons.today,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 10 * scale),

                // PAYMENT DETAILS CARD ----------------------------------
                Container(
                  padding: EdgeInsets.all(cardPad),
                  decoration: _cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle("Payment Details"),

                      SizedBox(height: 12 * scale),

                      _amountDisplay(
                        "Total Cost",
                        "₹${total.toStringAsFixed(2)}",
                        Icons.currency_rupee_rounded,
                        const Color(0xFF1E40AF),
                      ),
                      SizedBox(height: 12 * scale),

                      // RECEIVED AMOUNT BOX ----------------------------------
                      _receivedAmountBox(total),

                      const SizedBox(height: 16),

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
                                  final isSelected = _selectedMode == mode;
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
                                                ? const Color(0xFF1E40AF)
                                                : Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                              isSelected
                                                  ? const Color(0xFF1E40AF)
                                                  : Colors.grey.shade200,
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
                                                    : const Color(0xFF1E40AF),
                                          ),
                                          SizedBox(width: 6 * scale),
                                          Text(
                                            mode,
                                            style: TextStyle(
                                              fontSize: 12 * scale,
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  isSelected
                                                      ? Colors.white
                                                      : const Color(0xFF1E40AF),
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

                // SAVE BUTTON ---------------------------------------------
                SizedBox(
                  width: double.infinity,
                  height: 50 * scale,
                  child: ElevatedButton(
                    onPressed: saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E40AF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.save_rounded,
                          size: 18 * scale,
                          color: Colors.white,
                        ),
                        SizedBox(width: 8 * scale),
                        Text(
                          "Save Changes",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14 * scale,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10 * scale),
              ],
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------
  // REUSABLE UI WIDGETS (identical design to Sale UI)
  // -------------------------------------------------------------------

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );

  Widget _iconBox(IconData icon) => Container(
    padding: EdgeInsets.all(6 * scale),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: const Color(0xFF1E40AF), size: 20 * scale),
  );

  Widget _sectionTitle(String title) => Text(
    title,
    style: TextStyle(
      fontSize: 14 * scale,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1E40AF),
    ),
  );

  Widget _statusBadge(String txt, Color c, IconData i) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: c.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Icon(i, size: 10 * scale, color: c),
        const SizedBox(width: 4),
        Text(
          txt,
          style: TextStyle(
            fontSize: 10 * scale,
            fontWeight: FontWeight.w600,
            color: c,
          ),
        ),
      ],
    ),
  );

  Widget _modernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboard,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12 * scale)),
        SizedBox(height: 4 * scale),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            color: enabled ? Colors.white : Colors.grey.shade100,
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
                child: TextFormField(
                  controller: controller,
                  enabled: enabled,
                  keyboardType: keyboard,
                  style: TextStyle(
                    fontSize: 12 * scale,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12 * scale,
                      vertical: 12 * scale,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _amountDisplay(
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
            fontWeight: FontWeight.w700,
            fontSize: 14 * scale,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _receivedAmountBox(double total) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: 10 * scale,
        horizontal: 14 * scale,
      ),
      decoration: BoxDecoration(
        color:
            isFullyPaid
                ? const Color(0xFF10B981).withOpacity(0.1)
                : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isFullyPaid
                  ? const Color(0xFF10B981).withOpacity(0.3)
                  : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color:
                  isFullyPaid ? const Color(0xFF10B981) : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.payments_outlined,
              color: isFullyPaid ? Colors.white : Colors.grey.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      height: 40,
                      child: TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
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
                            color: const Color(0xFF10B981).withOpacity(0.5),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          prefixText: "₹",
                          prefixStyle: TextStyle(
                            fontSize: 16 * scale,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          if (!isFullyPaid &&
                              (value == null || value.trim().isEmpty)) {
                            return null; // not required unless user toggles fully paid off
                          }
                          final val = double.tryParse(value ?? '');
                          if (val == null) return 'Enter a valid amount';
                          if (val < 0) return 'Amount cannot be negative';
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
                    amountController.text = total.toStringAsFixed(2);
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
    );
  }
}
