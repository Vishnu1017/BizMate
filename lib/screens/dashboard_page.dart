// lib/screens/dashboard_page.dart
// Fully production-responsive DashboardPage with Net Profit & Expense Tracking
import 'dart:math' as math;

import 'package:bizmate/models/expense.dart';
import 'package:bizmate/screens/SalesReportPage.dart';
import 'package:bizmate/screens/expenses_page.dart';
import 'package:bizmate/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:bizmate/services/notification_service.dart';
import '../models/payment.dart';
import '../models/rental_sale_model.dart';
import '../models/sale.dart';

class DashboardPage extends StatefulWidget {
  final String userEmail;

  const DashboardPage({super.key, required this.userEmail});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  double totalSale = 0.0;
  double totalExpense = 0.0;
  double netProfit = 0.0;
  double profitMargin = 0.0;
  double rangeRevenue = 0.0;
  double rangeExpense = 0.0;
  double rangeNetProfit = 0.0;

  double growthPercent = 0.0;
  List<FlSpot> salesData = [];
  List<FlSpot> expenseData = [];
  List<FlSpot> profitData = [];
  Map<String, double> categoryDistribution = {};

  List<String> monthLabels = [];
  double maxYValue = 100;
  double minYValue = 0;
  String _selectedRange = '3m';
  int _activeView = 0; // 0: Net Profit & PnL, 1: Revenue, 2: Expense Breakdown

  final ScrollController _scrollController = ScrollController();
  double previousMonthsTotal = 0.0;
  double previousMonthsAvg = 0.0;
  int previousMonthsCount = 0;

