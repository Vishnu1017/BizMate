// ignore_for_file: unused_local_variable, unnecessary_null_comparison

import 'package:bizmate/models/sale.dart';
import 'package:bizmate/models/user_model.dart';
import 'package:bizmate/screens/WhatsAppHelper.dart';
import 'package:bizmate/screens/sale_detail_screen.dart';
import 'package:bizmate/widgets/advanced_search_bar.dart'
    show AdvancedSearchBar;
import 'package:bizmate/widgets/sale_options_menu.dart' show SaleOptionsMenu;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.userEmail,
    required this.userName,
    required this.userPhone,
  });

  final String userEmail;
  final String userName;
  final String userPhone;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  String welcomeMessage = "";
  late AnimationController _controller;
  String _searchQuery = "";
  DateTimeRange? selectedRange;
  String _currentUserName = '';
  String _currentUserEmail = '';
  String _currentUserPhone = '';
  bool _isUserDataLoaded = false;
  Box? userBox; // User-specific box reference

  Future<void> _loadCurrentUserData() async {
    final user = await _getCurrentUserName();

    if (!Hive.isBoxOpen('session')) {
      await Hive.openBox('session');
    }

    final sessionBox = Hive.box('session');
    final email = sessionBox.get("currentUserEmail");

    if (email != null) {
      final safeEmail = email
          .toString()
          .replaceAll('.', '_')
          .replaceAll('@', '_');

      // OPEN USER-SPECIFIC BOX
      userBox = await Hive.openBox("userdata_$safeEmail");

      setState(() {
        if (user != null) {
          _currentUserName = user.name;
          _currentUserEmail = user.email;
          _currentUserPhone = user.phone;
        }
        _isUserDataLoaded = true;
      });
    }
  }

  Future<User?> _getCurrentUserName() async {
    try {
      // Ensure users box is loaded
      final usersBox = Hive.box<User>('users');

      // Open or get session box
      if (!Hive.isBoxOpen('session')) {
        await Hive.openBox('session');
      }

      final sessionBox = Hive.box('session');
      final currentUserEmail = sessionBox.get('currentUserEmail');

      // 🔹 No email stored → show log and return null
      if (currentUserEmail == null || currentUserEmail.toString().isEmpty) {
        debugPrint("No current user email found in session.");
        return null;
      }

      // 🔹 Fetch EXACT user that logged in
      try {
        final matchedUser = usersBox.values.firstWhere(
          (u) =>
              u.email.trim().toLowerCase() ==
              currentUserEmail.toString().trim().toLowerCase(),
        );

        debugPrint("Loaded logged-in user: ${matchedUser.email}");
        return matchedUser;
      } catch (e) {
        debugPrint("User with email $currentUserEmail not found in users box");
        return null;
      }
    } catch (e) {
      debugPrint("Error loading current user: $e");
      return null;
    }
  }

  Future<void> fetchWelcomeMessage() async {
    // Open session box
    if (!Hive.isBoxOpen('session')) {
      await Hive.openBox('session');
    }
    final sessionBox = Hive.box('session');

    final email = sessionBox.get('currentUserEmail');

    if (email == null || email.toString().isEmpty) {
      setState(() {
        welcomeMessage = "Welcome!";
      });
      return;
    }

    // Load users box
    final usersBox = Hive.box<User>('users');

    User? user;
    try {
      user = usersBox.values.firstWhere(
        (u) =>
            u.email.trim().toLowerCase() ==
            email.toString().trim().toLowerCase(),
      );
    } catch (e) {
      user = null;
    }

    if (user == null) {
      setState(() {
        welcomeMessage = "Welcome!";
      });
      return;
    }

    // First login flag
    final firstLoginKey = "firstLogin_$email";
    bool isFirstLogin = sessionBox.get(firstLoginKey, defaultValue: true);

    // Always show name with welcome
    if (isFirstLogin) {
      welcomeMessage = "Welcome, \n${user.name}!";
      sessionBox.put(firstLoginKey, false); // Mark as visited
    } else {
      welcomeMessage = "Welcome back, \n${user.name}!";
    }

    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData().then((_) {
      fetchWelcomeMessage();
    });

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _handleDateRangeChanged(DateTimeRange? range) {
    setState(() {
      selectedRange = range;
    });
  }

  Widget buildSalesList() {
    if (userBox == null) {
      return Center(child: CircularProgressIndicator());
    }

    return ValueListenableBuilder(
      valueListenable: userBox!.listenable(),
      builder: (context, Box box, _) {
        // Get all sales from user-specific box and sort them by date in descending order (newest first)
        List<Sale> sales = [];
        try {
          sales = List<Sale>.from(box.get("sales", defaultValue: []));
        } catch (_) {
          sales = [];
        }

        sales.sort((a, b) => b.dateTime.compareTo(a.dateTime));

        // Filter sales based on search query
        if (_searchQuery.isNotEmpty) {
          sales =
              sales.where((sale) {
                final customerName = sale.customerName.toLowerCase();
                final productName = sale.productName.toLowerCase();
                final phoneNumber = sale.phoneNumber.toLowerCase();
                final amount = sale.totalAmount.toString();
                final date = DateFormat('dd MMM yyyy').format(sale.dateTime);
                final query = _searchQuery.toLowerCase();

                return customerName.contains(query) ||
                    productName.contains(query) ||
                    phoneNumber.contains(query) ||
                    amount.contains(query) ||
                    date.contains(query);
              }).toList();
        }

        // ✅ CORRECT DATE RANGE FILTER (INCLUSIVE + TIME SAFE)
        if (selectedRange != null) {
          final DateTime rangeStart = DateTime(
            selectedRange!.start.year,
            selectedRange!.start.month,
            selectedRange!.start.day,
            0,
            0,
            0,
          );

          final DateTime rangeEnd = DateTime(
            selectedRange!.end.year,
            selectedRange!.end.month,
            selectedRange!.end.day,
            23,
            59,
            59,
            999,
          );

          sales =
              sales.where((sale) {
                final saleDate = sale.dateTime;
                return !saleDate.isBefore(rangeStart) &&
                    !saleDate.isAfter(rangeEnd);
              }).toList();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isSmallScreen = constraints.maxWidth < 600;
            final bool isVerySmallScreen = constraints.maxWidth < 400;
            final bool isLargeScreen = constraints.maxWidth > 900;

            return Column(
              children: [
                AdvancedSearchBar(
                  hintText:
                      isVerySmallScreen
                          ? 'Search...'
                          : isSmallScreen
                          ? 'Search sales...'
                          : 'Search by customer, product, phone, amount...',
                  onSearchChanged: _handleSearchChanged,
                  onDateRangeChanged: _handleDateRangeChanged,
                  showDateFilter: true,
                ),
                if (sales.isEmpty &&
                    _searchQuery.isEmpty &&
                    selectedRange == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 100),
                    child: Center(
                      child: Text(
                        welcomeMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize:
                              isVerySmallScreen
                                  ? 16
                                  : isSmallScreen
                                  ? 18
                                  : 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (sales.isEmpty &&
                    (_searchQuery.isNotEmpty || selectedRange != null))
                  Padding(
                    padding: const EdgeInsets.only(top: 100),
                    child: Center(
                      child: Text(
                        _searchQuery.isNotEmpty && selectedRange != null
                            ? "No results found for '$_searchQuery' in selected date range"
                            : _searchQuery.isNotEmpty
                            ? "No results found for '$_searchQuery'"
                            : "No sales found in selected date range",
                        style: TextStyle(
                          fontSize:
                              isVerySmallScreen
                                  ? 12
                                  : isSmallScreen
                                  ? 14
                                  : 16,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                if (sales.isNotEmpty &&
                    _searchQuery.isEmpty &&
                    selectedRange == null)
                  SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.only(
                      bottom: 90,
                      left:
                          isVerySmallScreen
                              ? 4
                              : isSmallScreen
                              ? 8
                              : 0,
                      right:
                          isVerySmallScreen
                              ? 4
                              : isSmallScreen
                              ? 8
                              : 0,
                    ),
                    itemCount: sales.length,
                    itemBuilder: (context, index) {
                      final sale = sales[index];
                      if (sale == null) return SizedBox.shrink();

                      // Get the original index from the box to maintain invoice numbering
                      final originalIndex = sales.indexOf(sale);
                      final invoiceNumber = sales.length - originalIndex;
                      final formattedDate = DateFormat(
                        'dd MMM yyyy',
                      ).format(sale.dateTime);
                      final formattedTime = DateFormat(
                        'hh:mm a',
                      ).format(sale.dateTime);

                      double balanceAmount = (sale.totalAmount - sale.amount)
                          .clamp(0, double.infinity);

                      return Card(
                        margin: EdgeInsets.symmetric(
                          horizontal:
                              isVerySmallScreen
                                  ? 13
                                  : isSmallScreen
                                  ? 8
                                  : 27,
                          vertical: isVerySmallScreen ? 6 : 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => SaleDetailScreen(
                                      sale: sale,
                                      index: originalIndex,
                                    ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: EdgeInsets.all(
                              isVerySmallScreen
                                  ? 10
                                  : isSmallScreen
                                  ? 12
                                  : 16,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 15),
                                if (!isVerySmallScreen) ...[
                                  Column(
                                    children: [
                                      CircleAvatar(
                                        radius: isSmallScreen ? 20 : 24,
                                        backgroundColor: Color(0xFF1A237E),
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: isSmallScreen ? 20 : 24,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        "Invoice #$invoiceNumber",
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 10 : 12,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        DateFormat(
                                          'dd MMM',
                                        ).format(sale.dateTime),
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 10 : 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        DateFormat(
                                          'hh:mm a',
                                        ).format(sale.dateTime),
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 10 : 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(width: isSmallScreen ? 12 : 16),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (isVerySmallScreen) ...[
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: Color(
                                                0xFF1A237E,
                                              ),
                                              child: Icon(
                                                Icons.person,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                sale.customerName,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          "Invoice #$invoiceNumber • ${DateFormat('dd MMM, hh:mm a').format(sale.dateTime)}",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ] else ...[
                                        Text(
                                          sale.customerName,
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 15 : 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                      SizedBox(
                                        height: isVerySmallScreen ? 4 : 6,
                                      ),
                                      Text(
                                        sale.productName,
                                        style: TextStyle(
                                          fontSize:
                                              isVerySmallScreen
                                                  ? 12
                                                  : isSmallScreen
                                                  ? 13
                                                  : 14,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '+91 ${sale.phoneNumber}',
                                        style: TextStyle(
                                          fontSize:
                                              isVerySmallScreen
                                                  ? 12
                                                  : isSmallScreen
                                                  ? 13
                                                  : 14,
                                          color: Colors.black87,
                                        ),
                                      ),

                                      Divider(height: 16, thickness: 1),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Total:",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize:
                                                  isVerySmallScreen
                                                      ? 12
                                                      : isSmallScreen
                                                      ? 13
                                                      : null,
                                            ),
                                          ),
                                          Text(
                                            "₹${sale.totalAmount.toStringAsFixed(2)}",
                                            style: TextStyle(
                                              fontSize:
                                                  isVerySmallScreen
                                                      ? 12
                                                      : isSmallScreen
                                                      ? 13
                                                      : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Paid:",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize:
                                                  isVerySmallScreen
                                                      ? 12
                                                      : isSmallScreen
                                                      ? 13
                                                      : null,
                                            ),
                                          ),
                                          Text(
                                            "₹${sale.amount.toStringAsFixed(2)}",
                                            style: TextStyle(
                                              fontSize:
                                                  isVerySmallScreen
                                                      ? 12
                                                      : isSmallScreen
                                                      ? 13
                                                      : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Balance:",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize:
                                                  isVerySmallScreen
                                                      ? 12
                                                      : isSmallScreen
                                                      ? 13
                                                      : null,
                                            ),
                                          ),
                                          Text(
                                            "₹${(sale.totalAmount - sale.amount).clamp(0, double.infinity).toStringAsFixed(2)}",
                                            style: TextStyle(
                                              color: Colors.red[700],
                                              fontSize:
                                                  isVerySmallScreen
                                                      ? 12
                                                      : isSmallScreen
                                                      ? 13
                                                      : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Builder(
                                          builder: (context) {
                                            final bool isFullyPaid =
                                                sale.amount >= sale.totalAmount;
                                            final bool isPartiallyPaid =
                                                sale.amount > 0 &&
                                                sale.amount < sale.totalAmount;
                                            final bool isUnpaid =
                                                sale.amount == 0;

                                            final bool isDueOver7Days =
                                                isUnpaid &&
                                                sale.dateTime != null &&
                                                DateTime.now()
                                                        .difference(
                                                          sale.dateTime,
                                                        )
                                                        .inDays >
                                                    7;

                                            String label = '';
                                            Color badgeColor =
                                                Colors.orange[700]!;

                                            if (isFullyPaid) {
                                              label = "SALE : PAID";
                                              badgeColor = Colors.green[600]!;
                                            } else if (isPartiallyPaid) {
                                              label = "SALE : PARTIAL";
                                              badgeColor = Colors.lightBlue;
                                            } else if (isDueOver7Days) {
                                              label = "SALE : DUE";
                                              badgeColor = Colors.orange[700]!;

                                              final due =
                                                  sale.totalAmount -
                                                  sale.amount;
                                              final phone =
                                                  sale.phoneNumber
                                                      .replaceAll('+91', '')
                                                      .trim();
                                              final signature =
                                                  _currentUserName.isNotEmpty
                                                      ? ' - $_currentUserName'
                                                      : '';
                                              final msg =
                                                  "Hello ${sale.customerName}, your payment of ₹${due.toStringAsFixed(2)} is overdue for more than 7 days. Please make the payment at the earliest. - $signature";
                                              if (phone != null &&
                                                  phone.isNotEmpty) {
                                                WidgetsBinding.instance
                                                    .addPostFrameCallback((_) {
                                                      WhatsAppHelper.sendWhatsAppMessage(
                                                        phone: phone,
                                                        message: msg,
                                                      );
                                                    });
                                              }
                                            } else {
                                              label = "SALE : PARTIAL";
                                              badgeColor = Colors.lightBlue;
                                            }

                                            return Align(
                                              alignment: Alignment.centerRight,
                                              child: Container(
                                                margin: EdgeInsets.only(top: 6),
                                                padding: EdgeInsets.symmetric(
                                                  horizontal:
                                                      isVerySmallScreen
                                                          ? 6
                                                          : isSmallScreen
                                                          ? 8
                                                          : 12,
                                                  vertical:
                                                      isVerySmallScreen
                                                          ? 3
                                                          : isSmallScreen
                                                          ? 4
                                                          : 5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: badgeColor,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: badgeColor
                                                          .withOpacity(0.3),
                                                      blurRadius: 4,
                                                      offset: Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  label,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize:
                                                        isVerySmallScreen
                                                            ? 9
                                                            : isSmallScreen
                                                            ? 10
                                                            : 12,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isVerySmallScreen) ...[
                                  // SaleOptionsMenu with proper user data
                                  _isUserDataLoaded
                                      ? SaleOptionsMenu(
                                        sale: sale,
                                        originalIndex: originalIndex,
                                        box: box,
                                        isSmallScreen: isSmallScreen,
                                        invoiceNumber: invoiceNumber.toString(),
                                        currentUserName: _currentUserName,
                                        currentUserPhone: _currentUserPhone,
                                        currentUserEmail: _currentUserEmail,
                                        parentContext: context,
                                      )
                                      : Container(
                                        width: isSmallScreen ? 20 : 24,
                                        child: Center(
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                ] else ...[
                                  // For very small screens
                                  _isUserDataLoaded
                                      ? SaleOptionsMenu(
                                        sale: sale,
                                        originalIndex: originalIndex,
                                        box: box,
                                        isSmallScreen: true,
                                        invoiceNumber: invoiceNumber.toString(),
                                        currentUserName: _currentUserName,
                                        currentUserPhone: _currentUserPhone,
                                        currentUserEmail: _currentUserEmail,
                                        parentContext: context,
                                      )
                                      : Container(
                                        width: 16,
                                        child: Center(
                                          child: SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(children: [buildSalesList()]),
    );
  }
}
