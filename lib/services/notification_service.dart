import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/rental_sale_model.dart';

/// ----------------------------------------------------------------
/// LOCAL NOTIFICATION SERVICE
/// Automated alerts for overdue rentals and reminders
/// ----------------------------------------------------------------
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  /// Initialize local notification channels
  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          debugPrint('Notification tapped: ${details.payload}');
        },
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// Display an instant local notification
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (!_isInitialized) await init();

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'bizmate_channel_id',
            'BizMate Business Alerts',
            channelDescription:
                'Notifications for rentals, stock, and reminders',
            importance: Importance.max,
            priority: Priority.high,
          );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Show notification error: $e');
    }
  }

  /// Check camera/item rentals due today or overdue and trigger notification
  static Future<void> checkOverdueRentals(List<RentalSaleModel> rentals) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var rental in rentals) {
      final endDate = DateTime(
        rental.toDateTime.year,
        rental.toDateTime.month,
        rental.toDateTime.day,
      );

      if (endDate.isBefore(today)) {
        await showNotification(
          id: rental.id.hashCode,
          title: '🚨 Overdue Rental Return',
          body:
              'Rental for ${rental.customerName} is overdue! (Due: ${rental.toDateTime.day}/${rental.toDateTime.month})',
        );
      } else if (endDate.isAtSameMomentAs(today)) {
        await showNotification(
          id: rental.id.hashCode + 1,
          title: '⏰ Rental Due Today',
          body:
              'Rental return for ${rental.customerName} is scheduled for today.',
        );
      }
    }
  }
}
