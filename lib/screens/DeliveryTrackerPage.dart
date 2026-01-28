// lib/screens/delivery_tracker_page.dart
import 'dart:convert' show jsonEncode, jsonDecode;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart' show HugeIcon, HugeIcons;
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:bizmate/models/sale.dart';

/// DeliveryTrackerPage - fully responsive, polished and production-ready.
/// Combines responsive helper functions, an iOS-style large title header,
/// safe animations, and careful layout to avoid RenderFlex overflow.
class DeliveryTrackerPage extends StatefulWidget {
  final Sale sale;
  final String phoneWithCountryCode;
  final String phoneWithoutCountryCode;

  const DeliveryTrackerPage({
    super.key,
    required this.sale,
    required this.phoneWithCountryCode,
    required this.phoneWithoutCountryCode,
  });

  @override
  State<DeliveryTrackerPage> createState() => _DeliveryTrackerPageState();
}

// ------------------------- Responsive helper -------------------------
class _R {
  final double width;
  final double height;
  late final double scale;

  _R(this.width, this.height) {
    // Breakpoints tuned for phones, phablets, tablets, desktop
    scale =
        width < 360
            ? 0.88
            : width < 420
            ? 0.95
            : width < 600
            ? 1.0
            : width < 900
            ? 1.12
            : 1.25;
  }

  double sp(double size) => size * scale; // spacing/radius
  double fp(double size) => size * scale; // font
  double ip(double size) => size * scale; // icon
}

