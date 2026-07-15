import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// Whether the vault has been unlocked in this app session.
class VaultUnlockNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool unlocked) => state = unlocked;
}

final vaultUnlockedProvider =
    NotifierProvider<VaultUnlockNotifier, bool>(VaultUnlockNotifier.new);

final biometricServiceProvider =
    Provider<BiometricService>((ref) => BiometricService());

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Device supports biometrics or a PIN/pattern/passcode.
  Future<bool> canAuthenticate() async {
    try {
      return await _auth.isDeviceSupported() ||
          await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Shows the platform biometric prompt (falls back to device PIN).
  /// Returns true when the user authenticated successfully.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException catch (e) {
      // No enrolled biometrics / no device credential → don't lock the
      // user out of their own data.
      debugPrint('Biometric auth error: ${e.code}');
      return e.code == 'NotAvailable' || e.code == 'NotEnrolled';
    } catch (e) {
      debugPrint('Biometric auth unavailable: $e');
      return false;
    }
  }
}
