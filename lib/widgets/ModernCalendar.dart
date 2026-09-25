import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

class ModernCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const ModernCalendar({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<ModernCalendar> createState() => _ModernCalendarState();
}

class _ModernCalendarState extends State<ModernCalendar>
    with TickerProviderStateMixin {
  late DateTime _currentMonth;
  late DateTime _selectedDate;

  double _dragOffset = 0.0;
  bool _hasUserSelectedDate = false;

  late AnimationController _swipeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  final List<String> _weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  double get scale => 1.0;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month);

    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _swipeController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  void _previousMonth() {
    _animateMonthChange(isNext: false);
  }

  void _nextMonth() {
    _animateMonthChange(isNext: true);
  }

  void _animateMonthChange({required bool isNext}) {
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(isNext ? -1.0 : 1.0, 0.0),
    ).animate(
      CurvedAnimation(parent: _swipeController, curve: Curves.easeOutCubic),
    );

    _swipeController.forward().then((_) {
      setState(() {
        _currentMonth = DateTime(
          _currentMonth.year,
          isNext ? _currentMonth.month + 1 : _currentMonth.month - 1,
        );
      });

      _slideAnimation = Tween<Offset>(
        begin: Offset(isNext ? 1.0 : -1.0, 0.0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: _swipeController, curve: Curves.easeOutCubic),
      );

      _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _swipeController, curve: Curves.easeIn),
      );

      _swipeController.reverse();
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSelected(DateTime date) {
    return _isSameDay(_selectedDate, date);
  }

  bool _isCurrentMonth(DateTime date) {
    return date.month == _currentMonth.month && date.year == _currentMonth.year;
  }

  List<DateTime> _getDaysForMonth() {
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );
    final daysBefore = firstDayOfMonth.weekday % 7;

    final startDate = firstDayOfMonth.subtract(Duration(days: daysBefore));

    return List.generate(42, (index) => startDate.add(Duration(days: index)));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragOffset += details.primaryDelta!;
        });
      },
      onHorizontalDragEnd: (details) {
        if (_dragOffset > 50) {
          _previousMonth();
        } else if (_dragOffset < -50) {
          _nextMonth();
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
              color:
                  isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context, width),
                _buildWeekdays(context, width),
                AnimatedBuilder(
                  animation: _swipeController,
                  builder: (context, child) {
                    double offsetX = 0.0;
                    double opacity = 1.0;
                    double scaleValue = 1.0;

                    if (_swipeController.isAnimating) {
                      offsetX = _slideAnimation.value.dx;
                      opacity = _fadeAnimation.value;
                      scaleValue = 0.95 + (0.05 * opacity);
                    }

                    return Transform.translate(
                      offset: Offset(offsetX * 50, 0),
                      child: Transform.scale(
                        scale: scaleValue,
                        child: Opacity(
                          opacity: opacity.clamp(0.0, 1.0),
                          child: _buildGrid(context, _getDaysForMonth()),
                        ),
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) {
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      );
                      return ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.5,
                          end: 1.0,
                        ).animate(curved),
                        child: FadeTransition(
                          opacity: Tween<double>(
                            begin: 0.0,
                            end: 1.0,
                          ).animate(curved),
                          child: child,
                        ),
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
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    HugeIcon(
                                      icon: HugeIcons.strokeRoundedTickDouble03,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, double width) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor =
        isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A1A);
    final subtitleColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _navButton(context, Icons.chevron_left_rounded, _previousMonth),
          Column(
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_currentMonth),
                style: TextStyle(
                  fontSize: width * 0.045,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Select a date",
                style: TextStyle(fontSize: width * 0.03, color: subtitleColor),
              ),
            ],
          ),
          _navButton(context, Icons.chevron_right_rounded, _nextMonth),
        ],
      ),
    );
  }

  Widget _buildWeekdays(BuildContext context, double width) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weekdayColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

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
                          color: weekdayColor,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<DateTime> days) {
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
                color: _getDateColor(context, date, isCurrentMonth),
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
                            color: Colors.blue.shade300.withValues(alpha: 0.3),
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
                    color: _getTextColor(context, date, isCurrentMonth),
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

  Color? _getDateColor(
    BuildContext context,
    DateTime date,
    bool isCurrentMonth,
  ) {
    if (_isSelected(date)) return null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isCurrentMonth)
      return isDark
          ? const Color(0xFF0F172A).withValues(alpha: 0.4)
          : Colors.grey.shade50;
    return null;
  }

  Color _getTextColor(
    BuildContext context,
    DateTime date,
    bool isCurrentMonth,
  ) {
    if (_isSelected(date)) return Colors.white;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isCurrentMonth)
      return isDark ? const Color(0xFF475569) : Colors.grey.shade400;
    return isDark ? const Color(0xFFF1F5F9) : Colors.black87;
  }

  Widget _navButton(BuildContext context, IconData icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final btnBg = isDark ? const Color(0xFF334155) : Colors.white;
    final iconColor = isDark ? const Color(0xFFF1F5F9) : Colors.black87;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: btnBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.1),
              blurRadius: 6.0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );
  }
}
