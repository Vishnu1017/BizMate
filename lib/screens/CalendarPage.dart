import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:bizmate/models/sale.dart';
import 'package:bizmate/models/rental_sale_model.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:unicons/unicons.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  /// Mixed events (Sale + RentalSaleModel)
  Map<DateTime, List<dynamic>> _events = {};

  double scale = 1.0;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  // ---------------------------------------------------------------------------
  // LOAD EVENTS
  // ---------------------------------------------------------------------------

  void _loadEvents() async {
    final sales = await _loadUserSales();
    final rentals = await _loadUserRentalSales();

    Map<DateTime, List<dynamic>> events = {};

    for (final sale in sales) {
      final date = DateTime.utc(
        sale.dateTime.year,
        sale.dateTime.month,
        sale.dateTime.day,
      );
      events.putIfAbsent(date, () => []).add(sale);
    }

    for (final rental in rentals) {
      final date = DateTime.utc(
        rental.fromDateTime.year,
        rental.fromDateTime.month,
        rental.fromDateTime.day,
      );
      events.putIfAbsent(date, () => []).add(rental);
    }

    setState(() => _events = events);
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

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),

      // ✅ PROPER APP BAR
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,

          // ✅ SHOW BACK ARROW
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xFF0F172A),
              size: 20,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),

          titleSpacing: horizontalPadding,
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8 * scale),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Booking Calendar",
                      style: TextStyle(
                        fontSize: isTablet ? 22 : 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedDay == null
                          ? "View all your shoots & rentals"
                          : DateFormat(
                            'EEEE, dd MMM yyyy',
                          ).format(_selectedDay!),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
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
              12,
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
                    color: const Color(0xFF111827),
                  ),
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  todayDecoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                if (_selectedDay != null)
                  _buildSummaryChip(
                    count:
                        _getEventsForDay(
                          _selectedDay!,
                        ).whereType<Sale>().length,
                    label: "Sales",
                    color: Colors.blue,
                  ),
                const SizedBox(width: 6),
                if (_selectedDay != null)
                  _buildSummaryChip(
                    count:
                        _getEventsForDay(
                          _selectedDay!,
                        ).whereType<RentalSaleModel>().length,
                    label: "Rentals",
                    color: Colors.deepPurple,
                  ),
              ],
            ),
          ),

          // EVENTS LIST
          Expanded(
            child:
                _selectedDay == null
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
                                    size: 40,
                                    color: Colors.grey.shade400,
                                  ),
                                  SizedBox(height: 12 * scale),
                                  Text(
                                    "No bookings for this day",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
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

                            if (event is Sale) {
                              return Padding(
                                padding: EdgeInsets.only(bottom: 10 * scale),
                                child: _eventCard(
                                  icon: UniconsLine.shopping_cart,
                                  title: event.customerName,
                                  subtitle:
                                      "₹ ${event.totalAmount.toStringAsFixed(2)} • ${event.deliveryStatus}",
                                  color: const Color(0xFF2563EB),
                                  tag: "SALE",
                                  extra: Text(
                                    "Shoot date: ${DateFormat('dd MMM yyyy, hh:mm a').format(event.dateTime)}",
                                    style: _timeStyle,
                                  ),
                                ),
                              );
                            }

                            if (event is RentalSaleModel) {
                              final from = DateFormat(
                                'dd MMM yyyy, hh:mm a',
                              ).format(event.fromDateTime);
                              final to = DateFormat(
                                'dd MMM yyyy, hh:mm a',
                              ).format(event.toDateTime);

                              return Padding(
                                padding: EdgeInsets.only(bottom: 10 * scale),
                                child: _eventCard(
                                  icon: Icons.photo_camera_rounded,
                                  title: event.customerName,
                                  subtitle:
                                      "₹ ${event.totalCost.toStringAsFixed(2)} • ${event.itemName}",
                                  color: const Color(0xFF7C3AED),
                                  tag: "RENTAL",
                                  extra: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text("From: $from", style: _timeStyle),
                                      Text("To:   $to", style: _timeStyle),
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
  // HELPERS (UNCHANGED)
  // ---------------------------------------------------------------------------

  Widget _glassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.all(12 * scale),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.85),
                Colors.white.withOpacity(0.65),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.6)),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _glassContainer(
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
                  if (extra != null) extra,
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tag,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        "$count $label",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  TextStyle get _timeStyle => const TextStyle(fontSize: 11);
}
