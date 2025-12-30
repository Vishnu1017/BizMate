// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:bizmate/models/user_model.dart';
import 'package:bizmate/widgets/advanced_search_bar.dart'
    show AdvancedSearchBar;
import 'package:bizmate/widgets/app_snackbar.dart';
import 'package:bizmate/widgets/confirm_delete_dialog.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sale.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key, required String userEmail});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  List<Map<String, String>> customers = [];
  List<Map<String, String>> filteredCustomers = [];
  String _searchQuery = "";
  String profileName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchUniqueCustomers();
      _loadProfileName();
    });
  }

  // ------------------- SEARCH -------------------
  void _handleSearchChanged(String query) {
    _searchQuery = query;
    _filterCustomers();
    setState(() {});
  }

  void _handleDateRangeChanged(DateTimeRange? range) {
    _filterCustomers();
    setState(() {});
  }

  void _filterCustomers() {
    if (_searchQuery.isEmpty) {
      filteredCustomers = List.from(customers);
    } else {
      final q = _searchQuery.toLowerCase();
      filteredCustomers =
          customers.where((c) {
            return (c['name'] ?? "").toLowerCase().contains(q) ||
                (c['phone'] ?? "").toLowerCase().contains(q);
          }).toList();
    }
  }

  // ------------------- LOAD CUSTOMERS -------------------
  void fetchUniqueCustomers() async {
    if (!Hive.isBoxOpen('session')) {
      await Hive.openBox('session');
    }
    final sessionBox = Hive.box('session');
    final email = sessionBox.get('currentUserEmail');

    if (email == null) {
      customers = [];
      filteredCustomers = [];
      setState(() {});
      return;
    }

    final safeEmail = email.replaceAll('.', '_').replaceAll('@', '_');
    if (!Hive.isBoxOpen('userdata_$safeEmail')) {
      await Hive.openBox('userdata_$safeEmail');
    }
    final userBox = Hive.box('userdata_$safeEmail');

    List<Sale> sales = List<Sale>.from(userBox.get("sales", defaultValue: []));

    final seen = <String>{};
    final uniqueList = <Map<String, String>>[];

    for (var sale in sales) {
      final key = "${sale.customerName}_${sale.phoneNumber}";
      if (!seen.contains(key)) {
        seen.add(key);
        uniqueList.add({
          'name': sale.customerName.trim(),
          'phone': sale.phoneNumber.trim(),
        });
      }
    }

    customers = uniqueList;
    filteredCustomers = List.from(uniqueList);
    setState(() {});
  }

  Future<void> _loadProfileName() async {
    final sessionBox = await Hive.openBox('session');
    final email = sessionBox.get('currentUserEmail');

    if (email == null) return;

    final userBox = Hive.box<User>('users');

    User? user;

    try {
      user = userBox.values.firstWhere((u) => u.email == email);
    } catch (_) {
      user = null;
    }

    if (mounted && user != null && user.name.trim().isNotEmpty) {
      setState(() {
        profileName = user!.name.trim(); // ✅ PROFILE NAME ONLY
      });
    }
  }

  // ------------------- ALL EXISTING FUNCTIONS BELOW UNCHANGED -------------------
  // (generateAndShareAgreementPDF, _confirmDelete, _deleteCustomer,
  //  _makePhoneCall, _openWhatsApp, _buildPopupItem etc.)
  // -------------------------------------------------------------

  Future<void> generateAndShareAgreementPDF(String customerName) async {
    final pdf = pw.Document();
    final currentDate = DateFormat('MMMM dd, yyyy').format(DateTime.now());
    final sender = profileName;

    checkbox(String label) => pw.Row(
      children: [
        pw.Container(
          width: 12,
          height: 12,
          decoration: pw.BoxDecoration(border: pw.Border.all()),
        ),
        pw.SizedBox(width: 8),
        pw.Text(label),
      ],
    );

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(32),
        build:
            (_) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'PHOTOGRAPHY USAGE RELEASE AGREEMENT',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('This agreement is made on $currentDate between:'),
                pw.SizedBox(height: 12),
                pw.Text('PHOTOGRAPHER: Vishnu Chandan'),
                pw.Text('BUSINESS: $sender'),
                pw.Text('CLIENT: $customerName'),
                pw.Divider(thickness: 1.2),
                pw.SizedBox(height: 20),

                pw.Text(
                  '1. USAGE RIGHTS',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'The client grants permission to the photographer to use photographs in the following formats:',
                ),
                pw.SizedBox(height: 10),
                checkbox('Instagram'),
                pw.SizedBox(height: 5),
                checkbox('Facebook'),
                pw.SizedBox(height: 5),
                checkbox('Website / Portfolio'),
                pw.SizedBox(height: 5),
                checkbox('Marketing Materials'),
                pw.SizedBox(height: 5),
                checkbox('Other (specify): _______________'),

                pw.SizedBox(height: 20),

                pw.Text(
                  '2. RESTRICTIONS',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Bullet(text: 'Defamatory or explicit content'),
                pw.Bullet(text: 'Political/religious endorsements'),

                pw.SizedBox(height: 20),

                pw.Text(
                  '3. CLIENT ACKNOWLEDGEMENT',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text('I confirm I have read and understood this agreement.'),
                pw.SizedBox(height: 20),
                pw.Text('Name: __________________'),
                pw.SizedBox(height: 10),
                pw.Text('Signature: ______________'),
                pw.SizedBox(height: 10),
                pw.Text('Date: __________________'),

                pw.Spacer(),
                pw.Divider(),
                pw.Center(
                  child: pw.Text(
                    'Thank you for choosing $sender!',
                    style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
                  ),
                ),
              ],
            ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/${customerName.replaceAll(" ", "_")}_release.pdf',
    );
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<bool> _confirmDelete(int index) async {
    bool confirmed = false;
    await showConfirmDialog(
      context: context,
      title: "Confirm Deletion",
      message: "Delete all sales by ${filteredCustomers[index]['name']}?",
      icon: Icons.warning_amber,
      iconColor: Colors.redAccent,
      onConfirm: () => confirmed = true,
    );
    return confirmed;
  }

  void _deleteCustomer(int index) async {
    final sessionBox = await Hive.openBox('session');
    final email = sessionBox.get('currentUserEmail');
    final safeEmail = email.replaceAll('.', '_').replaceAll('@', '_');
    final userBox = await Hive.openBox('userdata_$safeEmail');

    List<Sale> sales = List<Sale>.from(userBox.get("sales", defaultValue: []));
    final target = filteredCustomers[index];

    sales.removeWhere(
      (sale) =>
          sale.customerName == target['name'] &&
          sale.phoneNumber == target['phone'],
    );

    await userBox.put("sales", sales);
    fetchUniqueCustomers();
  }

  void _makePhoneCall(String phone) async {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (!cleaned.startsWith('+') && cleaned.length == 10)
      cleaned = '+91$cleaned';

    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  void _openWhatsApp(String phone, String name, {String? purpose}) async {
    try {
      // ✅ Normalize phone (supports +91 / spaces)
      String raw = phone.replaceAll(RegExp(r'[^\d+]'), '');
      String waPhone;
      final sender = profileName;

      if (raw.startsWith('+')) {
        waPhone = raw.substring(1);
      } else if (raw.length == 10) {
        waPhone = '91$raw';
      } else {
        waPhone = raw;
      }

      if (waPhone.length < 10) {
        AppSnackBar.showWarning(
          context,
          message: "Invalid phone number",
          duration: const Duration(seconds: 2),
        );
        return;
      }

      // ✅ DIFFERENT MESSAGES BASED ON OPTION
      late String message;

      switch (purpose) {
        case 'feedback':
          message =
              "Hello $name,\n\n"
              "Thank you for choosing $sender.\n\n"
              "We’d love to hear your feedback about your experience with us. "
              "Your feedback helps us improve and serve you better.\n\n"
              "Warm regards,\n$sender";
          break;

        case 'payment_received':
          message =
              "Hello $name,\n\n"
              "We have successfully received your payment.\n\n"
              "Thank you for choosing $sender. "
              "Please feel free to contact us if you need the invoice or any further assistance.\n\n"
              "Warm regards,\n$sender";
          break;

        case 'booking_confirmation':
          message =
              "Hello $name,\n\n"
              "Your booking with $sender has been successfully confirmed.\n\n"
              "We’ll coordinate with you closer to the scheduled date. "
              "If you have any requirements or questions, feel free to reach out.\n\n"
              "Warm regards,\n$sender";
          break;

        // ✅ DEFAULT
        default:
          message =
              "Hello $name,\n\n"
              "This is $sender.\n\n"
              "How can we assist you today?\n\n"
              "Warm regards,\n$sender";
      }

      final encoded = Uri.encodeComponent(message);
      final uri = Uri.parse("https://wa.me/$waPhone?text=$encoded");

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception("WhatsApp not available");
      }
    } catch (_) {
      AppSnackBar.showError(
        context,
        message: "Couldn't open WhatsApp",
        duration: const Duration(seconds: 2),
      );
    }
  }

  Widget _buildPopupItem({
    IconData? icon,
    IconData? faIcon,
    required Color color,
    required String text,
    required bool isSmallScreen,
  }) {
    return Row(
      children: [
        faIcon != null
            ? FaIcon(faIcon, color: color, size: isSmallScreen ? 16 : 20)
            : Icon(icon, color: color, size: isSmallScreen ? 18 : 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 14,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  // ============================ BUILD ============================

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    double scale =
        w < 360
            ? 0.80
            : w < 480
            ? 0.90
            : w < 700
            ? 1.00
            : w < 1100
            ? 1.15
            : 1.30;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: MediaQuery.removePadding(
        removeTop: true,
        context: context,
        child: Column(
          children: [
            AdvancedSearchBar(
              hintText: 'Search customers...',
              onSearchChanged: _handleSearchChanged,
              onDateRangeChanged: _handleDateRangeChanged,
              showDateFilter: false,
            ),

            Expanded(
              child:
                  filteredCustomers.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 80 * scale,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16 * scale),
                            Text(
                              _searchQuery.isEmpty
                                  ? "No Customers Yet"
                                  : "No matching customers found",
                              style: TextStyle(
                                fontSize: 18 * scale,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14 * scale,
                          vertical: 6 * scale,
                        ),
                        itemCount: filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final name = filteredCustomers[index]['name'] ?? '';
                          final phone = filteredCustomers[index]['phone'] ?? '';
                          final initials =
                              name.isNotEmpty
                                  ? name
                                      .split(' ')
                                      .map((e) => e[0])
                                      .join()
                                      .toUpperCase()
                                  : "?";

                          return Dismissible(
                            key: Key(name + index.toString()),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) => _confirmDelete(index),
                            onDismissed: (_) => _deleteCustomer(index),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: EdgeInsets.symmetric(
                                horizontal: 20 * scale,
                              ),
                              margin: EdgeInsets.only(bottom: 14 * scale),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12 * scale),
                              ),
                              child: Icon(
                                Icons.delete,
                                color: Colors.white,
                                size: 30 * scale,
                              ),
                            ),
                            child: Container(
                              margin: EdgeInsets.only(bottom: 14 * scale),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF00BCD4),
                                    Color(0xFF1A237E),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12 * scale),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 10 * scale,
                                    offset: Offset(0, 4 * scale),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16 * scale,
                                  vertical: 12 * scale,
                                ),
                                leading: CircleAvatar(
                                  radius: 22 * scale,
                                  backgroundColor: Colors.white,
                                  child: Text(
                                    initials,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16 * scale,
                                      color: const Color(0xFF1A237E),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 15 * scale,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  phone,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.5 * scale,
                                  ),
                                ),
                                trailing: Wrap(
                                  runSpacing: 4 * scale,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.phone,
                                        size: 20 * scale,
                                        color: Colors.white,
                                      ),
                                      onPressed: () => _makePhoneCall(phone),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: Icon(
                                        FontAwesomeIcons.whatsapp,
                                        size: 20 * scale,
                                        color: Colors.white,
                                      ),
                                      itemBuilder: (context) {
                                        final isSmallScreen = w < 400;
                                        return [
                                          PopupMenuItem(
                                            value: 'default',
                                            child: _buildPopupItem(
                                              icon: Icons.chat,
                                              color: Colors.blue,
                                              text: "General Inquiry",
                                              isSmallScreen: isSmallScreen,
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'feedback',
                                            child: _buildPopupItem(
                                              icon: Icons.feedback_rounded,
                                              color: Colors.purple,
                                              text: "Feedback",
                                              isSmallScreen: isSmallScreen,
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'booking_confirmation',
                                            child: _buildPopupItem(
                                              icon: Icons.event_available,
                                              color: Colors.indigo,
                                              text: "Booking Confirmation",
                                              isSmallScreen: isSmallScreen,
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'payment_received',
                                            child: _buildPopupItem(
                                              icon: Icons.check_circle,
                                              color: Colors.green,
                                              text: "Payment Received",
                                              isSmallScreen: isSmallScreen,
                                            ),
                                          ),

                                          PopupMenuItem(
                                            value: 'agreement',
                                            child: _buildPopupItem(
                                              icon: Icons.picture_as_pdf,
                                              color: Colors.teal,
                                              text: "Send Release Agreement",
                                              isSmallScreen: isSmallScreen,
                                            ),
                                          ),
                                        ];
                                      },
                                      onSelected: (p) {
                                        if (p == 'agreement') {
                                          generateAndShareAgreementPDF(name);
                                        } else {
                                          _openWhatsApp(
                                            phone,
                                            name,
                                            purpose: p,
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
