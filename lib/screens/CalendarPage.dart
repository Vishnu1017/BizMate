import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:bizmate/models/sale.dart';
import 'package:bizmate/models/rental_sale_model.dart';
import 'package:bizmate/models/user_model.dart';
import 'package:bizmate/widgets/app_theme_toggle.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:unicons/unicons.dart';

class CalendarPage extends StatefulWidget {
  final String? initialRole;

  const CalendarPage({super.key, this.initialRole});

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  /// Active role filter: 'Photography', '3D Printing Brand', or 'All'
  String _selectedRole = 'All';

  /// Raw cached data
  List<Sale> _allSales = [];
  List<RentalSaleModel> _allRentals = [];

  /// Mixed events mapped by date (Sale, RentalSaleModel, photo_event, delivery_event)
  Map<DateTime, List<dynamic>> _events = {};

  double scale = 1.0;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _initCalendar();
  }

  Future<void> _initCalendar() async {
    // 1. Initial role from constructor if provided
    if (widget.initialRole != null && widget.initialRole!.trim().isNotEmpty) {
      _applyRoleString(widget.initialRole!);
    } else {
      await _loadUserRole();
    }
    // 2. Load cached sales & rentals
    _allSales = await _loadUserSales();
    _allRentals = await _loadUserRentalSales();
    // 3. Re-verify latest role from DB / session in case profile was recently edited
    await _loadUserRole();
    if (mounted) {
      _rebuildFilteredEvents();
    }
  }

  void _applyRoleString(String role) {
    final lower = role.toLowerCase().trim();
    if (lower.contains('photo')) {
      _selectedRole = 'Photography';
    } else if (lower.contains('3d') || lower.contains('print')) {
      _selectedRole = '3D Printing Brand';
    } else {
      _selectedRole = 'All';
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadUserRole() async {
    try {
      if (!Hive.isBoxOpen('session')) await Hive.openBox('session');
      final sessionBox = Hive.box('session');

      // 1. Check session role first
      final sessionRole = sessionBox.get('currentUserRole');
      if (sessionRole != null && sessionRole.toString().trim().isNotEmpty) {
        _applyRoleString(sessionRole.toString());
        return;
      }

      final email = sessionBox.get('currentUserEmail');
      if (email != null) {
        // 2. Check users box
        final usersBox = Hive.isBoxOpen('users')
            ? Hive.box<User>('users')
            : await Hive.openBox<User>('users');
        final user = usersBox.values.firstWhere(
          (u) => u.email.toLowerCase() == email.toString().toLowerCase(),
          orElse: () => User(name: '', email: '', phone: '', password: '', role: 'None'),
        );
        if (user.role.isNotEmpty && user.role != 'None') {
          _applyRoleString(user.role);
          return;
        }

        // 3. Check userdata box profile
        final safeEmail = email
            .toString()
            .replaceAll('.', '_')
            .replaceAll('@', '_');
        final userBox = await Hive.openBox("userdata_$safeEmail");
        final profile = userBox.get('profile');
        if (profile != null && profile is Map && profile['role'] != null) {
          final pRole = profile['role'].toString();
          if (pRole.isNotEmpty && pRole != 'None') {
            _applyRoleString(pRole);
            return;
          }
        }
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // LOAD & FILTER EVENTS
  // ---------------------------------------------------------------------------

  void _loadEvents() async {
    _allSales = await _loadUserSales();
    _allRentals = await _loadUserRentalSales();
    _rebuildFilteredEvents();
  }

  /// Extracts all distinct delivery dates for a sale
  List<DateTime> _getAllDeliveryDates(Sale sale) {
    final List<DateTime> dates = [];

    // 1. From delivery status history
    if (sale.deliveryStatusHistory != null && sale.deliveryStatusHistory!.isNotEmpty) {
      for (final item in sale.parsedDeliveryHistory) {
        final status = (item['status'] ?? '').toString().toLowerCase();
        final dtStr = item['dateTime']?.toString();
        if (dtStr != null) {
          final parsed = DateTime.tryParse(dtStr);
          if (parsed != null) {
            if (status.contains('deliver') ||
                status.contains('dispatch') ||
                status.contains('printed') ||
                status.contains('ship') ||
                status.contains('transit') ||
                status.contains('ready') ||
                status.contains('completed')) {
              if (!dates.any((d) => isSameDay(d, parsed))) {
                dates.add(parsed);
              }
            }
          }
        }
      }
    }

    // 2. From safeEventDates (for 3D Printing / custom orders, event dates represent target delivery dates)
    for (final ed in sale.safeEventDates) {
      if (!dates.any((d) => isSameDay(d, ed))) {
        dates.add(ed);
      }
    }

    return dates;
  }

  /// Gets the primary delivery date for display on a sale card
  DateTime? _getSaleDeliveryDate(Sale sale) {
    final all = _getAllDeliveryDates(sale);
    if (all.isNotEmpty) return all.first;
    return null;
  }

  void _rebuildFilteredEvents() {
    final Map<DateTime, List<dynamic>> events = {};

    final isPhotography = _selectedRole == 'Photography';
    final is3DPrinting = _selectedRole == '3D Printing Brand';

    // 1. Process Sales & associated events
    for (final sale in _allSales) {
      if (isPhotography) {
        // Photography role: Display Sales + Shoots (Rentals handled below, NO Deliveries)
        // Booking date event (Sales display!)
        final bookingDate = DateTime.utc(
          sale.dateTime.year,
          sale.dateTime.month,
          sale.dateTime.day,
        );
        events.putIfAbsent(bookingDate, () => []).add(sale);

        // Shoots on event dates
        if (sale.safeEventDates.isNotEmpty) {
          for (final eventDate in sale.safeEventDates) {
            final eventDay = DateTime.utc(
              eventDate.year,
              eventDate.month,
              eventDate.day,
            );
            events.putIfAbsent(eventDay, () => []).add({
              'type': 'photo_event',
              'sale': sale,
              'date': eventDate,
            });
          }
        }
      } else if (is3DPrinting) {
        // 3D Printing Brand: Display Sales + Deliver Dates (NO Shoots, NO Rentals)
        // Booking date event (Sales display!)
        final bookingDate = DateTime.utc(
          sale.dateTime.year,
          sale.dateTime.month,
          sale.dateTime.day,
        );
        events.putIfAbsent(bookingDate, () => []).add(sale);

        // Delivery date event(s)
        final deliveryDates = _getAllDeliveryDates(sale);
        for (final dDate in deliveryDates) {
          final deliveryDay = DateTime.utc(dDate.year, dDate.month, dDate.day);
          events.putIfAbsent(deliveryDay, () => []).add({
            'type': 'delivery_event',
            'sale': sale,
            'date': dDate,
            'status': sale.deliveryStatus,
          });
        }
      } else {
        // 'All' role: show all bookings, shoots, deliveries, and rentals
        final bookingDate = DateTime.utc(
          sale.dateTime.year,
          sale.dateTime.month,
          sale.dateTime.day,
        );
        events.putIfAbsent(bookingDate, () => []).add(sale);

        if (sale.safeEventDates.isNotEmpty) {
          for (final eventDate in sale.safeEventDates) {
            final eventDay = DateTime.utc(
              eventDate.year,
              eventDate.month,
              eventDate.day,
            );
            events.putIfAbsent(eventDay, () => []).add({
              'type': 'photo_event',
              'sale': sale,
              'date': eventDate,
            });
          }
        }

        final deliveryDates = _getAllDeliveryDates(sale);
        for (final dDate in deliveryDates) {
          final deliveryDay = DateTime.utc(dDate.year, dDate.month, dDate.day);
          events.putIfAbsent(deliveryDay, () => []).add({
            'type': 'delivery_event',
            'sale': sale,
            'date': dDate,
            'status': sale.deliveryStatus,
          });
        }
      }
    }

    // 2. Process Rentals (Display for Photography and All, NEVER for 3D Printing Brand)
    if (!is3DPrinting) {
      for (final rental in _allRentals) {
        final date = DateTime.utc(
          rental.fromDateTime.year,
          rental.fromDateTime.month,
          rental.fromDateTime.day,
        );
        events.putIfAbsent(date, () => []).add(rental);
      }
    }

    if (mounted) {
      setState(() => _events = events);
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final key = DateTime.utc(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  Future<List<Sale>> _loadUserSales() async {
    if (!Hive.isBoxOpen('session')) await Hive.openBox('session');
    final email = Hive.box('session').get('currentUserEmail');
    if (email == null) return [];

    final safeEmail = email
        .toString()
        .replaceAll('.', '_')
        .replaceAll('@', '_');
    final userBox = await Hive.openBox("userdata_$safeEmail");
    try {
      return List<Sale>.from(userBox.get("sales", defaultValue: []));
    } catch (_) {
      return [];
    }
  }

  Future<List<RentalSaleModel>> _loadUserRentalSales() async {
    if (!Hive.isBoxOpen('session')) await Hive.openBox('session');
    final email = Hive.box('session').get('currentUserEmail');
    if (email == null) return [];

    final safeEmail = email
        .toString()
        .replaceAll('.', '_')
        .replaceAll('@', '_');
    final userBox = await Hive.openBox("userdata_$safeEmail");
    try {
      return List<RentalSaleModel>.from(
        userBox.get("rental_sales", defaultValue: []),
      );
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isTablet = media.size.width >= 600;
    final horizontalPadding = isTablet ? 24.0 : 16.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text1 = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    final String appBarTitle = _selectedRole == 'Photography'
        ? "Photography Calendar"
        : _selectedRole == '3D Printing Brand'
            ? "3D Printing & Delivery"
            : "Booking Calendar";

    final String defaultSubtitle = _selectedRole == 'Photography'
        ? "Viewing Sales, Shoots & Equipment Rentals"
        : _selectedRole == '3D Printing Brand'
            ? "Viewing Sales & Delivery Dates"
            : "View all shoots, sales & rentals";

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      // APP BAR
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: text1, size: 20 * scale),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: AppThemeToggle(),
            ),
          ],
          titleSpacing: horizontalPadding,
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8 * scale),
                decoration: BoxDecoration(
                  color: cardColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.25 : 0.05,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _selectedRole == 'Photography'
                      ? Icons.camera_alt_rounded
                      : _selectedRole == '3D Printing Brand'
                          ? Icons.precision_manufacturing_rounded
                          : Icons.calendar_month_rounded,
                  color: _selectedRole == 'Photography'
                      ? const Color(0xFFE11D48)
                      : _selectedRole == '3D Printing Brand'
                          ? const Color(0xFF10B981)
                          : const Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      appBarTitle,
                      style: TextStyle(
                        fontSize: isTablet ? 22 : 18,
                        fontWeight: FontWeight.w700,
                        color: text1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedDay == null
                          ? defaultSubtitle
                          : DateFormat('EEEE, dd MMM yyyy').format(_selectedDay!),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // BODY
      body: Column(
        children: [
          // CALENDAR CARD
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              8,
              horizontalPadding,
              8,
            ),
            child: _glassContainer(
              child: TableCalendar<dynamic>(
                focusedDay: _focusedDay,
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2100, 12, 31),
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = DateTime.utc(
                      selected.year,
                      selected.month,
                      selected.day,
                    );
                    _focusedDay = focused;
                  });
                },
                eventLoader: _getEventsForDay,
                headerStyle: HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                  titleTextStyle: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, events) {
                    if (events.isEmpty) return const SizedBox();

                    final hasSale = events.any((e) => e is Sale);
                    final hasShoot = events.any(
                      (e) => e is Map && e['type'] == 'photo_event',
                    );
                    final hasRental = events.any((e) => e is RentalSaleModel);
                    final hasDelivery = events.any(
                      (e) => e is Map && e['type'] == 'delivery_event',
                    );

                    return Positioned(
                      bottom: 4,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasSale)
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: const BoxDecoration(
                                color: Color(0xFF2563EB), // SALE BLUE
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (hasDelivery)
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981), // DELIVERY GREEN
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (hasShoot)
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE11D48), // SHOOT RED
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (hasRental)
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: const BoxDecoration(
                                color: Color(0xFF7C3AED), // RENTAL PURPLE
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  todayDecoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: Color(0xFFF97316),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),

          // DAY SUMMARY
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 6,
            ),
            child: Row(
              children: [
                Text(
                  "Day Summary",
                  style: TextStyle(
                    fontSize: 12 * scale,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                  ),
                ),
                const Spacer(),

                if (_selectedDay != null) ...[
                  // SALES (Shown in ALL roles: Photography, 3D Printing Brand, All)
                  _buildSummaryChip(
                    count: _getEventsForDay(_selectedDay!).whereType<Sale>().length,
                    label: "Sales",
                    color: const Color(0xFF2563EB),
                  ),

                  // DELIVERIES (Shown in 3D Printing Brand & All)
                  if (_selectedRole != 'Photography') ...[
                    SizedBox(width: 6 * scale),
                    _buildSummaryChip(
                      count: _getEventsForDay(_selectedDay!)
                          .where((e) => e is Map && e['type'] == 'delivery_event')
                          .length,
                      label: "Deliveries",
                      color: const Color(0xFF10B981),
                    ),
                  ],

                  // SHOOTS (Shown in Photography & All)
                  if (_selectedRole != '3D Printing Brand') ...[
                    SizedBox(width: 6 * scale),
                    _buildSummaryChip(
                      count: _getEventsForDay(_selectedDay!)
                          .where((e) => e is Map && e['type'] == 'photo_event')
                          .length,
                      label: "Shoots",
                      color: const Color(0xFFE11D48),
                    ),
                  ],

                  // RENTALS (Shown in Photography & All)
                  if (_selectedRole != '3D Printing Brand') ...[
                    SizedBox(width: 6 * scale),
                    _buildSummaryChip(
                      count: _getEventsForDay(_selectedDay!)
                          .whereType<RentalSaleModel>()
                          .length,
                      label: "Rentals",
                      color: const Color(0xFF7C3AED),
                    ),
                  ],
                ],
              ],
            ),
          ),

          // EVENTS LIST
          Expanded(
            child: _selectedDay == null
                ? const Center(child: Text("No date selected"))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 700;
                      final listPadding = EdgeInsets.fromLTRB(
                        isWide ? (constraints.maxWidth - 700) / 2 + 16 : 16,
                        8,
                        isWide ? (constraints.maxWidth - 700) / 2 + 16 : 16,
                        16,
                      );

                      final events = _getEventsForDay(_selectedDay!);

                      if (events.isEmpty) {
                        return Padding(
                          padding: listPadding,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.event_busy_rounded,
                                  size: 40 * scale,
                                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                                ),
                                SizedBox(height: 12 * scale),
                                Text(
                                  _selectedRole == 'Photography'
                                      ? "No sales, shoots or rentals for this day"
                                      : _selectedRole == '3D Printing Brand'
                                          ? "No sales or deliveries for this day"
                                          : "No bookings for this day",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: listPadding,
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];

                          // 1. PHOTO SHOOT EVENT
                          if (event is Map && event['type'] == 'photo_event') {
                            final Sale sale = event['sale'];
                            final DateTime shootDate = event['date'];

                            return Padding(
                              padding: EdgeInsets.only(bottom: 10 * scale),
                              child: _eventCard(
                                icon: Icons.camera_alt_rounded,
                                title: sale.customerName,
                                subtitle: sale.productName,
                                color: const Color(0xFFE11D48),
                                tag: "SHOOT",
                                extra: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Shoot Date: ${DateFormat('dd MMM yyyy').format(shootDate)}",
                                      style: _timeStyle.copyWith(
                                        color: const Color(0xFFE11D48),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      "Booked: ${DateFormat('dd MMM yyyy').format(sale.dateTime)} • ₹ ${sale.totalAmount.toStringAsFixed(2)}",
                                      style: _timeStyle,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          // 2. DELIVERY DATE EVENT (3D Printing & All)
                          if (event is Map && event['type'] == 'delivery_event') {
                            final Sale sale = event['sale'];
                            final DateTime deliveryDate = event['date'];
                            final String status = event['status'] ?? sale.deliveryStatus;
                            final bool isDelivered = status.toLowerCase() == 'delivered';

                            return Padding(
                              padding: EdgeInsets.only(bottom: 10 * scale),
                              child: _eventCard(
                                icon: Icons.local_shipping_rounded,
                                title: sale.customerName,
                                subtitle: "${sale.productName} • ₹ ${sale.totalAmount.toStringAsFixed(2)}",
                                color: const Color(0xFF10B981),
                                tag: isDelivered ? "DELIVERED" : "DELIVERY",
                                extra: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.event_available_rounded,
                                          size: 12,
                                          color: Color(0xFF10B981),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Deliver Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(deliveryDate)}",
                                          style: _timeStyle.copyWith(
                                            color: const Color(0xFF10B981),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Order Date: ${DateFormat('dd MMM yyyy').format(sale.dateTime)} • Status: $status",
                                      style: _timeStyle,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          // 3. NORMAL SALE (Orders on Booking Date)
                          if (event is Sale) {
                            final deliveryDate = _getSaleDeliveryDate(event);

                            return Padding(
                              padding: EdgeInsets.only(bottom: 10 * scale),
                              child: _eventCard(
                                icon: UniconsLine.shopping_cart,
                                title: event.customerName,
                                subtitle:
                                    "₹ ${event.totalAmount.toStringAsFixed(2)} • ${event.productName}",
                                color: const Color(0xFF2563EB),
                                tag: "SALE",
                                extra: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Booking Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(event.dateTime)}",
                                      style: _timeStyle,
                                    ),
                                    // In 3D Printing Brand (or All), display Deliver Date alongside Sales
                                    if (_selectedRole == '3D Printing Brand' || _selectedRole == 'All') ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.local_shipping_outlined,
                                            size: 12,
                                            color: deliveryDate != null
                                                ? const Color(0xFF10B981)
                                                : (isDark ? Colors.amber.shade300 : Colors.amber.shade700),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            deliveryDate != null
                                                ? "Deliver Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(deliveryDate)}"
                                                : "Deliver Date: Pending / Not Set",
                                            style: _timeStyle.copyWith(
                                              color: deliveryDate != null
                                                  ? const Color(0xFF10B981)
                                                  : (isDark ? Colors.amber.shade300 : Colors.amber.shade800),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Delivery Status: ${event.deliveryStatus}",
                                        style: _timeStyle.copyWith(
                                          color: event.deliveryStatus.toLowerCase() == 'delivered'
                                              ? const Color(0xFF10B981)
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }

                          // 4. RENTAL SALE
                          if (event is RentalSaleModel) {
                            final from = DateFormat('dd MMM yyyy, hh:mm a').format(event.fromDateTime);
                            final to = DateFormat('dd MMM yyyy, hh:mm a').format(event.toDateTime);

                            return Padding(
                              padding: EdgeInsets.only(bottom: 10 * scale),
                              child: _eventCard(
                                icon: Icons.photo_camera_rounded,
                                title: event.customerName,
                                subtitle: "₹ ${event.totalCost.toStringAsFixed(2)} • ${event.itemName}",
                                color: const Color(0xFF7C3AED),
                                tag: "RENTAL",
                                extra: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("From: $from", style: _timeStyle),
                                    Text("To: $to", style: _timeStyle),
                                  ],
                                ),
                              ),
                            );
                          }

                          return const SizedBox.shrink();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  Widget _glassContainer({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor1 = isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.85);
    final glassColor2 = isDark
        ? const Color(0xFF0F172A).withValues(alpha: 0.8)
        : Colors.white.withValues(alpha: 0.65);
    final borderColor = isDark
        ? const Color(0xFF334155).withValues(alpha: 0.8)
        : Colors.white.withValues(alpha: 0.6);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.all(10 * scale),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [glassColor1, glassColor2]),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _eventCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String tag,
    required Widget? extra,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _glassContainer(
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 20 * scale),
            ),
            SizedBox(width: 12 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12 * scale,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                      fontSize: 10 * scale,
                    ),
                  ),
                  if (extra != null) extra,
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 8 * scale,
                vertical: 4 * scale,
              ),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10 * scale,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryChip({
    required int count,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 4 * scale),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        "$count $label",
        style: TextStyle(
          fontSize: 11 * scale,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  TextStyle get _timeStyle => TextStyle(
        fontSize: 11,
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF94A3B8)
            : Colors.grey.shade700,
      );
}
