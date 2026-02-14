// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:bizmate/screens/Camera%20rental%20page/rental_sale_detail_screen.dart'
    show RentalSaleDetailScreen;
import 'package:bizmate/widgets/advanced_search_bar.dart'
    show AdvancedSearchBar;
import 'package:bizmate/widgets/rental_sale_menu.dart' show RentalSaleMenu;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/rental_sale_model.dart';

class CameraRentalPage extends StatefulWidget {
  final String userName;
  final String userPhone;
  final String userEmail;

  const CameraRentalPage({
    super.key,
    required this.userName,
    required this.userPhone,
    required this.userEmail,
  });

  @override
  State<CameraRentalPage> createState() => _CameraRentalPageState();
}

class _CameraRentalPageState extends State<CameraRentalPage> {
  final ScrollController _scrollController = ScrollController();
  int _previousSaleCount = 0;
  LinearGradient getProgressGradient(double percentage) {
    if (percentage <= 20) {
      return const LinearGradient(
        colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
      );
    } else if (percentage <= 50) {
      return const LinearGradient(
        colors: [Color(0xFFE53935), Color(0xFFFFA726)],
      );
    } else if (percentage <= 75) {
      return const LinearGradient(
        colors: [Color(0xFFFFA726), Color(0xFFFFEB3B), Color(0xFF66BB6A)],
      );
    } else {
      return const LinearGradient(
        colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
      );
    }
  }

  int _findOriginalSaleIndex(
    List<RentalSaleModel> allSales,
    RentalSaleModel groupedSale,
  ) {
    return allSales.indexWhere((s) => s.id == groupedSale.id);
  }

  double scale = 1.0;

  double _calculatedRatePerDay(RentalSaleModel sale) {
    if (sale.numberOfDays <= 0) return 0;
    return sale.totalCost / sale.numberOfDays;
  }

  late Box userBox;
  bool _isLoading = true;
  List<RentalSaleModel> rentalSales = [];

  bool _hasMultipleItems(RentalSaleModel sale) {
    return sale.itemName.split(',').length > 1;
  }

  List<String> _getItemNames(RentalSaleModel sale) {
    return sale.itemName
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<RentalSaleModel> _groupSales(List<RentalSaleModel> sales) {
    final Map<String, RentalSaleModel> grouped = {};

    for (final sale in sales) {
      final key =
          '${sale.customerName}_${sale.customerPhone}_${sale.fromDateTime}_${sale.toDateTime}';

      if (grouped.containsKey(key)) {
        final existing = grouped[key]!;

        grouped[key] = existing.copyWith(
          itemName: '${existing.itemName}, ${sale.itemName}',
          totalCost: existing.totalCost + sale.totalCost,
          amountPaid: existing.amountPaid + sale.amountPaid,
        );
      } else {
        grouped[key] = sale;
      }
    }

    return grouped.values.toList();
  }

  // Search functionality variables
  String _searchQuery = "";
  DateTimeRange? _selectedRange;

  @override
  void initState() {
    super.initState();
    _initUserBoxAndListener();
    _loadProfileImage();
  }

  Future<void> _initUserBoxAndListener() async {
    try {
      final safeEmail = widget.userEmail
          .toString()
          .replaceAll('.', '_')
          .replaceAll('@', '_');
      final boxName = "userdata_$safeEmail";

      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox(boxName);
      }
      userBox = Hive.box(boxName);
    } catch (e) {
      debugPrint('Error opening user box: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _handleDateRangeChanged(DateTimeRange? range) {
    setState(() {
      _selectedRange = range;
    });
  }

  Future<void> _loadProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${widget.userEmail}_profileImagePath';
      final path = prefs.getString(key);

      if (path != null && path.isNotEmpty) {
        final file = File(path);
        final exists = await file.exists();
        if (exists) {
          if (mounted) setState(() {});
        } else {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('Error loading profile image for PDF: $e');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final int hour12 = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    final String period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return "${dateTime.day}/${dateTime.month}/${dateTime.year} "
        "$hour12:$minute $period";
  }

  Widget _buildImage(RentalSaleModel sale, double size) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTabletOrDesktop = screenWidth > 700;
    final adjustedSize = isTabletOrDesktop ? size + 8 : size;

    // ✅ MULTI-ITEM CASE → CUSTOMER LETTER
    if (_hasMultipleItems(sale)) {
      final count = _getItemNames(sale).length;

      return SizedBox(
        width: adjustedSize,
        height: adjustedSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // BACK CARD
            Positioned(
              left: 1.5 * scale,
              top: 1.5 * scale,
              child: Container(
                width: adjustedSize - 14 * scale,
                height: adjustedSize - 14 * scale,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      Colors.blueGrey.shade300,
                      Colors.blueGrey.shade500,
                    ],
                  ),
                ),
              ),
            ),

            // FRONT CARD
            Container(
              width: adjustedSize - 16 * scale,
              height: adjustedSize - 16 * scale,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.photo_camera_rounded,
                  color: Colors.white,
                  size: 30 * scale,
                ),
              ),
            ),

