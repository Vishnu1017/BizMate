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

    // 🔥 SAFE LISTENER FIX
    _rentalSalesListener = () {
      if (!mounted) return; // prevents setState crash
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

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();

      temp =
          temp.where((o) {
            return o.customerName.toLowerCase().contains(q) ||
                o.itemName.toLowerCase().contains(q) ||
                o.customerPhone.contains(q);
          }).toList();
    }

    // Payment status filters
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

  // ---------------------------------------------------------------------------
  // SEARCH HANDLER (CORRECTED FOR RENTAL ORDERS)
  // ---------------------------------------------------------------------------
  void _handleSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim();
      _applyFilters(); // <-- Apply filters again with updated search
    });
  }

  // ---------------------------------------------------------------------------
  // DATE RANGE HANDLER (Not used but required by widget)
  // ---------------------------------------------------------------------------
  void _handleDateRangeChanged(DateTimeRange? range) {
    // No date filter in orders page — function kept empty intentionally.
  }

  // STATUS COLORS
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // 🔍 MODERN SEARCH BAR
          AdvancedSearchBar(
            hintText: 'Search orders...',
            onSearchChanged: _handleSearchChanged,
            onDateRangeChanged: _handleDateRangeChanged,
            showDateFilter: false,
          ),

          // 🔘 MODERN FILTER CHIPS
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final filter = filters[i];
                final selected = _statusFilter == filter;

                return FilterChip(
                  label: Text(
                    filter,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.grey[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  selected: selected,
                  onSelected: (bool value) {
                    _statusFilter = filter;
                    _applyFilters();
                    setState(() {});
                  },
                  backgroundColor: Colors.white,
                  selectedColor: const Color(0xFF3B82F6),
                  checkmarkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color:
                          selected
                              ? const Color(0xFF3B82F6)
                              : Colors.grey[300]!,
                      width: selected ? 0 : 1,
                    ),
                  ),
                  elevation: selected ? 2 : 0,
                  shadowColor: Colors.black.withOpacity(0.1),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // 📊 ORDER SUMMARY
          if (filteredOrders.isNotEmpty) _buildOrderSummary(),

          // 📌 MODERN ORDER LIST
          Expanded(
            child:
                filteredOrders.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                      itemCount: filteredOrders.length,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];
                        final originalIndex = allOrders.indexOf(order);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Dismissible(
                            key: Key(order.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.delete_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            confirmDismiss: (_) async {
                              _deleteOrder(originalIndex);
                              return false;
                            },
                            child: _buildOrderCard(order, originalIndex),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  // 📊 ORDER SUMMARY WIDGET
  Widget _buildOrderSummary() {
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            "Total",
            "₹${totalAmount.toStringAsFixed(0)}",
            Colors.white,
          ),
          _buildSummaryItem(
            "Paid",
            "₹${paidAmount.toStringAsFixed(0)}",
            const Color(0xFF10B981),
          ),
          _buildSummaryItem(
            "Pending",
            "₹${pendingAmount.toStringAsFixed(0)}",
            const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // 🎨 EMPTY STATE DESIGN
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 50,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "No Orders Found",
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Try adjusting your search or filter",
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  // 📦 MODERN ORDER CARD UI
  Widget _buildOrderCard(RentalSaleModel o, int index) {
    final statusColor = _statusColor(o);
    final statusLabel = _statusLabel(o);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Add onTap functionality here
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Status Indicator
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),

                // Order Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            o.customerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        o.itemName,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${DateFormat('dd MMM yyyy').format(o.fromDateTime)} - ${DateFormat('dd MMM yyyy').format(o.toDateTime)}",
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            "₹${o.totalCost.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (o.amountPaid < o.totalCost)
                            Text(
                              "Paid: ₹${o.amountPaid.toStringAsFixed(0)}",
                              style: TextStyle(
                                color: Colors.green[600],
                                fontSize: 12,
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