  List<Sale> sales = [];
  List<RentalSaleModel> rentalSales = [];
  List<Expense> expenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration.zero, () async {
      await _initializeData();
      if (mounted) setState(() {});
    });
  }

  Future<void> _initializeData() async {
    await _loadSalesData();
    await _loadRentalSalesData();
    await _loadExpensesData();
    fetchSaleOverview(_selectedRange);

    if (rentalSales.isNotEmpty) {
      NotificationService.checkOverdueRentals(rentalSales);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSalesData() async {
    try {
      final safeEmail = widget.userEmail
          .replaceAll('.', '_')
          .replaceAll('@', '_');
      final boxName = "userdata_$safeEmail";

      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox(boxName);
      }
      final userBox = Hive.box(boxName);

      final rawSales = userBox.get('sales', defaultValue: []);
      sales = (rawSales as List).map((e) => e as Sale).toList();
    } catch (e) {
      debugPrint('Error loading sales data: $e');
      sales = [];
    }
  }

  Future<void> _loadRentalSalesData() async {
    try {
      final safeEmail = widget.userEmail
          .replaceAll('.', '_')
          .replaceAll('@', '_');
      final boxName = "userdata_$safeEmail";

      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox(boxName);
      }
      final userBox = Hive.box(boxName);

      final rawRentalSales = userBox.get('rental_sales', defaultValue: []);
      rentalSales =
          (rawRentalSales as List).map((e) => e as RentalSaleModel).toList();
    } catch (e) {
      debugPrint('Error loading rental sales data: $e');
      rentalSales = [];
    }
  }

  Future<void> _loadExpensesData() async {
    try {
      final safeEmail = widget.userEmail
          .replaceAll('.', '_')
          .replaceAll('@', '_');
      final boxName = "userdata_$safeEmail";

      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox(boxName);
      }
      final userBox = Hive.box(boxName);

      final rawExpenses = userBox.get('expenses', defaultValue: []);
      expenses = (rawExpenses as List).map((e) {
        if (e is Expense) return e;
        return Expense.fromJson(Map<String, dynamic>.from(e as Map));
      }).toList();
    } catch (e) {
      debugPrint('Error loading expenses data: $e');
      expenses = [];
    }
  }

  int getMonthRange(String range) {
    switch (range) {
      case '3m':
        return 3;
      case '6m':
        return 6;
      case '9m':
        return 9;
      case '1y':
        return 12;
      case '5y':
        return 60;
      case 'max':
        return 120;
      default:
        return 3;
    }
  }

  void fetchSaleOverview(String range) {
    final now = DateTime.now();
    final rangeInMonths = getMonthRange(range);

    final months = List.generate(rangeInMonths, (i) {
      final date = DateTime(now.year, now.month - (rangeInMonths - 1 - i));
      return DateFormat('MMM').format(date);
    });

    final keys = List.generate(rangeInMonths, (i) {
      final date = DateTime(now.year, now.month - (rangeInMonths - 1 - i));
      return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    });

    Map<String, double> monthlyTotals = {for (var key in keys) key: 0.0};
    Map<String, double> monthlyExpenses = {for (var key in keys) key: 0.0};
    Map<String, double> catDist = {};

    // Process regular sales
    for (var sale in sales) {
      final key =
          '${sale.dateTime.year}-${sale.dateTime.month.toString().padLeft(2, '0')}';
      if (monthlyTotals.containsKey(key)) {
        monthlyTotals[key] = monthlyTotals[key]! + sale.amount;
      }
    }

    // Process rental sales
    for (var rental in rentalSales) {
      final key =
          '${rental.fromDateTime.year}-${rental.fromDateTime.month.toString().padLeft(2, '0')}';
      if (monthlyTotals.containsKey(key)) {
        monthlyTotals[key] = monthlyTotals[key]! + rental.amountPaid;
      }
    }

    // Process expenses
    for (var exp in expenses) {
      final key =
          '${exp.dateTime.year}-${exp.dateTime.month.toString().padLeft(2, '0')}';
      if (monthlyExpenses.containsKey(key)) {
        monthlyExpenses[key] = monthlyExpenses[key]! + exp.amount;
        catDist[exp.category] = (catDist[exp.category] ?? 0.0) + exp.amount;
      }
    }

    Map<String, double> monthlyProfits = {};
    for (var key in keys) {
      monthlyProfits[key] =
          (monthlyTotals[key] ?? 0.0) - (monthlyExpenses[key] ?? 0.0);
    }

    List<double> monthlyValues =
        keys.map((key) => monthlyTotals[key] ?? 0.0).toList();
    List<double> monthlyExpenseValues =
        keys.map((key) => monthlyExpenses[key] ?? 0.0).toList();
    List<double> monthlyProfitValues =
        keys.map((key) => monthlyProfits[key] ?? 0.0).toList();

    final currentMonthTotal =
        monthlyValues.isNotEmpty ? monthlyValues.last : 0.0;
    final currentMonthExpenseTotal =
        monthlyExpenseValues.isNotEmpty ? monthlyExpenseValues.last : 0.0;
    final currentMonthNetProfitTotal =
        currentMonthTotal - currentMonthExpenseTotal;

    final previousMonths =
        monthlyValues.length > 1
            ? monthlyValues.sublist(0, monthlyValues.length - 1)
            : [];

    previousMonthsTotal = previousMonths.fold(0.0, (a, b) => a + b);
    previousMonthsAvg =
        previousMonths.isNotEmpty
            ? previousMonthsTotal / previousMonths.length
            : 0.0;
    previousMonthsCount = previousMonths.length;

    growthPercent =
        previousMonthsAvg > 0
            ? ((currentMonthTotal - previousMonthsAvg) / previousMonthsAvg) *
                100
            : (currentMonthTotal > 0 ? 100 : 0);

    totalSale = currentMonthTotal;
    totalExpense = currentMonthExpenseTotal;
    netProfit = currentMonthNetProfitTotal;
    profitMargin = currentMonthTotal > 0
        ? (currentMonthNetProfitTotal / currentMonthTotal) * 100
        : (currentMonthNetProfitTotal < 0 ? -100.0 : 0.0);

    rangeRevenue = monthlyValues.fold(0.0, (a, b) => a + b);
    rangeExpense = monthlyExpenseValues.fold(0.0, (a, b) => a + b);
    rangeNetProfit = rangeRevenue - rangeExpense;
    categoryDistribution = catDist;

    final allY = [
      ...monthlyValues,
      ...monthlyExpenseValues,
      ...monthlyProfitValues,
    ];

    final maxVal = allY.isEmpty ? 100.0 : allY.reduce(math.max);
    final minVal = allY.isEmpty ? 0.0 : allY.reduce(math.min);

    maxYValue = (maxVal <= 0 ? 100.0 : maxVal * 1.25).ceilToDouble();
    minYValue = minVal < 0 ? (minVal * 1.2).floorToDouble() : 0.0;

    setState(() {
      monthLabels = months;
      salesData = List.generate(
        keys.length,
        (i) => FlSpot(i.toDouble(), monthlyTotals[keys[i]]!),
      );
      expenseData = List.generate(
        keys.length,
        (i) => FlSpot(i.toDouble(), monthlyExpenses[keys[i]]!),
      );
      profitData = List.generate(
        keys.length,
        (i) => FlSpot(i.toDouble(), monthlyProfits[keys[i]]!),
      );
      _selectedRange = range;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients &&
          salesData.isNotEmpty &&
          salesData.length > 5) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Convert Rental → Sale (Required for SalesReportPage)
  Sale convertRentalToSale(RentalSaleModel r) {
    return Sale(
      customerName: r.customerName,
      amount: r.amountPaid,
      productName: r.itemName,
      dateTime: r.fromDateTime,
      phoneNumber: r.customerPhone,
      totalAmount: r.totalCost,
      discount: (r.ratePerDay * r.numberOfDays + r.safeTax - r.totalCost).clamp(
        0.0,
        double.infinity,
      ),
      item: r.itemName,
      tax: r.safeTax,
      paymentMode: r.paymentMode,
      paymentHistory: r.paymentHistory.isNotEmpty
          ? r.paymentHistory
          : [
              Payment(
                amount: r.amountPaid,
                date: r.fromDateTime,
                mode: r.paymentMode.isNotEmpty ? r.paymentMode : 'Cash',
              ),
            ],
      deliveryStatus: r.saleStatus,
    );
  }

  void _navigateToSalesReport() async {
    List<Sale> allSales = [];
    allSales.addAll(sales);
    allSales.addAll(rentalSales.map((r) => convertRentalToSale(r)).toList());
    allSales.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SalesReportPage(sales: allSales)),
    );
  }

  Future<void> _navigateToExpenses() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExpensesPage(userEmail: widget.userEmail),
      ),
    );
    await _initializeData();
  }

  void _onRangeSelected(String value) {
    setState(() {
      _selectedRange = value;
    });
    fetchSaleOverview(value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: c.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isNetProfitPositive = netProfit >= 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double scale = (width / 375.0).clamp(0.76, 1.35);

        final double outerPadding =
            width < 350 ? 10.0 : (16.0 * scale).clamp(12.0, 32.0);
        final double cardPaddingH =
            width < 350 ? 10.0 : (16.0 * scale).clamp(12.0, 24.0);
        final double cardPaddingV =
            width < 350 ? 10.0 : (14.0 * scale).clamp(10.0, 20.0);
        final double titleFont = (16.0 * scale).clamp(13.0, 20.0);
        final double chartHeight = (230.0 * scale).clamp(180.0, 320.0);

        return Scaffold(
          backgroundColor: c.background,
          body: MediaQuery.removePadding(
            removeTop: true,
            context: context,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(outerPadding),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. TOP METRIC CARDS ROW (Gross Revenue, Expenses, Net Profit)
                        _buildFinancialMetricsGrid(scale, isNetProfitPositive),
                        SizedBox(height: 16.0 * scale),

                        // 2. MAIN CARD: Interactive Financial Center
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: cardPaddingH,
                            vertical: cardPaddingV,
                          ),
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(18.0 * scale),
                            boxShadow: [
                              BoxShadow(
                                color: c.shadowColor,
                                blurRadius: 10.0 * scale,
                                offset: Offset(0, 4.0 * scale),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title + Time Range Menu
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Financial Analytics ($_selectedRange)",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: titleFont,
                                            color: c.text1,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          "Revenue, operational expenses & net margin",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12.0 * scale,
                                            color: c.text2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: _onRangeSelected,
                                    icon: Container(
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.blue.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(
                                          12.0 * scale,
                                        ),
                                      ),
                                      padding: EdgeInsets.all(8.0 * scale),
                                      child: FaIcon(
                                        FontAwesomeIcons.ellipsisVertical,
                                        size: 14.0 * scale,
                                        color: const Color(0xFF1E40AF),
                                      ),
                                    ),
                                    offset: Offset(0, 45.0 * scale),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(16.0 * scale),
                                    ),
                                    itemBuilder: (context) => [
                                      _buildMenuItem('3m', Icons.timelapse, Colors.blue, scale),
                                      _buildMenuItem('6m', Icons.hourglass_top, Colors.green, scale),
                                      _buildMenuItem('9m', Icons.hourglass_full, Colors.orange, scale),
                                      _buildMenuItem('1y', Icons.calendar_today, Colors.purple, scale),
                                      _buildMenuItem('5y', Icons.event, Colors.red, scale),
                                      _buildMenuItem('max', Icons.all_inclusive, Colors.teal, scale),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: 14.0 * scale),

                              // Segmented View Toggle
                              _buildSegmentedViewSelector(scale),
                              SizedBox(height: 16.0 * scale),

                              // View Content
                              if (_activeView == 2)
                                _buildCategoryBreakdownView(scale)
                              else
                                _buildChartView(scale, chartHeight),
                            ],
                          ),
                        ),
                        SizedBox(height: 18.0 * scale),

                        // 3. ACTION BUTTONS ROW (Manage Expenses & Sales Insights)
                        Row(
                          children: [
                            // Manage Expenses Button
                            Expanded(
                              child: SizedBox(
                                height: 48.0 * scale,
                                child: OutlinedButton.icon(
                                  onPressed: _navigateToExpenses,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF1E40AF),
                                    side: const BorderSide(
                                      color: Color(0xFF1E40AF),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(25.0 * scale),
                                    ),
                                  ),
                                  icon: Icon(
                                    Icons.receipt_long_rounded,
                                    size: 18.0 * scale,
                                  ),
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Manage Expenses',
                                      style: TextStyle(
                                        fontSize: 13.0 * scale,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12.0 * scale),

                            // View Sales Insights Button
                            Expanded(
                              child: SizedBox(
                                height: 48.0 * scale,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF2563EB),
                                        Color(0xFF1E40AF),
                                        Color(0xFF020617),
                                      ],
                                      stops: [0.0, 0.6, 1.0],
                                      begin: Alignment.bottomRight,
                                      end: Alignment.topLeft,
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(25.0 * scale),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF1E40AF)
                                            .withValues(alpha: 0.25),
                                        blurRadius: 8.0 * scale,
                                        offset: Offset(0, 3.0 * scale),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: _navigateToSalesReport,
                                    icon: Icon(
                                      Icons.bar_chart_rounded,
                                      color: Colors.white,
                                      size: 18.0 * scale,
                                    ),
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Sales Insights',
                                        style: TextStyle(
                                          fontSize: 13.0 * scale,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(25.0 * scale),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20.0 * scale),
                      ],
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

  // ---------------------------------------------------------------------------
  // FINANCIAL METRIC CARDS
  // ---------------------------------------------------------------------------

  Widget _buildFinancialMetricsGrid(double scale, bool isNetProfitPositive) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;

        final revenueCard = _buildMetricPill(
          title: "Revenue ($currentMonthName)",
          amount: "₹${totalSale.toStringAsFixed(0)}",
          subtitle: "Range: ₹${rangeRevenue.toStringAsFixed(0)}",
          color: const Color(0xFF2563EB),
          icon: Icons.payments_rounded,
          scale: scale,
        );

        final expenseCard = _buildMetricPill(
          title: "Expenses ($currentMonthName)",
          amount: "₹${totalExpense.toStringAsFixed(0)}",
          subtitle: "Range: ₹${rangeExpense.toStringAsFixed(0)}",
          color: const Color(0xFFF43F5E),
          icon: Icons.receipt_long_rounded,
          scale: scale,
        );

        final profitCard = _buildMetricPill(
          title: "Net Profit ($currentMonthName)",
          amount: "${isNetProfitPositive ? '+' : ''}₹${netProfit.toStringAsFixed(0)}",
          subtitle: "${profitMargin.toStringAsFixed(1)}% Net Margin",
          color: isNetProfitPositive
              ? const Color(0xFF10B981)
              : const Color(0xFFEF4444),
          icon: isNetProfitPositive
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded,
          scale: scale,
          highlight: true,
        );

        if (constraints.maxWidth < 360) {
          return Column(
            children: [
              profitCard,
              SizedBox(height: 8 * scale),
              revenueCard,
              SizedBox(height: 8 * scale),
              expenseCard,
            ],
          );
        } else if (isSmall) {
          return Column(
            children: [
              profitCard,
              SizedBox(height: 10 * scale),
              Row(
                children: [
                  Expanded(child: revenueCard),
                  SizedBox(width: 10 * scale),
                  Expanded(child: expenseCard),
                ],
              ),
            ],
          );
        } else {
          return Row(
            children: [
              Expanded(child: revenueCard),
              SizedBox(width: 12 * scale),
              Expanded(child: expenseCard),
              SizedBox(width: 12 * scale),
              Expanded(child: profitCard),
            ],
          );
        }
      },
    );
  }

  String get currentMonthName => DateFormat('MMM').format(DateTime.now());

  Widget _buildMetricPill({
    required String title,
    required String amount,
    required String subtitle,
    required Color color,
    required IconData icon,
    required double scale,
    bool highlight = false,
  }) {
    final c = context.appColors;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14.0 * scale,
        vertical: 14.0 * scale,
      ),
      decoration: BoxDecoration(
        color: highlight
            ? color.withValues(alpha: context.isDark ? 0.2 : 0.08)
            : c.card,
        borderRadius: BorderRadius.circular(16.0 * scale),
        border: Border.all(
          color: highlight ? color : c.divider,
          width: highlight ? 1.5 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: c.shadowColor,
            blurRadius: 6.0 * scale,
            offset: Offset(0, 2.0 * scale),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5 * scale,
                    fontWeight: FontWeight.w600,
                    color: c.text2,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: EdgeInsets.all(4.0 * scale),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14.0 * scale, color: color),
              ),
            ],
          ),
          SizedBox(height: 8.0 * scale),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: TextStyle(
                fontSize: 19.0 * scale,
                fontWeight: FontWeight.w800,
                color: highlight ? color : c.text1,
              ),
            ),
          ),
          SizedBox(height: 4.0 * scale),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.0 * scale,
              fontWeight: FontWeight.w500,
              color: highlight ? color : c.text2,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SEGMENTED TAB SELECTOR
  // ---------------------------------------------------------------------------

  Widget _buildSegmentedViewSelector(double scale) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14.0 * scale),
      ),
      child: Row(
        children: [
          _buildSegmentButton(0, 'Net Profit & PnL', Icons.balance_rounded, scale),
          _buildSegmentButton(1, 'Revenue', Icons.show_chart_rounded, scale),
          _buildSegmentButton(2, 'Expenses', Icons.pie_chart_outline_rounded, scale),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(
      int index, String label, IconData icon, double scale) {
    final isSel = _activeView == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeView = index;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.0 * scale),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFF1E40AF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10.0 * scale),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: (scale < 0.90 ? 12.0 : 14.0) * scale,
                color: isSel ? Colors.white : context.appColors.text2,
              ),
              SizedBox(width: 4.0 * scale),
              Flexible(
                child: Text(
                  (scale < 0.90 && index == 0) ? 'PnL' : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: (scale < 0.90 ? 10.5 : 11.5) * scale,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    color: isSel ? Colors.white : context.appColors.text2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CHART VIEW
  // ---------------------------------------------------------------------------

  Widget _buildChartView(double scale, double chartHeight) {
    final c = context.appColors;

    return Column(
      children: [
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('Revenue', const Color(0xFF2563EB), scale),
            SizedBox(width: 14 * scale),
            if (_activeView == 0) ...[
              _buildLegendItem('Expenses', const Color(0xFFF43F5E), scale),
              SizedBox(width: 14 * scale),
              _buildLegendItem('Net Profit', const Color(0xFF10B981), scale),
            ],
          ],
        ),
        SizedBox(height: 12.0 * scale),

        // Line Chart
        SizedBox(
          height: chartHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartWidth = salesData.length > 5
                  ? salesData.length * (54.0 * scale) + 64.0 * scale
                  : constraints.maxWidth;

              return SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: salesData.length > 5
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                child: Container(
                  width: chartWidth,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.0 * scale,
                    vertical: 8.0 * scale,
                  ),
                  child: LineChart(
                    duration: const Duration(milliseconds: 200),
                    LineChartData(
                      minX: 0,
                      maxX: (monthLabels.length - 1).toDouble().clamp(0.0, 120.0),
                      minY: minYValue,
                      maxY: maxYValue,
                      lineTouchData: LineTouchData(
                        handleBuiltInTouches: true,
                        touchSpotThreshold: 25,
                        getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                          return spotIndexes.map((spotIndex) {
                            return TouchedSpotIndicatorData(
                              FlLine(
                                color: c.text2.withValues(alpha: 0.4),
                                strokeWidth: 1.2,
                                dashArray: [4, 4],
                              ),
                              FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 5,
                                    color: barData.color ?? const Color(0xFF2563EB),
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  );
                                },
                              ),
                            );
                          }).toList();
                        },
                        touchTooltipData: LineTouchTooltipData(
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          maxContentWidth: 260,
                          tooltipBorderRadius: BorderRadius.circular(10),
                          tooltipBorder: const BorderSide(
                            color: Color(0xFF334155),
                            width: 1,
                          ),
                          tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          getTooltipColor: (touchedSpot) =>
                              const Color(0xFF0F172A),
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              String label = 'Revenue';
                              Color textColor = const Color(0xFF60A5FA);
                              if (spot.barIndex == 1) {
                                label = 'Expense';
                                textColor = const Color(0xFFFB7185);
                              }
                              if (spot.barIndex == 2) {
                                label = 'Net Profit';
                                textColor = spot.y >= 0
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFFF87171);
                              }

                              final formattedPrice = NumberFormat.currency(
                                locale: 'en_IN',
                                symbol: '₹',
                                decimalDigits: 0,
                              ).format(spot.y);

                              return LineTooltipItem(
                                '$label: $formattedPrice',
                                TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: _buildChartLines(scale),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1.0,
                            reservedSize: 28.0 * scale,
                            getTitlesWidget: (value, meta) {
                              int index = value.toInt();
                              if (index >= 0 && index < monthLabels.length) {
                                return Padding(
                                  padding: EdgeInsets.only(top: 8.0 * scale),
                                  child: Text(
                                    monthLabels[index],
                                    style: TextStyle(
                                      fontSize: 11.5 * scale,
                                      color: c.text2,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxYValue > 0 ? maxYValue / 4 : 25,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: c.divider.withValues(alpha: 0.5),
                          strokeWidth: 0.8,
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(bottom: BorderSide(color: c.divider)),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<LineChartBarData> _buildChartLines(double scale) {
    if (_activeView == 1) {
      // Revenue Only
      return [
        LineChartBarData(
          spots: salesData,
          isCurved: true,
          color: const Color(0xFF2563EB),
          barWidth: 3 * scale,
          isStrokeCapRound: true,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
          ),
        ),
      ];
    }

    // Net Profit & PnL View (Revenue + Expense + Profit)
    return [
      // 1. Revenue Line
      LineChartBarData(
        spots: salesData,
        isCurved: true,
        color: const Color(0xFF2563EB),
        barWidth: 2.5 * scale,
        dotData: FlDotData(show: false),
      ),
      // 2. Expenses Line
      LineChartBarData(
        spots: expenseData,
        isCurved: true,
        color: const Color(0xFFF43F5E),
        barWidth: 2.2 * scale,
        dashArray: [5, 4],
        dotData: FlDotData(show: false),
      ),
      // 3. Net Profit Line
      LineChartBarData(
        spots: profitData,
        isCurved: true,
        color: const Color(0xFF10B981),
        barWidth: 3.2 * scale,
        isStrokeCapRound: true,
        dotData: FlDotData(show: true),
        belowBarData: BarAreaData(
          show: true,
          color: const Color(0xFF10B981).withValues(alpha: 0.14),
        ),
      ),
    ];
  }

  Widget _buildLegendItem(String title, Color color, double scale) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8 * scale,
          height: 8 * scale,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 5 * scale),
        Text(
          title,
          style: TextStyle(
            fontSize: 11 * scale,
            fontWeight: FontWeight.w600,
            color: context.appColors.text2,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // EXPENSE CATEGORY BREAKDOWN VIEW
  // ---------------------------------------------------------------------------

  Widget _buildCategoryBreakdownView(double scale) {
    final c = context.appColors;

    if (categoryDistribution.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inventory_2_outlined, size: 36, color: c.text2),
              const SizedBox(height: 8),
              Text(
                'No expenses logged in this range',
                style: TextStyle(color: c.text2, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _navigateToExpenses,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add an Expense'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E40AF),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalExp = rangeExpense > 0 ? rangeExpense : 1.0;
    final sortedCats = categoryDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Spending by Category",
          style: TextStyle(
            fontSize: 13 * scale,
            fontWeight: FontWeight.bold,
            color: c.text1,
          ),
        ),
        SizedBox(height: 12 * scale),
        ...sortedCats.map((entry) {
          final catInfo = ExpensesPage.getCategoryInfo(entry.key);
          final percent = (entry.value / totalExp) * 100;

          return Padding(
            padding: EdgeInsets.symmetric(vertical: 6.0 * scale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(catInfo.icon, size: 15 * scale, color: catInfo.color),
                    SizedBox(width: 8 * scale),
                    Expanded(
                      child: Text(
                        entry.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5 * scale,
                          fontWeight: FontWeight.w600,
                          color: c.text1,
                        ),
                      ),
                    ),
                    Text(
                      '₹${entry.value.toStringAsFixed(0)} (${percent.toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontSize: 12.0 * scale,
                        fontWeight: FontWeight.bold,
                        color: c.text2,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 5 * scale),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (percent / 100).clamp(0.0, 1.0),
                    backgroundColor: c.divider.withValues(alpha: 0.4),
                    valueColor: AlwaysStoppedAnimation<Color>(catInfo.color),
                    minHeight: 6 * scale,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    String value,
    IconData icon,
    Color color,
    double scale,
  ) {
    return PopupMenuItem<String>(
      value: value,
      height: 40.0 * scale,
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            padding: EdgeInsets.all(6.0 * scale),
            child: Icon(icon, size: 16.0 * scale, color: color),
          ),
          SizedBox(width: 12.0 * scale),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.0 * scale,
              fontWeight: FontWeight.w500,
              color: context.appColors.text1,
            ),
          ),
        ],
      ),
    );
  }
}
