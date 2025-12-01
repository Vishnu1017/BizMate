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
    phoneController = TextEditingController(text: widget.sale.phoneNumber);
    productController = TextEditingController(text: widget.sale.productName);
    amountController = TextEditingController(
      text: widget.sale.amount.toString(),
    );
    totalAmountController = TextEditingController(
      text: widget.sale.totalAmount.toString(),
    );
    _selectedMode =
        widget.sale.paymentMode.isNotEmpty ? widget.sale.paymentMode : 'Cash';
    isFullyPaid = widget.sale.amount >= widget.sale.totalAmount;
  }

  void saveChanges() async {
    // ✅ VALIDATION
    if (customerController.text.trim().isEmpty) {
      AppSnackBar.showError(
        context,
        message: "Customer name cannot be empty!",
        duration: const Duration(seconds: 2),
      );
      return;
    }

    if (phoneController.text.trim().isEmpty ||
        phoneController.text.trim().length != 10 ||
        !RegExp(r'^[0-9]+$').hasMatch(phoneController.text.trim())) {
      AppSnackBar.showError(
        context,
        message: "Enter a valid 10-digit phone number!",
        duration: const Duration(seconds: 2),
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
        duration: const Duration(seconds: 2),
      );
      return;
    }

    if (!isFullyPaid && paid < 0) {
      AppSnackBar.showError(
        context,
        message: "Paid amount cannot be negative!",
        duration: const Duration(seconds: 2),
      );
      return;
    }

    // -------------------------------------------------------
    // ✅ FIX: Load the CURRENT USER'S SALES BOX
    // -------------------------------------------------------
    if (!Hive.isBoxOpen('session')) {
      await Hive.openBox('session');
    }

    final sessionBox = Hive.box('session');
    final email = sessionBox.get("currentUserEmail");

    if (email == null) {
      AppSnackBar.showError(
        context,
        message: "Session expired. Please login again.",
        duration: Duration(seconds: 2),
      );
      return;
    }

    final safeEmail = email
        .toString()
        .replaceAll('.', '_')
        .replaceAll('@', '_');

    final userBox = await Hive.openBox("userdata_$safeEmail");

    // Fetch the existing sales list
    List<Sale> sales = [];
    try {
      sales = List<Sale>.from(userBox.get("sales", defaultValue: []));
    } catch (_) {
      sales = [];
    }

    // -------------------------------------------------------
    // Generate new payment entry
    // -------------------------------------------------------
    final newPayment = Payment(
      amount: isFullyPaid ? total : paid,
      date: DateTime.now(),
      mode: _selectedMode,
    );

    // -------------------------------------------------------
    // Create updated sale object
    // -------------------------------------------------------
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

    // -------------------------------------------------------
    // ✅ Correct saving: Update sale inside user's sales LIST
    // -------------------------------------------------------
    if (widget.index < sales.length) {
      sales[widget.index] = updatedSale;
    }

    await userBox.put("sales", sales); // save entire list back

    AppSnackBar.showSuccess(
      context,
      message: 'Sale updated successfully!',
      duration: Duration(seconds: 2),
    );

    Navigator.pop(context);
  }

  InputDecoration customInput(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF1A237E),
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF1A237E)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF1A237E), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF90CAF9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF1A237E), width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(widget.sale.dateTime);

    double total = double.tryParse(totalAmountController.text) ?? 0;
    double paid =
        double.tryParse(
          amountController.text.isEmpty ? "0" : amountController.text,
        ) ??
        0;
    double balance = total - paid;

    String statusText;
    Color statusColor;

    if (paid == total) {
      statusText = "Paid in Full";
      statusColor = Colors.green;
    } else if (paid > total) {
      statusText = "Overpaid";
      statusColor = Colors.green;
    } else {
      statusText = "Balance Due";
      statusColor = Colors.red;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF00BCD4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: const Text(
            "Sale Details",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          centerTitle: true,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(" $formatted", style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 20),
                TextField(
                  controller: customerController,
                  decoration: customInput("Customer Name", Icons.person),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: customInput("Phone Number", Icons.phone),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: productController,
                  enabled: false,
                  decoration: customInput(
                    "Product Name (Locked)",
                    Icons.shopping_bag,
                  ).copyWith(filled: true, fillColor: Colors.grey.shade200),
                ),
                const SizedBox(height: 30),

                // 💰 Payment Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Total Amount",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          "₹ ${totalAmountController.text.isEmpty ? '0.00' : totalAmountController.text}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),

                    // Received
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              isFullyPaid = !isFullyPaid;
                              if (isFullyPaid) {
                                amountController.text =
                                    totalAmountController.text;
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
                                    color:
                                        isFullyPaid
                                            ? Colors.green
                                            : Colors.grey,
                                    width: 1.5,
                                  ),
                                  color:
                                      isFullyPaid
                                          ? Colors.green
                                          : Colors.transparent,
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
                                    "₹ ${(double.tryParse(totalAmountController.text) ?? 0).toStringAsFixed(2)}",
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
                                      contentPadding:
                                          const EdgeInsets.symmetric(
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
                    const Divider(),

                    // Balance / Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          statusText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: statusColor,
                          ),
                        ),
                        Text(
                          "₹ ${balance.abs().toStringAsFixed(2)}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Payment Mode
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
                                        color: const Color(0xFF1A237E),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(mode),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedMode = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Payment Mode',
                        prefixIcon: const Icon(Icons.payment),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.95),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.blue.shade100),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          borderSide: BorderSide(
                            color: Color(0xFF1A237E),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Save Button
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A237E), Color(0xFF00BCD4)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: saveChanges,
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14.0),
                      child: Text(
                        "Save Changes",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
