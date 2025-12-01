import 'package:flutter/material.dart';
import 'package:bizmate/models/sale.dart';
import 'package:intl/intl.dart';

class PaymentHistoryPage extends StatelessWidget {
  final Sale sale;

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
            leading: Container(
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: Color(0xFF1A237E)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                "Payment History",
                style: TextStyle(
                  color: Color(0xFF1A237E),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
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
                padding: EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index == 0) return SizedBox.shrink();

                    final current = sale.paymentHistory[index];
                    final previous = sale.paymentHistory[index - 1];
                    final difference =
                        (previous.amount - current.amount).toDouble();
                    final mode = previous.mode;

                    return _buildPaymentItem(
                      amount: difference,
                      mode: mode,
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
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
          SizedBox(height: 12),
          _buildSummaryRow("Received", received, Colors.white),
          SizedBox(height: 12),
          _buildSummaryRow(
            "Balance Due",
            balance,
            balance > 0 ? Color(0xFFFF6B6B) : Colors.white.withOpacity(0.8),
          ),
          SizedBox(height: 20),
          // Progress Bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    return AnimatedContainer(
                      duration: Duration(milliseconds: 800),
                      curve: Curves.easeOut,
                      width: constraints.maxWidth * (paidPercentage / 100),
                      decoration: BoxDecoration(
                        gradient: getProgressGradient(paidPercentage),

                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          // Percentage
          Text(
            "${paidPercentage.toStringAsFixed(1)}% Paid",
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
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
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          "₹${value.toStringAsFixed(2)}",
          style: TextStyle(
            color: color,
            fontSize: 16,
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
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 12),
        Text(
          "Payment Timeline",
          style: TextStyle(
            fontSize: 18,
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
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Color(0xFF667EEA),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF667EEA).withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(Icons.check_rounded, color: Colors.white, size: 14),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 60,
                  margin: EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF667EEA).withOpacity(0.6),
                        Color(0xFF764BA2).withOpacity(0.3),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(width: 16),

          // Payment Card
          Expanded(
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[100]!),
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Color(0xFF667EEA), size: 20),
                  ),

                  SizedBox(width: 12),

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "₹${amount.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(icon, size: 14, color: Colors.grey[800]),
                            SizedBox(width: 6),
                            Text(
                              mode,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 6),
                            Text(
                              DateFormat('dd MMM yyyy, hh:mm a').format(date),
                              style: TextStyle(
                                fontSize: 12,
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
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[100]!),
                    ),
                    child: Text(
                      "Paid",
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 12,
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
