import 'dart:io';
import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../../models/customer_model.dart';
import '../../../models/rental_sale_model.dart';
import '../../../models/rental_item.dart';

class RentalAddCustomerPage extends StatefulWidget {
  final RentalItem rentalItem;
  final int noOfDays;
  final double ratePerDay;
  final double totalAmount;
  final DateTime? fromDateTime;
  final DateTime? toDateTime;

  const RentalAddCustomerPage({
    Key? key,
    required this.rentalItem,
    required this.noOfDays,
    required this.ratePerDay,
    required this.totalAmount,
    this.fromDateTime,
    this.toDateTime,
  }) : super(key: key);

  @override
  State<RentalAddCustomerPage> createState() => _RentalAddCustomerPageState();
}

class _RentalAddCustomerPageState extends State<RentalAddCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final discountPercentController = TextEditingController();
  final discountAmountController = TextEditingController();

  DateTime? fromDateTime;
  DateTime? toDateTime;

  late Box<CustomerModel> customerBox;
  late Box<RentalSaleModel> salesBox;
  Box? userBox; // User-specific box reference

  bool _isLoading = true;
  bool _isSaving = false;
  bool isEditingPercent = true;
  String selectedTaxType = 'Without Tax';
  String? selectedTaxRate;

  final List<String> taxChoiceOptions = ['With Tax', 'Without Tax'];
  final List<String> taxRateOptions = [
    'None',
    'Exempted',
    'GST@0.0%',
    'IGST@0.0%',
    'GST@0.25%',
    'IGST@0.25%',
    'GST@3.0%',
    'IGST@3.0%',
    'GST@5.0%',
    'IGST@5.0%',
    'GST@12.0%',
    'IGST@12.0%',
    'GST@18.0%',
    'IGST@18.0%',
    'GST@28.0%',
    'IGST@28.0%',
  ];

  @override
  void initState() {
    super.initState();
    fromDateTime = widget.fromDateTime;
    toDateTime = widget.toDateTime;
    _initBoxes();
  }

  double parseTaxRate() {
    if (selectedTaxRate == null || !selectedTaxRate!.contains('%')) return 0;
    return double.tryParse(
          selectedTaxRate!.replaceAll(RegExp(r'[^\d.]'), ''),
        ) ??
        0;
  }

  Map<String, double> calculateSummary() {
    final subtotal = widget.totalAmount;
    final discountPercent =
        isEditingPercent
            ? (double.tryParse(discountPercentController.text) ?? 0.0)
            : 0.0;
    final discountAmount =
        !isEditingPercent
            ? (double.tryParse(discountAmountController.text) ?? 0.0)
            : 0.0;

    final taxPercent = parseTaxRate();
    final taxType = selectedTaxType;

    double taxAmount = 0.0;
    double calculatedDiscountAmount = 0.0;
    double totalAmount = 0.0;

    if (taxType == 'With Tax' && taxPercent > 0) {
      // Tax-inclusive: totalAmount includes tax
      final taxableAmountBeforeDiscount = subtotal;
      calculatedDiscountAmount =
          isEditingPercent
              ? (taxableAmountBeforeDiscount * discountPercent / 100).toDouble()
              : discountAmount;

      final taxableAmount =
          taxableAmountBeforeDiscount - calculatedDiscountAmount;

      taxAmount =
          calculatedDiscountAmount >= taxableAmountBeforeDiscount
              ? 0.0
              : (taxableAmount * taxPercent / 100).toDouble();

      totalAmount = taxableAmount + taxAmount;
    } else {
      // Tax-exclusive or Without Tax
      calculatedDiscountAmount =
          isEditingPercent
              ? (subtotal * discountPercent / 100).toDouble()
              : discountAmount > subtotal
              ? subtotal
              : discountAmount;

      final taxableAmount = subtotal - calculatedDiscountAmount;

      taxAmount =
          taxPercent > 0 ? (taxableAmount * taxPercent / 100).toDouble() : 0.0;

      totalAmount = taxableAmount + taxAmount;
    }

    // Update controllers for real-time UI sync
    if (isEditingPercent) {
      discountAmountController.text = calculatedDiscountAmount.toStringAsFixed(
        2,
      );
    } else {
      discountPercentController.text =
          subtotal > 0
              ? ((calculatedDiscountAmount / subtotal) * 100).toStringAsFixed(2)
              : '0.00';
    }

    return {
      'subtotal': subtotal,
      'discountAmount': calculatedDiscountAmount,
      'taxAmount': taxAmount,
      'total': totalAmount,
    };
  }

  Future<void> _initBoxes() async {
    try {
      // Initialize session box
      if (!Hive.isBoxOpen('session')) {
        await Hive.openBox('session');
        if (!mounted) return;
      }

      final sessionBox = Hive.box('session');
      final email = sessionBox.get("currentUserEmail");

      if (email != null) {
        final safeEmail = email
            .toString()
            .replaceAll('.', '_')
            .replaceAll('@', '_');

        if (!Hive.isBoxOpen("userdata_$safeEmail")) {
          await Hive.openBox("userdata_$safeEmail");
          if (!mounted) return;
        }

        userBox = Hive.box("userdata_$safeEmail");
      }

      // Customers box
      if (!Hive.isBoxOpen('customers')) {
        await Hive.openBox<CustomerModel>('customers');
        if (!mounted) return;
      }

      customerBox = Hive.box<CustomerModel>('customers');

      // Rental sales box
      if (!Hive.isBoxOpen('rental_sales')) {
        await Hive.openBox<RentalSaleModel>('rental_sales');
        if (!mounted) return;
      }

      salesBox = Hive.box<RentalSaleModel>('rental_sales');
    } catch (e) {
      debugPrint('Error initializing Hive boxes: $e');

      if (mounted) {
        AppSnackBar.showError(
          context,
          message: 'Error initializing database: $e',
          duration: Duration(seconds: 2),
        );
      }
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateTime(BuildContext context, bool isFrom) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time == null) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isFrom) {
        fromDateTime = selected;
      } else {
        toDateTime = selected;
      }
    });
  }

  // Fixed validator functions
  String? _validateDiscountPercent(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final percent = double.tryParse(value);
    if (percent == null || percent < 0 || percent > 100) {
      return 'Enter 0-100%';
    }
    return null;
  }

  String? _validateDiscountAmount(String? value) {
    final summary = calculateSummary();
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final amount = double.tryParse(value);
    if (amount == null || amount < 0) {
      return 'Invalid amount';
    }
    if (amount > summary['subtotal']!) {
      return 'Cannot exceed subtotal';
    }
    return null;
  }

  Future<void> saveCustomerAndSale() async {
    if (!_formKey.currentState!.validate()) return;
    if (fromDateTime == null || toDateTime == null) {
      AppSnackBar.showWarning(
        context,
        message: 'Please select both From & To dates',
        duration: Duration(seconds: 2),
      );
      return;
    }
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final summary = calculateSummary();

      // Save customer to user-specific box if available
      final newCustomer = CustomerModel(
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        createdAt: DateTime.now(),
      );

      // Save to both boxes for compatibility
      await customerBox.add(newCustomer);

      // Also save to user-specific box if available
      if (userBox != null) {
        List<CustomerModel> userCustomers = [];
        try {
          userCustomers = List<CustomerModel>.from(
            userBox!.get("customers", defaultValue: []),
          );
        } catch (_) {
          userCustomers = [];
        }
        userCustomers.add(newCustomer);
        await userBox!.put("customers", userCustomers);
      }

      // Save rental sale - using only existing parameters
      final newRental = RentalSaleModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        customerName: nameController.text.trim(),
        customerPhone: phoneController.text.trim(),
        itemName: widget.rentalItem.name,
        ratePerDay: widget.ratePerDay,
        numberOfDays: widget.noOfDays,
        totalCost: summary['total']!, // Use calculated total with discount/tax
        fromDateTime: fromDateTime!,
        toDateTime: toDateTime!,
        imageUrl: widget.rentalItem.imagePath,
      );

      // Save to both boxes for compatibility
      await salesBox.add(newRental);

      // Also save to user-specific box if available
      if (userBox != null) {
        List<RentalSaleModel> userRentalSales = [];
        try {
          userRentalSales = List<RentalSaleModel>.from(
            userBox!.get("rental_sales", defaultValue: []),
          );
        } catch (_) {
          userRentalSales = [];
        }
        userRentalSales.add(newRental);
        await userBox!.put("rental_sales", userRentalSales);
      }

      AppSnackBar.showSuccess(
        context,
        message: 'Sale and customer saved successfully!',
        duration: Duration(seconds: 2),
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error saving sale: $e');
      AppSnackBar.showError(
        context,
        message: 'Failed to save data: $e',
        duration: Duration(seconds: 2),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.day}/${dateTime.month}/${dateTime.year} "
        "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildGlassTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    VoidCallback? onTap,
    String? suffixText,
    String? prefixText,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        onTap: onTap,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.8)),
          suffixText: suffixText,
          prefixText: prefixText,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
        validator: validator,
        onChanged: (value) {
          if (label == "Customer Name" && value.isNotEmpty) {
            final formatted = value[0].toUpperCase() + value.substring(1);
            if (formatted != value) {
              controller.value = controller.value.copyWith(
                text: formatted,
                selection: TextSelection.collapsed(offset: formatted.length),
              );
            }
          }
          setState(() {});
        },
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> options,
    Function(String?) onChanged, {
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        dropdownColor: const Color(0xFF1A237E),
        style: const TextStyle(color: Colors.white),
        icon: Icon(Icons.arrow_drop_down, color: Colors.white.withOpacity(0.8)),
        items:
            options
                .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                .toList(),
        onChanged: enabled ? onChanged : null,
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeButton(bool isFrom) {
    final dateTime = isFrom ? fromDateTime : toDateTime;
    final label = isFrom ? "From" : "To";
    final icon = isFrom ? Icons.calendar_today : Icons.calendar_month;

    return Expanded(
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => _selectDateTime(context, isFrom),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      dateTime == null
                          ? "Select $label Date"
                          : _formatDateTime(dateTime),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRentalInfoCard() {
    final summary = calculateSummary();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Rental Summary",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow("Item Name", widget.rentalItem.name),
          _buildInfoRow("No. of Days", "${widget.noOfDays} days"),
          _buildInfoRow("Rate/Day", "₹${widget.ratePerDay.toStringAsFixed(2)}"),
          const Divider(color: Colors.white30, height: 20),
          _buildInfoRow(
            "Subtotal",
            "₹${summary['subtotal']!.toStringAsFixed(2)}",
          ),
          _buildInfoRow(
            "Discount",
            "-₹${summary['discountAmount']!.toStringAsFixed(2)}",
          ),
          if (summary['taxAmount']! > 0)
            _buildInfoRow(
              "Tax",
              "+₹${summary['taxAmount']!.toStringAsFixed(2)}",
            ),
          const Divider(color: Colors.white30, height: 20),
          _buildInfoRow(
            "Total Cost",
            "₹${summary['total']!.toStringAsFixed(2)}",
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isTotal ? Colors.amber : Colors.white,
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountTaxSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.percent, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                "Discount & Tax",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Discount Section
          Row(
            children: [
              Expanded(
                child: _buildGlassTextField(
                  label: "Discount %",
                  icon: Icons.percent,
                  controller: discountPercentController,
                  suffixText: "%",
                  onTap: () => setState(() => isEditingPercent = true),
                  validator: isEditingPercent ? _validateDiscountPercent : null,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGlassTextField(
                  label: "Discount ₹",
                  icon: Icons.currency_rupee,
                  controller: discountAmountController,
                  prefixText: "₹ ",
                  onTap: () => setState(() => isEditingPercent = false),
                  validator: !isEditingPercent ? _validateDiscountAmount : null,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tax Type
          _buildDropdown(
            "Tax Type",
            selectedTaxType,
            taxChoiceOptions,
            (val) => setState(() => selectedTaxType = val!),
          ),
          const SizedBox(height: 12),

          // Tax Rate
          IgnorePointer(
            ignoring: selectedTaxType != 'With Tax',
            child: Opacity(
              opacity: selectedTaxType == 'With Tax' ? 1.0 : 0.4,
              child: _buildDropdown(
                "Select Tax Rate",
                selectedTaxRate,
                taxRateOptions,
                (val) => setState(() => selectedTaxRate = val),
                enabled: selectedTaxType == 'With Tax',
              ),
            ),
          ),

          // Tax Info Cards
          if (selectedTaxType == 'With Tax' && parseTaxRate() > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    "Tax Rate",
                    "${parseTaxRate().toStringAsFixed(2)}%",
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    "Tax Amount",
                    "₹ ${calculateSummary()['taxAmount']!.toStringAsFixed(2)}",
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.rentalItem;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Complete Rental",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1A237E), // Deep blue
                  Color(0xFF00BCD4), // Light aqua blue
                ],

                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CustomPaint(painter: _BackgroundPatternPainter()),
          ),

          // Content
          if (_isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.2),
                          Colors.white.withOpacity(0.1),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Loading...",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Header
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.15),
                              Colors.white.withOpacity(0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Rental Agreement",
                              style: TextStyle(
                                fontSize: size.width * 0.065,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Complete customer details to finalize rental",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      // Image Section
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1A237E), Color(0xFF00BCD4)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Image or Placeholder
                            Positioned.fill(
                              child:
                                  item.imagePath.isNotEmpty &&
                                          File(item.imagePath).existsSync()
                                      ? ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Image.file(
                                          File(item.imagePath),
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                      : Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.image_not_supported,
                                              size: 60,
                                              color: Colors.white.withOpacity(
                                                0.6,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              "No Image",
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(
                                                  0.6,
                                                ),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                            ),

                            // Overlay
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(20),
                                    bottomRight: Radius.circular(20),
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.6),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Item Name Badge
                            Positioned(
                              bottom: 12,
                              left: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  item.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Customer Details Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.15),
                              Colors.white.withOpacity(0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.person_outline,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  "Customer Details",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildGlassTextField(
                              label: "Customer Name",
                              icon: Icons.person,
                              controller: nameController,
                              validator:
                                  (value) =>
                                      value == null || value.trim().isEmpty
                                          ? "Please enter customer name"
                                          : null,
                              // ⭐ NEW: Auto-capitalize first letter
                              keyboardType: TextInputType.name,
                              onTap: () {}, // keep existing
                            ),
                            _buildGlassTextField(
                              label: "Phone Number",
                              icon: Icons.phone,
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Please enter phone number";
                                } else if (value.trim().length != 10) {
                                  return "Enter a valid 10-digit phone number";
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                      // Date Time Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.15),
                              Colors.white.withOpacity(0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_today,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  "Rental Period",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _buildDateTimeButton(true),
                                const SizedBox(width: 12),
                                _buildDateTimeButton(false),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Discount & Tax Section
                      _buildDiscountTaxSection(),

                      // Rental Summary
                      _buildRentalInfoCard(),
                      const SizedBox(height: 30),

                      // Save Button
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        transform:
                            _isSaving
                                ? (Matrix4.identity()..scale(0.95))
                                : Matrix4.identity(),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors:
                                  _isSaving
                                      ? [Colors.grey, Colors.grey.shade600]
                                      : [Colors.white, Colors.white70],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    _isSaving
                                        ? Colors.grey.withOpacity(0.5)
                                        : Colors.white.withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              onTap: _isSaving ? null : saveCustomerAndSale,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                  horizontal: 40,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_isSaving)
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.grey.shade700,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.save_alt,
                                        color: Color(0xFF1A237E),
                                        size: 22,
                                      ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _isSaving
                                          ? "Saving..."
                                          : "Complete Rental",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color:
                                            _isSaving
                                                ? Colors.grey.shade700
                                                : const Color(0xFF1A237E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white.withOpacity(0.03)
          ..style = PaintingStyle.fill;

    const circleSize = 80.0;
    final rows = (size.height / circleSize).ceil();
    final columns = (size.width / circleSize).ceil();

    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < columns; j++) {
        final x = j * circleSize;
        final y = i * circleSize;

        if ((i + j) % 2 == 0) {
          canvas.drawCircle(
            Offset(x + circleSize / 2, y + circleSize / 2),
            circleSize / 4,
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
