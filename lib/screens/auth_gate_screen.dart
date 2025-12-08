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

  // ✅ NEW: helper to check if passcode is enabled
  Future<bool> _isPasscodeEnabled(String email) async {
    final pass = await _storage.read(key: "passcode_$email");
    return pass != null && pass.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    Future.microtask(() async {
      // NEW LOGIC – respects disable switch
      final isEnabled = await _isPasscodeEnabled(user.email);

      if (!isEnabled) {
        // 🔥 Passcode disabled → skip AuthGate → go to main home
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

      // OLD LOGIC – unchanged
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

    return Scaffold(
      backgroundColor: Colors.blue.shade900,
      body: const Center(child: CircularProgressIndicator(color: Colors.white)),
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

  Widget _buildAnimatedPinFields(BoxConstraints constraints) {
    double totalSpacing = (_numericLength - 1) * 12;
    double availableWidth = constraints.maxWidth - totalSpacing - 40;
    double fieldSize = availableWidth / _numericLength;
    fieldSize = fieldSize > 80 ? 80 : (fieldSize < 50 ? 50 : fieldSize);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_numericLength, (index) {
          bool isFilled = _pinDigits[index].isNotEmpty;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: fieldSize,
            height: fieldSize,
            margin: EdgeInsets.symmetric(horizontal: fieldSize / 22),
            decoration: BoxDecoration(
              gradient:
                  isFilled
                      ? LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade700],
                      )
                      : LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
              borderRadius: BorderRadius.circular(fieldSize / 5),
              border: Border.all(
                color:
                    isFilled
                        ? Colors.white.withOpacity(0.8)
                        : Colors.white.withOpacity(0.3),
              ),
            ),
            child: Center(
              child: TextField(
                obscureText: true,
                obscuringCharacter: '•',
                maxLength: 1,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fieldSize / 2.2,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration(
                  counterText: "",
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() => _pinDigits[index] = value);
                  if (value.isNotEmpty && index < _numericLength - 1) {
                    FocusScope.of(context).nextFocus();
                  }
                  if (value.isEmpty && index > 0) {
                    FocusScope.of(context).previousFocus();
                  }
                },
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTypeOption("Numeric", Icons.numbers, PasscodeType.numeric),
              _buildTypeOption(
                "Alphanumeric",
                Icons.text_fields,
                PasscodeType.alphanumeric,
              ),
            ],
          ),
          if (_selectedType == PasscodeType.numeric) ...[
            const SizedBox(height: 16),
            DropdownButton<int>(
              value: _numericLength,
              dropdownColor: Colors.blue.shade800,
              style: const TextStyle(color: Colors.white),
              items: const [
                DropdownMenuItem(value: 4, child: Text("4 Digits")),
                DropdownMenuItem(value: 6, child: Text("6 Digits")),
              ],
              onChanged: (val) => setState(() => _numericLength = val!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeOption(String title, IconData icon, PasscodeType type) {
    bool isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient:
              isSelected
                  ? LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                  )
                  : LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.05),
                      Colors.white.withOpacity(0.02),
                    ],
                  ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade900,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: LayoutBuilder(
                builder:
                    (context, constraints) => SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          const Icon(
                            Icons.fingerprint,
                            size: 60,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "Create Your Passcode",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildTypeSelector(),
                          const SizedBox(height: 20),
                          _selectedType == PasscodeType.numeric
                              ? _buildAnimatedPinFields(constraints)
                              : TextField(
                                controller: _alphanumericController,
                                obscureText: _obscureAlphanumeric,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: "Enter Passcode",
                                  labelStyle: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureAlphanumeric
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: Colors.white70,
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
                          const SizedBox(height: 30),
                          ElevatedButton(
                            onPressed: _savePasscode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blue.shade900,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 40,
                              ),
                            ),
                            child: const Text(
                              "Save Passcode",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 40),
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
        _errorMessage = 'Incorrect passcode';
      });
    }
  }

  Widget _buildPinFields(BoxConstraints constraints) {
    final spacing = _numericLength == 6 ? 6.0 : 12.0;
    final availableWidth =
        constraints.maxWidth - ((_numericLength - 1) * spacing) - 32;

    final double fieldSize =
        ((availableWidth / _numericLength).clamp(48.0, 72.0)).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_numericLength, (index) {
          final filled = _pinDigits[index].isNotEmpty;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: fieldSize,
            height: fieldSize,
            margin: EdgeInsets.symmetric(horizontal: spacing / 2),
            decoration: BoxDecoration(
              gradient:
                  filled
                      ? LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade700],
                      )
                      : LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
              borderRadius: BorderRadius.circular(fieldSize / 5),
              border: Border.all(
                color:
                    filled
                        ? Colors.white.withOpacity(0.8)
                        : Colors.white.withOpacity(0.3),
              ),
            ),
            child: TextField(
              focusNode: _pinFocusNodes[index],
              obscureText: true,
              obscuringCharacter: '•',
              maxLength: 1,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                color: Colors.white,
                fontSize: fieldSize / 2.2,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                counterText: "",
                border: InputBorder.none,
              ),
              onChanged: (value) {
                setState(() => _pinDigits[index] = value);

                if (value.isNotEmpty && index < _numericLength - 1) {
                  _pinFocusNodes[index + 1].requestFocus();
                }

                if (value.isEmpty && index > 0) {
                  _pinFocusNodes[index - 1].requestFocus();
                }
              },
            ),
          );
        }),
      ),
    );
  }

  void _forgotPasscode() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.blue.shade800,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              "Reset Passcode?",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              "This will create a new passcode. Your old passcode will be lost.",
              style: TextStyle(color: Colors.white.withOpacity(0.8)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.white70),
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
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue.shade900,
                ),
                child: const Text("Continue"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade900,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: LayoutBuilder(
                builder:
                    (context, constraints) => SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          const Icon(
                            Icons.lock_outline,
                            size: 60,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "Welcome Back",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                _errorMessage,
                                style: TextStyle(color: Colors.red.shade300),
                              ),
                            ),
                          _savedType == PasscodeType.numeric
                              ? _buildPinFields(constraints)
                              : TextField(
                                controller: _passcodeController,
                                obscureText: _obscureAlphanumeric,
                                style: const TextStyle(color: Colors.white),
                              ),
                          const SizedBox(height: 30),
                          ElevatedButton(
                            onPressed: _verifyPasscode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blue.shade900,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 40,
                              ),
                            ),
                            child: const Text(
                              "Unlock",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: _forgotPasscode,
                            child: const Text(
                              "Forgot Passcode?",
                              style: TextStyle(color: Colors.white70),
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
  }
}