class _DeliveryTrackerPageState extends State<DeliveryTrackerPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _statusNotesController = TextEditingController();
  String _ownerName = '';
  String _ownerPhone = '';
  double scale = 1.0;

  String? _selectedStatus;
  final List<String> statuses = [
    'All Non Editing Images',
    'Editing',
    'Printed',
    'Delivered',
  ];

  final Map<String, Color> _statusColors = {
    'All Non Editing Images': const Color(0xFF1E40AF),
    'Editing': const Color(0xFFF6AD55),
    'Printed': const Color(0xFF9F7AEA),
    'Delivered': const Color(0xFF48BB78),
  };

  final Map<String, IconData> _statusIcons = {
    'All Non Editing Images': Icons.cloud_queue_rounded,
    'Editing': Icons.auto_fix_high_rounded,
    'Printed': Icons.local_printshop_rounded,
    'Delivered': Icons.verified_rounded,
  };

  final Map<String, String> _statusNoteSuggestions = {
    'All Non Editing Images':
        'Non-edited photos are ready for download. Final edited versions will be shared separately once completed.',
    'Editing':
        'Photos are currently being edited. We\'ll notify you when they\'re ready for review.',
    'Printed': 'Photos have been printed and are being prepared for delivery.',
    'Delivered': 'Photos have been successfully delivered to the customer.',
  };

  List<Map<String, dynamic>> deliveryStatusHistory = [];
  String _previousSuggestion = '';

  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  int? _invoiceNumber;
  final bool _isSendingWhatsApp = false;
  bool _isSaving = false;

  // Store the Hive key separately
  int? _hiveKey;

  // A key used if we later need to measure the header/search bar etc.
  final GlobalKey _pageKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.fastOutSlowIn,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );

    _animationController.forward();

    _linkController.text = widget.sale.deliveryLink;
    _selectedStatus =
        (widget.sale.deliveryStatus.isNotEmpty)
            ? widget.sale.deliveryStatus
            : statuses.first;

    // Initialize delivery status history
    _initializeDeliveryHistory();

    _updateStatusNoteSuggestion();
    _loadHiveData();
    _loadProfileUser();
  }

  Future<void> _loadProfileUser() async {
    try {
      final sessionBox = await Hive.openBox('session');
      final email = sessionBox.get('currentUserEmail');

      if (email == null) return;

      final userBox = Hive.box('users');

      dynamic user;
      try {
        user = userBox.values.firstWhere((u) => u.email == email);
      } catch (_) {
        user = null;
      }

      if (mounted && user != null) {
        setState(() {
          _ownerName = (user.name ?? '').toString();
          _ownerPhone = (user.phone ?? '').toString();
        });
      }
    } catch (_) {
      // silent – app should never crash
    }
  }

  void _initializeDeliveryHistory() {
    if (widget.sale.deliveryStatusHistory == null ||
        widget.sale.deliveryStatusHistory!.isEmpty) {
      deliveryStatusHistory = [
        {
          'status': 'Order Received',
          'dateTime': widget.sale.dateTime.toIso8601String(),
          'notes': 'Order has been received and is being processed',
        },
      ];
    } else {
      try {
        deliveryStatusHistory =
            widget.sale.deliveryStatusHistory!
                .map((e) => jsonDecode(e) as Map<String, dynamic>)
                .toList();
      } catch (e) {
        deliveryStatusHistory = [
          {
            'status': 'Order Received',
            'dateTime': widget.sale.dateTime.toIso8601String(),
            'notes': 'Order has been received and is being processed',
          },
        ];
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_animationController.isAnimating) {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _linkController.dispose();
    _statusNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadHiveData() async {
    try {
      final salesBox = await Hive.openBox<Sale>('sales');

      // Try to find the sale in Hive and get its key
      final index = salesBox.values.toList().indexWhere((sale) {
        return sale.customerName == widget.sale.customerName &&
            sale.phoneNumber == widget.sale.phoneNumber &&
            sale.dateTime == widget.sale.dateTime &&
            sale.totalAmount == widget.sale.totalAmount;
      });

      if (mounted && index != -1) {
        final keys = salesBox.keys.toList();
        _hiveKey = keys[index] as int?;

        // Also load invoice number
        setState(() {
          _invoiceNumber = index + 1;
        });

        // If found, update our sale with the Hive version's delivery info
        final hiveSale = salesBox.get(_hiveKey);
        if (hiveSale != null) {
          // Update controllers with Hive data
          _linkController.text = hiveSale.deliveryLink;
          _selectedStatus =
              hiveSale.deliveryStatus.isNotEmpty
                  ? hiveSale.deliveryStatus
                  : statuses.first;

          // Update delivery history from Hive
          if (hiveSale.deliveryStatusHistory != null &&
              hiveSale.deliveryStatusHistory!.isNotEmpty) {
            try {
              deliveryStatusHistory =
                  hiveSale.deliveryStatusHistory!
                      .map((e) => jsonDecode(e) as Map<String, dynamic>)
                      .toList();
            } catch (e) {
              // Keep existing history if parsing fails
            }
          }

          _updateStatusNoteSuggestion();
        }
      } else {
        // Sale not found in Hive, use default invoice numbering
        final allSales = salesBox.values.toList();
        setState(() {
          _invoiceNumber = allSales.length + 1;
        });
      }
    } catch (_) {
      // silent in production
    }
  }

  void _updateStatusNoteSuggestion() {
    if (_selectedStatus != null &&
        _statusNoteSuggestions.containsKey(_selectedStatus) &&
        (_statusNotesController.text.isEmpty ||
            _statusNotesController.text == _previousSuggestion)) {
      _previousSuggestion = _statusNoteSuggestions[_selectedStatus]!;
      _statusNotesController.text = _previousSuggestion;
    }
  }

  Future<void> _saveDeliveryDetails() async {
    if (_selectedStatus == null) {
      AppSnackBar.showWarning(
        context,
        message: 'Please select a status',
        duration: const Duration(seconds: 2),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Update local sale object
      widget.sale.deliveryLink = _linkController.text.trim();
      widget.sale.deliveryStatus = _selectedStatus!;

      // Update delivery status history
      bool shouldAddToHistory = true;
      if (deliveryStatusHistory.isNotEmpty) {
        final lastStatus = deliveryStatusHistory.first['status'];
        if (lastStatus == _selectedStatus) {
          deliveryStatusHistory[0] = {
            'status': _selectedStatus!,
            'dateTime': DateTime.now().toIso8601String(),
            'notes': _statusNotesController.text.trim(),
          };
          shouldAddToHistory = false;
        }
      }

      if (shouldAddToHistory) {
        deliveryStatusHistory.insert(0, {
          'status': _selectedStatus!,
          'dateTime': DateTime.now().toIso8601String(),
          'notes': _statusNotesController.text.trim(),
        });
      }

      widget.sale.deliveryStatusHistory =
          deliveryStatusHistory.map((e) => jsonEncode(e)).toList();

      // Get the Hive box
      final salesBox = await Hive.openBox<Sale>('sales');

      if (_hiveKey != null) {
        // We have a Hive key, update the existing sale
        final existingSale = salesBox.get(_hiveKey);
        if (existingSale != null) {
          existingSale.deliveryStatus = widget.sale.deliveryStatus;
          existingSale.deliveryLink = widget.sale.deliveryLink;
          existingSale.deliveryStatusHistory =
              widget.sale.deliveryStatusHistory;

          await existingSale.save();
        } else {
          // Key exists but sale doesn't? This shouldn't happen, but handle it
          await _saveAsNewSale(salesBox);
        }
      } else {
        // No Hive key, try to find by properties
        await _saveByFindingSale(salesBox);
      }

      if (!mounted) return;

      AppSnackBar.showSuccess(
        context,
        message: 'Delivery updated successfully',
        duration: const Duration(seconds: 2),
      );

      // ✅ Go back after save
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          Navigator.pop(context, true); // return success
        }
      });
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        AppSnackBar.showError(
          context,
          message: 'Failed to save: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveByFindingSale(Box<Sale> salesBox) async {
    try {
      // Find the existing sale by matching properties
      final existingSaleIndex = salesBox.values.toList().indexWhere(
        (s) =>
            s.customerName == widget.sale.customerName &&
            s.phoneNumber == widget.sale.phoneNumber &&
            s.dateTime == widget.sale.dateTime &&
            s.totalAmount == widget.sale.totalAmount,
      );

      if (existingSaleIndex != -1) {
        // Get the actual key
        final keys = salesBox.keys.toList();
        final saleKey = keys[existingSaleIndex] as int;

        // Get the Hive-managed sale
        final hiveSale = salesBox.get(saleKey);
        if (hiveSale != null) {
          // Update the Hive-managed sale
          hiveSale.deliveryStatus = widget.sale.deliveryStatus;
          hiveSale.deliveryLink = widget.sale.deliveryLink;
          hiveSale.deliveryStatusHistory = widget.sale.deliveryStatusHistory;

          // Save the Hive-managed sale
          await hiveSale.save();

          // Store the key for future saves
          _hiveKey = saleKey;
        }
      } else {
        // This is a new sale, add it to Hive
        await _saveAsNewSale(salesBox);
      }
    } catch (e) {
      debugPrint("Error finding existing sale in Hive: $e");
      // Fallback: Save as new sale
      await _saveAsNewSale(salesBox);
    }
  }

  Future<void> _saveAsNewSale(Box<Sale> salesBox) async {
    final newKey = await salesBox.add(widget.sale);
    _hiveKey = newKey;
  }

  void _sendWhatsApp() {
    final customerName =
        widget.sale.customerName.isNotEmpty
            ? widget.sale.customerName
            : "Customer";
    final deliveryStatus = _selectedStatus ?? 'Ready';
    final deliveryLink =
        _linkController.text.isNotEmpty
            ? _linkController.text
            : 'Link not available';
    final phone = widget.sale.phoneNumber.replaceAll(' ', '');

    if (phone.length < 10 || !RegExp(r'^[0-9]+$').hasMatch(phone)) {
      AppSnackBar.showWarning(
        context,
        message: "Please enter a valid 10-digit phone number",
        duration: Duration(seconds: 2),
      );
      return;
    }

    String message;
    if (_selectedStatus == 'All Non Editing Images') {
      message =
          "Hi $customerName,\n\n"
          "Your non-edited photos are now ready for download!\n\n"
          "You can access them here: $deliveryLink\n\n"
          "Note: These are the raw, unedited images from your session. "
          "The final edited versions will be shared separately once completed.\n\n"
          "Thanks,\n"
          "${_ownerName.isNotEmpty ? _ownerName : 'Regards'}"
          "${_ownerPhone.isNotEmpty ? '\n$_ownerPhone' : ''}";
    } else {
      message =
          "Hi $customerName,\n\n"
          "Your photos are now *$deliveryStatus*.\n"
          "Download here: $deliveryLink\n\n"
          "Thanks,\n"
          "${_ownerName.isNotEmpty ? _ownerName : 'Regards'}"
          "${_ownerPhone.isNotEmpty ? '\n$_ownerPhone' : ''}";
    }

    final url1 = "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";
    final url2 = "https://wa.me/91$phone?text=${Uri.encodeComponent(message)}";

    canLaunchUrl(Uri.parse(url1)).then((canLaunch) {
      if (canLaunch) {
        launchUrl(Uri.parse(url1), mode: LaunchMode.externalApplication);
      } else {
        launchUrl(Uri.parse(url2), mode: LaunchMode.externalApplication);
      }
    });
  }

  void _showStatusHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildHistorySheet(),
    );
  }

  Widget _buildHistorySheet() {
    final height = MediaQuery.of(context).size.height * 0.78;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 40,
            spreadRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10 * scale),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF2563EB),
                          Color(0xFF1E40AF),
                          Color(0xFF020617),
                        ],
                        stops: [0.0, 0.6, 1.0],
                        begin: Alignment.bottomRight,
                        end: Alignment.topLeft,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.timeline_rounded,
                      color: Colors.white,
                      size: 16 * scale,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Delivery Timeline',
                      style: TextStyle(
                        fontSize: 16 * scale,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close timeline',
                  ),
                ],
              ),
            ),
            SizedBox(height: 8 * scale),
            Expanded(
              child:
                  deliveryStatusHistory.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timeline_rounded,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No history available',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        itemCount: deliveryStatusHistory.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder:
                            (context, index) => _buildTimelineItem(
                              deliveryStatusHistory[index],
                              index,
                            ),
                      ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: Colors.black.withOpacity(0.5)),
                  ),
                  child: const Text(
                    'Close Timeline',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> status, int index) {
    final isCurrent = index == 0;
    DateTime dateTime;
    try {
      dateTime = DateTime.parse(status['dateTime']);
    } catch (_) {
      dateTime = DateTime.now();
    }
    final formattedDate = DateFormat('MMM dd, yyyy').format(dateTime);
    final formattedTime = DateFormat('hh:mm a').format(dateTime);

    return Container(
      decoration: BoxDecoration(
        color: isCurrent ? Colors.white : Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? Colors.grey.withOpacity(0.12) : Colors.grey[200]!,
          width: isCurrent ? 1.4 : 1,
        ),
        boxShadow:
            isCurrent
                ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
                : null,
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                padding: EdgeInsets.all(6 * scale),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors:
                        isCurrent
                            ? [
                              Color(0xFF2563EB),
                              Color(0xFF1E40AF),
                              Color(0xFF020617),
                            ]
                            : [Colors.grey[300]!, Colors.grey[400]!],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    isCurrent ? Icons.check_rounded : Icons.circle_rounded,
                    color: Colors.white,
                    size: 16 * scale,
                  ),
                ),
              ),
              if (index < deliveryStatusHistory.length - 1)
                Container(
                  width: 2 * scale,
                  height: 48 * scale,
                  color: Colors.grey[200],
                  margin: const EdgeInsets.only(top: 8),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        status['status'] ?? 'Status',
                        style: TextStyle(
                          fontSize: 13 * scale,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8 * scale,
                          vertical: 2 * scale,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF48BB78),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Current',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10 * scale,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12 * scale,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$formattedDate • $formattedTime',
                      style: TextStyle(
                        fontSize: 11 * scale,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                if (status['notes'] != null &&
                    (status['notes'] as String).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(8 * scale),
                    decoration: BoxDecoration(
                      color: Colors.grey[40],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[100]!),
                    ),
                    child: Text(
                      status['notes'],
                      style: TextStyle(
                        fontSize: 12 * scale,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  int getCurrentStepIndex() {
    return statuses
        .indexOf(_selectedStatus ?? statuses.first)
        .clamp(0, statuses.length - 1);
  }

  // ---------------------- Large iOS-style header delegate ----------------------
  // Minimal custom delegate for a polished large title look.
  // It provides smooth interpolation and pinned small title overlay when collapsed.
  SliverPersistentHeader _buildLargeHeader(_R r) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _LargeTitleDelegate(
        expandedHeight: r.sp(140),
        title: 'Delivery Tracker',
        subtitle: 'Track photo delivery progress',
        onBack: () => Navigator.pop(context),
        onHistory: _showStatusHistory,
      ),
    );
  }

  // ---------------------- Build the body ----------------------
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final r = _R(width, height);
    // ignore: unused_local_variable
    final isSmall = width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              key: _pageKey,
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildLargeHeader(r),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: r.sp(16),
                      vertical: r.sp(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Customer card
                        _buildCustomerInfoCard(r),
                        SizedBox(height: r.sp(18)),

                        // Progress card
                        _buildProgressCard(r),
                        SizedBox(height: r.sp(18)),

                        // Status selector
                        _buildStatusSelectorCard(r),
                        SizedBox(height: r.sp(18)),

                        // Notes
                        _buildNotesCard(r),
                        SizedBox(height: r.sp(18)),

                        // Link
                        _buildLinkCard(r),
                        SizedBox(height: r.sp(22)),

                        // Actions
                        _buildActionButtons(r),
                        SizedBox(height: r.sp(20)),
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

  // ---------------------- Individual card builders (responsive using _R) ----------------------
  Widget _buildCustomerInfoCard(_R r) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.sp(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: r.sp(18),
            spreadRadius: 1,
          ),
        ],
      ),
      padding: EdgeInsets.all(r.sp(14)),
      child: Row(
        children: [
          Container(
            width: r.sp(56),
            height: r.sp(56),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF2563EB),
                  Color(0xFF1E40AF),
                  Color(0xFF020617),
                ],
                stops: [0.0, 0.6, 1.0],
                begin: Alignment.bottomRight,
                end: Alignment.topLeft,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E40AF).withOpacity(0.22),
                  blurRadius: r.sp(12),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.sale.customerName.isNotEmpty
                    ? widget.sale.customerName.substring(0, 1).toUpperCase()
                    : 'C',
                style: TextStyle(
                  fontSize: r.fp(20),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: r.sp(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.sale.customerName.isNotEmpty
                      ? widget.sale.customerName
                      : 'Customer',
                  style: TextStyle(
                    fontSize: r.fp(18),
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: r.sp(4)),
                Text(
                  widget.sale.phoneNumber,
                  style: TextStyle(fontSize: r.fp(13), color: Colors.grey[600]),
                ),
                SizedBox(height: r.sp(8)),
                Wrap(
                  spacing: r.sp(8),
                  runSpacing: r.sp(6),
                  children: [
                    _buildInfoChip(
                      icon: Icons.photo_album_rounded,
                      text: widget.sale.productName,
                      r: r,
                    ),
                    _buildInfoChip(
                      icon: Icons.calendar_month_rounded,
                      text: DateFormat('MMM dd').format(widget.sale.dateTime),
                      r: r,
                    ),
                    if (_invoiceNumber != null)
                      _buildInfoChip(
                        icon: Icons.receipt_long_rounded,
                        text: 'INV #$_invoiceNumber',
                        r: r,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String text,
    required _R r,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.sp(10), vertical: r.sp(6)),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(r.sp(10)),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: r.ip(14), color: Colors.grey[600]),
          SizedBox(width: r.sp(8)),
          Text(
            text,
            style: TextStyle(
              fontSize: r.fp(12),
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(_R r) {
    final currentIndex = getCurrentStepIndex();
    final progress = ((currentIndex + 1) / statuses.length).clamp(0.0, 1.0);
    final currentColor =
        _statusColors[_selectedStatus ?? statuses.first] ??
        const Color(0xFF1E40AF);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.sp(14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: r.sp(16),
            spreadRadius: 1,
          ),
        ],
      ),
      padding: EdgeInsets.all(r.sp(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Delivery Progress',
                style: TextStyle(
                  fontSize: r.fp(16),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: r.sp(10),
                  vertical: r.sp(6),
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [currentColor, currentColor.withOpacity(0.85)],
                  ),
                  borderRadius: BorderRadius.circular(r.sp(12)),
                ),
                child: Text(
                  statuses[currentIndex],
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: r.fp(12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: r.sp(12)),
          Container(
            height: r.sp(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(r.sp(8)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth * progress;
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: w,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF2563EB),
                          Color(0xFF1E40AF),
                          Color(0xFF020617),
                        ],
                        stops: [0.0, 0.6, 1.0],
                        begin: Alignment.bottomRight,
                        end: Alignment.topLeft,
                      ),
                      borderRadius: BorderRadius.circular(r.sp(8)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E40AF).withOpacity(0.18),
                          blurRadius: r.sp(10),
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: r.sp(12)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).round()}% Complete',
                style: TextStyle(
                  fontSize: r.fp(12),
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '${currentIndex + 1} of ${statuses.length} Steps',
                style: TextStyle(
                  fontSize: r.fp(12),
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSelectorCard(_R r) {
    final width = MediaQuery.of(context).size.width;
    final int columns =
        width < 420
            ? 1
            : width < 900
            ? 2
            : 3;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.sp(14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: r.sp(16),
            spreadRadius: 1,
          ),
        ],
      ),
      padding: EdgeInsets.all(r.sp(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Update Status',
            style: TextStyle(fontSize: r.fp(16), fontWeight: FontWeight.w700),
          ),
          SizedBox(height: r.sp(12)),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: r.sp(12),
              mainAxisSpacing: r.sp(12),
              childAspectRatio: width < 420 ? 4 : 3,
            ),
            itemCount: statuses.length,
            itemBuilder: (context, index) {
              final status = statuses[index];
              final isSelected = _selectedStatus == status;
              final color = _statusColors[status] ?? const Color(0xFF1E40AF);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedStatus = status;
                    _updateStatusNoteSuggestion();
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.white,
                    borderRadius: BorderRadius.circular(r.sp(12)),
                    border: Border.all(
                      color: isSelected ? color : Colors.grey[200]!,
                      width: 2,
                    ),
                    boxShadow:
                        isSelected
                            ? [
                              BoxShadow(
                                color: color.withOpacity(0.18),
                                blurRadius: r.sp(14),
                                spreadRadius: 1,
                              ),
                            ]
                            : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: r.sp(8),
                                spreadRadius: 1,
                              ),
                            ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _statusIcons[status],
                        color: isSelected ? Colors.white : color,
                        size: r.ip(18),
                      ),
                      SizedBox(width: r.sp(8)),
                      Flexible(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: r.sp(10)),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: r.fp(13),
                              fontWeight: FontWeight.w600,
                              color:
                                  isSelected ? Colors.white : Colors.grey[800],
                            ),
                            maxLines: 2,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(_R r) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.sp(14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: r.sp(16),
            spreadRadius: 1,
          ),
        ],
      ),
      padding: EdgeInsets.all(r.sp(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Status Notes',
                style: TextStyle(
                  fontSize: r.fp(16),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Tooltip(
                message: 'Apply template',
                child: GestureDetector(
                  onTap: () {
                    if (_selectedStatus != null &&
                        _statusNoteSuggestions.containsKey(_selectedStatus)) {
                      setState(() {
                        _previousSuggestion =
                            _statusNoteSuggestions[_selectedStatus]!;
                        _statusNotesController.text = _previousSuggestion;
                      });
                    }
                  },
                  child: Container(
                    width: r.sp(36),
                    height: r.sp(36),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(r.sp(10)),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: r.ip(18),
                      color: const Color(0xFF1E40AF),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: r.sp(12)),
          TextField(
            controller: _statusNotesController,
            style: TextStyle(
              fontSize: r.fp(14),
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Add notes about this status...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.sp(12)),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.all(r.sp(12)),
            ),
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildLinkCard(_R r) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.sp(14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: r.sp(16),
            spreadRadius: 1,
          ),
        ],
      ),
      padding: EdgeInsets.all(r.sp(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Download Link',
            style: TextStyle(fontSize: r.fp(16), fontWeight: FontWeight.w700),
          ),
          SizedBox(height: r.sp(12)),
          TextField(
            controller: _linkController,
            style: TextStyle(
              fontSize: r.fp(14),
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'https://drive.google.com/...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Container(
                margin: const EdgeInsets.only(right: 8),
                width: r.sp(44),
                child: const Center(child: Icon(Icons.link_rounded)),
              ),
              prefixIconConstraints: BoxConstraints(minWidth: r.sp(44)),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.sp(12)),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: r.sp(12),
                vertical: r.sp(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(_R r) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: r.sp(54),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveDeliveryDetails,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.sp(14)),
                ),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF2563EB),
                      Color(0xFF1E40AF),
                      Color(0xFF020617),
                    ],
                    stops: [0.0, 0.6, 1.0],
                    begin: Alignment.bottomRight,
                    end: Alignment.topLeft,
                  ),
                  borderRadius: BorderRadius.circular(r.sp(14)),
                ),
                child: Container(
                  alignment: Alignment.center,
                  child:
                      _isSaving
                          ? SizedBox(
                            width: r.sp(18),
                            height: r.sp(18),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.save_rounded,
                                color: Colors.white,
                              ),
                              SizedBox(width: r.sp(10)),
                              Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: r.fp(15),
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: r.sp(12)),
        SizedBox(
          width: r.sp(52),
          height: r.sp(52),
          child: ElevatedButton(
            onPressed: _isSendingWhatsApp ? null : _sendWhatsApp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF25D366),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.sp(14)),
              ),
            ),
            child:
                _isSendingWhatsApp
                    ? SizedBox(
                      width: r.sp(18),
                      height: r.sp(18),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF25D366),
                        ),
                      ),
                    )
                    : const FaIcon(FontAwesomeIcons.whatsapp, size: 24),
          ),
        ),
      ],
    );
  }
}

