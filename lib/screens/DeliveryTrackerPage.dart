import 'dart:ui';
import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:bizmate/models/sale.dart';

class DeliveryTrackerPage extends StatefulWidget {
  final Sale sale;
  final String phoneWithCountryCode;
  final String phoneWithoutCountryCode;

  const DeliveryTrackerPage({
    super.key,
    required this.sale,
    required this.phoneWithCountryCode,
    required this.phoneWithoutCountryCode,
  });

  @override
  State<DeliveryTrackerPage> createState() => _DeliveryTrackerPageState();
}

class _DeliveryTrackerPageState extends State<DeliveryTrackerPage> {
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _statusNotesController = TextEditingController();
  String? _selectedStatus;
  final List<String> statuses = [
    'All Non Editing Images',
    'Editing',
    'Printed',
    'Delivered',
  ];

  // Map of status-specific note suggestions
  final Map<String, String> _statusNoteSuggestions = {
    'All Non Editing Images':
        'Non-edited photos are ready for download. Final edited versions will be shared separately once completed.',
    'Editing':
        'Photos are currently being edited. We\'ll notify you when they\'re ready for review.',
    'Printed': 'Photos have been printed and are being prepared for delivery.',
    'Delivered': 'Photos have been successfully delivered to the customer.',
  };

  List<Map<String, dynamic>> deliveryStatusHistory = [];
  String _previousSuggestion = '';

  @override
  void initState() {
    super.initState();
    _linkController.text = widget.sale.deliveryLink;
    _selectedStatus =
        widget.sale.deliveryStatus.isNotEmpty
            ? widget.sale.deliveryStatus
            : 'All Non Editing Images';

    // Initialize delivery status history if empty
    if (widget.sale.deliveryStatusHistory == null ||
        widget.sale.deliveryStatusHistory!.isEmpty) {
      deliveryStatusHistory = [
        {
          'status': 'Order Received',
          'dateTime': widget.sale.dateTime.toIso8601String(),
          'notes': 'Order has been received and is being processed',
        },
      ];
      widget.sale.deliveryStatusHistory = deliveryStatusHistory;
    } else {
      deliveryStatusHistory = widget.sale.deliveryStatusHistory!;
    }
  }

  void _updateStatusNoteSuggestion() {
    if (_selectedStatus != null &&
        _statusNoteSuggestions.containsKey(_selectedStatus) &&
        (_statusNotesController.text.isEmpty ||
            _statusNotesController.text == _previousSuggestion)) {
      setState(() {
        _previousSuggestion = _statusNoteSuggestions[_selectedStatus]!;
        _statusNotesController.text = _previousSuggestion;
      });
    }
  }

  void _saveDeliveryDetails() async {
    widget.sale.deliveryLink = _linkController.text;
    widget.sale.deliveryStatus = _selectedStatus!;

    // Add current status to history if it's new or changed
    if (deliveryStatusHistory.isEmpty ||
        deliveryStatusHistory.first['status'] != _selectedStatus) {
      deliveryStatusHistory.insert(0, {
        'status': _selectedStatus!,
        'dateTime': DateTime.now().toIso8601String(),
        'notes':
            _statusNotesController.text.isNotEmpty
                ? _statusNotesController.text
                : null,
      });
      widget.sale.deliveryStatusHistory = deliveryStatusHistory;
    }

    await widget.sale.save();
    Navigator.pop(context);
  }

  void _sendWhatsApp() {
    final customerName =
        widget.sale.customerName.isNotEmpty
            ? widget.sale.customerName
            : "Customer";
    final deliveryStatus = _selectedStatus ?? 'Ready';
    final deliveryLink =
        _linkController.text.isNotEmpty
            ? _linkController.text
            : 'Link not available';
    final phone = widget.sale.phoneNumber.replaceAll(' ', '');

    if (phone.length < 10 || !RegExp(r'^[0-9]+$').hasMatch(phone)) {
      AppSnackBar.showWarning(
        context,
        message: "Please enter a valid 10-digit phone number",duration: Duration(seconds: 2)
      );
      return;
    }

    String message;
    if (_selectedStatus == 'All Non Editing Images') {
      message =
          "Hi $customerName,\n\n"
          "Your non-edited photos are now ready for download!\n\n"
          "You can access them here: $deliveryLink\n\n"
          "Note: These are the raw, unedited images from your session. "
          "The final edited versions will be shared separately once completed.\n\n"
          "Thanks,\n"
          "Shutter Life Photography";
    } else {
      message =
          "Hi $customerName,\n\n"
          "Your photos are now *$deliveryStatus*.\n"
          "Download here: $deliveryLink\n\n"
          "Thanks,\n"
          "Shutter Life Photography";
    }

    final url1 = "https://wa.me/$phone?text=${Uri.encodeComponent(message)}";
    final url2 = "https://wa.me/91$phone?text=${Uri.encodeComponent(message)}";

    canLaunchUrl(Uri.parse(url1)).then((canLaunch) {
      if (canLaunch) {
        launchUrl(Uri.parse(url1), mode: LaunchMode.externalApplication);
      } else {
        launchUrl(Uri.parse(url2), mode: LaunchMode.externalApplication);
      }
    });
  }

