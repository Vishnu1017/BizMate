// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:bizmate/widgets/confirm_delete_dialog.dart'
    show showConfirmDialog;
import 'package:bizmate/widgets/advanced_search_bar.dart'
    show AdvancedSearchBar;
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

  @override
  void initState() {
    super.initState();
    fetchUniqueCustomers();
  }

  void _handleSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filterCustomers();
    });
  }

  void _handleDateRangeChanged(DateTimeRange? range) {
    setState(() {
      _filterCustomers();
    });
  }

  void _filterCustomers() {
    if (_searchQuery.isEmpty) {
      filteredCustomers = List.from(customers);
    } else {
      filteredCustomers =
          customers.where((customer) {
            final name = customer['name']?.toLowerCase() ?? '';
            final phone = customer['phone']?.toLowerCase() ?? '';
            final query = _searchQuery.toLowerCase();
            return name.contains(query) || phone.contains(query);
          }).toList();
    }
  }

  void fetchUniqueCustomers() async {
    // Load logged-in user's email
    final sessionBox = await Hive.openBox('session');
    final email = sessionBox.get('currentUserEmail');

    if (email == null) {
      setState(() {
        customers = [];
        filteredCustomers = [];
      });
      return;
    }

    // Open user-specific box
    final safeEmail = email.replaceAll('.', '_').replaceAll('@', '_');
    final userBox = await Hive.openBox('userdata_$safeEmail');

    // Read user-specific sales
    List<Sale> sales = List<Sale>.from(userBox.get("sales", defaultValue: []));

    final Set<String> seen = {};
    final List<Map<String, String>> uniqueList = [];

    for (var sale in sales) {
      final key = "${sale.customerName}_${sale.phoneNumber}";

      if (!seen.contains(key)) {
        seen.add(key);
        uniqueList.add({'name': sale.customerName, 'phone': sale.phoneNumber});
      }
    }

    setState(() {
      customers = uniqueList;
      filteredCustomers = List.from(uniqueList);
    });
  }

  // All your existing methods remain unchanged below this point
  // (generateAndShareAgreementPDF, _confirmDelete, _deleteCustomer,
  // _makePhoneCall, _openWhatsApp, _buildPopupItem, etc.)

  Future<void> generateAndShareAgreementPDF(String customerName) async {
    final pdf = pw.Document();
    final currentDate = DateFormat('MMMM dd, yyyy').format(DateTime.now());

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
        margin: pw.EdgeInsets.all(32),
        build:
            (pw.Context context) => pw.Column(
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
                pw.Text('BUSINESS: Shutter Life Photography'),
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
                checkbox('Marketing Materials (posters, flyers, etc.)'),
                pw.SizedBox(height: 5),
                checkbox(
                  'Other Social Media (please specify): ____________________',
                ),

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
                pw.Text(
                  'Photographer agrees NOT to use photographs for the following:',
                ),
                pw.Bullet(text: 'Defamatory, explicit, or harmful content'),
                pw.Bullet(text: 'Political or religious endorsements'),

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
                pw.Text(
                  'I, the undersigned client, confirm that I have read and understood this release agreement.',
                ),
                pw.SizedBox(height: 20),
                pw.Text('Name: ________________________________'),
                pw.SizedBox(height: 10),
                pw.Text('Signature: _____________________________'),
                pw.SizedBox(height: 10),
                pw.Text('Date: _________________________________'),

                pw.Spacer(),

                pw.Divider(),
                pw.Center(
                  child: pw.Text(
                    'Thank you for choosing Shutter Life Photography!',
                    style: pw.TextStyle(
                      fontStyle: pw.FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final fileName =
        'PHOTOGRAPHY_USAGE_RELEASE_AGREEMENT_${customerName.replaceAll(' ', '_')}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Photography Usage Release Agreement for $customerName');
  }

  Future<bool> _confirmDelete(int index) async {
    bool confirmed = false;

    await showConfirmDialog(
      context: context,
      title: "Confirm Deletion",
      message: "Delete all sales by ${filteredCustomers[index]['name']}?",
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.redAccent,
      onConfirm: () {
        confirmed = true;
      },
    );

    return confirmed;
  }

  void _deleteCustomer(int index) async {
    final sessionBox = await Hive.openBox('session');
    final email = sessionBox.get('currentUserEmail');

    final safeEmail = email.replaceAll('.', '_').replaceAll('@', '_');
    final userBox = await Hive.openBox('userdata_$safeEmail');

    // Load all sales
    List<Sale> sales = List<Sale>.from(userBox.get("sales", defaultValue: []));

    final customerToDelete = filteredCustomers[index];

    // Keep only sales that DO NOT match the deleted customer
    sales.removeWhere(
      (sale) =>
          sale.customerName == customerToDelete['name'] &&
          sale.phoneNumber == customerToDelete['phone'],
    );

    // Save updated list
    await userBox.put("sales", sales);

    // Refresh UI
    fetchUniqueCustomers();
  }

  void _makePhoneCall(String phone) async {
    // Clean the phone number - remove all non-digit characters
    String cleanedPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');

    // Add +91 prefix if it's a 10-digit Indian number without country code
    if (!cleanedPhone.startsWith('+') && cleanedPhone.length == 10) {
      cleanedPhone = '+91$cleanedPhone';
    }

    final uri = Uri.parse('tel:$cleanedPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $uri';
    }
  }

  void _openWhatsApp(String phone, String name, {String? purpose}) async {
    try {
      final cleanedPhone = phone.replaceAll(' ', '');

      if (cleanedPhone.length < 10 ||
          !RegExp(r'^[0-9]+$').hasMatch(cleanedPhone)) {
        AppSnackBar.showWarning(
          context,
          message: "Please enter a valid 10-digit phone number",
          duration: Duration(seconds: 2),
        );
        return;
      }

      final customerName = name.isNotEmpty ? name : "there";

      String message =
          "Hi $customerName! This is Shutter Life Photography. How can we help you today?";

      if (purpose != null) {
        switch (purpose) {
          case 'followup':
            message =
                "Hi $customerName! 👋\n\nThis is Shutter Life Photography following up on your recent experience with us. "
                "Please let us know if you need any assistance or have any questions!\n\n"
                "We appreciate your business! ❤️";
            break;

          case 'feedback':
            message =
                "Dear $customerName,\n\nThank you for choosing Shutter Life Photography! 🌟\n\n"
                "We would truly value your feedback about your recent experience with us. "
                "Your thoughts help us serve you better!\n\n"
                "Please leave your review here: https://g.page/r/CZdlwsr8XKiUEBM/review\n\n"
                "Warm regards,\nThe Shutter Life Team";
            break;

          case 'promo':
            message =
                "Hello $customerName! 🎉\n\nShutter Life Photography has an exclusive offer just for you:\n\n"
                "✨ 15% OFF your next photo session\n"
                "📸 Free 8x10 print with every booking\n"
                "🎁 Referral bonuses available\n\n"
                "Limited time offer - book now!";
            break;

          case 'instagram_promo':
            message =
                "Hi $customerName! 😊\n\n"
                "Want to see our latest work? 📸\n"
                "Check out our Instagram for stunning shots from weddings, baby shoots, maternity, and more! 💖\n"
                "👉 https://www.instagram.com/shutter_life_photography\n\n"
                "Let us know what style you love most! 😊";
            break;

          case 'payment_confirmation':
            message =
                "Hi $customerName! 🎉\n\n"
                "Payment received ✅ & your booking is now locked in! 🥳\n\n"
                "We can't wait to capture your moments with love and lens! 🎞️📷\n\n"
                "*– Team Shutter Life Photography*";
            break;

          default:
            message =
                "Hello $customerName! 👋\n\nThank you for contacting Shutter Life Photography. "
                "How may we assist you today?";
        }
      }

      final url1 =
          "https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(message)}";
      final url2 =
          "https://wa.me/91$cleanedPhone?text=${Uri.encodeComponent(message)}";

      canLaunchUrl(Uri.parse(url1)).then((canLaunch) {
        if (canLaunch) {
          launchUrl(Uri.parse(url1), mode: LaunchMode.externalApplication);
        } else {
          launchUrl(Uri.parse(url2), mode: LaunchMode.externalApplication);
        }
      });
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF4F6FA),
      body: Column(
        children: [
          AdvancedSearchBar(
            hintText: 'Search customers...',
            onSearchChanged: _handleSearchChanged,
            onDateRangeChanged: _handleDateRangeChanged,
            showDateFilter: false, // No date filter needed for customers page
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
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? "No Customers Yet"
                                : "No matching customers found",
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
                      itemCount: filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = filteredCustomers[index];
                        final name = customer['name'] ?? '';
                        final phone = customer['phone'] ?? '';
                        final initials =
                            name
                                .split(' ')
                                .map((e) => e.isNotEmpty ? e[0] : '')
                                .join()
                                .toUpperCase();

                        return Dismissible(
                          key: Key(name + index.toString()),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmDelete(index),
                          onDismissed: (_) => _deleteCustomer(index),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            margin: EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.delete,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          child: Container(
                            margin: EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF00BCD4), Color(0xFF1A237E)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: Colors.white,
                                child: Text(
                                  initials,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A237E),
                                  ),
                                ),
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                phone,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              trailing: Wrap(
                                spacing: 0,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.phone,
                                      color: Colors.white,
                                    ),
                                    onPressed: () => _makePhoneCall(phone),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(
                                      FontAwesomeIcons.whatsapp,
                                      color: Colors.white,
                                    ),
                                    itemBuilder: (context) {
                                      final width =
                                          MediaQuery.of(context).size.width;
                                      final isSmallScreen = width < 400;

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
                                          value: 'followup',
                                          child: _buildPopupItem(
                                            icon: Icons.update,
                                            color: Colors.orange,
                                            text: "Follow Up",
                                            isSmallScreen: isSmallScreen,
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'feedback',
                                          child: _buildPopupItem(
                                            icon: Icons.feedback,
                                            color: Colors.purple,
                                            text: "Feedback Request",
                                            isSmallScreen: isSmallScreen,
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'promo',
                                          child: _buildPopupItem(
                                            icon: Icons.local_offer,
                                            color: Colors.red,
                                            text: "Special Offer",
                                            isSmallScreen: isSmallScreen,
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'instagram_promo',
                                          child: _buildPopupItem(
                                            faIcon: FontAwesomeIcons.instagram,
                                            color: Colors.pink,
                                            text: "Instagram Promotion",
                                            isSmallScreen: isSmallScreen,
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'payment_confirmation',
                                          child: _buildPopupItem(
                                            icon: Icons.verified_rounded,
                                            color: Colors.green,
                                            text: "Payment Confirmation",
                                            isSmallScreen: isSmallScreen,
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'release_agreement_pdf',
                                          child: _buildPopupItem(
                                            icon: Icons.picture_as_pdf,
                                            color: Colors.teal,
                                            text: "Send Release Agreement PDF",
                                            isSmallScreen: isSmallScreen,
                                          ),
                                        ),
                                      ];
                                    },
                                    onSelected: (purpose) {
                                      if (purpose == 'release_agreement_pdf') {
                                        generateAndShareAgreementPDF(name);
                                      } else {
                                        _openWhatsApp(
                                          phone,
                                          name,
                                          purpose: purpose,
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
    );
  }
}
