import 'dart:io';
import 'dart:ui';
import 'package:bizmate/services/rental_cart.dart';
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
    super.key,
    required this.rentalItem,
    required this.noOfDays,
    required this.ratePerDay,
    required this.totalAmount,
    this.fromDateTime,
    this.toDateTime,
  });

  @override
  State<RentalAddCustomerPage> createState() => _RentalAddCustomerPageState();
}

class _RentalAddCustomerPageState extends State<RentalAddCustomerPage> {
  List<Map<String, String>> customerList = [];
  bool isCustomerSelectedFromList = false;
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final discountPercentController = TextEditingController();
  final discountAmountController = TextEditingController();
  bool get _hasCustomers => customerList.isNotEmpty;
  double scale = 1.0;

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
  bool get _isRentalPeriodLocked =>
      widget.fromDateTime != null && widget.toDateTime != null;
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

  void _handleCustomerFieldTap() {
    if (!_hasCustomers) {
      AppSnackBar.showWarning(
        context,
        message: 'No customers found. Please add a customer first.',
        duration: const Duration(seconds: 2),
      );
      return; // ✅ stop here
    }

    showCustomerPicker(); // ✅ open picker only when customers exist
  }

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

  void showCustomerPicker() {
    if (!_hasCustomers) {
      AppSnackBar.showWarning(
        context,
        message: 'No customers found. Please add a customer first.',
        duration: const Duration(seconds: 2),
      );
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

        // ✅ SAME scaling logic — just clamped (NO visual change)
        double rs(double v) => (v * (width / 390)).clamp(v * 0.9, v * 1.15);

        int columns = 2;
        if (width >= 1200) {
          columns = 5;
        } else if (width >= 900) {
          columns = 4;
        } else if (width >= 600) {
          columns = 3;
        }

        final filteredCustomers = ValueNotifier<List<Map<String, String>>>(
          customerList,
        );

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: height * 0.85, // ✅ unchanged
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1A237E).withOpacity(0.98),
                  const Color(0xFF00BCD4).withOpacity(0.95),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 40,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Column(
              children: [
                // HEADER (UNCHANGED)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: rs(24),
                    vertical: rs(20),
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: const [Color(0xFF1A237E), Color(0xFF00BCD4)],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Select Customer",
                        style: TextStyle(
                          fontSize: rs(22),
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

                // BODY (UNCHANGED)
                Expanded(
                  child:
                      customerList.isEmpty
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.group_off,
                                  size: rs(40),
                                  color: Colors.white,
                                ),
                                SizedBox(height: rs(16)),
                                Text(
                                  "No Customers Found",
                                  style: TextStyle(
                                    fontSize: rs(18),
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                          : Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: rs(16),
                              vertical: rs(16),
                            ),
                            child: ValueListenableBuilder<
                              List<Map<String, String>>
                            >(
                              valueListenable: filteredCustomers,
                              builder: (context, list, _) {
                                return GridView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: list.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columns,
                                        crossAxisSpacing: rs(16),
                                        mainAxisSpacing: rs(16),
                                        childAspectRatio:
                                            width >= 600 ? 2.2 : 1.6,
                                      ),
                                  itemBuilder: (_, index) {
                                    final customer = list[index];
                                    final name = customer['name']!;
                                    final phone = customer['phone']!;
                                    final initials =
                                        name
                                            .split(' ')
                                            .where((e) => e.isNotEmpty)
                                            .map((e) => e[0])
                                            .take(2)
                                            .join()
                                            .toUpperCase();

                                    final color =
                                        _blueAquaColors[initials.codeUnits
                                                .reduce((a, b) => a + b) %
                                            _blueAquaColors.length];

                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          nameController.text = name;
                                          phoneController.text = phone;
                                          isCustomerSelectedFromList = true;
                                        });
                                        Navigator.pop(context);
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              color.withOpacity(0.9),
                                              color.withOpacity(0.7),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            rs(20),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: color.withOpacity(0.3),
                                              blurRadius: 15,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.3,
                                            ),
                                            width: 1.5,
                                          ),
                                        ),
                                        // ✅ inner layout unchanged
                                        padding: EdgeInsets.all(rs(16)),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              initials,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: rs(14),
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: rs(14),
                                              ),
                                            ),
                                            SizedBox(height: rs(4)),
                                            Text(
                                              phone,
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: rs(12),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
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
      // SESSION BOX
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

      // CUSTOMERS BOX
      if (!Hive.isBoxOpen('customers')) {
        await Hive.openBox<CustomerModel>('customers');
        if (!mounted) return;
      }
      customerBox = Hive.box<CustomerModel>('customers');

      // RENTAL SALES BOX
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
        );
      }
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }

    void loadCustomers() {
      try {
        List<CustomerModel> loaded = [];

        // 1️⃣ Load from user-specific box FIRST
        if (userBox != null && userBox!.containsKey("customers")) {
          loaded = List<CustomerModel>.from(
            userBox!.get("customers", defaultValue: []),
          );
        }

        // 2️⃣ Fallback to main customers box
        if (loaded.isEmpty) {
          loaded = customerBox.values.toList();
        }

        // 3️⃣ Deduplicate by phone (same logic as RentalCustomersPage)
        final Map<String, CustomerModel> unique = {};
        for (final c in loaded) {
          final key = c.phone.trim();

          if (!unique.containsKey(key) ||
              c.createdAt.isAfter(unique[key]!.createdAt)) {
            unique[key] = c;
          }
        }

        final cleanedList =
            unique.values.toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // 4️⃣ Convert to simple map list for your picker UI
        customerList =
            cleanedList.map((c) => {"name": c.name, "phone": c.phone}).toList();

        setState(() {});
      } catch (e) {
        debugPrint("Error loading customers: $e");
        customerList = [];
        setState(() {});
      }
    }

    loadCustomers();
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
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final summary = calculateSummary();

      // 1️⃣ SAVE CUSTOMER (ONCE)
      final newCustomer = CustomerModel(
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        createdAt: DateTime.now(),
      );

      await customerBox.add(newCustomer);

      if (userBox != null) {
        List<CustomerModel> list = List<CustomerModel>.from(
          userBox!.get("customers", defaultValue: []),
        );
        list.add(newCustomer);
        await userBox!.put("customers", list);
      }

      // 2️⃣ IF CART EMPTY → FALLBACK (OLD BEHAVIOR)
      if (RentalCart.isEmpty) {
        final rental = RentalSaleModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          customerName: newCustomer.name,
          customerPhone: newCustomer.phone,
          itemName: widget.rentalItem.name,
          ratePerDay: widget.ratePerDay,
          numberOfDays: widget.noOfDays,
          totalCost: summary['total']!,
          fromDateTime: fromDateTime!,
          toDateTime: toDateTime!,
          imageUrl: widget.rentalItem.imagePath,
        );

        await salesBox.add(rental);

        if (userBox != null) {
          List<RentalSaleModel> list = List<RentalSaleModel>.from(
            userBox!.get("rental_sales", defaultValue: []),
          );
          list.add(rental);
          await userBox!.put("rental_sales", list);
        }
      }

      // 3️⃣ SAVE MULTIPLE ITEMS (NEW FEATURE)
      for (final cartItem in RentalCart.items) {
        final sale = RentalSaleModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          customerName: newCustomer.name,
          customerPhone: newCustomer.phone,
          itemName: cartItem.item.name,
          ratePerDay: cartItem.ratePerDay,
          numberOfDays: cartItem.noOfDays,
          totalCost: cartItem.totalAmount,
          fromDateTime: cartItem.fromDateTime,
          toDateTime: cartItem.toDateTime,
          imageUrl: cartItem.item.imagePath,
        );

        await salesBox.add(sale);

        if (userBox != null) {
          List<RentalSaleModel> list = List<RentalSaleModel>.from(
            userBox!.get("rental_sales", defaultValue: []),
          );
          list.add(sale);
          await userBox!.put("rental_sales", list);
        }
      }

      RentalCart.clear();

      AppSnackBar.showSuccess(context, message: "Rental saved successfully");

      Navigator.pop(context, true);
    } catch (e) {
      AppSnackBar.showError(context, message: "Failed to save rental");
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final double localScale =
            (constraints.maxWidth / 390).clamp(0.9, 1.2) * scale;

        // 🔑 ONLY for Discount fields
        final bool isCompact =
            icon == Icons.percent || icon == Icons.currency_rupee;

        return Container(
          margin: EdgeInsets.symmetric(vertical: 8 * localScale),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18 * localScale),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.16),
                Colors.white.withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 14 * localScale,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            onTap: onTap,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12 * localScale,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
            decoration: InputDecoration(
              isDense: true,
              labelText: label,
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              labelStyle: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w600,
                fontSize: 13 * localScale,
              ),

              // ICON
              prefixIcon: Icon(
                icon,
                size: 18 * localScale,
                color: Colors.white.withOpacity(0.85),
              ),

              // 🔥 SHRINK icon box ONLY for these 2 fields
              prefixIconConstraints: BoxConstraints(
                minWidth: isCompact ? 30 * localScale : 42 * localScale,
                minHeight: 28 * localScale,
              ),

              // 🔥 Reduce space between icon & text ONLY here
              contentPadding: EdgeInsets.fromLTRB(
                isCompact ? 6 * localScale : 16 * localScale,
                14 * localScale,
                16 * localScale,
                14 * localScale,
              ),

              suffixText: suffixText,
              suffixStyle: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11 * localScale,
                fontWeight: FontWeight.w600,
              ),

              prefixText: prefixText,
              prefixStyle: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11 * localScale,
                fontWeight: FontWeight.w600,
              ),

              border: InputBorder.none,
            ),
            onChanged: (value) {
              if (label == "Customer Name" && value.isNotEmpty) {
                final cursorPosition = controller.selection.baseOffset;
                final formatted =
                    value[0].toUpperCase() +
                    (value.length > 1 ? value.substring(1) : '');

                if (formatted != value) {
                  controller.value = controller.value.copyWith(
                    text: formatted,
                    selection: TextSelection.collapsed(
                      offset: cursorPosition.clamp(0, formatted.length),
                    ),
                  );
                }
              }
              setState(() {});
            },
          ),
        );
      },
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
        initialValue: value,
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
        height: 50 * scale,
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
            onTap:
                _isRentalPeriodLocked
                    ? null
                    : () => _selectDateTime(context, isFrom),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10 * scale),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: Colors.white.withOpacity(0.8),
                    size: 14 * scale,
                  ),
                  SizedBox(width: 10 * scale),
                  Expanded(
                    child: Text(
                      dateTime == null
                          ? "Select $label Date"
                          : _formatDateTime(dateTime),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 10 * scale,
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
    final cartItems = RentalCart.items;
    final bool hasMultipleItems = cartItems.length > 1;

    return Container(
      padding: EdgeInsets.all(16 * scale),
      margin: EdgeInsets.only(bottom: 16 * scale),
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
          // HEADER
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6 * scale),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 16 * scale,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Rental Summary",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          SizedBox(height: 12 * scale),

          // ================= SINGLE ITEM =================
          if (cartItems.isEmpty) ...[
            _buildInfoRow("Item Name", widget.rentalItem.name),
            _buildInfoRow("No. of Days", "${widget.noOfDays} days"),
            _buildInfoRow(
              "Rate / Day",
              "₹${widget.ratePerDay.toStringAsFixed(2)}",
            ),
          ]
          // ================= MULTIPLE ITEMS (SCROLLABLE) =================
          else ...[
            Text(
              "Items (${cartItems.length})",
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            // 🔥 SCROLL AREA START
            SizedBox(
              height:
                  hasMultipleItems ? 180 : null, // 👈 controls scroll height
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children:
                      cartItems.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow("Item", item.item.name),
                              _buildInfoRow(
                                "Rate / Day",
                                "₹${item.ratePerDay.toStringAsFixed(2)}",
                              ),
                              _buildInfoRow("Days", "${item.noOfDays}"),
                              _buildInfoRow(
                                "Item Total",
                                "₹${item.totalAmount.toStringAsFixed(2)}",
                              ),
                              const Divider(color: Colors.white30),
                            ],
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),
            // 🔥 SCROLL AREA END
          ],

          // ================= TOTALS =================
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
      padding: EdgeInsets.all(16 * scale),
      margin: EdgeInsets.only(bottom: 16 * scale),
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
                padding: EdgeInsets.all(6 * scale),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.percent,
                  color: Colors.white,
                  size: 16 * scale,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Discount & Tax",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12 * scale),

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
              SizedBox(width: 12 * scale),
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
          SizedBox(height: 12 * scale),

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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "Complete Rental",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          icon: Container(
            width: 30 * scale,
            height: 30 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 20 * scale,
            ),
          ),
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
              child: AbsorbPointer(
                absorbing: _isSaving,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // Header
                        Container(
                          padding: EdgeInsets.all(16 * scale),
                          margin: EdgeInsets.only(bottom: 16 * scale),
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
                                  fontSize: 24 * scale,
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
                                  fontSize: 12 * scale,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        // Image Section
                        Container(
                          margin: EdgeInsets.only(bottom: 16 * scale),
                          height: 170 * scale,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20 * scale),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF1A237E), // Deep Blue
                                Color(0xFF00BCD4), // Aqua
                                Color(0xFF4DD0E1), // Soft Mint / Cyan
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),

                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20 * scale,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20 * scale),
                            child:
                                RentalCart.items.length <= 1
                                    // ================= SINGLE ITEM (UNCHANGED UI) =================
                                    ? Stack(
                                      children: [
                                        Positioned.fill(
                                          child:
                                              item.imagePath.isNotEmpty &&
                                                      File(
                                                        item.imagePath,
                                                      ).existsSync()
                                                  ? Image.file(
                                                    File(item.imagePath),
                                                    fit: BoxFit.cover,
                                                  )
                                                  : Center(
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .image_not_supported,
                                                          size: 60 * scale,
                                                          color: Colors.white
                                                              .withOpacity(0.6),
                                                        ),
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        Text(
                                                          "No Image",
                                                          style: TextStyle(
                                                            color: Colors.white
                                                                .withOpacity(
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

                                        // Item Name
                                        Positioned(
                                          bottom: 12,
                                          left: 16,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 10 * scale,
                                              vertical: 4 * scale,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(
                                                  0.3,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              item.name,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10 * scale,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                    // ================= MULTIPLE ITEMS =================
                                    : ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: RentalCart.items.length,
                                      itemBuilder: (context, index) {
                                        final cartItem =
                                            RentalCart.items[index];

                                        return Stack(
                                          children: [
                                            Container(
                                              width: 200 * scale,
                                              margin: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child:
                                                  cartItem
                                                              .item
                                                              .imagePath
                                                              .isNotEmpty &&
                                                          File(
                                                            cartItem
                                                                .item
                                                                .imagePath,
                                                          ).existsSync()
                                                      ? Image.file(
                                                        File(
                                                          cartItem
                                                              .item
                                                              .imagePath,
                                                        ),
                                                        fit: BoxFit.cover,
                                                      )
                                                      : Center(
                                                        child: Icon(
                                                          Icons
                                                              .image_not_supported,
                                                          size: 50,
                                                          color: Colors.white
                                                              .withOpacity(0.6),
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
                                                  gradient: LinearGradient(
                                                    begin:
                                                        Alignment.bottomCenter,
                                                    end: Alignment.topCenter,
                                                    colors: [
                                                      Colors.black.withOpacity(
                                                        0.6,
                                                      ),
                                                      Colors.transparent,
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // Item Name Badge
                                            Positioned(
                                              bottom: 12,
                                              left: 12,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 10 * scale,
                                                  vertical: 4 * scale,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withOpacity(0.3),
                                                  ),
                                                ),
                                                child: Text(
                                                  cartItem.item.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10 * scale,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                          ),
                        ),

                        // Customer Details Card
                        Container(
                          padding: EdgeInsets.all(16 * scale),
                          margin: EdgeInsets.only(bottom: 16 * scale),
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
                                    padding: EdgeInsets.all(6 * scale),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.person_outline,
                                      color: Colors.white,
                                      size: 16 * scale,
                                    ),
                                  ),
                                  SizedBox(width: 12 * scale),
                                  Text(
                                    "Customer Details",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14 * scale,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12 * scale),
                              _buildGlassTextField(
                                label: "Customer Name",
                                icon: Icons.person,
                                controller: nameController,
                                validator:
                                    (value) =>
                                        value == null || value.trim().isEmpty
                                            ? "Please enter customer name"
                                            : null,
                                keyboardType: TextInputType.name,
                                onTap: _handleCustomerFieldTap,
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
                          padding: EdgeInsets.all(16 * scale),
                          margin: EdgeInsets.only(bottom: 16 * scale),
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
                                    padding: EdgeInsets.all(6 * scale),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.calendar_today,
                                      color: Colors.white,
                                      size: 16 * scale,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Rental Period",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14 * scale,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12 * scale),
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
                        SizedBox(height: 25 * scale),

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
                                            : "Confirm Rental",
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
                        SizedBox(height: 10 * scale),
                      ],
                    ),
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

// Add this array of blue/aqua theme colors for avatar backgrounds
final List<Color> _blueAquaColors = [
  const Color(0xFF1A237E), // Deep Blue (Primary from your page)
  const Color(0xFF283593), // Dark Blue
  const Color(0xFF303F9F), // Blue
  const Color(0xFF3949AB), // Light Blue
  const Color(0xFF3F51B5), // Primary Blue
  const Color(0xFF5C6BC0), // Light Blue
  const Color(0xFF00BCD4), // Aqua Blue (Secondary from your page)
  const Color(0xFF00ACC1), // Dark Aqua
  const Color(0xFF0097A7), // Deep Aqua
  const Color(0xFF00838F), // Very Dark Aqua
  const Color(0xFF006064), // Teal
  const Color(0xFF4DD0E1), // Light Cyan
  const Color(0xFF26C6DA), // Cyan
  const Color(0xFF00B8D4), // Bright Aqua
  const Color(0xFF0091EA), // Light Blue
  const Color(0xFF2962FF), // Electric Blue
];

// Custom painter for card background pattern
class CustomerCardPatternPainter extends CustomPainter {
  final Color color;

  CustomerCardPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color.withOpacity(0.3)
          ..style = PaintingStyle.fill;

    const circleSize = 60.0;
    final rows = (size.height / circleSize).ceil();
    final columns = (size.width / circleSize).ceil();

    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < columns; j++) {
        final x = j * circleSize;
        final y = i * circleSize;

        if ((i + j) % 3 == 0) {
          canvas.drawCircle(
            Offset(x + circleSize / 2, y + circleSize / 2),
            circleSize / 8,
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
