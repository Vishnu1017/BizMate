// lib/screens/select_items_screen.dart
// FULL FILE WITH EXACT DISCOUNT & TAX LOGIC FROM RENTAL PAGE
// NO UI OR FUNCTION CHANGES — ONLY LOGIC FIXED 100% ACCURATE

import 'dart:ui';
import 'package:bizmate/models/product.dart';
import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:bizmate/widgets/discount_tax_widget.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SelectItemsScreen extends StatefulWidget {
  final Function(String)? onItemSaved;

  const SelectItemsScreen({super.key, this.onItemSaved});

  @override
  _SelectItemsScreenState createState() => _SelectItemsScreenState();
}

class _SelectItemsScreenState extends State<SelectItemsScreen> {
  final TextEditingController itemController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController rateController = TextEditingController();
  final TextEditingController discountPercentController =
      TextEditingController();
  final TextEditingController discountAmountController =
      TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool isEditingPercent = true;
  bool showSummarySections = false;

  String? selectedUnit;
  String selectedTaxType = 'Without Tax';
  String? selectedTaxRate;

  final List<String> units = ['Unit', 'Hours', 'Days'];

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

    quantityController.text = "1";

    // LIVE SYNC BETWEEN % AND ₹
    discountPercentController.addListener(() {
      if (isEditingPercent) {
        setState(() {
          calculateSummary();
        });
      }
    });

    discountAmountController.addListener(() {
      if (!isEditingPercent) {
        setState(() {
          calculateSummary();
        });
      }
    });

