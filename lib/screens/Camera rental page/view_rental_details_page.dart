import 'dart:io';
import 'package:bizmate/models/rental_cart_item.dart';
import 'package:bizmate/models/rental_item.dart';
import 'package:bizmate/models/customer_model.dart';
import 'package:bizmate/models/rental_sale_model.dart' show RentalSaleModel;
import 'package:bizmate/screens/Camera%20rental%20page/rental_add_customer_page.dart'
    show RentalAddCustomerPage;
import 'package:bizmate/screens/Camera%20rental%20page/rental_cart_preview_page.dart';
import 'package:bizmate/services/rental_cart.dart';
import 'package:bizmate/widgets/ModernCalendar.dart' show ModernCalendar;
import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:unicons/unicons.dart';

class ViewRentalDetailsPage extends StatefulWidget {
  final RentalItem item;
  final String name;
  final String imageUrl;
  final double pricePerDay;
  final String availability;

  const ViewRentalDetailsPage({
    super.key,
    required this.item,
    required this.name,
    required this.imageUrl,
    required this.pricePerDay,
    required this.availability,
  });

  @override
  State<ViewRentalDetailsPage> createState() => _ViewRentalDetailsPageState();
}

class _ViewRentalDetailsPageState extends State<ViewRentalDetailsPage> {
  final GlobalKey _addButtonKey = GlobalKey();
  final GlobalKey _cartButtonKey = GlobalKey();

  final ValueNotifier<int> _cartCount = ValueNotifier<int>(0);

  DateTime? fromDate;
  DateTime? toDate;
  String? selectedFromTime;
  String? selectedToTime;
  double scale = 1.0;

  int noOfDays = 0;
  double totalAmount = 0.0;

  bool _validateAddToCart(DateTime from, DateTime to) {
    for (final cartItem in RentalCart.items) {
      if (cartItem.item.name == widget.item.name) {
        final cartFrom = cartItem.fromDateTime;
        final cartTo = cartItem.toDateTime;

        final isOverlap = from.isBefore(cartTo) && to.isAfter(cartFrom);

        if (isOverlap) {
          AppSnackBar.showError(
            context,
            message: "This item is already added for overlapping dates",
            duration: const Duration(seconds: 2),
          );
          return false;
        }
      }
    }
    return true;
  }

  final List<String> timeSlots = [
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '1:00 PM',
    '2:00 PM',
    '3:00 PM',
    '4:00 PM',
    '5:00 PM',
  ];

  String availabilityStatus = "Available";

