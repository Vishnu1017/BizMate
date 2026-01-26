import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import '../models/sale.dart';

class PdfPreviewScreen extends StatelessWidget {
  final String filePath;
  final Sale sale;

  const PdfPreviewScreen({
    super.key,
    required this.filePath,
    required this.sale,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    final isTablet = width > 600;

    // Super-responsive paddings
    final outerMargin = width * 0.025;
    final pdfPaddingHorizontal =
        isTablet ? width * 0.06 : width * 0.01; // tablet-friendly
    final pdfPaddingVertical =
        isTablet ? height * 0.04 : height * 0.10; // better balance

    return Scaffold(
      extendBodyBehindAppBar: true,

      // ------------------------- APP BAR -------------------------
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
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
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            "Invoice Preview",
            style: TextStyle(
              color: Colors.white,
              fontSize: isTablet ? 26 : width * 0.045,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
      ),

      // ------------------------- BODY -------------------------
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              margin: EdgeInsets.all(outerMargin),
              child: Center(
                child: Container(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  padding: EdgeInsets.symmetric(
                    horizontal: pdfPaddingHorizontal,
                    vertical: pdfPaddingVertical,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(isTablet ? 18 : 12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isTablet ? 18 : 10),
                    child: PDFView(
                      filePath: filePath,
                      enableSwipe: true,
                      swipeHorizontal: false,
                      autoSpacing: true,
                      pageFling: true,
                      fitEachPage: true,
                      fitPolicy: FitPolicy.BOTH, // best for all screens
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),

      // ------------------------- SHARE BUTTON -------------------------
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      floatingActionButton: Container(
        margin: EdgeInsets.only(bottom: height * 0.015),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF1E40AF), Color(0xFF020617)],
            stops: [0.0, 0.6, 1.0],
            begin: Alignment.bottomRight,
            end: Alignment.topLeft,
          ),
          borderRadius: BorderRadius.circular(24), // smaller radius
        ),
        child: FloatingActionButton.extended(
          elevation: 0,
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),

          // SMALL ICON
          icon: Icon(
            Icons.share,
            color: Colors.white,
            size: width * 0.040, // smaller icon
          ),

          // SMALL TEXT + SMALL PADDING
          label: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: width * 0.01, // smaller padding
              vertical: width * 0.01,
            ),
            child: Text(
              "Share",
              style: TextStyle(
                color: Colors.white,
                fontSize: width * 0.030, // SMALL FONT
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Same share logic untouched
          onPressed: () async {
            final message = '''
              Hi ${sale.customerName},

              🧾 *Invoice Summary*
              • Total Amount: ₹${sale.totalAmount}
              • Received: ₹${sale.receivedAmount}
              • Balance Due: ₹${sale.balanceAmount}
              • Date: ${sale.formattedDate}

              📲 Scan the QR code to pay via UPI.

              Thanks for choosing *${sale.customerName}*!
              – *Team ${sale.customerName}*
              ''';

            await Clipboard.setData(ClipboardData(text: message));

            AppSnackBar.showSuccess(
              context,
              message:
                  "Message copied! Paste it in WhatsApp after selecting contact.",
              duration: const Duration(seconds: 2),
            );

            await Future.delayed(const Duration(milliseconds: 300));

            try {
              await Share.shareXFiles(
                [XFile(filePath)],
                text: message,
                subject: '📸 Your Invoice from ${sale.customerName}',
              );
            } catch (e) {
              AppSnackBar.showError(
                context,
                message: "Failed to share: $e",
                duration: const Duration(seconds: 2),
              );
            }
          },
        ),
      ),
    );
  }
}
