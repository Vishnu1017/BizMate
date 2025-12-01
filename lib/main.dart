import 'dart:async';
import 'dart:io';
import 'package:bizmate/models/user_model.dart';
import 'package:bizmate/models/sale.dart';
import 'package:bizmate/models/product.dart';
import 'package:bizmate/models/payment.dart';
import 'package:bizmate/models/rental_item.dart';
import 'package:bizmate/models/customer_model.dart';
import 'package:bizmate/models/rental_sale_model.dart';
import 'package:bizmate/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/responsive.dart'; // ⭐ ADDED

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
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

/// ------------------------------------------------------
/// HIVE INITIALIZATION
/// ------------------------------------------------------
Future<void> _initializeHive() async {
  try {
    await Hive.initFlutter();
    final appDocDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocDir.path);

    _registerAdapters();

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
    // await _deleteAllHiveBoxes();
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
    await Hive.deleteBoxFromDisk(name);
    return await Hive.openBox<T>(name);
  }
}

Future<void> _initializeDefaultProfileImage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profileImagePath');

    if (imagePath == null || !await File(imagePath).exists()) {
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Responsive.init(context); // ⭐ GLOBAL MEDIAQUERY INITIALIZED HERE
        });

        return const MaterialApp(
          title: 'Click Account',
          debugShowCheckedModeBanner: false,
          home: CustomSplashScreen(),
        );
      },
    );
  }
}

class CustomSplashScreen extends StatefulWidget {
  const CustomSplashScreen({super.key});

  @override
  State<CustomSplashScreen> createState() => _CustomSplashScreenState();
}

class _CustomSplashScreenState extends State<CustomSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    Timer(const Duration(seconds: 3), () {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen()));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF00BCD4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _animation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/bizmate_logo.JPG',
                    width: 130,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "BizMate",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
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
