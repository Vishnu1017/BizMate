// ignore_for_file: unused_local_variable

import 'dart:io';
import 'package:bizmate/services/image_compression_service.dart';
import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:bizmate/widgets/confirm_delete_dialog.dart'
    show showConfirmDialog;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'
    show FlutterSecureStorage, AndroidOptions;
import 'package:hive/hive.dart';
import 'package:hugeicons/hugeicons.dart' show HugeIcon, HugeIcons;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bizmate/models/user_model.dart';
import 'login_screen.dart';

class ProfilePage extends StatefulWidget {
  final User user;
  final Future<void> Function()? onRentalStatusChanged;

  const ProfilePage({
    super.key,
    required this.user,
    this.onRentalStatusChanged,
    required String userEmail,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  bool _isLoggingOut = false;
  late String name;
  late String role;
  late String email;
  late String phone;
  late String upiId;
  String location = 'India';
  File? _profileImage;
  final picker = ImagePicker();
  bool _isImageLoading = false;
  bool _isImageSaved = false;
  bool _isEditing = false;
  bool _isRentalEnabled = false;
  bool _isPasscodeEnabled = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  double scale = 1.0;

  final List<String> roles = [
    'None',
    'Photographer',
    'Sales Representative',
    'Account Manager',
    'Business Development',
    'Sales Manager',
    'Marketing Specialist',
    'Retail Associate',
    'Sales Executive',
    'Entrepreneur',
  ];

  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _upiController = TextEditingController();
  final _locationController = TextEditingController();

  final FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: const AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verifySession();
      _animationController.forward();
    });

    final box = Hive.box<User>('users');
    final user = box.values.firstWhere(
      (u) => u.email == widget.user.email,
      orElse: () => widget.user,
    );

    name = user.name;
    email = user.email;
    phone = user.phone;
    role = user.role;
    upiId = user.upiId;
    location =
        user.location?.trim().isNotEmpty == true
            ? user.location!.trim()
            : 'India';

    _nameController.text = name;
    _roleController.text = role;
    _emailController.text = email;
    _phoneController.text = phone;
    _upiController.text = upiId;
    _locationController.text = location;

    _loadImage();
    _loadRentalSetting();
    _loadPasscodeSetting();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _roleController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _upiController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _verifySession() async {
    try {
      final sessionBox = await Hive.openBox('session');
      if (sessionBox.isEmpty && mounted) {
        debugPrint('Session expired');
        await _logout();
      }
    } catch (e) {
      debugPrint('Session verification error: $e');
      if (mounted) {
        AppSnackBar.showError(
          context,
          message: 'Session error. Please login again.',
          duration: Duration(seconds: 2),
        );
        await _logout();
      }
    }
  }

