// lib/main.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:bizmate/models/customer_model.dart';
import 'package:bizmate/models/payment.dart';
import 'package:bizmate/models/product.dart';
import 'package:bizmate/models/rental_item.dart';
import 'package:bizmate/models/rental_sale_model.dart';
import 'package:bizmate/models/sale.dart';
import 'package:bizmate/models/user_model.dart';
import 'package:bizmate/screens/auth_gate_screen.dart';
import 'package:bizmate/screens/login_screen.dart';
import 'package:bizmate/screens/nav_bar_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/responsive.dart';

/// ----------------------------------------------------------------
/// ENTRY POINT
/// ----------------------------------------------------------------
Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    // ✅ GLOBAL EDGE-TO-EDGE (BEST PRACTICE)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Optional polish
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    await _initializeHive();
    await _initializeDefaultProfileImage();

    runApp(const MyApp());
  } catch (error, stackTrace) {
    debugPrint('App initialization failed: $error');
    debugPrint('Stack trace: $stackTrace');

    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Failed to initialize app. Please restart or contact support.',
            ),
          ),
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------
/// HIVE INITIALIZATION
/// ----------------------------------------------------------------
Future<void> _initializeHive() async {
  try {
    // Initialize Hive and register adapters
    await Hive.initFlutter();

    // ensure hive uses application documents if available
    final appDocDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocDir.path);

    _registerAdapters();

    // Open required boxes safely
    await Future.wait([
      _openBoxSafely<User>('users'),
      _openBoxSafely<Sale>('sales'),
      _openBoxSafely<Product>('products'),
      _openBoxSafely<Payment>('payments'),
      _openBoxSafely<RentalItem>('rental_items'),
      _openBoxSafely<CustomerModel>('customers'),
      _openBoxSafely<RentalSaleModel>('rental_sales'),
    ]);
  } catch (e) {
    debugPrint('Hive initialization error: $e');
    rethrow;
  }
}

void _registerAdapters() {
  _registerAdapter<User>(0, UserAdapter());
  _registerAdapter<Sale>(1, SaleAdapter());
  _registerAdapter<Product>(2, ProductAdapter());
  _registerAdapter<Payment>(3, PaymentAdapter());
  _registerAdapter<RentalItem>(4, RentalItemAdapter());
  _registerAdapter<CustomerModel>(5, CustomerModelAdapter());
  _registerAdapter<RentalSaleModel>(6, RentalSaleModelAdapter());
}

void _registerAdapter<T>(int typeId, TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(typeId)) {
    Hive.registerAdapter<T>(adapter);
  }
}

Future<Box<T>> _openBoxSafely<T>(String name) async {
  try {
    return await Hive.openBox<T>(name);
  } catch (e) {
    debugPrint('Failed to open box $name: $e');
    // Try to recover by deleting and reopening
    try {
      await Hive.deleteBoxFromDisk(name);
    } catch (deleteError) {
      debugPrint('Failed to delete box $name: $deleteError');
    }
    return await Hive.openBox<T>(name);
  }
}

/// ----------------------------------------------------------------
/// DEFAULT PROFILE IMAGE INITIALIZATION
/// ----------------------------------------------------------------
Future<void> _initializeDefaultProfileImage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profileImagePath');

    if (imagePath == null || !(await File(imagePath).exists())) {
      final byteData = await rootBundle.load('assets/images/bizmate_logo.JPG');
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/default_logo.jpg');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await prefs.setString('profileImagePath', file.path);
    }
  } catch (e) {
    debugPrint('Default image initialization failed: $e');
  }
}

/// ----------------------------------------------------------------
/// IMPORTANT: KEEP THIS FUNCTION (USER REQUEST)
/// ----------------------------------------------------------------
// Future<void> _deleteAllHiveBoxes() async {
//   final List<String> boxNames = [
//     'users',
//     'sales',
//     'products',
//     'payments',
//     'rental_items',
//     'customers',
//     'rental_sales',
//   ];

//   for (var boxName in boxNames) {
//     try {
//       if (await Hive.boxExists(boxName)) {
//         if (Hive.isBoxOpen(boxName)) {
//           await Hive.box(boxName).close();
//         }
//         await Hive.deleteBoxFromDisk(boxName);
//         debugPrint('Deleted Hive box: $boxName');
//       }
//     } catch (e) {
//       debugPrint('Error deleting Hive box $boxName: $e');
//     }
//   }
// }

