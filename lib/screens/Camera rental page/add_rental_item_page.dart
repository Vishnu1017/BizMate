import 'dart:io';
import 'package:bizmate/models/rental_item.dart';
import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:confetti/confetti.dart';
import 'package:lottie/lottie.dart';

class AddRentalItemPage extends StatefulWidget {
  const AddRentalItemPage({super.key});

  @override
  State<AddRentalItemPage> createState() => _AddRentalItemPageState();
}

class _AddRentalItemPageState extends State<AddRentalItemPage>
    with SingleTickerProviderStateMixin {
  double Scale = 1.0;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  late ConfettiController _confettiController;

  String _availability = 'Available';
  String _selectedCategory = 'Camera';
  String _condition = 'Excellent';
  File? _selectedImage;
  bool _isSaving = false;
  bool _showSuccess = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> _categories = [
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

  final List<String> _conditions = [
    'Brand New',
    'Excellent',
    'Good',
    'Fair',
    'Needs Repair',
  ];

  final ImagePicker _picker = ImagePicker();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _brandFocus = FocusNode();
  final FocusNode _priceFocus = FocusNode();
  final FocusNode _descFocus = FocusNode();

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _confettiController.dispose();
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _nameFocus.dispose();
    _brandFocus.dispose();
    _priceFocus.dispose();
    _descFocus.dispose();
    super.dispose();
  }

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
    HapticFeedback.lightImpact();

    final result = await showModalBottomSheet<ImageSource>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildImageSourceSheet(),
    );

    if (result != null) {
      final pickedFile = await _picker.pickImage(source: result);
      if (pickedFile != null) {
        HapticFeedback.selectionClick();
        final savedFile = await _saveImagePermanently(pickedFile.path);
        setState(() => _selectedImage = savedFile);
      }
    }
  }

  Widget _buildImageSourceSheet() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 24 * Scale,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40 * Scale,
                    height: 40 * Scale,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: Color(0xFF6366F1),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upload Image',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[900],
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Choose image source',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            Padding(
              padding: EdgeInsets.all(20 * Scale),
              child: Row(
                children: [
                  Expanded(
                    child: _buildImageSourceButton(
                      icon: Icons.photo_camera_outlined,
                      label: 'Camera',
                      color: const Color(0xFF10B981),
                      source: ImageSource.camera,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildImageSourceButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Gallery',
                      color: const Color(0xFF6366F1),
                      source: ImageSource.gallery,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceButton({
    required IconData icon,
    required String label,
    required Color color,
    required ImageSource source,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, source),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    if (_selectedImage == null) {
      AppSnackBar.showWarning(
        context,
        message: 'Please upload an image first!',
        duration: const Duration(seconds: 2),
      );
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _isSaving = true);

    try {
      await Future.delayed(const Duration(milliseconds: 300));

      if (!Hive.isBoxOpen('session')) {
        await Hive.openBox('session');
      }
      final sessionBox = Hive.box('session');
      final currentEmail = sessionBox.get("currentUserEmail");

      if (currentEmail == null || currentEmail.toString().isEmpty) {
        AppSnackBar.showError(
          context,
          message: "🔒 No active session found!",
          duration: const Duration(seconds: 2),
        );
        return;
      }

      final safeEmail = currentEmail.replaceAll('.', '_').replaceAll('@', '_');
      final userBox = await Hive.openBox("userdata_$safeEmail");

      final item = RentalItem(
        name: _nameController.text.trim(),
        brand: _brandController.text.trim(),
        category: _selectedCategory,
        price: double.parse(_priceController.text),
        availability: _availability,
        imagePath: _selectedImage!.path,
        condition: _condition, // ⭐ REQUIRED
      );

      List<RentalItem> rentalList = List<RentalItem>.from(
        userBox.get("rental_items", defaultValue: []),
      );

      rentalList.add(item);
      await userBox.put("rental_items", rentalList);

      _confettiController.play();
      HapticFeedback.vibrate();

      setState(() => _showSuccess = true);
      await Future.delayed(const Duration(milliseconds: 1500));

      AppSnackBar.showSuccess(
        context,
        message: '✅ Item added successfully!',
        duration: const Duration(seconds: 2),
      );

      await _clearForm();
    } catch (e) {
      AppSnackBar.showError(
        context,
        message: '❌ Error: ${e.toString()}',
        duration: const Duration(seconds: 2),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _showSuccess = false;
        });
      }
    }
  }

  Future<void> _clearForm() async {
    _animationController.reset();
    await Future.delayed(const Duration(milliseconds: 200));

    _nameController.clear();
    _brandController.clear();
    _priceController.clear();
    setState(() {
      _availability = 'Available';
      _selectedCategory = 'Camera';
      _condition = 'Excellent';
      _selectedImage = null;
    });

    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width > 600;
    final isDesktop = width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, const Color(0xFFF1F5F9)],
                ),
              ),
            ),
          ),

          // Animated Blobs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: isDesktop ? 400 : 300,
              height: isDesktop ? 400 : 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.1),
                    const Color(0xFF8B5CF6).withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: isDesktop ? 400 : 300,
              height: isDesktop ? 400 : 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF10B981).withOpacity(0.1),
                    const Color(0xFF059669).withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ),

          CustomScrollView(
            slivers: [
              // Modern App Bar
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                floating: true,
                expandedHeight: isDesktop ? 200 : (isTablet ? 180 : 160),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF6366F1),
                          const Color(0xFF8B5CF6),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 20,
                          right: 20,
                          child: Container(
                            width: isDesktop ? 150 : (isTablet ? 120 : 100),
                            height: isDesktop ? 150 : (isTablet ? 120 : 100),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 80 : (isTablet ? 70 : 54),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: isDesktop ? 80 : (isTablet ? 60 : 60),
                              ),
                              FadeTransition(
                                opacity: _fadeAnimation,
                                child: SlideTransition(
                                  position: _slideAnimation,
                                  child: Text(
                                    'Add Rental Gear',
                                    style: TextStyle(
                                      fontSize:
                                          isDesktop ? 40 : (isTablet ? 20 : 24),
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              FadeTransition(
                                opacity: _fadeAnimation,
                                child: SlideTransition(
                                  position: _slideAnimation,
                                  child: Text(
                                    'Add your photography equipment to inventory',
                                    style: TextStyle(
                                      fontSize: isDesktop ? 14 : 10,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withOpacity(0.9),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: isDesktop ? 30 : 20),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                leading: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    width: isDesktop ? 45 : (isTablet ? 40 : 35),
                    height: isDesktop ? 45 : (isTablet ? 40 : 35),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: isDesktop ? 28 : (isTablet ? 26 : 24),
                    ),
                  ),
                ),
              ),

              // Main Form
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 40 : (isTablet ? 30 : 20),
                        vertical: isDesktop ? 30 : 20,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth:
                                isDesktop ? 700 : (isTablet ? 600 : width),
                          ),
                          child: _buildFormCard(isTablet, isDesktop),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Success Animation Overlay
          if (_showSuccess)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: Center(
                  child: Lottie.asset(
                    'assets/animations/success.json',
                    width: isDesktop ? 250 : (isTablet ? 220 : 200),
                    height: isDesktop ? 250 : (isTablet ? 220 : 200),
                  ),
                ),
              ),
            ),

          // Confetti
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Color(0xFF6366F1),
              Color(0xFF8B5CF6),
              Color(0xFF10B981),
              Color(0xFFF59E0B),
              Color(0xFFEF4444),
            ],
            numberOfParticles: 50,
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(bool isTablet, bool isDesktop) {
    return Material(
      elevation: 0,
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isDesktop ? 36 : 32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? 32 : (isTablet ? 28 : 24)),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImagePicker(isTablet, isDesktop),
                SizedBox(height: isDesktop ? 32 : (isTablet ? 28 : 24)),
                _buildTextField(
                  controller: _nameController,
                  label: 'Equipment Name',
                  hint: 'e.g., Sony A7III Camera',
                  icon: Icons.camera_alt_outlined,
                  focusNode: _nameFocus,
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                ),
                SizedBox(height: isDesktop ? 20 : (isTablet ? 18 : 16)),
                _buildTextField(
                  controller: _brandController,
                  label: 'Brand',
                  hint: 'e.g., Sony, Canon, Nikon',
                  icon: Icons.branding_watermark_outlined,
                  focusNode: _brandFocus,
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                ),
                SizedBox(height: isDesktop ? 20 : (isTablet ? 18 : 16)),
                _buildCategorySelector(isTablet, isDesktop),
                SizedBox(height: isDesktop ? 20 : (isTablet ? 18 : 16)),
                isDesktop || isTablet
                    ? Row(
                      children: [
                        Expanded(child: _buildPriceField(isTablet, isDesktop)),
                        SizedBox(width: isDesktop ? 24 : 16),
                        Expanded(
                          child: _buildConditionSelector(isTablet, isDesktop),
                        ),
                      ],
                    )
                    : Column(
                      children: [
                        _buildPriceField(isTablet, isDesktop),
                        SizedBox(height: isDesktop ? 20 : (isTablet ? 18 : 16)),
                        _buildConditionSelector(isTablet, isDesktop),
                      ],
                    ),
                SizedBox(height: isDesktop ? 20 : (isTablet ? 18 : 16)),
                _buildAvailabilitySelector(isTablet, isDesktop),
                SizedBox(height: isDesktop ? 40 : (isTablet ? 36 : 32)),
                _buildActionButtons(isTablet, isDesktop),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker(bool isTablet, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: isDesktop ? 48 : (isTablet ? 44 : 40),
              height: isDesktop ? 48 : (isTablet ? 44 : 40),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(isDesktop ? 14 : 12),
              ),
              child: Icon(
                Icons.image_outlined,
                color: const Color(0xFF6366F1),
                size: isDesktop ? 26 : (isTablet ? 24 : 22),
              ),
            ),
            SizedBox(width: isDesktop ? 16 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Equipment Photo',
                    style: TextStyle(
                      fontSize: isDesktop ? 18 : (isTablet ? 17 : 16),
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Clear, well-lit photos work best',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: isDesktop ? 14 : (isTablet ? 13 : 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: isDesktop ? 16 : (isTablet ? 14 : 12)),
        GestureDetector(
          onTap: _pickImage,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: isDesktop ? 220 : (isTablet ? 200 : 180),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(isDesktop ? 28 : 24),
              border: Border.all(
                color:
                    _selectedImage != null
                        ? const Color(0xFF10B981)
                        : (const Color(0xFFE2E8F0)),
                width: _selectedImage != null ? 2 : 1.5,
              ),
              boxShadow:
                  _selectedImage != null
                      ? [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ]
                      : null,
            ),
            child:
                _selectedImage == null
                    ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: isDesktop ? 80 : (isTablet ? 72 : 64),
                          height: isDesktop ? 80 : (isTablet ? 72 : 64),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_photo_alternate_outlined,
                            color: const Color(0xFF6366F1),
                            size: isDesktop ? 36 : (isTablet ? 34 : 30),
                          ),
                        ),
                        SizedBox(height: isDesktop ? 16 : (isTablet ? 14 : 12)),
                        Text(
                          'Tap to upload photo',
                          style: TextStyle(
                            fontSize: isDesktop ? 18 : (isTablet ? 17 : 16),
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: isDesktop ? 8 : (isTablet ? 6 : 4)),
                        Text(
                          'PNG, JPG up to 5MB',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: isDesktop ? 14 : (isTablet ? 13 : 12),
                          ),
                        ),
                      ],
                    )
                    : ClipRRect(
                      borderRadius: BorderRadius.circular(isDesktop ? 26 : 22),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.error_outline),
                                ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.7),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: isDesktop ? 16 : (isTablet ? 14 : 12),
                            left: isDesktop ? 16 : (isTablet ? 14 : 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isDesktop ? 12 : 8,
                                    vertical: isDesktop ? 6 : 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '✓ Uploaded',
                                    style: TextStyle(
                                      fontSize:
                                          isDesktop ? 14 : (isTablet ? 13 : 12),
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: isDesktop ? 12 : (isTablet ? 10 : 8),
                            right: isDesktop ? 12 : (isTablet ? 10 : 8),
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() => _selectedImage = null);
                              },
                              child: Container(
                                padding: EdgeInsets.all(isDesktop ? 10 : 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: isDesktop ? 24 : (isTablet ? 22 : 20),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required FocusNode focusNode,
    required bool isTablet,
    required bool isDesktop,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
            letterSpacing: -0.2,
          ),
        ),
        SizedBox(height: isDesktop ? 12 : (isTablet ? 10 : 8)),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isDesktop ? 18 : 16),
            border: Border.all(
              color:
                  focusNode.hasFocus
                      ? const Color(0xFF6366F1)
                      : const Color(0xFFE2E8F0),
              width: focusNode.hasFocus ? 2 : 1.5,
            ),
            boxShadow:
                focusNode.hasFocus
                    ? [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ]
                    : null,
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: TextStyle(
              fontSize: isDesktop ? 18 : (isTablet ? 17 : 16),
              color: Colors.black,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: isDesktop ? 16 : 14,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 20 : 16,
                vertical:
                    maxLines > 1
                        ? isDesktop
                            ? 20
                            : (isTablet ? 18 : 16)
                        : isDesktop
                        ? 18
                        : (isTablet ? 16 : 14),
              ),
              prefixIcon: Container(
                width: isDesktop ? 56 : 48,
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color:
                      focusNode.hasFocus
                          ? const Color(0xFF6366F1)
                          : Colors.grey[600],
                  size: isDesktop ? 24 : (isTablet ? 22 : 20),
                ),
              ),
            ),
            onTap: () => setState(() {}),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label is required';
              }

              if (label == "Equipment Name" && value.trim().length < 3) {
                return "Enter a valid equipment name";
              }

              if (label == "Brand" && value.trim().length < 2) {
                return "Enter a valid brand name";
              }

              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector(bool isTablet, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: TextStyle(
            fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
            letterSpacing: -0.2,
          ),
        ),
        SizedBox(height: isDesktop ? 12 : (isTablet ? 10 : 8)),
        SizedBox(
          height: isDesktop ? 60 : (isTablet ? 55 : 50),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              final isSelected = _selectedCategory == category;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedCategory = category);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: EdgeInsets.only(
                    right: index == _categories.length - 1 ? 0 : 12,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 24 : (isTablet ? 22 : 20),
                    vertical: isDesktop ? 16 : (isTablet ? 14 : 12),
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? const Color(0xFF6366F1)
                            : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(isDesktop ? 14 : 12),
                    border: Border.all(
                      color:
                          isSelected
                              ? const Color(0xFF6366F1)
                              : const Color(0xFFE2E8F0),
                    ),
                    boxShadow:
                        isSelected
                            ? [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                            : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getCategoryIcon(category),
                        color: isSelected ? Colors.white : Colors.grey[600],
                        size: isDesktop ? 20 : (isTablet ? 18 : 16),
                      ),
                      SizedBox(width: isDesktop ? 12 : 8),
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPriceField(bool isTablet, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Rate',
          style: TextStyle(
            fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
            letterSpacing: -0.2,
          ),
        ),
        SizedBox(height: isDesktop ? 12 : (isTablet ? 10 : 8)),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(isDesktop ? 18 : 16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Padding(
                padding: EdgeInsets.only(left: isDesktop ? 20 : 16),
                child: Text(
                  '₹',
                  style: TextStyle(
                    fontSize: isDesktop ? 24 : (isTablet ? 22 : 20),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: _priceController,
                  focusNode: _priceFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly, // ✅ ONLY NUMBERS
                  ],
                  style: TextStyle(
                    fontSize: isDesktop ? 20 : (isTablet ? 19 : 18),
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontWeight: FontWeight.normal,
                      fontSize: isDesktop ? 18 : 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 16 : 12,
                      vertical: isDesktop ? 20 : (isTablet ? 18 : 16),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter price';
                    if (int.tryParse(value) == null) {
                      return 'Only numbers allowed';
                    }
                    if (int.parse(value) <= 0) {
                      return 'Price must be greater than 0';
                    }
                    return null;
                  },
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 20 : 16,
                  vertical: isDesktop ? 8 : 4,
                ),
                margin: EdgeInsets.only(right: isDesktop ? 16 : 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isDesktop ? 10 : 8),
                ),
                child: Text(
                  '/day',
                  style: TextStyle(
                    color: const Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                    fontSize: isDesktop ? 14 : (isTablet ? 13 : 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConditionSelector(bool isTablet, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Condition',
          style: TextStyle(
            fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
            letterSpacing: -0.2,
          ),
        ),
        SizedBox(height: isDesktop ? 12 : (isTablet ? 10 : 8)),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(isDesktop ? 18 : 16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _condition,
              isExpanded: true,
              icon: Padding(
                padding: EdgeInsets.only(right: isDesktop ? 20 : 16),
                child: Icon(
                  Icons.expand_more_rounded,
                  color: Colors.grey[600],
                  size: isDesktop ? 26 : (isTablet ? 24 : 20),
                ),
              ),
              items:
                  _conditions.map((condition) {
                    Color conditionColor;
                    switch (condition) {
                      case 'Brand New':
                        conditionColor = Colors.green;
                      case 'Excellent':
                        conditionColor = Colors.teal;
                      case 'Good':
                        conditionColor = Colors.orange;
                      case 'Fair':
                        conditionColor = Colors.orangeAccent;
                      default:
                        conditionColor = Colors.grey;
                    }

                    return DropdownMenuItem(
                      value: condition,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 20 : 16,
                          vertical: isDesktop ? 16 : (isTablet ? 14 : 12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: isDesktop ? 12 : (isTablet ? 11 : 10),
                              height: isDesktop ? 12 : (isTablet ? 11 : 10),
                              decoration: BoxDecoration(
                                color: conditionColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: isDesktop ? 16 : 12),
                            Expanded(
                              child: Text(
                                condition,
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontSize:
                                      isDesktop ? 16 : (isTablet ? 15 : 14),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _condition = value!);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvailabilitySelector(bool isTablet, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Availability Status',
          style: TextStyle(
            fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
            letterSpacing: -0.2,
          ),
        ),
        SizedBox(height: 8 * Scale),
        Row(
          children: [
            Expanded(
              child: _buildAvailabilityButton(
                label: 'Available',
                isSelected: _availability == 'Available',
                color: const Color(0xFF10B981),
                icon: Icons.check_circle_outline_rounded,
                isTablet: isTablet,
                isDesktop: isDesktop,
                onTap: () => setState(() => _availability = 'Available'),
              ),
            ),
            SizedBox(width: 8 * Scale),
            Expanded(
              child: _buildAvailabilityButton(
                label: 'Not Available',
                isSelected: _availability == 'Not Available',
                color: const Color(0xFFEF4444),
                icon: Icons.cancel_outlined,
                isTablet: isTablet,
                isDesktop: isDesktop,
                onTap: () => setState(() => _availability = 'Not Available'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvailabilityButton({
    required String label,
    required bool isSelected,
    required Color color,
    required IconData icon,
    required bool isTablet,
    required bool isDesktop,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: isDesktop ? 64 : (isTablet ? 60 : 56),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(isDesktop ? 18 : 16),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey[600],
              size: 16 * Scale,
            ),
            SizedBox(width: isDesktop ? 12 : 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 10 * Scale,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isTablet, bool isDesktop) {
    return Row(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 50 * Scale,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16 * Scale),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              gradient:
                  _isSaving
                      ? null
                      : LinearGradient(
                        colors: [
                          const Color(0xFF6366F1),
                          const Color(0xFF8B5CF6),
                        ],
                      ),
              boxShadow:
                  _isSaving
                      ? null
                      : [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16 * Scale),
              child: InkWell(
                borderRadius: BorderRadius.circular(16 * Scale),
                onTap: _isSaving ? null : _saveItem,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isSaving)
                      SizedBox(
                        width: 24 * Scale,
                        height: 24 * Scale,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(Colors.grey[600]),
                        ),
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle_outline_rounded,
                            color: Colors.white,
                            size: 14 * Scale,
                          ),
                          SizedBox(width: 8 * Scale),
                          Text(
                            'Add to Inventory',
                            style: TextStyle(
                              fontSize: 12 * Scale,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!_isSaving) ...[
          SizedBox(width: 10 * Scale),
          Container(
            width: 50 * Scale,
            height: 50 * Scale,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(isDesktop ? 18 : 16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(isDesktop ? 18 : 16),
              child: InkWell(
                borderRadius: BorderRadius.circular(isDesktop ? 18 : 16),
                onTap: _clearForm,
                child: Icon(
                  Icons.refresh_rounded,
                  color: const Color(0xFF64748B),
                  size: 20 * Scale,
                ),
              ),
            ),
          ),
        ],
      ],
    );
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
