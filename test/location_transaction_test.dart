import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/models/transaction_model.dart';
import 'package:money_tracker_app/services/location_service.dart';

void main() {
  group('Location Transaction Tests', () {
    test('TransactionModel stores and preserves location coordinates', () {
      final tx = TransactionModel(
        id: 'test_tx_loc_1',
        uid: 'user_123',
        type: 'expense',
        category: 'Ăn uống',
        categoryIconCode: 12345,
        amount: 55000,
        date: DateTime(2026, 10, 21),
        time: '12:30',
        description: 'Cà phê sáng',
        location: 'Highlands Coffee, Q.1, TP.HCM',
        latitude: 10.7769,
        longitude: 106.7009,
      );

      expect(tx.location, 'Highlands Coffee, Q.1, TP.HCM');
      expect(tx.latitude, 10.7769);
      expect(tx.longitude, 106.7009);

      // Test SQLite Serialization
      final sqliteMap = tx.toSqlite();
      expect(sqliteMap['location'], 'Highlands Coffee, Q.1, TP.HCM');
      expect(sqliteMap['latitude'], 10.7769);
      expect(sqliteMap['longitude'], 106.7009);

      final fromSqliteTx = TransactionModel.fromSqlite(sqliteMap);
      expect(fromSqliteTx.id, tx.id);
      expect(fromSqliteTx.location, tx.location);
      expect(fromSqliteTx.latitude, tx.latitude);
      expect(fromSqliteTx.longitude, tx.longitude);

      // Test Firestore Serialization
      final firestoreMap = tx.toFirestore();
      expect(firestoreMap['location'], 'Highlands Coffee, Q.1, TP.HCM');
      expect(firestoreMap['latitude'], 10.7769);
      expect(firestoreMap['longitude'], 106.7009);

      // Test copyWith and clearLocation
      final updatedTx = tx.copyWith(location: 'Phúc Long Bến Nghé');
      expect(updatedTx.location, 'Phúc Long Bến Nghé');
      expect(updatedTx.latitude, 10.7769);

      final clearedTx = updatedTx.copyWith(clearLocation: true);
      expect(clearedTx.location, isNull);
      expect(clearedTx.latitude, isNull);
      expect(clearedTx.longitude, isNull);
    });

    test('LocationResult data class formats correctly', () {
      const res = LocationResult(
        placeName: 'Hồ Gươm, Hoàn Kiếm, Hà Nội',
        latitude: 21.0285,
        longitude: 105.8542,
      );

      expect(res.placeName, 'Hồ Gươm, Hoàn Kiếm, Hà Nội');
      expect(res.latitude, 21.0285);
      expect(res.longitude, 105.8542);
      expect(res.toString(), contains('LocationResult'));
    });
  });
}
