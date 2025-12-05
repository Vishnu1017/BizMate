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

  List<RentalItem> rentalItems = [];
  List<RentalItem> filteredItems = [];

  String _searchQuery = "";
  String _selectedCategory = "All";

  final List<String> _categories = [
    'All',
    'Camera',
    'Lens',
    'Light',
    'Tripod',
    'Drone',
    'Gimbal',
    'Microphone',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserSpecificBox();
  }

  Future<void> _loadUserSpecificBox() async {
    final sessionBox = Hive.box('session');
    final email = sessionBox.get("currentUserEmail");

    final safeEmail = email
        .toString()
        .replaceAll('.', '_')
        .replaceAll('@', '_');
    final boxName = "userdata_$safeEmail";

    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }

    userBox = Hive.box(boxName);

    _loadItems();
    userBox.listenable(keys: ['rental_items']).addListener(() => _loadItems());
  }

  void _loadItems() {
    try {
      final raw = userBox.get('rental_items', defaultValue: []);
      rentalItems = List<RentalItem>.from(raw);
      filteredItems = rentalItems;

      _filterItems();
      setState(() {});
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

  void _deleteItem(int index) {
    showConfirmDialog(
      context: context,
      title: "Delete Item?",
      message: "Are you sure you want to remove this item permanently?",
      icon: Icons.delete_forever_rounded,
      iconColor: Colors.redAccent,
      onConfirm: () {
        rentalItems.removeAt(index);
        _saveItems();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double responsivePadding = MediaQuery.of(context).size.width * 0.02;

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
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: responsivePadding,
              vertical: responsivePadding / 1,
            ),
            child: SizedBox(
              height: 35,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
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
                      padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width * 0.025,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient:
                            selected
                                ? LinearGradient(
                                  colors: [
                                    Colors.blue.shade700,
                                    Colors.blue.shade900,
                                  ],
                                )
                                : LinearGradient(
                                  colors: [
                                    Colors.grey.shade200,
                                    Colors.grey.shade300,
                                  ],
                                ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 14,
                            color:
                                selected ? Colors.white : Colors.grey.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            category,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.grey[900],
                              fontWeight:
                                  selected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          Expanded(
            child:
                rentalItems.isEmpty
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
        double width = constraints.maxWidth;

        int columns;
        double ratio;

        if (width <= 380) {
          columns = 1;
          ratio = 0.85;
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
          padding: const EdgeInsets.all(14),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: ratio,
          ),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            final originalIndex = rentalItems.indexOf(item);

            return GestureDetector(
              onLongPress: () => _deleteItem(originalIndex),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => EditRentalItemPage(
                          item: item,
                          index: originalIndex,
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

    return LayoutBuilder(
      builder: (context, c) {
        double imageHeight = c.maxHeight * 0.40;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFFE3F2FD), Color(0xFFB2EBF2)],
            ),
            boxShadow: const [
              BoxShadow(
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
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D47A1),
                              fontSize: 15,
                            ),
                          ),

                          const SizedBox(height: 3),

                          // BRAND + CONDITION IN ONE PRODUCTION ROW
                          Row(
                            children: [
                              const Icon(Icons.camera, size: 14),
                              const SizedBox(width: 5),

                              Expanded(
                                child: Text(
                                  item.brand,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),

                              const SizedBox(width: 10),

                              Icon(
                                Icons.circle,
                                size: 10,
                                color: _getConditionColor(conditionSafe),
                              ),
                              const SizedBox(width: 4),

                              Text(
                                conditionSafe,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _getConditionColor(conditionSafe),
                                ),
                              ),
                            ],
                          ),

                          const Spacer(),

                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '₹${item.price.toStringAsFixed(0)}/day',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
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
                                  size: 18,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D47A1),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
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
                              child: const Text(
                                'Place Order',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
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

              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _deleteItem(index),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
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
        return Colors.redAccent;
      case 'Needs Repair':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }
}
