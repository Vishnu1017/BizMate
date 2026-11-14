import 'package:hive/hive.dart';

part 'expense.g.dart';

@HiveType(typeId: 7)
class Expense extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  double amount;

  @HiveField(3)
  String category;

  @HiveField(4)
  DateTime dateTime;

  @HiveField(5)
  String paymentMode;

  @HiveField(6)
  String? notes;

  @HiveField(7)
  String? receiptImagePath;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.dateTime,
    this.paymentMode = 'Cash',
    this.notes = '',
    this.receiptImagePath = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category,
        'dateTime': dateTime.toIso8601String(),
        'paymentMode': paymentMode,
        'notes': notes,
        'receiptImagePath': receiptImagePath,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: json['title']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        category: json['category']?.toString() ?? 'Other',
        dateTime: DateTime.tryParse(json['dateTime']?.toString() ?? '') ??
            DateTime.now(),
        paymentMode: json['paymentMode']?.toString() ?? 'Cash',
        notes: json['notes']?.toString() ?? '',
        receiptImagePath: json['receiptImagePath']?.toString() ?? '',
      );
}
