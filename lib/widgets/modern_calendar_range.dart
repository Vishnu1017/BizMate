import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart' show HugeIcon, HugeIcons;
import 'package:intl/intl.dart';

class ModernCalendarRange extends StatefulWidget {
  final DateTime? selectedStartDate;
  final DateTime? selectedEndDate;
  final Function(DateTime?, DateTime?) onRangeSelected;
  final DateTime? minDate;
  final DateTime? maxDate;

  const ModernCalendarRange({
    super.key,
    this.selectedStartDate,
    this.selectedEndDate,
    required this.onRangeSelected,
    this.minDate,
    this.maxDate,
  });

  @override
  State<ModernCalendarRange> createState() => _ModernCalendarRangeState();
}

class _ModernCalendarRangeState extends State<ModernCalendarRange> {
  late DateTime _currentMonth;
  late DateTime? _selectedStartDate;
  late DateTime? _selectedEndDate;
  DateTime? _hoverDate;

  final List<String> _weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  void initState() {
    super.initState();
    _selectedStartDate = widget.selectedStartDate;
    _selectedEndDate = widget.selectedEndDate;

    if (_selectedStartDate != null) {
      _currentMonth = _selectedStartDate!;
    } else if (_selectedEndDate != null) {
      _currentMonth = _selectedEndDate!;
    } else {
      _currentMonth = DateTime.now();
    }
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

  bool _isCurrentMonth(DateTime d) =>
      d.month == _currentMonth.month && d.year == _currentMonth.year;

  bool _isStartDate(DateTime d) =>
      _selectedStartDate != null &&
      d.year == _selectedStartDate!.year &&
      d.month == _selectedStartDate!.month &&
      d.day == _selectedStartDate!.day;

  bool _isEndDate(DateTime d) =>
      _selectedEndDate != null &&
      d.year == _selectedEndDate!.year &&
      d.month == _selectedEndDate!.month &&
      d.day == _selectedEndDate!.day;

  bool _isInRange(DateTime d) {
    if (_selectedStartDate == null || _selectedEndDate == null) return false;

    return (d.isAfter(_selectedStartDate!) && d.isBefore(_selectedEndDate!)) ||
        _isStartDate(d) ||
        _isEndDate(d);
  }

  bool _isInHoverRange(DateTime d) {
    if (_selectedStartDate == null || _hoverDate == null) return false;

    if (_selectedEndDate == null) {
      final start = _selectedStartDate!;
      final hover = _hoverDate!;

      if (start.isBefore(hover)) {
        return d.isAfter(start) && d.isBefore(hover);
      } else if (start.isAfter(hover)) {
        return d.isAfter(hover) && d.isBefore(start);
      }
    }
    return false;
  }

  bool _isInSelectedRange(DateTime d) {
    if (_selectedStartDate == null || _selectedEndDate == null) return false;
    return _isInRange(d) && !_isStartDate(d) && !_isEndDate(d);
  }

  /// ❗ Modified: REMOVED auto-callback. Save button handles it now.
  void _onDateSelected(DateTime date) {
    setState(() {
      if (_selectedStartDate == null) {
        _selectedStartDate = date;
        _selectedEndDate = null;
      } else if (_selectedEndDate == null) {
        if (date.isBefore(_selectedStartDate!)) {
          _selectedEndDate = _selectedStartDate;
          _selectedStartDate = date;
        } else {
          _selectedEndDate = date;
        }
      } else {
        _selectedStartDate = date;
        _selectedEndDate = null;
      }
    });
  }

  void _onDateHover(DateTime? date) {
    if (_selectedStartDate != null && _selectedEndDate == null) {
      if (_hoverDate != date) {
        setState(() => _hoverDate = date);
      }
    }
  }

  Color _getDateColor(DateTime date, bool currentMonth) {
    if (_isStartDate(date) || _isEndDate(date)) return Colors.white;
    if (_isInSelectedRange(date)) return Colors.blue.shade700;
    if (_isToday(date)) return Colors.black87;
    if (!currentMonth) return Colors.grey.shade400;
    return Colors.black87;
  }

  BoxDecoration _getDateDecoration(DateTime date) {
    final isStart = _isStartDate(date);
    final isEnd = _isEndDate(date);
    final isInRange = _isInSelectedRange(date);
    final isInHoverRange = _isInHoverRange(date);
    final isToday = _isToday(date);
    final isCurrentMonth = _isCurrentMonth(date);

    if (isStart || isEnd) {
      return BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.purple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            isStart && isEnd
                ? BorderRadius.circular(12)
                : isStart
                ? const BorderRadius.horizontal(
                  left: Radius.circular(12),
                  right: Radius.circular(4),
                )
                : const BorderRadius.horizontal(
                  left: Radius.circular(4),
                  right: Radius.circular(12),
                ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade400.withOpacity(0.5),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      );
    } else if (isInRange) {
      return BoxDecoration(color: Colors.blue.shade100.withOpacity(0.55));
    } else if (isInHoverRange) {
      return BoxDecoration(color: Colors.blue.shade50.withOpacity(0.4));
    } else if (isToday && isCurrentMonth) {
      return BoxDecoration(
        border: Border.all(color: Colors.orange.shade400, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      );
    }

    return BoxDecoration(borderRadius: BorderRadius.circular(12));
  }

  String _getSelectedRangeText() {
    if (_selectedStartDate == null && _selectedEndDate == null) {
      return "Select a date range";
    }

    if (_selectedStartDate != null && _selectedEndDate == null) {
      return "Start: ${DateFormat('MMM dd, yyyy').format(_selectedStartDate!)} - Select end date";
    }

    if (_selectedStartDate != null && _selectedEndDate != null) {
      final start = DateFormat('MMM dd, yyyy').format(_selectedStartDate!);
      final end = DateFormat('MMM dd, yyyy').format(_selectedEndDate!);
      return "Range: $start to $end";
    }

    return "Select a date range";
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
              _buildHeader(width),

              // WEEKDAYS
              _buildWeekdays(width),

              // GRID
              _buildDateGrid(days, width),

              // FOOTER WITH SAVE BUTTON
              _buildFooter(width),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double width) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
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
              SizedBox(height: 2),
              Text(
                "Select date range",
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
                          color: Colors.grey.shade700,
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

  Widget _buildDateGrid(List<DateTime> days, double width) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: days.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1.2,
        ),
        itemBuilder: (context, index) {
          final date = days[index];
          final isCurrentMonth = _isCurrentMonth(date);

          return MouseRegion(
            onEnter: (_) => _onDateHover(date),
            onExit: (_) => _onDateHover(null),
            child: GestureDetector(
              onTap: isCurrentMonth ? () => _onDateSelected(date) : null,
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                decoration: _getDateDecoration(date),
                child: Center(
                  child: Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontSize: width * 0.035,
                      fontWeight:
                          (_isStartDate(date) || _isEndDate(date))
                              ? FontWeight.bold
                              : FontWeight.w500,
                      color: _getDateColor(date, isCurrentMonth),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooter(double width) {
    bool canSave = _selectedStartDate != null && _selectedEndDate != null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        color: Colors.grey.shade200,
      ),
      child: Column(
        children: [
          Text(
            _getSelectedRangeText(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: width * 0.035,
              color: Colors.grey.shade700,
            ),
          ),

          SizedBox(height: 14),

          if (_selectedStartDate != null || _selectedEndDate != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // SAVE BUTTON
                if (canSave)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_selectedStartDate != null &&
                            _selectedEndDate != null) {
                          widget.onRangeSelected(
                            _selectedStartDate,
                            _selectedEndDate,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedTickDouble03,
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text("Save"),
                        ],
                      ),
                    ),
                  ),

                if (canSave) SizedBox(width: 12),

                // CLEAR BUTTON
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedStartDate = null;
                        _selectedEndDate = null;
                        _hoverDate = null;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      side: BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel02,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text("Clear"),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.black87, size: 20),
      ),
    );
  }
}
