// ignore_for_file: use_build_context_synchronously
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
  final String userEmail;

  const RentalCustomersPage({Key? key, required this.userEmail})
    : super(key: key);

  @override
  State<RentalCustomersPage> createState() => _RentalCustomersPageState();
}

class _RentalCustomersPageState extends State<RentalCustomersPage> {
  late Box<CustomerModel> customerBox;
  Box? userBox;
  String _searchQuery = "";
  bool _isLoading = true;

  List<CustomerModel> customers = [];
  List<CustomerModel> allCustomers = []; // FULL backup list (important)

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  // ---------------------------------------------------------------------------
  // ⭐ LOAD CUSTOMERS
  // ---------------------------------------------------------------------------
  Future<void> _loadCustomers() async {
    try {
      if (!Hive.isBoxOpen('customers')) {
        await Hive.openBox<CustomerModel>('customers');
      }
      customerBox = Hive.box<CustomerModel>('customers');

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

      // ✅ Load from USER box first (highest priority)
      if (userBox != null && userBox!.containsKey("customers")) {
        loaded = List<CustomerModel>.from(
          userBox!.get("customers", defaultValue: []),
        );
      }

      // ✅ Fallback to global box
      if (loaded.isEmpty) {
        loaded = customerBox.values.toList();
      }

      // ✅ HARD DEDUPLICATION (by phone number)
      final Map<String, CustomerModel> uniqueCustomers = {};

      for (final customer in loaded) {
        final phoneKey = customer.phone.trim();

        // Keep the MOST RECENT customer entry
        if (!uniqueCustomers.containsKey(phoneKey) ||
            customer.createdAt.isAfter(uniqueCustomers[phoneKey]!.createdAt)) {
          uniqueCustomers[phoneKey] = customer;
        }
      }

      final dedupedList =
          uniqueCustomers.values.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // ✅ Persist cleaned list back (self-healing)
      if (userBox != null) {
        await userBox!.put("customers", dedupedList);
      }

      if (!mounted) return;

      setState(() {
        allCustomers = dedupedList;
        customers = List.from(allCustomers);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: 'Error loading customers: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // ⭐ DELETE CUSTOMER
  // ---------------------------------------------------------------------------
  Future<void> _deleteCustomer(int index) async {
    // Defensive: ensure index valid
    if (index < 0 || index >= customers.length) return;

    final customer = customers[index];

    try {
      // USER BOX delete
      if (userBox != null) {
        List<CustomerModel> userCustomers = [];
        try {
          userCustomers = List<CustomerModel>.from(
            userBox!.get("customers", defaultValue: []),
          );
        } catch (_) {
          userCustomers = [];
        }

        userCustomers.removeWhere(
          (c) =>
              c.name == customer.name &&
              c.phone == customer.phone &&
              c.createdAt == customer.createdAt,
        );

        await userBox!.put("customers", userCustomers);
      }

      // MAIN BOX delete
      final mainList = customerBox.values.toList();
      final mainIndex = mainList.indexWhere(
        (c) =>
            c.name == customer.name &&
            c.phone == customer.phone &&
            c.createdAt == customer.createdAt,
      );

      if (mainIndex != -1) await customerBox.deleteAt(mainIndex);

      // SAFETY: ensure widget still mounted before updating UI
      if (!mounted) return;

      // DELETE from UI lists
      setState(() {
        allCustomers.removeWhere(
          (c) =>
              c.name == customer.name &&
              c.phone == customer.phone &&
              c.createdAt == customer.createdAt,
        );
        customers.removeAt(index);
      });

      await _deleteCustomerRentalSales(customer.name, customer.phone);

      if (!mounted) return;
      AppSnackBar.showSuccess(context, message: "${customer.name} deleted");
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          message: 'Failed to delete customer: $e',
        );
      }
    }
  }

  Future<void> _deleteCustomerRentalSales(
    String customerName,
    String customerPhone,
  ) async {
    if (userBox == null) return;

    try {
      final raw = userBox!.get('rental_sales', defaultValue: []);
      List<RentalSaleModel> rentalSales =
          (raw as List).map((e) => e as RentalSaleModel).toList();

      rentalSales.removeWhere(
        (s) =>
            s.customerName == customerName && s.customerPhone == customerPhone,
      );

      await userBox!.put('rental_sales', rentalSales);
    } catch (e) {
      // best-effort; log
      debugPrint("Error deleting rental sales of customer: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // SEARCH HANDLER
  // ---------------------------------------------------------------------------
  void _handleSearchChanged(String query) {
    _searchQuery = query; // ⭐ Track the active search text

    if (query.isEmpty) {
      setState(() {
        customers = List.from(allCustomers);
      });
      return;
    }

    setState(() {
      customers =
          allCustomers.where((c) {
            return c.name.toLowerCase().contains(query.toLowerCase()) ||
                c.phone.toLowerCase().contains(query.toLowerCase());
          }).toList();
    });
  }

  // Required by widget
  void _handleDateRangeChanged(DateTimeRange? range) {}

  // ---------------------------------------------------------------------------
  // CONFIRM DELETE
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
  // UI BUILDERS (NO CHANGE)
  // ---------------------------------------------------------------------------
  Widget _buildCustomerCard(CustomerModel customer, int index) {
    // Responsive calculations inside the widget (no function changes)
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600 && screenWidth < 1000;
    final isDesktop = screenWidth >= 1000;
    final isSmallPhone = screenWidth < 360;

    final avatarSize =
        isDesktop ? 84.0 : (isTablet ? 72.0 : (isSmallPhone ? 56.0 : 70.0));
    final horizontalPadding = isDesktop ? 28.0 : (isTablet ? 10.0 : 8.0);
    final titleFont =
        isDesktop ? 22.0 : (isTablet ? 20.0 : (isSmallPhone ? 16.0 : 20.0));
    final subtitleFont = isDesktop ? 16.0 : (isTablet ? 15.0 : 14.0);

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
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
      child: Dismissible(
        key: Key(
          '${customer.name}_${customer.phone}_${customer.createdAt.millisecondsSinceEpoch}',
        ),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async => await _confirmDelete(customer),
        onDismissed: (_) {
          // onDismissed fires after the dismiss animation completes.
          // We call _deleteCustomer which mutates data and state (it has its own mounted checks).
          _deleteCustomer(index);
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 25),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade500, Colors.red.shade700],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.delete_forever_rounded,
                color: Colors.white,
                size: isDesktop ? 40 : 32,
              ),
              SizedBox(height: isDesktop ? 6 : 4),
              Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: isDesktop ? 16 : 14,
                ),
              ),
            ],
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 1100 : double.infinity,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colorPair,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
              boxShadow: [
                BoxShadow(
                  color: colorPair[0].withOpacity(0.35),
                  blurRadius: isDesktop ? 22 : 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                if (isDesktop)
                  Positioned(
                    right: -30,
                    top: -30,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                  )
                else
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.all(isDesktop ? 17.0 : 15.0),
                  child: Row(
                    children: [
                      Container(
                        width: avatarSize,
                        height: avatarSize,
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
                            customer.name.isNotEmpty
                                ? customer.name[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: (avatarSize * 0.45).clamp(16.0, 36.0),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: isDesktop ? 24 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              style: TextStyle(
                                fontSize: titleFont,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            SizedBox(height: isDesktop ? 10 : 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone,
                                  color: Colors.white70,
                                  size: subtitleFont,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    customer.phone,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: subtitleFont,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isDesktop ? 8 : 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_month,
                                  color: Colors.white70,
                                  size: subtitleFont - 1,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  DateFormat(
                                    'MMM dd, yyyy',
                                  ).format(customer.createdAt),
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: (subtitleFont - 1).clamp(
                                      12.0,
                                      16.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: isDesktop ? 18 : 12),
                      Container(
                        width: isDesktop ? 48 : 40,
                        height: isDesktop ? 48 : 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.22),
                        ),
                        child: Icon(
                          Icons.drag_handle,
                          color: Colors.white,
                          size: isDesktop ? 22 : 18,
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
  }

  Widget _buildNoMatchState(String query) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade500),
          const SizedBox(height: 16),
          Text(
            "No matching results",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Nothing found for \"$query\"",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI - EMPTY
  // ---------------------------------------------------------------------------
  Widget _buildEmptyState() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTabletOrDesktop = screenWidth > 700;
    final maxWidth = isTabletOrDesktop ? 500.0 : double.infinity;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isTabletOrDesktop ? 160 : 120,
              height: isTabletOrDesktop ? 160 : 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: isTabletOrDesktop ? 70 : 50,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "No Customers Yet",
              style: TextStyle(
                fontSize: isTabletOrDesktop ? 22 : 20,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Add your first customer to start tracking rentals and sales.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isTabletOrDesktop ? 16 : 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isVeryWide = screenWidth > 1100;
    final maxContentWidth =
        isVeryWide ? 1100.0 : (screenWidth > 800 ? 900.0 : screenWidth);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MediaQuery.removePadding(
        removeTop: true,
        context: context,
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),

              // ⭐ FIX: Search bar ALWAYS visible
              child: Column(
                children: [
                  AdvancedSearchBar(
                    hintText: 'Search customers...',
                    onSearchChanged: _handleSearchChanged,
                    onDateRangeChanged: _handleDateRangeChanged,
                    showDateFilter: false,
                  ),

                  // ⭐ SUMMARY / COUNT
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isVeryWide ? 32 : 24,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        double w = constraints.maxWidth;
                        double scale =
                            w < 360
                                ? 0.75
                                : w < 480
                                ? 0.85
                                : w < 700
                                ? 0.95
                                : 1.1;

                        return Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10 * scale,
                                vertical: 6 * scale,
                              ),
                              constraints: BoxConstraints(
                                minWidth: 20 * scale,
                                maxWidth: 60 * scale,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30 * scale),
                                border: Border.all(
                                  color: Colors.grey,
                                  width: 1.2 * scale,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_alt_rounded,
                                    size: 16 * scale,
                                    color: Colors.black87,
                                  ),
                                  SizedBox(width: 4 * scale),
                                  Text(
                                    '${customers.length}',
                                    style: TextStyle(
                                      fontSize: 14 * scale,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(width: 12 * scale),

                            Expanded(child: SizedBox()),
                          ],
                        );
                      },
                    ),
                  ),

                  // ⭐ LIST AREA — only this part changes based on data
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isVeryWide ? 20 : 0,
                      ),
                      child:
                          _isLoading
                              ? _buildLoadingState()
                              : customers.isEmpty
                              ? (_searchQuery.isNotEmpty
                                  ? _buildNoMatchState(_searchQuery)
                                  : _buildEmptyState())
                              : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 20),
                                itemCount: customers.length,
                                itemBuilder: (context, index) {
                                  return _buildCustomerCard(
                                    customers[index],
                                    index,
                                  );
                                },
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
}
