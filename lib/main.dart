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
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bizmate/services/database_maintenance.dart';
import 'package:bizmate/services/notification_service.dart';
import 'package:bizmate/utils/app_theme.dart';
import 'utils/responsive.dart';

/// ----------------------------------------------------------------
/// ENTRY POINT
/// ----------------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MyApp());
}

Future<void> _initializeApp() async {
  try {
    await Future.wait([_initializeHive(), _initializeDefaultProfileImage()]);
  } catch (e) {
    debugPrint("Startup init error: $e");
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
/// Disables stretching/expanding overscroll and rubber-banding across all pages
class NoOverscrollScrollBehavior extends MaterialScrollBehavior {
  const NoOverscrollScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Responsive.init(context);
        });

        return ValueListenableBuilder<ThemeMode>(
          valueListenable: AppTheme.themeModeNotifier,
          builder: (context, currentThemeMode, _) {
            return MaterialApp(
              title: 'BizMate',
              debugShowCheckedModeBanner: false,
              scrollBehavior: const NoOverscrollScrollBehavior(),
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: currentThemeMode,
              home: const CustomSplashScreen(),
            );
          },
        );
      },
    );
  }
}

/// ----------------------------------------------------------------
/// SPLASH SCREEN — Modern Business Management Theme
/// ----------------------------------------------------------------
class CustomSplashScreen extends StatefulWidget {
  const CustomSplashScreen({super.key});

  @override
  State<CustomSplashScreen> createState() => _CustomSplashScreenState();
}

