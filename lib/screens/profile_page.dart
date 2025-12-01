import 'dart:io';
import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:bizmate/widgets/confirm_delete_dialog.dart'
    show showConfirmDialog;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'
    show FlutterSecureStorage, AndroidOptions;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hive/hive.dart';
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

class _ProfilePageState extends State<ProfilePage> {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verifySession();
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

    // Read stored toggle
    final toggleValue =
        prefs.getBool('${widget.user.email}_passcodeEnabled') ?? false;

    // Read stored passcode (we do NOT enable automatically)
    final savedPasscode = await _secureStorage.read(
      key: "passcode_${widget.user.email}",
    );

    // Only enable if toggle = true
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

  Future<void> _setupPasscode() async {
    final newPasscode = await _showPasscodeDialog(
      "Setup Passcode",
      "Enter your new 4-digit passcode",
    );
    if (newPasscode != null && newPasscode.length == 4) {
      final confirmPasscode = await _showPasscodeDialog(
        "Confirm Passcode",
        "Re-enter your 4-digit passcode",
      );

      if (confirmPasscode == newPasscode) {
        await _secureStorage.write(
          key: "passcode_${widget.user.email}",
          value: newPasscode,
        );
        setState(() {
          _isPasscodeEnabled = true;
        });

        if (mounted) {
          AppSnackBar.showSuccess(
            context,
            message: 'Passcode setup successfully!',
            duration: Duration(seconds: 2),
          );
        }
      } else {
        if (mounted) {
          AppSnackBar.showError(
            context,
            message: 'Passcodes do not match!',
            duration: Duration(seconds: 2),
          );
        }
      }
    } else if (newPasscode != null) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          message: 'Passcode must be 4 digits!',
          duration: Duration(seconds: 2),
        );
      }
    }
  }

  Future<String?> _showPasscodeDialog(String title, String hint) async {
    TextEditingController passcodeController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: passcodeController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (passcodeController.text.length == 4) {
                  Navigator.of(context).pop(passcodeController.text);
                }
              },
              child: Text('Confirm'),
            ),
          ],
        );
      },
    );
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
      body: Container(
        height: screenHeight,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(200, 0, 0, 0),
              Color.fromARGB(150, 0, 0, 0),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 16 : 32,
              vertical: 20,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: isSmallScreen ? screenWidth * 0.95 : screenWidth * 0.7,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white30, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Column(
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: PopupMenuButton<String>(
                              icon: const Icon(
                                FontAwesomeIcons.ellipsisV,
                                color: Colors.white,
                                size: 20,
                              ),
                              shadowColor: Colors.black.withOpacity(0.3),
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
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.blueAccent
                                                .withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.edit,
                                            color: Colors.blueAccent,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Edit Profile',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ];
                              },
                            ),
                          ),
                          const SizedBox(height: 8),

                          GestureDetector(
                            onTap: _pickImage,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                _isImageLoading
                                    ? CircleAvatar(
                                      radius: 50,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                    : CircleAvatar(
                                      radius: isSmallScreen ? 50 : 60,
                                      backgroundColor: Colors.white.withOpacity(
                                        0.3,
                                      ),
                                      child:
                                          _profileImage != null && _isImageSaved
                                              ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(50),
                                                child: Image.file(
                                                  _profileImage!,
                                                  fit: BoxFit.cover,
                                                  width:
                                                      isSmallScreen ? 100 : 120,
                                                  height:
                                                      isSmallScreen ? 100 : 120,
                                                  errorBuilder: (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) {
                                                    return Text(
                                                      name.isNotEmpty
                                                          ? name[0]
                                                              .toUpperCase()
                                                          : 'U',
                                                      style: TextStyle(
                                                        fontSize:
                                                            isSmallScreen
                                                                ? 36
                                                                : 42,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              )
                                              : Text(
                                                name.isNotEmpty
                                                    ? name[0].toUpperCase()
                                                    : 'U',
                                                style: TextStyle(
                                                  fontSize:
                                                      isSmallScreen ? 36 : 42,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                    ),
                                if (!_isImageLoading)
                                  const CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.white,
                                    child: Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: Colors.black87,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _isEditing
                              ? TextField(
                                controller: _nameController,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 22 : 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              )
                              : Text(
                                name,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 22 : 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                          const SizedBox(height: 12),
                        ],
                      ),

                      _isEditing
                          ? Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            child: DropdownButtonFormField<String>(
                              value: role,
                              decoration: InputDecoration(
                                labelText: 'Role',
                                labelStyle: const TextStyle(
                                  color: Colors.white70,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.white30,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.white30,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.1),
                              ),
                              dropdownColor: Colors.blueGrey[800],
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.white70,
                              ),
                              style: TextStyle(
                                fontSize: isSmallScreen ? 16 : 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              onChanged: (String? newValue) async {
                                if (newValue == null) return;

                                setState(() {
                                  role = newValue;
                                  _roleController.text = newValue;
                                });

                                final prefs =
                                    await SharedPreferences.getInstance();

                                if (newValue == 'Photographer') {
                                  await prefs.setBool(
                                    '${widget.user.email}_rentalEnabled',
                                    true,
                                  );
                                  setState(() => _isRentalEnabled = true);
                                  widget.onRentalStatusChanged?.call();
                                } else {
                                  await prefs.setBool(
                                    '${widget.user.email}_rentalEnabled',
                                    false,
                                  );
                                  setState(() => _isRentalEnabled = false);
                                  widget.onRentalStatusChanged?.call();
                                }
                              },
                              items:
                                  roles.map<DropdownMenuItem<String>>((
                                    String value,
                                  ) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(
                                        value,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            ),
                          )
                          : Container(
                            margin: const EdgeInsets.symmetric(vertical: 16),
                            child: Chip(
                              avatar: CircleAvatar(
                                backgroundColor: Colors.blue.shade100
                                    .withOpacity(0.8),
                                child: Icon(
                                  Icons.work_outline,
                                  size: isSmallScreen ? 18 : 20,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              label: Text(
                                role,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 16 : 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              backgroundColor: Colors.blue.shade50.withOpacity(
                                0.9,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.blue.shade200.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),

                      const Divider(color: Colors.white30, height: 20),
                      const SizedBox(height: 20),

                      _buildInfoSection(isSmallScreen),

                      // Passcode Control Section - For all users
                      if (!_isEditing) ...[
                        const SizedBox(height: 10),
                        const Divider(color: Colors.white30, height: 20),
                        const SizedBox(height: 10),
                        _buildPasscodeControlSection(isSmallScreen),
                      ],

                      // Rental Page Control Section - Only for Photographer role
                      if (role == 'Photographer' && !_isEditing) ...[
                        const SizedBox(height: 10),
                        const Divider(color: Colors.white30, height: 20),
                        const SizedBox(height: 10),
                        _buildRentalControlSection(isSmallScreen),
                      ],

                      if (_isEditing) ...[
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _toggleEditing,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.black,
                                  side: BorderSide(color: Colors.white),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 16 : 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  side: BorderSide(color: Colors.white),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 16 : 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),

                if (!_isEditing) ...[
                  const SizedBox(height: 30),
                  SizedBox(
                    width:
                        isSmallScreen ? screenWidth * 0.95 : screenWidth * 0.7,
                    child: Row(
                      children: [
                        Expanded(
                          child: _actionButton(
                            icon: Icons.logout,
                            text: "Logout",
                            color: Colors.black,
                            borderColor: Colors.white,
                            onTap: _logout,
                            isSmallScreen: isSmallScreen,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _actionButton(
                            icon: Icons.delete_forever,
                            text: "Delete",
                            color: Colors.red.shade600,
                            borderColor: Colors.white,
                            gradient: LinearGradient(
                              colors: [
                                Colors.red.shade600,
                                Colors.red.shade800,
                              ],
                            ),
                            onTap: () => _showEnhancedDeleteDialog(context),
                            isSmallScreen: isSmallScreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(bool isSmallScreen) {
    return Column(
      children: [
        _buildInfoField(
          Icons.email,
          "Email",
          _emailController,
          email,
          isSmallScreen,
        ),
        const SizedBox(height: 16),
        _buildInfoField(
          Icons.phone,
          "Phone",
          _phoneController,
          phone,
          isSmallScreen,
        ),
        const SizedBox(height: 16),
        _buildInfoField(
          Icons.qr_code,
          "UPI ID",
          _upiController,
          upiId.isEmpty ? "No UPI ID" : upiId,
          isSmallScreen,
        ),
        const SizedBox(height: 16),
        _glassInfoRow(Icons.location_city, 'Bangalore, India', isSmallScreen),
      ],
    );
  }

  Widget _buildRentalControlSection(bool isSmallScreen) {
    final w = MediaQuery.of(context).size.width;
    final isTablet = w > 600;

    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isTablet ? 20 : 10),
        color: Colors.grey.shade900,
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: isTablet ? 40 : 20,
            offset: Offset(0, isTablet ? 12 : 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// --- Header Row ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: isTablet ? 12 : 8,
                    height: isTablet ? 12 : 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.blueAccent, Colors.cyanAccent],
                      ),
                    ),
                  ),
                  Text(
                    "RENTAL CONTROL",
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),

              /// LIVE / OFFLINE Badge
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 14 : 10,
                  vertical: isTablet ? 6 : 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color:
                      _isRentalEnabled
                          ? Colors.green.withOpacity(0.15)
                          : Colors.red.withOpacity(0.15),
                  border: Border.all(
                    color:
                        _isRentalEnabled
                            ? Colors.greenAccent.withOpacity(0.3)
                            : Colors.redAccent.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: isTablet ? 8 : 4,
                      height: isTablet ? 8 : 4,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            _isRentalEnabled
                                ? Colors.greenAccent
                                : Colors.redAccent,
                      ),
                    ),
                    Text(
                      _isRentalEnabled ? "LIVE" : "OFFLINE",
                      style: TextStyle(
                        fontSize: isTablet ? 11 : 8,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: isTablet ? 18 : 12),

          /// --- Title & Subtitle ---
          Text(
            "Rental Page Access",
            style: TextStyle(
              fontSize: isTablet ? 28 : (isSmallScreen ? 22 : 24),
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Toggle to enable or disable the rental page for all users",
            style: TextStyle(
              fontSize: isTablet ? 17 : 14,
              color: Colors.white.withOpacity(0.5),
              height: 1.4,
            ),
          ),

          SizedBox(height: isTablet ? 30 : 24),

          /// --- Switch Row ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              /// Left Status
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "STATUS",
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 10,
                      color: Colors.white54,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _isRentalEnabled ? "Enabled" : "Disabled",
                    style: TextStyle(
                      fontSize: isTablet ? 40 : (isSmallScreen ? 24 : 32),
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),

              /// Right Switch
              Transform.scale(
                scale: isTablet ? 1.35 : (isSmallScreen ? 1.0 : 1.15),
                child: Switch(
                  value: _isRentalEnabled,
                  activeThumbColor: Colors.white,
                  inactiveThumbColor: Colors.white,
                  activeTrackColor: Colors.green.shade700,
                  inactiveTrackColor: Colors.red.shade700,
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

          SizedBox(height: isTablet ? 16 : 6),

          Divider(color: Colors.white.withOpacity(0.1)),

          /// --- Bottom Status Text ---
          Row(
            children: [
              Icon(
                _isRentalEnabled ? Icons.visibility : Icons.visibility_off,
                size: isTablet ? 22 : 16,
                color: _isRentalEnabled ? Colors.greenAccent : Colors.redAccent,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isRentalEnabled
                      ? "Rental page is currently visible in your Home Page"
                      : "Rental page is hidden from your Home Page",
                  style: TextStyle(
                    fontSize: isTablet ? 15 : 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasscodeControlSection(bool isSmallScreen) {
    final w = MediaQuery.of(context).size.width;
    final isTablet = w > 600;

    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isTablet ? 20 : 10),
        color: Colors.grey.shade900,
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: isTablet ? 40 : 20,
            offset: Offset(0, isTablet ? 12 : 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ------------------ HEADER ------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: isTablet ? 12 : 8,
                    height: isTablet ? 12 : 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Colors.purpleAccent, Colors.pinkAccent],
                      ),
                    ),
                  ),
                  Text(
                    "SECURITY CONTROL",
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),

              /// ACTIVE or INACTIVE badge
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 14 : 10,
                  vertical: isTablet ? 6 : 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color:
                      _isPasscodeEnabled
                          ? Colors.green.withOpacity(0.15)
                          : Colors.red.withOpacity(0.15),
                  border: Border.all(
                    color:
                        _isPasscodeEnabled
                            ? Colors.greenAccent.withOpacity(0.3)
                            : Colors.redAccent.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: isTablet ? 8 : 4,
                      height: isTablet ? 8 : 4,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            _isPasscodeEnabled
                                ? Colors.greenAccent
                                : Colors.redAccent,
                      ),
                    ),
                    Text(
                      _isPasscodeEnabled ? "ACTIVE" : "INACTIVE",
                      style: TextStyle(
                        fontSize: isTablet ? 11 : 8,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: isTablet ? 18 : 12),

          /// ------------------ TITLE + SUBTITLE ------------------
          Text(
            "App Passcode",
            style: TextStyle(
              fontSize: isTablet ? 30 : (isSmallScreen ? 22 : 24),
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),

          SizedBox(height: 6),

          Text(
            "Secure your app with a passcode",
            style: TextStyle(
              fontSize: isTablet ? 17 : (isSmallScreen ? 13.5 : 15),
              color: Colors.white.withOpacity(0.5),
              height: 1.4,
            ),
          ),

          SizedBox(height: isTablet ? 30 : 24),

          /// ------------------ STATUS + SWITCH ------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              /// Left status
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "SECURITY",
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 11,
                      color: Colors.white54,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isPasscodeEnabled ? "Protected" : "Unprotected",
                    style: TextStyle(
                      fontSize: isTablet ? 40 : (isSmallScreen ? 24 : 32),
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),

              /// Right switch (responsive)
              Transform.scale(
                scale: isTablet ? 1.35 : (isSmallScreen ? 1.0 : 1.15),
                child: Switch(
                  value: _isPasscodeEnabled,
                  activeThumbColor: Colors.white,
                  inactiveThumbColor: Colors.white,
                  activeTrackColor: Colors.green.shade700,
                  inactiveTrackColor: Colors.red.shade700,
                  onChanged: (value) async {
                    final prefs = await SharedPreferences.getInstance();

                    if (value) {
                      final existing = await _secureStorage.read(
                        key: "passcode_${widget.user.email}",
                      );

                      if (existing == null || existing.isEmpty) {
                        await _setupPasscode();
                      }

                      await prefs.setBool(
                        '${widget.user.email}_passcodeEnabled',
                        true,
                      );

                      setState(() => _isPasscodeEnabled = true);

                      AppSnackBar.showSuccess(
                        context,
                        message: "Passcode enabled",
                        duration: Duration(seconds: 2),
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
                        duration: Duration(seconds: 2),
                      );
                    }
                  },
                ),
              ),
            ],
          ),

          SizedBox(height: isTablet ? 16 : 6),

          Divider(color: Colors.white.withOpacity(0.1)),

          /// ------------------ BOTTOM MESSAGE ------------------
          Row(
            children: [
              Icon(
                _isPasscodeEnabled ? Icons.security : Icons.no_encryption,
                size: isTablet ? 22 : 16,
                color:
                    _isPasscodeEnabled
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isPasscodeEnabled
                      ? "App passcode is currently active and securing your data"
                      : "Passcode disabled but stored safely for future use",
                  style: TextStyle(
                    fontSize: isTablet ? 15 : 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoField(
    IconData icon,
    String label,
    TextEditingController controller,
    String value,
    bool isSmallScreen,
  ) {
    return _isEditing
        ? Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white30),
          ),
          child: TextField(
            controller: controller,
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.white70, size: 22),
              hintText: value.isEmpty ? 'Enter your $label' : value,
              hintStyle: const TextStyle(color: Colors.white54),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
            ),
          ),
        )
        : _glassInfoRow(
          icon,
          value.isNotEmpty
              ? (label == "Phone" ? "+91 $value" : value)
              : "No $label",
          isSmallScreen,
        );
  }

  Widget _glassInfoRow(IconData icon, String text, bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white30),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: isSmallScreen ? 16 : 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String text,
    required Color color,
    Gradient? gradient,
    Color borderColor = Colors.transparent,
    required Function onTap,
    required bool isSmallScreen,
  }) {
    return InkWell(
      onTap: () => onTap(),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow:
              gradient != null
                  ? [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: isSmallScreen ? 20 : 22),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: isSmallScreen ? 16 : 18,
              ),
            ),
          ],
        ),
      ),
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
