import 'dart:io';
import 'dart:ui';
import 'package:bizmate/screens/Camera%20rental%20page/rental_add_customer_page.dart';
import 'package:bizmate/services/rental_cart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RentalCartPreviewPage extends StatefulWidget {
  const RentalCartPreviewPage({super.key});

  @override
  State<RentalCartPreviewPage> createState() => _RentalCartPreviewPageState();
}

class _RentalCartPreviewPageState extends State<RentalCartPreviewPage> {
  void _removeItem(int index) {
    setState(() {
      RentalCart.items.removeAt(index);
    });
  }

  String _formatDate(DateTime dt) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final items = RentalCart.items;
    final size = MediaQuery.of(context).size;
    double scale = 1.0;
    final bool isTablet = size.width >= 600;
    final bool isWide = size.width >= 900;

    final double horizontalPadding =
        isWide
            ? size.width * 0.18
            : isTablet
            ? 32
            : 16;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      // ================= APP BAR =================
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Rental Cart",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
            color: Colors.white,
          ),
        ),

        // 🔥 CLEAR CART BUTTON
        actions: [
          if (items.isNotEmpty)
            IconButton(
              tooltip: "Clear Cart",
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: () async {
                bool confirmed = false;

                await showGeneralDialog(
                  context: context,
                  barrierDismissible: true,
                  barrierLabel: '',
                  barrierColor: Colors.black54,
                  transitionDuration: const Duration(milliseconds: 300),
                  pageBuilder: (ctx, anim1, anim2) {
                    return Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: MediaQuery.of(ctx).size.width * 0.85,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.delete_forever_rounded,
                                    color: Colors.redAccent,
                                    size: 64,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    "Clear Cart?",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "This will remove all items from your cart.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white12,
                                        ),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          confirmed = true;
                                          Navigator.pop(ctx);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                        ),
                                        child: const Text(
                                          'Clear',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  transitionBuilder: (ctx, anim1, anim2, child) {
                    return Transform.scale(
                      scale: anim1.value,
                      child: Opacity(opacity: anim1.value, child: child),
                    );
                  },
                );

                if (confirmed) {
                  setState(() {
                    RentalCart.clear(); // ✅ instant UI update
                  });
                }
              },
            ),
        ],

        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1E40AF), Color(0xFF020617)],
              stops: [0.0, 0.6, 1.0],
              begin: Alignment.bottomRight,
              end: Alignment.topLeft,
            ),
          ),
        ),
      ),
      // ================= BODY =================
      body: SafeArea(
        child:
            items.isEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 60 * scale,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Your cart is empty",
                        style: TextStyle(
                          fontSize: 18 * scale,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
                : Column(
                  children: [
                    // ================= ITEM LIST =================
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: 14 * scale,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final item = items[i];

                          final imageSize = 62 * scale;

                          return Container(
                            margin: EdgeInsets.only(bottom: 12 * scale),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(14 * scale),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ================= IMAGE =================
                                  Container(
                                    width: imageSize,
                                    height: imageSize,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: Colors.grey.shade200,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child:
                                        item.item.imagePath.isNotEmpty &&
                                                File(
                                                  item.item.imagePath,
                                                ).existsSync()
                                            ? Image.file(
                                              File(item.item.imagePath),
                                              fit: BoxFit.cover,
                                            )
                                            : Icon(
                                              Icons.photo_camera,
                                              color: Colors.grey.shade500,
                                              size: 28 * scale,
                                            ),
                                  ),

                                  SizedBox(width: 14 * scale),

                                  // ================= DETAILS =================
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.item.name,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 14 * scale,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () => _removeItem(i),
                                              icon: Icon(
                                                Icons.delete_outline,
                                                color: Colors.redAccent,
                                                size: 16 * scale,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 4 * scale),
                                        Text(
                                          "₹${item.ratePerDay}/day • ${item.noOfDays} days",
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12 * scale,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.schedule,
                                              size: 10 * scale,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                "From: ${_formatDate(item.fromDateTime)}",
                                                style: TextStyle(
                                                  fontSize: 10 * scale,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 4 * scale),
                                        Row(
                                          children: [
                                            Icon(Icons.event, size: 10 * scale),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                "To: ${_formatDate(item.toDateTime)}",
                                                style: TextStyle(
                                                  fontSize: 10 * scale,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 10 * scale),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 10 * scale,
                                              vertical: 4 * scale,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: Text(
                                              "₹${item.totalAmount.toStringAsFixed(0)}",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade800,
                                                fontSize: 14 * scale,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // ================= TOTAL + CTA =================
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        10 * scale,
                        horizontalPadding,
                        16 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 18,
                            offset: const Offset(0, -6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Total Amount",
                                style: TextStyle(
                                  fontSize: 16 * scale,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "₹${RentalCart.totalAmount.toStringAsFixed(0)}",
                                style: TextStyle(
                                  fontSize: 18 * scale,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E40AF),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 14 * scale),

                          // ================= BOOK NOW =================
                          SizedBox(
                            height: 55 * scale,
                            width: double.infinity,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
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
                                borderRadius: BorderRadius.circular(16 * scale),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.4),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => RentalAddCustomerPage(
                                              rentalItem: items.first.item,
                                              noOfDays: items.first.noOfDays,
                                              ratePerDay:
                                                  items.first.ratePerDay,
                                              totalAmount:
                                                  RentalCart.totalAmount,
                                              fromDateTime:
                                                  items.first.fromDateTime,
                                              toDateTime:
                                                  items.first.toDateTime,
                                            ),
                                      ),
                                    );

                                    if (result == true) {
                                      setState(() {
                                        RentalCart.clear();
                                      });
                                    }
                                  },
                                  child: Center(
                                    child: Text(
                                      "Book Now",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16 * scale,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
