import 'package:flutter/material.dart';
import 'package:bizmate/models/sale.dart';
import 'package:intl/intl.dart';

class PaymentHistoryPage extends StatelessWidget {
  final Sale sale;
  double get scale => 1.0;
  bool get isSale => sale.deliveryLink.isNotEmpty;

  const PaymentHistoryPage({super.key, required this.sale});

  LinearGradient getProgressGradient(double percentage) {
    if (percentage <= 20) {
      return LinearGradient(colors: [Color(0xFFE53935), Color(0xFFD32F2F)]);
    } else if (percentage <= 50) {
      return LinearGradient(colors: [Color(0xFFE53935), Color(0xFFFFA726)]);
    } else if (percentage <= 75) {
      return LinearGradient(
        colors: [Color(0xFFFFA726), Color(0xFFFFEB3B), Color(0xFF66BB6A)],
      );
    } else {
      return LinearGradient(colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = (sale.totalAmount - sale.amount).clamp(0, double.infinity);
    final paidPercentage =
        (sale.amount / sale.totalAmount * 100).clamp(0, 100).toDouble();

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Container(
                width: 30 * scale,
                height: 30 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: Color(0xFF1E40AF),
                  size: 20 * scale,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                "Payment History",
                style: TextStyle(
                  color: Color(0xFF1E40AF),
                  fontWeight: FontWeight.bold,
                  fontSize: 16 * scale,
                ),
              ),
              centerTitle: true,
              titlePadding: EdgeInsets.only(bottom: 16),
            ),
          ),

          // Content
          SliverPadding(
            padding: EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Summary Card
                _buildSummaryCard(
                  sale.totalAmount.toDouble(),
                  sale.amount.toDouble(),
                  balance.toDouble(),
                  paidPercentage,
                ),

                SizedBox(height: 24),

                // Payments Header
                _buildPaymentsHeader(),

                SizedBox(height: 16),
              ]),
            ),
          ),

          // Payments List
          sale.paymentHistory.isEmpty
              ? SliverFillRemaining(
                child: Column(
                  children: [
                    SizedBox(height: 100),
                    Icon(
                      Icons.payments_outlined,
                      size: 64,
                      color: Colors.grey[300],
                    ),
                    SizedBox(height: 16),
                    Text(
                      "No payments recorded",
                      style: TextStyle(color: Colors.grey[500], fontSize: 16),
                    ),
                  ],
                ),
              )
              : SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    // ✅ Detect SALE baseline (only for Sale)
                    final isSaleBaseline =
                        index == 0 &&
                        sale.paymentHistory.length > 1 &&
                        sale.paymentHistory[0].amount == sale.amount;

                    // ✅ Skip ONLY sale baseline
                    if (isSaleBaseline) {
                      return const SizedBox.shrink();
                    }

                    // ✅ RENTAL: show directly
                    if (index == 0) {
                      final payment = sale.paymentHistory[index];
                      return _buildPaymentItem(
                        amount: payment.amount.toDouble(),
                        mode: payment.mode,
                        date: payment.date,
                        index: index,
                        isLast: sale.paymentHistory.length == 1,
                      );
                    }

                    // ✅ SALE: show difference-based payment
                    final current = sale.paymentHistory[index];
                    final previous = sale.paymentHistory[index - 1];

                    final amount =
                        (previous.amount - current.amount).abs().toDouble();

                    return _buildPaymentItem(
                      amount: amount,
                      mode: previous.mode,
                      date: previous.date,
                      index: index,
                      isLast: index == sale.paymentHistory.length - 1,
                    );
                  }, childCount: sale.paymentHistory.length),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    double total,
    double received,
    double balance,
    double paidPercentage,
  ) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF), Color(0xFF020617)],
          stops: [0.0, 0.6, 1.0],
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.2),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Amount Rows
          _buildSummaryRow(
            "Total Amount",
            total,
            Colors.white.withOpacity(0.8),
          ),
          SizedBox(height: 10 * scale),
          _buildSummaryRow("Received", received, Colors.white),
          SizedBox(height: 10 * scale),
          _buildSummaryRow(
            "Balance Due",
            balance,
            balance > 0 ? Color(0xFFFF6B6B) : Colors.white.withOpacity(0.8),
          ),
          SizedBox(height: 16 * scale),
          // Progress Bar
          Container(
            height: 8 * scale,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Align(
                  alignment: Alignment.centerLeft, // ✅ force start from left
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOut,
                    width: constraints.maxWidth * (paidPercentage / 100),
                    height: 8 * scale,
                    decoration: BoxDecoration(
                      gradient: getProgressGradient(paidPercentage),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 8 * scale),
          // Percentage
          Text(
            "${paidPercentage.toStringAsFixed(1)}% Paid",
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String title, double value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12 * scale,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          "₹${value.toStringAsFixed(2)}",
          style: TextStyle(
            color: color,
            fontSize: 14 * scale,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentsHeader() {
    return Row(
      children: [
        Container(
          width: 4 * scale,
          height: 20 * scale,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1E40AF), Color(0xFF020617)],
              stops: [0.0, 0.6, 1.0],
              begin: Alignment.bottomRight,
              end: Alignment.topLeft,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 10 * scale),
        Text(
          "Payment Timeline",
          style: TextStyle(
            fontSize: 16 * scale,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A237E),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentItem({
    required double amount,
    required String mode,
    required DateTime date,
    required int index,
    required bool isLast,
  }) {
    final paymentIcons = {
      'cash': Icons.wallet_rounded,
      'card': Icons.credit_card_rounded,
      'upi': Icons.qr_code_rounded,
      'online': Icons.public_rounded,
      'bank': Icons.account_balance_rounded,
    };

    final icon = paymentIcons[mode.toLowerCase()] ?? Icons.payments_rounded;

    return Container(
      margin: EdgeInsets.only(bottom: 16 * scale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline
          Column(
            children: [
              Container(
                width: 20 * scale,
                height: 20 * scale,
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
                  borderRadius: BorderRadius.circular(12), // adjust if needed
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 12 * scale,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2 * scale,
                  height: 60 * scale,
                  margin: EdgeInsets.symmetric(vertical: 4 * scale),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF2563EB),
                        Color(0xFF1E40AF),
                        Color(0xFF020617),
                      ],
                      stops: [0.0, 0.6, 1.0],
                      begin: Alignment.bottomRight,
                      end: Alignment.topLeft,
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(width: 14 * scale),

          // Payment Card
          Expanded(
            child: Container(
              padding: EdgeInsets.all(12 * scale),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[100]!),
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    padding: EdgeInsets.all(8 * scale),
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
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 18 * scale),
                  ),

                  SizedBox(width: 10 * scale),

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "₹${amount.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14 * scale,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                        SizedBox(height: 4 * scale),
                        Row(
                          children: [
                            Icon(
                              icon,
                              size: 12 * scale,
                              color: Colors.grey[800],
                            ),
                            SizedBox(width: 6 * scale),
                            Text(
                              mode,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 11 * scale,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2 * scale),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 12 * scale,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 6 * scale),
                            Text(
                              DateFormat('dd MMM yyyy, hh:mm a').format(date),
                              style: TextStyle(
                                fontSize: 10 * scale,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Status Badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6 * scale,
                      vertical: 2 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[100]!),
                    ),
                    child: Text(
                      "Paid",
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 10 * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
