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
            foregroundColor: const Color(0xFF1A237E),
            title: Text(
              "Rental Sale Details",
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A237E),
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
                              style: const TextStyle(
                                fontSize: 18,
                                color: Color(0xFF1A237E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatted,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _statusBadge(statusText, statusColor, statusIcon),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // CUSTOMER INFO CARD -----------------------------------
                Container(
                  padding: EdgeInsets.all(cardPad),
                  decoration: _cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle("Customer Information"),
                      const SizedBox(height: 16),
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

                const SizedBox(height: 20),

                // PAYMENT DETAILS CARD ----------------------------------
                Container(
                  padding: EdgeInsets.all(cardPad),
                  decoration: _cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle("Payment Details"),

                      const SizedBox(height: 20),

                      _amountDisplay(
                        "Total Cost",
                        "₹${total.toStringAsFixed(2)}",
                        Icons.currency_rupee_rounded,
                        const Color(0xFF1A237E),
                      ),

                      const SizedBox(height: 16),

                      // RECEIVED AMOUNT BOX ----------------------------------
                      _receivedAmountBox(total),

                      const SizedBox(height: 16),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Payment Mode",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                _paymentModes.map((mode) {
                                  final isSelected = _selectedMode == mode;
                                  return GestureDetector(
                                    onTap:
                                        () => setState(
                                          () => _selectedMode = mode,
                                        ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected
                                                ? const Color(0xFF1A237E)
                                                : Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                              isSelected
                                                  ? const Color(0xFF1A237E)
                                                  : Colors.grey.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _getIconForMode(mode),
                                            size: 18,
                                            color:
                                                isSelected
                                                    ? Colors.white
                                                    : const Color(0xFF1A237E),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            mode,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  isSelected
                                                      ? Colors.white
                                                      : const Color(0xFF1A237E),
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

                const SizedBox(height: 24),

                // SAVE BUTTON ---------------------------------------------
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save_rounded, size: 20, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          "Save Changes",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: const Color(0xFF1A237E), size: 24),
  );

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1A237E),
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
        Icon(i, size: 14, color: c),
        const SizedBox(width: 4),
        Text(
          txt,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c),
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
        Text(label),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            color: enabled ? Colors.white : Colors.grey.shade100,
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Icon(icon, color: const Color(0xFF1A237E)),
              ),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  enabled: enabled,
                  keyboardType: keyboard,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _receivedAmountBox(double total) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                isFullyPaid
                    ? Text(
                      "₹${total.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 18,
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
                        style: const TextStyle(
                          fontSize: 18,
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
                          prefixStyle: const TextStyle(
                            fontSize: 18,
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
          Switch.adaptive(
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
        ],
      ),
    );
  }
}