            // COUNT BADGE
            Positioned(
              right: -2 * scale,
              top: -6 * scale,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 5 * scale,
                  vertical: 2 * scale,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "+$count",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8 * scale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ✅ SINGLE ITEM → EXISTING IMAGE LOGIC
    return Container(
      width: adjustedSize,
      height: adjustedSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF), Color(0xFF020617)],
          stops: [0.0, 0.6, 1.0],
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E40AF).withOpacity(0.4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FutureBuilder<bool>(
          future: _checkImageExists(sale.imageUrl),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data == true) {
              return Image.file(
                File(sale.imageUrl!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return _buildPlaceholderImage();
                },
              );
            }
            return _buildPlaceholderImage();
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF), Color(0xFF020617)],
          stops: [0.0, 0.6, 1.0],
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
        ),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_camera, color: Colors.white, size: 32),
          SizedBox(height: 8),
          Text(
            "Camera",
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkImageExists(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) {
      return false;
    }

    try {
      final file = File(imageUrl);
      final exists = await file.exists();
      if (exists) {
        final length = await file.length();
        return length > 0;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking image file: $e');
      return false;
    }
  }

  String getSaleStatus(RentalSaleModel sale) {
    if (sale.amountPaid >= sale.totalCost) {
      return "PAID";
    } else if (sale.amountPaid > 0) {
      return "PARTIAL";
    } else {
      return "DUE";
    }
  }

  Color getSaleStatusColor(RentalSaleModel sale) {
    switch (getSaleStatus(sale)) {
      case "PAID":
        return const Color(0xFF00C853);
      case "PARTIAL":
        return const Color(0xFFFF9800);
      case "DUE":
        return const Color(0xFFF44336);
      default:
        return Colors.grey;
    }
  }

  double get totalSalesAmount {
    return rentalSales.fold(0, (sum, sale) => sum + sale.totalCost);
  }

  Widget _buildStatusBadge(RentalSaleModel sale) {
    final status = getSaleStatus(sale);
    final color = getSaleStatusColor(sale);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.7), width: 1),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10 * scale,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return ValueListenableBuilder(
      valueListenable: userBox.listenable(),
      builder: (context, Box box, _) {
        List<RentalSaleModel> allSales = [];
        try {
          allSales = List<RentalSaleModel>.from(
            box.get("rental_sales", defaultValue: []),
          );
          // 🔥 AUTO SCROLL WHEN NEW SALE ADDED
          if (allSales.length > _previousSaleCount) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                );
              }
            });
          }

          _previousSaleCount = allSales.length;
        } catch (_) {
          allSales = [];
        }

        final totalAmount = allSales.fold(
          0.0,
          (sum, sale) => sum + sale.totalCost,
        );
        final totalPaid = allSales.fold(
          0.0,
          (sum, sale) => sum + sale.amountPaid,
        );
        final totalDue = totalAmount - totalPaid;
        final totalRentals = allSales.length;

        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: 12 * scale,
            vertical: 0 * scale,
          ),
          padding: EdgeInsets.all(16 * scale),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1E40AF), Color(0xFF020617)],
              stops: [0.0, 0.6, 1.0],
              begin: Alignment.bottomRight,
              end: Alignment.topLeft,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E40AF).withOpacity(0.4),

                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                Icons.camera_alt,
                totalRentals.toString(),
                "Rentals",
              ),
              _buildStatItem(
                Icons.currency_rupee,
                "₹${totalAmount.toInt()}",
                "Total",
              ),
              _buildStatItem(Icons.trending_up, "₹${totalDue.toInt()}", "Due"),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20 * scale * scale),
        SizedBox(height: 4 * scale),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14 * scale,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 2 * scale),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 10 * scale,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSaleCard(RentalSaleModel sale, int index, bool isWide) {
    final horizontalMargin = 10.0 * scale;
    final verticalMargin = 8.0 * scale;
    final radius = 20.0 * scale;
    final padding = EdgeInsets.all(12 * scale);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalMargin,
        vertical: verticalMargin,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300.withOpacity(0.7),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: () async {
            if (index < 0) return;

            await Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => RentalSaleDetailScreen(
                      sale: sale,
                      index: index,
                      userEmail: widget.userEmail,
                    ),
              ),
            );
          },

          child: Padding(
            padding: padding,
            child:
                isWide
                    ? _buildWideLayout(sale, index)
                    : _buildMobileLayout(sale, index),
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(RentalSaleModel sale, int index) {
    final items = _getItemNames(sale);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildImage(sale, 80),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderRow(sale, index),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    items.take(2).join(', '),
                    style: TextStyle(
                      fontSize: 12 * scale,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (items.length > 2)
                    Text(
                      "+${items.length - 2} more",
                      style: TextStyle(
                        fontSize: 12 * scale,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _buildDetailsRow(sale),
              const SizedBox(height: 12),
              _buildAmountProgress(sale),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(RentalSaleModel sale, int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallPhone = screenWidth < 360;
    final items = _getItemNames(sale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(sale, isSmallPhone ? 52 : 60),
            SizedBox(width: 10 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderRow(sale, index),
                  SizedBox(height: 4 * scale),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items.take(2).join(', '),
                        style: TextStyle(
                          fontSize: 8 * scale,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (items.length > 2)
                        Text(
                          "+${items.length - 2} more",
                          style: TextStyle(
                            fontSize: 10 * scale,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildDetailsRow(sale),
        const SizedBox(height: 12),
        _buildAmountProgress(sale),
      ],
    );
  }

  Widget _buildHeaderRow(RentalSaleModel sale, int index) {
    final customerPhone = sale.customerPhone.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sale.customerName,
                style: TextStyle(
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1a1a1a),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              if (customerPhone.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.phone,
                      size: 12 * scale,
                      color: Colors.grey.shade600,
                    ),
                    SizedBox(width: 4 * scale),
                    Text(
                      customerPhone,
                      style: TextStyle(
                        fontSize: 12 * scale,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          children: [
            const SizedBox(width: 8),
            RentalSaleMenu(
              sale: sale,
              originalIndex: index,
              userBox: userBox,
              isSmallScreen: MediaQuery.of(context).size.width < 600,
              currentUserName: widget.userName,
              currentUserPhone: widget.userPhone,
              currentUserEmail: widget.userEmail,
              parentContext: context,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailsRow(RentalSaleModel sale) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Adaptive max chip width → behaves like real production apps
        double maxChipWidth = (constraints.maxWidth / 2) - 20;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxChipWidth),
                  child: _buildDetailChip(
                    icon: Icons.calendar_today,
                    value: '${sale.numberOfDays} days',
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxChipWidth),
                  child: _buildDetailChip(
                    icon: Icons.currency_rupee,
                    value:
                        '₹${_calculatedRatePerDay(sale).toStringAsFixed(0)}/day',
                  ),
                ),
              ],
            ),

            SizedBox(height: 8 * scale),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxChipWidth),
                  child: _buildDateChip(
                    'From',
                    _formatDateTime(sale.fromDateTime),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxChipWidth),
                  child: _buildDateChip('To', _formatDateTime(sale.toDateTime)),
                ),
              ],
            ),
            SizedBox(height: 10 * scale),
            _buildStatusBadge(sale),
          ],
        );
      },
    );
  }

  Widget _buildAmountProgress(RentalSaleModel sale) {
    final double progress =
        sale.totalCost > 0 ? sale.amountPaid / sale.totalCost : 0.0;

    final double percentage = progress * 100;
    final balanceDue = sale.totalCost - sale.amountPaid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '₹${sale.amountPaid.toInt()} paid',
              style: TextStyle(
                fontSize: 12 * scale,
                fontWeight: FontWeight.w600,
                color: Color(0xFF00C853),
              ),
            ),
            Text(
              '₹${balanceDue.toInt()} due',
              style: TextStyle(
                fontSize: 12 * scale,
                fontWeight: FontWeight.w600,
                color:
                    balanceDue > 0
                        ? const Color(0xFFF44336)
                        : const Color(0xFF00C853),
              ),
            ),
          ],
        ),
        SizedBox(height: 8 * scale),
        Container(
          height: 8 * scale,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                width: constraints.maxWidth * progress,
                decoration: BoxDecoration(
                  gradient: getProgressGradient(percentage),
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            },
          ),
        ),

        SizedBox(height: 8 * scale),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total: ₹${sale.totalCost.toInt()}',
              style: TextStyle(
                fontSize: 10 * scale,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 10 * scale,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailChip({required IconData icon, required String value}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 6 * scale),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 8 * scale),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 8 * scale,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 6 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 8 * scale * scale,
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 8 * scale,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTabletOrDesktop = screenWidth > 700;
    final maxWidth = isTabletOrDesktop ? 400.0 : double.infinity;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isTabletOrDesktop ? 140 : 120,
              height: isTabletOrDesktop ? 140 : 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.photo_camera_outlined,
                size: isTabletOrDesktop ? 60 : 50,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "No Rental Sales",
              style: TextStyle(
                fontSize: isTabletOrDesktop ? 22 : 20,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Start by adding your first camera rental sale to get started",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTabletOrDesktop = screenWidth > 700;
    final maxWidth = isTabletOrDesktop ? 400.0 : double.infinity;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: isTabletOrDesktop ? 90 : 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              "No Results Found",
              style: TextStyle(
                fontSize: isTabletOrDesktop ? 20 : 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _searchQuery.isNotEmpty && _selectedRange != null
                    ? "No results for '$_searchQuery' in selected date range"
                    : _searchQuery.isNotEmpty
                    ? "No results for '$_searchQuery'"
                    : "No rentals found in selected date range",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf8f9fa),
      body: AbsorbPointer(
        absorbing: _isLoading,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: AdvancedSearchBar(
                  hintText: 'Search customers, items, phone...',
                  onSearchChanged: _handleSearchChanged,
                  onDateRangeChanged: _handleDateRangeChanged,
                  showDateFilter: true,
                ),
              ),
              SliverToBoxAdapter(child: _buildStatsCard()),
            ];
          },
          body:
              _isLoading
                  ? _buildLoadingState()
                  : ValueListenableBuilder(
                    valueListenable: userBox.listenable(),
                    builder: (context, Box box, _) {
                      List<RentalSaleModel> allSales = [];
                      try {
                        allSales = List<RentalSaleModel>.from(
                          box.get("rental_sales", defaultValue: []),
                        );
                      } catch (_) {
                        allSales = [];
                      }

                      allSales.sort(
                        (a, b) => b.rentalDateTime.compareTo(a.rentalDateTime),
                      );

                      List<RentalSaleModel> filteredSales = _groupSales(
                        List<RentalSaleModel>.from(allSales),
                      );

                      if (_searchQuery.isNotEmpty) {
                        final query = _searchQuery.toLowerCase();
                        filteredSales =
                            filteredSales.where((sale) {
                              final customerName =
                                  sale.customerName.toLowerCase();
                              final itemName = sale.itemName.toLowerCase();
                              final customerPhone =
                                  sale.customerPhone.toLowerCase();
                              final totalCost = sale.totalCost.toString();
                              final amountPaid = sale.amountPaid.toString();
                              final fromDate =
                                  _formatDateTime(
                                    sale.fromDateTime,
                                  ).toLowerCase();
                              final toDate =
                                  _formatDateTime(
                                    sale.toDateTime,
                                  ).toLowerCase();

                              return customerName.contains(query) ||
                                  itemName.contains(query) ||
                                  customerPhone.contains(query) ||
                                  totalCost.contains(query) ||
                                  amountPaid.contains(query) ||
                                  fromDate.contains(query) ||
                                  toDate.contains(query);
                            }).toList();
                      }

                      if (_selectedRange != null) {
                        filteredSales =
                            filteredSales.where((sale) {
                              return sale.fromDateTime.isAfter(
                                    _selectedRange!.start.subtract(
                                      const Duration(days: 1),
                                    ),
                                  ) &&
                                  sale.toDateTime.isBefore(
                                    _selectedRange!.end.add(
                                      const Duration(days: 1),
                                    ),
                                  );
                            }).toList();
                      }

                      if (allSales.isEmpty) {
                        return _buildEmptyState();
                      }

                      if (filteredSales.isEmpty) {
                        return _buildNoResultsState();
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isVeryWide = constraints.maxWidth > 1000;
                          final maxWidth =
                              isVeryWide ? 900.0 : constraints.maxWidth;

                          return Column(
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isVeryWide ? 32 : 24,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.list_alt_rounded,
                                      color: Colors.grey.shade600,
                                      size: 14 * scale,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${filteredSales.length} ${filteredSales.length == 1 ? 'rental' : 'rentals'}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12 * scale,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'Latest first',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 10 * scale,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: maxWidth,
                                    ),
                                    child: ListView.builder(
                                      controller: _scrollController,
                                      padding: EdgeInsets.only(
                                        bottom: 20 * scale,
                                      ),
                                      itemCount: filteredSales.length,
                                      itemBuilder: (context, index) {
                                        final sale = filteredSales[index];
                                        final originalIndex =
                                            _findOriginalSaleIndex(
                                              allSales,
                                              sale,
                                            );

                                        return LayoutBuilder(
                                          builder: (context, cardConstraints) {
                                            final isWideCard =
                                                cardConstraints.maxWidth > 600;
                                            return _buildSaleCard(
                                              sale,
                                              originalIndex,
                                              isWideCard,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTabletOrDesktop = screenWidth > 700;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: isTabletOrDesktop ? 90 : 80,
            height: isTabletOrDesktop ? 90 : 80,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF1E40AF),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Loading Rentals...",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: isTabletOrDesktop ? 18 : 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
