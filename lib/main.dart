// lib/main.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:math' as math;
import 'dart:ui';
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
import 'package:bizmate/services/backup_scheduler.dart';
import 'package:bizmate/utils/app_theme.dart';
import 'package:bizmate/constants/bizmate_emblem_bytes.dart';
import 'utils/responsive.dart';

/// ----------------------------------------------------------------
/// ENTRY POINT
/// ----------------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise workmanager for background scheduled backups
  await BackupScheduler.init();

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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Ambient Background Grid ────────────────────────────────────────
          AnimatedBuilder(
            animation: _masterCtrl,
            builder: (context, _) {
              return CustomPaint(
                painter: _BizGridPainter(bgFade: _bgFade.value),
              );
            },
          ),

          // ── Responsive Layout Engine ───────────────────────────────────────
          // ── Responsive Layout Engine (Centered B Logo across All Devices) ──
          LayoutBuilder(
            builder: (context, constraints) {
              return _buildResponsiveSplash(context, constraints);
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UNIFIED RESPONSIVE SPLASH LAYOUT (Mobile, Tablets, iPads & Big Screens)
  // Perfectly centers the 'B' Brand Emblem in both X and Y axes on all devices
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildResponsiveSplash(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final screenH = constraints.maxHeight;
    final screenW = constraints.maxWidth;
    final isShort = screenH < 500; // landscape phones
    final isCompact = screenH < 720; // compact phones (iPhone SE, mini)
    final isTablet = screenW >= 600; // tablets, iPads, desktop

    // Responsive deck dimensions
    final double deckW;
    final double deckH;
    final double cardScale;

    // Always constrain the artwork to the available width. This also handles
    // narrow phones in landscape and iPad split-screen / Stage Manager windows.
    final availableDeckW = math.max(1.0, screenW - 24.0).toDouble();

    if (isShort) {
      deckH = (screenH * 0.58).clamp(170.0, 220.0).toDouble();
      deckW =
          math
              .min((deckH * 1.45).clamp(240.0, 360.0), availableDeckW)
              .toDouble();
      cardScale = 0.85;
    } else if (isTablet) {
      deckW =
          math
              .min((screenW * 0.55).clamp(360.0, 520.0), availableDeckW)
              .toDouble();
      deckH = (screenH * 0.36).clamp(280.0, 400.0).toDouble();
      cardScale = 1.14;
    } else if (isCompact) {
      deckW =
          math
              .min((screenW - 24.0).clamp(240.0, 360.0), availableDeckW)
              .toDouble();
      deckH = (screenH * 0.36).clamp(220.0, 270.0).toDouble();
      cardScale = 0.85;
    } else {
      // Standard & Large Smartphones
      deckW =
          math
              .min((screenW - 28.0).clamp(280.0, 400.0), availableDeckW)
              .toDouble();
      deckH = (screenH * 0.36).clamp(260.0, 320.0).toDouble();
      cardScale = 1.00;
    }

    final wordmarkSize =
        isShort ? 24.0 : (isCompact ? 28.0 : (isTablet ? 38.0 : 34.0));
    final taglineSize =
        isShort ? 10.5 : (isCompact ? 11.5 : (isTablet ? 13.5 : 12.5));

    // Keep the B emblem mathematically centered in the available splash body.
    // The KPI cards are sized responsively around it without moving this center.
    final centerY = screenH / 2;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── CENTER HERO SHOWCASE (Deck with Central B Logo) ─────────────────
        Positioned(
          left: (screenW - deckW) / 2,
          top: centerY - (deckH / 2),
          width: deckW,
          height: deckH,
          child: _buildAnalyticsDeck(
            width: deckW,
            height: deckH,
            cardScale: cardScale,
          ),
        ),

        // ── BRAND IDENTITY BLOCK (Wordmark + Tagline + Progress Capsule) ────
        Positioned(
          left: 16,
          right: 16,
          top: centerY + (deckH / 2) + (isCompact ? 10 : 16),
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
                      _buildBrandWordmark(fontSize: wordmarkSize),
                      SizedBox(height: isCompact ? 4 : 6),
                      _buildBrandTagline(
                        fontSize: taglineSize,
                        maxW: deckW + 40,
                      ),
                      SizedBox(height: isCompact ? 12 : 18),
                      _buildProgressCapsule(width: isCompact ? 105 : 128),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // ── ANCHORED VERSION FOOTER ─────────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: safeBottom + (isCompact ? 8 : 14),
          child: _buildVersionFooter(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ANALYTICS SHOWCASE DECK WITH FLOATING CARDS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAnalyticsDeck({
    required double width,
    required double height,
    required double cardScale,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Dashboard Custom Canvas
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _masterCtrl,
                _pulseCtrl,
                _floatCtrl,
              ]),
              builder: (context, _) {
                return CustomPaint(
                  size: Size(width, height),
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
          ),

          // 2. Animated Center Circle 'B' Brand Emblem (BizMate Logo with Handshake & Arrow)
          _buildAnimatedCircleLogo(
            cx: width * 0.50,
            cy: height * 0.50,
            r: (height * 0.17).clamp(34.0, 60.0).toDouble(),
          ),

          // 3. Floating KPI Cards (Pinned safely to Deck Boundaries)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_masterCtrl, _floatCtrl]),
              builder: (context, _) {
                return Opacity(
                  opacity: _cardsFade.value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, _cardsSlide.value),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Revenue — Top Left
                        Positioned(
                          left: 0,
                          top: -18,
                          child: _kpiCard(
                            icon: Icons.trending_up_rounded,
                            label: "Revenue",
                            value: "₹2.4L",
                            color: const Color(0xFF2563EB),
                            change: "+18%",
                            positive: true,
                            scale: cardScale,
                          ),
                        ),
                        // Sales — Top Right
                        Positioned(
                          right: 0,
                          top: -18,
                          child: _kpiCard(
                            icon: Icons.receipt_long_rounded,
                            label: "Sales",
                            value: "1,284",
                            color: const Color(0xFF818CF8),
                            change: "+9%",
                            positive: true,
                            scale: cardScale,
                          ),
                        ),
                        // Customers — Bottom Left
                        Positioned(
                          left: 0,
                          top: height * 0.40,
                          child: _kpiCard(
                            icon: Icons.people_alt_rounded,
                            label: "Customers",
                            value: "348",
                            color: const Color(0xFF22C55E),
                            change: "+5%",
                            positive: true,
                            scale: cardScale,
                          ),
                        ),
                        // Stock — Bottom Right
                        Positioned(
                          right: 0,
                          top: height * 0.40,
                          child: _kpiCard(
                            icon: Icons.inventory_2_rounded,
                            label: "Stock",
                            value: "96 items",
                            color: const Color(0xFF38BDF8),
                            change: "OK",
                            positive: true,
                            scale: cardScale,
                          ),
                        ),
                      ],
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

  /// ─────────────────────────────────────────────────────────────────────────
  /// ANIMATED CENTER CIRCLE 'B' MONOGRAM (Fluid Laser Pen Drawing to Official Logo)
  /// ─────────────────────────────────────────────────────────────────────────
  Widget _buildAnimatedCircleLogo({
    required double cx,
    required double cy,
    required double r,
  }) {
    // Exact sizing matching circle aperture proportionally across all device sizes
    final double sw = (r * 0.22).clamp(8.0, 12.0).toDouble();
    final double innerDiameter = 2 * (r - sw * 0.5);
    // Slightly smaller emblem for a cleaner, less crowded center on phones.
    final double emblemSize = innerDiameter * 0.78;

    return AnimatedBuilder(
      animation: Listenable.merge([_masterCtrl, _pulseCtrl, _floatCtrl]),
      builder: (context, _) {
        final t = _masterCtrl.value;
        // Start drawing as the ambient ring begins forming (t = 0.06)
        if (t < 0.06) return const SizedBox.shrink();

        // 1. Fluid, cinematic drawing over 1.8 seconds (t = 0.06 -> 0.68)
        final drawProgress = ((t - 0.06) / 0.62).clamp(0.0, 1.0);
        final drawEase = Curves.easeInOutCubic.transform(drawProgress);

        // 2. Official High-Def Logo Paint-In & Bloom (t = 0.54 -> 0.78)
        final fillProgress = ((t - 0.54) / 0.24).clamp(0.0, 1.0);
        final fillEase = Curves.easeOutCubic.transform(fillProgress);

        // 3. Arrowhead celebratory diamond starburst flare (t = 0.66 -> 0.82)
        final flareProgress = ((t - 0.66) / 0.16).clamp(0.0, 1.0);

        final shimmerX = -1.6 + 3.2 * _pulseCtrl.value;

        // Ambient backlight halo intensity
        final ambientAlpha = (0.44 *
                (t / 0.50).clamp(0.0, 1.0) *
                (0.8 + 0.2 * _pulseCtrl.value))
            .clamp(0.0, 1.0);

        return Positioned(
          left: cx - emblemSize / 2,
          top: cy - emblemSize / 2,
          width: emblemSize,
          height: emblemSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Ambient backlight halo behind emblem
              Container(
                width: emblemSize * 0.78,
                height: emblemSize * 0.78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFF00F0FF,
                      ).withValues(alpha: ambientAlpha * 0.85),
                      blurRadius: 26,
                      spreadRadius: 3,
                    ),
                    BoxShadow(
                      color: const Color(
                        0xFF2563EB,
                      ).withValues(alpha: ambientAlpha * 0.70),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),

              // 2. Real-time Laser Pen Drawing (Exact contours of BizMate B & Arrow)
              if (fillEase < 1.0)
                CustomPaint(
                  size: Size(emblemSize, emblemSize),
                  painter: _LogoBDrawingPainter(
                    drawProgress: drawEase,
                    fillProgress: fillEase,
                    pulseValue: _pulseCtrl.value,
                  ),
                ),

              // 3. Official High-Def Logo (Paints in smoothly and rests permanently in pristine clarity)
              if (fillProgress > 0.0)
                Opacity(
                  opacity: fillEase,
                  child: Transform.scale(
                    scale: 0.94 + 0.06 * fillEase,
                    child: ShaderMask(
                      blendMode: BlendMode.srcATop,
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          begin: Alignment(shimmerX - 0.45, -1.0),
                          end: Alignment(shimmerX + 0.45, 1.0),
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(
                              alpha: 0.40 * (0.7 + 0.3 * _pulseCtrl.value),
                            ),
                            const Color(0xFF00F5FF).withValues(alpha: 0.50),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.45, 0.55, 1.0],
                        ).createShader(bounds);
                      },
                      child: Image.memory(
                        kBizmateEmblemBytes,
                        width: emblemSize,
                        height: emblemSize,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),

              // 4. Arrowhead celebratory diamond starburst flare
              if (flareProgress > 0.0 && flareProgress < 1.0)
                CustomPaint(
                  size: Size(emblemSize, emblemSize),
                  painter: _ArrowheadFlarePainter(progress: flareProgress),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BRAND WIDGET HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBrandLogo({double size = 84}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.45),
            blurRadius: 30,
            spreadRadius: 3,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: Image.asset(
          'assets/images/bizmate_logo.JPG',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF60A5FA), Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(size * 0.24),
              ),
              child: Icon(
                Icons.bar_chart_rounded,
                color: Colors.white,
                size: size * 0.46,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrandWordmark({double fontSize = 40}) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.3,
        ),
        children: const [
          TextSpan(text: "Biz", style: TextStyle(color: Colors.white)),
          TextSpan(text: "Mate", style: TextStyle(color: Color(0xFF2563EB))),
        ],
      ),
    );
  }

  Widget _buildBrandTagline({double fontSize = 13.5, double maxW = 340}) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          "Smart tools to manage, grow & track your business.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.45),
            height: 1.5,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCapsule({double width = 120, double height = 4}) {
    return Opacity(
      opacity: _loaderFade.value.clamp(0.0, 1.0),
      child: Container(
        width: width,
        height: height,
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
                alignment: Alignment(-1.0 + 2.0 * _pulseCtrl.value, 0),
                widthFactor: 0.36,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVersionFooter() {
    if (_appVersion.isEmpty) return const SizedBox.shrink();
    return AnimatedBuilder(
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
    );
  }

  /// Glassmorphic KPI card widget with scale factor
  Widget _kpiCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required String change,
    required bool positive,
    double scale = 1.0,
  }) {
    final changeColor =
        positive ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    return Container(
      width: 140 * scale,
      padding: EdgeInsets.symmetric(
        horizontal: 12 * scale,
        vertical: 12 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14 * scale),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.09),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.14),
            blurRadius: 16 * scale,
            offset: Offset(0, 4 * scale),
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
                width: 29 * scale,
                height: 29 * scale,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(7 * scale),
                ),
                child: Icon(icon, color: color, size: 18 * scale),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 5 * scale,
                  vertical: 2 * scale,
                ),
                decoration: BoxDecoration(
                  color: changeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(5 * scale),
                ),
                child: Text(
                  change,
                  style: TextStyle(
                    fontSize: 9.5 * scale,
                    fontWeight: FontWeight.w700,
                    color: changeColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 9 * scale),
          Text(
            value,
            style: TextStyle(
              fontSize: 17.5 * scale,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          SizedBox(height: 1 * scale),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5 * scale,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.40),
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// CINEMATIC LASER PEN DRAWING PAINTER FOR BIZMATE B LOGO
/// Traces Spine, Top Loop, Bottom Loop, Handshake Clasp, and Growth Arrow
/// ─────────────────────────────────────────────────────────────────────────
class _LogoBDrawingPainter extends CustomPainter {
  final double drawProgress;
  final double fillProgress;
  final double pulseValue;

  const _LogoBDrawingPainter({
    required this.drawProgress,
    required this.fillProgress,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (drawProgress <= 0.0) return;

    // Fade drawing stroke alpha as the high-def logo blooms in
    final strokeFade = (1.0 - fillProgress).clamp(0.0, 1.0);
    if (strokeFade <= 0.001) return;

    // Coordinate mapping helper from 280x280 emblem to current widget size
    Offset p(double x, double y) =>
        Offset(x / 280.0 * size.width, y / 280.0 * size.height);

    // ── STROKE 1: Backbone Spine of B (Top down to bottom) ────────────────
    final spinePath =
        Path()
          ..moveTo(p(58, 20).dx, p(58, 20).dy)
          ..lineTo(p(58, 264).dx, p(58, 264).dy)
          ..lineTo(p(98, 264).dx, p(98, 264).dy)
          ..lineTo(p(98, 20).dx, p(98, 20).dy)
          ..close();

    // ── STROKE 2: Top Loop of B (Turquoise Cyan arc) ─────────────────────
    final topLoopOuter =
        Path()
          ..moveTo(p(98, 20).dx, p(98, 20).dy)
          ..lineTo(p(178, 20).dx, p(178, 20).dy)
          ..cubicTo(
            p(232, 20).dx,
            p(232, 20).dy,
            p(232, 98).dx,
            p(232, 98).dy,
            p(178, 106).dx,
            p(178, 106).dy,
          )
          ..lineTo(p(98, 106).dx, p(98, 106).dy);

    final topLoopInner =
        Path()
          ..moveTo(p(98, 42).dx, p(98, 42).dy)
          ..lineTo(p(162, 42).dx, p(162, 42).dy)
          ..cubicTo(
            p(196, 42).dx,
            p(196, 42).dy,
            p(196, 84).dx,
            p(196, 84).dy,
            p(162, 84).dx,
            p(162, 84).dy,
          )
          ..lineTo(p(98, 84).dx, p(98, 84).dy)
          ..close();

    // ── STROKE 3: Lower Loop of B (Deep Royal Sapphire arc) ──────────────
    final botLoopOuter =
        Path()
          ..moveTo(p(98, 106).dx, p(98, 106).dy)
          ..lineTo(p(178, 106).dx, p(178, 106).dy)
          ..cubicTo(
            p(252, 115).dx,
            p(252, 115).dy,
            p(252, 264).dx,
            p(252, 264).dy,
            p(178, 264).dx,
            p(178, 264).dy,
          )
          ..lineTo(p(98, 264).dx, p(98, 264).dy);

    final botLoopInner =
        Path()
          ..moveTo(p(98, 130).dx, p(98, 130).dy)
          ..lineTo(p(164, 130).dx, p(164, 130).dy)
          ..cubicTo(
            p(210, 130).dx,
            p(210, 130).dy,
            p(210, 238).dx,
            p(210, 238).dy,
            p(164, 238).dx,
            p(164, 238).dy,
          )
          ..lineTo(p(98, 238).dx, p(98, 238).dy)
          ..close();

    // ── STROKE 4: Handshake Arc and Clasp across center waist ─────────────
    final handshakeLeftArm =
        Path()
          ..moveTo(p(34, 68).dx, p(34, 68).dy)
          ..cubicTo(
            p(40, 138).dx,
            p(40, 138).dy,
            p(85, 160).dx,
            p(85, 160).dy,
            p(126, 156).dx,
            p(126, 156).dy,
          );

    final handshakeClasp =
        Path()
          ..moveTo(p(102, 142).dx, p(102, 142).dy)
          ..cubicTo(
            p(118, 166).dx,
            p(118, 166).dy,
            p(148, 160).dx,
            p(148, 160).dy,
            p(138, 132).dx,
            p(138, 132).dy,
          );

    // ── STROKE 5: Upward Growth Swoosh and Arrowhead ──────────────────────
    final growthSwoosh =
        Path()
          ..moveTo(p(118, 156).dx, p(118, 156).dy)
          ..cubicTo(
            p(165, 150).dx,
            p(165, 150).dy,
            p(202, 85).dx,
            p(202, 85).dy,
            p(226, 38).dx,
            p(226, 38).dy,
          );

    final arrowTip = p(244, 10);
    final arrowLeft = p(214, 26);
    final arrowNotch = p(228, 28);
    final arrowRight = p(234, 48);

    final arrowheadPath =
        Path()
          ..moveTo(arrowTip.dx, arrowTip.dy)
          ..lineTo(arrowLeft.dx, arrowLeft.dy)
          ..lineTo(arrowNotch.dx, arrowNotch.dy)
          ..lineTo(arrowRight.dx, arrowRight.dy)
          ..close();

    // ── PEN DRAWING HELPER ────────────────────────────────────────────────
    void tracePath(
      Path path,
      double progress, {
      required Color glowColor,
      required Color coreColor,
      required double strokeWidth,
      bool showSpark = true,
    }) {
      if (progress <= 0.0) return;
      final metrics = path.computeMetrics().toList();
      for (final metric in metrics) {
        final currentLen = metric.length * progress;
        if (currentLen <= 0.0) continue;
        final partial = metric.extractPath(0.0, currentLen);

        // Ambient neon aura
        canvas.drawPath(
          partial,
          Paint()
            ..color = glowColor.withValues(alpha: 0.70 * strokeFade)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth + 4.0
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );

        // Vivid crisp pen line
        canvas.drawPath(
          partial,
          Paint()
            ..color = coreColor.withValues(alpha: 0.95 * strokeFade)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );

        // Active glowing laser stylus tip at pen head
        if (showSpark && progress > 0.01 && progress < 0.999) {
          final tangent = metric.getTangentForOffset(currentLen);
          if (tangent != null) {
            final headPos = tangent.position;

            // Outer laser tip halo
            canvas.drawCircle(
              headPos,
              strokeWidth * 2.2,
              Paint()
                ..color = glowColor.withValues(alpha: 0.90 * strokeFade)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
            );

            // Intense white core
            canvas.drawCircle(
              headPos,
              strokeWidth * 1.0,
              Paint()..color = Colors.white.withValues(alpha: strokeFade),
            );

            // Orbiting micro-sparks around the pen tip
            const sparkCount = 3;
            for (int i = 0; i < sparkCount; i++) {
              final angle = pulseValue * 4 * pi + (i * 2 * pi / sparkCount);
              final sparkDist = strokeWidth * (1.8 + 0.8 * sin(angle * 2));
              final sparkPos =
                  headPos +
                  Offset(cos(angle) * sparkDist, sin(angle) * sparkDist);
              canvas.drawCircle(
                sparkPos,
                1.2,
                Paint()
                  ..color = const Color(
                    0xFF00F5FF,
                  ).withValues(alpha: 0.85 * strokeFade),
              );
            }
          }
        }
      }
    }

    // ── SEQUENTIAL STROKE TIMELINE (Cinematic drawing order) ──────────────
    // 1. Spine (0.00 -> 0.22)
    final prog1 = (drawProgress / 0.22).clamp(0.0, 1.0);
    tracePath(
      spinePath,
      prog1,
      glowColor: const Color(0xFF00F5FF),
      coreColor: Colors.white,
      strokeWidth: 2.6,
    );

    // 2. Top Loop (0.16 -> 0.42)
    final prog2 = ((drawProgress - 0.16) / 0.26).clamp(0.0, 1.0);
    if (prog2 > 0.0) {
      tracePath(
        topLoopOuter,
        prog2,
        glowColor: const Color(0xFF00F5FF),
        coreColor: const Color(0xFFBAE6FD),
        strokeWidth: 2.4,
      );
      tracePath(
        topLoopInner,
        prog2,
        glowColor: const Color(0xFF38BDF8),
        coreColor: Colors.white,
        strokeWidth: 1.8,
        showSpark: false,
      );
    }

    // 3. Bottom Loop (0.34 -> 0.60)
    final prog3 = ((drawProgress - 0.34) / 0.26).clamp(0.0, 1.0);
    if (prog3 > 0.0) {
      tracePath(
        botLoopOuter,
        prog3,
        glowColor: const Color(0xFF2563EB),
        coreColor: const Color(0xFF93C5FD),
        strokeWidth: 2.6,
      );
      tracePath(
        botLoopInner,
        prog3,
        glowColor: const Color(0xFF1D4ED8),
        coreColor: Colors.white,
        strokeWidth: 1.8,
        showSpark: false,
      );
    }

    // 4. Handshake Clasp (0.48 -> 0.74)
    final prog4 = ((drawProgress - 0.48) / 0.26).clamp(0.0, 1.0);
    if (prog4 > 0.0) {
      tracePath(
        handshakeLeftArm,
        prog4,
        glowColor: const Color(0xFF38BDF8),
        coreColor: Colors.white,
        strokeWidth: 2.6,
      );
      tracePath(
        handshakeClasp,
        prog4,
        glowColor: const Color(0xFF00F5FF),
        coreColor: const Color(0xFFBAE6FD),
        strokeWidth: 2.2,
      );
    }

    // 5. Growth Arrow Swoosh (0.62 -> 0.92)
    final prog5 = ((drawProgress - 0.62) / 0.30).clamp(0.0, 1.0);
    if (prog5 > 0.0) {
      tracePath(
        growthSwoosh,
        prog5,
        glowColor: const Color(0xFF10B981),
        coreColor: const Color(0xFF6EE7B7),
        strokeWidth: 2.8,
      );
    }

    // 6. Arrowhead tip (0.84 -> 1.00)
    final prog6 = ((drawProgress - 0.84) / 0.16).clamp(0.0, 1.0);
    if (prog6 > 0.0) {
      tracePath(
        arrowheadPath,
        prog6,
        glowColor: const Color(0xFF00F5FF),
        coreColor: Colors.white,
        strokeWidth: 2.4,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LogoBDrawingPainter old) {
    return drawProgress != old.drawProgress ||
        fillProgress != old.fillProgress ||
        pulseValue != old.pulseValue;
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// ARROWHEAD CELEBRATORY DIAMOND STARBURST FLARE
/// ─────────────────────────────────────────────────────────────────────────
class _ArrowheadFlarePainter extends CustomPainter {
  final double progress;

  const _ArrowheadFlarePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    // Arrow tip location in normalized coordinates
    final tip = Offset(244.0 / 280.0 * size.width, 10.0 / 280.0 * size.height);

    // Eased burst curve: expands then fades
    final burstScale = sin(progress * pi);
    final fadeOut = (1.0 - progress).clamp(0.0, 1.0);

    // 1. Expanding micro shockwave ring
    final ringRadius = size.width * 0.16 * progress;
    canvas.drawCircle(
      tip,
      ringRadius,
      Paint()
        ..color = const Color(0xFF00F5FF).withValues(alpha: 0.65 * fadeOut)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * fadeOut,
    );

    // 2. Diamond 4-point star rays
    final rayLen = size.width * 0.22 * burstScale;
    final rayPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.90 * fadeOut)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;

    final rayGlowPaint =
        Paint()
          ..color = const Color(0xFF00F5FF).withValues(alpha: 0.70 * fadeOut)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final crossPath =
        Path()
          ..moveTo(tip.dx - rayLen, tip.dy)
          ..lineTo(tip.dx + rayLen, tip.dy)
          ..moveTo(tip.dx, tip.dy - rayLen)
          ..lineTo(tip.dx, tip.dy + rayLen);

    canvas.drawPath(crossPath, rayGlowPaint);
    canvas.drawPath(crossPath, rayPaint);

    // 3. Brilliant central white spark
    canvas.drawCircle(
      tip,
      4.0 * burstScale,
      Paint()..color = Colors.white.withValues(alpha: fadeOut),
    );
  }

  @override
  bool shouldRepaint(covariant _ArrowheadFlarePainter old) =>
      progress != old.progress;
}

/// FULL-SCREEN AMBIENT DOT GRID PAINTER
/// ----------------------------------------------------------------
class _BizGridPainter extends CustomPainter {
  final double bgFade;

  const _BizGridPainter({required this.bgFade});

  @override
  void paint(Canvas canvas, Size size) {
    if (bgFade <= 0) return;
    final paint =
        Paint()
          ..color = Colors.white.withValues(
            alpha: 0.038 * bgFade.clamp(0.0, 1.0),
          );
    const spacing = 28.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BizGridPainter old) => bgFade != old.bgFade;
}

/// ----------------------------------------------------------------
/// BUSINESS DASHBOARD CANVAS PAINTER
/// Bounded to Deck Showcase: Ambient Orb → Donut Ring → Bar Chart → Trend Line
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
    _drawGlowOrb(canvas, size);
    _drawDonutRing(canvas, size);
    _drawBarChart(canvas, size);
    _drawTrendLine(canvas, size);
    _drawAxisDecor(canvas, size);
  }

  // ── Ambient Glow Orb ──────────────────────────────────────────────────────
  void _drawGlowOrb(Canvas canvas, Size size) {
    final double alpha = (0.16 * bgFade * (0.85 + 0.15 * pulseValue)).clamp(
      0.0,
      1.0,
    );
    final center = Offset(size.width * 0.50, size.height * 0.50);
    final double radius = size.width * 0.52;
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

  // ── Donut Ring (Revenue / Profit / Expense) ───────────────────────────────
  void _drawDonutRing(Canvas canvas, Size size) {
    final cx = size.width * 0.50;
    final cy = size.height * 0.50;
    final double r = (size.height * 0.17).clamp(34.0, 60.0).toDouble();
    final double sw = (r * 0.22).clamp(8.0, 12.0).toDouble();

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

    // Segment: Blue – Revenue (60%)
    _arc(
      canvas,
      Offset(cx, cy),
      r,
      sw,
      start: -pi / 2,
      sweep: 2 * pi * 0.60 * ringProgress,
      color: const Color(0xFF2563EB),
    );

    // Segment: Green – Profit (25%)
    _arc(
      canvas,
      Offset(cx, cy),
      r,
      sw,
      start: -pi / 2 + 2 * pi * 0.60 * ringProgress,
      sweep: 2 * pi * 0.25 * ringProgress,
      color: const Color(0xFF22C55E),
    );

    // Segment: Indigo – Expenses (15%)
    _arc(
      canvas,
      Offset(cx, cy),
      r,
      sw,
      start: -pi / 2 + 2 * pi * 0.85 * ringProgress,
      sweep: 2 * pi * 0.15 * ringProgress,
      color: const Color(0xFF818CF8),
    );

    // Center Circle Ambient Aura & Orbiting Particles
    if (ringProgress > 0.12) {
      final double a = ((ringProgress - 0.12) / 0.88).clamp(0.0, 1.0);
      _drawDonutCenterAura(canvas, Offset(cx, cy), a, r);
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
    // Soft outer glow
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw + 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Sharp core stroke
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

  void _drawDonutCenterAura(Canvas canvas, Offset c, double alpha, double r) {
    if (alpha <= 0) return;

    // 1. Ambient Holographic Core Glow
    final coreR = r * 0.76;
    final pulseScale = 0.92 + 0.08 * pulseValue;
    canvas.drawCircle(
      c,
      coreR * pulseScale,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(
              0xFF00F0FF,
            ).withValues(alpha: 0.35 * alpha * (0.8 + 0.2 * pulseValue)),
            const Color(0xFF2563EB).withValues(alpha: 0.20 * alpha),
            const Color(0xFF1E1B4B).withValues(alpha: 0.06 * alpha),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 0.80, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: coreR * pulseScale)),
    );

    // 2. Concentric Orbit Rings & Counter-Rotating Cyber Arcs
    final orbitR = r * 0.70;
    canvas.drawCircle(
      c,
      orbitR,
      Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.20 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Orbiting Cyan Energy Arc (clockwise)
    final satAngle1 = 2 * pi * pulseValue;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: orbitR),
      satAngle1,
      pi * 0.45,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: satAngle1,
          endAngle: satAngle1 + pi * 0.45,
          colors: [
            const Color(0xFF00F0FF).withValues(alpha: 0.0),
            const Color(0xFF00F0FF).withValues(alpha: 0.85 * alpha),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: orbitR))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Counter-orbiting Subtle Violet Arc (counter-clockwise)
    final satAngle2 = -2 * pi * pulseValue + pi * 0.8;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: orbitR * 0.88),
      satAngle2,
      pi * 0.30,
      false,
      Paint()
        ..color = const Color(0xFF818CF8).withValues(alpha: 0.45 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );

    // 3. Orbiting Kinetic Energy Sparks (matching BizMate brand icon accents)
    final List<Map<String, double>> sparks = [
      {'angle': 2 * pi * pulseValue + 0.3, 'dist': orbitR * 0.95, 'size': 2.2},
      {'angle': 2 * pi * pulseValue + 3.14, 'dist': orbitR * 0.78, 'size': 1.8},
      {'angle': -2 * pi * pulseValue + 1.2, 'dist': orbitR * 1.05, 'size': 1.5},
      {'angle': -2 * pi * pulseValue + 4.2, 'dist': orbitR * 0.85, 'size': 2.0},
    ];
    for (final spark in sparks) {
      final spOffset =
          c +
          Offset(
            cos(spark['angle']!) * spark['dist']!,
            sin(spark['angle']!) * spark['dist']!,
          );
      canvas.drawCircle(
        spOffset,
        spark['size']! * 2.2,
        Paint()
          ..color = const Color(0xFF00F5FF).withValues(alpha: 0.40 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        spOffset,
        spark['size']!,
        Paint()
          ..color = const Color(0xFFE0F2FE).withValues(alpha: 0.95 * alpha),
      );
    }

    // 4. Cyan Beacon Pulse Node beneath emblem
    final nodeY = r * 0.64;
    canvas.drawCircle(
      c + Offset(0, nodeY),
      2.6,
      Paint()
        ..color = const Color(0xFF00F0FF).withValues(alpha: 0.90 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(
      c + Offset(0, nodeY),
      1.5,
      Paint()..color = Colors.white.withValues(alpha: 0.95 * alpha),
    );
  }

  // ── Monthly Performance Bar Chart ─────────────────────────────────────────
  void _drawBarChart(Canvas canvas, Size size) {
    if (barsProgress <= 0) return;

    final double left = size.width * 0.08;
    final double bottom = size.height * 0.95;
    final double chartH = size.height * 0.20;

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
    final double gapW = (size.width * 0.84) / heights.length;
    final double barW = (gapW * 0.44).clamp(10.0, 18.0);

    for (int i = 0; i < heights.length; i++) {
      final double h = chartH * heights[i] * barsProgress;
      final double x = left + i * gapW + (gapW - barW) / 2;
      final double y = bottom - h;
      final Color col = colors[i];

      // Bar shadow glow
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 2, y - 3, barW + 4, h + 3),
          const Radius.circular(5),
        ),
        Paint()
          ..color = col.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      // Gradient bar body
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
          Offset(x + barW / 2, bottom + 5),
          size: 9.0,
          bold: false,
          alpha: 0.35 * la,
          centered: true,
        );
      }
    }
  }

  // ── Growth Trend Line with Pulsing Live Tip ───────────────────────────────
  void _drawTrendLine(Canvas canvas, Size size) {
    if (lineProgress <= 0) return;

    final double left = size.width * 0.08;
    final double bottom = size.height * 0.95;
    final double chartH = size.height * 0.20;
    final List<double> heights = [0.45, 0.62, 0.50, 0.80, 0.68, 0.92, 0.75];
    final double gapW = (size.width * 0.84) / heights.length;

    final List<Offset> pts = List.generate(heights.length, (i) {
      final double cx = left + i * gapW + gapW / 2;
      final double cy =
          bottom - chartH * heights[i] * 1.12 + (i.isEven ? -2 : 3);
      return Offset(cx, cy);
    });

    // Build the complete smooth curve first, including the final data point.
    // Revealing a measured portion of this path guarantees that the green line
    // reaches the last point when the animation reaches 100%.
    final Path fullPath = Path()..moveTo(pts.first.dx, pts.first.dy);

    for (int i = 0; i < pts.length - 1; i++) {
      final Offset current = pts[i];
      final Offset next = pts[i + 1];

      if (i == pts.length - 2) {
        // Explicitly finish at the last point; otherwise the line stops at
        // the final midpoint and looks as though the drawing animation failed.
        fullPath.quadraticBezierTo(current.dx, current.dy, next.dx, next.dy);
      } else {
        final Offset midpoint = Offset(
          (current.dx + next.dx) / 2,
          (current.dy + next.dy) / 2,
        );
        fullPath.quadraticBezierTo(
          current.dx,
          current.dy,
          midpoint.dx,
          midpoint.dy,
        );
      }
    }

    final List<PathMetric> metrics = fullPath.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final PathMetric metric = metrics.first;
    if (metric.length <= 0) return;

    final double progress = lineProgress.clamp(0.0, 1.0);
    final double drawnLength = metric.length * progress;
    final Path visiblePath = metric.extractPath(0, drawnLength);

    // Soft green glow beneath the line.
    canvas.drawPath(
      visiblePath,
      Paint()
        ..color = const Color(0xFF22C55E).withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Crisp foreground line.
    canvas.drawPath(
      visiblePath,
      Paint()
        ..color = const Color(0xFF22C55E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Reveal data-point markers progressively along the animation.
    for (int i = 0; i < pts.length; i++) {
      final double pointProgress = i / (pts.length - 1);
      if (progress < pointProgress) break;

      final double alpha = ((progress - pointProgress) / 0.12).clamp(0.0, 1.0);

      canvas.drawCircle(
        pts[i],
        4.0,
        Paint()
          ..color = const Color(0xFF22C55E).withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawCircle(
        pts[i],
        2.2,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }

    // Keep the pulsing tip attached to the actual end of the drawn curve.
    // At 100%, this lands precisely on the final data point.
    if (progress > 0.0) {
      final Tangent? tangent = metric.getTangentForOffset(
        drawnLength.clamp(0.0, metric.length),
      );
      if (tangent != null) {
        final Offset tip = tangent.position;

        canvas.drawCircle(
          tip,
          7.0 + pulseValue * 3,
          Paint()
            ..color = const Color(0xFF22C55E).withValues(alpha: 0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawCircle(tip, 4.0, Paint()..color = const Color(0xFF22C55E));
        canvas.drawCircle(tip, 2.0, Paint()..color = Colors.white);
      }
    }
  }

  // ── Axis Decoration and Guide Lines ───────────────────────────────────────
  void _drawAxisDecor(Canvas canvas, Size size) {
    if (bgFade < 0.3) return;
    final double a = ((bgFade - 0.3) / 0.7).clamp(0.0, 1.0);
    final Paint axisPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.05 * a)
          ..strokeWidth = 1.0;

    final double left = size.width * 0.06;
    final double right = size.width * 0.94;
    final double bottom = size.height * 0.95;
    final double chartH = size.height * 0.20;

    for (int i = 1; i <= 3; i++) {
      final double y = bottom - chartH * (i / 3);
      canvas.drawLine(Offset(left, y), Offset(right, y), axisPaint);
    }

    if (barsProgress > 0.35) {
      final double la = ((barsProgress - 0.35) / 0.65).clamp(0.0, 1.0);
      // Left-align the chart heading with the chart's left edge.
      _drawText(
        canvas,
        "MONTHLY PERFORMANCE",
        Offset(left + 8, bottom - chartH - 17),
        size: 8.2,
        bold: true,
        alpha: 0.30 * la,
        leftAligned: true,
        letterSpacing: 1.3,
      );
    }
  }

  // ── Text Helper ───────────────────────────────────────────────────────────
  void _drawText(
    Canvas canvas,
    String text,
    Offset position, {
    required double size,
    required bool bold,
    required double alpha,
    bool centered = false,
    bool leftAligned = false,
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
      leftAligned
          ? Offset(position.dx, position.dy - tp.height / 2)
          : centered
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
