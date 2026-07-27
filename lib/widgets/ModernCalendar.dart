import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hugeicons/hugeicons.dart';

class ModernCalendar extends StatefulWidget {
  final DateTime? selectedDate;
  final Function(DateTime) onDateSelected;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<DateTime> selectedDates;

  const ModernCalendar({
    super.key,
    this.selectedDate,
    this.selectedDates = const [],
    required this.onDateSelected,
    this.startDate,
    this.endDate,
  });

  @override
  State<ModernCalendar> createState() => _ModernCalendarState();
}

class _ModernCalendarState extends State<ModernCalendar>
    with SingleTickerProviderStateMixin {
  late DateTime _currentMonth;
  late DateTime _selectedDate;
  double scale = 1.0;
  bool _hasUserSelectedDate = false;

  late AnimationController _swipeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  double _dragOffset = 0.0;
  bool _isDragging = false;
  int _swipeDirection = 0;

  final List<String> _weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate ?? DateTime.now();
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month);

    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _swipeController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(parent: _swipeController, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(parent: _swipeController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  void _previousMonth() {
    setState(() {
      _swipeDirection = -1;
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _triggerSwipeAnimation();
    });
  }

  void _nextMonth() {
    setState(() {
      _swipeDirection = 1;
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _triggerSwipeAnimation();
    });
  }

  void _triggerSwipeAnimation() {
    _swipeController.reset();

    final offsetX = _swipeDirection * 0.4;
    _slideAnimation = Tween<Offset>(
      begin: Offset(offsetX, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _swipeController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _swipeController, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _swipeController, curve: Curves.easeOutCubic),
    );

    _swipeController.forward();
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

    while (days.length % 7 != 0) {
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

    return GestureDetector(
      onHorizontalDragStart: (details) {
        _isDragging = true;
        _dragOffset = 0.0;
      },
      onHorizontalDragUpdate: (details) {
        if (!_isDragging) return;
        _dragOffset += details.delta.dx;
        setState(() {});
      },
      onHorizontalDragEnd: (details) {
        _isDragging = false;
        if (_dragOffset.abs() > 50) {
          if (_dragOffset > 0) {
            _previousMonth();
          } else {
            _nextMonth();
          }
        } else {
          setState(() {
            _dragOffset = 0.0;
          });
        }
        _dragOffset = 0.0;
      },
      child: ClipRRect(
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
                _buildHeader(width),
                _buildWeekdays(width),
                AnimatedBuilder(
                  animation: _swipeController,
                  builder: (context, child) {
                    double offsetX = 0.0;
                    double opacity = 1.0;
                    double scaleValue = 1.0;

                    if (_swipeController.isAnimating) {
                      offsetX = _slideAnimation.value.dx;
                      opacity = _fadeAnimation.value;
                      scaleValue = _scaleAnimation.value;
                    } else if (_isDragging) {
                      offsetX = (_dragOffset / 300).clamp(-0.5, 0.5);
                      opacity = 1.0 - (offsetX.abs() * 0.3);
                      scaleValue = 1.0 - (offsetX.abs() * 0.05);
                    }

                    // Clamp values to safe ranges
                    offsetX = offsetX.clamp(-0.5, 0.5);
                    opacity = opacity.clamp(0.0, 1.0);
                    scaleValue = scaleValue.clamp(0.5, 1.0);

                    return Transform.translate(
                      offset: Offset(offsetX * width, 0),
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.scale(scale: scaleValue, child: child),
                      ),
                    );
                  },
                  child: _buildGrid(days),
                ),
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
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final curved = CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          );

                          final scale = Tween<double>(
                            begin: 0.5,
                            end: 1.0,
                          ).animate(curved);

                          final fade = Tween<double>(
                            begin: 0.0,
                            end: 1.0,
                          ).animate(curved);

                          return ScaleTransition(
                            scale: scale,
                            child: FadeTransition(opacity: fade, child: child),
                          );
                        },
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
                                      backgroundColor: Colors.blue.shade600,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        HugeIcon(
                                          icon:
                                              HugeIcons
                                                  .strokeRoundedTickDouble03,
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
      ),
    );
  }

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
          final isCurrentMonth = _isCurrentMonth(date);
          final isSelected = _isSelected(date);

          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap:
                isCurrentMonth
                    ? () {
                      setState(() {
                        _selectedDate = date;
                        _hasUserSelectedDate = true;
                      });
                    }
                    : null,
            child: Container(
              margin: EdgeInsets.all(2 * scale),
              decoration: BoxDecoration(
                color: _getDateColor(date, isCurrentMonth),
                borderRadius: BorderRadius.circular(10),
                gradient:
                    isSelected
                        ? LinearGradient(
                          colors: [
                            Colors.blue.shade600,
                            Colors.purple.shade600,
                          ],
                        )
                        : null,
                boxShadow:
                    isSelected
                        ? [
                          BoxShadow(
                            color: Colors.blue.shade300.withOpacity(0.3),
                            blurRadius: 6.0,
                            offset: const Offset(0, 2),
                          ),
                        ]
                        : null,
              ),
              child: Center(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontSize: 14 * scale,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: _getTextColor(date, isCurrentMonth),
                  ),
                  child: Text(date.day.toString()),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color? _getDateColor(DateTime date, bool isCurrentMonth) {
    if (_isSelected(date)) return null;
    if (_isInRange(date)) return Colors.blue.shade100.withOpacity(0.5);
    if (!isCurrentMonth) return Colors.grey.shade50;
    return null;
  }

  Color _getTextColor(DateTime date, bool isCurrentMonth) {
    if (_isSelected(date)) return Colors.white;
    if (!isCurrentMonth) return Colors.grey.shade400;
    return Colors.black87;
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
              blurRadius: 6.0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}
