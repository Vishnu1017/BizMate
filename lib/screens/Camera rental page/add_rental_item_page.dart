import 'dart:io';
import 'package:bizmate/models/rental_item.dart';
import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart'
    show getApplicationDocumentsDirectory;

class AddRentalItemPage extends StatefulWidget {
  const AddRentalItemPage({super.key});

  @override
  State<AddRentalItemPage> createState() => _AddRentalItemPageState();
}

class _AddRentalItemPageState extends State<AddRentalItemPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  String _availability = 'Available';
  String _selectedCategory = 'Camera';
  File? _selectedImage;

  final List<String> _categories = [
    'Camera',
    'Lens',
    'Light',
    'Tripod',
    'Drone',
    'Gimbal',
    'Microphone',
  ];

  final ImagePicker _picker = ImagePicker();

  Future<File> _saveImagePermanently(String path) async {
    final directory = await getApplicationDocumentsDirectory();
    final folder = Directory("${directory.path}/rental_images");

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
    final newImage = File("${folder.path}/$fileName");

    return File(path).copy(newImage.path);
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      // SAVE IT PERMANENTLY
      final savedFile = await _saveImagePermanently(pickedFile.path);

      setState(() => _selectedImage = savedFile);
    }
  }

  Future<void> _saveItem() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedImage == null) {
        AppSnackBar.showWarning(
          context,
          message: 'Please upload an image!',
          duration: Duration(seconds: 2),
        );
        return;
      }

      // 🔥 Load logged-in user email
      if (!Hive.isBoxOpen('session')) {
        await Hive.openBox('session');
      }
      final sessionBox = Hive.box('session');
      final currentEmail = sessionBox.get("currentUserEmail");

      if (currentEmail == null || currentEmail.toString().isEmpty) {
        AppSnackBar.showError(
          context,
          message: "No logged-in user found!",
          duration: Duration(seconds: 2),
        );
        return;
      }

      // 🔥 Convert email → safe box name
      final safeEmail = currentEmail.replaceAll('.', '_').replaceAll('@', '_');

      // 🔥 Open user-specific box
      final userBox = await Hive.openBox("userdata_$safeEmail");

      // 🔥 Prepare rental item
      final item = RentalItem(
        name: _nameController.text.trim(),
        brand: _brandController.text.trim(),
        category: _selectedCategory,
        price: double.parse(_priceController.text.trim()),
        availability: _availability,
        imagePath: _selectedImage!.path,
      );

      // 🔥 Read existing rental list
      List<RentalItem> rentalList = List<RentalItem>.from(
        userBox.get("rental_items", defaultValue: []),
      );

      // 🔥 Add item to user's private list
      rentalList.add(item);

      // 🔥 Save back to box
      await userBox.put("rental_items", rentalList);

      AppSnackBar.showSuccess(
        context,
        message: 'Item added successfully!',
        duration: Duration(seconds: 2),
      );
      _clearForm();
    }
  }

  void _clearForm() {
    _nameController.clear();
    _brandController.clear();
    _priceController.clear();
    setState(() {
      _availability = 'Available';
      _selectedCategory = 'Camera';
      _selectedImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF00BCD4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Add Rental Item',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF00BCD4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width > 600 ? 500 : width),
              child: Card(
                color: Colors.white,
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                shadowColor: Colors.black26,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Add New Item',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 📸 Image Picker
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            height: 180,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE3F2FD), Color(0xFFB2EBF2)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: Colors.blueAccent.shade100,
                                width: 2,
                              ),
                            ),
                            child:
                                _selectedImage == null
                                    ? const Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_a_photo_rounded,
                                            color: Color(0xFF1A237E),
                                            size: 40,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Tap to upload image',
                                            style: TextStyle(
                                              color: Color(0xFF1A237E),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    : ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: Image.file(
                                        _selectedImage!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      ),
                                    ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _nameController,
                          label: 'Item Name',
                          icon: Icons.camera_alt_rounded,
                        ),
                        const SizedBox(height: 15),
                        _buildTextField(
                          controller: _brandController,
                          label: 'Brand',
                          icon: Icons.branding_watermark_rounded,
                        ),
                        const SizedBox(height: 15),
                        _buildGradientDropdown(
                          label: 'Category',
                          icon: Icons.category_rounded,
                          value: _selectedCategory,
                          items: _categories,
                          onChanged:
                              (value) =>
                                  setState(() => _selectedCategory = value!),
                        ),
                        const SizedBox(height: 15),
                        _buildTextField(
                          controller: _priceController,
                          label: 'Rental Price per Day (₹)',
                          icon: Icons.currency_rupee_rounded,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 15),

                        // ✅ Availability Dropdown with icon
                        _buildGradientDropdown(
                          label: 'Availability',
                          icon:
                              _availability == 'Available'
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                          iconColor:
                              _availability == 'Available'
                                  ? Colors.green
                                  : Colors.redAccent,
                          value: _availability,
                          items: const ['Available', 'Not Available'],
                          onChanged:
                              (value) => setState(() => _availability = value!),
                        ),
                        const SizedBox(height: 30),

                        // ✨ Gradient Add Button
                        Container(
                          height: 55,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1A237E), Color(0xFF00BCD4)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            onPressed: _saveItem,
                            icon: const Icon(
                              Icons.add_box_rounded,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Add Item',
                              style: TextStyle(
                                fontSize: 18,
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientDropdown({
    required String label,
    required IconData icon,
    Color? iconColor,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFB2EBF2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: DropdownButtonFormField<String>(
          value: value,
          items:
              items
                  .map(
                    (cat) => DropdownMenuItem(
                      value: cat,
                      child: Text(
                        cat,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  )
                  .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: iconColor ?? const Color(0xFF1A237E)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          dropdownColor: Colors.white,
          iconEnabledColor: const Color(0xFF1A237E),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: (value) {
        // ⭐ AUTO CAPITALIZE FIRST LETTER (Item Name & Brand)
        if (label == "Item Name" || label == "Brand") {
          if (value.isNotEmpty) {
            final formatted =
                value[0].toUpperCase() +
                (value.length > 1 ? value.substring(1) : "");
            if (formatted != value) {
              controller.value = controller.value.copyWith(
                text: formatted,
                selection: TextSelection.collapsed(offset: formatted.length),
              );
            }
          }
        }
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.black54),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator:
          (value) =>
              value == null || value.isEmpty ? 'Please enter $label' : null,
    );
  }
}