  void _showStatusHistory() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            width: isSmallScreen ? screenWidth * 0.9 : 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery Status History',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 18 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                deliveryStatusHistory.isEmpty
                    ? Center(
                      child: Text(
                        'No status history available',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          color: Colors.grey,
                        ),
                      ),
                    )
                    : Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: deliveryStatusHistory.length,
                        itemBuilder: (context, index) {
                          final status = deliveryStatusHistory[index];
                          return _buildHistoryItem(
                            status,
                            index,
                            deliveryStatusHistory.length,
                            isSmallScreen,
                          );
                        },
                      ),
                    ),
                SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryItem(
    Map<String, dynamic> status,
    int index,
    int totalItems,
    bool isSmallScreen,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: isSmallScreen ? 16 : 20,
                height: isSmallScreen ? 16 : 20,
                decoration: BoxDecoration(
                  color: index == 0 ? Colors.green : Colors.grey[400],
                  shape: BoxShape.circle,
                ),
                child:
                    index == 0
                        ? Icon(
                          Icons.check,
                          color: Colors.white,
                          size: isSmallScreen ? 12 : 14,
                        )
                        : null,
              ),
              if (index < totalItems - 1)
                Container(
                  width: 2,
                  height: isSmallScreen ? 40 : 50,
                  color: Colors.grey[300],
                ),
            ],
          ),
          SizedBox(width: isSmallScreen ? 12 : 16),

          // Status content
          Expanded(
            child: Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status['status'],
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 17,
                        fontWeight: FontWeight.bold,
                        color: index == 0 ? Colors.green[700] : Colors.black,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: 4),
                        Text(
                          DateFormat(
                            'dd MMM yyyy, hh:mm a',
                          ).format(DateTime.parse(status['dateTime'])),
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    if (status['notes'] != null &&
                        status['notes'].isNotEmpty) ...[
                      SizedBox(height: 8),
                      Text(
                        status['notes'],
                        style: TextStyle(fontSize: isSmallScreen ? 14 : 15),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int getCurrentStepIndex() {
    return statuses.indexOf(_selectedStatus ?? 'All Non Editing Images');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 600;
    final isPortrait = screenHeight > screenWidth;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF00BCD4)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: true,
            centerTitle: true,
            iconTheme: IconThemeData(color: Colors.white),
            title: Text(
              'Photo Delivery Tracker',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 18 : 20,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.history),
                onPressed: _showStatusHistory,
                tooltip: 'View History',
              ),
            ],
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF00BCD4).withOpacity(0.4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + kToolbarHeight + 20,
                bottom: isSmallScreen ? 12 : 20,
                left: isSmallScreen ? 12 : 20,
                right: isSmallScreen ? 12 : 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isSmallScreen ? double.infinity : 600,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Container(
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white30, width: 1.5),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Customer Info
                          _buildCustomerInfo(isSmallScreen),
                          SizedBox(height: isSmallScreen ? 15 : 20),

                          // Stepper Timeline - Responsive version
                          _buildResponsiveStepper(isSmallScreen, isPortrait),
                          SizedBox(height: isSmallScreen ? 10 : 20),

                          // Status Dropdown
                          DropdownButtonFormField<String>(
                            initialValue: _selectedStatus,
                            decoration: InputDecoration(
                              labelText: 'Delivery Status',
                              labelStyle: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: isSmallScreen ? 14 : 16,
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              contentPadding: EdgeInsets.symmetric(
                                vertical: isSmallScreen ? 14 : 18,
                                horizontal: isSmallScreen ? 12 : 16,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1.2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            dropdownColor: Colors.white,
                            iconEnabledColor: Colors.white,
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: isSmallScreen ? 24 : 28,
                            ),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 14 : 16,
                            ),
                            items:
                                statuses.map((status) {
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w700,
                                        fontSize: isSmallScreen ? 13 : 14,
                                      ),
                                    ),
                                  );
                                }).toList(),
                            selectedItemBuilder: (BuildContext context) {
                              return statuses.map((status) {
                                return Text(
                                  status,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmallScreen ? 14 : 16,
                                  ),
                                );
                              }).toList();
                            },
                            onChanged: (value) {
                              setState(() {
                                _selectedStatus = value!;
                                // Update the status note when status changes
                                _updateStatusNoteSuggestion();
                              });
                            },
                          ),
                          SizedBox(height: isSmallScreen ? 15 : 20),

                          // Status Notes with suggestion indicator
                          Stack(
                            children: [
                              TextFormField(
                                controller: _statusNotesController,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isSmallScreen ? 14 : 16,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Status Notes (Optional)',
                                  labelStyle: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: isSmallScreen ? 14 : 16,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.05),
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: isSmallScreen ? 14 : 18,
                                    horizontal: isSmallScreen ? 12 : 16,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1.2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                maxLines: 2,
                                onTap: () {
                                  // Clear the field if it contains the default suggestion
                                  if (_statusNotesController.text ==
                                      _previousSuggestion) {
                                    setState(() {
                                      _statusNotesController.clear();
                                      _previousSuggestion = '';
                                    });
                                  }
                                },
                                onChanged: (value) {
                                  // Track if user modifies the suggestion
                                  if (value != _previousSuggestion) {
                                    _previousSuggestion = '';
                                  }
                                },
                              ),
                              if (_statusNotesController.text.isEmpty ||
                                  _statusNotesController.text ==
                                      _previousSuggestion)
                                Positioned(
                                  right: 12,
                                  top: 12,
                                  child: GestureDetector(
                                    onTap: () {
                                      // Apply the suggestion when the hint is tapped
                                      if (_selectedStatus != null &&
                                          _statusNoteSuggestions.containsKey(
                                            _selectedStatus,
                                          )) {
                                        setState(() {
                                          _previousSuggestion =
                                              _statusNoteSuggestions[_selectedStatus]!;
                                          _statusNotesController.text =
                                              _previousSuggestion;
                                        });
                                      }
                                    },
                                    child: Tooltip(
                                      message: 'Apply status note template',
                                      child: Icon(
                                        Icons.lightbulb_outline,
                                        color: Colors.amber,
                                        size: isSmallScreen ? 18 : 20,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: isSmallScreen ? 15 : 20),

                          // Link Field
                          TextFormField(
                            controller: _linkController,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 14 : 16,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Google Drive / Download Link',
                              labelStyle: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: isSmallScreen ? 14 : 16,
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              contentPadding: EdgeInsets.symmetric(
                                vertical: isSmallScreen ? 14 : 18,
                                horizontal: isSmallScreen ? 12 : 16,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1.2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 20 : 30),

                          // Responsive Buttons
                          _buildResponsiveButtons(isSmallScreen),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerInfo(bool isSmallScreen) {
    return Card(
      color: Colors.white.withOpacity(0.1),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.sale.customerName,
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              widget.sale.phoneNumber,
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 4),
            Text(
              widget.sale.productName,
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.white70),
                SizedBox(width: 4),
                Text(
                  DateFormat('dd MMM yyyy').format(widget.sale.dateTime),
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                SizedBox(width: 16),
                Icon(Icons.receipt, size: 16, color: Colors.white70),
                SizedBox(width: 4),
                FutureBuilder<Box<Sale>>(
                  future: Hive.openBox<Sale>('sales'),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final box = snapshot.data!;
                      final invoiceNumber =
                          box.values.toList().indexOf(widget.sale) + 1;
                      return Text(
                        'Invoice #$invoiceNumber',
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      );
                    }
                    return Text(
                      'Invoice #...',
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveStepper(bool isSmallScreen, bool isPortrait) {
    if (isSmallScreen && !isPortrait) {
      // Horizontal stepper for landscape on small screens
      return SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: statuses.length,
          itemBuilder: (context, index) {
            return Container(
              width: 150,
              padding: EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          index <= getCurrentStepIndex()
                              ? Colors.white
                              : Colors.white.withOpacity(0.3),
                    ),
                    child:
                        index < getCurrentStepIndex()
                            ? Icon(Icons.check, size: 16, color: Colors.black)
                            : null,
                  ),
                  SizedBox(height: 8),
                  Text(
                    statuses[index],
                    style: TextStyle(
                      color:
                          index <= getCurrentStepIndex()
                              ? Colors.white
                              : Colors.white60,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                ],
              ),
            );
          },
        ),
      );
    } else {
      // Vertical stepper for most cases
      return MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.white,
              onSurface: Colors.white54,
            ),
          ),
          child: Stepper(
            currentStep: getCurrentStepIndex(),
            controlsBuilder: (context, _) => SizedBox.shrink(),
            physics: NeverScrollableScrollPhysics(),
            steps:
                statuses.map((status) {
                  final index = statuses.indexOf(status);
                  return Step(
                    title: Text(
                      status,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color:
                            index <= getCurrentStepIndex()
                                ? Colors.white
                                : Colors.white60,
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                    ),
                    content: SizedBox.shrink(),
                    isActive: index <= getCurrentStepIndex(),
                    state:
                        index < getCurrentStepIndex()
                            ? StepState.complete
                            : index == getCurrentStepIndex()
                            ? StepState.editing
                            : StepState.indexed,
                  );
                }).toList(),
          ),
        ),
      );
    }
  }

  Widget _buildResponsiveButtons(bool isSmallScreen) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _saveDeliveryDetails,
            icon: Icon(
              Icons.save,
              color: Colors.white,
              size: isSmallScreen ? 18 : 24,
            ),
            label: Text(
              "Save",
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 14 : 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF1A237E),
              padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        SizedBox(width: isSmallScreen ? 8 : 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _sendWhatsApp,
            icon: FaIcon(
              FontAwesomeIcons.whatsapp,
              color: Colors.white,
              size: isSmallScreen ? 18 : 20,
            ),
            label: Text(
              "WhatsApp",
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 14 : 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
