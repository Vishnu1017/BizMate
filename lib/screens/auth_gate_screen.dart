import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bizmate/models/user_model.dart';
import 'package:bizmate/screens/nav_bar_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final _storage = FlutterSecureStorage(
  aOptions: const AndroidOptions(encryptedSharedPreferences: true),
);

enum PasscodeType { numeric, alphanumeric }

// A global max width so forms look good on tablets / web.
const double kMaxFormWidth = 480;

class AuthGateScreen extends StatelessWidget {
  final User user;
  final String userPhone;
  final String userEmail;

  const AuthGateScreen({
    super.key,
    required this.user,
    required this.userPhone,
    required this.userEmail,
  });

  Future<bool> _isPasscodeEnabled(String email) async {
    final pass = await _storage.read(key: "passcode_$email");
    return pass != null && pass.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    // Auth redirection logic (unchanged)
    Future.microtask(() async {
      final isEnabled = await _isPasscodeEnabled(user.email);

      if (!isEnabled) {
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
        return;
      }

      final key = "passcode_${user.email}";
      final savedPasscode = await _storage.read(key: key);

      if (savedPasscode == null || savedPasscode.isEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) =>
                    PasscodeCreationScreen(user: user, secureStorage: _storage),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => EnterPasscodeScreen(user: user, secureStorage: _storage),
          ),
        );
      }
    });

    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5F7FA), Color(0xFFE4E7EB), Color(0xFFD1D5DB)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450, minWidth: 280),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: screenHeight * 0.1),
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF667EEA).withOpacity(0.3),
                            blurRadius: 25,
                            spreadRadius: 2,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      "Secure Access",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF334155),
                        fontSize: responsiveTextSize(context, 28, 24),
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Verifying your identity",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF64748B),
                        fontSize: responsiveTextSize(context, 16, 14),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: 80,
                      child: LinearProgressIndicator(
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF667EEA),
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.1),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// -----------------------------------------------------
///              PASSCODE CREATION SCREEN
/// -----------------------------------------------------

class PasscodeCreationScreen extends StatefulWidget {
  final User user;
  final FlutterSecureStorage secureStorage;

  const PasscodeCreationScreen({
    super.key,
    required this.user,
    required this.secureStorage,
  });

  @override
  State<PasscodeCreationScreen> createState() => _PasscodeCreationScreenState();
}

class _PasscodeCreationScreenState extends State<PasscodeCreationScreen> {
  PasscodeType _selectedType = PasscodeType.numeric;
  int _numericLength = 4;
  final TextEditingController _alphanumericController = TextEditingController();
  List<String> _pinDigits = List.filled(6, '');
  bool _obscureAlphanumeric = true;
  late List<FocusNode> _pinFocusNodes;
  double scale = 1.0;

  @override
  void initState() {
    super.initState();
    _pinFocusNodes = List.generate(6, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final f in _pinFocusNodes) {
      f.dispose();
    }
    _alphanumericController.dispose();
    super.dispose();
  }

  // Helper function for responsive field sizing (fixed for small phones)
  double _getFieldSize(BuildContext context, int length) {
    final screenWidth = MediaQuery.of(context).size.width;
    const padding = 40.0;
    final totalSpacing = (length - 1) * 12.0;
    final availableWidth = screenWidth - padding - totalSpacing;
    final calculatedSize = availableWidth / length;

    // Clamp between min and max sizes, min tuned so 6 digits fit on 320px width
    return calculatedSize.clamp(32.0, 70.0);
  }

