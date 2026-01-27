// ignore_for_file: public_member_api_docs, sort_constructors_first, unused_field
import 'package:bizmate/models/rental_cart_item.dart';
import 'package:bizmate/screens/Camera%20rental%20page/camera_rental.dart';
import 'package:bizmate/screens/Camera%20rental%20page/rental_cart_preview_page.dart';
import 'package:bizmate/screens/Camera%20rental%20page/rental_items.dart';
import 'package:bizmate/services/rental_cart.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart' show HugeIcon, HugeIcons;
import 'rental_orders_page.dart';
import 'add_rental_item_page.dart';
import 'rental_customers_page.dart';

///
/// Responsive, production-ready rewrite of CameraRentalNavBar.
///
/// - Maintains all original navigation logic and functionality.
/// - Matches the design system from NavBarPage.
/// - Adaptive layout for phone/tablet/desktop.
///
class CameraRentalNavBar extends StatefulWidget {
  final String userName;
  final String userPhone;
  final String userEmail;

  const CameraRentalNavBar({
    super.key,
    required this.userName,
    required this.userPhone,
    required this.userEmail,
  });

  @override
  State<CameraRentalNavBar> createState() => _CameraRentalNavBarState();
}

class _CameraRentalNavBarState extends State<CameraRentalNavBar> {
  int _currentIndex = 0;
  final ValueNotifier<int> _cartCount = ValueNotifier<int>(0);
  // Modern color palette (matching NavBarPage)
  final Color _primaryColor = const Color(0xFF1A237E);
  final Color _secondaryColor = const Color(0xFF3949AB);
  final Color _accentColor = const Color(0xFF00BCD4);
  final Color _surfaceColor = const Color(0xFFFFFFFF);
  final Color _backgroundColor = const Color(0xFFF5F7FA);
  final Color _textPrimary = const Color(0xFF1A1A1A);
  final Color _textSecondary = const Color.fromARGB(255, 72, 72, 72);
  final Color _dividerColor = const Color(0xFFE0E0E0);

  final List<String> _titles = [
    "Camera Rental Sales",
    "Rental Orders",
    "Rental Items",
    "Rental Customers",
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      CameraRentalPage(
        userName: widget.userName,
        userPhone: widget.userPhone,
        userEmail: widget.userEmail,
      ),
      RentalOrdersPage(userEmail: widget.userEmail),
      RentalItems(userEmail: widget.userEmail),
      RentalCustomersPage(userEmail: widget.userEmail),
    ];

    // ✅ INITIAL CART COUNT
    _cartCount.value = RentalCart.items.length;
  }

  @override
  void dispose() {
    _cartCount.dispose();
    super.dispose();
  }

  // ------------------------
  // Responsive helpers
  // ------------------------

  // Breakpoint map (same as NavBarPage)
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
  // AppBar (matching NavBarPage style)
  // ------------------------

  Widget _buildCleanAppBar(double screenWidth) {
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
                // 🔝 TOP ROW
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [_buildBackButton(screenWidth)],
                ),

                SizedBox(height: _scaleForWidth(screenWidth, 18)),

                // TITLE
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ===== TITLE =====
                    Text(
                      _titles[_currentIndex],
                      style: TextStyle(
                        fontSize: _scaleForWidth(screenWidth, 28),
                        color: _textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),

                    // ===== CART BUTTON =====
                    InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RentalCartPreviewPage(),
                          ),
                        );

                        // ✅ UPDATE AFTER RETURN
                        _cartCount.value = RentalCart.items.length;
                      },

                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: _scaleForWidth(screenWidth, 10),
                              vertical: _scaleForWidth(screenWidth, 6),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: const Color(0xFF2563EB),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white,
                                  offset: const Offset(-4, -4),
                                  blurRadius: 8,
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  offset: const Offset(1, 3),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.shopping_cart_outlined,
                              size: _scaleForWidth(screenWidth, 18),
                              color: const Color(0xFF2563EB),
                            ),
                          ),

                          // ===== CART BADGE =====
                          Positioned(
                            top: -6,
                            right: -6,
                            child: ValueListenableBuilder<List<RentalCartItem>>(
                              valueListenable: RentalCart.notifier,
                              builder: (_, items, __) {
                                if (items.isEmpty)
                                  return const SizedBox.shrink();

                                return Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${items.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: _scaleForWidth(screenWidth, 8)),

                // INDICATOR
                Container(
                  height: _scaleForWidth(screenWidth, 3),
                  width: _scaleForWidth(screenWidth, 60),
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

  Widget _buildBackButton(double screenWidth) {
    return Tooltip(
      message: 'Back',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pop(context),
          child: Container(
            width: _scaleForWidth(screenWidth, 44),
            height: _scaleForWidth(screenWidth, 44),
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _dividerColor),
            ),
            child: Icon(
              Icons.arrow_back,
              color: _textSecondary,
              size: _scaleForWidth(screenWidth, 20),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------
  // Add Rental Item button
  // ------------------------

  Widget _buildAddRentalButton(double screenWidth) {
    if (_currentIndex != 2) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(bottom: _scaleForWidth(screenWidth, 12)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddRentalItemPage()),
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
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    border: Border.all(
                      color: const Color(0xFF4CAF50).withOpacity(0.2),
                    ),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedCameraAdd01,
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
                        'Add Rental Item',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: _scaleForWidth(screenWidth, 16),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: _scaleForWidth(screenWidth, 4)),
                      Text(
                        'Add new camera or equipment for rental',
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
    final horizontalMargin = isSmallScreen ? 16.0 : 28.0;

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
          _buildNavItem(
            screenWidth,
            0,
            Icons.camera_alt_outlined,
            Icons.camera_alt,
          ),
          _buildNavItem(
            screenWidth,
            1,
            Icons.shopping_bag_outlined,
            Icons.shopping_bag,
          ),
          _buildNavItem(screenWidth, 2, Icons.add_box_outlined, Icons.add_box),
          _buildNavItem(
            screenWidth,
            3,
            Icons.people_alt_outlined,
            Icons.people_alt,
          ),
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
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
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
              // ================= ICON WITH GRADIENT FOCUS =================
              Container(
                width: _scaleForWidth(screenWidth, 42),
                height: _scaleForWidth(screenWidth, 42),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),

                  // 🔥 GRADIENT WHEN SELECTED
                  gradient:
                      isSelected
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
                          : null,

                  color: isSelected ? null : Colors.transparent,

                  boxShadow:
                      isSelected
                          ? [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.35),
                              blurRadius: 22,
                              offset: const Offset(0, 6),
                            ),
                          ]
                          : [],
                ),
                child: Icon(
                  isSelected ? filledIcon : outlineIcon,
                  color: isSelected ? Colors.white : _textSecondary,
                  size:
                      isSelected
                          ? _scaleForWidth(screenWidth, 26)
                          : _scaleForWidth(screenWidth, 24),
                ),
              ),

              const SizedBox(height: 4),

              // ================= MICRO INDICATOR DOT =================
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: isSelected ? 6 : 0,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
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
          // Clean AppBar (matching NavBarPage)
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
                  // Add Rental Item button (when on Items page)
                  if (_currentIndex == 2) _buildAddRentalButton(screenWidth),
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
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _pages[_currentIndex],
                          transitionBuilder: (
                            Widget child,
                            Animation<double> animation,
                          ) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // Clean Navigation Bar (matching NavBarPage)
      bottomNavigationBar: SafeArea(child: _buildCleanNavigation(screenWidth)),
    );
  }
}
