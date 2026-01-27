import 'package:flutter/material.dart';
import '../models/rental_cart_item.dart';

class RentalCart {
  // 🔥 Reactive notifier
  static final ValueNotifier<List<RentalCartItem>> notifier =
      ValueNotifier<List<RentalCartItem>>([]);

  // Existing API — unchanged
  static List<RentalCartItem> get items => notifier.value;

  static void add(RentalCartItem item) {
    notifier.value = [...notifier.value, item];
  }

  static void clear() {
    notifier.value = [];
  }

  static bool get isEmpty => notifier.value.isEmpty;

  static double get totalAmount =>
      notifier.value.fold(0.0, (sum, item) => sum + item.totalAmount);
}