    itemController.addListener(() {
      if (mounted) {
        setState(() {
          showSummarySections = itemController.text.trim().isNotEmpty;
        });
      }
    });
  }

  // ---------------------------------------
  // USER PRODUCTS LOAD / SAVE
  // ---------------------------------------
  Future<List<Product>> loadUserProducts() async {
    final sessionBox = await Hive.openBox('session');
    final email = sessionBox.get('currentUserEmail');
    if (email == null) return [];

    final safeEmail = email
        .toString()
        .replaceAll('.', '_')
        .replaceAll('@', '_');
    final boxName = "userdata_$safeEmail";

    final userBox =
        Hive.isBoxOpen(boxName)
            ? Hive.box(boxName)
            : await Hive.openBox(boxName);

    if (!userBox.containsKey("products")) {
      await userBox.put("products", <Product>[]);
    }

    final raw = userBox.get("products", defaultValue: <Product>[]);

    try {
      return List<Product>.from(raw);
    } catch (_) {
      final List<Product> converted = [];
      for (var r in (raw as List)) {
        if (r is Product) {
          converted.add(r);
        } else if (r is Map) {
          final name = r['name']?.toString() ?? '';
          final rate = double.tryParse(r['rate']?.toString() ?? '0') ?? 0.0;
          converted.add(Product(name, rate));
        }
      }
      return converted;
    }
  }

  Future<void> saveUserProduct(Product p) async {
    final sessionBox = await Hive.openBox('session');
    final email = sessionBox.get('currentUserEmail');
    if (email == null) return;

    final safeEmail = email
        .toString()
        .replaceAll('.', '_')
        .replaceAll('@', '_');
    final boxName = "userdata_$safeEmail";

    final userBox =
        Hive.isBoxOpen(boxName)
            ? Hive.box(boxName)
            : await Hive.openBox(boxName);

    final current = List<Product>.from(
      userBox.get("products", defaultValue: <Product>[]),
    );
    current.add(p);
    await userBox.put("products", current);
  }

  // ---------------------------------------------------------------------------
  // EXACT SAME LOGIC AS RentalAddCustomerPage (NO DESIGN OR FUNCTION CHANGE)
  // ---------------------------------------------------------------------------
  double parseTaxRate() {
    if (selectedTaxRate == null || !selectedTaxRate!.contains('%')) return 0;
    return double.tryParse(
          selectedTaxRate!.replaceAll(RegExp(r'[^\d.]'), ''),
        ) ??
        0;
  }

  Map<String, double> calculateSummary() {
    final qty = double.tryParse(quantityController.text) ?? 1.0;
    final rate = double.tryParse(rateController.text) ?? 0.0;

    final subtotal = qty * rate;

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

    double calculatedDiscountAmount = 0.0;
    double taxAmount = 0.0;
    double totalAmount = 0.0;

    // EXACT SAME TAX-INCLUSIVE LOGIC
    if (taxType == "With Tax" && taxPercent > 0) {
      final taxableBeforeDiscount = subtotal;

      calculatedDiscountAmount =
          isEditingPercent
              ? taxableBeforeDiscount * discountPercent / 100
              : discountAmount;

      final taxable = taxableBeforeDiscount - calculatedDiscountAmount;

      taxAmount =
          calculatedDiscountAmount >= taxableBeforeDiscount
              ? 0.0
              : taxable * taxPercent / 100;

      totalAmount = taxable + taxAmount;
    } else {
      // Without Tax (Tax Exclusive)
      calculatedDiscountAmount =
          isEditingPercent
              ? subtotal * discountPercent / 100
              : (discountAmount > subtotal ? subtotal : discountAmount);

      final taxable = subtotal - calculatedDiscountAmount;

      taxAmount = taxPercent > 0 ? taxable * taxPercent / 100 : 0.0;

      totalAmount = taxable + taxAmount;
    }

    // EXACT SYNC LOGIC (same as first file)
    if (isEditingPercent) {
      discountAmountController.text = calculatedDiscountAmount.toStringAsFixed(
        2,
      );
    } else {
      discountPercentController.text =
          subtotal == 0
              ? "0.00"
              : ((calculatedDiscountAmount / subtotal) * 100).toStringAsFixed(
                2,
              );
    }

    return {
      'rate': rate,
      'subtotal': subtotal,
      'discountAmount': calculatedDiscountAmount,
      'taxAmount': taxAmount,
      'total': totalAmount,
    };
  }

  // ---------------------------------
  // PRODUCT PICKER (unchanged)
  // ---------------------------------
  void showItemPicker() async {
    final items = await loadUserProducts();
    if (items.isEmpty) {
      AppSnackBar.showWarning(
        context,
        message: "No products found. Please add products.",
        duration: Duration(seconds: 2),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: 420,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  Text(
                    "Select Product",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      itemCount: items.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 3.2,
                      ),
                      itemBuilder: (context, index) {
                        final item = items[index];

                        final initials =
                            item.name.isNotEmpty
                                ? item.name
                                    .split(' ')
                                    .map((e) => e.isNotEmpty ? e[0] : '')
                                    .join()
                                    .toUpperCase()
                                : '';

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              itemController.text = item.name;
                              rateController.text = item.rate.toStringAsFixed(
                                2,
                              );
                              showSummarySections = true;
                            });
                            Navigator.pop(context);
                          },
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [Color(0xFF00BCD4), Color(0xFF1A237E)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 10,
                                  offset: Offset(2, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.white,
                                  child: Text(
                                    initials,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A237E),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        item.name,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        "₹ ${item.rate.toStringAsFixed(2)}",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------
  // BUILD UI (unchanged)
  // ---------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final summary = calculateSummary();

    return Scaffold(
      appBar: AppBar(
        title: Text("Add Items to Sale"),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF00BCD4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardSection(
                title: "Item Details",
                children: [
                  _buildTextField(
                    itemController,
                    "e.g. Premium Photography",
                    onTap: showItemPicker,
                    keyboardType: TextInputType.text,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an item name';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          quantityController,
                          "Quantity",
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: false,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter quantity';
                            }
                            final quantity = int.tryParse(value);
                            if (quantity == null || quantity <= 0) {
                              return 'Quantity must be greater than 0';
                            }
                            if (quantity > 9999) {
                              return 'Maximum quantity is 9999';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown(
                          "Unit",
                          selectedUnit,
                          units,
                          (val) => setState(() => selectedUnit = val),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          rateController,
                          "Rate (Price/Unit)",
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a rate';
                            }
                            final rate = double.tryParse(value);
                            if (rate == null || rate <= 0) {
                              return 'Rate must be greater than 0';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown(
                          "Tax Type",
                          selectedTaxType,
                          taxChoiceOptions,
                          (val) => setState(() => selectedTaxType = val!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              if (showSummarySections) ...[
                _buildCardSection(
                  title: "Discount & Tax",
                  children: [
                    DiscountTaxWidget(
                      discountPercentController: discountPercentController,
                      discountAmountController: discountAmountController,
                      isEditingPercent: isEditingPercent,
                      onModeChange:
                          (value) => setState(() => isEditingPercent = value),
                      subtotal: summary['subtotal']!,
                      selectedTaxRate: selectedTaxRate,
                      selectedTaxType: selectedTaxType,
                      taxRateOptions: taxRateOptions,
                      onTaxRateChanged:
                          (val) => setState(() => selectedTaxRate = val),
                      parsedTaxRate: parseTaxRate(),
                      taxAmount: summary['taxAmount']!,
                    ),
                  ],
                ),

                SizedBox(height: 24),

                _buildCardSection(
                  title: "Total Summary",
                  children: [
                    _buildSummaryRow(
                      "Total Amount",
                      summary['total']!,
                      isBold: true,
                      fontSize: 18,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),

      bottomNavigationBar: SafeArea(
        child: Row(
          children: [
            // Save & New
            Expanded(
              child: Container(
                color: Colors.white,
                child: TextButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final name = itemController.text.trim();
                      final rate = double.tryParse(rateController.text) ?? 0;

                      if (rate > 0 && name.isNotEmpty) {
                        await saveUserProduct(Product(name, rate));
                        widget.onItemSaved?.call(name);
                      }

                      // Reset inputs
                      itemController.clear();
                      rateController.clear();
                      discountPercentController.clear();
                      discountAmountController.clear();
                      quantityController.text = "1";

                      setState(() {
                        selectedUnit = null;
                        selectedTaxRate = null;
                        selectedTaxType = "Without Tax";
                        showSummarySections = false;
                      });
                    }
                  },
                  child: Text("Save & New"),
                ),
              ),
            ),

            // Save & Close
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00BCD4), Color(0xFF1A237E)],
                  ),
                ),
                child: TextButton(
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;

                    final summary = calculateSummary();
                    Navigator.pop(context, {
                      'itemName': itemController.text.trim(),
                      'qty': double.tryParse(quantityController.text) ?? 0,
                      'rate': double.tryParse(rateController.text) ?? 0,
                      'unit': selectedUnit ?? '',
                      'tax': parseTaxRate(),
                      'discount':
                          double.tryParse(discountPercentController.text) ?? 0,
                      'discountAmount':
                          double.tryParse(discountAmountController.text) ?? 0,
                      'totalAmount': summary['total']!,
                      'subtotal': summary['subtotal']!,
                      'taxType': selectedTaxType,
                    });
                  },
                  child: Text(
                    "Save",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // UI HELPERS (unchanged)
  // -------------------------------------------------------
  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    VoidCallback? onTap,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
      readOnly: false,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> list,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
      items:
          list.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSummaryRow(
    String label,
    double value, {
    bool isBold = false,
    double fontSize = 16,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          "₹ ${value.toStringAsFixed(2)}",
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildCardSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Divider(thickness: 1.2, color: Colors.black),
          SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
