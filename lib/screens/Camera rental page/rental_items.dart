import 'dart:async';
import 'dart:io';
import 'package:bizmate/screens/Camera rental page/view_rental_details_page.dart';
import 'package:bizmate/widgets/confirm_delete_dialog.dart';
import 'package:bizmate/widgets/advanced_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/rental_item.dart';
import 'edit_rental_item_page.dart';

class RentalItems extends StatefulWidget {
  final String userEmail;

  const RentalItems({super.key, required this.userEmail});

  @override
  State<RentalItems> createState() => _RentalItemsState();
}

class _RentalItemsState extends State<RentalItems> {
  late Box userBox;
  double scale = 1.0;
  List<RentalItem> rentalItems = [];
  List<RentalItem> filteredItems = [];
  final ScrollController _scrollController = ScrollController();
  int? _latestItemIndex;
  Timer? _newBadgeTimer;

  String _searchQuery = "";
  String _selectedCategory = "All";

  final List<String> _categories = [
    'All',
    'Camera',
    'Lens',
    'Lighting',
    'Tripod',
    'Drone',
    'Gimbal',
    'Audio',
    'Video',
    'Accessories',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserSpecificBox();
  }

  @override
  void dispose() {
    try {
      userBox
          .listenable(keys: ['rental_items'])
          .removeListener(_onRentalItemsChanged);
    } catch (_) {}

    _scrollController.dispose();
    _newBadgeTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserSpecificBox() async {
    try {
      // 🔥 Ensure session box is open
      if (!Hive.isBoxOpen('session')) {
        await Hive.openBox('session');
      }

      final sessionBox = Hive.box('session');
      final email = sessionBox.get("currentUserEmail");

      if (email == null) {
        rentalItems = [];
        filteredItems = [];
        setState(() {});
        return;
      }

      final safeEmail = email
          .toString()
          .replaceAll('.', '_')
          .replaceAll('@', '_');

      final boxName = "userdata_$safeEmail";

      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox(boxName);
      }

      userBox = Hive.box(boxName);

      // 🔥 Load once
      _loadItems();

      // 🔥 Safe listener
      userBox
          .listenable(keys: ['rental_items'])
          .addListener(_onRentalItemsChanged);
    } catch (e) {
      rentalItems = [];
      filteredItems = [];
      setState(() {});
    }
  }

  void _onRentalItemsChanged() {
    if (!mounted) return;
    _loadItems();
  }

  void _startNewItemEffect() {
    // Auto scroll to top
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }

    // Remove badge after 3 seconds
    _newBadgeTimer?.cancel();
    _newBadgeTimer = Timer(const Duration(seconds: 3), () {
      setState(() {
        _latestItemIndex = null;
      });
    });