/// ----------------------------------------------------------------
/// APP WIDGET
/// ----------------------------------------------------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Responsive.init(context);
        });

        return const MaterialApp(
          title: 'BizMate',
          debugShowCheckedModeBanner: false,
          home: CustomSplashScreen(),
        );
      },
    );
  }
}

/// ----------------------------------------------------------------
/// SPLASH SCREEN
/// ----------------------------------------------------------------
class CustomSplashScreen extends StatefulWidget {
  const CustomSplashScreen({super.key});

  @override
  State<CustomSplashScreen> createState() => _CustomSplashScreenState();
}

class _CustomSplashScreenState extends State<CustomSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  late final Animation<double> _floatAnimation;
  Timer? _navTimer;
  bool _navigated = false;

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  void initState() {
    super.initState();

    // ✅ Modern animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    _floatAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
      ),
    );

    _controller.repeat(reverse: true);

    // ✅ Navigation after splash
    _navTimer = Timer(const Duration(seconds: 3), _checkAndNavigate);
  }

  Future<void> _checkAndNavigate() async {
    if (_navigated) return;
    _navigated = true;

    try {
      // ✅ 1. SESSION
      if (!Hive.isBoxOpen('session')) {
        await Hive.openBox('session');
      }
      final sessionBox = Hive.box('session');
      final email = sessionBox.get('currentUserEmail');

      if (!mounted) return;

      if (email == null || email.toString().trim().isEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      // ✅ 2. USER
      if (!Hive.isBoxOpen('users')) {
        await Hive.openBox<User>('users');
      }

      final usersBox = Hive.box<User>('users');
      User? user;

      try {
        user = usersBox.values.firstWhere(
          (u) =>
              u.email.trim().toLowerCase() ==
              email.toString().trim().toLowerCase(),
        );
      } catch (_) {
        user = null;
      }

      if (user == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      final loggedInUser = user;

      // ✅ 3. ✅ SINGLE SOURCE OF TRUTH
      final prefs = await SharedPreferences.getInstance();

      final bool toggleEnabled =
          prefs.getBool('${loggedInUser.email}_passcodeEnabled') ?? false;

      final String? storedPasscode = await _secureStorage.read(
        key: 'passcode_${loggedInUser.email}',
      );

      final bool shouldShowAuthGate =
          toggleEnabled && storedPasscode != null && storedPasscode.isNotEmpty;

      if (!mounted) return;

      // ✅ 4. DECISION
      if (shouldShowAuthGate) {
        // 🔒 Passcode ON
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => AuthGateScreen(
                  user: loggedInUser,
                  userEmail: loggedInUser.email,
                  userPhone: loggedInUser.phone,
                ),
          ),
        );
      } else {
        // 🏠 Passcode OFF
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => NavBarPage(
                  user: loggedInUser,
                  userEmail: loggedInUser.email,
                  userPhone: loggedInUser.phone,
                ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ✅ UI — Modern Geometric Design
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              Color(0xFF0F73B8).withOpacity(0.95),
              Color(0xFF1FB5D0),
              Color(0xFF3EE4D8),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Floating geometric shapes
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _ModernShapesPainter(
                      controllerValue: _controller.value,
                    ),
                  );
                },
              ),
            ),

            Center(
              child: FadeTransition(
                opacity: _animation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Modern logo container
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        final floatValue = _floatAnimation.value;
                        final floatOffset = 10 * sin(floatValue * 2 * pi);

                        return Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(),
                          child: Stack(
                            children: [
                              // Gradient background
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    center: Alignment.center,
                                    radius: 0.8,
                                    colors: [
                                      Colors.white.withOpacity(0.15),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),

                              // Logo with floating effect
                              Transform.translate(
                                offset: Offset(0, floatOffset),
                                child: Center(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Image.asset(
                                      'assets/images/bizmate_logo.JPG',
                                      width: 140,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),

                              // Animated rings
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _LogoRingsPainter(
                                    animationValue: _controller.value,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 35),

                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        final textScale =
                            1.0 + 0.05 * sin(_controller.value * pi * 2);

                        return Transform.scale(
                          scale: textScale,
                          child: Text(
                            "BizMate",
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                              height: 1.0,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 8),

                    // Modern subtitle
                    Text(
                      "Business Solutions",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        color: Colors.white.withOpacity(0.8),
                        letterSpacing: 3.0,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Modern loading indicator
                    Container(
                      width: 200,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: Colors.white.withOpacity(0.2),
                      ),
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final progress = _controller.value;

                          return Stack(
                            children: [
                              // Background gradient
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withOpacity(0.3),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),

                              // Animated progress bar
                              Positioned(
                                left: 0,
                                child: Container(
                                  width: 200 * progress,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF3EE4D8),
                                        Colors.white,
                                        Color(0xFF3EE4D8),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(
                                          0xFF3EE4D8,
                                        ).withOpacity(0.6),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Animated dot
                              Positioned(
                                left: 200 * progress - 8,
                                top: -2,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      center: Alignment.center,
                                      radius: 0.7,
                                      colors: [Colors.white, Color(0xFF3EE4D8)],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(
                                          0xFF3EE4D8,
                                        ).withOpacity(0.8),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Modern loading text with dots
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        final dotsCount =
                            (1 + (_controller.value * 3).floor() % 4);
                        final opacity =
                            0.7 + 0.3 * sin(_controller.value * pi * 2);

                        return Opacity(
                          opacity: opacity,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "LOADING",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.9),
                                  letterSpacing: 2.0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '.' * dotsCount,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3EE4D8),
                                  height: 0.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Modern floating shapes painter
class _ModernShapesPainter extends CustomPainter {
  final double controllerValue;

  _ModernShapesPainter({required this.controllerValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final center = Offset(size.width / 2, size.height / 2);

    // Draw modern geometric shapes
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * pi + controllerValue * 0.5;
      final distance = 100.0 + 50 * sin(controllerValue * pi + i * 0.5);
      final x = center.dx + distance * cos(angle);
      final y = center.dy + distance * sin(angle);
      final shapeSize = 10.0 + 5 * sin(controllerValue * 2 * pi + i);
      final opacity = 0.08 + 0.04 * sin(controllerValue * pi + i);

      // Draw different shapes
      if (i % 3 == 0) {
        // Circle
        paint.color = Colors.white.withOpacity(opacity);
        canvas.drawCircle(Offset(x, y), shapeSize, paint);
      } else if (i % 3 == 1) {
        // Square
        paint.color = Color(0xFF3EE4D8).withOpacity(opacity);
        final rect = Rect.fromCenter(
          center: Offset(x, y),
          width: shapeSize * 2,
          height: shapeSize * 2,
        );
        canvas.drawRect(rect, paint);
      } else {
        // Triangle
        paint.color = Color(0xFF1FB5D0).withOpacity(opacity);
        final path =
            Path()
              ..moveTo(x, y - shapeSize)
              ..lineTo(x - shapeSize, y + shapeSize)
              ..lineTo(x + shapeSize, y + shapeSize)
              ..close();
        canvas.drawPath(path, paint);
      }
    }

    // Draw connecting lines
    paint.color = Colors.white.withOpacity(0.05);
    paint.strokeWidth = 1.0;
    paint.style = PaintingStyle.stroke;

    for (int i = 0; i < 4; i++) {
      final angle1 = (i / 4) * 2 * pi + controllerValue * 0.3;
      final angle2 = ((i + 2) / 4) * 2 * pi + controllerValue * 0.3;
      final distance = 180.0;

      final x1 = center.dx + distance * cos(angle1);
      final y1 = center.dy + distance * sin(angle1);
      final x2 = center.dx + distance * cos(angle2);
      final y2 = center.dy + distance * sin(angle2);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ModernShapesPainter oldDelegate) {
    return controllerValue != oldDelegate.controllerValue;
  }
}

// Logo rings painter
class _LogoRingsPainter extends CustomPainter {
  final double animationValue;

  _LogoRingsPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    // Draw animated rings
    for (int i = 0; i < 3; i++) {
      final radius = 60 + i * 20 + 5 * sin(animationValue * 2 * pi + i);
      final opacity = 0.2 - i * 0.05 + 0.05 * sin(animationValue * 2 * pi);
      final sweepAngle = pi * 1.5;
      final startAngle = -pi / 2 + animationValue * pi * 0.5;

      paint.color = Colors.white.withOpacity(opacity);
      paint.strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(center: center, radius: radius);

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LogoRingsPainter oldDelegate) {
    return animationValue != oldDelegate.animationValue;
  }
}
