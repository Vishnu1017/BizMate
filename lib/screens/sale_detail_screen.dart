// lib/screens/sale_detail_screen.dart
import 'package:bizmate/models/payment.dart';
import 'package:bizmate/widgets/ModernCalendar.dart';
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
  bool _isSaving = false;

  final List<String> _paymentModes = [
    'Cash',
    'UPI',
    'Card',
    'Bank Transfer',
    'Cheque',
    'Wallet',
  ];

  final _formKey = GlobalKey<FormState>();

  List<DateTime> selectedEventDates = [];

  Future<void> _selectMultipleDates() async {
    final result = await showModalBottomSheet<List<DateTime>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ModernCalendar(
            selectedDates: selectedEventDates,
            onDateSelected: (DateTime date) {
              setState(() {
                final exists = selectedEventDates.any(
                  (d) =>
                      d.day == date.day &&
                      d.month == date.month &&
                      d.year == date.year,
                );

                if (!exists) {
                  selectedEventDates.add(date);
                }
              });
            },
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        selectedEventDates = List<DateTime>.from(result);
      });
    }
  }

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

    selectedEventDates = List<DateTime>.from(widget.sale.eventDates ?? []);
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
    if (_isSaving) return;

    setState(() => _isSaving = true);

    if (customerController.text.trim().isEmpty) {
      AppSnackBar.showError(context, message: "Customer name cannot be empty!");
      setState(() => _isSaving = false);
      return;
    }

    if (phoneController.text.trim().isEmpty ||
        phoneController.text.trim().length != 10 ||
        !RegExp(r'^[0-9]+$').hasMatch(phoneController.text.trim())) {
      AppSnackBar.showError(
        context,
        message: "Enter a valid 10-digit phone number!",
      );
      setState(() => _isSaving = false);
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
      setState(() => _isSaving = false);
      return;
    }

    if (!isFullyPaid && paid < 0) {
      AppSnackBar.showError(
        context,
        message: "Paid amount cannot be negative!",
      );
      setState(() => _isSaving = false);
      return;
    }

    if (!Hive.isBoxOpen('session')) await Hive.openBox('session');
    final sessionBox = Hive.box('session');
    final email = sessionBox.get("currentUserEmail");

    if (email == null) {
      AppSnackBar.showError(
        context,
        message: "Session expired. Please login again.",
      );
      setState(() => _isSaving = false);
      return;
    }

    final safeEmail = email
        .toString()
        .replaceAll('.', '_')
        .replaceAll('@', '_');

    final userBox = await Hive.openBox("userdata_$safeEmail");

    List<Sale> sales = [];

    try {
      sales = List<Sale>.from(userBox.get("sales", defaultValue: []));
    } catch (_) {
      sales = [];
    }

    final targetDate = widget.sale.dateTime;

    final newPayment = Payment(
      amount: isFullyPaid ? total : paid,
      date: DateTime.now(),
      mode: _selectedMode,
    );

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
      eventDates: selectedEventDates,
    );

    for (int i = 0; i < sales.length; i++) {
      if (sales[i].dateTime == targetDate) {
        sales[i] = updatedSale;
        break;
      }
    }

    await userBox.put("sales", sales);

    if (!mounted) return;

    AppSnackBar.showSuccess(
      context,
      message: 'Sale updated successfully!',
      duration: const Duration(seconds: 2),
    );

    setState(() => _isSaving = false);

    Navigator.pop(context, true);
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
        final completedCount = widget.sale.completedPhotographyCount;
        final totalCount = selectedEventDates.length;

        final allCompleted = completedCount == totalCount && totalCount > 0;
        final partiallyCompleted =
            completedCount > 0 && completedCount < totalCount;

        return AbsorbPointer(
          absorbing: _isSaving,
          child: Scaffold(
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
                  onPressed: _isSaving ? null : saveChanges,
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

                          // ==============================================
                          // MODERN PHOTOGRAPHY SCHEDULE CARD - RED & GREEN THEME
                          // ==============================================
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(cardPadding),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.white, const Color(0xFFF8FAFC)],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 30,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color:
                                      allCompleted
                                          ? const Color(
                                            0xFF10B981,
                                          ).withOpacity(0.08)
                                          : const Color(
                                            0xFFEF4444,
                                          ).withOpacity(0.08),
                                  blurRadius: 40,
                                  spreadRadius: -5,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // --- Header ---
                                Row(
                                  children: [
                                    // Animated Icon Container
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 400,
                                      ),
                                      curve: Curves.easeInOut,
                                      padding: EdgeInsets.all(6 * scale),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors:
                                              allCompleted
                                                  ? [
                                                    const Color(0xFF10B981),
                                                    const Color(0xFF34D399),
                                                  ]
                                                  : [
                                                    const Color(0xFFEF4444),
                                                    const Color(0xFFF87171),
                                                  ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                allCompleted
                                                    ? const Color(
                                                      0xFF10B981,
                                                    ).withOpacity(0.3)
                                                    : const Color(
                                                      0xFFEF4444,
                                                    ).withOpacity(0.3),
                                            blurRadius: 12,
                                            spreadRadius: 0,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        allCompleted
                                            ? Icons.done_all_rounded
                                            : Icons.camera_alt_rounded,
                                        color: Colors.white,
                                        size: 16 * scale,
                                      ),
                                    ),
                                    SizedBox(width: 12 * scale),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                "Photography Schedule",
                                                style: TextStyle(
                                                  fontSize: 13 * scale,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(
                                                    0xFF0F172A,
                                                  ),
                                                  letterSpacing: -0.5,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Status Dot
                                              AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 400,
                                                ),
                                                width: 6 * scale,
                                                height: 6 * scale,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color:
                                                      allCompleted
                                                          ? const Color(
                                                            0xFF10B981,
                                                          )
                                                          : partiallyCompleted
                                                          ? const Color(
                                                            0xFFF59E0B,
                                                          )
                                                          : const Color(
                                                            0xFFEF4444,
                                                          ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color:
                                                          allCompleted
                                                              ? const Color(
                                                                0xFF10B981,
                                                              ).withOpacity(0.5)
                                                              : partiallyCompleted
                                                              ? const Color(
                                                                0xFFF59E0B,
                                                              ).withOpacity(0.5)
                                                              : const Color(
                                                                0xFFEF4444,
                                                              ).withOpacity(
                                                                0.5,
                                                              ),
                                                      blurRadius: 8,
                                                      spreadRadius: 0,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 3 * scale),
                                          Text(
                                            "${selectedEventDates.length} shoot date${selectedEventDates.length != 1 ? 's' : ''}",
                                            style: TextStyle(
                                              fontSize: 8 * scale,
                                              color: Colors.grey.shade500,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Gradient Progress Ring
                                    SizedBox(
                                      width: 36 * scale,
                                      height: 36 * scale,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Gradient circular progress
                                          CustomPaint(
                                            painter:
                                                GradientCircularProgressPainter(
                                                  value:
                                                      totalCount > 0
                                                          ? completedCount /
                                                              totalCount
                                                          : 0,
                                                  strokeWidth: 4,
                                                  gradient: getProgressGradient(
                                                    totalCount > 0
                                                        ? (completedCount /
                                                                totalCount) *
                                                            100
                                                        : 0,
                                                  ),
                                                ),
                                            size: Size(36 * scale, 36 * scale),
                                          ),
                                          // Percentage text
                                          Text(
                                            totalCount > 0
                                                ? "${((completedCount / totalCount) * 100).toStringAsFixed(0)}%"
                                                : "0%",
                                            style: TextStyle(
                                              fontSize: 8 * scale,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10 * scale),
                                // --- Stats Row ---
                                Row(
                                  children: [
                                    _buildModernStat(
                                      label: "Completed",
                                      value: "$completedCount",
                                      color: const Color(0xFF10B981),
                                      icon: Icons.check_circle_outline_rounded,
                                    ),
                                    Container(
                                      width: 1,
                                      height: 30,
                                      color: Colors.grey.shade200,
                                    ),
                                    _buildModernStat(
                                      label: "Pending",
                                      value: "${totalCount - completedCount}",
                                      color: const Color(0xFFEF4444),
                                      icon: Icons.pending_actions_rounded,
                                    ),
                                    Container(
                                      width: 1,
                                      height: 30,
                                      color: Colors.grey.shade200,
                                    ),
                                    _buildModernStat(
                                      label: "Total",
                                      value: "$totalCount",
                                      color: const Color(0xFF64748B),
                                      icon: Icons.calendar_today_rounded,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10 * scale),
                                InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: _selectMultipleDates,
                                  child: Container(
                                    padding: EdgeInsets.all(10 * scale),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors:
                                            allCompleted
                                                ? [
                                                  const Color(
                                                    0xFF10B981,
                                                  ).withOpacity(0.08),
                                                  const Color(
                                                    0xFF34D399,
                                                  ).withOpacity(0.04),
                                                ]
                                                : [
                                                  const Color(
                                                    0xFFEF4444,
                                                  ).withOpacity(0.08),
                                                  const Color(
                                                    0xFFF87171,
                                                  ).withOpacity(0.04),
                                                ],
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        12 * scale,
                                      ),
                                      border: Border.all(
                                        color:
                                            allCompleted
                                                ? const Color(
                                                  0xFF10B981,
                                                ).withOpacity(0.15)
                                                : const Color(
                                                  0xFFEF4444,
                                                ).withOpacity(0.15),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color:
                                                allCompleted
                                                    ? const Color(
                                                      0xFF10B981,
                                                    ).withOpacity(0.12)
                                                    : const Color(
                                                      0xFFEF4444,
                                                    ).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(
                                              10 * scale,
                                            ),
                                          ),
                                          child: Icon(
                                            selectedEventDates.isEmpty
                                                ? Icons.add_rounded
                                                : Icons.edit_rounded,
                                            color:
                                                allCompleted
                                                    ? const Color(0xFF10B981)
                                                    : const Color(0xFFEF4444),
                                            size: 12 * scale,
                                          ),
                                        ),
                                        SizedBox(width: 10 * scale),
                                        Expanded(
                                          child: Text(
                                            selectedEventDates.isEmpty
                                                ? "Add photography dates"
                                                : "Manage schedule",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 10 * scale,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10 * scale,
                                            vertical: 4 * scale,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                allCompleted
                                                    ? const Color(
                                                      0xFF10B981,
                                                    ).withOpacity(0.1)
                                                    : const Color(
                                                      0xFFEF4444,
                                                    ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              10 * scale,
                                            ),
                                          ),
                                          child: Text(
                                            selectedEventDates.length
                                                .toString(),
                                            style: TextStyle(
                                              color:
                                                  allCompleted
                                                      ? const Color(0xFF10B981)
                                                      : const Color(0xFFEF4444),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 10 * scale,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8 * scale),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 12 * scale,
                                          color: Colors.grey.shade400,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // --- Date Chips with Modern Design ---
                                if (selectedEventDates.isNotEmpty) ...[
                                  SizedBox(height: 10 * scale),
                                  Wrap(
                                    spacing: 8 * scale,
                                    runSpacing: 8 * scale,
                                    children:
                                        selectedEventDates.map((date) {
                                          // Check if date is completed (past)
                                          final isCompleted = DateTime(
                                            date.year,
                                            date.month,
                                            date.day,
                                            23,
                                            59,
                                            59,
                                          ).isBefore(DateTime.now());

                                          // Check if date is today
                                          final isToday =
                                              date.day == DateTime.now().day &&
                                              date.month ==
                                                  DateTime.now().month &&
                                              date.year == DateTime.now().year;

                                          // Determine if date is pending (not completed and not today)
                                          final isPending =
                                              !isCompleted && !isToday;

                                          return Container(
                                            child: Chip(
                                              avatar: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                padding: EdgeInsets.all(
                                                  4 * scale,
                                                ),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors:
                                                        isCompleted
                                                            ? [
                                                              const Color(
                                                                0xFF10B981,
                                                              ),
                                                              const Color(
                                                                0xFF34D399,
                                                              ),
                                                            ]
                                                            : isToday
                                                            ? [
                                                              const Color(
                                                                0xFFF59E0B,
                                                              ),
                                                              const Color(
                                                                0xFFFBBF24,
                                                              ),
                                                            ]
                                                            : [
                                                              const Color(
                                                                0xFFEF4444,
                                                              ),
                                                              const Color(
                                                                0xFFF87171,
                                                              ),
                                                            ], // Red for pending
                                                  ),
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color:
                                                          isCompleted
                                                              ? const Color(
                                                                0xFF10B981,
                                                              ).withOpacity(0.3)
                                                              : isToday
                                                              ? const Color(
                                                                0xFFF59E0B,
                                                              ).withOpacity(0.3)
                                                              : const Color(
                                                                0xFFEF4444,
                                                              ).withOpacity(
                                                                0.3,
                                                              ),
                                                      blurRadius: 6,
                                                      spreadRadius: 0,
                                                    ),
                                                  ],
                                                ),
                                                child: Icon(
                                                  isCompleted
                                                      ? Icons.check_rounded
                                                      : isToday
                                                      ? Icons.today_rounded
                                                      : Icons.event_rounded,
                                                  size: 8 * scale,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              backgroundColor: Colors.white,
                                              side: BorderSide(
                                                color:
                                                    isCompleted
                                                        ? const Color(
                                                          0xFF10B981,
                                                        ).withOpacity(0.3)
                                                        : isToday
                                                        ? const Color(
                                                          0xFFF59E0B,
                                                        ).withOpacity(0.3)
                                                        : const Color(
                                                          0xFFEF4444,
                                                        ).withOpacity(
                                                          0.2,
                                                        ), // Red border for pending
                                                width: 1.5,
                                              ),
                                              elevation: 2,
                                              shadowColor:
                                                  isCompleted
                                                      ? const Color(
                                                        0xFF10B981,
                                                      ).withOpacity(0.1)
                                                      : isToday
                                                      ? const Color(
                                                        0xFFF59E0B,
                                                      ).withOpacity(0.1)
                                                      : const Color(
                                                        0xFFEF4444,
                                                      ).withOpacity(0.1),
                                              label: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    DateFormat(
                                                      'dd MMM yyyy',
                                                    ).format(date),
                                                    style: TextStyle(
                                                      color: const Color(
                                                        0xFF1E293B,
                                                      ),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 10 * scale,
                                                      letterSpacing: -0.3,
                                                    ),
                                                  ),
                                                  if (isCompleted) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal:
                                                                4 * scale,
                                                            vertical: 2 * scale,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFF10B981,
                                                        ).withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                        border: Border.all(
                                                          color: const Color(
                                                            0xFF10B981,
                                                          ).withOpacity(0.15),
                                                          width: 0.5,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        "DONE",
                                                        style: TextStyle(
                                                          color: const Color(
                                                            0xFF10B981,
                                                          ),
                                                          fontSize: 6 * scale,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  if (isToday &&
                                                      !isCompleted) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal:
                                                                4 * scale,
                                                            vertical: 2 * scale,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFF59E0B,
                                                        ).withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                        border: Border.all(
                                                          color: const Color(
                                                            0xFFF59E0B,
                                                          ).withOpacity(0.15),
                                                          width: 0.5,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        "TODAY",
                                                        style: TextStyle(
                                                          color: const Color(
                                                            0xFF92400E,
                                                          ),
                                                          fontSize: 6 * scale,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  if (isPending) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal:
                                                                4 * scale,
                                                            vertical: 2 * scale,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFEF4444,
                                                        ).withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                        border: Border.all(
                                                          color: const Color(
                                                            0xFFEF4444,
                                                          ).withOpacity(0.15),
                                                          width: 0.5,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        "PENDING",
                                                        style: TextStyle(
                                                          color: const Color(
                                                            0xFFDC2626,
                                                          ),
                                                          fontSize: 6 * scale,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              deleteIcon: Container(
                                                padding: EdgeInsets.all(
                                                  4 * scale,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.grey.shade300,
                                                    width: 0.5,
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.close_rounded,
                                                  color: Colors.grey.shade500,
                                                  size: 8 * scale,
                                                ),
                                              ),
                                              onDeleted: () {
                                                setState(() {
                                                  selectedEventDates.remove(
                                                    date,
                                                  );
                                                });
                                              },
                                            ),
                                          );
                                        }).toList(),
                                  ),
                                ],
                                // --- Modern Empty State ---
                                if (selectedEventDates.isEmpty) ...[
                                  SizedBox(height: 10 * scale),
                                  Center(
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 10 * scale,
                                        horizontal: 15 * scale,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(
                                              0xFFEF4444,
                                            ).withOpacity(0.04),
                                            const Color(
                                              0xFFF87171,
                                            ).withOpacity(0.02),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(
                                            0xFFEF4444,
                                          ).withOpacity(0.08),
                                          width: 1,
                                          style: BorderStyle.solid,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.photo_camera_outlined,
                                            color: const Color(
                                              0xFFEF4444,
                                            ).withOpacity(0.2),
                                            size: 24 * scale,
                                          ),
                                          SizedBox(height: 10 * scale),
                                          Text(
                                            "No dates scheduled",
                                            style: TextStyle(
                                              color: const Color(0xFF0F172A),
                                              fontSize: 12 * scale,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            "Tap above to add your first photography date",
                                            style: TextStyle(
                                              color: Colors.grey.shade400,
                                              fontSize: 10 * scale,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                                    controller:
                                                        amountController,
                                                    keyboardType:
                                                        const TextInputType.numberWithOptions(
                                                          decimal: true,
                                                        ),
                                                    inputFormatters: [
                                                      FilteringTextInputFormatter.allow(
                                                        RegExp(
                                                          r'^\d*\.?\d{0,2}',
                                                        ),
                                                      ),
                                                    ],
                                                    style: TextStyle(
                                                      fontSize: 16 * scale,
                                                      fontWeight:
                                                          FontWeight.w700,
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
                                                        color: Color(
                                                          0xFF10B981,
                                                        ),
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
                                                      final val =
                                                          double.tryParse(
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
                                                  mainAxisSize:
                                                      MainAxisSize.min,
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
                              onPressed: _isSaving ? null : saveChanges,
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

  // --- Helper Widgets ---
  Widget _buildModernStat({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 10 * scale, color: color.withOpacity(0.6)),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 8 * scale,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// Add this helper function at the top of your file
LinearGradient getProgressGradient(double percentage) {
  if (percentage <= 20) {
    return LinearGradient(colors: [Color(0xFFE53935), Color(0xFFD32F2F)]);
  } else if (percentage <= 50) {
    return LinearGradient(colors: [Color(0xFFE53935), Color(0xFFFFA726)]);
  } else if (percentage <= 75) {
    return LinearGradient(
      colors: [Color(0xFFFFA726), Color(0xFFFFEB3B), Color(0xFF66BB6A)],
    );
  } else {
    return LinearGradient(colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)]);
  }
}

// Custom painter for gradient circular progress
class GradientCircularProgressPainter extends CustomPainter {
  final double value;
  final double strokeWidth;
  final LinearGradient gradient;

  GradientCircularProgressPainter({
    required this.value,
    required this.strokeWidth,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;

    // Draw background
    final backgroundPaint =
        Paint()
          ..color = Colors.grey.shade100
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw gradient progress
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint =
        Paint()
          ..shader = gradient.createShader(rect)
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * 3.14159 * (value.clamp(0.0, 1.0));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
