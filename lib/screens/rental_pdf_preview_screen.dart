import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/rental_sale_model.dart';
import 'package:cross_file/cross_file.dart';
import '../../widgets/app_snackbar.dart';

class RentalPdfPreviewScreen extends StatelessWidget {
  final String filePath;
  final RentalSaleModel sale;
  final String userName;

  const RentalPdfPreviewScreen({
    super.key,
    required this.filePath,
    required this.sale,
    required this.userName, required String customerName,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final outerMargin = screenWidth * 0.03;
    final innerMargin = screenWidth * 0.04;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF00BCD4)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          title: const Text(
            "Rental Invoice Preview",
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
              padding: const EdgeInsets.all(10),
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
                    boxShadow: const [
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
          gradient: const LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF00BCD4)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: FloatingActionButton.extended(
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.share, color: Colors.white),
          label: const Text("Share", style: TextStyle(color: Colors.white)),
          onPressed: () async {
            final message = '''
Hi ${sale.customerName},

🧾 *Rental Invoice Summary*
• Item: ${sale.itemName}
• Rate/day: ₹${sale.ratePerDay.toStringAsFixed(2)}
• Days: ${sale.numberOfDays}
• Total: ₹${(sale.ratePerDay * sale.numberOfDays).toStringAsFixed(2)}
• From: ${sale.fromDateTime.day}/${sale.fromDateTime.month}/${sale.fromDateTime.year}
• To: ${sale.toDateTime.day}/${sale.toDateTime.month}/${sale.toDateTime.year}

Thanks for renting with us!
''';

            final file = XFile(filePath);

            // 1️⃣ Copy message to clipboard
            await Clipboard.setData(ClipboardData(text: message));
            AppSnackBar.showSuccess(
              context,
              message:
                  "Message copied! Paste it in WhatsApp after selecting contact.",duration: Duration(seconds: 2)
            );

            await Future.delayed(const Duration(milliseconds: 300));

            // 2️⃣ Share PDF and message
            try {
              await Share.shareXFiles(
                [file],
                text: message,
                subject: '📸 Rental Invoice from Shutter Life Photography',
              );
            } catch (e) {
              AppSnackBar.showError(
                context,
                message: "Failed to share: ${e.toString()}",
                duration: const Duration(seconds: 2),
              );
            }
          },
        ),
      ),
    );
  }
}
