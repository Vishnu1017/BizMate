// ignore_for_file: use_build_context_synchronously
import 'package:bizmate/models/rental_sale_model.dart' show RentalSaleModel;
import 'package:bizmate/widgets/advanced_search_bar.dart'
    show AdvancedSearchBar;
import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:bizmate/widgets/confirm_delete_dialog.dart'
    show showConfirmDialog;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/customer_model.dart';

class RentalCustomersPage extends StatefulWidget {
  final String userEmail;

  const RentalCustomersPage({super.key, required this.userEmail});

  @override
  State<RentalCustomersPage> createState() => _RentalCustomersPageState();
}

class _RentalCustomersPageState extends State<RentalCustomersPage> {
  late Box<CustomerModel> customerBox;
  Box? userBox;
  String _searchQuery = "";
  bool _isLoading = true;
  double scale = 1.0;
  final ScrollController _scrollController = ScrollController();
  int _previousCustomerCount = 0;

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

      // 🔥 AUTO SCROLL WHEN NEW CUSTOMER ADDED
      if (dedupedList.length > _previousCustomerCount) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }

      _previousCustomerCount = dedupedList.length;

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

  void _makePhoneCall(String phone) async {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');

    if (!cleaned.startsWith('+') && cleaned.length == 10) {
      cleaned = '+91$cleaned';
    }

    final uri = Uri.parse('tel:$cleaned');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        AppSnackBar.showError(context, message: "Couldn't open dialer");
      }
    }
  }

  void _openWhatsApp(String phone, String name, {String? purpose}) async {
    try {
      String raw = phone.replaceAll(RegExp(r'[^\d+]'), '');
      String waPhone;

      if (raw.startsWith('+')) {
        waPhone = raw.substring(1);
      } else if (raw.length == 10) {
        waPhone = '91$raw';
      } else {
        waPhone = raw;
      }

      if (waPhone.length < 10) {
        AppSnackBar.showWarning(context, message: "Invalid phone number");
        return;
      }

      late String message;

      switch (purpose) {
        case 'payment_received':
          message =
              "Hello $name,\n\n"
              "We have successfully received your rental payment.\n\n"
              "Thank you for choosing us.\n\n"
              "Warm regards.";
          break;

        case 'rental_due':
          message =
              "Hello $name,\n\n"
              "This is a friendly reminder that your rental payment is due.\n\n"
              "Please let us know if you need any assistance.\n\n"
              "Thank you.";
          break;

        case 'booking_confirmation':
          message =
              "Hello $name,\n\n"
              "Your rental booking has been successfully confirmed.\n\n"
              "We look forward to serving you.\n\n"
              "Thank you.";
          break;

        default:
          message =
              "Hello $name,\n\n"
              "How can we assist you today?\n\n"
              "Thank you.";
      }

      final encoded = Uri.encodeComponent(message);
      final uri = Uri.parse("https://wa.me/$waPhone?text=$encoded");

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception("WhatsApp not available");
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.showError(context, message: "Couldn't open WhatsApp");
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
    final horizontalPadding = isDesktop ? 32.0 : (isTablet ? 14.0 : 12.0);
    final titleFont = 14 * scale;
    final subtitleFont = 12 * scale;

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
          padding: EdgeInsets.symmetric(horizontal: 25 * scale),
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
                size: 26 * scale,
              ),
              SizedBox(height: 4 * scale),
              Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12 * scale,
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
              borderRadius: BorderRadius.circular(12 * scale),
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
                      width: 140 * scale,
                      height: 140 * scale,
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
                      width: 100 * scale,
                      height: 100 * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14 * scale,
                    vertical: 20 * scale,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 45 * scale,
                        height: 45 * scale,
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
                              fontSize: (avatarSize * 0.25).clamp(16.0, 36.0),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 14 * scale),
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
                            SizedBox(height: 6 * scale),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone,
                                  color: Colors.white70,
                                  size: subtitleFont,
                                ),
                                SizedBox(width: 6 * scale),
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
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.phone,
                              color: Colors.white,
                              size: 18 * scale,
                            ),
                            onPressed: () => _makePhoneCall(customer.phone),
                          ),

                          PopupMenuButton<String>(
                            icon: FaIcon(
                              FontAwesomeIcons.whatsapp,
                              color: Colors.white,
                              size: 18 * scale,
                            ),
                            onSelected: (value) {
                              _openWhatsApp(
                                customer.phone,
                                customer.name,
                                purpose: value,
                              );
                            },
                            itemBuilder:
                                (context) => [
                                  PopupMenuItem(
                                    value: 'default',
                                    child: Row(
                                      children: const [
                                        Icon(Icons.chat, color: Colors.blue),
                                        SizedBox(width: 8),
                                        Text("General Inquiry"),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'booking_confirmation',
                                    child: Row(
                                      children: const [
                                        Icon(
                                          Icons.event_available,
                                          color: Colors.indigo,
                                        ),
                                        SizedBox(width: 8),
                                        Text("Booking Confirmation"),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'payment_received',
                                    child: Row(
                                      children: const [
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                        ),
                                        SizedBox(width: 8),
                                        Text("Payment Received"),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'rental_due',
                                    child: Row(
                                      children: const [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.orange,
                                        ),
                                        SizedBox(width: 8),
                                        Text("Rental Due Reminder"),
                                      ],
                                    ),
                                  ),
                                ],
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
                    padding: EdgeInsets.symmetric(horizontal: 24 * scale),
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
                                minWidth: 12 * scale,
                                maxWidth: 45 * scale,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20 * scale),
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
                                    size: 12 * scale,
                                    color: Colors.black87,
                                  ),
                                  SizedBox(width: 4 * scale),
                                  Text(
                                    '${customers.length}',
                                    style: TextStyle(
                                      fontSize: 10 * scale,
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
                                controller: _scrollController,
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
