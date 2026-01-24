// lib/screens/nav_bar_page.dart
// ignore_for_file: public_member_api_docs, sort_constructors_first, unused_field

import 'package:bizmate/screens/Camera%20rental%20page/camera_rental_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:bizmate/models/user_model.dart';
import 'package:bizmate/screens/CalendarPage.dart';
import 'package:hive/hive.dart';
import 'package:hugeicons/hugeicons.dart' show HugeIcon, HugeIcons;
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;
import '../models/product_store.dart';
import 'customers_page.dart';
import 'dashboard_page.dart';
import 'home_page.dart';
import 'new_sale_screen.dart';
import 'products_page.dart';
import 'profile_page.dart';
import 'select_items_screen.dart';

///
/// Responsive, production-ready rewrite of NavBarPage.
///
/// - Keeps all original functions, callbacks and navigation logic intact.
/// - Adds adaptive paddings / font scaling across phone/tablet/desktop breakpoints.
/// - Uses LayoutBuilder + MediaQuery to avoid fixed sizes that break on different devices.
///
class NavBarPage extends StatefulWidget {
  final User user;
  final String userPhone;
  final String userEmail;
  const NavBarPage({
    super.key,
    required this.user,
    required this.userPhone,
    required this.userEmail,
  });

  @override
  State<NavBarPage> createState() => _NavBarPageState();
}

