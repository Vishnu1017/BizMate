import 'dart:io';
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

  late TextEditingController _nameController;
  late TextEditingController _roleController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _upiController;

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

    _nameController = TextEditingController(text: name);
    _roleController = TextEditingController(text: role);
    _emailController = TextEditingController(text: email);
    _phoneController = TextEditingController(text: phone);
    _upiController = TextEditingController(text: upiId);

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
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.all(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
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
                  padding: EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
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
                          size: 28,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Security Level",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Choose your preferred authentication method",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Options
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSecurityOption(
                        icon: Icons.looks_4_rounded,
                        title: "4-Digit PIN",
                        description: "Basic security • Quick access",
                        level: "Low",
                        color: Color(0xFF3B82F6),
                        value: "pin4",
                        isRecommended: false,
                      ),

                      SizedBox(height: 12),

                      _buildSecurityOption(
                        icon: Icons.looks_6_rounded,
                        title: "6-Digit PIN",
                        description: "Enhanced security • Recommended",
                        level: "Medium",
                        color: Color(0xFF10B981),
                        value: "pin6",
                        isRecommended: true,
                      ),

                      SizedBox(height: 12),

                      _buildSecurityOption(
                        icon: Icons.password_rounded,
                        title: "Alphanumeric",
                        description: "Maximum security • Letters & numbers",
                        level: "High",
                        color: Color(0xFF8B5CF6),
                        value: "alphanumeric",
                        isRecommended: false,
                      ),
                    ],
                  ),
                ),

                // Cancel Button
                Container(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
          padding: EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white,
            border: Border.all(
              color: isRecommended ? color.withOpacity(0.3) : Color(0xFFF1F5F9),
              width: isRecommended ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                  ),
                ),
                child: Center(child: Icon(icon, color: color, size: 24)),
              ),

              SizedBox(width: 16),

              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        SizedBox(width: 8),
                        if (isRecommended)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: color.withOpacity(0.3)),
                            ),
                            child: Text(
                              "Recommended",
                              style: TextStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            level,
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF475569),
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
                color: Color(0xFF94A3B8),
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
    TextEditingController passcodeController = TextEditingController();
    bool isObscured = true;
    bool isConfirmMode = false;
    String firstPasscode = "";
    String currentTitle = title;
    String currentHint = hint;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: EdgeInsets.all(20),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
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
                        vertical: 24,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                        gradient: _getPasscodeTypeGradient(passcodeType),
                      ),
                      child: Column(
                        children: [
                          // Progress indicator
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (int i = 0; i < (isConfirmMode ? 2 : 1); i++)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        i == 0
                                            ? Colors.white
                                            : Colors.white.withOpacity(0.3),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 16),

                          Icon(
                            isConfirmMode
                                ? Icons.verified_rounded
                                : Icons.lock_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                          SizedBox(height: 16),

                          Text(
                            currentTitle,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 8),

                          Text(
                            currentHint,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          if (isConfirmMode) ...[
                            SizedBox(height: 8),
                            Text(
                              "Re-enter your passcode to confirm",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Body
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Visual indicator
                          _buildPasscodeVisualIndicator(
                            passcodeController.text,
                            maxLength,
                            passcodeType,
                            isConfirmMode,
                          ),

                          SizedBox(height: 32),

                          // Input field with toggle
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Color(0xFFE2E8F0),
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
                                      fontSize: _getFontSizeForPasscodeType(
                                        passcodeType,
                                      ),
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                      letterSpacing:
                                          _getLetterSpacingForPasscodeType(
                                            passcodeType,
                                          ),
                                      fontFamily:
                                          passcodeType == "alphanumeric"
                                              ? 'monospace'
                                              : null,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: _getHintTextForPasscodeType(
                                        passcodeType,
                                      ),
                                      hintStyle: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        letterSpacing:
                                            _getLetterSpacingForPasscodeType(
                                              passcodeType,
                                            ),
                                        fontFamily:
                                            passcodeType == "alphanumeric"
                                                ? 'monospace'
                                                : null,
                                      ),
                                      counterText: '',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setState(() {});
                                      // Auto-submit when max length reached for PIN
                                      if ((passcodeType == "pin4" ||
                                              passcodeType == "pin6") &&
                                          value.length == maxLength &&
                                          !isConfirmMode) {
                                        Future.delayed(
                                          Duration(milliseconds: 300),
                                          () {
                                            setState(() {
                                              firstPasscode = value;
                                              isConfirmMode = true;
                                              passcodeController.clear();
                                              currentTitle = "Confirm Passcode";
                                              currentHint =
                                                  "Re-enter your $maxLength-digit PIN";
                                            });
                                          },
                                        );
                                      }
                                    },
                                  ),
                                ),

                                // Toggle visibility button (for alphanumeric)
                                if (passcodeType == "alphanumeric")
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        isObscured = !isObscured;
                                      });
                                    },
                                    icon: Icon(
                                      isObscured
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      color: Color(0xFF64748B),
                                      size: 22,
                                    ),
                                    splashRadius: 20,
                                    padding: EdgeInsets.all(8),
                                  ),
                              ],
                            ),
                          ),

                          SizedBox(height: 12),

                          // Requirements indicator
                          _buildPasscodeRequirements(
                            passcodeType,
                            passcodeController.text,
                          ),

                          // Length indicator
                          if (passcodeType == "alphanumeric")
                            Container(
                              margin: EdgeInsets.only(top: 8),
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Length: ",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    "${passcodeController.text.length}/$maxLength",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          passcodeController.text.length ==
                                                  maxLength
                                              ? Color(0xFF10B981)
                                              : Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Action Buttons
                    Container(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Row(
                        children: [
                          // Cancel/Back Button
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Color(0xFFE2E8F0)),
                              ),
                              child: TextButton(
                                onPressed:
                                    isConfirmMode
                                        ? () {
                                          setState(() {
                                            isConfirmMode = false;
                                            passcodeController.clear();
                                            currentTitle = title;
                                            currentHint = hint;
                                          });
                                        }
                                        : () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isConfirmMode)
                                      Icon(Icons.arrow_back_rounded, size: 18),
                                    SizedBox(width: isConfirmMode ? 6 : 0),
                                    Text(
                                      isConfirmMode ? "Back" : "Cancel",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          SizedBox(width: 16),

                          // Confirm/Next Button
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: _getPasscodeTypeGradient(
                                  passcodeType,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _getPrimaryColorForPasscodeType(
                                      passcodeType,
                                    ).withOpacity(0.3),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed:
                                    passcodeController.text.length == maxLength
                                        ? () {
                                          if (isConfirmMode) {
                                            if (passcodeController.text ==
                                                firstPasscode) {
                                              Navigator.pop(
                                                context,
                                                firstPasscode,
                                              );
                                            } else {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    "Passcodes don't match. Try again.",
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                              setState(() {
                                                passcodeController.clear();
                                              });
                                            }
                                          } else {
                                            if (passcodeType ==
                                                "alphanumeric") {
                                              setState(() {
                                                firstPasscode =
                                                    passcodeController.text;
                                                isConfirmMode = true;
                                                passcodeController.clear();
                                                currentTitle =
                                                    "Confirm Passcode";
                                                currentHint =
                                                    "Re-enter your alphanumeric passcode";
                                              });
                                            } else {
                                              // For PINs, already handled by auto-submit
                                            }
                                          }
                                        }
                                        : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      isConfirmMode ? "Confirm" : "Continue",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    SizedBox(width: 8),
                                    Icon(
                                      isConfirmMode
                                          ? Icons.check_rounded
                                          : Icons.arrow_forward_rounded,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
    bool isConfirmMode,
  ) {
    return Column(
      children: [
        // Dots or letters indicator
        if (passcodeType == "pin4" || passcodeType == "pin6")
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(maxLength, (index) {
              final filled = index < text.length;
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 8),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      filled
                          ? _getPrimaryColorForPasscodeType(passcodeType)
                          : Color(0xFFE2E8F0),
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
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFE2E8F0)),
            ),
            child: Text(
              text.isEmpty ? "Enter your passcode" : "•" * text.length,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: text.isEmpty ? Color(0xFF94A3B8) : Color(0xFF1E293B),
                fontFamily: 'monospace',
                letterSpacing: 4,
              ),
            ),
          ),

        SizedBox(height: 8),

        // Status text
        if (text.isNotEmpty)
          Text(
            "${text.length} character${text.length != 1 ? 's' : ''} entered",
            style: TextStyle(
              fontSize: 12,
              color: _getPrimaryColorForPasscodeType(passcodeType),
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  Widget _buildPasscodeRequirements(String passcodeType, String currentText) {
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
      return SizedBox(); // No requirements for 4-digit PIN
    }

    return Container(
      margin: EdgeInsets.only(top: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Requirements:",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
            ),
          ),
          SizedBox(height: 8),
          ...requirements
              .map(
                (req) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        req["met"]
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 14,
                        color:
                            req["met"] ? Color(0xFF10B981) : Color(0xFF94A3B8),
                      ),
                      SizedBox(width: 8),
                      Text(
                        req["text"],
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              req["met"]
                                  ? Color(0xFF10B981)
                                  : Color(0xFF64748B),
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

  // Helper functions
  LinearGradient _getPasscodeTypeGradient(String passcodeType) {
    switch (passcodeType) {
      case "pin6":
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        );
      case "alphanumeric":
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
        );
      default: // pin4
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
        );
    }
  }

  Color _getPrimaryColorForPasscodeType(String passcodeType) {
    switch (passcodeType) {
      case "pin6":
        return Color(0xFF10B981);
      case "alphanumeric":
        return Color(0xFF8B5CF6);
      default:
        return Color(0xFF3B82F6);
    }
  }

  double _getFontSizeForPasscodeType(String passcodeType) {
    switch (passcodeType) {
      case "pin4":
        return 28.0;
      case "pin6":
        return 26.0;
      case "alphanumeric":
        return 20.0;
      default:
        return 22.0;
    }
  }

  double _getLetterSpacingForPasscodeType(String passcodeType) {
    switch (passcodeType) {
      case "pin4":
        return 12.0;
      case "pin6":
        return 10.0;
      case "alphanumeric":
        return 2.0;
      default:
        return 8.0;
    }
  }

  String _getHintTextForPasscodeType(String passcodeType) {
    switch (passcodeType) {
      case "pin4":
        return "0000";
      case "pin6":
        return "000000";
      case "alphanumeric":
        return "Enter passcode";
      default:
        return "Enter passcode";
    }
  }

  bool _hasRepeatingPattern(String text) {
    if (text.length < 2) return false;

    // Check for repeating digits (e.g., 111111, 121212)
    for (int i = 0; i < text.length - 1; i++) {
      if (text[i] != text[i + 1]) {
        return false;
      }
    }
    return true;
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

      final file = File(picked.path);
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

        await existingUser.save();

        setState(() {
          name = existingUser.name;
          role = existingUser.role;
          email = existingUser.email;
          phone = existingUser.phone;
          upiId = existingUser.upiId;
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
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'PROFILE',
                    style: TextStyle(
                      fontSize: 12,
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
                    size: 28,
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
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Color(0xFF3B82F6).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.edit,
                                color: Color(0xFF3B82F6),
                                size: 18,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontSize: 14,
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

            SizedBox(height: 20),

            // Profile Image
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: isSmallScreen ? 120 : 140,
                  height: isSmallScreen ? 120 : 140,
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
                        width: isSmallScreen ? 100 : 120,
                        height: isSmallScreen ? 100 : 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
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
                                              fontSize: 36,
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
                                          fontSize: 36,
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
                          padding: EdgeInsets.all(10),
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
                            size: 18,
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
                    fontSize: isSmallScreen ? 24 : 28,
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
                      Icon(Icons.work, size: 16, color: Color(0xFF3B82F6)),
                      SizedBox(width: 8),
                      Text(
                        role,
                        style: TextStyle(
                          fontSize: 14,
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
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_city_rounded,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Bangalore, India',
                          style: TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Color(0xFF64748B), size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
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
                        fontSize: 16,
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
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
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        width: 6,
                        height: 6,
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
                          fontSize: 10,
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
                fontSize: isSmallScreen ? 22 : 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                letterSpacing: 0.5,
              ),
            ),

            SizedBox(height: 8),

            Text(
              'Secure your app with a 4-digit passcode',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),

            SizedBox(height: 24),

            Container(
              padding: EdgeInsets.all(16),
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
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _isPasscodeEnabled ? 'Protected' : 'Unprotected',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  Transform.scale(
                    scale: 1.2,
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
                  size: 18,
                  color:
                      _isPasscodeEnabled
                          ? Color(0xFF10B981)
                          : Color(0xFFF59E0B),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isPasscodeEnabled
                        ? 'Your app is secured with a passcode'
                        : 'Enable passcode protection for added security',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
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
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        width: 6,
                        height: 6,
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
                          fontSize: 10,
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
                fontSize: isSmallScreen ? 22 : 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                letterSpacing: 0.5,
              ),
            ),

            SizedBox(height: 8),

            Text(
              'Control rental page visibility for users',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),

            SizedBox(height: 24),

            Container(
              padding: EdgeInsets.all(16),
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
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _isRentalEnabled ? 'Enabled' : 'Disabled',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  Transform.scale(
                    scale: 1.2,
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
                  size: 18,
                  color:
                      _isRentalEnabled ? Color(0xFF10B981) : Color(0xFFEF4444),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isRentalEnabled
                        ? 'Rental page is visible in Home Page'
                        : 'Rental page is hidden from Home Page',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
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
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        SizedBox(width: 16),

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
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Delete',
                    style: TextStyle(
                      fontSize: 16,
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
