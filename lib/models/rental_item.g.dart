// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rental_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RentalItemAdapter extends TypeAdapter<RentalItem> {
  @override
  final int typeId = 4;

  @override
  RentalItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RentalItem(
      name: fields[0] as String,
      brand: fields[1] as String,
      category: fields[2] as String,
      price: fields[3] as double,
      availability: fields[4] as String,
      imagePath: fields[5] as String,
      bookedSlots: (fields[6] as List?)?.cast<RentalBooking>(),
      condition: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, RentalItem obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.brand)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.price)
      ..writeByte(4)
      ..write(obj.availability)
      ..writeByte(5)
      ..write(obj.imagePath)
      ..writeByte(6)
      ..write(obj.bookedSlots)
      ..writeByte(7)
      ..write(obj.condition);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RentalItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RentalBookingAdapter extends TypeAdapter<RentalBooking> {
  @override
  final int typeId = 5;

  @override
  RentalBooking read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RentalBooking(
      from: fields[0] as DateTime,
      to: fields[1] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, RentalBooking obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.from)
      ..writeByte(1)
      ..write(obj.to);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RentalBookingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
