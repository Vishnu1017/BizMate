// ignore_for_file: unused_local_variable, unnecessary_null_comparison

import 'package:bizmate/models/sale.dart';
import 'package:bizmate/models/user_model.dart';
import 'package:bizmate/screens/WhatsAppHelper.dart';
import 'package:bizmate/screens/sale_detail_screen.dart';
import 'package:bizmate/utils/app_theme.dart';
import 'package:bizmate/widgets/advanced_search_bar.dart'
    show AdvancedSearchBar;
import 'package:bizmate/widgets/sale_options_menu.dart' show SaleOptionsMenu;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
  Box? userBox;
  final ScrollController _scrollController = ScrollController();
  int _previousSalesCount = 0;
  bool _isSendingReminder = false;
  double scale = 1.0;
  String _statusFilter = 'All'; // 'All' | 'PAID' | 'PARTIAL' | 'DUE'
  String _currentUserRole = '';

  Future<void> _loadUserRole() async {
    try {
      if (!Hive.isBoxOpen('session')) {
        await Hive.openBox('session');
      }
      final sessionBox = Hive.box('session');
      String? role = sessionBox.get('currentUserRole')?.toString();

      if (role == null || role.trim().isEmpty) {
        final email = sessionBox.get('currentUserEmail')?.toString();
        if (email != null && email.isNotEmpty) {
          final usersBox = Hive.isBoxOpen('users')
              ? Hive.box<User>('users')
              : await Hive.openBox<User>('users');
          final user = usersBox.values.firstWhere(
            (u) => u.email.trim().toLowerCase() == email.trim().toLowerCase(),
            orElse: () => User(name: '', email: '', phone: '', password: '', role: 'None'),
          );
          if (user.role.isNotEmpty && user.role != 'None') {
            role = user.role;
          } else {
            final safeEmail = email.replaceAll('.', '_').replaceAll('@', '_');
            final uBox = await Hive.openBox("userdata_$safeEmail");
            final profile = uBox.get('profile');
            if (profile != null && profile is Map && profile['role'] != null) {
              role = profile['role'].toString();
            }
          }
        }
      }
      if (role != null && role.isNotEmpty) {
        await sessionBox.put('currentUserRole', role);
      }
      if (mounted) {
        setState(() {
          _currentUserRole = (role ?? '').toLowerCase().trim();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCurrentUserData() async {
    final user = await _getCurrentUserName();
    await _loadUserRole();

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

  // ── Status filter chips ────────────────────────────────────────────────────
  static const _filters = ['All', 'PAID', 'PARTIAL', 'DUE'];

  static const _filterColors = {
    'All': Color(0xFF2563EB),
    'PAID': Color(0xFF16A34A),
    'PARTIAL': Color(0xFF0284C7),
    'DUE': Color(0xFFEA580C),
  };

  static const _filterIcons = {
    'All': Icons.list_alt_rounded,
    'PAID': Icons.check_circle_rounded,
    'PARTIAL': Icons.pending_rounded,
    'DUE': Icons.warning_amber_rounded,
  };

  Widget _buildStatusFilterChips({
    bool isSmallScreen = true,
    bool isLargeScreen = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double hPadding =
        isLargeScreen ? 20.0 : (isSmallScreen ? 10.0 : 14.0);
    final double chipHPadding =
        isLargeScreen ? 14.0 : (isSmallScreen ? 7.0 : 10.0);
    final double chipVPadding =
        isLargeScreen ? 5.5 : (isSmallScreen ? 2.5 : 3.5);
    final double chipRadius =
        isLargeScreen ? 16.0 : (isSmallScreen ? 12.0 : 13.0);
    final double iconSize = isLargeScreen ? 14.0 : (isSmallScreen ? 9.5 : 11.0);
    final double fontSize = isLargeScreen ? 12.5 : (isSmallScreen ? 9.0 : 10.0);
    final double gap = isLargeScreen ? 4.0 : 3.0;
    final double itemSpacing =
        isLargeScreen ? 6.0 : (isSmallScreen ? 4.0 : 5.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(hPadding, 0, hPadding, 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              _filters.map((label) {
                final isSelected = _statusFilter == label;
                final color = _filterColors[label]!;
                final icon = _filterIcons[label]!;
                return Padding(
                  padding: EdgeInsets.only(right: itemSpacing),
                  child: GestureDetector(
                    onTap: () => setState(() => _statusFilter = label),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      padding: EdgeInsets.symmetric(
                        horizontal: chipHPadding,
                        vertical: chipVPadding,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? color.withValues(alpha: isDark ? 0.22 : 0.12)
                                : (isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white),
                        borderRadius: BorderRadius.circular(chipRadius),
                        border: Border.all(
                          color:
                              isSelected
                                  ? color
                                  : (isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFE2E8F0)),
                          width: isSelected ? 1.2 : 1,
                        ),
                        boxShadow:
                            isSelected
                                ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.15),
                                    blurRadius: isLargeScreen ? 6 : 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                                : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: Icon(
                              icon,
                              key: ValueKey('$label-$isSelected'),
                              size: iconSize,
                              color:
                                  isSelected
                                      ? color
                                      : (isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B)),
                            ),
                          ),
                          SizedBox(width: gap),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                              color:
                                  isSelected
                                      ? color
                                      : (isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B)),
                              letterSpacing: 0.1,
                            ),
                            child: Text(label),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget buildSalesList() {
    if (userBox == null) {
      return Center(child: CircularProgressIndicator());
    }

    final sessionBox = Hive.isBoxOpen('session') ? Hive.box('session') : null;
    final salesListWidget = ValueListenableBuilder(
      valueListenable: userBox!.listenable(),
      builder: (context, Box box, _) {
        // Get all sales from user-specific box and sort them by date in descending order (newest first)
        List<Sale> sales = [];
        try {
          sales = List<Sale>.from(box.get("sales", defaultValue: []));
          // 🔥 AUTO SCROLL TO TOP WHEN NEW SALE IS ADDED
          if (sales.length > _previousSalesCount) {
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

          _previousSalesCount = sales.length;
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

        // ── Status filter ────────────────────────────────────────────
        if (_statusFilter != 'All') {
          sales =
              sales.where((sale) {
                final bool isFullyPaid = sale.amount >= sale.totalAmount;
                final bool isPartiallyPaid =
                    sale.amount > 0 && sale.amount < sale.totalAmount;
                final bool isUnpaid = sale.amount == 0;
                if (_statusFilter == 'PAID') return isFullyPaid;
                if (_statusFilter == 'PARTIAL') return isPartiallyPaid;
                if (_statusFilter == 'DUE') return isUnpaid;
                return true;
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

                // ── Status Filter Chips ──────────────────────────────
                _buildStatusFilterChips(
                  isSmallScreen: isSmallScreen,
                  isLargeScreen: isLargeScreen,
                ),
                if (sales.isEmpty &&
                    _searchQuery.isEmpty &&
                    selectedRange == null &&
                    _statusFilter == 'All')
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
                    (_searchQuery.isNotEmpty ||
                        selectedRange != null ||
                        _statusFilter != 'All'))
                  Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_list_off_rounded,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _statusFilter != 'All' &&
                                    _searchQuery.isEmpty &&
                                    selectedRange == null
                                ? 'No $_statusFilter sales found'
                                : _searchQuery.isNotEmpty &&
                                    selectedRange != null
                                ? "No results for '\$_searchQuery' in selected range"
                                : _searchQuery.isNotEmpty
                                ? "No results found for '\$_searchQuery'"
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
                        ],
                      ),
                    ),
                  ),
                if (sales.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
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
                        const Color greenColor = Color(0xFF16A34A);
                        const Color redColor = Color(0xFFE11D48);

                        final completedCount = sale.completedPhotographyCount;
                        final totalCount = sale.safeEventDates.length;

                        final allCompleted =
                            totalCount > 0 && completedCount == totalCount;
                        final noneCompleted = completedCount == 0;
                        final partiallyCompleted =
                            completedCount > 0 && completedCount < totalCount;

                        final double progress =
                            totalCount == 0 ? 0 : completedCount / totalCount;

                        final scheduleColor =
                            allCompleted
                                ? greenColor
                                : noneCompleted
                                ? redColor
                                : Colors.orange;
                        if (sale == null) return SizedBox.shrink();

                        final currentRole = (Hive.isBoxOpen('session')
                                ? (Hive.box('session').get('currentUserRole')?.toString() ?? _currentUserRole)
                                : _currentUserRole)
                            .toLowerCase()
                            .trim();
                        final is3dPrinting =
                            currentRole.contains('3d') || currentRole.contains('print');

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
                                    ? 9
                                    : isSmallScreen
                                    ? 4
                                    : 23,
                            vertical: isVerySmallScreen ? 4 : 6,
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
                                    ? 6
                                    : isSmallScreen
                                    ? 8
                                    : 12,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(width: 6 * scale),
                                  if (!isVerySmallScreen) ...[
                                    Column(
                                      children: [
                                        Container(
                                          width:
                                              isSmallScreen
                                                  ? 32
                                                  : 36, // Reduced from 40:48
                                          height:
                                              isSmallScreen
                                                  ? 32
                                                  : 36, // Reduced from 40:48
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient:
                                                context.isDark
                                                    ? const LinearGradient(
                                                      colors: [
                                                        Color(0xFF38BDF8),
                                                        Color(0xFF60A5FA),
                                                        Color(0xFFBAE6FD),
                                                      ],
                                                      stops: [0.0, 0.6, 1.0],
                                                      begin:
                                                          Alignment.bottomRight,
                                                      end: Alignment.topLeft,
                                                    )
                                                    : const LinearGradient(
                                                      colors: [
                                                        Color(0xFF2563EB),
                                                        Color(0xFF1E40AF),
                                                        Color(0xFF020617),
                                                      ],
                                                      stops: [0.0, 0.6, 1.0],
                                                      begin:
                                                          Alignment.bottomRight,
                                                      end: Alignment.topLeft,
                                                    ),
                                          ),
                                          child: Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size:
                                                isSmallScreen
                                                    ? 16
                                                    : 18, // Reduced from 20:24
                                          ),
                                        ),
                                        SizedBox(height: 4), // Reduced from 8
                                        Text(
                                          "Invoice #$invoiceNumber",
                                          style: TextStyle(
                                            fontSize:
                                                isSmallScreen
                                                    ? 8
                                                    : 10, // Reduced from 10:12
                                            color:
                                                context.isDark
                                                    ? const Color(0xFF38BDF8)
                                                    : Colors.indigo,
                                          ),
                                        ),
                                        SizedBox(height: 2), // Reduced from 4
                                        Text(
                                          DateFormat(
                                            'dd MMM',
                                          ).format(sale.dateTime),
                                          style: TextStyle(
                                            fontSize:
                                                isSmallScreen
                                                    ? 8
                                                    : 10, // Reduced from 10:12
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          DateFormat(
                                            'hh:mm a',
                                          ).format(sale.dateTime),
                                          style: TextStyle(
                                            fontSize:
                                                isSmallScreen
                                                    ? 8
                                                    : 10, // Reduced from 10:12
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                      width: isSmallScreen ? 8 : 12,
                                    ), // Reduced from 12:16
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (isVerySmallScreen) ...[
                                          Row(
                                            children: [
                                              Container(
                                                width: isSmallScreen ? 30 : 38,
                                                height: isSmallScreen ? 30 : 38,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient:
                                                      context.isDark
                                                          ? const LinearGradient(
                                                            colors: [
                                                              Color(0xFF38BDF8),
                                                              Color(0xFF60A5FA),
                                                              Color(0xFFBAE6FD),
                                                            ],
                                                            stops: [
                                                              0.0,
                                                              0.6,
                                                              1.0,
                                                            ],
                                                            begin:
                                                                Alignment
                                                                    .bottomRight,
                                                            end:
                                                                Alignment
                                                                    .topLeft,
                                                          )
                                                          : const LinearGradient(
                                                            colors: [
                                                              Color(0xFF2563EB),
                                                              Color(0xFF1E40AF),
                                                              Color(0xFF020617),
                                                            ],
                                                            stops: [
                                                              0.0,
                                                              0.6,
                                                              1.0,
                                                            ],
                                                            begin:
                                                                Alignment
                                                                    .bottomRight,
                                                            end:
                                                                Alignment
                                                                    .topLeft,
                                                          ),
                                                ),
                                                child: Icon(
                                                  Icons.person,
                                                  color: Colors.white,
                                                  size: isSmallScreen ? 16 : 20,
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
                                            color:
                                                context.isDark
                                                    ? Colors.white
                                                    : Colors.black87,
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
                                            color:
                                                context.isDark
                                                    ? Colors.white
                                                    : Colors.black87,
                                          ),
                                        ),
                                        if (sale.safeEventDates.isNotEmpty) ...[
                                          SizedBox(height: 10 * scale),

                                          Container(
                                            width: double.infinity * scale,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 10 * scale,
                                              vertical: 8 * scale,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  const Color(
                                                    0xFF4ADE80,
                                                  ).withValues(alpha: 0.25),
                                                  const Color(
                                                    0xFF22C55E,
                                                  ).withValues(alpha: 0.21),
                                                  const Color(
                                                    0xFFFB7185,
                                                  ).withValues(alpha: 0.21),
                                                  const Color(
                                                    0xFFF43F5E,
                                                  ).withValues(alpha: 0.25),
                                                ],
                                                stops: [
                                                  0.0,
                                                  progress,
                                                  progress,
                                                  1.0,
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    12 * scale,
                                                  ),
                                              border: Border.all(
                                                color: Colors.white.withValues(
                                                  alpha: 0.18,
                                                ),
                                                width: 1.2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFF16A34A,
                                                  ).withValues(alpha: 0.12),
                                                  blurRadius: 14,
                                                  spreadRadius: 1,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ],
                                            ),
                                            child: IntrinsicHeight(
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    width: 2.5 * scale,
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin:
                                                            Alignment.topLeft,
                                                        end:
                                                            Alignment
                                                                .bottomRight,
                                                        colors: [
                                                          const Color(
                                                            0xFF34D399,
                                                          ).withValues(
                                                            alpha: 0.85,
                                                          ),
                                                          const Color(
                                                            0xFF16A34A,
                                                          ).withValues(
                                                            alpha: 0.85,
                                                          ),
                                                          const Color(
                                                            0xFFFB7185,
                                                          ).withValues(
                                                            alpha: 0.85,
                                                          ),
                                                          const Color(
                                                            0xFFE11D48,
                                                          ).withValues(
                                                            alpha: 0.85,
                                                          ),
                                                        ],
                                                        stops: [
                                                          0.0,
                                                          progress,
                                                          progress,
                                                          1.0,
                                                        ],
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            22,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.18,
                                                            ),
                                                        width: 1.2,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: const Color(
                                                            0xFF16A34A,
                                                          ).withValues(
                                                            alpha: 0.12,
                                                          ),
                                                          blurRadius: 14,
                                                          spreadRadius: 1,
                                                          offset: const Offset(
                                                            0,
                                                            6,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                  SizedBox(width: 8 * scale),

                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              is3dPrinting
                                                                  ? Icons
                                                                      .local_shipping_rounded
                                                                  : Icons
                                                                      .camera_alt_rounded,
                                                              size: 12 * scale,
                                                              color:
                                                                  partiallyCompleted
                                                                      ? Colors
                                                                          .orange
                                                                          .shade700
                                                                      : scheduleColor,
                                                            ),

                                                            SizedBox(
                                                              width: 6 * scale,
                                                            ),

                                                            Expanded(
                                                              child: Text(
                                                                is3dPrinting
                                                                    ? "Delivery Schedule"
                                                                    : "Photography Schedule",
                                                                style: TextStyle(
                                                                  fontSize:
                                                                      10 *
                                                                      scale,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color:
                                                                      partiallyCompleted
                                                                          ? Colors
                                                                              .orange
                                                                              .shade700
                                                                          : scheduleColor,
                                                                ),
                                                              ),
                                                            ),

                                                            Container(
                                                              padding:
                                                                  EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        8 *
                                                                        scale,
                                                                    vertical:
                                                                        3 *
                                                                        scale,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                gradient: LinearGradient(
                                                                  colors: [
                                                                    Colors.white
                                                                        .withValues(
                                                                          alpha:
                                                                              0.2,
                                                                        ),
                                                                    Colors.white
                                                                        .withValues(
                                                                          alpha:
                                                                              0.1,
                                                                        ),
                                                                  ],
                                                                ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                                border: Border.all(
                                                                  color:
                                                                      allCompleted
                                                                          ? Colors.green.withValues(
                                                                            alpha:
                                                                                0.9,
                                                                          )
                                                                          : partiallyCompleted
                                                                          ? Colors.orange.withValues(
                                                                            alpha:
                                                                                0.9,
                                                                          )
                                                                          : Colors.red.withValues(
                                                                            alpha:
                                                                                0.8,
                                                                          ),
                                                                  width: 1.2,
                                                                ),
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                    color: Colors
                                                                        .white
                                                                        .withValues(
                                                                          alpha:
                                                                              0.08,
                                                                        ),
                                                                    blurRadius:
                                                                        6,
                                                                    spreadRadius:
                                                                        0,
                                                                  ),
                                                                ],
                                                              ),
                                                              child: Text(
                                                                allCompleted
                                                                    ? "COMPLETED"
                                                                    : partiallyCompleted
                                                                    ? "$completedCount/$totalCount"
                                                                    : "PENDING",
                                                                style: TextStyle(
                                                                  color:
                                                                      allCompleted
                                                                          ? Colors
                                                                              .green
                                                                          : partiallyCompleted
                                                                          ? Colors
                                                                              .orange
                                                                          : Colors
                                                                              .red,
                                                                  fontSize:
                                                                      8 * scale,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),

                                                        SizedBox(
                                                          height: 8 * scale,
                                                        ),

                                                        Column(
                                                          children:
                                                              sale.safeEventDates.map((
                                                                date,
                                                              ) {
                                                                final isCompleted =
                                                                    DateTime(
                                                                      date.year,
                                                                      date.month,
                                                                      date.day,
                                                                      23,
                                                                      59,
                                                                      59,
                                                                    ).isBefore(
                                                                      DateTime.now(),
                                                                    );

                                                                return Padding(
                                                                  padding:
                                                                      EdgeInsets.only(
                                                                        bottom:
                                                                            2 *
                                                                            scale,
                                                                      ),
                                                                  child: Row(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Container(
                                                                        margin: EdgeInsets.only(
                                                                          top:
                                                                              5 *
                                                                              scale,
                                                                          left:
                                                                              3 *
                                                                              scale,
                                                                        ),
                                                                        width:
                                                                            6 *
                                                                            scale,
                                                                        height:
                                                                            6 *
                                                                            scale,
                                                                        decoration: BoxDecoration(
                                                                          color:
                                                                              isCompleted
                                                                                  ? const Color(
                                                                                    0xFF16A34A,
                                                                                  )
                                                                                  : const Color(
                                                                                    0xFFE11D48,
                                                                                  ),
                                                                          shape:
                                                                              BoxShape.circle,
                                                                        ),
                                                                      ),

                                                                      SizedBox(
                                                                        width:
                                                                            10 *
                                                                            scale,
                                                                      ),

                                                                      Expanded(
                                                                        child: Text(
                                                                          DateFormat(
                                                                            'EEEE, dd MMM yyyy',
                                                                          ).format(
                                                                            date,
                                                                          ),
                                                                          style: TextStyle(
                                                                            fontSize:
                                                                                10 *
                                                                                scale,
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            color:
                                                                                isCompleted
                                                                                    ? Colors.green.shade700
                                                                                    : Colors.grey.shade700,
                                                                            decoration:
                                                                                isCompleted
                                                                                    ? TextDecoration.lineThrough
                                                                                    : TextDecoration.none,
                                                                          ),
                                                                        ),
                                                                      ),

                                                                      if (isCompleted)
                                                                        Icon(
                                                                          Icons
                                                                              .check_circle,
                                                                          color: Color(
                                                                            0xFF16A34A,
                                                                          ),
                                                                          size:
                                                                              14 *
                                                                              scale,
                                                                        ),
                                                                    ],
                                                                  ),
                                                                );
                                                              }).toList(),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          SizedBox(height: 10 * scale),
                                        ],

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
                                                  sale.amount >=
                                                  sale.totalAmount;
                                              final bool isPartiallyPaid =
                                                  sale.amount > 0 &&
                                                  sale.amount <
                                                      sale.totalAmount;
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
                                                badgeColor =
                                                    Colors.orange[700]!;
                                              } else {
                                                label = "SALE : PARTIAL";
                                                badgeColor = Colors.lightBlue;
                                              }

                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  // ✅ SALE BADGE
                                                  Container(
                                                    margin: EdgeInsets.only(
                                                      top: 6,
                                                    ),
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
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: badgeColor
                                                              .withValues(
                                                                alpha: 0.3,
                                                              ),
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
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ),

                                                  // ✅ SEND REMINDER BUTTON (ONLY IF DUE)
                                                  if (isDueOver7Days) ...[
                                                    SizedBox(height: 6),

                                                    GestureDetector(
                                                      onTap: () async {
                                                        final due =
                                                            sale.totalAmount -
                                                            sale.amount;
                                                        final phone =
                                                            sale.phoneNumber
                                                                .replaceAll(
                                                                  '+91',
                                                                  '',
                                                                )
                                                                .trim();

                                                        final signature =
                                                            _currentUserName
                                                                    .isNotEmpty
                                                                ? ' - $_currentUserName'
                                                                : '';

                                                        final msg =
                                                            "Hello ${sale.customerName}, your payment of ₹${due.toStringAsFixed(2)} is overdue for more than 7 days. Please make the payment at the earliest.$signature";

                                                        final bool?
                                                        confirm = await showDialog<
                                                          bool
                                                        >(
                                                          context: context,
                                                          builder: (context) {
                                                            return AlertDialog(
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      16,
                                                                    ),
                                                              ),
                                                              title: Row(
                                                                children: [
                                                                  FaIcon(
                                                                    FontAwesomeIcons
                                                                        .whatsapp,
                                                                    color:
                                                                        Colors
                                                                            .green,
                                                                    size:
                                                                        18 *
                                                                        scale,
                                                                  ),
                                                                  SizedBox(
                                                                    width:
                                                                        10 *
                                                                        scale,
                                                                  ),
                                                                  Text(
                                                                    "Send Reminder",
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          16 *
                                                                          scale,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              content: Text(
                                                                "Send WhatsApp reminder to ${sale.customerName} for ₹${due.toStringAsFixed(2)}?",
                                                                style:
                                                                    TextStyle(
                                                                      fontSize:
                                                                          12 *
                                                                          scale,
                                                                    ),
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed:
                                                                      () => Navigator.pop(
                                                                        context,
                                                                        false,
                                                                      ),
                                                                  child: Text(
                                                                    "Cancel",
                                                                    style: TextStyle(
                                                                      color:
                                                                          Colors
                                                                              .black,
                                                                      fontSize:
                                                                          14 *
                                                                          scale,
                                                                    ),
                                                                  ),
                                                                ),
                                                                ElevatedButton(
                                                                  style: ElevatedButton.styleFrom(
                                                                    backgroundColor:
                                                                        Colors
                                                                            .green,
                                                                    shape: RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            8,
                                                                          ),
                                                                    ),
                                                                  ),
                                                                  onPressed:
                                                                      () => Navigator.pop(
                                                                        context,
                                                                        true,
                                                                      ),
                                                                  child: Text(
                                                                    "Send",
                                                                    style: TextStyle(
                                                                      color:
                                                                          Colors
                                                                              .white,
                                                                      fontSize:
                                                                          14 *
                                                                          scale,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            );
                                                          },
                                                        );

                                                        if (confirm == true &&
                                                            phone.isNotEmpty) {
                                                          setState(
                                                            () =>
                                                                _isSendingReminder =
                                                                    true,
                                                          );

                                                          try {
                                                            await WhatsAppHelper.sendWhatsAppMessage(
                                                              phone: phone,
                                                              message: msg,
                                                            );
                                                          } catch (_) {}

                                                          if (mounted) {
                                                            setState(
                                                              () =>
                                                                  _isSendingReminder =
                                                                      false,
                                                            );
                                                          }
                                                        }
                                                      },
                                                      child: Container(
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              horizontal:
                                                                  8 * scale,
                                                              vertical:
                                                                  6 * scale,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          gradient:
                                                              LinearGradient(
                                                                colors: [
                                                                  Color(
                                                                    0xFF25D366,
                                                                  ),
                                                                  Color(
                                                                    0xFF128C7E,
                                                                  ),
                                                                ],
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Color(
                                                                0xFF25D366,
                                                              ).withValues(
                                                                alpha: 0.3,
                                                              ),
                                                              blurRadius: 6,
                                                              offset: Offset(
                                                                0,
                                                                3,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            FaIcon(
                                                              FontAwesomeIcons
                                                                  .whatsapp,
                                                              color:
                                                                  Colors.white,
                                                              size: 14 * scale,
                                                            ),
                                                            SizedBox(width: 6),
                                                            Text(
                                                              "Send Reminder",
                                                              style: TextStyle(
                                                                color:
                                                                    Colors
                                                                        .white,
                                                                fontSize:
                                                                    11 * scale,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isVerySmallScreen) ...[
                                    // SaleOptionsMenu with proper user data - reduced width
                                    SizedBox(
                                      width:
                                          28, // Reduced width for the menu icon
                                      child:
                                          _isUserDataLoaded
                                              ? SaleOptionsMenu(
                                                sale: sale,
                                                originalIndex: originalIndex,
                                                box: box,
                                                isSmallScreen: isSmallScreen,
                                                invoiceNumber:
                                                    invoiceNumber.toString(),
                                                currentUserName:
                                                    _currentUserName,
                                                currentUserPhone:
                                                    _currentUserPhone,
                                                currentUserEmail:
                                                    _currentUserEmail,
                                                parentContext: context,
                                              )
                                              : Center(
                                                child: SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              ),
                                    ),
                                  ] else ...[
                                    // For very small screens - even smaller width
                                    SizedBox(
                                      width:
                                          28, // Even smaller for very small screens
                                      child:
                                          _isUserDataLoaded
                                              ? SaleOptionsMenu(
                                                sale: sale,
                                                originalIndex: originalIndex,
                                                box: box,
                                                isSmallScreen: true,
                                                invoiceNumber:
                                                    invoiceNumber.toString(),
                                                currentUserName:
                                                    _currentUserName,
                                                currentUserPhone:
                                                    _currentUserPhone,
                                                currentUserEmail:
                                                    _currentUserEmail,
                                                parentContext: context,
                                              )
                                              : Center(
                                                child: SizedBox(
                                                  width: 12,
                                                  height: 12,
                                                  child:
                                                      CircularProgressIndicator(
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

    if (sessionBox != null) {
      return ValueListenableBuilder(
        valueListenable: sessionBox.listenable(keys: ['currentUserRole']),
        builder: (context, roleBox, child) => salesListWidget,
      );
    }
    return salesListWidget;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 🔥 BLOCK TOUCHES WHEN SENDING
          AbsorbPointer(absorbing: _isSendingReminder, child: buildSalesList()),

          // 🔥 OPTIONAL LOADING OVERLAY
          if (_isSendingReminder)
            Container(
              color: Colors.black.withValues(alpha: 0.15),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
