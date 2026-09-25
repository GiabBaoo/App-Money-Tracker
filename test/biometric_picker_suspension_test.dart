import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/services/biometric_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BiometricService - Picker Suspension Tests', () {
    final service = BiometricService.instance;

    test('isPickerActive is true during runWithPickerSuspended execution', () async {
      bool activeDuringAction = false;
      await service.runWithPickerSuspended(() async {
        activeDuringAction = service.isPickerActive;
        return 'done';
      });

      expect(activeDuringAction, isTrue);
      // Immediately after action completes, it should still be true due to the grace period
      expect(service.isPickerActive, isTrue);
    });

    test('setPickerActive sets active state and grace buffer', () {
      service.setPickerActive(true);
      expect(service.isPickerActive, isTrue);

      service.setPickerActive(false);
      // Within the 1500ms grace period, isPickerActive is still true
      expect(service.isPickerActive, isTrue);
    });
  });
}
