import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// ----------------------------------------------------------------
/// BIOMETRIC AUTHENTICATION SERVICE
/// Safe wrapper for Face ID, Touch ID, and Android Fingerprint auth
/// ----------------------------------------------------------------
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Check if the device hardware supports biometrics and has enrolled biometrics
  static Future<bool> canAuthenticate() async {
    try {
      final bool isSupported = await _auth.isDeviceSupported();
      final bool canCheck = await _auth.canCheckBiometrics;
      if (!isSupported || !canCheck) return false;

      final List<BiometricType> availableBiometrics =
          await _auth.getAvailableBiometrics();

      return availableBiometrics.isNotEmpty;
    } on PlatformException catch (e) {
      debugPrint('Biometric availability check failed: $e');
      return false;
    } catch (e) {
      debugPrint('Biometric check error: $e');
      return false;
    }
  }

  /// Trigger biometric authentication prompt
  static Future<bool> authenticate({
    String reason = 'Please authenticate to access BizMate',
  }) async {
    try {
      final bool canAuth = await canAuthenticate();
      if (!canAuth) return false;

      return await _auth.authenticate(
        localizedReason: reason,
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric authentication failed: $e');
      return false;
    } catch (e) {
      debugPrint('Biometric error: $e');
      return false;
    }
  }
}
