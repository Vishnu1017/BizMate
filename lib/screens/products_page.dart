// lib/screens/products_page.dart
// FULL FIXED – USER SPECIFIC PRODUCTS + SEARCH + DELETE + NO BUILD ERRORS

import 'package:bizmate/widgets/confirm_delete_dialog.dart'
    show showConfirmDialog;
import 'package:bizmate/widgets/advanced_search_bar.dart'
    show AdvancedSearchBar;
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
  List<Product> _filteredProducts = [];

  Box<dynamic>? userBox;

  @override
  void initState() {
    super.initState();
    _loadUserProducts();
  }

  // ---------------- LOAD USER-SPECIFIC PRODUCTS ----------------
  Future<void> _loadUserProducts() async {
    // Load logged-in user's email
    if (!Hive.isBoxOpen('session')) await Hive.openBox('session');
    final sessionBox = Hive.box('session');
    final email = sessionBox.get('currentUserEmail');

    if (email == null) {
      setState(() {
        _allProducts = [];
        _filteredProducts = [];
      });
      return;
    }

    final safeEmail = email.replaceAll('.', '_').replaceAll('@', '_');
    final boxName = 'userdata_$safeEmail';

    userBox =
        Hive.isBoxOpen(boxName)
            ? Hive.box(boxName)
            : await Hive.openBox(boxName);

    // Ensure products key exists
    if (!userBox!.containsKey('products')) {
      await userBox!.put('products', <Product>[]);
    }

    final List<Product> loaded = List<Product>.from(
      userBox!.get("products", defaultValue: <Product>[]),
    );

    setState(() {
      _allProducts = loaded;
      _filteredProducts = List.from(_allProducts);
    });
  }

  // ---------------- SEARCH ----------------
  void _filterProducts() {
    if (_searchQuery.isEmpty) {
      _filteredProducts = List.from(_allProducts);
      setState(() {});
      return;
    }

    final q = _searchQuery.toLowerCase();

    _filteredProducts =
        _allProducts.where((p) => p.name.toLowerCase().contains(q)).toList();

    setState(() {});
  }

  void _handleSearchChanged(String query) {
    _searchQuery = query;
    _filterProducts();
  }

  void _handleDateRangeChanged(DateTimeRange? range) {
    // Not needed for products
  }

  // ---------------- DELETE PRODUCT ----------------
  Future<bool> _confirmDelete(int realIndex) async {
    bool confirmed = false;

    await showConfirmDialog(
      context: context,
      title: "Confirm Deletion",
      message: "Are you sure you want to delete this package?",
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.redAccent,
      onConfirm: () {
        confirmed = true;
      },
    );

    if (confirmed && realIndex >= 0) {
      _allProducts.removeAt(realIndex);
      await userBox!.put("products", _allProducts);

      // Refresh filtered list
      _filterProducts();
      setState(() {});
    }

    return confirmed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Column(
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
                // Reload list when Hive updates (no setState!)
                final List<Product> newList = List<Product>.from(
                  userBox!.get("products", defaultValue: <Product>[]),
                );

                _allProducts = newList;

                // Re-apply filter
                if (_searchQuery.isEmpty) {
                  _filteredProducts = List.from(_allProducts);
                } else {
                  _filterProducts();
                }

                if (_filteredProducts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty
                              ? Icons.inventory_2
                              : Icons.search_off,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? "No Packages Yet"
                              : "No matching packages found",
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 16,
                  ),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = _filteredProducts[index];
                    final realIndex = _allProducts.indexOf(product);

                    return Dismissible(
                      key: Key(product.name + index.toString()),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmDelete(realIndex),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00BCD4), Color(0xFF1A237E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          leading: const CircleAvatar(
                            backgroundColor: Colors.white,
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedShoppingBasket01,
                              color: Color(0xFF1A237E),
                            ),
                          ),
                          title: Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            "Rate: ₹${product.rate.toStringAsFixed(2)}",
                            style: const TextStyle(color: Colors.white70),
                          ),
                          trailing: const Icon(
                            Icons.drag_handle,
                            color: Colors.white70,
                          ),
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
    );
  }
}