  Future<void> _savePasscode() async {
    String passcode;

    if (_selectedType == PasscodeType.numeric) {
      passcode = _pinDigits.take(_numericLength).join();
      if (passcode.length != _numericLength) {
        AppSnackBar.showError(
          context,
          message:
              "Please enter exactly $_numericLength digits for the numeric passcode",
          duration: const Duration(seconds: 2),
        );
        return;
      }
    } else {
      passcode = _alphanumericController.text.trim();
      if (passcode.length < 6) {
        AppSnackBar.showError(
          context,
          message: "Alphanumeric passcode must be at least 6 characters",
          duration: const Duration(seconds: 2),
        );
        return;
      }
    }

    final key = 'passcode_${widget.user.email}';
    await widget.secureStorage.write(key: key, value: passcode);
    await widget.secureStorage.write(
      key: 'passcode_type_${widget.user.email}',
      value: _selectedType.name,
    );

    final check = await widget.secureStorage.read(key: key);

    if (check != null && check == passcode) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => NavBarPage(
                user: widget.user,
                userPhone: widget.user.phone,
                userEmail: widget.user.email,
              ),
        ),
      );
    } else {
      AppSnackBar.showError(
        context,
        message: "Failed to save passcode",
        duration: const Duration(seconds: 2),
      );
    }
  }

  Widget _buildPinFields() {
    final fieldSize = _getFieldSize(context, _numericLength);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: max(16, MediaQuery.of(context).size.width * 0.05),
      ),
      child: Column(
        children: [
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_numericLength, (index) {
              final isFilled = _pinDigits[index].isNotEmpty;

              return SizedBox(
                width: fieldSize,
                height: fieldSize,
                child: GestureDetector(
                  onTap: () {
                    FocusScope.of(context).requestFocus(_pinFocusNodes[index]);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(fieldSize * 0.3),
                      boxShadow: [
                        BoxShadow(
                          color:
                              isFilled
                                  ? const Color(0xFF667EEA).withOpacity(0.3)
                                  : Colors.grey.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.8),
                          blurRadius: 10,
                          offset: const Offset(-5, -5),
                        ),
                      ],
                      gradient:
                          isFilled
                              ? const LinearGradient(
                                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                              : null,
                      border: Border.all(
                        color:
                            isFilled
                                ? Colors.transparent
                                : Colors.grey.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: TextField(
                        focusNode: _pinFocusNodes[index],
                        maxLength: 1,
                        obscureText: true,
                        obscuringCharacter: '●',
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          color:
                              isFilled ? Colors.white : const Color(0xFF334155),
                          fontSize: fieldSize * 0.4,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: const InputDecoration(
                          counterText: "",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (value) {
                          setState(() => _pinDigits[index] = value);

                          if (value.isNotEmpty && index < _numericLength - 1) {
                            FocusScope.of(
                              context,
                            ).requestFocus(_pinFocusNodes[index + 1]);
                          }
                          if (value.isEmpty && index > 0) {
                            FocusScope.of(
                              context,
                            ).requestFocus(_pinFocusNodes[index - 1]);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Text(
            "Enter $_numericLength-digit passcode",
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: EdgeInsets.symmetric(
        horizontal: max(16, MediaQuery.of(context).size.width * 0.05),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Select Passcode Type",
            style: TextStyle(
              color: Color(0xFF334155),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTypeOption(
                  "Numeric",
                  Icons.numbers,
                  PasscodeType.numeric,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTypeOption(
                  "Alphanumeric",
                  Icons.text_fields,
                  PasscodeType.alphanumeric,
                ),
              ),
            ],
          ),
          if (_selectedType == PasscodeType.numeric) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Passcode Length",
                    style: TextStyle(
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButton<int>(
                      value: _numericLength,
                      underline: Container(),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Color(0xFF64748B),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 4,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text("4 Digits"),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 6,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text("6 Digits"),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _numericLength = value!;
                          _pinDigits = List.filled(6, '');
                          for (var node in _pinFocusNodes) {
                            node.unfocus();
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeOption(String title, IconData icon, PasscodeType type) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF667EEA) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF667EEA) : const Color(0xFFE2E8F0),
            width: 2,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: const Color(0xFF667EEA).withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ]
                  : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF334155),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: screenHeight),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF5F7FA),
                    Color(0xFFE4E7EB),
                    Color(0xFFD1D5DB),
                  ],
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: kMaxFormWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: screenHeight * 0.05),
                      // Header
                      Container(
                        width: min(80, screenWidth * 0.18),
                        height: min(80, screenWidth * 0.18),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          ),
                        ),
                        child: Icon(
                          Icons.key,
                          color: Colors.white,
                          size: min(36, screenWidth * 0.08),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Setup Passcode",
                        style: TextStyle(
                          color: const Color(0xFF334155),
                          fontSize: responsiveTextSize(context, 28, 22),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          "Create a secure passcode for your account",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.05),
                      _buildTypeSelector(),
                      SizedBox(height: screenHeight * 0.04),
                      if (_selectedType == PasscodeType.numeric)
                        _buildPinFields()
                      else
                        Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: max(20, screenWidth * 0.08),
                          ),
                          child: TextField(
                            controller: _alphanumericController,
                            obscureText: _obscureAlphanumeric,
                            decoration: InputDecoration(
                              labelText: "Enter Custom Passcode",
                              labelStyle: const TextStyle(
                                color: Color(0xFF64748B),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF667EEA),
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureAlphanumeric
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: const Color(0xFF64748B),
                                ),
                                onPressed:
                                    () => setState(
                                      () =>
                                          _obscureAlphanumeric =
                                              !_obscureAlphanumeric,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      SizedBox(height: screenHeight * 0.05),
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: max(20, screenWidth * 0.08),
                        ),
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _savePasscode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667EEA),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            shadowColor: const Color(
                              0xFF667EEA,
                            ).withOpacity(0.3),
                          ),
                          child: const Text(
                            "Save Passcode",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.1),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// -----------------------------------------------------
///                ENTER PASSCODE SCREEN
/// -----------------------------------------------------

class EnterPasscodeScreen extends StatefulWidget {
  final User user;
  final FlutterSecureStorage secureStorage;

  const EnterPasscodeScreen({
    super.key,
    required this.user,
    required this.secureStorage,
  });

  @override
  State<EnterPasscodeScreen> createState() => _EnterPasscodeScreenState();
}

class _EnterPasscodeScreenState extends State<EnterPasscodeScreen> {
  final TextEditingController _passcodeController = TextEditingController();
  String _errorMessage = '';
  PasscodeType _savedType = PasscodeType.numeric;
  int _numericLength = 4;
  List<String> _pinDigits = List.filled(6, '');
  bool _obscureAlphanumeric = true;
  late List<FocusNode> _pinFocusNodes;

  double scale = 1.0;
  @override
  void initState() {
    super.initState();
    _pinFocusNodes = List.generate(6, (_) => FocusNode());
    _loadPasscodeType();
  }

  @override
  void dispose() {
    for (final f in _pinFocusNodes) {
      f.dispose();
    }
    _passcodeController.dispose();
    super.dispose();
  }

  // Helper function for responsive field sizing (same fix as creation)
  double _getFieldSize(BuildContext context, int length) {
    final screenWidth = MediaQuery.of(context).size.width;
    const padding = 40.0;
    final totalSpacing = (length - 1) * 12.0;
    final availableWidth = screenWidth - padding - totalSpacing;
    final calculatedSize = availableWidth / length;

    return calculatedSize.clamp(32.0, 70.0);
  }

  Future<void> _loadPasscodeType() async {
    final typeStr = await widget.secureStorage.read(
      key: 'passcode_type_${widget.user.email}',
    );

    if (typeStr == PasscodeType.alphanumeric.name) {
      setState(() => _savedType = PasscodeType.alphanumeric);
    } else {
      final pass = await widget.secureStorage.read(
        key: 'passcode_${widget.user.email}',
      );
      if (pass != null) {
        setState(() {
          _savedType = PasscodeType.numeric;
          _numericLength = pass.length;
          _pinDigits = List.filled(6, '');
        });
      }
    }
  }

  Future<void> _verifyPasscode() async {
    final key = 'passcode_${widget.user.email}';
    final savedPasscode = await widget.secureStorage.read(key: key);

    if (savedPasscode == null || savedPasscode.isEmpty) return;

    final enteredPass =
        _savedType == PasscodeType.numeric
            ? _pinDigits.take(_numericLength).join()
            : _passcodeController.text.trim();

    if (enteredPass.length != savedPasscode.length) {
      setState(() {
        _errorMessage =
            "Passcode must be ${savedPasscode.length} characters long";
      });
      return;
    }

    if (enteredPass == savedPasscode) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => NavBarPage(
                user: widget.user,
                userPhone: widget.user.phone,
                userEmail: widget.user.email,
              ),
        ),
      );
    } else {
      setState(() {
        _errorMessage = 'Incorrect passcode. Please try again.';
      });
    }
  }

  Widget _buildPinFields() {
    final fieldSize = _getFieldSize(context, _numericLength);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: max(16, MediaQuery.of(context).size.width * 0.05),
      ),
      child: Column(
        children: [
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_numericLength, (index) {
              final isFilled = _pinDigits[index].isNotEmpty;

              return SizedBox(
                width: fieldSize,
                height: fieldSize,
                child: GestureDetector(
                  onTap: () {
                    FocusScope.of(context).requestFocus(_pinFocusNodes[index]);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(fieldSize * 0.3),
                      boxShadow: [
                        BoxShadow(
                          color:
                              isFilled
                                  ? const Color(0xFF667EEA).withOpacity(0.3)
                                  : Colors.grey.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.8),
                          blurRadius: 10,
                          offset: const Offset(-5, -5),
                        ),
                      ],
                      gradient:
                          isFilled
                              ? const LinearGradient(
                                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                              : null,
                      border: Border.all(
                        color:
                            isFilled
                                ? Colors.transparent
                                : Colors.grey.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: TextField(
                        focusNode: _pinFocusNodes[index],
                        maxLength: 1,
                        obscureText: true,
                        obscuringCharacter: '●',
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          color:
                              isFilled ? Colors.white : const Color(0xFF334155),
                          fontSize: fieldSize * 0.4,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: const InputDecoration(
                          counterText: "",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (value) {
                          setState(() => _pinDigits[index] = value);

                          if (value.isNotEmpty && index < _numericLength - 1) {
                            FocusScope.of(
                              context,
                            ).requestFocus(_pinFocusNodes[index + 1]);
                          }
                          if (value.isEmpty && index > 0) {
                            FocusScope.of(
                              context,
                            ).requestFocus(_pinFocusNodes[index - 1]);
                          }

                          // Clear error when user starts typing
                          if (_errorMessage.isNotEmpty) {
                            setState(() => _errorMessage = '');
                          }
                        },
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Text(
            "Enter your $_numericLength-digit passcode",
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _forgotPasscode() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth > 600 ? 420 : screenWidth * 0.9,
            ),
            child: AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.help_outline,
                    color: Color(0xFFF59E0B),
                    size: 14 * scale,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Reset Passcode?",
                      style: TextStyle(
                        color: const Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                        fontSize: 12 * scale,
                      ),
                    ),
                  ),
                ],
              ),
              content: Text(
                "You'll need to create a new passcode. Your old passcode will be permanently deleted.",
                style: TextStyle(
                  color: Color(0xFF64748B),
                  height: 1.4,
                  fontSize: 10 * scale,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => PasscodeCreationScreen(
                              user: widget.user,
                              secureStorage: widget.secureStorage,
                            ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667EEA),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Continue",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: screenHeight),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF5F7FA),
                    Color(0xFFE4E7EB),
                    Color(0xFFD1D5DB),
                  ],
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: kMaxFormWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: screenHeight * 0.1),
                      // Header
                      Container(
                        width: min(80, screenWidth * 0.18),
                        height: min(80, screenWidth * 0.18),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          ),
                        ),
                        child: Icon(
                          Icons.lock,
                          color: Colors.white,
                          size: min(36, screenWidth * 0.08),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Welcome Back",
                        style: TextStyle(
                          color: const Color(0xFF334155),
                          fontSize: responsiveTextSize(context, 28, 22),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.user.name.split('@')[0],
                        style: TextStyle(
                          color: const Color(0xFF64748B),
                          fontSize: responsiveTextSize(context, 16, 14),
                        ),
                      ),

                      // Error message
                      if (_errorMessage.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 20),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFFECACA),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Color(0xFFDC2626),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage,
                                    style: const TextStyle(
                                      color: Color(0xFF991B1B),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      SizedBox(height: screenHeight * 0.05),

                      // Passcode input
                      if (_savedType == PasscodeType.numeric)
                        _buildPinFields()
                      else
                        Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: max(20, screenWidth * 0.08),
                          ),
                          child: TextField(
                            controller: _passcodeController,
                            obscureText: _obscureAlphanumeric,
                            decoration: InputDecoration(
                              labelText: "Enter Passcode",
                              labelStyle: const TextStyle(
                                color: Color(0xFF64748B),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF667EEA),
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureAlphanumeric
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: const Color(0xFF64748B),
                                ),
                                onPressed:
                                    () => setState(
                                      () =>
                                          _obscureAlphanumeric =
                                              !_obscureAlphanumeric,
                                    ),
                              ),
                            ),
                          ),
                        ),

                      SizedBox(height: screenHeight * 0.06),

                      // Unlock button
                      MouseRegion(
                        onHover: (_) {},
                        child: GestureDetector(
                          onTap: _verifyPasscode,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 40,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF667EEA,
                                  ).withOpacity(0.4),
                                  blurRadius: 30,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.lock_open_outlined,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "Unlock Account",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Forgot passcode
                      TextButton(
                        onPressed: _forgotPasscode,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.help_outline_rounded,
                              color: Color(0xFF64748B),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Forgot Passcode?",
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.1),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Helper function for responsive text sizing
double responsiveTextSize(BuildContext context, double desktop, double mobile) {
  final width = MediaQuery.of(context).size.width;

  // Basic breakpoint logic
  if (width >= 900) {
    // large tablet / web
    return desktop;
  } else if (width >= 600) {
    // small tablet
    return (desktop + mobile) / 2;
  } else {
    // phones
    return mobile;
  }
}

// Helper function to get min value
double min(double a, double b) => a < b ? a : b;

// Helper function to get max value
double max(double a, double b) => a > b ? a : b;
