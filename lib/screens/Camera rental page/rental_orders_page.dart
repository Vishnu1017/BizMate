import 'package:bizmate/models/rental_sale_model.dart';
import 'package:bizmate/widgets/advanced_search_bar.dart'
    show AdvancedSearchBar;
import 'package:bizmate/widgets/confirm_delete_dialog.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class RentalOrdersPage extends StatefulWidget {
  final String userEmail;

  const RentalOrdersPage({super.key, required this.userEmail});

  @override
  State<RentalOrdersPage> createState() => _RentalOrdersPageState();
}

class _RentalOrdersPageState extends State<RentalOrdersPage> {
  late Box userBox;

  List<RentalSaleModel> allOrders = [];
  List<RentalSaleModel> filteredOrders = [];

  String _searchQuery = "";
  String _statusFilter = "All";

  final List<String> filters = [
    "All",
    "Fully Paid",
    "Partially Paid",
    "Unpaid",
  ];
  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'Fully Paid':
        return Icons.check_circle_outline;
      case 'Partially Paid':
        return Icons.timelapse_rounded;
      case 'Unpaid':
        return Icons.error_outline;
      default:
        return Icons.filter_list_rounded;
    }
  }

  late final VoidCallback _rentalSalesListener;

  @override
  void initState() {
    super.initState();
    _loadUserBox();
  }

  Future<void> _loadUserBox() async {
    final safeEmail = widget.userEmail
        .replaceAll(".", "_")
        .replaceAll("@", "_");

    final boxName = "userdata_$safeEmail";

    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }

    userBox = Hive.box(boxName);

    _loadOrders();

    _rentalSalesListener = () {
      if (!mounted) return;
      _loadOrders();
    };

    userBox
        .listenable(keys: ['rental_sales'])
        .addListener(_rentalSalesListener);
  }

  @override
  void dispose() {
    try {
      userBox
          .listenable(keys: ['rental_sales'])
          .removeListener(_rentalSalesListener);
    } catch (_) {}
    super.dispose();
  }

  void _loadOrders() {
    final raw = userBox.get('rental_sales', defaultValue: []);
    allOrders = List<RentalSaleModel>.from(raw);
    _applyFilters();
    setState(() {});
  }

  void _applyFilters() {
    List<RentalSaleModel> temp = List.from(allOrders);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();

      temp =
          temp.where((o) {
            return o.customerName.toLowerCase().contains(q) ||
                o.itemName.toLowerCase().contains(q) ||
                o.customerPhone.contains(q);
          }).toList();
    }

    if (_statusFilter == "Fully Paid") {
      temp = temp.where((o) => o.amountPaid >= o.totalCost).toList();
    } else if (_statusFilter == "Partially Paid") {
      temp =
          temp
              .where((o) => o.amountPaid > 0 && o.amountPaid < o.totalCost)
              .toList();
    } else if (_statusFilter == "Unpaid") {
      temp = temp.where((o) => o.amountPaid == 0).toList();
    }

    filteredOrders = temp;
  }

  void _deleteOrder(int index) {
    showConfirmDialog(
      context: context,
      title: "Delete Order?",
      message: "Are you sure you want to permanently delete this order?",
      icon: Icons.delete_forever_rounded,
      iconColor: Colors.redAccent,
      onConfirm: () {
        final raw = userBox.get('rental_sales', defaultValue: []);
        List<RentalSaleModel> updatedList = List<RentalSaleModel>.from(raw);
        updatedList.removeAt(index);
        userBox.put('rental_sales', updatedList);
      },
    );
  }

  void _handleSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim();
      _applyFilters();
    });
  }

  void _handleDateRangeChanged(DateTimeRange? range) {}

  Color _statusColor(RentalSaleModel o) {
    if (o.amountPaid >= o.totalCost) return const Color(0xFF10B981);
    if (o.amountPaid == 0) return const Color(0xFFEF4444);
    return const Color(0xFFF59E0B);
  }

  String _statusLabel(RentalSaleModel o) {
    if (o.amountPaid >= o.totalCost) return "Fully Paid";
    if (o.amountPaid == 0) return "Unpaid";
    return "Partially Paid";
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    double scale =
        w < 360
            ? 0.78
            : w < 480
            ? 0.90
            : w < 700
            ? 1.00
            : w < 1100
            ? 1.15
            : 1.25;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MediaQuery.removePadding(
        removeTop: true,
        context: context,
        child: Column(
          children: [
            AdvancedSearchBar(
              hintText: 'Search orders...',
              onSearchChanged: _handleSearchChanged,
              onDateRangeChanged: _handleDateRangeChanged,
              showDateFilter: false,
            ),

            SizedBox(
              height: 35 * scale,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 14 * scale),
                itemCount: filters.length,
                separatorBuilder: (_, __) => SizedBox(width: 8 * scale),
                itemBuilder: (context, i) {
                  final filter = filters[i];
                  final selected = _statusFilter == filter;

                  return GestureDetector(
                    onTap: () {
                      _statusFilter = filter;
                      _applyFilters();
                      setState(() {});
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30 * scale),
                        gradient:
                            selected
                                ? const LinearGradient(
                                  colors: [
                                    Color(0xFF2563EB),
                                    Color(0xFF1E40AF),
                                    Color(0xFF020617),
                                  ],
                                  stops: [0.0, 0.6, 1.0],
                                  begin: Alignment.bottomRight,
                                  end: Alignment.topLeft,
                                )
                                : LinearGradient(
                                  colors: [
                                    Colors.grey.shade200,
                                    Colors.grey.shade300,
                                  ],
                                ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          /// ICON — ALWAYS VISIBLE
                          Icon(
                            _getFilterIcon(filter),
                            size: 14 * scale,
                            color:
                                selected ? Colors.white : Colors.grey.shade700,
                          ),
                          SizedBox(width: 6 * scale),

                          /// TEXT
                          Text(
                            filter,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.grey[800],
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 12 * scale,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            SizedBox(height: 8 * scale),

            if (filteredOrders.isNotEmpty) _buildOrderSummary(scale),

            Expanded(
              child:
                  filteredOrders.isEmpty
                      ? _buildEmptyState(scale)
                      : ListView.builder(
                        itemCount: filteredOrders.length,
                        padding: EdgeInsets.symmetric(
                          horizontal: 10 * scale,
                          vertical: 8 * scale,
                        ),
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final order = filteredOrders[index];
                          final originalIndex = allOrders.indexOf(order);

                          return Padding(
                            padding: EdgeInsets.only(bottom: 12 * scale),
                            child: Dismissible(
                              key: Key(order.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: EdgeInsets.only(right: 24 * scale),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(
                                    16 * scale,
                                  ),
                                ),
                                child: Icon(
                                  Icons.delete_rounded,
                                  color: Colors.white,
                                  size: 22 * scale,
                                ),
                              ),
                              confirmDismiss: (_) async {
                                _deleteOrder(originalIndex);
                                return false;
                              },
                              child: _buildOrderCard(
                                order,
                                originalIndex,
                                scale,
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(double scale) {
    final totalAmount = filteredOrders.fold(
      0.0,
      (sum, order) => sum + order.totalCost,
    );
    final paidAmount = filteredOrders.fold(
      0.0,
      (sum, order) => sum + order.amountPaid,
    );
    final pendingAmount = totalAmount - paidAmount;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 6 * scale),
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF), Color(0xFF020617)],
          stops: [0.0, 0.6, 1.0],
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
        ),
        borderRadius: BorderRadius.circular(16 * scale),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E40AF).withOpacity(0.25),
            blurRadius: 10 * scale,
            offset: Offset(0, 5 * scale),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem(
            "Total",
            "₹${totalAmount.toStringAsFixed(0)}",
            Colors.white,
            scale,
          ),
          _summaryItem(
            "Paid",
            "₹${paidAmount.toStringAsFixed(0)}",
            Colors.lightGreenAccent,
            scale,
          ),
          _summaryItem(
            "Pending",
            "₹${pendingAmount.toStringAsFixed(0)}",
            const Color.fromARGB(255, 248, 171, 56),
            scale,
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(
    String label,
    String value,
    Color valueColor,
    double scale,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white, fontSize: 11 * scale),
        ),
        SizedBox(height: 4 * scale),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 16 * scale,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(double scale) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110 * scale,
            height: 110 * scale,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 45 * scale,
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: 18 * scale),
          Text(
            "No Orders Found",
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6 * scale),
          Text(
            "Try adjusting your search or filter",
            style: TextStyle(color: Colors.grey[500], fontSize: 13 * scale),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(RentalSaleModel o, int index, double scale) {
    final statusColor = _statusColor(o);
    final statusLabel = _statusLabel(o);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12 * scale,
            offset: Offset(0, 4 * scale),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16 * scale),
          onTap: () {},
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 14 * scale,
              vertical: 10 * scale,
            ),
            child: Row(
              children: [
                Container(
                  width: 4 * scale,
                  height: 60 * scale,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2 * scale),
                  ),
                ),

                SizedBox(width: 14 * scale),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// NAME + STATUS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            o.customerName,
                            style: TextStyle(
                              fontSize: 16 * scale,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10 * scale,
                              vertical: 4 * scale,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12 * scale),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6 * scale,
                                  height: 6 * scale,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 6 * scale),
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11 * scale,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 8 * scale),

                      Text(
                        o.itemName,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      SizedBox(height: 4 * scale),

                      Text(
                        "${DateFormat('dd MMM yyyy').format(o.fromDateTime)} - "
                        "${DateFormat('dd MMM yyyy').format(o.toDateTime)}",
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12 * scale,
                        ),
                      ),

                      SizedBox(height: 8 * scale),

                      Row(
                        children: [
                          Text(
                            "₹${o.totalCost.toStringAsFixed(0)}",
                            style: TextStyle(
                              fontSize: 16 * scale,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),

                          SizedBox(width: 8 * scale),

                          if (o.amountPaid < o.totalCost)
                            Text(
                              "Paid: ₹${o.amountPaid.toStringAsFixed(0)}",
                              style: TextStyle(
                                color: Colors.green[600],
                                fontSize: 12 * scale,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
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
  }
}
