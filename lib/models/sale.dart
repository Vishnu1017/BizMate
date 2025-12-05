import 'dart:convert';
import 'package:bizmate/models/payment.dart';
import 'package:hive/hive.dart';

part 'sale.g.dart';

@HiveType(typeId: 1)
class Sale extends HiveObject {
  @HiveField(0)
  String customerName;

  @HiveField(1)
  double amount;

  @HiveField(2)
  String productName;

  @HiveField(3)
  DateTime dateTime;

  @HiveField(4)
  String phoneNumber;

  @HiveField(5)
  double totalAmount;

  @HiveField(6)
  List<Payment> paymentHistory;

  @HiveField(7)
  String deliveryStatus;

  @HiveField(8)
  String deliveryLink;

  @HiveField(9)
  String paymentMode;

  @HiveField(10)
  List<String>? deliveryStatusHistory;

  @HiveField(11)
  double discount;

  @HiveField(12)
  String item;

  Sale({
    required this.customerName,
    required this.amount,
    required this.productName,
    required this.dateTime,
    required this.phoneNumber,
    required this.totalAmount,
    required this.discount,
    this.paymentHistory = const [],
    this.deliveryStatus = 'All Non Editing Images',
    this.deliveryLink = '',
    this.paymentMode = 'Cash',
    this.deliveryStatusHistory,
    required this.item,
  });

  List<Map<String, dynamic>> get parsedDeliveryHistory {
    if (deliveryStatusHistory == null) return [];
    return deliveryStatusHistory!
        .map((e) => Map<String, dynamic>.from(jsonDecode(e)))
        .toList();
  }

  Future<void> addDeliveryStatus(String status, String notes) async {
    deliveryStatusHistory ??= <String>[];
    deliveryStatusHistory!.insert(
      0,
      jsonEncode({
        'status': status,
        'dateTime': DateTime.now().toIso8601String(),
        'notes': notes,
      }),
    );

    deliveryStatus = status;
    await save();
  }

  double get receivedAmount =>
      paymentHistory.fold(0.0, (sum, p) => sum + p.amount);

  double get balanceAmount => totalAmount - receivedAmount;

  String get formattedDate =>
      "${dateTime.day.toString().padLeft(2, '0')}-"
      "${dateTime.month.toString().padLeft(2, '0')}-"
      "${dateTime.year}";

  @override
  Future<void> delete() {
    if (discount > 0) {
      throw Exception("Deleting this sale is not allowed.");
    }
    return super.delete();
  }
}