  Future<void> _loadImage() async {
    setState(() => _isImageLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('${widget.user.email}_profileImagePath');

    if (path != null && path.isNotEmpty) {
      final file = File(path);
      try {
        final exists = await file.exists();
        if (exists) {
          setState(() {
            _profileImage = file;
            _isImageSaved = true;
          });
        } else {
          await prefs.remove('${widget.user.email}_profileImagePath');
          setState(() {
            _profileImage = null;
            _isImageSaved = false;
          });
        }
      } catch (e) {
        debugPrint('Error loading image: $e');
        setState(() {
          _profileImage = null;
          _isImageSaved = false;
        });
      }
    } else {
      setState(() {
        _profileImage = null;
        _isImageSaved = false;
      });
    }

    setState(() => _isImageLoading = false);
  }

  Future<void> _loadRentalSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isRentalEnabled =
          prefs.getBool('${widget.user.email}_rentalEnabled') ?? false;
    });
  }

  Future<void> _loadPasscodeSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final toggleValue =
        prefs.getBool('${widget.user.email}_passcodeEnabled') ?? false;
    final savedPasscode = await _secureStorage.read(
      key: "passcode_${widget.user.email}",
    );
    setState(() {
      _isPasscodeEnabled =
          toggleValue && savedPasscode != null && savedPasscode.isNotEmpty;
    });
  }

  Future<void> _enableRental() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${widget.user.email}_rentalEnabled', true);
    if (widget.onRentalStatusChanged != null) {
      await widget.onRentalStatusChanged!();
    }

    setState(() {
      _isRentalEnabled = true;
    });

    widget.onRentalStatusChanged?.call();

    if (mounted) {
      AppSnackBar.showSuccess(
        context,
        message: 'Rental page enabled successfully!',
        duration: Duration(seconds: 2),
      );
    }
  }

  Future<void> _disableRental() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${widget.user.email}_rentalEnabled', false);
    setState(() {
      _isRentalEnabled = false;
    });

    widget.onRentalStatusChanged?.call();

    if (mounted) {
      AppSnackBar.showWarning(
        context,
        message: 'Rental page disabled',
        duration: Duration(seconds: 2),
      );
    }
  }

  Future<bool> _setupPasscode() async {
    // 1️⃣ Ask for passcode type
    final passcodeType = await _showPasscodeTypeDialog();

    // ✅ User cancelled → return false
    if (passcodeType == null) {
      return false;
    }

    int maxLength;
    TextInputType keyboardType;
    String hintText;
    String title;

    if (passcodeType == "pin4") {
      maxLength = 4;
      keyboardType = TextInputType.number;
      hintText = "Enter your new 4-digit PIN";
      title = "Setup 4-Digit PIN";
    } else if (passcodeType == "pin6") {
      maxLength = 6;
      keyboardType = TextInputType.number;
      hintText = "Enter your new 6-digit PIN";
      title = "Setup 6-Digit PIN";
    } else {
      maxLength = 18;
      keyboardType = TextInputType.text;
      hintText = "Enter your new alphanumeric passcode";
      title = "Setup Passcode";
    }

    // 2️⃣ First passcode entry
    final newPasscode = await _showPasscodeDialog(
      title,
      hintText,
      maxLength,
      keyboardType,
      passcodeType,
    );

    if (newPasscode == null) {
      return false; // cancelled
    }

    if (newPasscode.length != maxLength) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          message:
              'Passcode must be $maxLength ${passcodeType == "alphanumeric" ? "characters" : "digits"}!',
          duration: const Duration(seconds: 2),
        );
      }
      return false;
    }

    // 3️⃣ Confirm passcode
    final confirmPasscode = await _showPasscodeDialog(
      "Confirm Passcode",
      "Re-enter your ${passcodeType == "alphanumeric" ? "alphanumeric" : "$maxLength-digit"} passcode",
      maxLength,
      keyboardType,
      passcodeType,
    );

    if (confirmPasscode == null) {
      return false; // cancelled
    }

    // 4️⃣ Match check
    if (confirmPasscode != newPasscode) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          message: 'Passcodes do not match!',
          duration: const Duration(seconds: 2),
        );
      }
      return false;
    }

    // ✅ 5️⃣ Save passcode
    await _secureStorage.write(
      key: "passcode_${widget.user.email}",
      value: newPasscode,
    );

    await _secureStorage.write(
      key: "passcode_type_${widget.user.email}",
      value: passcodeType,
    );

    if (mounted) {
      setState(() {
        _isPasscodeEnabled = true;
      });

      AppSnackBar.showSuccess(
        context,
        message:
            '${passcodeType == "pin4"
                ? "4-digit"
                : passcodeType == "pin6"
                ? "6-digit"
                : "Alphanumeric"} passcode setup successfully!',
        duration: const Duration(seconds: 2),
      );
    }

    // ✅ SUCCESS
    return true;
  }

  Future<String?> _showPasscodeTypeDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) {
        // Calculate responsive dimensions
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isSmallScreen = screenWidth < 360;
        final isVerySmallScreen = screenWidth < 320;
        final isLargeScreen = screenWidth > 600;

        // Responsive padding
        final horizontalPadding = isSmallScreen ? 16.0 : 20.0;
        final verticalPadding = isSmallScreen ? 16.0 : 20.0;
        final dialogPadding = EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        );

        // Responsive font sizes
        final titleFontSize = isSmallScreen ? 22.0 : 26.0;
        final optionTitleFontSize = isSmallScreen ? 15.0 : 17.0;
        final descriptionFontSize = isSmallScreen ? 12.0 : 13.0;
        final levelFontSize = isSmallScreen ? 10.0 : 11.0;

        // Responsive icon sizes
        final headerIconSize = isSmallScreen ? 24.0 : 28.0;
        final optionIconSize = isSmallScreen ? 20.0 : 24.0;

        // Responsive spacing
        final optionSpacing = isSmallScreen ? 8.0 : 12.0;
        final iconContainerSize = isSmallScreen ? 44.0 : 52.0;

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.all(isSmallScreen ? 12.0 : 20.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isLargeScreen ? 500 : screenWidth * 0.9,
              maxHeight: screenHeight * 0.85,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    isSmallScreen ? 24.0 : 28.0,
                  ),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 50,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 20.0 : 24.0,
                        horizontal: isSmallScreen ? 20.0 : 24.0,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(isSmallScreen ? 24.0 : 28.0),
                          topRight: Radius.circular(
                            isSmallScreen ? 24.0 : 28.0,
                          ),
                        ),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: isSmallScreen ? 48.0 : 56.0,
                            height: isSmallScreen ? 48.0 : 56.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.2),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.shield_rounded,
                              color: Colors.white,
                              size: headerIconSize,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                          Text(
                            "Security Level",
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 6.0 : 8.0),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 8.0 : 0,
                            ),
                            child: Text(
                              "Choose your preferred authentication method",
                              style: TextStyle(
                                fontSize: isSmallScreen ? 13.0 : 14.0,
                                color: Colors.white.withOpacity(0.9),
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Options
                    Padding(
                      padding: dialogPadding,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSecurityOption(
                            icon: Icons.looks_4_rounded,
                            title: "4-Digit PIN",
                            description: "Basic security • Quick access",
                            level: "Low",
                            color: const Color(0xFF3B82F6),
                            value: "pin4",
                            isRecommended: false,
                            fontSize: optionTitleFontSize,
                            descriptionSize: descriptionFontSize,
                            levelSize: levelFontSize,
                            iconSize: optionIconSize,
                            iconContainerSize: iconContainerSize,
                          ),

                          SizedBox(height: optionSpacing),

                          _buildSecurityOption(
                            icon: Icons.looks_6_rounded,
                            title: "6-Digit PIN",
                            description: "Enhanced security • Recommended",
                            level: "Medium",
                            color: const Color(0xFF10B981),
                            value: "pin6",
                            isRecommended: true,
                            fontSize: optionTitleFontSize,
                            descriptionSize: descriptionFontSize,
                            levelSize: levelFontSize,
                            iconSize: optionIconSize,
                            iconContainerSize: iconContainerSize,
                          ),

                          SizedBox(height: optionSpacing),

                          _buildSecurityOption(
                            icon: Icons.password_rounded,
                            title: "Alphanumeric",
                            description: "Maximum security • Letters & numbers",
                            level: "High",
                            color: const Color(0xFF8B5CF6),
                            value: "alphanumeric",
                            isRecommended: false,
                            fontSize: optionTitleFontSize,
                            descriptionSize: descriptionFontSize,
                            levelSize: levelFontSize,
                            iconSize: optionIconSize,
                            iconContainerSize: iconContainerSize,
                          ),
                        ],
                      ),
                    ),

                    // Cancel Button
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        0,
                        horizontalPadding,
                        verticalPadding,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: isSmallScreen ? 14.0 : 16.0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                isSmallScreen ? 12.0 : 14.0,
                              ),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              fontSize: isSmallScreen ? 15.0 : 16.0,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
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
      },
    );
  }

  Widget _buildSecurityOption({
    required IconData icon,
    required String title,
    required String description,
    required String level,
    required Color color,
    required String value,
    required bool isRecommended,
    required double fontSize,
    required double descriptionSize,
    required double levelSize,
    required double iconSize,
    required double iconContainerSize,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => Navigator.pop(context, value),
        borderRadius: BorderRadius.circular(18),
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white,
            border: Border.all(
              color:
                  isRecommended
                      ? color.withOpacity(0.3)
                      : const Color(0xFFF1F5F9),
              width: isRecommended ? 2 : 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.03),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: iconContainerSize,
                height: iconContainerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                  ),
                ),
                child: Center(child: Icon(icon, color: color, size: iconSize)),
              ),

              SizedBox(width: 12),

              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isRecommended) ...[
                          SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: color.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                "Recommended",
                                style: TextStyle(
                                  fontSize: levelSize - 1,
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: descriptionSize,
                        color: const Color(0xFF64748B),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            level,
                            style: TextStyle(
                              fontSize: levelSize,
                              color: const Color(0xFF475569),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.chevron_right_rounded,
                color: const Color(0xFF94A3B8),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _showPasscodeDialog(
    String title,
    String hint,
    int maxLength,
    TextInputType keyboardType,
    String passcodeType,
  ) async {
    final TextEditingController passcodeController = TextEditingController();
    bool isObscured = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Responsive helpers
            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;
            final isSmallScreen = screenWidth < 360;
            final isLargeScreen = screenWidth > 600;

            final dialogBorderRadius = isSmallScreen ? 24.0 : 28.0;
            final contentPadding = isSmallScreen ? 16.0 : 24.0;
            final buttonPadding = isSmallScreen ? 16.0 : 20.0;
            final inputFontSize = _getFontSizeForPasscodeType(
              passcodeType,
              isSmallScreen: isSmallScreen,
            );
            final buttonFontSize = isSmallScreen ? 15.0 : 16.0;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.all(isSmallScreen ? 12 : 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isLargeScreen ? 500 : screenWidth * 0.9,
                  maxHeight: screenHeight * 0.85,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(dialogBorderRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 50,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // HEADER
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isSmallScreen ? 20.0 : 24.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(dialogBorderRadius),
                            ),
                            gradient: _getPasscodeTypeGradient(passcodeType),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.lock_rounded,
                                color: Colors.white,
                                size: isSmallScreen ? 30 : 36,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 20 : 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                hint,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 13 : 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // BODY
                        Padding(
                          padding: EdgeInsets.all(contentPadding),
                          child: Column(
                            children: [
                              _buildPasscodeVisualIndicator(
                                passcodeController.text,
                                maxLength,
                                passcodeType,
                                false,
                                isSmallScreen: isSmallScreen,
                              ),

                              SizedBox(height: isSmallScreen ? 24 : 32),

                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 12 : 16,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(
                                    isSmallScreen ? 14 : 16,
                                  ),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: passcodeController,
                                        keyboardType: keyboardType,
                                        maxLength: maxLength,
                                        obscureText: isObscured,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: inputFontSize,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1E293B),
                                          letterSpacing:
                                              _getLetterSpacingForPasscodeType(
                                                passcodeType,
                                                isSmallScreen: isSmallScreen,
                                              ),
                                          fontFamily:
                                              passcodeType == "alphanumeric"
                                                  ? 'monospace'
                                                  : null,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: _getHintTextForPasscodeType(
                                            passcodeType,
                                            isSmallScreen: isSmallScreen,
                                          ),
                                          hintStyle: TextStyle(
                                            color: const Color(0xFF94A3B8),
                                            letterSpacing:
                                                _getLetterSpacingForPasscodeType(
                                                  passcodeType,
                                                  isSmallScreen: isSmallScreen,
                                                ),
                                            fontFamily:
                                                passcodeType == "alphanumeric"
                                                    ? 'monospace'
                                                    : null,
                                          ),
                                          counterText: '',
                                          border: InputBorder.none,
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),

                                    if (passcodeType == "alphanumeric")
                                      IconButton(
                                        icon: Icon(
                                          isObscured
                                              ? Icons.visibility_off_rounded
                                              : Icons.visibility_rounded,
                                          color: const Color(0xFF64748B),
                                        ),
                                        onPressed:
                                            () => setState(
                                              () => isObscured = !isObscured,
                                            ),
                                      ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              _buildPasscodeRequirements(
                                passcodeType,
                                passcodeController.text,
                                isSmallScreen: isSmallScreen,
                              ),
                            ],
                          ),
                        ),

                        // ACTION BUTTONS
                        // MODERN ACTION BUTTONS SECTION
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            buttonPadding,
                            0,
                            buttonPadding,
                            buttonPadding,
                          ),
                          child: Column(
                            children: [
                              // Progress indicator
                              Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(1),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor:
                                      passcodeController.text.length /
                                      maxLength,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Theme.of(context).colorScheme.primary,
                                          Theme.of(context).colorScheme.primary
                                              .withOpacity(0.7),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              Row(
                                children: [
                                  // CANCEL BUTTON - Modern Design
                                  Expanded(
                                    child: Material(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        onTap: () => Navigator.pop(context),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          height: 54,
                                          decoration: BoxDecoration(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey[300]!,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              // Background effect
                                              Positioned.fill(
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin:
                                                            Alignment.topLeft,
                                                        end:
                                                            Alignment
                                                                .bottomRight,
                                                        colors: [
                                                          Colors.white
                                                              .withOpacity(0.1),
                                                          Colors.transparent,
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // Content
                                              Center(
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Container(
                                                      width: 24,
                                                      height: 24,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color:
                                                              Colors.grey[600]!,
                                                          width: 1.5,
                                                        ),
                                                      ),
                                                      child: Center(
                                                        child: Container(
                                                          width: 8,
                                                          height: 8,
                                                          decoration: BoxDecoration(
                                                            shape:
                                                                BoxShape.circle,
                                                            color:
                                                                Colors
                                                                    .grey[600]!,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      "Cancel",
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            Colors.grey[800]!,
                                                        letterSpacing: -0.2,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 16),

                                  // CONTINUE BUTTON - Modern Design
                                  Expanded(
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      height: 54,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        gradient:
                                            passcodeController.text.length ==
                                                    maxLength
                                                ? LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                        .withGreen(50),
                                                  ],
                                                )
                                                : LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Colors.grey[200]!,
                                                    Colors.grey[300]!,
                                                  ],
                                                ),
                                        boxShadow:
                                            passcodeController.text.length ==
                                                    maxLength
                                                ? [
                                                  BoxShadow(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                        .withOpacity(0.4),
                                                    blurRadius: 15,
                                                    spreadRadius: 0,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ]
                                                : [
                                                  BoxShadow(
                                                    color: Colors.grey
                                                        .withOpacity(0.1),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        child: InkWell(
                                          onTap:
                                              passcodeController.text.length ==
                                                      maxLength
                                                  ? () => Navigator.pop(
                                                    context,
                                                    passcodeController.text,
                                                  )
                                                  : null,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Stack(
                                            children: [
                                              // Inner highlight effect
                                              Positioned.fill(
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      gradient:
                                                          passcodeController
                                                                      .text
                                                                      .length ==
                                                                  maxLength
                                                              ? LinearGradient(
                                                                begin:
                                                                    Alignment
                                                                        .topCenter,
                                                                end:
                                                                    Alignment
                                                                        .bottomCenter,
                                                                colors: [
                                                                  Colors.white
                                                                      .withOpacity(
                                                                        0.2,
                                                                      ),
                                                                  Colors
                                                                      .transparent,
                                                                ],
                                                              )
                                                              : null,
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // Content
                                              Center(
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      "Continue",
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            passcodeController
                                                                        .text
                                                                        .length ==
                                                                    maxLength
                                                                ? Colors.white
                                                                : Colors
                                                                    .grey[400]!,
                                                        letterSpacing: -0.2,
                                                        shadows:
                                                            passcodeController
                                                                        .text
                                                                        .length ==
                                                                    maxLength
                                                                ? [
                                                                  Shadow(
                                                                    color: Colors
                                                                        .black
                                                                        .withOpacity(
                                                                          0.1,
                                                                        ),
                                                                    blurRadius:
                                                                        2,
                                                                    offset:
                                                                        const Offset(
                                                                          0,
                                                                          1,
                                                                        ),
                                                                  ),
                                                                ]
                                                                : null,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    AnimatedContainer(
                                                      duration: const Duration(
                                                        milliseconds: 400,
                                                      ),
                                                      curve: Curves.elasticOut,
                                                      transform:
                                                          Matrix4.translationValues(
                                                            passcodeController
                                                                        .text
                                                                        .length ==
                                                                    maxLength
                                                                ? 0
                                                                : -10,
                                                            0,
                                                            0,
                                                          ),
                                                      child: Icon(
                                                        Icons
                                                            .arrow_forward_rounded,
                                                        size: 20,
                                                        color:
                                                            passcodeController
                                                                        .text
                                                                        .length ==
                                                                    maxLength
                                                                ? Colors.white
                                                                : Colors
                                                                    .grey[400]!,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
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
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPasscodeVisualIndicator(
    String text,
    int maxLength,
    String passcodeType,
    bool isConfirmMode, {
    bool isSmallScreen = false,
  }) {
    final dotSize = isSmallScreen ? 14.0 : 18.0;
    final fontSize = isSmallScreen ? 16.0 : 18.0;
    final statusFontSize = isSmallScreen ? 11.0 : 12.0;

    return Column(
      children: [
        // Dots or letters indicator
        if (passcodeType == "pin4" || passcodeType == "pin6")
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(maxLength, (index) {
              final filled = index < text.length;
              return Container(
                margin: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 6.0 : 8.0,
                ),
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      filled
                          ? _getPrimaryColorForPasscodeType(passcodeType)
                          : const Color(0xFFE2E8F0),
                  boxShadow:
                      filled
                          ? [
                            BoxShadow(
                              color: _getPrimaryColorForPasscodeType(
                                passcodeType,
                              ).withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                          : null,
                ),
              );
            }),
          ),

        if (passcodeType == "alphanumeric")
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12.0 : 16.0,
              vertical: isSmallScreen ? 10.0 : 12.0,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              text.isEmpty ? "Enter your passcode" : "•" * text.length,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color:
                    text.isEmpty
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF1E293B),
                fontFamily: 'monospace',
                letterSpacing: isSmallScreen ? 3.0 : 4.0,
              ),
            ),
          ),

        SizedBox(height: isSmallScreen ? 6.0 : 8.0),

        // Status text
        if (text.isNotEmpty)
          Text(
            "${text.length} character${text.length != 1 ? 's' : ''} entered",
            style: TextStyle(
              fontSize: statusFontSize,
              color: _getPrimaryColorForPasscodeType(passcodeType),
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  Widget _buildPasscodeRequirements(
    String passcodeType,
    String currentText, {
    bool isSmallScreen = false,
  }) {
    List<Map<String, dynamic>> requirements = [];

    if (passcodeType == "alphanumeric") {
      requirements = [
        {"text": "At least 8 characters", "met": currentText.length >= 8},
        {
          "text": "Contains letters",
          "met": RegExp(r'[a-zA-Z]').hasMatch(currentText),
        },
        {
          "text": "Contains numbers",
          "met": RegExp(r'[0-9]').hasMatch(currentText),
        },
      ];
    } else if (passcodeType == "pin6") {
      requirements = [
        {"text": "6 digits required", "met": currentText.length == 6},
        {
          "text": "No repeating patterns",
          "met": !_hasRepeatingPattern(currentText),
        },
      ];
    } else {
      return const SizedBox(); // No requirements for 4-digit PIN
    }

    final requirementsFontSize = isSmallScreen ? 11.0 : 12.0;
    final iconSize = isSmallScreen ? 12.0 : 14.0;

    return Container(
      margin: EdgeInsets.only(top: isSmallScreen ? 8.0 : 12.0),
      padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Requirements:",
            style: TextStyle(
              fontSize: requirementsFontSize,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF475569),
            ),
          ),
          SizedBox(height: isSmallScreen ? 6.0 : 8.0),
          ...requirements
              .map(
                (req) => Padding(
                  padding: EdgeInsets.only(bottom: isSmallScreen ? 4.0 : 6.0),
                  child: Row(
                    children: [
                      Icon(
                        req["met"]
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: iconSize,
                        color:
                            req["met"]
                                ? const Color(0xFF10B981)
                                : const Color(0xFF94A3B8),
                      ),
                      SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                      Expanded(
                        child: Text(
                          req["text"],
                          style: TextStyle(
                            fontSize: requirementsFontSize,
                            color:
                                req["met"]
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  // Add these new responsive helper functions

  double _getFontSizeForPasscodeType(
    String passcodeType, {
    bool isSmallScreen = false,
  }) {
    if (passcodeType == "alphanumeric") {
      return isSmallScreen ? 16.0 : 18.0;
    } else if (passcodeType == "pin6") {
      return isSmallScreen ? 22.0 : 24.0;
    } else {
      return isSmallScreen ? 24.0 : 26.0; // pin4
    }
  }

  String _getHintTextForPasscodeType(
    String passcodeType, {
    bool isSmallScreen = false,
  }) {
    if (passcodeType == "alphanumeric") {
      return isSmallScreen ? "Enter passcode" : "Enter your passcode";
    } else if (passcodeType == "pin6") {
      return isSmallScreen ? "6 digits" : "6-digit PIN";
    } else {
      return isSmallScreen ? "4 digits" : "4-digit PIN";
    }
  }

  double _getLetterSpacingForPasscodeType(
    String passcodeType, {
    bool isSmallScreen = false,
  }) {
    if (passcodeType == "alphanumeric") {
      return isSmallScreen ? 1.0 : 1.5;
    } else if (passcodeType == "pin6") {
      return isSmallScreen ? 4.0 : 6.0;
    } else {
      return isSmallScreen ? 6.0 : 8.0; // pin4
    }
  }

  // Existing helper functions (keep these exactly as they were)

  LinearGradient _getPasscodeTypeGradient(String passcodeType) {
    if (passcodeType == "pin4") {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
      );
    } else if (passcodeType == "pin6") {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF10B981), Color(0xFF34D399)],
      );
    } else {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
      );
    }
  }

  Color _getPrimaryColorForPasscodeType(String passcodeType) {
    if (passcodeType == "pin4") {
      return const Color(0xFF3B82F6);
    } else if (passcodeType == "pin6") {
      return const Color(0xFF10B981);
    } else {
      return const Color(0xFF8B5CF6);
    }
  }

  bool _hasRepeatingPattern(String text) {
    if (text.length < 2) return false;

    // Check for repeating digits
    for (int i = 1; i < text.length; i++) {
      if (text[i] != text[0]) return false;
    }

    // Check for sequential patterns (123456, 654321)
    bool isSequentialIncreasing = true;
    bool isSequentialDecreasing = true;
    for (int i = 1; i < text.length; i++) {
      if (int.parse(text[i]) != int.parse(text[i - 1]) + 1) {
        isSequentialIncreasing = false;
      }
      if (int.parse(text[i]) != int.parse(text[i - 1]) - 1) {
        isSequentialDecreasing = false;
      }
    }

    return isSequentialIncreasing || isSequentialDecreasing;
  }

  Future<void> _pickImage() async {
    try {
      final status = await Permission.photos.request();

      if (!status.isGranted) {
        if (!mounted) return;
        AppSnackBar.showError(
          context,
          message: 'Permission denied. Please allow access to gallery.',
          duration: Duration(seconds: 2),
        );
        return;
      }

      setState(() => _isImageLoading = true);

      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
      );

      if (picked == null) {
        setState(() => _isImageLoading = false);
        return;
      }

      final originalFile = File(picked.path);

      final compressedFile = await ImageCompressionService.compressProfileImage(
        originalFile: originalFile,
      );

      final file = compressedFile ?? originalFile;
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('${widget.user.email}_profileImagePath', file.path);

      if (!mounted) return;
      setState(() {
        _profileImage = file;
        _isImageLoading = false;
        _isImageSaved = true;
      });

      AppSnackBar.showSuccess(
        context,
        message: 'Profile image updated successfully!',
        duration: Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint('Image picking error: $e');
      setState(() => _isImageLoading = false);
      if (!mounted) return;
      AppSnackBar.showError(
        context,
        message: 'Error picking image: ${e.toString()}',
        duration: Duration(seconds: 2),
      );
    }
  }

  void _toggleEditing() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        _nameController.text = name;
        _roleController.text = role;
        _emailController.text = email;
        _phoneController.text = phone;
        _upiController.text = upiId;
        _locationController.text = location;
      }
    });
  }

  Future<void> _saveProfile() async {
    try {
      final box = Hive.box<User>('users');
      final userKey = box.keys.firstWhere(
        (key) => box.get(key)?.email == widget.user.email,
        orElse: () => null,
      );

      if (userKey != null) {
        final existingUser = box.get(userKey)!;

        existingUser.name = _nameController.text.trim();
        existingUser.email = _emailController.text.trim();
        existingUser.phone = _phoneController.text.trim();
        existingUser.role = _roleController.text.trim();
        existingUser.upiId = _upiController.text.trim();
        existingUser.location = _locationController.text.trim();

        await existingUser.save();

        setState(() {
          name = existingUser.name;
          role = existingUser.role;
          email = existingUser.email;
          phone = existingUser.phone;
          upiId = existingUser.upiId;
          location =
              existingUser.location?.trim().isNotEmpty == true
                  ? existingUser.location!.trim()
                  : 'India';
          _isEditing = false;
        });

        AppSnackBar.showSuccess(
          context,
          message: 'Profile updated successfully!',
          duration: Duration(seconds: 2),
        );
      }
    } catch (e) {
      debugPrint('Save profile error: $e');
      AppSnackBar.showError(
        context,
        message: 'Error saving profile. Please try again.',
        duration: Duration(seconds: 2),
      );
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);

    try {
      final sessionBox = await Hive.openBox('session');
      await sessionBox.clear();
      await sessionBox.close();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Logout error: $e');
      if (!mounted) return;
      AppSnackBar.showError(
        context,
        message: 'Logout failed. Please try again.',
        duration: Duration(seconds: 2),
      );
    } finally {
      setState(() => _isLoggingOut = false);
    }
  }

  Future<void> deleteCurrentUser(String email) async {
    try {
      print("Deleting account for: $email");

      final userBox = Hive.box<User>('users');
      dynamic userKey;

      for (var key in userBox.keys) {
        final u = userBox.get(key);
        if (u != null && u.email.trim() == email.trim()) {
          userKey = key;
          break;
        }
      }

      if (userKey != null) {
        await userBox.delete(userKey);
        print("User deleted from Hive");
      } else {
        print("User not found in Hive");
      }

      final storage = FlutterSecureStorage(
        aOptions: const AndroidOptions(encryptedSharedPreferences: true),
      );

      await storage.delete(key: "passcode_$email");
      await storage.delete(key: "passcode_type_$email");

      print("Passcode + Type deleted");

      final prefs = await SharedPreferences.getInstance();
      final imgPath = prefs.getString('${email}_profileImagePath');

      if (imgPath != null) {
        final file = File(imgPath);
        if (await file.exists()) {
          await file.delete();
          print("Profile image deleted");
        }
      }

      await prefs.remove('${email}_profileImagePath');
      await prefs.remove('${email}_rentalEnabled');

      print("SharedPrefs cleared");

      if (Hive.isBoxOpen('session')) {
        await Hive.box('session').clear();
      } else {
        final sessionBox = await Hive.openBox('session');
        await sessionBox.clear();
      }

      print("Session cleared");

      if (!mounted) return;

      AppSnackBar.showSuccess(
        context,
        message: "Account deleted successfully!",
        duration: Duration(seconds: 2),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      print("Delete error: $e");

      if (!mounted) return;

      AppSnackBar.showError(
        context,
        message: "Error deleting account",
        duration: Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            height: screenHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
              ),
            ),
            child: Stack(
              children: [
                // Background decorative elements
                Positioned(
                  top: -50,
                  right: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0xFF3B82F6).withOpacity(0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  left: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0xFF10B981).withOpacity(0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Main content with animation
                Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true, // ✅ removes status bar gap
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 16 : 32,
                            vertical: 16, // ✅ reduced from 60
                          ),
                          child: Column(
                            children: [
                              // Profile Header Card
                              _buildProfileHeader(isSmallScreen),
                              SizedBox(height: 30),

                              // Personal Info Section
                              _buildPersonalInfoSection(isSmallScreen),

                              // Security Section (for all users)
                              if (!_isEditing) ...[
                                SizedBox(height: 24),
                                _buildSecuritySection(isSmallScreen),
                              ],

                              // Rental Section (for photographers only)
                              if (role == 'Photographer' && !_isEditing) ...[
                                SizedBox(height: 24),
                                _buildRentalSection(isSmallScreen),
                              ],

                              // Action Buttons
                              if (!_isEditing) ...[
                                SizedBox(height: 30),
                                _buildActionButtons(isSmallScreen),
                                SizedBox(height: 20),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 30,
            spreadRadius: 5,
            offset: Offset(0, 10),
          ),
        ],
        border: Border.all(color: Color(0xFFF1F5F9), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12 * scale,
                    vertical: 6 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'PROFILE',
                    style: TextStyle(
                      fontSize: 10 * scale,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: Color(0xFF64748B),
                    size: 20 * scale,
                  ),
                  color: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Color(0xFFF1F5F9)),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _toggleEditing();
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6 * scale),
                              decoration: BoxDecoration(
                                color: Color(0xFF3B82F6).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.edit,
                                color: Color(0xFF3B82F6),
                                size: 12 * scale,
                              ),
                            ),
                            SizedBox(width: 10 * scale),
                            Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontSize: 12 * scale,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),

            SizedBox(height: 12 * scale),

            // Profile Image
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 110 * scale,
                  height: 110 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF3B82F6).withOpacity(0.1),
                        Color(0xFF10B981).withOpacity(0.1),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 90 * scale,
                        height: 90 * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 4 * scale,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child:
                              _isImageLoading
                                  ? Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF3B82F6),
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : _profileImage != null && _isImageSaved
                                  ? Image.file(
                                    _profileImage!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0xFF3B82F6),
                                              Color(0xFF1D4ED8),
                                            ],
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : 'U',
                                            style: TextStyle(
                                              fontSize: 32 * scale,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                  : Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF3B82F6),
                                          Color(0xFF1D4ED8),
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : 'U',
                                        style: TextStyle(
                                          fontSize: 32 * scale,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(6 * scale),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF3B82F6),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF3B82F6).withOpacity(0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedCameraAdd01,
                            size: 16 * scale,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Name
            _isEditing
                ? TextField(
                  controller: _nameController,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 24 : 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                )
                : Text(
                  name,
                  style: TextStyle(
                    fontSize: 22 * scale,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),

            SizedBox(height: 10),

            // Role - FIXED: Using Icon instead of HugeIcon to avoid the List issue
            _isEditing
                ? _buildRoleDropdown()
                : Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Using Material Icon instead of HugeIcon to fix the List issue
                      Icon(
                        Icons.work_rounded,
                        size: 16 * scale,
                        color: Color(0xFF3B82F6),
                      ),
                      SizedBox(width: 8),
                      Text(
                        role,
                        style: TextStyle(
                          fontSize: 12 * scale,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),

            if (_isEditing) ...[
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFFE2E8F0)),
                      ),
                      child: TextButton(
                        onPressed: _toggleEditing,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF3B82F6).withOpacity(0.3),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: TextButton(
                        onPressed: _saveProfile,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: role,
          dropdownColor: Colors.white,
          icon: Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
          ),
          onChanged: (String? newValue) async {
            if (newValue == null) return;
            setState(() {
              role = newValue;
              _roleController.text = newValue;
            });

            final prefs = await SharedPreferences.getInstance();
            if (newValue == 'Photographer') {
              await prefs.setBool('${widget.user.email}_rentalEnabled', true);
              setState(() => _isRentalEnabled = true);
              widget.onRentalStatusChanged?.call();
            } else {
              await prefs.setBool('${widget.user.email}_rentalEnabled', false);
              setState(() => _isRentalEnabled = false);
              widget.onRentalStatusChanged?.call();
            }
          },
          items:
              roles.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: TextStyle(color: Color(0xFF1E293B)),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection(bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 2,
            offset: Offset(0, 5),
          ),
        ],
        border: Border.all(color: Color(0xFFF1F5F9), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInfoRow(
              Icons.email_rounded,
              'Email',
              _emailController,
              email,
              isSmallScreen,
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              Icons.phone_rounded,
              'Phone',
              _phoneController,
              phone,
              isSmallScreen,
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              Icons.qr_code_2_rounded,
              'UPI ID',
              _upiController,
              upiId.isEmpty ? 'Not Set' : upiId,
              isSmallScreen,
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              Icons.location_city_rounded,
              'Location',
              _locationController,
              location.isNotEmpty ? location : 'India',
              isSmallScreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    TextEditingController controller,
    String value,
    bool isSmallScreen,
  ) {
    return _isEditing
        ? Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: controller,
            style: TextStyle(fontSize: 16, color: Color(0xFF1E293B)),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Color(0xFF64748B)),
              hintText: value.isEmpty ? 'Enter $label' : value,
              hintStyle: TextStyle(color: Color(0xFF94A3B8)),
              border: InputBorder.none,
            ),
          ),
        )
        : Container(
          padding: EdgeInsets.all(12 * scale),
          decoration: BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Color(0xFF64748B), size: 16 * scale),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10 * scale,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      value.isNotEmpty
                          ? (label == "Phone" ? "+91 $value" : value)
                          : "No $label",
                      style: TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
  }

  Widget _buildSecuritySection(bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 30,
            spreadRadius: 5,
            offset: Offset(0, 10),
          ),
        ],
        border: Border.all(color: Color(0xFFF1F5F9), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(16 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6 * scale,
                      height: 6 * scale,
                      margin: EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                        ),
                      ),
                    ),
                    Text(
                      'SECURITY',
                      style: TextStyle(
                        fontSize: 10 * scale,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8 * scale,
                    vertical: 5 * scale,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _isPasscodeEnabled
                            ? Color(0xFF10B981).withOpacity(0.1)
                            : Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          _isPasscodeEnabled
                              ? Color(0xFF10B981).withOpacity(0.3)
                              : Color(0xFFEF4444).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4 * scale,
                        height: 4 * scale,
                        margin: EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              _isPasscodeEnabled
                                  ? Color(0xFF10B981)
                                  : Color(0xFFEF4444),
                        ),
                      ),
                      Text(
                        _isPasscodeEnabled ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          fontSize: 8 * scale,
                          fontWeight: FontWeight.bold,
                          color:
                              _isPasscodeEnabled
                                  ? Color(0xFF065F46)
                                  : Color(0xFF991B1B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            Text(
              'App Passcode',
              style: TextStyle(
                fontSize: 16 * scale,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                letterSpacing: 0.5,
              ),
            ),

            SizedBox(height: 8),

            Text(
              'Secure your app with a 4-digit passcode',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 10 * scale),
            ),

            SizedBox(height: 24),

            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12 * scale,
                vertical: 6 * scale,
              ),
              decoration: BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STATUS',
                        style: TextStyle(
                          fontSize: 8 * scale,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _isPasscodeEnabled ? 'Protected' : 'Unprotected',
                        style: TextStyle(
                          fontSize: 16 * scale,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  Transform.scale(
                    scale: 0.8 * scale,
                    child: Switch(
                      value: _isPasscodeEnabled,
                      activeColor: Colors.white,
                      activeTrackColor: Color(0xFF10B981),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Color(0xFFEF4444),
                      onChanged: (value) async {
                        final prefs = await SharedPreferences.getInstance();

                        if (value) {
                          final success = await _setupPasscode();

                          if (!success) {
                            setState(() => _isPasscodeEnabled = false);
                            return;
                          }

                          await prefs.setBool(
                            '${widget.user.email}_passcodeEnabled',
                            true,
                          );

                          setState(() => _isPasscodeEnabled = true);

                          AppSnackBar.showSuccess(
                            context,
                            message: "Passcode enabled",
                            duration: const Duration(seconds: 2),
                          );
                        } else {
                          await prefs.setBool(
                            '${widget.user.email}_passcodeEnabled',
                            false,
                          );

                          setState(() => _isPasscodeEnabled = false);

                          AppSnackBar.showWarning(
                            context,
                            message: "Passcode disabled",
                            duration: const Duration(seconds: 2),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            Row(
              children: [
                Icon(
                  _isPasscodeEnabled ? Icons.shield : Icons.shield_outlined,
                  size: 14 * scale,
                  color:
                      _isPasscodeEnabled
                          ? Color(0xFF10B981)
                          : Color(0xFFF59E0B),
                ),
                SizedBox(width: 8 * scale),
                Expanded(
                  child: Text(
                    _isPasscodeEnabled
                        ? 'Your app is secured with a passcode'
                        : 'Enable passcode protection for added security',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10 * scale,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRentalSection(bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 30,
            spreadRadius: 5,
            offset: Offset(0, 10),
          ),
        ],
        border: Border.all(color: Color(0xFFF1F5F9), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(16 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6 * scale,
                      height: 6 * scale,
                      margin: EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                        ),
                      ),
                    ),
                    Text(
                      'RENTAL',
                      style: TextStyle(
                        fontSize: 10 * scale,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8 * scale,
                    vertical: 5 * scale,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _isRentalEnabled
                            ? Color(0xFF10B981).withOpacity(0.1)
                            : Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          _isRentalEnabled
                              ? Color(0xFF10B981).withOpacity(0.3)
                              : Color(0xFFEF4444).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4 * scale,
                        height: 4 * scale,
                        margin: EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              _isRentalEnabled
                                  ? Color(0xFF10B981)
                                  : Color(0xFFEF4444),
                        ),
                      ),
                      Text(
                        _isRentalEnabled ? 'LIVE' : 'OFFLINE',
                        style: TextStyle(
                          fontSize: 8 * scale,
                          fontWeight: FontWeight.bold,
                          color:
                              _isRentalEnabled
                                  ? Color(0xFF065F46)
                                  : Color(0xFF991B1B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            Text(
              'Rental Page',
              style: TextStyle(
                fontSize: 16 * scale,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                letterSpacing: 0.5,
              ),
            ),

            SizedBox(height: 8),

            Text(
              'Control rental page visibility for users',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 10 * scale),
            ),

            SizedBox(height: 24),

            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12 * scale,
                vertical: 6 * scale,
              ),
              decoration: BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STATUS',
                        style: TextStyle(
                          fontSize: 8 * scale,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _isRentalEnabled ? 'Enabled' : 'Disabled',
                        style: TextStyle(
                          fontSize: 16 * scale,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  Transform.scale(
                    scale: 0.8 * scale,
                    child: Switch(
                      value: _isRentalEnabled,
                      activeColor: Colors.white,
                      activeTrackColor: Color(0xFF10B981),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Color(0xFFEF4444),
                      onChanged: (value) {
                        if (value) {
                          _enableRental();
                        } else {
                          _disableRental();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            Row(
              children: [
                Icon(
                  _isRentalEnabled ? Icons.visibility : Icons.visibility_off,
                  size: 14 * scale,
                  color:
                      _isRentalEnabled ? Color(0xFF10B981) : Color(0xFFEF4444),
                ),
                SizedBox(width: 8 * scale),
                Expanded(
                  child: Text(
                    _isRentalEnabled
                        ? 'Rental page is visible in Home Page'
                        : 'Rental page is hidden from Home Page',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10 * scale,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isSmallScreen) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: Offset(0, 5),
                ),
              ],
              border: Border.all(color: Color(0xFFE2E8F0)),
            ),
            child: TextButton(
              onPressed: _logout,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.logout_rounded,
                    color: Color(0xFF64748B),
                    size: 18 * scale,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 14 * scale,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        SizedBox(width: 16 * scale),

        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFFEF4444).withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: TextButton(
              onPressed: () => _showEnhancedDeleteDialog(context),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.white,
                    size: 18 * scale,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Delete',
                    style: TextStyle(
                      fontSize: 14 * scale,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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

  Future<void> _showEnhancedDeleteDialog(BuildContext context) async {
    await showConfirmDialog(
      context: context,
      title: "Delete Account?",
      message:
          "This will permanently remove all your data.\nThis action cannot be undone.",
      onConfirm: () {
        deleteCurrentUser(widget.user.email);
      },
    );
  }
}
