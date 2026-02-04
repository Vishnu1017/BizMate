// lib/widgets/advanced_search_bar.dart
import 'package:bizmate/widgets/modern_calendar_range.dart'
    show ModernCalendarRange;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum DateRangePreset {
  today,
  thisWeek,
  thisMonth,
  thisQuarter,
  thisFinancialYear,
  custom,
}

class AdvancedSearchBar extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;
  final bool showDateFilter;
  final String? initialSearchQuery;

  const AdvancedSearchBar({
    super.key,
    this.hintText = 'Search...',
    required this.onSearchChanged,
    required this.onDateRangeChanged,
    this.showDateFilter = true,
    this.initialSearchQuery,
  });

  @override
  State<AdvancedSearchBar> createState() => _AdvancedSearchBarState();
}

class _AdvancedSearchBarState extends State<AdvancedSearchBar>
    with SingleTickerProviderStateMixin {
  // controllers / nodes
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey _searchBarKey = GlobalKey();

  // UI state
  bool _isSearchFocused = false;
  DateTimeRange? selectedRange;
  DateRangePreset? selectedPreset;

  // Overlay
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isMenuOpen = false;

  // Animations (nullable -> lazy init)
  AnimationController? _animationController;
  Animation<double>? _scaleAnimation;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  // Track initialization
  bool _animationsInitialized = false;

  // Keep small / base sizes (we will scale them depending on screen width)
  static const double _baseIconSize = 20.0;
  static const double _basePadding = 16.0;
  static const double _baseHeight = 44.0;

  @override
  void initState() {
    super.initState();

    // Apply initial search query if provided
    if (widget.initialSearchQuery != null) {
      _searchController.text = widget.initialSearchQuery!;
    }

    // Listen to focus change
    _searchFocusNode.addListener(() {
      if (!mounted) return;
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    });

    // Listen to text changes so UI updates (clear button visibility)
    _searchController.addListener(_onSearchTextChanged);

    // Lazily initialize animations after first frame (covers normal case)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureAnimationsInitialized();
    });
  }

  void _onSearchTextChanged() {
    if (!mounted) return;
    // only call setState when necessary to avoid unnecessary rebuilds
    setState(() {});
  }

  @override
  void dispose() {
    _removeOverlay();

    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();

    if (_animationController != null) {
      if (_animationController!.isAnimating) {
        _animationController!.stop(canceled: true);
      }
      _animationController!.dispose();
      _animationController = null;
    }

    _scaleAnimation = null;
    _fadeAnimation = null;
    _slideAnimation = null;
    _animationsInitialized = false;

    super.dispose();
  }

  // -----------------------
  // Animation initialization (lazy + safe)
  // -----------------------
  void _ensureAnimationsInitialized() {
    if (_animationsInitialized) return;
    if (!mounted) return;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeOut),
    );

    _animationsInitialized = true;
  }

  // ============================================================
  // MODERN CALENDAR PICKER - FIXED VERSION
  // ============================================================
  Future<void> _showModernCalendar(BuildContext context) async {
    // Hide the dropdown menu immediately
    _hideMenu();

    // Store the current selected dates for the calendar
    final DateTime? currentStartDate = selectedRange?.start;
    final DateTime? currentEndDate = selectedRange?.end;

    // Show ModernCalendarRange for date range selection
    final DateTimeRange? result = await showModalBottomSheet<DateTimeRange?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ModernCalendarRange(
          selectedStartDate: currentStartDate,
          selectedEndDate: currentEndDate,
          onRangeSelected: (startDate, endDate) {
            // If both dates are selected, close the modal and return the range
            if (startDate != null && endDate != null) {
              Navigator.of(
                context,
              ).pop(DateTimeRange(start: startDate, end: endDate));
            }
          },
        );
      },
    );

    // Handle the result from calendar
    if (result != null && mounted) {
      setState(() {
        selectedRange = result;
        selectedPreset = DateRangePreset.custom;
      });
      // Notify parent about the date range change
      widget.onDateRangeChanged(selectedRange);
    }
  }

  // ============================================================
  // DATE RANGE HANDLING
  // ============================================================
  void _handlePresetSelection(DateRangePreset preset) {
    if (preset == DateRangePreset.custom) {
      _showModernCalendar(context);
      return;
    }

    final now = DateTime.now();
    late DateTime start;
    late DateTime end;

    switch (preset) {
      case DateRangePreset.today:
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(
          now.year,
          now.month,
          now.day + 1,
        ).subtract(const Duration(microseconds: 1));
        break;

      case DateRangePreset.thisWeek:
        start = DateTime(now.year, now.month, now.day - (now.weekday - 1));
        end = DateTime(
          start.year,
          start.month,
          start.day + 7,
        ).subtract(const Duration(microseconds: 1));
        break;

      case DateRangePreset.thisMonth:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(
          now.year,
          now.month + 1,
          1,
        ).subtract(const Duration(microseconds: 1));
        break;

      case DateRangePreset.thisQuarter:
        final q = ((now.month - 1) ~/ 3) + 1;
        final qs = (q - 1) * 3 + 1;
        final qe = qs + 3;

        start = DateTime(now.year, qs, 1);
        end = DateTime(
          now.year,
          qe,
          1,
        ).subtract(const Duration(microseconds: 1));
        break;

      case DateRangePreset.thisFinancialYear:
        if (now.month >= 4) {
          start = DateTime(now.year, 4, 1);
          end = DateTime(
            now.year + 1,
            4,
            1,
          ).subtract(const Duration(microseconds: 1));
        } else {
          start = DateTime(now.year - 1, 4, 1);
          end = DateTime(
            now.year,
            4,
            1,
          ).subtract(const Duration(microseconds: 1));
        }
        break;

      case DateRangePreset.custom:
        return;
    }

    setState(() {
      selectedPreset = preset;
      selectedRange = DateTimeRange(start: start, end: end);
    });

    _hideMenu();
    widget.onDateRangeChanged(selectedRange);
  }

  void _clearDateFilter() {
    if (!mounted) return;
    setState(() {
      selectedRange = null;
      selectedPreset = null;
    });
    widget.onDateRangeChanged(null);
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    widget.onSearchChanged("");
  }

  // ============================================================
  // OVERLAY MENU HANDLING (safe)
  // ============================================================
  void _toggleMenu() => _isMenuOpen ? _hideMenu() : _showMenu();

  void _showMenu() {
    _ensureAnimationsInitialized();
    if (!_animationsInitialized || !mounted) return;

    _removeOverlay();

    final screenWidth = MediaQuery.of(context).size.width;

    // Measure search bar width using key (safe)
    final RenderBox? barBox =
        _searchBarKey.currentContext?.findRenderObject() as RenderBox?;
    final double barWidth = barBox?.size.width ?? screenWidth;

    // Menu width logic (your current logic preserved)
    final double menuWidth = screenWidth < 350 ? (screenWidth * 0.92) : 320.0;

    // RIGHT ALIGN MENU ↓↓↓
    final double dx = (barWidth - menuWidth) / 1.35;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return GestureDetector(
          onTap: _hideMenu,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(color: Colors.black.withOpacity(0.40)),
              ),

              CompositedTransformFollower(
                link: _layerLink,
                offset: Offset(dx, 60), // ⭐ RIGHT ALIGNED MENU
                showWhenUnlinked: false,
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: menuWidth,
                      minWidth: menuWidth,
                    ),
                    child: SlideTransition(
                      position: _slideAnimation!,
                      child: FadeTransition(
                        opacity: _fadeAnimation!,
                        child: ScaleTransition(
                          scale: _scaleAnimation!,
                          child: _buildMenuUI(menuWidth),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    _isMenuOpen = true;
    _animationController?.forward();
  }

  void _hideMenu() {
    if (!_animationsInitialized || !mounted) {
      _removeOverlay();
      return;
    }

    _animationController?.reverse().then((_) {
      if (mounted) _removeOverlay();
    });
  }

  void _removeOverlay() {
    try {
      _overlayEntry?.remove();
    } catch (_) {
      // ignore
    }
    _overlayEntry = null;
    _isMenuOpen = false;
  }

  // ============================================================
  // MENU UI
  // ============================================================
  Widget _buildMenuUI(double width) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    // 🔥 Correct fully responsive width
    final double responsiveWidth =
        size.width < 500
            ? size.width *
                0.92 // Mobile
            : size.width < 900
            ? size.width *
                0.60 // Tablet
            : size.width * 0.40; // Desktop

    final double maxHeight = size.height * 0.40;

    return Align(
      alignment: Alignment.topCenter, // 🔥 Forces perfect horizontal centering
      child: Container(
        margin: const EdgeInsets.only(top: 10), // optional small top spacing
        child: Material(
          elevation: 20,
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: responsiveWidth,
              minWidth: responsiveWidth,
              maxHeight: maxHeight,
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom: padding.bottom + 2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Time Filter',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 6),

                  Text(
                    'Filter your results by date range',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      physics: const BouncingScrollPhysics(),
                      itemCount: DateRangePreset.values.length,
                      itemBuilder: (context, index) {
                        final preset = DateRangePreset.values[index];
                        return _buildMenuItem(
                          context,
                          preset,
                          _getPresetIcon(preset),
                          _getPresetLabel(preset),
                          _getPresetDescription(preset),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    DateRangePreset preset,
    IconData icon,
    String label,
    String description,
  ) {
    final isSelected = selectedPreset == preset;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handlePresetSelection(preset),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color:
                isSelected ? const Color(0xFF1E40AF).withOpacity(0.08) : null,
            border: Border.all(
              color:
                  isSelected
                      ? const Color(0xFF1E40AF).withOpacity(0.28)
                      : const Color(0xFFF3F4F6),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient:
                      isSelected
                          ? const LinearGradient(
                            colors: [
                              Color(0xFF2563EB),
                              Color(0xFF1E40AF),
                              Color(0xFF020617),
                            ],
                            stops: [0.0, 0.6, 1.0],
                            begin: Alignment.bottomRight,
                            end: Alignment.topLeft,
                          )
                          : null,
                  color: isSelected ? null : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),

                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : const Color(0xFF6B7280),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? const Color(0xFF1E40AF) : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isSelected
                                ? const Color(0xFF1E40AF).withOpacity(0.6)
                                : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  size: 18,
                  color: Color(0xFF1E40AF),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ICONS + LABELS
  // ============================================================
  IconData _getPresetIcon(DateRangePreset preset) {
    switch (preset) {
      case DateRangePreset.today:
        return Icons.today_rounded;
      case DateRangePreset.thisWeek:
        return Icons.calendar_view_week_rounded;
      case DateRangePreset.thisMonth:
        return Icons.calendar_month_rounded;
      case DateRangePreset.thisQuarter:
        return Icons.timeline_rounded;
      case DateRangePreset.thisFinancialYear:
        return Icons.account_balance_wallet_rounded;
      case DateRangePreset.custom:
        return Icons.date_range_rounded;
    }
  }

  String _getPresetLabel(DateRangePreset p) {
    switch (p) {
      case DateRangePreset.today:
        return 'Today';
      case DateRangePreset.thisWeek:
        return 'This Week';
      case DateRangePreset.thisMonth:
        return 'This Month';
      case DateRangePreset.thisQuarter:
        return 'This Quarter';
      case DateRangePreset.thisFinancialYear:
        return 'Financial Year';
      case DateRangePreset.custom:
        return 'Custom Range';
    }
  }

  String _getPresetDescription(DateRangePreset p) {
    switch (p) {
      case DateRangePreset.today:
        return 'Current day only';
      case DateRangePreset.thisWeek:
        return 'Monday to Sunday';
      case DateRangePreset.thisMonth:
        return 'Entire month view';
      case DateRangePreset.thisQuarter:
        return '3 month period';
      case DateRangePreset.thisFinancialYear:
        return 'April 1 to March 31';
      case DateRangePreset.custom:
        return 'Select any date range';
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Mobile-first scaling (Option A) + keep UI consistent (Option C)
    // Scale factor ranges from 0.9 (very small phones) to 1.0 (normal) to 1.08 (large phones)
    final double scale =
        screenWidth < 340
            ? 0.90
            : (screenWidth < 400 ? 0.96 : (screenWidth < 600 ? 1.0 : 1.08));

    // Horizontal margin: keep small screens tighter, larger screens default
    final horizontal = screenWidth < 350 ? 10.0 : 20.0;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        key: _searchBarKey,
        margin: EdgeInsets.symmetric(
          horizontal: horizontal,
          vertical: 12 * scale,
        ),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: _buildSearchBar(scale),
        ),
      ),
    );
  }

  Widget _buildSearchBar(double scale) {
    final double iconSize = _baseIconSize * (scale);
    final double height = _baseHeight * (scale);
    final double horizontalPadding = (_basePadding - 2) * (scale);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 8 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14 * scale),
        border: Border.all(
          color:
              _isSearchFocused
                  ? const Color(0xFF1E40AF).withOpacity(0.35)
                  : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isSearchFocused ? 0.12 : 0.03),
            blurRadius: _isSearchFocused ? 20 : 10,
            offset: Offset(0, 4 * scale),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: height,
            child: Row(
              children: [
                _buildSearchIconScaled(iconSize, scale),
                SizedBox(width: 12 * scale),
                Expanded(child: _buildSearchInputScaled(scale)),
                if (_searchController.text.isNotEmpty)
                  _buildClearButtonScaled(scale),
                if (widget.showDateFilter) ...[
                  SizedBox(width: 12 * scale),
                  _buildMenuButtonScaled(scale),
                ],
              ],
            ),
          ),
          _buildActiveFilterScaled(scale),
        ],
      ),
    );
  }

  Widget _buildSearchIconScaled(double iconSize, double scale) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      width: 42 * scale,
      height: 42 * scale,
      decoration: BoxDecoration(
        color:
            _isSearchFocused
                ? const Color(0xFF1E40AF).withOpacity(0.1)
                : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10 * scale),
      ),
      child: Icon(
        Icons.search_rounded,
        color:
            _isSearchFocused
                ? const Color(0xFF1E40AF)
                : const Color(0xFF9CA3AF),
        size: iconSize,
      ),
    );
  }

  Widget _buildSearchInputScaled(double scale) {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      style: TextStyle(
        fontSize: 16 * scale,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF111827),
      ),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: TextStyle(
          color: const Color(0xFF9CA3AF),
          fontSize: 16 * scale,
          fontWeight: FontWeight.w400,
        ),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 10 * scale),
      ),
      onChanged: widget.onSearchChanged,
    );
  }

  Widget _buildClearButtonScaled(double scale) {
    return GestureDetector(
      onTap: _clearSearch,
      child: Container(
        width: 32 * scale,
        height: 32 * scale,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8 * scale),
        ),
        child: Icon(
          Icons.close_rounded,
          size: 18 * scale,
          color: const Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _buildMenuButtonScaled(double scale) {
    final filtered = selectedRange != null;
    return GestureDetector(
      onTap: _toggleMenu,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: filtered ? 100 * scale : 44 * scale,
        height: 44 * scale,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12 * scale),
          gradient:
              filtered
                  ? const LinearGradient(
                    colors: [
                      Color(0xFF2563EB),
                      Color(0xFF1E40AF),
                      Color(0xFF020617),
                    ],
                    stops: [0.0, 0.6, 1.0],
                    begin: Alignment.bottomRight,
                    end: Alignment.topLeft,
                  )
                  : null,
          color: filtered ? null : const Color(0xFFF9FAFB),
          border: Border.all(
            color:
                filtered
                    ? const Color(0xFF1E40AF).withOpacity(0.35)
                    : const Color(0xFFE5E7EB),
          ),
          boxShadow:
              filtered
                  ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 6 * scale,
                      offset: Offset(0, 3 * scale),
                    ),
                  ]
                  : [],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                filtered ? Icons.filter_alt_rounded : Icons.tune_rounded,
                size: 20 * scale,
                color: filtered ? Colors.white : const Color(0xFF6B7280),
              ),
              if (filtered) ...[
                SizedBox(width: 8 * scale),
                Text(
                  'Filtered',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget closeButtonPolished(double scale, VoidCallback? onTap) {
    return Semantics(
      button: true,
      label: 'Remove filter',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 30 * scale,
          height: 30 * scale,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
            border: Border.all(
              color: const Color(0xFFEF4444).withOpacity(0.25),
              width: 1.4,
            ),
          ),
          child: Icon(
            Icons.close_rounded,
            size: 16 * scale,
            color: const Color(0xFFEF4444),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilterScaled(double scale) {
    if (selectedRange == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: 14 * scale),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _clearDateFilter,
          borderRadius: BorderRadius.circular(12 * scale),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 12 * scale,
              vertical: 10 * scale,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(12 * scale),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34 * scale,
                  height: 34 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E40AF).withOpacity(0.10),
                  ),
                  child: Icon(
                    _getPresetIcon(selectedPreset!),
                    size: 16 * scale,
                    color: const Color(0xFF1E40AF),
                  ),
                ),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getPresetLabel(selectedPreset!),
                        style: TextStyle(
                          fontSize: 12 * scale,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E40AF),
                        ),
                      ),
                      SizedBox(height: 4 * scale),
                      Text(
                        '${DateFormat('MMM dd, yyyy').format(selectedRange!.start)} - ${DateFormat('MMM dd, yyyy').format(selectedRange!.end)}',
                        style: TextStyle(
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8 * scale),
                closeButtonPolished(1.0, _clearDateFilter),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
