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
  bool _isLoggedIn = false;
  bool _obscurePassword = true;
  late AnimationController _controller;
  String selectedRole = 'None';

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
    final enabledFlag = prefs.getBool('${email}_passcodeEnabled');

    // If flag is null, default to true (for old users before flag existed)
    return enabledFlag ?? true;
  }

  // ----------------------------------------------------------------------
  // 🔥 LOGIN
  // ----------------------------------------------------------------------
  Future<void> login() async {
    if (_isLoggedIn) return;
    _isLoggedIn = true;

    final input = emailController.text.trim();
    final password = passwordController.text.trim();

    if (input.isEmpty) {
      showError("Please enter your email or phone number");
      _isLoggedIn = false;
      return;
    }

    if (password.isEmpty) {
      showError("Please enter your password");
      _isLoggedIn = false;
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
        _isLoggedIn = false;
        return;
      }

      // Password verification
      if (existsUser.password != password) {
        showError("Incorrect password");
        _isLoggedIn = false;
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
      _isLoggedIn = false;
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
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.purple.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_reset, size: 50, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
                    "Reset Password",
                    style: TextStyle(color: Colors.white, fontSize: 22),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Enter your email",
                      labelStyle: const TextStyle(color: Colors.white70),
                      errorText: _isResetEmailValid ? null : "Invalid email",
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white38),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _handlePasswordReset,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade700,
                    ),
                    child: const Text("Reset Password"),
                  ),
                ],
              ),
            ),
          ),
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

    // Find the user
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

    // Close email dialog
    Navigator.pop(context);

    // Open new password dialog
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            insetPadding: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.grey.shade100, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 40,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Icon
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade600,
                              Colors.purple.shade500,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Create New Password",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey.shade900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Secure your account with a new password",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Password Strength Indicator
                  _PasswordStrengthIndicator(newPasswordController),

                  const SizedBox(height: 20),

                  // New Password Field
                  _ModernPasswordField(
                    controller: newPasswordController,
                    label: "New Password",
                    hint: "Enter at least 6 characters",
                  ),

                  const SizedBox(height: 18),

                  // Confirm Password Field
                  _ModernPasswordField(
                    controller: confirmPasswordController,
                    label: "Confirm Password",
                    hint: "Re-enter your password",
                  ),

                  const SizedBox(height: 8),

                  // Password Match Indicator
                  _PasswordMatchIndicator(
                    newPasswordController,
                    confirmPasswordController,
                  ),

                  const SizedBox(height: 26),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.grey.shade100,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final newPass = newPasswordController.text.trim();
                            final confirmPass =
                                confirmPasswordController.text.trim();

                            if (newPass.length < 6) {
                              showError(
                                "Password must be at least 6 characters",
                              );
                              return;
                            }

                            if (newPass != confirmPass) {
                              showError("Passwords do not match");
                              return;
                            }

                            // Update password in Hive
                            final userIndex = usersBox.values.toList().indexOf(
                              user,
                            );

                            final updatedUser = User(
                              name: user.name,
                              email: user.email,
                              phone: user.phone,
                              password: newPass,
                              role: user.role,
                              upiId: user.upiId,
                              imageUrl: user.imageUrl,
                            );

                            await usersBox.putAt(userIndex, updatedUser);

                            Navigator.pop(context);
                            showSuccess("Password updated successfully!");
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            shadowColor: Colors.transparent,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                "Update Password",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.purple.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: w * 0.08,
              vertical: h * 0.05,
            ),
            child: Column(
              children: [
                SizedBox(height: h * 0.05),
                Text(
                  isCreating ? "Join Us!" : "Welcome Back",
                  style: TextStyle(
                    fontSize: h * 0.035,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: h * 0.015),
                Text(
                  isCreating ? "Create your account" : "Login to continue",
                  style: TextStyle(color: Colors.white70, fontSize: h * 0.018),
                ),
                SizedBox(height: h * 0.05),

                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    children: [
                      if (isCreating)
                        TextField(
                          controller: fullNameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Full Name",
                            labelStyle: const TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Colors.white54,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.white),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            errorText:
                                _isFullNameValid
                                    ? null
                                    : "Name must be at least 2 characters",
                          ),
                        ),

                      if (isCreating) SizedBox(height: h * 0.025),

                      if (isCreating)
                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          dropdownColor: Colors.blue.shade900,
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white,
                          ),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Your Profession",
                            labelStyle: const TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Colors.white54,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          items:
                              roles
                                  .map(
                                    (r) => DropdownMenuItem(
                                      value: r,
                                      child: Text(r),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (val) => setState(() => selectedRole = val!),
                        ),

                      if (isCreating) SizedBox(height: h * 0.025),

                      if (isCreating)
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Phone Number",
                            labelStyle: const TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Colors.white54,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.white),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            errorText:
                                _isPhoneValid
                                    ? null
                                    : "Enter a valid 10-digit phone number",
                          ),
                        ),

                      if (isCreating) SizedBox(height: h * 0.025),

                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: isCreating ? "Email" : "Email or Phone",
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white54),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          errorText:
                              _isEmailValid
                                  ? null
                                  : isCreating
                                  ? "Enter a valid email"
                                  : "Enter valid email / phone",
                        ),
                      ),

                      SizedBox(height: h * 0.025),

                      TextField(
                        controller: passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Password",
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(
                            Icons.lock,
                            color: Colors.white70,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.white70,
                            ),
                            onPressed:
                                () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white54),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          errorText:
                              _isPasswordValid
                                  ? null
                                  : "Password must be at least 6 characters",
                        ),
                      ),
                    ],
                  ),
                ),

                // 🔥 Forgot Password button
                if (!isCreating)
                  Padding(
                    padding: const EdgeInsets.only(top: 10, right: 4),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showResetPasswordDialog,
                        child: const Text(
                          "Forgot Password?",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                    ),
                  ),

                SizedBox(height: h * 0.04),

                // Login / Signup button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isCreating ? createAccount : login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade700,
                      padding: EdgeInsets.symmetric(vertical: h * 0.02),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      isCreating ? "SIGN UP" : "LOGIN",
                      style: TextStyle(
                        fontSize: h * 0.02,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: h * 0.03),

                TextButton(
                  onPressed: toggleMode,
                  child: RichText(
                    text: TextSpan(
                      text:
                          isCreating
                              ? "Already have an account? "
                              : "Don’t have an account? ",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: h * 0.016,
                      ),
                      children: [
                        TextSpan(
                          text: isCreating ? "Login" : "Sign up",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: h * 0.02,
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
          ),
          child: TextField(
            controller: widget.controller,
            obscureText: _obscureText,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
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
                  size: 20,
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
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isMatch ? "Passwords match" : "Passwords don't match",
                    style: TextStyle(
                      fontSize: 12,
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
