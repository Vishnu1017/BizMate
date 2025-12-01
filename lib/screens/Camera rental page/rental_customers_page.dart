import 'dart:ui';
import 'package:bizmate/models/rental_sale_model.dart' show RentalSaleModel;
import 'package:bizmate/widgets/advanced_search_bar.dart'
    show AdvancedSearchBar;
import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:bizmate/widgets/confirm_delete_dialog.dart'
    show showConfirmDialog;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../../../models/customer_model.dart';

class RentalCustomersPage extends StatefulWidget {
  final String userEmail; // ✅ FIXED

  const RentalCustomersPage({
    Key? key,
    required this.userEmail, // <-- REQUIRED and stored
  }) : super(key: key);

  @override
  State<RentalCustomersPage> createState() => _RentalCustomersPageState();
}

class _RentalCustomersPageState extends State<RentalCustomersPage> {
  late Box<CustomerModel> customerBox;
  Box? userBox;
  bool _isLoading = true;
  List<CustomerModel> customers = [];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  // ---------------------------------------------------------------------------
  // ⭐ LOAD CUSTOMERS (USER-SPECIFIC FIRST)
  // ---------------------------------------------------------------------------
  Future<void> _loadCustomers() async {
    try {
      // Open main box
      if (!Hive.isBoxOpen('customers')) {
        await Hive.openBox<CustomerModel>('customers');
      }
      customerBox = Hive.box<CustomerModel>('customers');

      // Build user-specific box
      final safeEmail = widget.userEmail
          .replaceAll('.', '_')
          .replaceAll('@', '_');

      final boxName = "userdata_$safeEmail";

      if (!Hive.isBoxOpen(boxName)) {
        userBox = await Hive.openBox(boxName);
      } else {
        userBox = Hive.box(boxName);
      }

      List<CustomerModel> loaded = [];

      // Load USER-SPECIFIC customers first
      if (userBox != null && userBox!.containsKey("customers")) {
        try {
          loaded = List<CustomerModel>.from(
            userBox!.get("customers", defaultValue: []),
          );
        } catch (_) {
          loaded = [];
        }
      }

      // If none found, fallback to global main box
      if (loaded.isEmpty) {
        loaded = customerBox.values.toList();
      }

      setState(() {
        customers = loaded.reversed.toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading customers: $e');
      setState(() => _isLoading = false);
      AppSnackBar.showError(
        context,
        message: 'Error loading customers: $e',
        duration: const Duration(seconds: 2),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // ⭐ DELETE CUSTOMER (USER-SPECIFIC + MAIN BOX)
  // ---------------------------------------------------------------------------
  Future<void> _deleteCustomer(int index) async {
    final customer = customers[index];

    try {
      // ---------------------
      // DELETE FROM USER BOX
      // ---------------------
      if (userBox != null) {
        List<CustomerModel> userCustomers = [];

        try {
          userCustomers = List<CustomerModel>.from(
            userBox!.get("customers", defaultValue: []),
          );
        } catch (_) {
          userCustomers = [];
        }

        // Remove matching
        userCustomers.removeWhere(
          (c) =>
              c.name == customer.name &&
              c.phone == customer.phone &&
              c.createdAt == customer.createdAt,
        );

        await userBox!.put("customers", userCustomers);
      }

      // ---------------------
      // DELETE FROM MAIN customers BOX
      // ---------------------
      final allMainCustomers = customerBox.values.toList();
      final mainIndex = allMainCustomers.indexWhere(
        (c) =>
            c.name == customer.name &&
            c.phone == customer.phone &&
            c.createdAt == customer.createdAt,
      );

      if (mainIndex != -1) {
        await customerBox.deleteAt(mainIndex);
      }

      // Remove customer from UI list
      setState(() {
        customers.removeAt(index);
      });

      // ALSO delete rental sales of this customer
      await _deleteCustomerRentalSales(customer.name, customer.phone);

      AppSnackBar.showSuccess(
        context,
        message: '${customer.name} deleted successfully',
        duration: Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint('Error deleting customer: $e');
      AppSnackBar.showError(
        context,
        message: 'Failed to delete customer: $e',
        duration: const Duration(seconds: 2),
      );
    }
  }

  Future<void> _deleteCustomerRentalSales(
    String customerName,
    String customerPhone,
  ) async {
    try {
      if (userBox == null) return;

      // Load existing rental sales
      final raw = userBox!.get('rental_sales', defaultValue: []);
      List<RentalSaleModel> rentalSales =
          (raw as List).map((e) => e as RentalSaleModel).toList();

      // Remove sales belonging to this customer
      rentalSales.removeWhere(
        (sale) =>
            sale.customerName == customerName &&
            sale.customerPhone == customerPhone,
      );

      await userBox!.put('rental_sales', rentalSales);

      debugPrint("✓ Rental sales deleted for $customerName");
    } catch (e) {
      debugPrint("Error deleting rental sales of customer: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // SEARCH HANDLER
  // ---------------------------------------------------------------------------
  void _handleSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        // Reload original list
        _loadCustomers();
        return;
      }

      customers =
          customers.where((c) {
            return c.name.toLowerCase().contains(query.toLowerCase()) ||
                c.phone.toLowerCase().contains(query.toLowerCase());
          }).toList();
    });
  }

  // ---------------------------------------------------------------------------
  // DATE RANGE HANDLER (NOT USED HERE BUT REQUIRED BY WIDGET)
  // ---------------------------------------------------------------------------
  void _handleDateRangeChanged(DateTimeRange? range) {
    // NO DATE FILTER FOR CUSTOMERS — but function must exist
  }

  // ---------------------------------------------------------------------------
  // ⭐ SWEET CONFIRMATION POPUP
  // ---------------------------------------------------------------------------
  Future<bool> _confirmDelete(CustomerModel customer) async {
    bool confirmed = false;

    await showConfirmDialog(
      context: context,
      title: "Delete Customer?",
      message: "Are you sure you want to remove ${customer.name}?",
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.redAccent,
      onConfirm: () {
        confirmed = true;
      },
    );

    return confirmed;
  }

  // ---------------------------------------------------------------------------
  // ⭐ CUSTOMER CARD WIDGET
  // ---------------------------------------------------------------------------
  Widget _buildCustomerCard(CustomerModel customer, int index) {
    final blueShades = [
      [Color(0xFF3B82F6), Color(0xFF2563EB)],
      [Color(0xFF60A5FA), Color(0xFF3B82F6)],
      [Color(0xFF1E40AF), Color(0xFF1E3A8A)],
      [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
      [Color(0xFF0EA5E9), Color(0xFF0284C7)],
      [Color(0xFF1E3A8A), Color(0xFF3730A3)],
    ];

    final colorPair = blueShades[index % blueShades.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),

      // DELETE SWIPE
      child: Dismissible(
        key: Key(
          '${customer.name}_${customer.phone}_${customer.createdAt.millisecondsSinceEpoch}',
        ),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async => await _confirmDelete(customer),
        onDismissed: (_) => _deleteCustomer(index),

        background: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 25),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade500, Colors.red.shade700],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_forever_rounded, color: Colors.white, size: 32),
              SizedBox(height: 4),
              Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colorPair,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colorPair[0].withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),

              // CONTENT
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          customer.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 20),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.phone,
                                color: Colors.white70,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                customer.phone,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_month,
                                color: Colors.white70,
                                size: 14,
                              ),
                              SizedBox(width: 6),
                              Text(
                                DateFormat(
                                  'MMM dd, yyyy',
                                ).format(customer.createdAt),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Menu Icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.25),
                      ),
                      child: Icon(Icons.more_vert, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI - EMPTY
  // ---------------------------------------------------------------------------
  Widget _buildEmptyState() {
    return Center(
      child: Text(
        "No Customers Yet",
        style: TextStyle(fontSize: 22, color: Colors.grey),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI - LOADING
  // ---------------------------------------------------------------------------
  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  // ---------------------------------------------------------------------------
  // ⭐ BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body:
          _isLoading
              ? _buildLoadingState()
              : customers.isEmpty
              ? _buildEmptyState()
              : Column(
                children: [
                  AdvancedSearchBar(
                    hintText: 'Search customers...',
                    onSearchChanged: _handleSearchChanged,
                    onDateRangeChanged: _handleDateRangeChanged,
                    showDateFilter:
                        false, // No date filter needed for customers page
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${customers.length} Customers',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: customers.length,
                      itemBuilder: (context, index) {
                        return _buildCustomerCard(customers[index], index);
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}
