// ignore_for_file: library_private_types_in_public_api

import 'package:bizmate/screens/nav_bar_page.dart' show NavBarPage;
import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'
    show FlutterSecureStorage, AndroidOptions;
import 'package:hive/hive.dart';
import 'package:bizmate/models/user_model.dart';
import 'package:bizmate/screens/auth_gate_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ ADDED

// 🔥 Each user gets a separate private box
Future<Box> openUserDataBox(String email) async {
  final safeEmail = email.replaceAll('.', '_').replaceAll('@', '_');
  return await Hive.openBox('userdata_$safeEmail');
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool isCreating = false;
  bool _obscurePassword = true;
  late AnimationController _controller;
  String selectedRole = 'None';
  bool _isProcessing = false;
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

  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final resetEmailController = TextEditingController();

  bool _isFullNameValid = true;
  bool _isPhoneValid = true;
  bool _isEmailValid = true;
  bool _isPasswordValid = true;
  bool _isResetEmailValid = true;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    fullNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    resetEmailController.dispose();
    super.dispose();
  }

  void toggleMode() {
    setState(() {
      isCreating = !isCreating;
      if (isCreating) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
      _resetValidationStates();
    });
  }

  void _resetValidationStates() {
    setState(() {
      _isFullNameValid = true;
      _isPhoneValid = true;
      _isEmailValid = true;
      _isPasswordValid = true;
      _isResetEmailValid = true;
    });
  }

  bool _isValidFullName(String name) => name.trim().length >= 2;

  bool _isValidPhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    return cleaned.length == 10 && !cleaned.startsWith('0');
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(email.trim());
  }

  bool _isValidPassword(String password) => password.length >= 6;

  // ----------------------------------------------------------------------
  // 🔥 CREATE ACCOUNT
  // ----------------------------------------------------------------------
  Future<void> createAccount() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    final fullName = fullNameController.text.trim();
    final phone = phoneController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    bool isValid = true;

    if (!_isValidFullName(fullName)) {
      setState(() => _isFullNameValid = false);
      isValid = false;
    }

    if (!_isValidPhoneNumber(phone)) {
      setState(() => _isPhoneValid = false);
      isValid = false;
    }

    if (!_isValidEmail(email)) {
      setState(() => _isEmailValid = false);
      isValid = false;
    }

    if (!_isValidPassword(password)) {
      setState(() => _isPasswordValid = false);
      isValid = false;
    }

    if (!isValid) {
      showError("Please fix the validation errors above");
      return;
    }

    if (selectedRole == "None") {
      showError("Please select your profession");
      return;
    }

    final usersBox = Hive.box<User>('users');

    if (usersBox.values.any((u) => u.email == email)) {
      showError("Email already exists");
      return;
    }

    if (usersBox.values.any((u) => u.phone == phone)) {
      showError("Phone number already exists");
      return;
    }

    try {
      final user = User(
        name: fullName,
        email: email,
        phone: phone,
        password: password,
        role: selectedRole,
        upiId: '',
        imageUrl: '',
      );

      await usersBox.add(user);

      // 🔥 Create private user data box
      final userBox = await openUserDataBox(email);

      await userBox.put('profile', {
        "name": user.name,
        "email": user.email,
        "phone": user.phone,
        "role": user.role,
        "imageUrl": user.imageUrl,
      });

      await userBox.put("sales", []);
      await userBox.put("rentals", []);
      await userBox.put("invoices", []);

      final sessionBox = await Hive.openBox("session");
      await sessionBox.put("currentUserEmail", email);

      showSuccess("Account created successfully!");

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => AuthGateScreen(
                  user: user,
                  userPhone: user.phone,
                  userEmail: user.email,
                ),
          ),
        );
      }
    } catch (e) {
      showError("Account creation failed. Try again.");
    }
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  // ----------------------------------------------------------------------
  // ✅ PASSCODE ENABLE / DISABLE CHECK (Respects ProfilePage Switch)
  // ----------------------------------------------------------------------
  Future<bool> _isPasscodeEnabledForUser(String email) async {
    final secure = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );

    // Is there any passcode stored?
    final passcodeExists = await secure.read(key: "passcode_$email");
    if (passcodeExists == null || passcodeExists.isEmpty) {
      // No passcode at all → treat as disabled
      return false;
    }

    // Check the toggle flag set from ProfilePage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    final enabledFlag = prefs.getBool('${email}_passcodeEnabled');

    // If flag is null, default to true (for old users before flag existed)
    return enabledFlag ?? true;
  }

  // ----------------------------------------------------------------------
  // 🔥 LOGIN
  // ----------------------------------------------------------------------
  Future<void> login() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    final input = emailController.text.trim();
    final password = passwordController.text.trim();

    if (input.isEmpty) {
      showError("Please enter your email or phone number");
      setState(() => _isProcessing = false);
      return;
    }

    if (password.isEmpty) {
      showError("Please enter your password");
      setState(() => _isProcessing = false);
      return;
    }

    try {
      final box = Hive.box<User>('users');

      // First check if user exists (email or phone)
      final existsUser = box.values.firstWhere(
        (u) => u.email == input || u.phone == input,
        orElse:
            () => User(
              name: '',
              email: '',
              phone: '',
              password: '',
              role: '',
              upiId: '',
              imageUrl: '',
            ),
      );

      if (existsUser.name.isEmpty) {
        showError("User not found. Please create an account.");
        setState(() => _isProcessing = false);
        return;
      }

      // Password verification
      if (existsUser.password != password) {
        showError("Incorrect password");
        setState(() => _isProcessing = false);
        return;
      }

      // Correct login → proceed
      await openUserDataBox(existsUser.email);

      final sessionBox = await Hive.openBox('session');
      await sessionBox.put('currentUserEmail', existsUser.email);

      final isEnabled = await _isPasscodeEnabledForUser(existsUser.email);

      if (isEnabled) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => AuthGateScreen(
                  user: existsUser,
                  userPhone: existsUser.phone,
                  userEmail: existsUser.email,
                ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => NavBarPage(
                  user: existsUser,
                  userPhone: existsUser.phone,
                  userEmail: existsUser.email,
                ),
          ),
        );
      }
    } catch (e) {
      showError("Login failed. Try again.");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // ----------------------------------------------------------------------
  // 🔥 AUTO LOGIN SESSION
  // ----------------------------------------------------------------------
  Future<void> _checkExistingSession() async {
    final sessionBox = await Hive.openBox('session');
    final email = sessionBox.get('currentUserEmail');

    if (email == null) return;

    final usersBox = Hive.box<User>('users');

    final user = usersBox.values.firstWhere(
      (u) => u.email == email,
      orElse:
          () => User(
            name: '',
            email: '',
            phone: '',
            password: '',
            role: '',
            upiId: '',
            imageUrl: '',
          ),
    );

    if (user.name.isEmpty) return;

    await openUserDataBox(email);

    if (mounted) {
      final isEnabled = await _isPasscodeEnabledForUser(user.email);

      if (isEnabled) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => AuthGateScreen(
                  user: user,
                  userPhone: user.phone,
                  userEmail: user.email,
                ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => NavBarPage(
                  user: user,
                  userPhone: user.phone,
                  userEmail: user.email,
                ),
          ),
        );
      }
    }
  }

  // ----------------------------------------------------------------------
  // SNACKBAR HELPERS
  // ----------------------------------------------------------------------
  void showError(String msg) {
    AppSnackBar.showError(
      context,
      message: msg,
      duration: const Duration(seconds: 2),
    );
  }

  void showSuccess(String msg) {
    AppSnackBar.showSuccess(
      context,
      message: msg,
      duration: const Duration(seconds: 2),
    );
  }

  // ----------------------------------------------------------------------
  // 🔥 RESET PASSWORD – STEP 1: ASK EMAIL
  // ----------------------------------------------------------------------
  void _showResetPasswordDialog() {
    resetEmailController.clear();
    setState(() => _isResetEmailValid = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final media = MediaQuery.of(dialogContext);

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: media.size.height * 0.85,
                maxWidth: 500,
              ),
              child: Material(
                borderRadius: BorderRadius.circular(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: EdgeInsets.all(22 * scale),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF3EE4D8),
                          Color(0xFF1FB5D0),
                          Color(0xFF0F73B8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              icon: Icon(
                                Icons.close,
                                color: const Color(0xFF072A4A),
                                size: 20 * scale,
                              ),
                              onPressed: () => Navigator.pop(dialogContext),
                            ),
                          ),

                          SizedBox(height: 8 * scale),

                          const Icon(
                            Icons.lock_reset,
                            size: 50,
                            color: Color(0xFF072A4A),
                          ),

                          SizedBox(height: 18 * scale),

                          Text(
                            "Reset Password",
                            style: TextStyle(
                              color: const Color(0xFF072A4A),
                              fontSize: 18 * scale,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: 16 * scale),

                          TextField(
                            controller: resetEmailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Color(0xFF072A4A), fontWeight: FontWeight.w600),
                            cursorColor: const Color(0xFF072A4A),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.3),
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: Color(0xFF072A4A),
                              ),
                              labelText: "Enter your email",
                              labelStyle: const TextStyle(
                                color: Color(0xFF072A4A),
                                fontWeight: FontWeight.w600,
                              ),
                              errorText:
                                  _isResetEmailValid ? null : "Invalid email",
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: const Color(0xFF072A4A).withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF072A4A),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 18 * scale),

                          SizedBox(
                            width: double.infinity,
                            height: 44 * scale,
                            child: ElevatedButton(
                              onPressed: _handlePasswordReset,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.blue.shade700,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "Reset Password",
                                style: TextStyle(
                                  fontSize: 13 * scale,
                                  fontWeight: FontWeight.w600,
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
        );
      },
    );
  }

  // ----------------------------------------------------------------------
  // 🔥 RESET PASSWORD – STEP 2: CREATE NEW PASSWORD
  // ----------------------------------------------------------------------
  void _handlePasswordReset() {
    final email = resetEmailController.text.trim();

    if (!_isValidEmail(email)) {
      setState(() => _isResetEmailValid = false);
      showError("Invalid email address");
      return;
    }

    final usersBox = Hive.box<User>('users');

    final user = usersBox.values.firstWhere(
      (u) => u.email == email,
      orElse:
          () => User(
            name: '',
            email: '',
            phone: '',
            password: '',
            role: '',
            upiId: '',
            imageUrl: '',
          ),
    );

    if (user.name.isEmpty) {
      setState(() => _isResetEmailValid = false);
      showError("No account found for this email");
      return;
    }

    Navigator.pop(context);

    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final media = MediaQuery.of(dialogContext);

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          backgroundColor: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: media.size.height * 0.9,
                maxWidth: 500, // tablet safe
              ),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                elevation: 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: ScrollConfiguration(
                    behavior: const ScrollBehavior().copyWith(
                      overscroll: false,
                    ),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.all(28 * scale),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double responsiveScale =
                              (constraints.maxWidth / 360).clamp(0.85, 1.05) *
                              scale;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ================= HEADER =================
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(
                                      12 * responsiveScale,
                                    ),
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF3EE4D8),
                                          Color(0xFF1FB5D0),
                                          Color(0xFF0F73B8),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.lock_reset_rounded,
                                      color: Colors.white,
                                      size: 20 * responsiveScale,
                                    ),
                                  ),
                                  SizedBox(width: 12 * responsiveScale),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Create New Password",
                                          style: TextStyle(
                                            fontSize: 18 * responsiveScale,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.grey.shade900,
                                          ),
                                        ),
                                        SizedBox(height: 4 * responsiveScale),
                                        Text(
                                          "Secure your account with a new password",
                                          style: TextStyle(
                                            fontSize: 11 * responsiveScale,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 22 * responsiveScale),

                              _PasswordStrengthIndicator(newPasswordController),

                              SizedBox(height: 18 * responsiveScale),

                              _ModernPasswordField(
                                controller: newPasswordController,
                                label: "New Password",
                                hint: "Enter at least 6 characters",
                              ),

                              SizedBox(height: 16 * responsiveScale),

                              _ModernPasswordField(
                                controller: confirmPasswordController,
                                label: "Confirm Password",
                                hint: "Re-enter your password",
                              ),

                              SizedBox(height: 10 * responsiveScale),

                              _PasswordMatchIndicator(
                                newPasswordController,
                                confirmPasswordController,
                              ),

                              SizedBox(height: 28 * responsiveScale),

                              // ================= BUTTONS =================
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final double buttonScale =
                                      (constraints.maxWidth / 360).clamp(
                                        0.85,
                                        1.0,
                                      ) *
                                      responsiveScale;

                                  final double height = 46 * buttonScale;
                                  final double radius = 14 * buttonScale;
                                  final double textSize = 12 * buttonScale;
                                  final double iconSize = 16 * buttonScale;

                                  return Row(
                                    children: [
                                      // CANCEL
                                      Expanded(
                                        child: SizedBox(
                                          height: height,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(radius),
                                              border: Border.all(
                                                color: Colors.grey.shade300,
                                                width: 1.2,
                                              ),
                                            ),
                                            child: Material(
                                              color: Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(radius),
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      radius,
                                                    ),
                                                onTap:
                                                    () => Navigator.pop(
                                                      dialogContext,
                                                    ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.close_rounded,
                                                      size: iconSize,
                                                      color: Colors.black,
                                                    ),
                                                    SizedBox(
                                                      width: 6 * buttonScale,
                                                    ),
                                                    Text(
                                                      "Cancel",
                                                      style: TextStyle(
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: textSize,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      SizedBox(width: 12 * buttonScale),

                                      // UPDATE
                                      Expanded(
                                        child: SizedBox(
                                          height: height,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.blue.shade700,
                                                  Colors.blue.shade900,
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(radius),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.blue
                                                      .withValues(alpha: 0.3),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Material(
                                              color: Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(radius),
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      radius,
                                                    ),
                                                onTap: () async {
                                                  if (_isProcessing) return;

                                                  setState(
                                                    () => _isProcessing = true,
                                                  );

                                                  final newPass =
                                                      newPasswordController.text
                                                          .trim();
                                                  final confirmPass =
                                                      confirmPasswordController
                                                          .text
                                                          .trim();

                                                  if (newPass.length < 6) {
                                                    showError(
                                                      "Password must be at least 6 characters",
                                                    );
                                                    setState(
                                                      () =>
                                                          _isProcessing = false,
                                                    );
                                                    return;
                                                  }

                                                  if (newPass != confirmPass) {
                                                    showError(
                                                      "Passwords do not match",
                                                    );
                                                    setState(
                                                      () =>
                                                          _isProcessing = false,
                                                    );
                                                    return;
                                                  }

                                                  final userIndex = usersBox
                                                      .values
                                                      .toList()
                                                      .indexOf(user);

                                                  final updatedUser = User(
                                                    name: user.name,
                                                    email: user.email,
                                                    phone: user.phone,
                                                    password: newPass,
                                                    role: user.role,
                                                    upiId: user.upiId,
                                                    imageUrl: user.imageUrl,
                                                  );

                                                  await usersBox.putAt(
                                                    userIndex,
                                                    updatedUser,
                                                  );

                                                  Navigator.pop(dialogContext);

                                                  showSuccess(
                                                    "Password updated successfully!",
                                                  );

                                                  if (mounted) {
                                                    setState(
                                                      () =>
                                                          _isProcessing = false,
                                                    );
                                                  }
                                                },
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.lock_reset_rounded,
                                                      size: iconSize,
                                                      color: Colors.white,
                                                    ),
                                                    SizedBox(
                                                      width: 6 * buttonScale,
                                                    ),
                                                    Text(
                                                      "Update Password",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: textSize,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ----------------------------------------------------------------------
  // UI
  // ----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: _isProcessing,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF3EE4D8),
                    Color(0xFF1FB5D0),
                    Color(0xFF0F73B8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: w * 0.08,
                    vertical: h * 0.04,
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: h * 0.015),
                      // 🌟 BizMate Brand Logo
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/images/bizmate_logo.JPG',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      SizedBox(height: h * 0.025),
                      Text(
                        isCreating ? "Join Us!" : "Welcome Back",
                        style: TextStyle(
                          fontSize: h * 0.035,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              offset: const Offset(0, 2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: h * 0.012),
                      Text(
                        isCreating
                            ? "Create your account"
                            : "Login to continue",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: h * 0.019,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              offset: const Offset(0, 1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: h * 0.035),

                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        child: Column(
                          children: [
                            if (isCreating)
                              TextField(
                                controller: fullNameController,
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                cursorColor: const Color(0xFF0F73B8),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: const Icon(
                                    Icons.person_outline,
                                    color: Color(0xFF0F73B8),
                                  ),
                                  hintText: "Full Name",
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                      color: Color(0xFF0F73B8),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  errorText:
                                      _isFullNameValid
                                          ? null
                                          : "Name must be at least 2 characters",
                                  errorStyle: const TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                            if (isCreating) SizedBox(height: h * 0.02),

                            if (isCreating)
                              DropdownButtonFormField<String>(
                                initialValue: selectedRole,
                                dropdownColor: Colors.white,
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Color(0xFF0F73B8),
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: const Icon(
                                    Icons.work_outline,
                                    color: Color(0xFF0F73B8),
                                  ),
                                  hintText: "Your Profession",
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                      color: Color(0xFF0F73B8),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                      color: Colors.redAccent,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                      color: Colors.redAccent,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                items:
                                    roles
                                        .map(
                                          (r) => DropdownMenuItem(
                                            value: r,
                                            child: Text(
                                              r,
                                              style: const TextStyle(
                                                color: Color(0xFF1E293B),
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                onChanged:
                                    (val) =>
                                        setState(() => selectedRole = val!),
                              ),

                            if (isCreating) SizedBox(height: h * 0.02),

                            if (isCreating)
                              TextField(
                                controller: phoneController,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                cursorColor: const Color(0xFF0F73B8),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: const Icon(
                                    Icons.phone_outlined,
                                    color: Color(0xFF0F73B8),
                                  ),
                                  hintText: "Phone Number",
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                      color: Color(0xFF0F73B8),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  errorText:
                                      _isPhoneValid
                                          ? null
                                          : "Enter a valid 10-digit phone number",
                                  errorStyle: const TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                            if (isCreating) SizedBox(height: h * 0.02),

                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              cursorColor: const Color(0xFF0F73B8),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  color: Color(0xFF0F73B8),
                                ),
                                hintText:
                                    isCreating ? "Email" : "Email or Phone",
                                hintStyle: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                    color: Color(0xFF0F73B8),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                errorText:
                                    _isEmailValid
                                        ? null
                                        : isCreating
                                        ? "Enter a valid email"
                                        : "Enter valid email / phone",
                                errorStyle: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            SizedBox(height: h * 0.02),

                            TextField(
                              controller: passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              cursorColor: const Color(0xFF0F73B8),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: Color(0xFF0F73B8),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: const Color(0xFF0F73B8),
                                  ),
                                  onPressed:
                                      () => setState(
                                        () =>
                                            _obscurePassword =
                                                !_obscurePassword,
                                      ),
                                ),
                                hintText: "Password",
                                hintStyle: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                    color: Color(0xFF0F73B8),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                errorText:
                                    _isPasswordValid
                                        ? null
                                        : "Password must be at least 6 characters",
                                errorStyle: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 🔥 Forgot Password button
                      if (!isCreating)
                        Padding(
                          padding: EdgeInsets.only(
                            top: 10 * scale,
                            right: 4 * scale,
                          ),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showResetPasswordDialog,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                              ),
                              child: Text(
                                "Forgot Password?",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14 * scale,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      offset: const Offset(0, 1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      SizedBox(height: h * 0.035),

                      // Login / Signup button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isCreating ? createAccount : login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0F73B8),
                            elevation: 6,
                            shadowColor: Colors.black.withValues(alpha: 0.3),
                            padding: EdgeInsets.symmetric(vertical: h * 0.02),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            isCreating ? "SIGN UP" : "LOGIN",
                            style: TextStyle(
                              fontSize: h * 0.02,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: const Color(0xFF0F73B8),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: h * 0.025),

                      TextButton(
                        onPressed: toggleMode,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: RichText(
                          text: TextSpan(
                            text:
                                isCreating
                                    ? "Already have an account? "
                                    : "Don’t have an account? ",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: h * 0.017,
                              fontWeight: FontWeight.w500,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  offset: const Offset(0, 1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            children: [
                              TextSpan(
                                text: isCreating ? "Login" : "Sign up",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

// ======================================================================
// 🔹 HELPER WIDGETS FOR MODERN PASSWORD DIALOG
// ======================================================================

class _PasswordStrengthIndicator extends StatefulWidget {
  final TextEditingController controller;

  const _PasswordStrengthIndicator(this.controller);

  @override
  State<_PasswordStrengthIndicator> createState() =>
      _PasswordStrengthIndicatorState();
}

class _PasswordStrengthIndicatorState
    extends State<_PasswordStrengthIndicator> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        final password = widget.controller.text;
        final strength = _calculatePasswordStrength(password);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Password Strength",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: strength >= 1 ? 1 : 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        gradient: _getStrengthGradient(strength),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _getStrengthText(strength),
              style: TextStyle(
                fontSize: 12,
                color: _getStrengthColor(strength),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  int _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    if (password.length < 6) return 1;

    bool hasUpper = password.contains(RegExp(r'[A-Z]'));
    bool hasLower = password.contains(RegExp(r'[a-z]'));
    bool hasDigit = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    int strength = 1;
    if (password.length >= 8) strength++;
    if (hasUpper && hasLower) strength++;
    if (hasDigit) strength++;
    if (hasSpecial) strength++;

    return strength.clamp(1, 4);
  }

  LinearGradient _getStrengthGradient(int strength) {
    switch (strength) {
      case 1:
        return LinearGradient(
          colors: [Colors.red.shade400, Colors.red.shade600],
        );
      case 2:
        return LinearGradient(
          colors: [Colors.orange.shade400, Colors.orange.shade600],
        );
      case 3:
        return LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        );
      case 4:
        return LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade600],
        );
      default:
        return LinearGradient(
          colors: [Colors.grey.shade400, Colors.grey.shade600],
        );
    }
  }

  String _getStrengthText(int strength) {
    switch (strength) {
      case 1:
        return "Weak";
      case 2:
        return "Fair";
      case 3:
        return "Good";
      case 4:
        return "Strong";
      default:
        return "Very Weak";
    }
  }

  Color _getStrengthColor(int strength) {
    switch (strength) {
      case 1:
        return Colors.red.shade600;
      case 2:
        return Colors.orange.shade600;
      case 3:
        return Colors.blue.shade600;
      case 4:
        return Colors.green.shade600;
      default:
        return Colors.grey.shade600;
    }
  }
}

// Modern Password Field Widget
class _ModernPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _ModernPasswordField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  @override
  State<_ModernPasswordField> createState() => _ModernPasswordFieldState();
}

class _ModernPasswordFieldState extends State<_ModernPasswordField> {
  bool _obscureText = true;
  double scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 12 * scale,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        SizedBox(height: 8 * scale),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
          ),
          child: TextField(
            controller: widget.controller,
            obscureText: _obscureText,
            style: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w500),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12 * scale,
                vertical: 12 * scale,
              ),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.grey.shade500,
                  size: 20 * scale,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Password Match Indicator
class _PasswordMatchIndicator extends StatefulWidget {
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;

  const _PasswordMatchIndicator(
    this.newPasswordController,
    this.confirmPasswordController,
  );

  @override
  State<_PasswordMatchIndicator> createState() =>
      _PasswordMatchIndicatorState();
}

class _PasswordMatchIndicatorState extends State<_PasswordMatchIndicator> {
  double scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.newPasswordController,
      builder: (context, value, child) {
        return ValueListenableBuilder(
          valueListenable: widget.confirmPasswordController,
          builder: (context, value, child) {
            final newPass = widget.newPasswordController.text;
            final confirmPass = widget.confirmPasswordController.text;

            if (confirmPass.isEmpty) return const SizedBox();

            final isMatch = newPass == confirmPass && newPass.isNotEmpty;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Row(
                children: [
                  Icon(
                    isMatch ? Icons.check_circle_rounded : Icons.error_rounded,
                    color:
                        isMatch ? Colors.green.shade500 : Colors.red.shade500,
                    size: 16 * scale,
                  ),
                  SizedBox(width: 6 * scale),
                  Text(
                    isMatch ? "Passwords match" : "Passwords don't match",
                    style: TextStyle(
                      fontSize: 10 * scale,
                      color:
                          isMatch ? Colors.green.shade600 : Colors.red.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
