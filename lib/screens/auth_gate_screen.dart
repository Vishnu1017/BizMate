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

  Future<bool> _isPasscodeEnabled(String email) async {
    final pass = await _storage.read(key: "passcode_$email");
    return pass != null && pass.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5F7FA), Color(0xFFE4E7EB), Color(0xFFD1D5DB)],
          ),
        ),
        child: Stack(
          children: [
            // Background elements
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF667EEA).withOpacity(0.1),
                      Color(0xFF764BA2).withOpacity(0.1),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFF093FB).withOpacity(0.1),
                      Color(0xFFF5576C).withOpacity(0.1),
                    ],
                  ),
                ),
              ),
            ),

            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Glass morphism card
                  Container(
                    width: 140,
                    height: 140,
                    margin: const EdgeInsets.only(bottom: 40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.8),
                          Colors.white.withOpacity(0.4),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 30,
                          offset: Offset(10, 10),
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.7),
                          blurRadius: 30,
                          offset: Offset(-10, -10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF667EEA).withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.shield_outlined,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  Text(
                    "Secure Access",
                    style: TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Verifying your identity",
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 40),

                  // Modern loading indicator
                  Container(
                    width: 80,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: Color(0xFFE2E8F0),
                    ),
                    child: Stack(
                      children: [
                        AnimatedContainer(
                          duration: Duration(milliseconds: 1500),
                          curve: Curves.easeInOut,
                          width: 80,
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: LinearGradient(
                              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                            ),
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

class _PasscodeCreationScreenState extends State<PasscodeCreationScreen>
    with SingleTickerProviderStateMixin {
  PasscodeType _selectedType = PasscodeType.numeric;
  int _numericLength = 4;
  final TextEditingController _alphanumericController = TextEditingController();
  List<String> _pinDigits = List.filled(6, '');
  bool _obscureAlphanumeric = true;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.98, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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

  Widget _buildAnimatedPinFields(BoxConstraints constraints) {
    final spacing = _numericLength == 6 ? 10.0 : 16.0;

    final maxWidth = constraints.maxWidth;
    final availableWidth = maxWidth - ((_numericLength - 1) * spacing) - 24;

    final double fieldSize = (availableWidth / _numericLength).clamp(
      52.0,
      70.0,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_numericLength, (index) {
            final isFilled = _pinDigits[index].isNotEmpty;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: fieldSize,
              height: fieldSize,
              margin: EdgeInsets.symmetric(horizontal: spacing / 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color:
                        isFilled
                            ? const Color(0xFF667EEA).withOpacity(0.35)
                            : Colors.grey.shade300,
                    blurRadius: isFilled ? 18 : 14,
                    offset: isFilled ? const Offset(0, 10) : const Offset(8, 8),
                  ),
                  const BoxShadow(
                    color: Colors.white,
                    blurRadius: 14,
                    offset: Offset(-8, -8),
                  ),
                ],
                gradient:
                    isFilled
                        ? const LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        )
                        : null,
              ),
              child: Center(
                child: TextField(
                  maxLength: 1,
                  obscureText: true,
                  obscuringCharacter: '•',
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    color: isFilled ? Colors.white : const Color(0xFF334155),
                    fontSize: fieldSize / 2.6,
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
                    } else if (value.isEmpty && index > 0) {
                      FocusScope.of(context).previousFocus();
                    }
                  },
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 30,
                  offset: Offset(15, 15),
                ),
                BoxShadow(
                  color: Colors.white,
                  blurRadius: 30,
                  offset: Offset(-15, -15),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTypeOption(
                      "Numeric",
                      Icons.pin_outlined,
                      PasscodeType.numeric,
                    ),
                    _buildTypeOption(
                      "Custom",
                      Icons.text_fields_outlined,
                      PasscodeType.alphanumeric,
                    ),
                  ],
                ),
                if (_selectedType == PasscodeType.numeric) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Color(0xFFE2E8F0), width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.format_list_numbered_rounded,
                          color: Color(0xFF667EEA),
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          "Length:",
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 12),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF667EEA).withOpacity(0.1),
                                Color(0xFF764BA2).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButton<int>(
                            value: _numericLength,
                            underline: Container(),
                            dropdownColor: Colors.white,
                            style: TextStyle(
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.w600,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 4,
                                child: Text("4 Digits"),
                              ),
                              DropdownMenuItem(
                                value: 6,
                                child: Text("6 Digits"),
                              ),
                            ],
                            onChanged:
                                (val) => setState(() => _numericLength = val!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypeOption(String title, IconData icon, PasscodeType type) {
    bool isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          gradient:
              isSelected
                  ? LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                  : LinearGradient(colors: [Colors.white, Color(0xFFF8FAFC)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Color(0xFF667EEA).withOpacity(0.4),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ]
                  : [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 15,
                      offset: Offset(8, 8),
                    ),
                    BoxShadow(
                      color: Colors.white,
                      blurRadius: 15,
                      offset: Offset(-8, -8),
                    ),
                  ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Color(0xFF667EEA),
              size: 28,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Color(0xFF334155),
                fontWeight: FontWeight.w600,
                fontSize: 14,
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5F7FA), Color(0xFFE4E7EB), Color(0xFFD1D5DB)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LayoutBuilder(
                  builder:
                      (context, constraints) => SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 40),
                            // Header
                            Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF667EEA),
                                        Color(0xFF764BA2),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(
                                          0xFF667EEA,
                                        ).withOpacity(0.4),
                                        blurRadius: 30,
                                        offset: Offset(0, 20),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.key_outlined,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  "Setup Passcode",
                                  style: TextStyle(
                                    color: Color(0xFF334155),
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Create a secure passcode for ${widget.user.email.split('@')[0]}",
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                            const SizedBox(height: 40),
                            _buildTypeSelector(),
                            const SizedBox(height: 40),
                            _selectedType == PasscodeType.numeric
                                ? _buildAnimatedPinFields(constraints)
                                : Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.shade300,
                                        blurRadius: 20,
                                        offset: Offset(10, 10),
                                      ),
                                      BoxShadow(
                                        color: Colors.white,
                                        blurRadius: 20,
                                        offset: Offset(-10, -10),
                                      ),
                                    ],
                                  ),
                                  child: TextField(
                                    controller: _alphanumericController,
                                    obscureText: _obscureAlphanumeric,
                                    style: TextStyle(
                                      color: Color(0xFF334155),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: "Enter custom passcode",
                                      hintStyle: TextStyle(
                                        color: Color(0xFF94A3B8),
                                      ),
                                      border: InputBorder.none,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureAlphanumeric
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: Color(0xFF667EEA),
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
                            const SizedBox(height: 50),
                            // Save button
                            MouseRegion(
                              onHover: (_) {},
                              child: GestureDetector(
                                onTap: _savePasscode,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                    horizontal: 40,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF667EEA),
                                        Color(0xFF764BA2),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(
                                          0xFF667EEA,
                                        ).withOpacity(0.4),
                                        blurRadius: 30,
                                        offset: Offset(0, 20),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        "Save Passcode",
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
                            const SizedBox(height: 60),
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

class _EnterPasscodeScreenState extends State<EnterPasscodeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _passcodeController = TextEditingController();
  String _errorMessage = '';
  PasscodeType _savedType = PasscodeType.numeric;
  int _numericLength = 4;
  List<String> _pinDigits = List.filled(6, '');
  bool _obscureAlphanumeric = true;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  late List<FocusNode> _pinFocusNodes;

  @override
  void initState() {
    super.initState();
    _pinFocusNodes = List.generate(6, (_) => FocusNode());
    _loadPasscodeType();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
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
      _shakeController.forward(from: 0);
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
      _shakeController.forward(from: 0);
    }
  }

  Widget _buildPinFields(BoxConstraints constraints) {
    final spacing = _numericLength == 6 ? 10.0 : 16.0;

    final maxWidth = constraints.maxWidth;
    final availableWidth = maxWidth - ((_numericLength - 1) * spacing) - 24;

    final double fieldSize = (availableWidth / _numericLength).clamp(
      52.0,
      70.0,
    );

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final offset =
            _errorMessage.isNotEmpty
                ? Offset(
                  16 *
                      _shakeAnimation.value *
                      (_shakeAnimation.value - 0.5).sign,
                  0,
                )
                : Offset.zero;

        return Transform.translate(
          offset: offset,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_numericLength, (index) {
                  final filled = _pinDigits[index].isNotEmpty;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: fieldSize,
                    height: fieldSize,
                    margin: EdgeInsets.symmetric(horizontal: spacing / 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color:
                              filled
                                  ? const Color(0xFF667EEA).withOpacity(0.35)
                                  : Colors.grey.shade300,
                          blurRadius: filled ? 20 : 14,
                          offset:
                              filled ? const Offset(0, 10) : const Offset(8, 8),
                        ),
                        const BoxShadow(
                          color: Colors.white,
                          blurRadius: 14,
                          offset: Offset(-8, -8),
                        ),
                      ],
                      gradient:
                          filled
                              ? const LinearGradient(
                                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                              )
                              : null,
                    ),
                    child: Center(
                      child: TextField(
                        focusNode: _pinFocusNodes[index],
                        maxLength: 1,
                        obscureText: true,
                        obscuringCharacter: '•',
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          color:
                              filled ? Colors.white : const Color(0xFF334155),
                          fontSize: fieldSize / 2.6,
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
                          } else if (value.isEmpty && index > 0) {
                            _pinFocusNodes[index - 1].requestFocus();
                          }

                          if (_errorMessage.isNotEmpty) {
                            setState(() => _errorMessage = '');
                          }
                        },
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  void _forgotPasscode() {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 50,
                    offset: Offset(0, 30),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFF5576C), Color(0xFFF093FB)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFF5576C).withOpacity(0.3),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Reset Passcode?",
                    style: TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "You'll need to create a new passcode.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Color(0xFFE2E8F0),
                            width: 2,
                          ),
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                          ),
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFF5576C), Color(0xFFF093FB)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFFF5576C).withOpacity(0.4),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: TextButton(
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
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                          ),
                          child: Text(
                            "Continue",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5F7FA), Color(0xFFE4E7EB), Color(0xFFD1D5DB)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LayoutBuilder(
                  builder:
                      (context, constraints) => SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 40),
                            // Header
                            Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF667EEA),
                                        Color(0xFF764BA2),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(
                                          0xFF667EEA,
                                        ).withOpacity(0.4),
                                        blurRadius: 30,
                                        offset: Offset(0, 20),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.lock_person_outlined,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  "Welcome Back",
                                  style: TextStyle(
                                    color: Color(0xFF334155),
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.user.email.split('@')[0],
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),

                            // Error message
                            if (_errorMessage.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(
                                  top: 20,
                                  bottom: 10,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Color(0xFFFECACA),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      color: Color(0xFFDC2626),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _errorMessage,
                                      style: TextStyle(
                                        color: Color(0xFF991B1B),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 20),

                            // Passcode input
                            _savedType == PasscodeType.numeric
                                ? _buildPinFields(constraints)
                                : Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.shade300,
                                        blurRadius: 20,
                                        offset: Offset(10, 10),
                                      ),
                                      BoxShadow(
                                        color: Colors.white,
                                        blurRadius: 20,
                                        offset: Offset(-10, -10),
                                      ),
                                    ],
                                  ),
                                  child: TextField(
                                    controller: _passcodeController,
                                    obscureText: _obscureAlphanumeric,
                                    style: TextStyle(
                                      color: Color(0xFF334155),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: "Enter passcode",
                                      hintStyle: TextStyle(
                                        color: Color(0xFF94A3B8),
                                      ),
                                      border: InputBorder.none,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureAlphanumeric
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: Color(0xFF667EEA),
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

                            const SizedBox(height: 40),

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
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF667EEA),
                                        Color(0xFF764BA2),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(
                                          0xFF667EEA,
                                        ).withOpacity(0.4),
                                        blurRadius: 30,
                                        offset: Offset(0, 20),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
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

                            const SizedBox(height: 24),

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
                                children: [
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

                            const SizedBox(height: 60),
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
}
