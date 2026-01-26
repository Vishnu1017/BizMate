import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hugeicons/hugeicons.dart';

class ModernCalendar extends StatefulWidget {
  final DateTime? selectedDate;
  final Function(DateTime) onDateSelected;
  final DateTime? startDate;
  final DateTime? endDate;

  const ModernCalendar({
    super.key,
    this.selectedDate,
    required this.onDateSelected,
    this.startDate,
    this.endDate,
  });

  @override
  State<ModernCalendar> createState() => _ModernCalendarState();
}

class _ModernCalendarState extends State<ModernCalendar> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;
  double scale = 1.0;
  bool _hasUserSelectedDate = false;

  final List<String> _weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate ?? DateTime.now();
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  List<DateTime> _getDaysInMonth() {
    final first = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final last = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final days = <DateTime>[];

    for (int i = 1; i < first.weekday; i++) {
      days.add(first.subtract(Duration(days: first.weekday - i)));
    }

    for (int i = 0; i < last.day; i++) {
      days.add(DateTime(_currentMonth.year, _currentMonth.month, i + 1));
    }

    while (days.length < 42) {
      days.add(days.last.add(const Duration(days: 1)));
    }

    return days;
  }

  bool _isToday(DateTime d) =>
      d.year == DateTime.now().year &&
      d.month == DateTime.now().month &&
      d.day == DateTime.now().day;

  bool _isSelected(DateTime d) =>
      d.year == _selectedDate.year &&
      d.month == _selectedDate.month &&
      d.day == _selectedDate.day;

  bool _isCurrentMonth(DateTime d) =>
      d.month == _currentMonth.month && d.year == _currentMonth.year;

  bool _isInRange(DateTime d) {
    if (widget.startDate == null || widget.endDate == null) return false;
    return (d.isAfter(widget.startDate!) ||
            d.isAtSameMomentAs(widget.startDate!)) &&
        (d.isBefore(widget.endDate!) || d.isAtSameMomentAs(widget.endDate!));
  }

  @override
  Widget build(BuildContext context) {
    final days = _getDaysInMonth();
    final width = MediaQuery.of(context).size.width;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: width * 0.9,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // HEADER
              _buildHeader(width),

              // WEEKDAYS
              _buildWeekdays(width),

              // GRID
              _buildGrid(days),

              // FOOTER + SAVE BUTTON
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  children: [
                    Text(
                      "Selected: ${DateFormat('MMM dd, yyyy').format(_selectedDate)}",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),

                    const SizedBox(height: 14),

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child:
                          _hasUserSelectedDate
                              ? SizedBox(
                                key: const ValueKey("save_btn"),
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: () {
                                    widget.onDateSelected(_selectedDate);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    backgroundColor: Colors.blue.shade600,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      HugeIcon(
                                        icon:
                                            HugeIcons.strokeRoundedTickDouble03,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "Save Date",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------- UI HELPERS --------------------

  Widget _buildHeader(double width) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade200, Colors.purple.shade200],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _navButton(Icons.chevron_left_rounded, _previousMonth),
          Column(
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_currentMonth),
                style: TextStyle(
                  fontSize: width * 0.045,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Select a date",
                style: TextStyle(
                  fontSize: width * 0.03,
                  color: Colors.black.withOpacity(0.6),
                ),
              ),
            ],
          ),
          _navButton(Icons.chevron_right_rounded, _nextMonth),
        ],
      ),
    );
  }

  Widget _buildWeekdays(double width) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children:
            _weekdays
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: width * 0.03,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _buildGrid(List<DateTime> days) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: days.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1.2,
        ),
        itemBuilder: (_, index) {
          final date = days[index];
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap:
                _isCurrentMonth(date)
                    ? () {
                      setState(() {
                        _selectedDate = date;
                        _hasUserSelectedDate = true;
                      });
                    }
                    : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: EdgeInsets.all(6 * scale),
              decoration:
                  _isSelected(date)
                      ? BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade600,
                            Colors.purple.shade600,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      )
                      : _isInRange(date)
                      ? BoxDecoration(
                        color: Colors.blue.shade100.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(12),
                      )
                      : _isToday(date)
                      ? BoxDecoration(
                        border: Border.all(
                          color: Colors.orange.shade400,
                          width: 1.4,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      )
                      : BoxDecoration(borderRadius: BorderRadius.circular(8)),
              child: Center(
                child: Text(
                  date.day.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        _isSelected(date) ? FontWeight.bold : FontWeight.w500,
                    color: _isSelected(date) ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}