  late Box userBox;
  List<CustomerModel> userCustomers = [];
  List<RentalSaleModel> userRentalSales = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _cartCount.value = RentalCart.items.length;
  }

  @override
  void dispose() {
    _cartCount.dispose();
    super.dispose();
  }

  void _syncAvailabilityWithCart() {
    final existsInCart = RentalCart.items.any(
      (cartItem) => cartItem.item.name == widget.item.name,
    );

    setState(() {
      availabilityStatus = existsInCart ? "Unavailable" : "Available";
    });
  }

  void _animateAddToCart() {
    final overlay = Overlay.of(context);

    final addBox =
        _addButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final cartBox =
        _cartButtonKey.currentContext?.findRenderObject() as RenderBox?;

    if (addBox == null || cartBox == null) return;

    final addPos = addBox.localToGlobal(Offset.zero);
    final cartPos = cartBox.localToGlobal(Offset.zero);

    final entry = OverlayEntry(
      builder: (context) {
        return TweenAnimationBuilder<Offset>(
          tween: Tween(begin: addPos, end: cartPos),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
          builder: (_, value, child) {
            return Positioned(left: value.dx, top: value.dy, child: child!);
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.orange.shade600,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.5),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Icon(
                UniconsLine.shopping_cart,
                size: 16 * scale,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);

    Future.delayed(const Duration(milliseconds: 750), () {
      entry.remove();
    });
  }

  void _loadUserData() {
    final sessionBox = Hive.box('session');
    final email = sessionBox.get("currentUserEmail", defaultValue: "");

    final safeEmail = email
        .toString()
        .replaceAll('.', '_')
        .replaceAll('@', '_');

    final userBoxName = "userdata_$safeEmail";

    if (!Hive.isBoxOpen(userBoxName)) {
      Hive.openBox(userBoxName);
    }

    userBox = Hive.box(userBoxName);

    userCustomers = List<CustomerModel>.from(
      userBox.get('customers', defaultValue: []),
    );

    userRentalSales = List<RentalSaleModel>.from(
      userBox.get('rental_sales', defaultValue: []),
    );
  }

  void calculateTotal() {
    if (fromDate != null &&
        toDate != null &&
        selectedFromTime != null &&
        selectedToTime != null) {
      final fromDT = _combineDateAndTime(fromDate!, selectedFromTime!);
      final toDT = _combineDateAndTime(toDate!, selectedToTime!);

      final diff = toDT.difference(fromDT).inHours;

      if (diff <= 0) {
        noOfDays = 0;
        totalAmount = 0;
      } else {
        noOfDays = (diff / 24).ceil();
        totalAmount = noOfDays * widget.pricePerDay;
      }

      checkAvailability(fromDT, toDT);
      setState(() {});
    }
  }

  DateTime _combineDateAndTime(DateTime date, String timeString) {
    final DateFormat format = DateFormat("hh:mm a");
    final t = format.parse(timeString);
    return DateTime(date.year, date.month, date.day, t.hour, t.minute);
  }

  bool _validateTimeSelection({required bool isFrom}) {
    if (fromDate == null ||
        toDate == null ||
        selectedFromTime == null ||
        selectedToTime == null) {
      return true; // wait until all values are selected
    }

    final fromDT = _combineDateAndTime(fromDate!, selectedFromTime!);
    final toDT = _combineDateAndTime(toDate!, selectedToTime!);

    // SAME DAY → TIME MUST BE STRICTLY GREATER
    final isSameDay =
        fromDate!.year == toDate!.year &&
        fromDate!.month == toDate!.month &&
        fromDate!.day == toDate!.day;

    if (isSameDay && !toDT.isAfter(fromDT)) {
      AppSnackBar.showWarning(
        context,
        message: "End time must be after start time",
        duration: const Duration(seconds: 2),
      );

      setState(() {
        if (isFrom) {
          selectedFromTime = null;
        } else {
          selectedToTime = null;
        }
        noOfDays = 0;
        totalAmount = 0;
        availabilityStatus = "Available";
      });

      return false;
    }

    return true;
  }

  void clearSelection() {
    setState(() {
      fromDate = null;
      toDate = null;
      selectedFromTime = null;
      selectedToTime = null;
      noOfDays = 0;
      totalAmount = 0;
      availabilityStatus = "Available";
    });
  }

  Future<void> pickDate(bool isFrom) async {
    await showDialog(
      context: context,
      builder: (context) {
        final size = MediaQuery.of(context).size;
        final isTablet = size.width >= 600;

        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? size.width * 0.2 : 24,
            vertical: isTablet ? 24 : 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ModernCalendar(
            selectedDate: isFrom ? fromDate : toDate,
            startDate: isFrom ? null : fromDate,
            endDate: isFrom ? toDate : null,
            onDateSelected: (date) {
              setState(() {
                if (isFrom) {
                  fromDate = date;
                  if (toDate != null && toDate!.isBefore(fromDate!)) {
                    toDate = null;
                  }
                } else {
                  toDate = date;
                }
                calculateTotal();
              });

              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  // ------------------------------
  // VALIDATION BEFORE BOOKING
  // ------------------------------
  bool _validateBooking() {
    if (fromDate == null) {
      AppSnackBar.showWarning(
        context,
        message: "Please select From Date",
        duration: Duration(seconds: 2),
      );
      return false;
    }

    if (toDate == null) {
      AppSnackBar.showWarning(
        context,
        message: "Please select To Date",
        duration: Duration(seconds: 2),
      );
      return false;
    }

    if (selectedFromTime == null) {
      AppSnackBar.showWarning(
        context,
        message: "Please select From Time",
        duration: Duration(seconds: 2),
      );
      return false;
    }

    if (selectedToTime == null) {
      AppSnackBar.showWarning(
        context,
        message: "Please select To Time",
        duration: Duration(seconds: 2),
      );
      return false;
    }

    final fromDT = _combineDateAndTime(fromDate!, selectedFromTime!);
    final toDT = _combineDateAndTime(toDate!, selectedToTime!);

    // SAME-DAY BOOKING FIX
    if (fromDate!.year == toDate!.year &&
        fromDate!.month == toDate!.month &&
        fromDate!.day == toDate!.day) {
      if (!toDT.isAfter(fromDT)) {
        AppSnackBar.showError(
          context,
          message: "End time must be greater than start time",
          duration: Duration(seconds: 2),
        );
        return false;
      }

      noOfDays = 1;
      totalAmount = widget.pricePerDay;
    } else {
      if (!toDT.isAfter(fromDT)) {
        AppSnackBar.showError(
          context,
          message: "End time must be greater than start time",
          duration: Duration(seconds: 2),
        );
        return false;
      }

      if (noOfDays <= 0) {
        AppSnackBar.showError(
          context,
          message: "Minimum rental duration is 1 day",
          duration: Duration(seconds: 2),
        );
        return false;
      }
    }

    if (availabilityStatus == "Unavailable") {
      AppSnackBar.showError(
        context,
        message: "Selected dates are not available",
        duration: Duration(seconds: 2),
      );
      return false;
    }

    return true;
  }

  void checkAvailability(DateTime from, DateTime to) {
    bool isAvailable = true;

    for (var customer in userCustomers) {
      for (var rental in customer.rentals) {
        if (rental.itemName == widget.item.name) {
          if ((from.isBefore(rental.to) && to.isAfter(rental.from)) ||
              from.isAtSameMomentAs(rental.from) ||
              to.isAtSameMomentAs(rental.to)) {
            isAvailable = false;
            break;
          }
        }
      }
      if (!isAvailable) break;
    }

    if (isAvailable) {
      for (var sale in userRentalSales) {
        if (sale.itemName == widget.item.name) {
          if ((from.isBefore(sale.toDateTime) &&
                  to.isAfter(sale.fromDateTime)) ||
              from.isAtSameMomentAs(sale.fromDateTime) ||
              to.isAtSameMomentAs(sale.toDateTime)) {
            isAvailable = false;
            break;
          }
        }
      }
    }

    setState(() {
      availabilityStatus = isAvailable ? "Available" : "Unavailable";
    });
  }

  Widget _buildNeumorphicCard({
    required Widget child,
    EdgeInsetsGeometry? margin,
  }) {
    final width = MediaQuery.of(context).size.width;
    final bool isTablet = width >= 600;

    final horizontal = 14 * scale;

    return Container(
      margin:
          margin ?? EdgeInsets.symmetric(horizontal: horizontal, vertical: 8),
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: isTablet ? 24 : 20,
            offset: const Offset(10, 10),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: isTablet ? 24 : 20,
            offset: const Offset(-10, -10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDateTimeButton(bool isFrom) {
    final dateTime = isFrom ? fromDate : toDate;
    final label = isFrom ? "From" : "To";
    final icon = isFrom ? Icons.calendar_today : Icons.calendar_month;

    return Expanded(
      child: Container(
        height: 55 * scale,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15 * scale),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 10,
              offset: const Offset(4, 4),
            ),
            BoxShadow(
              color: Colors.white,
              blurRadius: 10,
              offset: const Offset(-4, -4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(15 * scale),
          child: InkWell(
            onTap: () => pickDate(isFrom),
            borderRadius: BorderRadius.circular(15 * scale),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16 * scale),
              child: Row(
                children: [
                  Icon(icon, color: Colors.blue.shade600, size: 16 * scale),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      dateTime == null
                          ? "Select $label Date"
                          : DateFormat('dd/MM/yyyy').format(dateTime),
                      style: TextStyle(
                        color:
                            dateTime == null
                                ? Colors.grey.shade500
                                : Colors.grey.shade800,
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w500,
                        overflow: TextOverflow.ellipsis,
                      ),
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

  Widget _buildTimeDropdown(bool isFrom) {
    final value = isFrom ? selectedFromTime : selectedToTime;
    final label = isFrom ? "From Time" : "To Time";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: const Offset(4, 4),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: const Offset(-4, -4),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        items:
            timeSlots
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(
                      t,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w500,
                        fontSize: 12 * scale,
                      ),
                    ),
                  ),
                )
                .toList(),
        onChanged: (val) {
          setState(() {
            if (isFrom) {
              selectedFromTime = val;
            } else {
              selectedToTime = val;
            }
          });

          if (!_validateTimeSelection(isFrom: isFrom)) return;

          calculateTotal();
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
            fontSize: 12 * scale,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        dropdownColor: Colors.white,
        style: TextStyle(
          color: Colors.grey.shade800,
          fontWeight: FontWeight.w500,
        ),
        icon: Icon(Icons.arrow_drop_down, color: Colors.blue.shade600),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    final isAvailable = availabilityStatus == "Available";
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 6 * scale),
      decoration: BoxDecoration(
        color: isAvailable ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAvailable ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAvailable ? Icons.check_circle : Icons.error,
            color: isAvailable ? Colors.green.shade600 : Colors.red.shade600,
            size: 14 * scale,
          ),
          SizedBox(width: 4 * scale),
          Text(
            availabilityStatus,
            style: TextStyle(
              color: isAvailable ? Colors.green.shade800 : Colors.red.shade800,
              fontWeight: FontWeight.w600,
              fontSize: 10 * scale,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard() {
    return _buildNeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6 * scale),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.attach_money_rounded,
                  color: Colors.blue.shade600,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Pricing Details",
                style: TextStyle(
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPriceRow(
            "Daily Rate",
            "₹${widget.pricePerDay.toStringAsFixed(0)}",
          ),
          _buildPriceRow("Number of Days", "$noOfDays days"),
          if (fromDate != null &&
              toDate != null &&
              selectedFromTime != null &&
              selectedToTime != null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4 * scale),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Status",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                      fontSize: 13 * scale,
                    ),
                  ),
                  _buildStatusIndicator(),
                ],
              ),
            ),
          Divider(height: 24 * scale, color: Colors.grey.shade300),
          _buildPriceRow(
            "Total Amount",
            "₹${totalAmount.toStringAsFixed(0)}",
            isTotal: true,
          ),
          SizedBox(height: 16 * scale),
          LayoutBuilder(
            builder: (context, constraints) {
              // 🔒 Slightly reduced scale (safe)
              final double buttonScale =
                  (constraints.maxWidth / 360).clamp(0.85, 1.0) * scale;

              final double buttonHeight = 46 * buttonScale;
              final double radius = 14 * buttonScale;
              final double iconSize = 14 * buttonScale;
              final double textSize = 11 * buttonScale;

              return Row(
                children: [
                  // ================= PRIMARY : BOOK NOW =================
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: buttonHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade700,
                              Colors.blue.shade900,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(radius),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(radius),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(radius),
                            onTap: () async {
                              if (!_validateBooking()) return;

                              final fromDT = _combineDateAndTime(
                                fromDate!,
                                selectedFromTime!,
                              );
                              final toDT = _combineDateAndTime(
                                toDate!,
                                selectedToTime!,
                              );

                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => RentalAddCustomerPage(
                                        rentalItem: widget.item,
                                        noOfDays: noOfDays,
                                        ratePerDay: widget.pricePerDay,
                                        totalAmount: totalAmount,
                                        fromDateTime: fromDT,
                                        toDateTime: toDT,
                                      ),
                                ),
                              );

                              if (result == true) {
                                setState(() {
                                  _loadUserData();
                                  calculateTotal();
                                });
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  UniconsLine.shopping_cart,
                                  size: iconSize,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6 * buttonScale),
                                Text(
                                  'Book Now',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: textSize,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: 8 * buttonScale),

                  // ================= SECONDARY : ADD CART =================
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: buttonHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(radius),
                          border: Border.all(
                            color: Colors.orange.shade300,
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(radius),
                          child: InkWell(
                            key: _addButtonKey,
                            borderRadius: BorderRadius.circular(radius),
                            onTap: () {
                              if (!_validateBooking()) return;

                              final fromDT = _combineDateAndTime(
                                fromDate!,
                                selectedFromTime!,
                              );
                              final toDT = _combineDateAndTime(
                                toDate!,
                                selectedToTime!,
                              );

                              if (!_validateAddToCart(fromDT, toDT)) return;

                              RentalCart.add(
                                RentalCartItem(
                                  item: widget.item,
                                  noOfDays: noOfDays,
                                  ratePerDay: widget.pricePerDay,
                                  totalAmount: totalAmount,
                                  fromDateTime: fromDT,
                                  toDateTime: toDT,
                                ),
                              );

                              _cartCount.value = RentalCart.items.length;
                              _animateAddToCart();
                              _syncAvailabilityWithCart();

                              AppSnackBar.showSuccess(
                                context,
                                message: "Item added to cart",
                              );
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_shopping_cart_rounded,
                                  color: Colors.orange.shade800,
                                  size: iconSize,
                                ),
                                SizedBox(width: 6 * buttonScale),
                                Text(
                                  'Add to Cart',
                                  style: TextStyle(
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.w700,
                                    fontSize: textSize,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: 8 * buttonScale),

                  // ================= RESET =================
                  SizedBox(
                    width: buttonHeight,
                    height: buttonHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(radius),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1.1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(radius),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(radius),
                          onTap: clearSelection,
                          child: Icon(
                            Icons.refresh_rounded,
                            color: Colors.grey.shade700,
                            size: 20 * buttonScale,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12 * scale,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isTotal ? Colors.blue.shade800 : Colors.grey.shade800,
              fontSize: 12 * scale,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.width >= 600;
    final bool isWide = size.width >= 900;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: isTablet ? 340 : 300,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Container(
                width: 35 * scale,
                height: 35 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: Colors.black,
                  size: 20 * scale,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(left: 60 * scale, bottom: 16),
              title: Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade200,
                  fontWeight: FontWeight.w700,
                  fontSize: isTablet ? 20 : 18,
                ),
              ),
              background: Stack(
                children: [
                  Positioned.fill(
                    child:
                        widget.imageUrl.isNotEmpty &&
                                File(widget.imageUrl).existsSync()
                            ? Image.file(
                              File(widget.imageUrl),
                              fit: BoxFit.cover,
                            )
                            : Container(
                              color: Colors.grey.shade200,
                              child: Icon(
                                Icons.photo_camera,
                                color: Colors.grey.shade400,
                                size: 60,
                              ),
                            ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 720 : double.infinity,
                ),
                child: Column(
                  children: [
                    _buildNeumorphicCard(
                      margin: EdgeInsets.symmetric(
                        horizontal: 14 * scale,
                        vertical: 12 * scale,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(6 * scale),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.calendar_today,
                                      color: Colors.orange.shade600,
                                      size: 16 * scale,
                                    ),
                                  ),
                                  SizedBox(width: 12 * scale),
                                  Text(
                                    "Select Rental Period",
                                    style: TextStyle(
                                      fontSize: 14 * scale,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              // ---------------- VIEW CART ----------------
                              InkWell(
                                key: _cartButtonKey,
                                borderRadius: BorderRadius.circular(30 * scale),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => const RentalCartPreviewPage(),
                                    ),
                                  );

                                  // ✅ UPDATE COUNT AFTER RETURN
                                  _cartCount.value = RentalCart.items.length;
                                  _syncAvailabilityWithCart();
                                },
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // ================= CART BUTTON =================
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10 * scale,
                                        vertical: 6 * scale,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF1E40AF,
                                          ), // 🔵 border color
                                          width: 1.2, // optional thickness
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.white,
                                            offset: const Offset(-4, -4),
                                            blurRadius: 8,
                                          ),
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.30,
                                            ),
                                            offset: const Offset(1, 3),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            UniconsLine.shopping_cart,
                                            size: 16 * scale,
                                            color: const Color(0xFF1E40AF),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // ================= CART COUNT BADGE =================
                                    Positioned(
                                      top: -6,
                                      right: -6,
                                      child: ValueListenableBuilder<int>(
                                        valueListenable: _cartCount,
                                        builder: (_, count, __) {
                                          if (count == 0)
                                            return const SizedBox.shrink();

                                          return Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              '$count',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              _buildDateTimeButton(true),
                              const SizedBox(width: 12),
                              _buildDateTimeButton(false),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildTimeDropdown(true)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildTimeDropdown(false)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Pricing Section
                    _buildPriceCard(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
