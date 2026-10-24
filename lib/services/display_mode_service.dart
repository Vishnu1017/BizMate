// lib/services/display_mode_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service responsible for managing high screen refresh rates (60Hz, 90Hz, 120Hz, 144Hz, 165Hz)
/// and GPU display synchronization across different hardware vendors (Qualcomm Adreno, ARM Mali,
/// ARM Immortalis, Apple Silicon, PowerVR, etc.).
class DisplayModeService {
  DisplayModeService._();
  static final DisplayModeService instance = DisplayModeService._();

  static const MethodChannel _channel = MethodChannel('com.bizmate.app/display');

  final ValueNotifier<double> currentRefreshRate = ValueNotifier<double>(60.0);
  final ValueNotifier<List<double>> supportedRefreshRates = ValueNotifier<List<double>>([60.0]);

  bool _initialized = false;

  /// Initializes high refresh rate optimization on app startup.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!kIsWeb && Platform.isAndroid) {
      try {
        final appliedRate = await enableHighestRefreshRate();
        final available = await getAvailableRefreshRates();
        supportedRefreshRates.value = available;
        currentRefreshRate.value = appliedRate;
        debugPrint(
          'DisplayModeService: Initialized high refresh rate: ${appliedRate.toStringAsFixed(0)} Hz. Available modes: $available',
        );
      } catch (e) {
        debugPrint('DisplayModeService: Could not initialize high refresh rate: $e');
      }
    } else if (!kIsWeb && Platform.isIOS) {
      // iOS ProMotion (120Hz) is controlled by CADisableMinimumFrameDurationOnPhone in Info.plist
      currentRefreshRate.value = 120.0;
    }
  }

  /// Requests the hardware display and GPU to switch to the highest available refresh rate.
  Future<double> enableHighestRefreshRate() async {
    if (kIsWeb || !Platform.isAndroid) return 60.0;
    try {
      final rate = await _channel.invokeMethod<double>('setHighRefreshRate');
      if (rate != null && rate > 0) {
        currentRefreshRate.value = rate;
        return rate;
      }
    } on MissingPluginException {
      debugPrint('DisplayModeService: Display channel not available on this platform.');
    } catch (e) {
      debugPrint('DisplayModeService error setting high refresh rate: $e');
    }
    return 60.0;
  }

  /// Queries all hardware refresh rates supported by the current display panel.
  Future<List<double>> getAvailableRefreshRates() async {
    if (kIsWeb || !Platform.isAndroid) return [60.0];
    try {
      final List<dynamic>? rates = await _channel.invokeMethod<List<dynamic>>('getAvailableRefreshRates');
      if (rates != null && rates.isNotEmpty) {
        final doubleList = rates.map((r) => (r as num).toDouble()).toList()..sort();
        supportedRefreshRates.value = doubleList;
        return doubleList;
      }
    } catch (e) {
      debugPrint('DisplayModeService error getting available refresh rates: $e');
    }
    return [60.0];
  }

  /// Gets the currently active refresh rate in Hz.
  Future<double> getCurrentRefreshRate() async {
    if (kIsWeb || !Platform.isAndroid) return 60.0;
    try {
      final rate = await _channel.invokeMethod<double>('getCurrentRefreshRate');
      if (rate != null && rate > 0) {
        currentRefreshRate.value = rate;
        return rate;
      }
    } catch (e) {
      debugPrint('DisplayModeService error getting current refresh rate: $e');
    }
    return 60.0;
  }

  /// User-friendly label for current display performance.
  String get refreshRateLabel {
    final rate = currentRefreshRate.value;
    if (rate >= 144) {
      return '${rate.toStringAsFixed(0)} Hz (Ultra High)';
    } else if (rate >= 120) {
      return '${rate.toStringAsFixed(0)} Hz (ProMotion / Smooth 120)';
    } else if (rate >= 90) {
      return '${rate.toStringAsFixed(0)} Hz (Smooth 90)';
    }
    return '${rate.toStringAsFixed(0)} Hz (Standard)';
  }
}
