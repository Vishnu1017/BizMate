// lib/screens/new_sale_screen.dart
import 'dart:ui';
import 'package:bizmate/models/payment.dart';
import 'package:bizmate/widgets/ModernCalendar.dart' show ModernCalendar;
import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/sale.dart';
import 'select_items_screen.dart';

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final customerController = TextEditingController();
  final productController = TextEditingController();
  final amountController = TextEditingController();
  final totalAmountController = TextEditingController();
  final receivedController = TextEditingController();
  final phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime selectedDate = DateTime.now();
  bool isLoading = false;
  bool isFullyPaid = false;
  String _selectedMode = 'Cash';
  bool isCustomerSelectedFromList = false;
  double scale = 1.0;
  late final screenWidth = MediaQuery.of(context).size.width;

  List<Map<String, String>> customerList = [];
  Map<String, dynamic>? selectedItemDetails;
  List<Map<String, dynamic>> selectedItems = [];

  double get totalQty => selectedItems.fold(
    0.0,
    (sum, item) =>
        sum +
        (double.tryParse(item['qty']?.toString() ?? '1') ??
            1.0), // safe fallback to 1.0
  );

  double get totalDiscount {
    return selectedItems.fold(0.0, (sum, item) {
      final discountAmount =
          double.tryParse(item['discountAmount']?.toString() ?? '0') ?? 0;
      return sum + discountAmount;
    });
  }

  double get totalTaxAmount {
    double totalTax = 0.0;

    for (final item in selectedItems) {
      final qty = double.tryParse(item['qty']?.toString() ?? '1') ?? 1;
      final rawRate = double.tryParse(item['rate']?.toString() ?? '0') ?? 0;
      final discountPercent =
          double.tryParse(item['discount']?.toString() ?? '0') ?? 0;
      final discountAmount =
          double.tryParse(item['discountAmount']?.toString() ?? '0') ?? 0;
      final taxPercent = double.tryParse(item['tax']?.toString() ?? '0') ?? 0;
      final taxType = item['taxType']?.toString() ?? 'Without Tax';

      double rate = rawRate;

      if (taxType == 'With Tax' && taxPercent > 0) {
        rate = rawRate / (1 + (taxPercent / 100));
      }

      final itemSubtotal = rate * qty;
      final taxableAmount = itemSubtotal - discountAmount;

      double taxAmount = 0.0;
      if (taxType == 'With Tax' && discountPercent < 100) {
        taxAmount = taxableAmount * taxPercent / 100;
      }

      totalTax += taxAmount;
    }

    return totalTax;
  }

  double get subtotal {
    double sum = 0.0;

    for (final item in selectedItems) {
      final totalAmount =
          double.tryParse(item['totalAmount']?.toString() ?? '0') ?? 0;
      sum += totalAmount;
    }

    return sum;
  }

  @override
  void initState() {
    super.initState();
    fetchCustomerList();
  }

  void fetchCustomerList() async {
    try {
      final sessionBox = await Hive.openBox('session');
      final email = sessionBox.get('currentUserEmail');

      if (email == null || email.toString().isEmpty) {
        setState(() => customerList = []);
        return;
      }

      final safeEmail = email.replaceAll('.', '_').replaceAll('@', '_');
      final userBox = await Hive.openBox('userdata_$safeEmail');

      List<Sale> sales = List<Sale>.from(
        userBox.get("sales", defaultValue: <Sale>[]),
      );

      final Set<String> seen = {};
      final List<Map<String, String>> uniqueCustomers = [];

      for (final sale in sales) {
        final key = "${sale.customerName}_${sale.phoneNumber}";
        if (!seen.contains(key)) {
          seen.add(key);
          uniqueCustomers.add({
            'name': sale.customerName,
            'phone': sale.phoneNumber,
          });
        }
      }

      setState(() {
        customerList = uniqueCustomers;
      });
    } catch (e) {
      // safe fallback
      setState(() => customerList = []);
    }
  }

  void removeItem(int index) {
    setState(() {
      selectedItems.removeAt(index);
      productController.text = selectedItems
          .map((e) => e['itemName'])
          .join(', ');
      totalAmountController.text = subtotal.toStringAsFixed(2);
    });
  }

  Future<bool> isPhoneNumberDuplicate() async {
    if (isCustomerSelectedFromList) return false;

    final saleBox = Hive.box<Sale>('sales');
    final phoneNumber = phoneController.text.trim();

    if (phoneNumber.isEmpty) return false;

    return saleBox.values.any((sale) => sale.phoneNumber.trim() == phoneNumber);
  }

  void addItem() async {
    final newItem = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SelectItemsScreen()),
    );

    if (newItem != null && newItem is Map<String, dynamic>) {
      setState(() {
        selectedItems.add(newItem);
        productController.text = selectedItems
            .map((e) => e['itemName'])
            .join(', ');
        totalAmountController.text = subtotal.toStringAsFixed(2);
      });
    }
  }

  void _showCustomCalendar(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ModernCalendar(
            onDateSelected: (DateTime date) {
              setState(() {
                selectedDate = date;
              });
              Navigator.pop(context); // close bottom sheet
            },
          ),
        );
      },
    );
  }

  Widget buildItemCard(int index, Map<String, dynamic> item) {
    final qty = double.tryParse(item['qty']?.toString() ?? '1') ?? 1.0;
    final rate = double.tryParse(item['rate']?.toString() ?? '0') ?? 0.0;
    final discountPercent =
        double.tryParse(item['discount']?.toString() ?? '0') ?? 0.0;
    final discountAmount =
        double.tryParse(item['discountAmount']?.toString() ?? '0') ?? 0.0;
    final taxPercent = double.tryParse(item['tax']?.toString() ?? '0') ?? 0.0;
    final subtotalItem =
        double.tryParse(item['subtotal']?.toString() ?? '0') ?? 0.0;
    final totalAmount =
        double.tryParse(item['totalAmount']?.toString() ?? '0') ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF8FAFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // INDEX BADGE
                Container(
                  width: 24 * scale,
                  height: 24 * scale,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "${index + 1}",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14 * scale,
                    ),
                  ),
                ),

                // LEFT SIDE — ITEM DETAILS
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['itemName']?.toString() ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 10 * scale,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${qty.toStringAsFixed(1)} × ₹${rate.toStringAsFixed(2)}",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 8 * scale,
                        ),
                      ),
                    ],
                  ),
                ),

                // RIGHT SIDE — PRICE + SAVE (SAFE WITH FLEXIBLE)
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "₹ ${totalAmount.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12 * scale,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667EEA).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Save ₹${discountAmount.toStringAsFixed(2)}",
                          style: TextStyle(
                            color: Color(0xFF667EEA),
                            fontSize: 8 * scale,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // DELETE ICON
                GestureDetector(
                  onTap: () => removeItem(index),
                  child: Container(
                    width: 30 * scale,
                    height: 30 * scale,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDetailItem(
                    "Subtotal",
                    "₹${subtotalItem.toStringAsFixed(2)}",
                    const Color(0xFF666666),
                  ),
                  Container(width: 1, height: 20, color: Colors.grey.shade300),
                  _buildDetailItem(
                    "Discount",
                    "${discountPercent.toStringAsFixed(1)}%",
                    const Color(0xFFFF6B6B),
                  ),
                  Container(width: 1, height: 20, color: Colors.grey.shade300),
                  if (taxPercent > 0)
                    _buildDetailItem(
                      "Tax",
                      "${taxPercent.toStringAsFixed(1)}%",
                      const Color(0xFF4ECDC4),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 10 * scale,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  void showCustomerPicker() {
    if (customerList.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppSnackBar.showWarning(
          context,
          message: 'No customers found. Please add a sale first.',
          duration: const Duration(seconds: 2),
        );
      });
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final media = MediaQuery.of(context);
        final width = media.size.width;
        final height = media.size.height;

        // RESOLUTION SCALING (Same as product picker)
        double rs(double v) => v * (width / 390);

        // GRID RESPONSIVENESS
        int columns = 2;
        if (width >= 1200) {
          columns = 5;
        } else if (width >= 900) {
          columns = 4;
        } else if (width >= 600) {
          columns = 3;
        }

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                // ---------- HEADER ----------
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: rs(20),
                    vertical: rs(16),
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Select Customer",
                        style: TextStyle(
                          fontSize: rs(18),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: rs(22),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ---------- EMPTY STATE ----------
                if (customerList.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.group_outlined,
                            size: rs(60),
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(height: rs(16)),
                          Text(
                            "No customers yet",
                            style: TextStyle(
                              fontSize: rs(16),
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            "Add a sale to see customers here",
                            style: TextStyle(
                              fontSize: rs(13),
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // ---------- RESPONSIVE GRID ----------
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: rs(14)),
                      child: GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: customerList.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: rs(14),
                          mainAxisSpacing: rs(14),
                          childAspectRatio:
                              width >= 900
                                  ? 2.6
                                  : width >= 600
                                  ? 2.3
                                  : 1.8,
                        ),
                        itemBuilder: (context, index) {
                          final customer = customerList[index];
                          final initials =
                              customer['name']!
                                  .split(' ')
                                  .map((e) => e.isNotEmpty ? e[0] : '')
                                  .join()
                                  .toUpperCase();

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                customerController.text = customer['name']!;
                                phoneController.text = customer['phone']!;
                                isCustomerSelectedFromList = true;
                              });
                              Navigator.pop(context);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF667EEA),
                                    Color(0xFF764BA2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(rs(16)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: rs(8),
                                    offset: Offset(0, rs(4)),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(rs(16)),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: rs(28),
                                        height: rs(28),
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          borderRadius: BorderRadius.circular(
                                            rs(8),
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          initials.length > 2
                                              ? initials.substring(0, 2)
                                              : initials,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: rs(12),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: rs(12),
                                        color: Colors.white70,
                                      ),
                                    ],
                                  ),

                                  // Name & Phone
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer['name']!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: rs(13),
                                        ),
                                      ),
                                      SizedBox(height: rs(4)),
                                      Text(
                                        customer['phone']!,
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: rs(12),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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

  void saveSale() async {
    setState(() => isLoading = true);

    final sessionBox = await Hive.openBox('session');
    final currentEmail = sessionBox.get("currentUserEmail");

    if (currentEmail == null || currentEmail.toString().isEmpty) {
      setState(() => isLoading = false);
      AppSnackBar.showError(
        context,
        message: "No logged-in user found!",
        duration: const Duration(seconds: 2),
      );
      return;
    }

    final safeEmail = currentEmail.replaceAll('.', '_').replaceAll('@', '_');
    final userBox = await Hive.openBox('userdata_$safeEmail');

    final newPayment = Payment(
      amount: double.tryParse(amountController.text) ?? 0,
      date: DateTime.now(),
      mode: _selectedMode,
    );

    final sale = Sale(
      customerName: customerController.text,
      item: productController.text,
      phoneNumber: phoneController.text,
      amount: newPayment.amount,
      totalAmount: double.tryParse(totalAmountController.text) ?? 0,
      dateTime: selectedDate,
      deliveryStatus: 'All Non Editing Images',
      paymentHistory: [newPayment],
      discount: totalDiscount,
      productName: productController.text,
    );

    List<Sale> userSales = List<Sale>.from(
      userBox.get("sales", defaultValue: <Sale>[]),
    );
    userSales.add(sale);

    await userBox.put("sales", userSales);

    setState(() => isLoading = false);

    AppSnackBar.showSuccess(
      context,
      message: "Sale saved successfully!",
      duration: const Duration(seconds: 2),
    );

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) Navigator.pop(context);
  }

  InputDecoration customInput(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF667EEA),
        fontWeight: FontWeight.w500,
        fontSize: 15,
      ),
      hintText: "Enter $label",
      hintStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: Container(
        width: 56,
        child: Icon(icon, color: const Color(0xFF667EEA), size: 22),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: const Color(0xFF667EEA).withOpacity(0.5),
          width: 2,
        ),
      ),
      floatingLabelBehavior: FloatingLabelBehavior.always,
    );
  }

  double _scaleForWidth(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    if (width >= 1200) return 1.12;
    if (width >= 1000) return 1.05;
    if (width >= 800) return 1.0;
    if (width >= 600) return 0.96;
    return 0.92;
  }

  EdgeInsets _responsivePadding(BoxConstraints constraints) {
    final w = constraints.maxWidth;
    if (w >= 1200)
      return const EdgeInsets.symmetric(horizontal: 48, vertical: 24);
    if (w >= 900)
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
    if (w >= 600)
      return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    return const EdgeInsets.symmetric(horizontal: 12, vertical: 12);
  }

  Widget _leftColumn(BuildContext context, BoxConstraints constraints) {
    final scale = _scaleForWidth(constraints);
    final padding = _responsivePadding(constraints);
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: padding,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Customer Details",
                      style: TextStyle(
                        fontSize: 18 * scale,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: customerController,
                      onTap: showCustomerPicker,
                      decoration: customInput(
                        "Customer Name",
                        Icons.person,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Color(0xFF667EEA),
                          ),
                          onPressed: showCustomerPicker,
                        ),
                      ),
                      validator:
                          (val) =>
                              val!.trim().isEmpty
                                  ? 'Enter customer name'
                                  : null,
                      onChanged: (value) {
                        if (value.isNotEmpty &&
                            value[0] != value[0].toUpperCase()) {
                          customerController.text = value.splitMapJoin(
                            ' ',
                            onNonMatch:
                                (word) =>
                                    word.isNotEmpty
                                        ? word[0].toUpperCase() +
                                            (word.length > 1
                                                ? word
                                                    .substring(1)
                                                    .toLowerCase()
                                                : '')
                                        : '',
                          );
                          customerController
                              .selection = TextSelection.fromPosition(
                            TextPosition(
                              offset: customerController.text.length,
                            ),
                          );
                        }
                        if (isCustomerSelectedFromList)
                          setState(() => isCustomerSelectedFromList = false);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: customInput("Phone Number", Icons.phone),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty)
                          return 'Enter phone number';
                        if (!RegExp(r'^[0-9]{10}$').hasMatch(val))
                          return 'Enter valid 10-digit number';
                        return null;
                      },
                      onChanged: (value) {
                        if (isCustomerSelectedFromList)
                          setState(() => isCustomerSelectedFromList = false);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Date Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Sale Date",
                      style: TextStyle(
                        fontSize: 16 * scale,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => _showCustomCalendar(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF667EEA).withOpacity(0.1),
                              const Color(0xFF764BA2).withOpacity(0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF667EEA).withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF667EEA),
                                        Color(0xFF764BA2),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_today,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Select Sale Date",
                                      style: TextStyle(
                                        fontSize: 12 * scale,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                                      style: TextStyle(
                                        fontSize: 14 * scale,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF333333),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Color(0xFF667EEA),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Items Section
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 20 * scale,
                  vertical: 18 * scale,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Items",
                          style: TextStyle(
                            fontSize: (screenWidth > 900 ? 20 : 18) * scale,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2A2A2A),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14 * scale),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF667EEA,
                                ).withOpacity(0.28),
                                blurRadius: 10 * scale,
                                offset: Offset(0, 4 * scale),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: addItem,
                            icon: Icon(
                              Icons.add,
                              size: (screenWidth > 900 ? 20 : 18) * scale,
                              color: Colors.white,
                            ),
                            label: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: 2 * scale,
                              ),
                              child: Text(
                                'Add Items',
                                style: TextStyle(
                                  fontSize:
                                      (screenWidth > 900 ? 14 : 12) * scale,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: EdgeInsets.symmetric(
                                horizontal: 20 * scale,
                                vertical: 12 * scale,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14 * scale),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20 * scale),
                    if (selectedItems.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 32 * scale,
                          vertical: 40 * scale,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFF),
                          borderRadius: BorderRadius.circular(18 * scale),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1.4,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_basket_outlined,
                              size: (screenWidth > 900 ? 70 : 60) * scale,
                              color: Colors.grey.shade400,
                            ),
                            SizedBox(height: 16 * scale),
                            Text(
                              "No items added yet",
                              style: TextStyle(
                                fontSize: (screenWidth > 900 ? 18 : 16) * scale,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(height: 8 * scale),
                            Text(
                              "Tap 'Add Items' to start",
                              style: TextStyle(
                                fontSize: (screenWidth > 900 ? 15 : 14) * scale,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children:
                            selectedItems
                                .asMap()
                                .entries
                                .map(
                                  (entry) =>
                                      buildItemCard(entry.key, entry.value),
                                )
                                .toList(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Summary (only visible when items exist)
            if (selectedItems.isNotEmpty)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Order Summary",
                        style: TextStyle(
                          fontSize: 16 * scale,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryRow(
                        "Total Items",
                        selectedItems.length.toString(),
                        scale: scale,
                      ),
                      _buildSummaryRow(
                        "Total Quantity",
                        totalQty.toStringAsFixed(1),
                        scale: scale,
                      ),
                      const Divider(height: 24),
                      _buildSummaryRow(
                        "Discount",
                        "-₹${totalDiscount.toStringAsFixed(2)}",
                        color: const Color(0xFFFF6B6B),
                        scale: scale,
                      ),
                      _buildSummaryRow(
                        "Tax Amount",
                        "₹${totalTaxAmount.toStringAsFixed(2)}",
                        color: const Color(0xFF4ECDC4),
                        scale: scale,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Container(
                          width: 275 * scale,
                          height: 70 * scale,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF667EEA).withOpacity(0.1),
                                const Color(0xFF764BA2).withOpacity(0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Total Amount",
                                style: TextStyle(
                                  fontSize: 14 * scale,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF333333),
                                ),
                              ),
                              Text(
                                "₹ ${totalAmountController.text.isEmpty ? '0.00' : totalAmountController.text}",
                                style: TextStyle(
                                  fontSize: 18 * scale,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF667EEA),
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
            const SizedBox(height: 30),

            if (isLoading)
              Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(const Color(0xFF667EEA)),
                ),
              )
            else
              Center(
                child: Container(
                  width: 280 * scale,
                  height: 50 * scale,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667EEA).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!_formKey.currentState!.validate()) return;

                      if (!isCustomerSelectedFromList) {
                        final isDuplicate = await isPhoneNumberDuplicate();
                        if (isDuplicate) {
                          AppSnackBar.showError(
                            context,
                            message:
                                "A customer with this phone number already exists!",
                            duration: const Duration(seconds: 2),
                          );
                          return;
                        }
                      }

                      if (selectedItems.isEmpty) {
                        AppSnackBar.showError(
                          context,
                          message: "Please add at least one item",
                          duration: const Duration(seconds: 2),
                        );
                        return;
                      }

                      saveSale();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save, color: Colors.white, size: 16 * scale),
                        const SizedBox(width: 10),
                        Text(
                          "SAVE SALE",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14 * scale,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    Color? color,
    double scale = 1.0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12 * scale),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? const Color(0xFF333333),
              fontSize: 14 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mobile-first: single column scrollable layout to avoid overflow on keyboard
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFF),
          appBar: AppBar(
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              "New Sale",
              style: TextStyle(color: Colors.white),
            ),
            centerTitle: true,
            elevation: 0,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height - kToolbarHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left column (form + items) - always shown first (mobile-first)
                      _leftColumn(context, constraints),
                      // give bottom space so floating keyboard/button won't overlap
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    customerController.dispose();
    productController.dispose();
    amountController.dispose();
    totalAmountController.dispose();
    receivedController.dispose();
    phoneController.dispose();
    super.dispose();
  }
}
