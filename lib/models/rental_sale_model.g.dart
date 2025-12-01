// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rental_sale_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RentalSaleModelAdapter extends TypeAdapter<RentalSaleModel> {
  @override
  final int typeId = 6;

  @override
  RentalSaleModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RentalSaleModel(
      id: fields[0] as String,
      customerName: fields[1] as String,
      customerPhone: fields[2] as String,
      itemName: fields[3] as String,
      ratePerDay: fields[4] as double,
      numberOfDays: fields[5] as int,
      totalCost: fields[6] as double,
      fromDateTime: fields[7] as DateTime,
      toDateTime: fields[8] as DateTime,
      imageUrl: fields[9] as String?,
      pdfFilePath: fields[10] as String?,
      paymentMode: fields[11] as String,
      amountPaid: fields[12] as double,
      rentalDateTime: fields[13] as DateTime?,
      paymentHistory: (fields[14] as List?)?.cast<Payment>(),
    );
  }

  @override
  void write(BinaryWriter writer, RentalSaleModel obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.customerName)
      ..writeByte(2)
      ..write(obj.customerPhone)
      ..writeByte(3)
      ..write(obj.itemName)
      ..writeByte(4)
      ..write(obj.ratePerDay)
      ..writeByte(5)
      ..write(obj.numberOfDays)
      ..writeByte(6)
      ..write(obj.totalCost)
      ..writeByte(7)
      ..write(obj.fromDateTime)
      ..writeByte(8)
      ..write(obj.toDateTime)
      ..writeByte(9)
      ..write(obj.imageUrl)
      ..writeByte(10)
      ..write(obj.pdfFilePath)
      ..writeByte(11)
      ..write(obj.paymentMode)
      ..writeByte(12)
      ..write(obj.amountPaid)
      ..writeByte(13)
      ..write(obj.rentalDateTime)
      ..writeByte(14)
      ..write(obj.paymentHistory);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RentalSaleModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
