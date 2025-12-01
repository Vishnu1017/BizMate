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

  // ------------------------------------------------------------------
  // ⭐⭐⭐ SAVE CHANGES (EXACTLY LIKE FIRST CODE YOU SENT) ⭐⭐⭐
  // ------------------------------------------------------------------
  void saveChanges() async {
    // VALIDATION
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

    // NEW PAYMENT ENTRY
    final newPayment = Payment(
      amount: isFullyPaid ? total : paid,
      date: DateTime.now(),
      mode: _selectedMode,
    );

    // ------------ ⭐ FIX: UPDATE ALL EDITABLE FIELDS ⭐ --------------
    final updatedSale = RentalSaleModel(
      id: widget.sale.id,

      customerName: customerController.text.trim(),
      customerPhone: phoneController.text.trim(),

      /// Previously you did NOT update these — FIXED now
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

    // ------------ ⭐ FIX: CORRECT HIVE UPDATE WITH REVERSE INDEX ⭐ --------------

    final safeEmail = widget.userEmail
        .replaceAll('.', '_')
        .replaceAll('@', '_');

    final box = Hive.box("userdata_$safeEmail");

    List<RentalSaleModel> originalList = List<RentalSaleModel>.from(
      box.get("rental_sales", defaultValue: []),
    );

    // Convert UI index → real index
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

  InputDecoration customInput(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Color(0xFF1A237E)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.blue.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Color(0xFF1A237E), width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(widget.sale.rentalDateTime);

    double total = double.tryParse(totalController.text) ?? 0;
    double paid = double.tryParse(amountController.text) ?? 0;
    double balance = total - paid;

    return Scaffold(
      backgroundColor: Color(0xFFE3F2FD),
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: const Text(
          "Rental Sale Details",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF00BCD4)],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Text(formattedDate, style: TextStyle(color: Colors.grey[700])),
              SizedBox(height: 20),

              TextField(
                controller: customerController,
                decoration: customInput("Customer Name", Icons.person),
              ),
              SizedBox(height: 20),

              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: customInput("Phone Number", Icons.phone),
              ),
              SizedBox(height: 20),

              TextField(
                controller: itemController,
                readOnly: true,
                decoration: customInput("Item Name", Icons.camera_alt),
              ),
              SizedBox(height: 20),

              TextField(
                controller: rateController,
                readOnly: true,
                decoration: customInput("Rate Per Day", Icons.currency_rupee),
              ),
              SizedBox(height: 20),

              TextField(
                controller: daysController,
                readOnly: true,
                decoration: customInput("Number of Days", Icons.today),
              ),
              SizedBox(height: 20),

              // Payment Section ---------------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total Cost",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    "₹ ${total.toStringAsFixed(2)}",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),

              Divider(),

              // Received Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        isFullyPaid = !isFullyPaid;
                        if (isFullyPaid) {
                          amountController.text = total.toStringAsFixed(2);
                        } else {
                          amountController.clear();
                        }
                      });
                    },
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isFullyPaid ? Colors.green : Colors.grey,
                              width: 1.5,
                            ),
                            color:
                                isFullyPaid ? Colors.green : Colors.transparent,
                          ),
                          child:
                              isFullyPaid
                                  ? const Icon(
                                    Icons.check,
                                    size: 18,
                                    color: Colors.white,
                                  )
                                  : null,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Received",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 100,
                    height: 40,
                    alignment: Alignment.centerRight,
                    child:
                        isFullyPaid
                            ? Text(
                              "₹ ${(double.tryParse(total.toStringAsFixed(2)) ?? 0).toStringAsFixed(2)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.green[700],
                              ),
                            )
                            : TextFormField(
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
                              textAlign: TextAlign.end,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: "0.00",
                                hintStyle: TextStyle(
                                  color: Colors.green.shade400,
                                ),
                                prefixIcon: Icon(
                                  Icons.currency_rupee,
                                  color: Colors.green.shade700,
                                  size: 20,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.green[700],
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                  ),
                ],
              ),

              Divider(),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    balance > 0 ? "Balance Due" : "Paid in Full",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: balance > 0 ? Colors.red : Colors.green,
                    ),
                  ),
                  Text(
                    "₹ ${balance.abs().toStringAsFixed(2)}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: balance > 0 ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: _selectedMode,
                items:
                    _paymentModes
                        .map(
                          (mode) => DropdownMenuItem(
                            value: mode,
                            child: Row(
                              children: [
                                Icon(
                                  _getIconForMode(mode),
                                  size: 20,
                                  color: Color(0xFF1A237E),
                                ),
                                SizedBox(width: 8),
                                Text(mode),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _selectedMode = v!),
                decoration: customInput("Payment Mode", Icons.payment),
              ),

              SizedBox(height: 30),

              // Save Button ----------------------------------------------------
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1A237E), Color(0xFF00BCD4)],
                  ),
                ),
                child: ElevatedButton.icon(
                  onPressed: saveChanges,
                  icon: Icon(Icons.save, color: Colors.white),
                  label: Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      "Save Changes",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
