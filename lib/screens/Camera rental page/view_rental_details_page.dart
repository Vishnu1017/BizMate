import 'dart:io';
import 'package:bizmate/models/rental_item.dart';
import 'package:bizmate/models/customer_model.dart';
import 'package:bizmate/models/rental_sale_model.dart' show RentalSaleModel;
import 'package:bizmate/screens/Camera%20rental%20page/rental_add_customer_page.dart'
    show RentalAddCustomerPage;
import 'package:bizmate/widgets/ModernCalendar.dart' show ModernCalendar;
import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

class ViewRentalDetailsPage extends StatefulWidget {
  final RentalItem item;
  final String name;
  final String imageUrl;
  final double pricePerDay;
  final String availability;

  const ViewRentalDetailsPage({
    Key? key,
    required this.item,
    required this.name,
    required this.imageUrl,
    required this.pricePerDay,
    required this.availability,
  }) : super(key: key);

  @override
  State<ViewRentalDetailsPage> createState() => _ViewRentalDetailsPageState();
}

class _ViewRentalDetailsPageState extends State<ViewRentalDetailsPage> {
  DateTime? fromDate;
  DateTime? toDate;
  String? selectedFromTime;
  String? selectedToTime;

  int noOfDays = 0;
  double totalAmount = 0.0;

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
    final bool isWide = width >= 900;

    final horizontal =
        isWide
            ? width * 0.18
            : isTablet
            ? width * 0.12
            : 20.0;

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
    final width = MediaQuery.of(context).size.width;
    final bool isVerySmall = width < 360;
    final bool isTablet = width >= 600;

    final dateTime = isFrom ? fromDate : toDate;
    final label = isFrom ? "From" : "To";
    final icon = isFrom ? Icons.calendar_today : Icons.calendar_month;

    return Expanded(
      child: Container(
        height:
            isTablet
                ? 60
                : isVerySmall
                ? 50
                : 55,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isTablet ? 18 : 15),
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
          borderRadius: BorderRadius.circular(isTablet ? 18 : 15),
          child: InkWell(
            onTap: () => pickDate(isFrom),
            borderRadius: BorderRadius.circular(isTablet ? 18 : 15),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 18 : 16),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: Colors.blue.shade600,
                    size: isTablet ? 22 : 20,
                  ),
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
                        fontSize:
                            isVerySmall
                                ? 12
                                : isTablet
                                ? 15
                                : 14,
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
    final width = MediaQuery.of(context).size.width;
    final bool isVerySmall = width < 360;
    final bool isTablet = width >= 600;

    final value = isFrom ? selectedFromTime : selectedToTime;
    final label = isFrom ? "From Time" : "To Time";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 18 : 15),
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
        value: value,
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
                        fontSize:
                            isVerySmall
                                ? 12
                                : isTablet
                                ? 15
                                : 14,
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
            calculateTotal();
          });
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
            fontSize:
                isVerySmall
                    ? 12
                    : isTablet
                    ? 14
                    : 13,
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
    final width = MediaQuery.of(context).size.width;
    final bool isVerySmall = width < 360;

    final isAvailable = availabilityStatus == "Available";
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isVerySmall ? 12 : 16,
        vertical: 8,
      ),
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
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            availabilityStatus,
            style: TextStyle(
              color: isAvailable ? Colors.green.shade800 : Colors.red.shade800,
              fontWeight: FontWeight.w600,
              fontSize: isVerySmall ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard() {
    final width = MediaQuery.of(context).size.width;
    final bool isTablet = width >= 600;

    return _buildNeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.attach_money_rounded,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Pricing Details",
                style: TextStyle(
                  fontSize: isTablet ? 20 : 18,
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
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Status",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                      fontSize: isTablet ? 14 : 13,
                    ),
                  ),
                  _buildStatusIndicator(),
                ],
              ),
            ),
          Divider(height: 24, color: Colors.grey.shade300),
          _buildPriceRow(
            "Total Amount",
            "₹${totalAmount.toStringAsFixed(0)}",
            isTotal: true,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: isTablet ? 58 : 55,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade800],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade300,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                    child: InkWell(
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
                      borderRadius: BorderRadius.circular(15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_checkout,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Book Now',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: isTablet ? 17 : 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: isTablet ? 58 : 55,
                height: isTablet ? 58 : 55,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 10,
                      offset: const Offset(4, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    onTap: clearSelection,
                    borderRadius: BorderRadius.circular(15),
                    child: Icon(
                      Icons.refresh,
                      color: Colors.grey.shade600,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false}) {
    final width = MediaQuery.of(context).size.width;
    final bool isTablet = width >= 600;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: isTablet ? 15 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isTotal ? Colors.blue.shade800 : Colors.grey.shade800,
              fontSize: isTotal ? (isTablet ? 18 : 16) : (isTablet ? 15 : 14),
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
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.black, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(
                left: isWide ? size.width * 0.18 : 56,
                bottom: 16,
              ),
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
                        horizontal:
                            isWide
                                ? size.width * 0.18
                                : isTablet
                                ? size.width * 0.12
                                : 20,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.calendar_today,
                                  color: Colors.orange.shade600,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "Select Rental Period",
                                style: TextStyle(
                                  fontSize: isTablet ? 20 : 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade800,
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