class _CustomSplashScreenState extends State<CustomSplashScreen>
    with TickerProviderStateMixin {
  // ── Controllers ────────────────────────────────────────────────────────────
  late final AnimationController _masterCtrl; // 3-second main sequence
  late final AnimationController _pulseCtrl; // infinite shimmer / pulse
  late final AnimationController _floatCtrl; // card float oscillation

  // ── Master Animations ──────────────────────────────────────────────────────
  late final Animation<double> _bgFade;
  late final Animation<double> _ringProgress;
  late final Animation<double> _barsProgress;
  late final Animation<double> _lineProgress;
  late final Animation<double> _cardsSlide;
  late final Animation<double> _cardsFade;
  late final Animation<double> _brandSlide;
  late final Animation<double> _brandFade;
  late final Animation<double> _loaderFade;

  String _appVersion = "";
  bool _navigated = false;
  final _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();

    _masterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // ── Intervals ─────────────────────────────────────────────────────────────
    _bgFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.00, 0.25, curve: Curves.easeOut),
      ),
    );
    _ringProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.08, 0.52, curve: Curves.easeInOutCubic),
      ),
    );
    _barsProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.20, 0.62, curve: Curves.easeOutBack),
      ),
    );
    _lineProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.40, 0.75, curve: Curves.easeInOutCubic),
      ),
    );
    _cardsSlide = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.52, 0.78, curve: Curves.easeOutBack),
      ),
    );
    _cardsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.52, 0.74, curve: Curves.easeOut),
      ),
    );
    _brandSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.65, 0.90, curve: Curves.easeOutBack),
      ),
    );
    _brandFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.65, 0.88, curve: Curves.easeOut),
      ),
    );
    _loaderFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.78, 0.98, curve: Curves.easeIn),
      ),
    );

    _masterCtrl.forward();
    _loadAppVersion();
    _initSplash();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _appVersion = "v${info.version}");
    } catch (_) {
      if (!mounted) return;
      setState(() => _appVersion = "");
    }
  }

  Future<void> _initSplash() async {
    await Future.wait([
      _initializeAppTasks(),
      Future.delayed(const Duration(milliseconds: 3200)),
    ]);
    if (mounted) _checkAndNavigate();
  }

  Future<void> _initializeAppTasks() async {
    try {
      await _initializeHive();
      await _initializeDefaultProfileImage();
      await AppTheme.loadThemeMode();
      await NotificationService.init();
      DatabaseMaintenance.initLifecycleListener();
      await DatabaseMaintenance.performCompaction();
    } catch (e) {
      debugPrint("Startup init error: $e");
    }
  }

  Future<void> _checkAndNavigate() async {
    if (_navigated) return;
    _navigated = true;
    await Future.delayed(const Duration(milliseconds: 120));
    try {
      if (!Hive.isBoxOpen('session')) await Hive.openBox('session');
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

      if (!Hive.isBoxOpen('users')) await Hive.openBox<User>('users');
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
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      final loggedInUser = user;
      final prefs = await SharedPreferences.getInstance();
      final bool toggleEnabled =
          prefs.getBool('${loggedInUser.email}_passcodeEnabled') ?? false;
      final String? storedPasscode = await _secureStorage.read(
        key: 'passcode_${loggedInUser.email}',
      );
      final bool shouldShowAuthGate =
          toggleEnabled && storedPasscode != null && storedPasscode.isNotEmpty;

      if (!mounted) return;
      if (shouldShowAuthGate) {
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
    _masterCtrl.dispose();
    _pulseCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Business Dashboard Canvas ─────────────────────────────────
          AnimatedBuilder(
            animation: Listenable.merge([_masterCtrl, _pulseCtrl, _floatCtrl]),
            builder: (context, _) {
              return CustomPaint(
                size: size,
                painter: _BizDashboardPainter(
                  bgFade: _bgFade.value,
                  ringProgress: _ringProgress.value,
                  barsProgress: _barsProgress.value,
                  lineProgress: _lineProgress.value,
                  pulseValue: _pulseCtrl.value,
                  floatValue: _floatCtrl.value,
                ),
              );
            },
          ),

          // ── 2. Floating KPI Cards ─────────────────────────────────────────
          AnimatedBuilder(
            animation: Listenable.merge([_masterCtrl, _floatCtrl]),
            builder: (context, _) {
              return Opacity(
                opacity: _cardsFade.value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, _cardsSlide.value),
                  child: Stack(
                    children: [
                      // Revenue — top left
                      Positioned(
                        left: size.width * 0.04,
                        top: size.height * 0.10 + _floatCtrl.value * 6,
                        child: _kpiCard(
                          icon: Icons.trending_up_rounded,
                          label: "Revenue",
                          value: "₹2.4L",
                          color: const Color(0xFF2563EB),
                          change: "+18%",
                          positive: true,
                        ),
                      ),
                      // Sales — top right
                      Positioned(
                        right: size.width * 0.04,
                        top: size.height * 0.07 + (1 - _floatCtrl.value) * 7,
                        child: _kpiCard(
                          icon: Icons.receipt_long_rounded,
                          label: "Sales",
                          value: "1,284",
                          color: const Color(0xFF818CF8),
                          change: "+9%",
                          positive: true,
                        ),
                      ),
                      // Customers — left mid
                      Positioned(
                        left: size.width * 0.03,
                        top: size.height * 0.27 + _floatCtrl.value * 5,
                        child: _kpiCard(
                          icon: Icons.people_alt_rounded,
                          label: "Customers",
                          value: "348",
                          color: const Color(0xFF22C55E),
                          change: "+5%",
                          positive: true,
                        ),
                      ),
                      // Stock — right mid
                      Positioned(
                        right: size.width * 0.03,
                        top: size.height * 0.29 + (1 - _floatCtrl.value) * 6,
                        child: _kpiCard(
                          icon: Icons.inventory_2_rounded,
                          label: "Stock",
                          value: "96 items",
                          color: const Color(0xFF38BDF8),
                          change: "OK",
                          positive: true,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ── 3. Brand Block (bottom) ───────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * 0.13,
            child: AnimatedBuilder(
              animation: _masterCtrl,
              builder: (context, _) {
                return Opacity(
                  opacity: _brandFade.value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, _brandSlide.value),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // BizMate logo
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF2563EB,
                                ).withValues(alpha: 0.45),
                                blurRadius: 32,
                                spreadRadius: 4,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.asset(
                              'assets/images/bizmate_logo.JPG',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback to icon if asset is missing
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF60A5FA),
                                        Color(0xFF1D4ED8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: const Icon(
                                    Icons.bar_chart_rounded,
                                    color: Colors.white,
                                    size: 42,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Wordmark
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.4,
                            ),
                            children: [
                              TextSpan(
                                text: "Biz",
                                style: TextStyle(color: Colors.white),
                              ),
                              TextSpan(
                                text: "Mate",
                                style: TextStyle(color: Color(0xFF2563EB)),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Tagline
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 48),
                          child: Text(
                            "Smart tools to manage, grow & track your business.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.45),
                              height: 1.55,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),

                        const SizedBox(height: 34),

                        // Sliding progress capsule
                        Opacity(
                          opacity: _loaderFade.value.clamp(0.0, 1.0),
                          child: Container(
                            width: 130,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedBuilder(
                                animation: _pulseCtrl,
                                builder: (context, _) {
                                  return FractionallySizedBox(
                                    alignment: Alignment(
                                      -1.0 + 2.0 * _pulseCtrl.value,
                                      0,
                                    ),
                                    widthFactor: 0.36,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF60A5FA),
                                            Color(0xFF2563EB),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ── 4. Version footer ─────────────────────────────────────────────
          if (_appVersion.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 22,
              child: AnimatedBuilder(
                animation: _masterCtrl,
                builder: (context, _) {
                  return Opacity(
                    opacity: _loaderFade.value.clamp(0.0, 1.0),
                    child: Text(
                      _appVersion,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.22),
                        letterSpacing: 0.6,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Glassmorphic KPI card widget
  Widget _kpiCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required String change,
    required bool positive,
  }) {
    final changeColor =
        positive ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    return Container(
      width: 122,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.09),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: changeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  change,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: changeColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.40),
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------
/// BUSINESS DASHBOARD CANVAS PAINTER
/// Sequence: dot grid → ambient orb → donut ring → bar chart → trend line
/// ----------------------------------------------------------------
class _BizDashboardPainter extends CustomPainter {
  final double bgFade;
  final double ringProgress;
  final double barsProgress;
  final double lineProgress;
  final double pulseValue;
  final double floatValue;

  const _BizDashboardPainter({
    required this.bgFade,
    required this.ringProgress,
    required this.barsProgress,
    required this.lineProgress,
    required this.pulseValue,
    required this.floatValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawDotGrid(canvas, size);
    _drawGlowOrb(canvas, size);
    _drawDonutRing(canvas, size);
    _drawBarChart(canvas, size);
    _drawTrendLine(canvas, size);
    _drawAxisDecor(canvas, size);
  }

  // ── Subtle dot grid ────────────────────────────────────────────────────────
  void _drawDotGrid(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white.withValues(
            alpha: 0.042 * bgFade.clamp(0.0, 1.0),
          );
    const spacing = 26.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  // ── Ambient glow orb ──────────────────────────────────────────────────────
  void _drawGlowOrb(Canvas canvas, Size size) {
    final double alpha = (0.16 * bgFade * (0.85 + 0.15 * pulseValue)).clamp(
      0.0,
      1.0,
    );
    final center = Offset(size.width * 0.5, size.height * 0.42);
    final double radius = size.width * 0.58;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF2563EB).withValues(alpha: alpha),
            const Color(0xFF2563EB).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  // ── Donut ring (revenue/profit/expense) ───────────────────────────────────
  void _drawDonutRing(Canvas canvas, Size size) {
    final cx = size.width * 0.50;
    final cy = size.height * 0.36;
    const double r = 70.0;
    const double sw = 15.0;

    // Background track
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06 * bgFade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw,
    );

    if (ringProgress <= 0) return;

    // Segment: Orange – Revenue (60 %)
    _arc(
      canvas,
      Offset(cx, cy),
      r,
      sw,
      start: -pi / 2,
      sweep: 2 * pi * 0.60 * ringProgress,
      color: const Color(0xFF2563EB),
    );

    // Segment: Green – Profit (25 %)
    _arc(
      canvas,
      Offset(cx, cy),
      r,
      sw,
      start: -pi / 2 + 2 * pi * 0.60 * ringProgress,
      sweep: 2 * pi * 0.25 * ringProgress,
      color: const Color(0xFF22C55E),
    );

    // Segment: Indigo – Expenses (15 %)
    _arc(
      canvas,
      Offset(cx, cy),
      r,
      sw,
      start: -pi / 2 + 2 * pi * 0.85 * ringProgress,
      sweep: 2 * pi * 0.15 * ringProgress,
      color: const Color(0xFF818CF8),
    );

    // Center label
    if (ringProgress > 0.7) {
      final double a = ((ringProgress - 0.7) / 0.3).clamp(0.0, 1.0);
      _centerLabel(canvas, Offset(cx, cy), a);
    }
  }

  void _arc(
    Canvas canvas,
    Offset center,
    double r,
    double sw, {
    required double start,
    required double sweep,
    required Color color,
  }) {
    if (sweep <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: r);
    // Glow
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw + 8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    // Solid
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );
  }

  void _centerLabel(Canvas canvas, Offset c, double alpha) {
    _drawText(
      canvas,
      "78%",
      c.translate(0, -8),
      size: 20,
      bold: true,
      alpha: alpha,
    );
    _drawText(
      canvas,
      "Profit Margin",
      c.translate(0, 12),
      size: 9.5,
      bold: false,
      alpha: alpha * 0.50,
    );
  }

  // ── Bar Chart ─────────────────────────────────────────────────────────────
  void _drawBarChart(Canvas canvas, Size size) {
    if (barsProgress <= 0) return;

    final double left = size.width * 0.11;
    final double bottom = size.height * 0.668;
    final double chartH = size.height * 0.155;

    final List<double> heights = [0.45, 0.62, 0.50, 0.80, 0.68, 0.92, 0.75];
    final List<Color> colors = [
      const Color(0xFF818CF8),
      const Color(0xFF818CF8),
      const Color(0xFF818CF8),
      const Color(0xFF2563EB),
      const Color(0xFF818CF8),
      const Color(0xFF22C55E),
      const Color(0xFF818CF8),
    ];
    const List<String> labels = ["J", "F", "M", "A", "M", "J", "J"];
    const double barW = 19.0;
    final double gapW = (size.width * 0.78) / heights.length;

    for (int i = 0; i < heights.length; i++) {
      final double h = chartH * heights[i] * barsProgress;
      final double x = left + i * gapW + (gapW - barW) / 2;
      final double y = bottom - h;
      final Color col = colors[i];

      // Glow shadow
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 2, y - 4, barW + 4, h + 4),
          const Radius.circular(6),
        ),
        Paint()
          ..color = col.withValues(alpha: 0.24)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );

      // Gradient bar
      final barRect = Rect.fromLTWH(x, y, barW, h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(5)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [col, col.withValues(alpha: 0.50)],
          ).createShader(barRect),
      );

      // Month label
      if (barsProgress > 0.55) {
        final double la = ((barsProgress - 0.55) / 0.45).clamp(0.0, 1.0);
        _drawText(
          canvas,
          labels[i],
          Offset(x + barW / 2, bottom + 6),
          size: 9.5,
          bold: false,
          alpha: 0.35 * la,
          centered: true,
        );
      }
    }
  }

  // ── Trend Line ────────────────────────────────────────────────────────────
  void _drawTrendLine(Canvas canvas, Size size) {
    if (lineProgress <= 0) return;

    final List<Offset> pts = [
      Offset(size.width * 0.10, size.height * 0.640),
      Offset(size.width * 0.24, size.height * 0.592),
      Offset(size.width * 0.38, size.height * 0.612),
      Offset(size.width * 0.52, size.height * 0.552),
      Offset(size.width * 0.66, size.height * 0.570),
      Offset(size.width * 0.80, size.height * 0.505),
      Offset(size.width * 0.92, size.height * 0.522),
    ];

    final Path path = Path();
    path.moveTo(pts[0].dx, pts[0].dy);

    for (int i = 0; i < pts.length - 1; i++) {
      final double t0 = i / (pts.length - 1);
      final double t1 = (i + 1) / (pts.length - 1);
      if (lineProgress < t0) break;
      final double lT =
          lineProgress >= t1 ? 1.0 : (lineProgress - t0) / (t1 - t0);
      final Offset cp = Offset(
        (pts[i].dx + pts[i + 1].dx) / 2,
        (pts[i].dy + pts[i + 1].dy) / 2,
      );
      final double ex = pts[i].dx + (cp.dx - pts[i].dx) * lT;
      final double ey = pts[i].dy + (cp.dy - pts[i].dy) * lT;
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, ex, ey);
    }

    // Glow
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF22C55E).withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Line
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF22C55E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Data point dots
    for (int i = 0; i < pts.length; i++) {
      final double t = i / (pts.length - 1);
      if (lineProgress < t) break;
      final double a = ((lineProgress - t) / 0.12).clamp(0.0, 1.0);
      canvas.drawCircle(
        pts[i],
        4.5,
        Paint()
          ..color = const Color(0xFF22C55E).withValues(alpha: a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawCircle(
        pts[i],
        2.5,
        Paint()..color = Colors.white.withValues(alpha: a),
      );
    }

    // Live pulsing tip
    if (lineProgress > 0.08) {
      final int idx = (lineProgress * (pts.length - 1)).floor();
      final int ti = idx.clamp(0, pts.length - 2);
      final double lT = (lineProgress * (pts.length - 1)) - ti;
      final Offset tip = Offset(
        pts[ti].dx + (pts[ti + 1].dx - pts[ti].dx) * lT,
        pts[ti].dy + (pts[ti + 1].dy - pts[ti].dy) * lT,
      );

      canvas.drawCircle(
        tip,
        8.0 + pulseValue * 3,
        Paint()
          ..color = const Color(0xFF22C55E).withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(tip, 4.5, Paint()..color = const Color(0xFF22C55E));
      canvas.drawCircle(tip, 2.0, Paint()..color = Colors.white);
    }
  }

  // ── Axis decoration & label ───────────────────────────────────────────────
  void _drawAxisDecor(Canvas canvas, Size size) {
    if (bgFade < 0.3) return;
    final double a = ((bgFade - 0.3) / 0.7).clamp(0.0, 1.0);
    final Paint axisPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.06 * a)
          ..strokeWidth = 1.0;

    for (int i = 1; i <= 3; i++) {
      final double y = size.height * 0.50 + (size.height * 0.168 / 3) * i;
      canvas.drawLine(
        Offset(size.width * 0.09, y),
        Offset(size.width * 0.93, y),
        axisPaint,
      );
    }

    if (barsProgress > 0.35) {
      final double la = ((barsProgress - 0.35) / 0.65).clamp(0.0, 1.0);
      _drawText(
        canvas,
        "MONTHLY PERFORMANCE",
        Offset(size.width * 0.12, size.height * 0.478),
        size: 8.0,
        bold: true,
        alpha: 0.18 * la,
        letterSpacing: 1.8,
      );
    }
  }

  // ── Text helper ───────────────────────────────────────────────────────────
  void _drawText(
    Canvas canvas,
    String text,
    Offset position, {
    required double size,
    required bool bold,
    required double alpha,
    bool centered = false,
    double letterSpacing = 0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          color: Colors.white.withValues(alpha: alpha),
          letterSpacing: letterSpacing,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      centered
          ? Offset(position.dx - tp.width / 2, position.dy)
          : Offset(position.dx - tp.width / 2, position.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _BizDashboardPainter old) {
    return bgFade != old.bgFade ||
        ringProgress != old.ringProgress ||
        barsProgress != old.barsProgress ||
        lineProgress != old.lineProgress ||
        pulseValue != old.pulseValue ||
        floatValue != old.floatValue;
  }
}
