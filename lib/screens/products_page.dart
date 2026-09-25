// lib/screens/products_page.dart
// FIXED — NO setState-inside-build + FULL RESPONSIVE

import 'package:bizmate/widgets/confirm_delete_dialog.dart'
    show showConfirmDialog;
import 'package:bizmate/widgets/advanced_search_bar.dart'
    show AdvancedSearchBar;
import 'package:bizmate/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:bizmate/models/product.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hugeicons/hugeicons.dart' show HugeIcon, HugeIcons;

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key, required String userEmail});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  String _searchQuery = "";
  List<Product> _allProducts = [];
  final ScrollController _scrollController = ScrollController();
  int _previousProductCount = 0;
  Box<dynamic>? userBox;

  @override
  void initState() {
    super.initState();
    _loadUserProducts();
  }

  // ---------------- LOAD USER-SPECIFIC PRODUCTS ----------------
  Future<void> _loadUserProducts() async {
    if (!Hive.isBoxOpen('session')) await Hive.openBox('session');
    final email = Hive.box('session').get("currentUserEmail");

    if (email == null) {
      setState(() {
        _allProducts = [];
      });
      return;
    }

    final safeEmail = email.replaceAll('.', '_').replaceAll('@', '_');
    final boxName = 'userdata_$safeEmail';

    userBox =
        Hive.isBoxOpen(boxName)
            ? Hive.box(boxName)
            : await Hive.openBox(boxName);

    if (!userBox!.containsKey('products')) {
      await userBox!.put('products', <Product>[]);
    }

    final List<Product> loaded = List<Product>.from(
      userBox!.get("products", defaultValue: <Product>[]),
    );

    setState(() {
      _allProducts = loaded;
    });
  }

  // ---------------- SEARCH ----------------
  void _filterProducts() {
    if (_searchQuery.isEmpty) {
    } else {
      _searchQuery.toLowerCase();
    }
    setState(() {});
  }

  void _handleSearchChanged(String query) {
    _searchQuery = query;
    _filterProducts();
  }

  void _handleDateRangeChanged(DateTimeRange? range) {}

  // ---------------- DELETE PRODUCT ----------------
  Future<bool> _confirmDelete(int realIndex) async {
    bool confirmed = false;

    await showConfirmDialog(
      context: context,
      title: "Confirm Deletion",
      message: "Are you sure you want to delete this package?",
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.redAccent,
      onConfirm: () => confirmed = true,
    );

    if (confirmed) {
      _allProducts.removeAt(realIndex);
      await userBox!.put("products", _allProducts);

      _filterProducts();
    }

    return confirmed;
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: MediaQuery.removePadding(
        removeTop: true,
        context: context,
        child: Column(
          children: [
            AdvancedSearchBar(
              hintText: 'Search packages...',
              onSearchChanged: _handleSearchChanged,
              onDateRangeChanged: _handleDateRangeChanged,
              showDateFilter: false,
            ),

            // -------- PRODUCTS LIST --------
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: userBox!.listenable(),
                builder: (context, box, _) {
                  // 🔥 REPLACE setState WITH LOCAL COMPUTATION
                  final List<Product> newList = List<Product>.from(
                    userBox!.get("products", defaultValue: <Product>[]),
                  );
                  // 🔥 AUTO SCROLL TO TOP WHEN NEW PRODUCT ADDED
                  if (newList.length > _previousProductCount) {
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

                  _previousProductCount = newList.length;
                  // Local assignments (NO setState)
                  _allProducts = newList;

                  // Local filtered list (NO setState)
                  List<Product> visibleList =
                      _searchQuery.isEmpty
                          ? List.from(_allProducts)
                          : _allProducts
                              .where(
                                (p) => p.name.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                ),
                              )
                              .toList();

                  if (visibleList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isEmpty
                                ? Icons.inventory_2
                                : Icons.search_off,
                            size: 80 * scale,
                            color: context.textSecondary.withValues(alpha: 0.5),
                          ),
                          SizedBox(height: 16 * scale),
                          Text(
                            _searchQuery.isEmpty
                                ? "No Packages Yet"
                                : "No matching packages found",
                            style: TextStyle(
                              fontSize: 18 * scale,
                              color: context.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: 14 * scale,
                      vertical: 6 * scale,
                    ),
                    itemCount: visibleList.length,
                    itemBuilder: (context, index) {
                      final product = visibleList[index];
                      final realIndex = _allProducts.indexOf(product);

                      return Dismissible(
                        key: Key(product.name + index.toString()),
                        direction:
                            _searchQuery.isEmpty
                                ? DismissDirection.endToStart
                                : DismissDirection.none,
                        confirmDismiss: (_) => _confirmDelete(realIndex),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                          margin: EdgeInsets.only(bottom: 14 * scale),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12 * scale),
                          ),
                          child: Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: 28 * scale,
                          ),
                        ),
                        child: Container(
                          margin: EdgeInsets.only(bottom: 14 * scale),

                          decoration: BoxDecoration(
                            // -----------------------------------------------------------------------
                            // 🎨 THEME-AWARE BLUE GRADIENT
                            // -----------------------------------------------------------------------
                            gradient: LinearGradient(
                              colors:
                                  context.isDark
                                      ? [
                                        const Color(0xFF93C5FD),
                                        const Color(0xFF60A5FA),
                                      ]
                                      : [
                                        const Color(0xFF00BCD4),
                                        const Color(0xFF1A237E),
                                      ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),

                            borderRadius: BorderRadius.circular(12 * scale),

                            // -----------------------------------------------------------------------
                            // ✨ THEME-AWARE SHADOW
                            // -----------------------------------------------------------------------
                            boxShadow: [
                              BoxShadow(
                                color:
                                    context.isDark
                                        ? const Color(
                                          0xFF60A5FA,
                                        ).withValues(alpha: 0.25)
                                        : Colors.black.withValues(alpha: 0.10),
                                blurRadius:
                                    context.isDark ? 14 * scale : 10 * scale,
                                spreadRadius: context.isDark ? 1 : 0,
                                offset: Offset(0, 4 * scale),
                              ),
                            ],
                          ),

                          child: Stack(
                            children: [
                              // ---------------------------------------------------------------------
                              // ✨ DECORATIVE CIRCLE
                              // ---------------------------------------------------------------------
                              Positioned(
                                right: -20,
                                top: -20,
                                child: Container(
                                  width: 100 * scale,
                                  height: 100 * scale,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        context.isDark
                                            ? Colors.white.withValues(
                                              alpha: 0.20,
                                            )
                                            : Colors.white.withValues(
                                              alpha: 0.08,
                                            ),
                                  ),
                                ),
                              ),

                              // ---------------------------------------------------------------------
                              // 🛍 PRODUCT CONTENT
                              // ---------------------------------------------------------------------
                              ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20 * scale,
                                  vertical: 8 * scale,
                                ),

                                // -------------------------------------------------------------------
                                // 🛒 PRODUCT ICON
                                // -------------------------------------------------------------------
                                leading: CircleAvatar(
                                  radius: 20 * scale,
                                  backgroundColor:
                                      context.isDark
                                          ? Colors.white.withValues(alpha: 0.90)
                                          : Colors.white,

                                  child: HugeIcon(
                                    icon:
                                        HugeIcons.strokeRoundedShoppingBasket01,
                                    color:
                                        context.isDark
                                            ? const Color(0xFF2563EB)
                                            : const Color(0xFF1A237E),
                                    size: 20 * scale,
                                  ),
                                ),

                                // -------------------------------------------------------------------
                                // 📦 PRODUCT NAME
                                // -------------------------------------------------------------------
                                title: Text(
                                  product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16 * scale,
                                    color:
                                        context.isDark
                                            ? const Color(0xFF123A66)
                                            : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                // -------------------------------------------------------------------
                                // 💰 PRODUCT RATE
                                // -------------------------------------------------------------------
                                subtitle: Text(
                                  "Rate: ₹${product.rate.toStringAsFixed(2)}",
                                  style: TextStyle(
                                    fontSize: 13 * scale,
                                    color:
                                        context.isDark
                                            ? const Color(0xFF315D89)
                                            : Colors.white70,
                                  ),
                                ),

                                // -------------------------------------------------------------------
                                // ↕ DRAG HANDLE
                                // -------------------------------------------------------------------
                                trailing: Icon(
                                  Icons.drag_handle,
                                  color:
                                      context.isDark
                                          ? const Color(0xFF315D89)
                                          : Colors.white70,
                                  size: 20 * scale,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