    setState(() {});
  }

  void _loadItems() {
    try {
      final raw = userBox.get('rental_items', defaultValue: []);
      List<RentalItem> originalList = List<RentalItem>.from(raw);

      // 🔥 Reverse ONLY for display
      rentalItems = originalList.reversed.toList();

      if (rentalItems.isNotEmpty) {
        _latestItemIndex = 0;
        _startNewItemEffect();
      }

      _filterItems();
    } catch (e) {
      rentalItems = [];
      filteredItems = [];
      setState(() {});
    }
  }

  void _saveItems() {
    userBox.put('rental_items', rentalItems);
  }

  void _handleSearchChanged(String query) {
    _searchQuery = query;
    _filterItems();
  }

  void _handleDateRangeChanged(DateTimeRange? range) {
    _filterItems();
  }

  void _filterItems() {
    List<RentalItem> temp = List.from(rentalItems);

    if (_selectedCategory != "All") {
      temp = temp.where((i) => i.category == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      temp =
          temp
              .where(
                (i) =>
                    i.name.toLowerCase().contains(q) ||
                    i.brand.toLowerCase().contains(q) ||
                    i.availability.toLowerCase().contains(q) ||
                    i.price.toString().contains(q) ||
                    (i.condition).toLowerCase().contains(q),
              )
              .toList();
    }
    filteredItems = temp;
    setState(() {});
  }

  void _deleteItem(RentalItem itemToDelete) {
    showConfirmDialog(
      context: context,
      title: "Delete Item?",
      message: "Are you sure you want to remove this item permanently?",
      icon: Icons.delete_forever_rounded,
      iconColor: Colors.redAccent,
      onConfirm: () {
        final raw = userBox.get('rental_items', defaultValue: []);
        List<RentalItem> originalList = List<RentalItem>.from(raw);

        // 🔥 Remove by matching item (SAFE even with filters & reverse)
        originalList.removeWhere(
          (item) =>
              item.name == itemToDelete.name &&
              item.brand == itemToDelete.brand &&
              item.imagePath == itemToDelete.imagePath,
        );

        userBox.put('rental_items', originalList);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          AdvancedSearchBar(
            hintText: 'Search rental items...',
            onSearchChanged: _handleSearchChanged,
            onDateRangeChanged: _handleDateRangeChanged,
            showDateFilter: false,
          ),

          // CATEGORY CHIPS
          SizedBox(
            height: 28 * scale,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12 * scale),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => SizedBox(width: 8 * scale),
              itemBuilder: (context, i) {
                final category = _categories[i];
                bool selected = _selectedCategory == category;

                return GestureDetector(
                  onTap: () {
                    _selectedCategory = category;
                    _filterItems();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: EdgeInsets.symmetric(horizontal: 10 * scale),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30 * scale),
                      gradient:
                          selected
                              ? LinearGradient(
                                colors: [
                                  Color(0xFF2563EB),
                                  Color(0xFF1E40AF),
                                  Color(0xFF020617),
                                ],
                                stops: [0.0, 0.6, 1.0],
                                begin: Alignment.bottomRight,
                                end: Alignment.topLeft,
                              )
                              : LinearGradient(
                                colors: [
                                  Colors.grey.shade200,
                                  Colors.grey.shade300,
                                ],
                              ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getCategoryIcon(category),
                          size: 12 * scale,
                          color: selected ? Colors.white : Colors.grey.shade700,
                        ),
                        SizedBox(width: 6 * scale),
                        Text(
                          category,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.grey[900],
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 10 * scale,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 6 * scale),
          Expanded(
            child:
                filteredItems.isEmpty && rentalItems.isEmpty
                    ? const Center(
                      child: Text(
                        'No items added yet!',
                        style: TextStyle(color: Colors.grey, fontSize: 18),
                      ),
                    )
                    : filteredItems.isEmpty
                    ? const Center(
                      child: Text(
                        "No items match your filters",
                        style: TextStyle(color: Colors.grey, fontSize: 18),
                      ),
                    )
                    : _buildGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        int columns;
        double ratio;

        // 🔥 FIXED RESPONSIVE LOGIC
        if (width <= 380) {
          columns = 2;
          ratio = 0.62; // MORE HEIGHT → button fits
        } else if (width <= 600) {
          columns = 2;
          ratio = 0.75;
        } else if (width <= 900) {
          columns = 3;
          ratio = 0.70;
        } else if (width <= 1200) {
          columns = 4;
          ratio = 0.68;
        } else {
          columns = 5;
          ratio = 0.65;
        }

        return GridView.builder(
          controller: _scrollController, // 🔥 ADD THIS
          padding: EdgeInsets.symmetric(
            horizontal: width <= 380 ? 10 : 14,
            vertical: 14,
          ),
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: width <= 380 ? 10 : 12,
            mainAxisSpacing: width <= 380 ? 10 : 12,
            childAspectRatio: ratio,
          ),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            final originalIndex = index;

            return GestureDetector(
              onLongPress: () => _deleteItem(item),
              onTap: () {
                final raw = userBox.get('rental_items', defaultValue: []);
                List<RentalItem> originalList = List<RentalItem>.from(raw);

                // 🔥 Find REAL index inside Hive box
                final realIndex = originalList.indexWhere(
                  (i) =>
                      i.name == item.name &&
                      i.brand == item.brand &&
                      i.imagePath == item.imagePath,
                );

                if (realIndex == -1) return; // safety

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => EditRentalItemPage(
                          item: item,
                          index: realIndex, // ✅ correct index
                          userEmail: widget.userEmail,
                        ),
                  ),
                );
              },
              child: _buildCard(item, originalIndex),
            );
          },
        );
      },
    );
  }

  Widget _buildCard(RentalItem item, int index) {
    final conditionSafe = item.condition;
    final bool isNewItem =
        _latestItemIndex != null && index == _latestItemIndex;

    return LayoutBuilder(
      builder: (context, c) {
        final bool isSmallPhone = c.maxWidth <= 180;
        final double imageHeight = c.maxHeight * 0.38;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),

            // 🔥 Sticky Highlight Border
            border:
                isNewItem
                    ? Border.all(color: Colors.redAccent, width: 2)
                    : null,

            gradient: const LinearGradient(
              colors: [Color(0xFFE3F2FD), Color(0xFFB2EBF2)],
            ),

            boxShadow: [
              if (isNewItem)
                BoxShadow(
                  color: Colors.redAccent.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              const BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(18 * scale),
                    ),
                    child: Image.file(
                      File(item.imagePath),
                      height: imageHeight,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),

                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8 * scale,
                        vertical: 6 * scale,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0D47A1),
                              fontSize: isSmallPhone ? 10 : 12 * scale,
                            ),
                          ),

                          SizedBox(height: 4 * scale),

                          Row(
                            children: [
                              Icon(Icons.camera, size: 10 * scale),
                              SizedBox(width: 4 * scale),
                              Expanded(
                                child: Text(
                                  item.brand,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 9 * scale),
                                ),
                              ),
                              SizedBox(width: 6 * scale),
                              Icon(
                                Icons.circle,
                                size: 6 * scale,
                                color: _getConditionColor(conditionSafe),
                              ),
                              SizedBox(width: 4 * scale),
                              Text(
                                conditionSafe,
                                style: TextStyle(
                                  fontSize: 8 * scale,
                                  fontWeight: FontWeight.w600,
                                  color: _getConditionColor(conditionSafe),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: isSmallPhone ? 20 : 24),

                          Container(
                            padding: EdgeInsets.all(6 * scale),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8 * scale),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '₹${item.price.toStringAsFixed(0)}/day',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10 * scale,
                                    color: Colors.teal,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  item.availability == 'Available'
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color:
                                      item.availability == 'Available'
                                          ? Colors.green
                                          : Colors.red,
                                  size: 14 * scale,
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 8 * scale),

                          SizedBox(
                            width: double.infinity,
                            height: isSmallPhone ? 34 : 38,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D47A1),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => ViewRentalDetailsPage(
                                          item: item,
                                          name: item.name,
                                          imageUrl: item.imagePath,
                                          pricePerDay: item.price,
                                          availability: item.availability,
                                        ),
                                  ),
                                );
                              },
                              child: Text(
                                'Place Order',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isSmallPhone ? 9 : 11 * scale,
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

              // 🔥 TOP RIGHT SECTION (NEW + Availability + Delete)
              Positioned(
                top: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 🏷 NEW Badge
                    if (isNewItem)
                      AnimatedScale(
                        duration: const Duration(milliseconds: 600),
                        scale: 1,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: EdgeInsets.symmetric(
                            horizontal: 6 * scale,
                            vertical: 2 * scale,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B6B), Color(0xFFFF3B3B)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            "NEW",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8 * scale,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),

                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8 * scale,
                            vertical: 4 * scale,
                          ),
                          decoration: BoxDecoration(
                            color:
                                item.availability == 'Available'
                                    ? Colors.green.withOpacity(0.9)
                                    : Colors.redAccent.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.availability,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8 * scale,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _deleteItem(item),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                              size: 12 * scale,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // CONDITION COLORS
  Color _getConditionColor(String condition) {
    switch (condition) {
      case 'Brand New':
        return Colors.green;
      case 'Excellent':
        return Colors.teal;
      case 'Good':
        return Colors.orange;
      case 'Fair':
        return Colors.orangeAccent;
      case 'Needs Repair':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'camera':
        return Icons.camera_alt_outlined;
      case 'lens':
        return Icons.lens_outlined;
      case 'lighting':
        return Icons.lightbulb_outline;
      case 'tripod':
        return Icons.camera_alt_outlined;
      case 'drone':
        return Icons.airplanemode_active;
      case 'gimbal':
        return Icons.video_stable_outlined;
      case 'audio':
        return Icons.mic_outlined;
      case 'video':
        return Icons.videocam_outlined;
      case 'accessories':
        return Icons.settings_input_component_outlined;
      default:
        return Icons.category_outlined;
    }
  }
}
