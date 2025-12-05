// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SaleAdapter extends TypeAdapter<Sale> {
  @override
  final int typeId = 1;

  @override
  Sale read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Sale(
      customerName: fields[0] as String,
      amount: fields[1] as double,
      productName: fields[2] as String,
      dateTime: fields[3] as DateTime,
      phoneNumber: fields[4] as String,
      totalAmount: fields[5] as double,
      discount: fields[11] as double,
      paymentHistory: (fields[6] as List).cast<Payment>(),
      deliveryStatus: fields[7] as String,
      deliveryLink: fields[8] as String,
      paymentMode: fields[9] as String,
      deliveryStatusHistory: (fields[10] as List?)?.cast<String>(),
      item: fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Sale obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.customerName)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.productName)
      ..writeByte(3)
      ..write(obj.dateTime)
      ..writeByte(4)
      ..write(obj.phoneNumber)
      ..writeByte(5)
      ..write(obj.totalAmount)
      ..writeByte(6)
      ..write(obj.paymentHistory)
      ..writeByte(7)
      ..write(obj.deliveryStatus)
      ..writeByte(8)
      ..write(obj.deliveryLink)
      ..writeByte(9)
      ..write(obj.paymentMode)
      ..writeByte(10)
      ..write(obj.deliveryStatusHistory)
      ..writeByte(11)
      ..write(obj.discount)
      ..writeByte(12)
      ..write(obj.item);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