// ---------------------- LargeTitleDelegate for iOS-like header ----------------------

class _LargeTitleDelegate extends SliverPersistentHeaderDelegate {
  final double expandedHeight;
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onHistory;

  _LargeTitleDelegate({
    required this.expandedHeight,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onHistory,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final double t = (shrinkOffset / (expandedHeight - kToolbarHeight)).clamp(
      0.0,
      1.0,
    );

    final double titleSize = lerpDouble(26, 18, t)!;
    final double subtitleSize = lerpDouble(14, 10, t)!;
    final double paddingTop = lerpDouble(40, 10, t)!;

    return Container(
      decoration: const BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF), Color(0xFF020617)],
          stops: [0.0, 0.6, 1.0],
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
        ),
      ),
      child: Stack(
        children: [
          // ---------- CENTERED TITLE BLOCK ----------
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: paddingTop),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                if (t < 0.8) // hide subtitle when fully collapsed
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: subtitleSize,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ---------- LEFT: BACK BUTTON ----------
          Positioned(
            left: 12,
            top: 12,
            child: _circleButton(
              icon: Icon(
                Icons.arrow_back,
                color: Colors.black,
                size: 20 * scale,
              ),
              onTap: () => Navigator.pop(context),
            ),
          ),

          // ---------- RIGHT: HISTORY BUTTON ----------
          Positioned(
            right: 12,
            top: 12,
            child: _circleButton(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedTransactionHistory,
                color: Colors.black87,
                size: 20 * scale,
              ),
              onTap: onHistory,
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({required Widget icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        splashColor: Colors.black.withOpacity(0.08),
        highlightColor: Colors.black.withOpacity(0.05),
        child: Container(
          width: 35 * scale,
          height: 35 * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,

            // ✅ SUBTLE BORDER (clean & visible)
            border: Border.all(color: Colors.black.withOpacity(0.08), width: 1),

            // ✅ SOFT ELEVATION
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(child: icon),
        ),
      ),
    );
  }

  @override
  double get maxExtent => expandedHeight;

  @override
  double get minExtent => kToolbarHeight + 12;
  double scale = 1.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}
