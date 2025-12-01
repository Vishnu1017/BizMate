import 'package:bizmate/widgets/app_snackbar.dart' show AppSnackBar;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import '../models/sale.dart'; // Ensure this file includes the new getters

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
    final screenWidth = MediaQuery.of(context).size.width;
    final outerMargin = screenWidth * 0.03;
    final innerMargin = screenWidth * 0.04;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF00BCD4)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          title: Text(
            "Invoice Preview",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          centerTitle: true,
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              margin: EdgeInsets.all(outerMargin),
              padding: EdgeInsets.all(10),
              child: Center(
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: innerMargin,
                    vertical: screenWidth * 0.3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 3),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: PDFView(
                      filePath: filePath,
                      enableSwipe: true,
                      swipeHorizontal: false,
                      autoSpacing: true,
                      pageFling: true,
                      fitEachPage: true,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF00BCD4)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: FloatingActionButton.extended(
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: Icon(Icons.share, color: Colors.white),
          label: Text("Share", style: TextStyle(color: Colors.white)),
          onPressed: () async {
            final message = '''
Hi ${sale.customerName},

🧾 *Invoice Summary*
• Total Amount: ₹${sale.totalAmount}
• Received: ₹${sale.receivedAmount}
• Balance Due: ₹${sale.balanceAmount}
• Date: ${sale.formattedDate}

📲 Scan the QR code to pay via UPI.

Thanks for choosing *Shutter Life Photography*!
– *Team Shutter Life Photography*
''';

            final file = XFile(filePath);

            // 1. First copy to clipboard for WhatsApp
            await Clipboard.setData(ClipboardData(text: message));

            // Show snackbar about clipboard copy
            AppSnackBar.showSuccess(
              context,
              message:
                  "Message copied! Paste it in WhatsApp after selecting contact.",
              duration: Duration(seconds: 2),
            );

            await Future.delayed(Duration(milliseconds: 300)); // Small wait

            // 2. Then share both PDF and message via other apps
            try {
              await Share.shareXFiles(
                [file],
                text: message, // This will work in Telegram, Gmail etc.
                subject: '📸 Your Invoice from Shutter Life Photography',
              );
            } catch (e) {
              AppSnackBar.showError(
                context,
                message: "Failed to share: ${e.toString()}",
                duration: Duration(seconds: 2),
              );
            }
          },
        ),
      ),
    );
  }
}