class _NavBarPageState extends State<NavBarPage>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isRentalEnabled = false;
  String welcomeMessage = "";
  double scale = 1.0;
  late ValueNotifier<String> _nameNotifier;

  // Modern color palette
  final Color _primaryColor = const Color(0xFF1A237E);
  final Color _secondaryColor = const Color(0xFF3949AB);
  final Color _accentColor = const Color(0xFF00BCD4);
  final Color _surfaceColor = const Color(0xFFFFFFFF);
  final Color _backgroundColor = const Color(0xFFF5F7FA);
  final Color _textPrimary = const Color(0xFF1A1A1A);
  final Color _textSecondary = const Color.fromARGB(255, 72, 72, 72);
  final Color _dividerColor = const Color(0xFFE0E0E0);

  final List<String> _titles = [
    "Home",
    "Dashboard",
    "Customers",
    "Packages",
    "Profile",
  ];

  @override
  void initState() {
    super.initState();
    _nameNotifier = ValueNotifier(widget.user.name);
    _loadRentalStatus();
    fetchWelcomeMessage();
  }

  Future<void> _loadRentalStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isRentalEnabled =
          prefs.getBool('${widget.user.email}_rentalEnabled') ?? false;
    });
  }

  Future<void> _reloadRentalStatus() async {
    await _loadRentalStatus();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> fetchWelcomeMessage() async {
    // Open session box
    if (!Hive.isBoxOpen('session')) {
      await Hive.openBox('session');
    }
    final sessionBox = Hive.box('session');

    // Read email & normalize it (IMPORTANT FIX)
    final rawEmail = sessionBox.get('currentUserEmail');

    if (rawEmail == null || rawEmail.toString().isEmpty) {
      setState(() => welcomeMessage = "Welcome!");
      return;
    }

    final email = rawEmail.toString().trim().toLowerCase();

    // Load users box
    final usersBox = Hive.box<User>('users');

    User? user;
    try {
      user = usersBox.values.firstWhere(
        (u) => u.email.trim().toLowerCase() == email,
      );
    } catch (e) {
      user = null;
    }

    if (user == null) {
      setState(() => welcomeMessage = "Welcome!");
      return;
    }

    // FIRST LOGIN FLAG
    final firstLoginKey = "firstLogin_$email";

    bool isFirstLogin = sessionBox.get(firstLoginKey, defaultValue: true);

    if (isFirstLogin) {
      welcomeMessage = "Welcome, \n${user.name}!";
      sessionBox.put(firstLoginKey, false); // mark as visited
    } else {
      welcomeMessage = "Welcome back, \n${user.name}!";
    }

    if (mounted) setState(() {});
  }

  List<Widget> get _pages => [
    HomePage(
      userEmail: widget.userEmail,
      userName: widget.user.name,
      userPhone: widget.userPhone,
    ),
    DashboardPage(userEmail: widget.userEmail),
    CustomersPage(userEmail: widget.userEmail),
    ProductsPage(userEmail: widget.userEmail),
    ProfilePage(
      user: widget.user,
      userEmail: widget.userEmail,
      onRentalStatusChanged: () async {
        await _reloadRentalStatus();
        if (!mounted) return;
        setState(() {});
      },
      onProfileUpdated: (updatedName) {
        // 🔥 INSTANT UPDATE
        _nameNotifier.value = updatedName;

        // keep widget.user in sync too
        widget.user.name = updatedName;

        // optional: refresh welcome message
        fetchWelcomeMessage();
      },
    ),
  ];

  // ------------------------
  // Responsive helpers
  // ------------------------
  // Breakpoint map (simple and easy to tune)
  static const double _kCompactMax = 480; // small phones
  static const double _kLargePhoneMax = 768; // large phones / small tablets
  static const double _kTabletMax = 1024; // tablets

  double _scaleForWidth(double width, double base) {
    // returns scaled value for font/padding based on width
    if (width <= _kCompactMax) return base * 0.85; // compact
    if (width <= _kLargePhoneMax) return base * 0.95; // large phone
    if (width <= _kTabletMax) return base * 1.05; // tablet
    return base * 1.15; // desktop
  }

  EdgeInsets _pagePadding(double width) {
    if (width <= _kCompactMax) {
      return const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
    }
    if (width <= _kLargePhoneMax) {
      return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    }
    if (width <= _kTabletMax) {
      return const EdgeInsets.symmetric(horizontal: 28, vertical: 20);
    }
    return const EdgeInsets.symmetric(horizontal: 48, vertical: 24);
  }

  double _appBarHeight(double width) {
    if (width <= _kCompactMax) return 110;
    if (width <= _kLargePhoneMax) return 140;
    if (width <= _kTabletMax) return 170;
    return 200;
  }

  // ------------------------
  // AppBar & actions (kept logic intact)
  // ------------------------
  Widget _buildCleanAppBar(double screenWidth) {
    final bool isPhotographer = widget.user.role == 'Photographer';
    // ignore: unused_local_variable
    final isSmallScreen = screenWidth < _kLargePhoneMax;
    final padding = _pagePadding(screenWidth);

    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        border: Border(bottom: BorderSide(color: _dividerColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: padding,
          child: SizedBox(
            height: _appBarHeight(screenWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row with user info and actions
                Row(
                  children: [
                    // User profile
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentIndex = 4; // ✅ Profile tab index
                        });
                      },
                      child: Container(
                        width: _scaleForWidth(screenWidth, 44 * scale),
                        height: _scaleForWidth(screenWidth, 44 * scale),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _primaryColor,
                        ),
                        child: Center(
                          child: ValueListenableBuilder<String>(
                            valueListenable: _nameNotifier,
                            builder: (context, name, _) {
                              return Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: _scaleForWidth(
                                    screenWidth,
                                    18 * scale,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: _scaleForWidth(screenWidth, 12)),

                    // User info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Welcome / Welcome back (STATIC)
                          Text(
                            welcomeMessage.split('\n').first,
                            style: TextStyle(
                              fontSize: _scaleForWidth(screenWidth, 12),
                              color: _textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          // Name (LIVE)
                          ValueListenableBuilder<String>(
                            valueListenable: _nameNotifier,
                            builder: (context, name, _) {
                              return Text(
                                name, // ✅ ALWAYS LIVE
                                style: TextStyle(
                                  fontSize: _scaleForWidth(
                                    screenWidth,
                                    16 * scale,
                                  ),
                                  color: _textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: _scaleForWidth(screenWidth, 12 * scale)),
                    // Action buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Calendar button
                        _buildCleanActionButton(
                          screenWidth: screenWidth,
                          icon: Icons.calendar_today_outlined,
                          tooltip: 'Calendar',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CalendarPage(),
                              ),
                            );
                          },
                        ),

                        if (isPhotographer && _isRentalEnabled)
                          SizedBox(
                            width: _scaleForWidth(screenWidth, 10 * scale),
                          ),

                        // Camera rental button
                        if (isPhotographer && _isRentalEnabled)
                          _buildCameraRentalCleanButton(screenWidth),
                      ],
                    ),
                  ],
                ),

                SizedBox(height: _scaleForWidth(screenWidth, 18)),

                // Page title and status
                Row(
                  children: [
                    Text(
                      _titles[_currentIndex],
                      style: TextStyle(
                        fontSize: _scaleForWidth(screenWidth, 24 * scale),
                        color: _textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4 * scale,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: _scaleForWidth(screenWidth, 8)),

                // Progress indicator
                Container(
                  height: _scaleForWidth(screenWidth, 2.5 * scale),
                  width: _scaleForWidth(screenWidth, 50 * scale),
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCleanActionButton({
    required double screenWidth,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: _scaleForWidth(screenWidth, 36 * scale),
            height: _scaleForWidth(screenWidth, 36 * scale),
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _dividerColor),
            ),
            child: Icon(
              icon,
              color: _textSecondary,
              size: _scaleForWidth(screenWidth, 20 * scale),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraRentalCleanButton(double screenWidth) {
    return Tooltip(
      message: 'Camera Rental',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => CameraRentalNavBar(
                      userName: widget.user.name,
                      userPhone: widget.userPhone,
                      userEmail: widget.userEmail,
                    ),
              ),
            );
          },
          child: Container(
            width: _scaleForWidth(screenWidth, 36 * scale),
            height: _scaleForWidth(screenWidth, 36 * scale),
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _dividerColor),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCameraAdd01,
                  color: _textSecondary,
                  size: _scaleForWidth(screenWidth, 22 * scale),
                ),
                Positioned(
                  bottom: 3,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: _scaleForWidth(screenWidth, 1.5 * scale),
                      vertical: _scaleForWidth(screenWidth, 0.5 * scale),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      "Rental",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _scaleForWidth(screenWidth, 8 * scale),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------
  // Add Sale / Add Item buttons
  // ------------------------
  Widget _buildAddSaleButton(double screenWidth) {
    if (![0, 1, 2].contains(_currentIndex)) {
      return const SizedBox.shrink();
    }

    final labelText =
        _currentIndex == 0
            ? "Create New Sale"
            : _currentIndex == 1
            ? "Quick Sale"
            : "New Customer Sale";

    return Container(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NewSaleScreen()),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(_scaleForWidth(screenWidth, 18)),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _dividerColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(
                    MediaQuery.of(context).size.width < 350
                        ? 3 // very small phones
                        : MediaQuery.of(context).size.width < 500
                        ? 5 // normal phones
                        : MediaQuery.of(context).size.width < 900
                        ? 7 // tablets
                        : 9, // desktops
                  ),
                  width: _scaleForWidth(screenWidth, 44),
                  height: _scaleForWidth(screenWidth, 44),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primaryColor.withOpacity(0.1),
                    border: Border.all(color: _primaryColor.withOpacity(0.2)),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedAdd02,
                    color: _primaryColor,
                    size: _scaleForWidth(screenWidth, 24),
                  ),
                ),
                SizedBox(width: _scaleForWidth(screenWidth, 16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        labelText,
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: _scaleForWidth(screenWidth, 16),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: _scaleForWidth(screenWidth, 4)),
                      Text(
                        'Start a new sales transaction',
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: _scaleForWidth(screenWidth, 12),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: _textSecondary,
                  size: _scaleForWidth(screenWidth, 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddItemButton(double screenWidth) {
    if (_currentIndex != 3) return const SizedBox.shrink();

    return Container(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            bool continueAdding = true;

            while (continueAdding) {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SelectItemsScreen()),
              );

              if (result != null &&
                  result is Map &&
                  result['itemName'] != null) {
                final itemName = result['itemName'];
                final rate = result['rate'] ?? 0.0;

                ProductStore().add(itemName, rate);
                if (!mounted) return;
                setState(() {});
              }

              continueAdding =
                  result != null && result is Map && result['continue'] == true;
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(_scaleForWidth(screenWidth, 18)),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _dividerColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(
                    MediaQuery.of(context).size.width < 350
                        ? 3 // very small phones
                        : MediaQuery.of(context).size.width < 500
                        ? 5 // normal phones
                        : MediaQuery.of(context).size.width < 900
                        ? 7 // tablets
                        : 9, // desktops
                  ),
                  width: _scaleForWidth(screenWidth, 44),
                  height: _scaleForWidth(screenWidth, 44),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    border: Border.all(
                      color: const Color(0xFF4CAF50).withOpacity(0.2),
                    ),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedPackageAdd,
                    color: const Color(0xFF4CAF50),
                    size: _scaleForWidth(screenWidth, 24),
                  ),
                ),
                SizedBox(width: _scaleForWidth(screenWidth, 16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New Package',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: _scaleForWidth(screenWidth, 16),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: _scaleForWidth(screenWidth, 4)),
                      Text(
                        'Add products to your inventory',
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: _scaleForWidth(screenWidth, 12),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: _textSecondary,
                  size: _scaleForWidth(screenWidth, 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------
  // Bottom navigation (clean)
  // ------------------------
  Widget _buildCleanNavigation(double screenWidth) {
    final isSmallScreen = screenWidth < _kLargePhoneMax;
    final horizontalMargin = isSmallScreen ? 14.0 : 30.0;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalMargin,
        vertical: _scaleForWidth(screenWidth, 14),
      ),
      constraints: const BoxConstraints(maxWidth: 900),
      height: _scaleForWidth(screenWidth, 70),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildNavItem(screenWidth, 0, Icons.home_outlined, Icons.home),
          _buildNavItem(
            screenWidth,
            1,
            Icons.dashboard_outlined,
            Icons.dashboard,
          ),
          _buildNavItem(screenWidth, 2, Icons.people_outline, Icons.people),
          _buildNavItem(
            screenWidth,
            3,
            Icons.inventory_2_outlined,
            Icons.inventory_2,
          ),
          _buildNavItem(screenWidth, 4, Icons.person_outline, Icons.person),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    double screenWidth,
    int index,
    IconData outlineIcon,
    IconData filledIcon,
  ) {
    final isSelected = index == _currentIndex;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          setState(() {
            _currentIndex = index;
          });

          if (index == 3) {
            await Future.delayed(const Duration(milliseconds: 100));
            if (!mounted) return;
            setState(() {});
          }

          await _loadRentalStatus();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            0,
            isSelected ? -6 : 0, // 🔥 POP-UP EFFECT
            0,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ICON WITH FOCUS GLOW
              Container(
                width: _scaleForWidth(screenWidth, 42),
                height: _scaleForWidth(screenWidth, 42),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color:
                      isSelected
                          ? _primaryColor.withOpacity(0.12)
                          : Colors.transparent,
                  boxShadow:
                      isSelected
                          ? [
                            BoxShadow(
                              color: _primaryColor.withOpacity(0.125),
                              blurRadius: 25,
                              offset: const Offset(0, 6),
                            ),
                          ]
                          : [],
                ),
                child: Icon(
                  isSelected ? filledIcon : outlineIcon,
                  color: isSelected ? _primaryColor : _textSecondary,
                  size:
                      isSelected
                          ? _scaleForWidth(screenWidth, 26)
                          : _scaleForWidth(screenWidth, 24),
                ),
              ),

              const SizedBox(height: 4),

              // MICRO INDICATOR DOT
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: isSelected ? 6 : 0,
                height: 6,
                decoration: BoxDecoration(
                  color: _primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < _kLargePhoneMax;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Column(
        children: [
          // Clean AppBar
          _buildCleanAppBar(screenWidth),

          // Main content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: isSmallScreen ? 8 : 10,
                left: _pagePadding(screenWidth).horizontal / 4,
                right: _pagePadding(screenWidth).horizontal / 4,
                bottom: _pagePadding(screenWidth).horizontal / 11,
              ),
              child: Column(
                children: [
                  // Action buttons
                  if ([0, 1, 2].contains(_currentIndex))
                    _buildAddSaleButton(screenWidth),
                  if (_currentIndex == 3) _buildAddItemButton(screenWidth),

                  SizedBox(height: _scaleForWidth(screenWidth, 16)),

                  // Page content
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _dividerColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _pages[_currentIndex],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // Clean Navigation Bar
      bottomNavigationBar: SafeArea(child: _buildCleanNavigation(screenWidth)),
    );
  }
}

class SelectItemsScreenWithCallback extends StatelessWidget {
  final Function(String) onItemSaved;
  const SelectItemsScreenWithCallback({super.key, required this.onItemSaved});

  @override
  Widget build(BuildContext context) {
    return SelectItemsScreen(onItemSaved: onItemSaved);
  }
}
