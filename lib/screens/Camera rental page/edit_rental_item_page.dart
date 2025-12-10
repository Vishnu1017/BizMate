import 'dart:io';
import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../models/rental_item.dart';

class EditRentalItemPage extends StatefulWidget {
  final RentalItem item;
  final int index;
  final String userEmail;

  const EditRentalItemPage({
    super.key,
    required this.item,
    required this.index,
    required this.userEmail,
  });

  @override
  State<EditRentalItemPage> createState() => _EditRentalItemPageState();
}

class _EditRentalItemPageState extends State<EditRentalItemPage> {
  late TextEditingController nameController;
  late TextEditingController brandController;
  late TextEditingController priceController;

  String availability = 'Available';
  String condition = 'Excellent'; // Add condition field

  late Box<RentalItem> rentalBox;
  Box? userBox;
  List<RentalItem> userItems = [];

  // Condition options
  final List<String> _conditions = [
    'Brand New',
    'Excellent',
    'Good',
    'Fair',
    'Needs Repair',
  ];

  @override
  void initState() {
    super.initState();

    rentalBox = Hive.box<RentalItem>('rental_items');

    nameController = TextEditingController(text: widget.item.name);
    brandController = TextEditingController(text: widget.item.brand);
    priceController = TextEditingController(text: widget.item.price.toString());
    availability = widget.item.availability;
    condition = widget.item.condition; // Initialize condition

    _initUserBox();
  }

  Future<void> _initUserBox() async {
    final safeEmail = widget.userEmail
        .replaceAll('.', '_')
        .replaceAll('@', '_');

    userBox = await Hive.openBox("userdata_$safeEmail");

    final stored = userBox!.get("rental_items", defaultValue: []);
    userItems = List<RentalItem>.from(stored);
  }

  void _saveChanges() async {
    final updatedItem = RentalItem(
      name: nameController.text.trim(),
      brand: brandController.text.trim(),
      price: double.tryParse(priceController.text) ?? 0,
      imagePath: widget.item.imagePath,
      availability: availability,
      category: widget.item.category,
      condition: condition,
    );

    // ✅ SAFELY UPDATE GLOBAL BOX
    if (widget.index >= 0 && widget.index < rentalBox.length) {
      // normal update
      await rentalBox.putAt(widget.index, updatedItem);
    } else {
      // fallback: find and replace
      final existingIndex = rentalBox.values.toList().indexWhere(
        (i) =>
            i.name == widget.item.name &&
            i.brand == widget.item.brand &&
            i.imagePath == widget.item.imagePath,
      );

      if (existingIndex != -1) {
        await rentalBox.putAt(existingIndex, updatedItem);
      } else {
        // last safety: add
        await rentalBox.add(updatedItem);
      }
    }

    // ✅ USER-SPECIFIC BOX (ALREADY SAFE)
    if (userItems.isNotEmpty && widget.index < userItems.length) {
      userItems[widget.index] = updatedItem;
    } else {
      userItems.add(updatedItem);
    }

    await userBox!.put("rental_items", userItems);

    AppSnackBar.showSuccess(
      context,
      message: 'Changes saved successfully!',
      duration: const Duration(seconds: 2),
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      Navigator.pop(context, updatedItem);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Color(0xFFF8FAFD),
      appBar: AppBar(
        title: const Text(
          'Edit Item',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image section with modern design
            Container(
              height: size.height * 0.25,
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Image.file(
                      File(widget.item.imagePath),
                      height: size.height * 0.25,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Form section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Item Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Update your rental item information',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),

                  _buildTextField(
                    nameController,
                    'Item Name',
                    Icons.photo_camera_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    brandController,
                    'Brand',
                    Icons.business_center_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    priceController,
                    'Price per day',
                    Icons.currency_rupee,
                    isNumber: true,
                  ),
                  const SizedBox(height: 16),

                  // Condition dropdown - ADDED
                  _buildConditionDropdown(),
                  const SizedBox(height: 16),

                  // Availability dropdown
                  _buildAvailabilityDropdown(),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Save Button
            Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _saveChanges,
                  borderRadius: BorderRadius.circular(16),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_rounded, color: Colors.white, size: 22),
                      SizedBox(width: 12),
                      Text(
                        'Save Changes',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Cancel Button
            Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                border: Border.all(color: Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.close_rounded,
                        color: Colors.grey[600],
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Color(0xFFE5E7EB), width: 1.5),
          ),
          child: TextField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Color(0xFF2563EB)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              hintText: 'Enter $label',
              hintStyle: TextStyle(color: Colors.grey[500]),
            ),
          ),
        ),
      ],
    );
  }

  // NEW: Condition Dropdown Widget
  Widget _buildConditionDropdown() {
    // Helper function to get color for condition
    Color getConditionColor(String condition) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Equipment Condition',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Color(0xFFF9FAFB),
            border: Border.all(color: Color(0xFFE5E7EB), width: 1.5),
          ),
          child: DropdownButtonFormField<String>(
            value: condition,
            dropdownColor: Colors.white,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF2563EB),
              size: 24,
            ),
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              prefixIcon: Icon(
                Icons.construction_outlined,
                color: Color(0xFF2563EB),
              ),
            ),
            items:
                _conditions.map((condition) {
                  return DropdownMenuItem(
                    value: condition,
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: getConditionColor(condition),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          condition,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
            onChanged: (value) => setState(() => condition = value!),
          ),
        ),
      ],
    );
  }

  // Updated Availability Dropdown Widget
  Widget _buildAvailabilityDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Availability Status',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Color(0xFFF9FAFB),
            border: Border.all(color: Color(0xFFE5E7EB), width: 1.5),
          ),
          child: DropdownButtonFormField<String>(
            value: availability,
            dropdownColor: Colors.white,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF2563EB),
              size: 24,
            ),
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              prefixIcon: Icon(
                Icons.event_available_outlined,
                color: Color(0xFF2563EB),
              ),
            ),
            items: [
              DropdownMenuItem(
                value: 'Available',
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('Available'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'Not Available',
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('Not Available'),
                  ],
                ),
              ),
            ],
            onChanged: (value) => setState(() => availability = value!),
          ),
        ),
      ],
    );
  }
}
