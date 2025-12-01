import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ModernCalendar extends StatefulWidget {
  final DateTime? selectedDate;
  final Function(DateTime) onDateSelected;
  final DateTime? startDate;
  final DateTime? endDate;

  const ModernCalendar({
    Key? key,
    this.selectedDate,
    required this.onDateSelected,
    this.startDate,
    this.endDate,
  }) : super(key: key);

  @override
  State<ModernCalendar> createState() => _ModernCalendarState();
}

class _ModernCalendarState extends State<ModernCalendar> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;

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

    int startingWeekday = first.weekday;
    for (int i = 1; i < startingWeekday; i++) {
      days.add(first.subtract(Duration(days: startingWeekday - i)));
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
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withOpacity(0.85),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade200, Colors.purple.shade200],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
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
                            color: Colors.black87,
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
              ),

              // WEEKDAYS
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children:
                      _weekdays.map((day) {
                        return Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: width * 0.03,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),

              // GRID
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: days.length,
                  itemBuilder: (context, index) {
                    final date = days[index];

                    final selected = _isSelected(date);
                    final today = _isToday(date);
                    final currentMonth = _isCurrentMonth(date);
                    final inRange = _isInRange(date);

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color:
                            selected
                                ? Colors.blue.shade700
                                : inRange
                                ? Colors.blue.shade100.withOpacity(0.55)
                                : today
                                ? Colors.orange.shade100
                                : Colors.transparent,
                        border:
                            today && !selected
                                ? Border.all(
                                  color: Colors.orange.shade400,
                                  width: 1.2,
                                )
                                : null,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap:
                            currentMonth
                                ? () {
                                  setState(() => _selectedDate = date);
                                  widget.onDateSelected(date);
                                }
                                : null,
                        child: Center(
                          child: Text(
                            date.day.toString(),
                            style: TextStyle(
                              fontSize: width * 0.035,
                              fontWeight:
                                  selected ? FontWeight.bold : FontWeight.w500,
                              color:
                                  selected
                                      ? Colors.white
                                      : currentMonth
                                      ? Colors.black87
                                      : Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // FOOTER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(22),
                  ),
                  color: Colors.grey.shade200,
                ),
                child: Text(
                  "Selected: ${DateFormat('MMM dd, yyyy').format(_selectedDate)}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: width * 0.035,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
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
        child: Icon(icon, color: Colors.black87, size: 20),
      ),
    );
  }
}
