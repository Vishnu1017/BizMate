// lib/screens/select_items_screen.dart
import 'dart:ui';
import 'package:bizmate/models/product.dart';
import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:bizmate/widgets/discount_tax_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late final screenWidth = MediaQuery.of(context).size.width;
  double scale = 1.0;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool isEditingPercent = true;
  bool showSummarySections = false;
  bool _isLoadingProducts = false;

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

  // Focus nodes for keyboard navigation
  final FocusNode _itemFocusNode = FocusNode();
  final FocusNode _quantityFocusNode = FocusNode();
  final FocusNode _rateFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _setupListeners();
  }

  void _initializeForm() {
    quantityController.text = "1";

    // Set default tax rate
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          selectedTaxRate = taxRateOptions[2]; // GST@0.0%
        });
      }
    });
  }

  void _setupListeners() {
    discountPercentController.addListener(() {
      if (isEditingPercent && mounted) {
        _calculateSummary();
      }
    });

    discountAmountController.addListener(() {
      if (!isEditingPercent && mounted) {
        _calculateSummary();
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

  Future<List<Product>> loadUserProducts() async {
    try {
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
    } catch (e) {
      AppSnackBar.showError(context, message: "Failed to load products");
      return [];
    }
  }

  Future<void> saveUserProduct(Product p) async {
    try {
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
    } catch (e) {
      AppSnackBar.showError(context, message: "Failed to save product");
    }
  }

  double parseTaxRate() {
    if (selectedTaxRate == null || !selectedTaxRate!.contains('%')) return 0;
    try {
      return double.tryParse(
            selectedTaxRate!.replaceAll(RegExp(r'[^\d.]'), ''),
          ) ??
          0;
    } catch (_) {
      return 0;
    }
  }

  void _calculateSummary() {
    if (!mounted) return;
    setState(() {});
  }

  Map<String, double> getCalculatedSummary() {
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
      calculatedDiscountAmount =
          isEditingPercent
              ? subtotal * discountPercent / 100
              : (discountAmount > subtotal ? subtotal : discountAmount);

      final taxable = subtotal - calculatedDiscountAmount;

      taxAmount = taxPercent > 0 ? taxable * taxPercent / 100 : 0.0;

      totalAmount = taxable + taxAmount;
    }

    // Update controllers without triggering listeners
    if (isEditingPercent) {
      final currentAmount = discountAmountController.text;
      final newAmount = calculatedDiscountAmount.toStringAsFixed(2);
      if (currentAmount != newAmount) {
        discountAmountController
          ..removeListener(() {})
          ..text = newAmount
          ..addListener(() {
            if (!isEditingPercent && mounted) {
              _calculateSummary();
            }
          });
      }
    } else {
      final currentPercent = discountPercentController.text;
      final newPercent =
          subtotal == 0
              ? "0.00"
              : ((calculatedDiscountAmount / subtotal) * 100).toStringAsFixed(
                2,
              );
      if (currentPercent != newPercent) {
        discountPercentController
          ..removeListener(() {})
          ..text = newPercent
          ..addListener(() {
            if (isEditingPercent && mounted) {
              _calculateSummary();
            }
          });
      }
    }

    return {
      'rate': rate,
      'subtotal': subtotal,
      'discountAmount': calculatedDiscountAmount,
      'taxAmount': taxAmount,
      'total': totalAmount,
    };
  }

  void showItemPicker() async {
    if (_isLoadingProducts) return;

    setState(() => _isLoadingProducts = true);

    try {
      final items = await loadUserProducts();

      if (items.isEmpty) {
        AppSnackBar.showWarning(
          context,
          message: "No products found. Please add products.",
          duration: const Duration(seconds: 3),
        );
        return;
      }

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          final media = MediaQuery.of(context);
          final width = media.size.width;
          final height = media.size.height;

          // -----------------------------
          // RESPONSIVE SCALING
          // -----------------------------
          double rs(double v) =>
              v * (width / 390); // 390 = reference iPhone width

          // -----------------------------
          // RESPONSIVE GRID COLUMN LOGIC
          // -----------------------------
          int columns = 2;

          if (width >= 1200) {
            columns = 5; // large screen / web
          } else if (width >= 900) {
            columns = 4; // large tablet
          } else if (width >= 600) {
            columns = 3; // tablet
          } else {
            columns = 2; // phones
          }

          return Container(
            height: height * 0.75,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(26),
                  ),
                ),
                child: Column(
                  children: [
                    // HEADER
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
                          top: Radius.circular(26),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Select Product",
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

                    const SizedBox(height: 10),

                    // MAIN GRID
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: rs(14)),
                        child: GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: items.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: rs(14),
                                crossAxisSpacing: rs(14),
                                childAspectRatio:
                                    width >= 900
                                        ? 2.6
                                        : width >= 600
                                        ? 2.3
                                        : 1.8,
                              ),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final initials =
                                item.name
                                    .split(" ")
                                    .map((e) => e.isNotEmpty ? e[0] : "")
                                    .join()
                                    .toUpperCase();

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  itemController.text = item.name;
                                  rateController.text = item.rate
                                      .toStringAsFixed(2);
                                  showSummarySections = true;
                                });
                                Navigator.pop(context);
                                _rateFocusNode.requestFocus();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF667EEA),
                                      Color(0xFF764BA2),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(rs(14)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.09),
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
                                          width: rs(26),
                                          height: rs(26),
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
                                              fontSize: rs(11),
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          color: Colors.white,
                                          size: rs(12),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: rs(12),
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "₹${item.rate.toStringAsFixed(2)}",
                                          style: TextStyle(
                                            fontSize: rs(11),
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
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

                    // FOOTER BUTTON
                    Container(
                      padding: EdgeInsets.all(rs(16)),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: Icon(Icons.add, size: rs(18)),
                          label: Text(
                            "Add New Product",
                            style: TextStyle(fontSize: rs(14)),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: rs(12)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(rs(12)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      AppSnackBar.showError(context, message: "Error loading products");
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Theme.of(context).primaryColor,
        fontWeight: FontWeight.w500,
      ),
      hintText: "Enter $label",
      hintStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: Icon(
        icon,
        color: Theme.of(context).primaryColor,
        size: 20 * scale,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      floatingLabelBehavior: FloatingLabelBehavior.always,
    );
  }

  Widget _buildGuideStep(int number, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 32 * scale,
            height: 32 * scale,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,

              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14 * scale,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14 * scale,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12 * scale,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14 * scale, color: Colors.grey.shade600),
          ),
          Text(
            value >= 0
                ? "₹${value.toStringAsFixed(2)}"
                : "-₹${(-value).toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: 16 * scale,
              fontWeight: FontWeight.w600,
              color: color ?? const Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  void _saveAndNew() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final name = itemController.text.trim();
      final rate = double.tryParse(rateController.text) ?? 0;

      if (rate > 0 && name.isNotEmpty) {
        await saveUserProduct(Product(name, rate));
        widget.onItemSaved?.call(name);
      }

      _resetForm();

      AppSnackBar.showSuccess(context, message: "Item saved successfully");
    } catch (e) {
      AppSnackBar.showError(context, message: "Failed to save item");
    }
  }

  void _resetForm() {
    itemController.clear();
    rateController.clear();
    discountPercentController.clear();
    discountAmountController.clear();
    quantityController.text = "1";
    selectedUnit = null;
    selectedTaxRate = taxRateOptions[2];
    selectedTaxType = "Without Tax";
    showSummarySections = false;
    if (mounted) setState(() {});
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            insetPadding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.help,
                            color: Colors.white,
                            size: 26 * scale,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Quick Guide",
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20 * scale,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                            splashRadius: 20,
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildGuideStep(
                            1,
                            "Select Item",
                            "Choose from list or type new",
                          ),
                          const SizedBox(height: 12),
                          _buildGuideStep(
                            2,
                            "Set Quantity",
                            "Enter amount & unit type",
                          ),
                          const SizedBox(height: 12),
                          _buildGuideStep(3, "Enter Rate", "Price per unit"),
                          const SizedBox(height: 12),
                          _buildGuideStep(4, "Configure", "Set tax & discount"),
                          const SizedBox(height: 12),
                          _buildGuideStep(5, "Save", "Add to sale list"),
                        ],
                      ),
                    ),

                    // Footer
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              padding: EdgeInsets.symmetric(
                                horizontal: 28 * scale,
                                vertical: 10 * scale,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              "Got It",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14 * scale,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = getCalculatedSummary();
    double scale = 1.0;
    final isTablet = screenWidth >= 600 && screenWidth < 1000;
    bool isItemSelectedFromList = false;

    // Important: put page content inside a scrollable with extra bottom padding so keyboard won't cause overflow
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        appBar: AppBar(
          iconTheme: const IconThemeData(
            color: Colors.white, // ← makes the back arrow white
          ),
          title: Text(
            "Add Item",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          toolbarHeight: 56 * scale,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: _showHelpDialog,
              tooltip: "Help",
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // responsive padding
              final horizontalPadding = isTablet ? 14.0 * scale : 18.0 * scale;
              final bottomInset = MediaQuery.of(context).viewInsets.bottom;
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 14 * scale,
                ),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(bottom: 20 + bottomInset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Item Details Card
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          color: Colors.white,
                          child: Padding(
                            padding: EdgeInsets.all(16 * scale),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 32 * scale,
                                      height: 32 * scale,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFF667EEA),
                                            Color(0xFF764BA2),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.shopping_bag,
                                        color: Colors.white,
                                        size: 18 * scale,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "Item Details",
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16 * scale,
                                          color: const Color(0xFF333333),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Item Name Field
                                TextFormField(
                                  controller: itemController,
                                  focusNode: _itemFocusNode,
                                  onTap: showItemPicker,
                                  style: TextStyle(fontSize: 14 * scale),
                                  readOnly: false, // 🔥 Allow typing
                                  decoration: _buildInputDecoration(
                                    "Item Name",
                                    Icons.inventory_2,
                                  ).copyWith(
                                    suffixIcon: IconButton(
                                      icon:
                                          _isLoadingProducts
                                              ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                              : Icon(
                                                Icons.arrow_drop_down,
                                                color: Color(0xFF667EEA),
                                              ),
                                      onPressed: showItemPicker,
                                    ),
                                  ),

                                  // -------------------
                                  // VALIDATION
                                  // -------------------
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return "Enter item name";
                                    }
                                    return null;
                                  },

                                  // -------------------
                                  // TYPING + AUTO CAPITALIZATION
                                  // -------------------
                                  onChanged: (value) {
                                    if (value.isNotEmpty &&
                                        value[0] != value[0].toUpperCase()) {
                                      itemController.text = value.splitMapJoin(
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

                                      // Keep cursor at end
                                      itemController.selection =
                                          TextSelection.fromPosition(
                                            TextPosition(
                                              offset:
                                                  itemController.text.length,
                                            ),
                                          );
                                    }

                                    // If user is typing after selecting from list, reset flag
                                    if (isItemSelectedFromList) {
                                      setState(() {
                                        isItemSelectedFromList = false;
                                      });
                                    }
                                  },

                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) {
                                    _quantityFocusNode.requestFocus();
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Quantity and Unit Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: quantityController,
                                        focusNode: _quantityFocusNode,
                                        style: TextStyle(fontSize: 14 * scale),
                                        decoration: _buildInputDecoration(
                                          "Quantity",
                                          Icons.numbers,
                                        ),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(4),
                                        ],
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Please enter quantity';
                                          }
                                          final quantity = int.tryParse(value);
                                          if (quantity == null ||
                                              quantity <= 0) {
                                            return 'Quantity must be greater than 0';
                                          }
                                          if (quantity > 9999) {
                                            return 'Maximum quantity is 9999';
                                          }
                                          return null;
                                        },
                                        textInputAction: TextInputAction.next,
                                        onFieldSubmitted: (_) {
                                          _rateFocusNode.requestFocus();
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: selectedUnit,
                                              style: TextStyle(
                                                fontSize: 14 * scale,
                                                color: Colors.black,
                                              ),
                                              isExpanded: true,
                                              icon: const Icon(
                                                Icons.arrow_drop_down,
                                              ),
                                              hint: Text(
                                                "Unit",
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 14 * scale,
                                                ),
                                              ),
                                              items:
                                                  units.map((String value) {
                                                    return DropdownMenuItem<
                                                      String
                                                    >(
                                                      value: value,
                                                      child: Text(value),
                                                    );
                                                  }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  selectedUnit = value;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Rate Field
                                TextFormField(
                                  controller: rateController,
                                  focusNode: _rateFocusNode,
                                  style: TextStyle(fontSize: 14 * scale),
                                  decoration: _buildInputDecoration(
                                    "Rate (Price/Unit)",
                                    Icons.currency_rupee,
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d+\.?\d{0,2}'),
                                    ),
                                    LengthLimitingTextInputFormatter(10),
                                  ],
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
                                  textInputAction: TextInputAction.done,
                                ),
                                const SizedBox(height: 16),

                                // Tax Type and Rate Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: selectedTaxType,
                                              style: TextStyle(
                                                fontSize: 12 * scale,
                                                color: Colors.black,
                                              ),
                                              isExpanded: true,
                                              icon: const Icon(
                                                Icons.arrow_drop_down,
                                              ),
                                              items:
                                                  taxChoiceOptions.map((
                                                    String value,
                                                  ) {
                                                    return DropdownMenuItem<
                                                      String
                                                    >(
                                                      value: value,
                                                      child: Text(value),
                                                    );
                                                  }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  selectedTaxType = value!;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: selectedTaxRate,
                                              style: TextStyle(
                                                fontSize: 12 * scale,
                                                color: Colors.black,
                                              ),
                                              isExpanded: true,
                                              icon: const Icon(
                                                Icons.arrow_drop_down,
                                              ),
                                              hint: const Text("Tax Rate"),
                                              items:
                                                  taxRateOptions.map((
                                                    String value,
                                                  ) {
                                                    return DropdownMenuItem<
                                                      String
                                                    >(
                                                      value: value,
                                                      child: Text(value),
                                                    );
                                                  }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  selectedTaxRate = value;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Only show Discount & Tax and Summary when item is entered
                        if (showSummarySections) ...[
                          // Discount & Tax Card
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            color: Colors.white,
                            child: Padding(
                              padding: EdgeInsets.all(16 * scale),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 32 * scale,
                                        height: 32 * scale,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0xFF4ECDC4),
                                              Color(0xFF44A08D),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.discount,
                                          color: Colors.white,
                                          size: 18 * scale,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          "Discount & Tax",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16 * scale,
                                            color: const Color(0xFF333333),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  DiscountTaxWidget(
                                    discountPercentController:
                                        discountPercentController,
                                    discountAmountController:
                                        discountAmountController,
                                    isEditingPercent: isEditingPercent,
                                    onModeChange:
                                        (value) => setState(() {
                                          isEditingPercent = value;
                                        }),
                                    subtotal: summary['subtotal']!,
                                    selectedTaxRate: selectedTaxRate,
                                    selectedTaxType: selectedTaxType,
                                    taxRateOptions: taxRateOptions,
                                    onTaxRateChanged:
                                        (val) => setState(() {
                                          selectedTaxRate = val;
                                        }),
                                    parsedTaxRate: parseTaxRate(),
                                    taxAmount: summary['taxAmount']!,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Total Summary Card
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            color: Colors.white,
                            child: Padding(
                              padding: EdgeInsets.all(16 * scale),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 32 * scale,
                                        height: 32 * scale,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0xFFFF6B6B),
                                              Color(0xFFFF8E8E),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.summarize,
                                          color: Colors.white,
                                          size: 18 * scale,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          "Total Summary",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16 * scale,
                                            color: const Color(0xFF333333),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Theme.of(
                                            context,
                                          ).primaryColor.withOpacity(0.08),
                                          Theme.of(
                                            context,
                                          ).primaryColorDark.withOpacity(0.08),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildSummaryRow(
                                          "Subtotal",
                                          summary['subtotal']!,
                                        ),
                                        Divider(
                                          height: 24,
                                          color: Colors.grey.shade300,
                                        ),
                                        _buildSummaryRow(
                                          "Discount",
                                          -summary['discountAmount']!,
                                          color: const Color(0xFF4ECDC4),
                                        ),
                                        Divider(
                                          height: 24,
                                          color: Colors.grey.shade300,
                                        ),
                                        _buildSummaryRow(
                                          "Tax",
                                          summary['taxAmount']!,
                                          color: const Color(0xFFFF6B6B),
                                        ),
                                        Divider(
                                          height: 24 * scale,
                                          color: Colors.grey.shade300,
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(14),
                                          height: 45 * scale,
                                          width: 300 * scale,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Color(0xFF667EEA),
                                                Color(0xFF764BA2),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "Total Amount",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12 * scale,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                "₹${summary['total']!.toStringAsFixed(2)}",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14 * scale,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Empty state when no item entered
                        if (!showSummarySections)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.add_circle_outline,
                                  size: 55 * scale,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Enter item details to see calculations",
                                  style: TextStyle(
                                    fontSize: 14 * scale,
                                    color: Colors.grey.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Discount, tax and total will appear here",
                                  style: TextStyle(
                                    fontSize: 12 * scale,
                                    color: Colors.grey.shade500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Bottom Buttons
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.all(16 * scale),
              child: Row(
                children: [
                  // Save & New Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saveAndNew,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14 * scale),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Theme.of(context).primaryColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            color: Theme.of(context).primaryColor,
                            size: 20 * scale,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Save & New",
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14 * scale,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(width: 20 * scale),

                  // Save & Close Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;

                        final summary = getCalculatedSummary();
                        Navigator.pop(context, {
                          'itemName': itemController.text.trim(),
                          'qty': double.tryParse(quantityController.text) ?? 0,
                          'rate': double.tryParse(rateController.text) ?? 0,
                          'unit': selectedUnit ?? '',
                          'tax': parseTaxRate(),
                          'discount':
                              double.tryParse(discountPercentController.text) ??
                              0,
                          'discountAmount':
                              double.tryParse(discountAmountController.text) ??
                              0,
                          'totalAmount': summary['total']!,
                          'subtotal': summary['subtotal']!,
                          'taxType': selectedTaxType,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 14 * scale),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20 * scale,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Save Item",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14 * scale,
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
    );
  }

  @override
  void dispose() {
    itemController.dispose();
    quantityController.dispose();
    rateController.dispose();
    discountPercentController.dispose();
    discountAmountController.dispose();
    _itemFocusNode.dispose();
    _quantityFocusNode.dispose();
    _rateFocusNode.dispose();
    super.dispose();
  }
}
