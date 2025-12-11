import 'package:hive/hive.dart';

part 'delivery_status.g.dart';

@HiveType(typeId: 50)
class DeliveryStatus extends HiveObject {
  @HiveField(0)
  String status;

  @HiveField(1)
  String dateTime;

  @HiveField(2)
  String notes;

  DeliveryStatus({
    required this.status,
    required this.dateTime,
    required this.notes,
  });
}
