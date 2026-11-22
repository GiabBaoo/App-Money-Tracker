import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/models/transaction_model.dart';
import 'package:money_tracker_app/services/place_name_resolver.dart';
import 'package:money_tracker_app/widgets/mini_location_map.dart';

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

    test('PlaceNameResolver.rankByProximity sorts nearest branch first and deduplicates', () {
      // Vị trí người dùng ở Quận 1, TP.HCM
      const userLat = 10.7769;
      const userLon = 106.7009;

      final candidates = [
        const LocationResult(
          placeName: 'Bách Hóa Xanh Hà Nội',
          latitude: 21.0285,
          longitude: 105.8542,
        ),
        const LocationResult(
          placeName: 'Bách Hóa Xanh Quận 5',
          latitude: 10.7540,
          longitude: 106.6634,
        ),
        const LocationResult(
          placeName: 'Bách Hóa Xanh Quận 1 (gần nhất)',
          latitude: 10.7775,
          longitude: 106.7012,
        ),
        // Trùng lặp trong bán kính <50m với kết quả Quận 1
        const LocationResult(
          placeName: 'Bách Hóa Xanh Q1 duplicate',
          latitude: 10.77751,
          longitude: 106.70121,
        ),
      ];

      final ranked = PlaceNameResolver.rankByProximity(
        candidates,
        userLat: userLat,
        userLon: userLon,
        limit: 5,
      );

      expect(ranked.length, 3);
      expect(ranked.first.placeName, 'Bách Hóa Xanh Quận 1 (gần nhất)');
      expect(ranked.first.distanceMeters, isNotNull);
      expect(ranked.first.distanceMeters!, lessThan(150));
      expect(ranked[1].placeName, 'Bách Hóa Xanh Quận 5');
      expect(ranked[2].placeName, 'Bách Hóa Xanh Hà Nội');
      expect(ranked[0].distanceMeters!, lessThan(ranked[1].distanceMeters!));
      expect(ranked[1].distanceMeters!, lessThan(ranked[2].distanceMeters!));
    });

    test('MiniLocationMap.latLonToTile computes valid Web Mercator coordinates', () {
      final tile = MiniLocationMap.latLonToTile(10.7769, 106.7009, 16);
      expect(tile.x, greaterThan(52000));
      expect(tile.x, lessThan(53000));
      expect(tile.y, greaterThan(30000));
      expect(tile.y, lessThan(31500));
    });

    testWidgets('MiniLocationMap renders placeName, coordinates, and controls', (
      tester,
    ) async {
      var tapped = false;
      var cleared = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiniLocationMap(
              latitude: 10.7769,
              longitude: 106.7009,
              placeName: 'Bách Hóa Xanh, Nguyễn Trãi, Q.1',
              actionLabel: 'Đổi vị trí',
              onTap: () => tapped = true,
              onClear: () => cleared = true,
            ),
          ),
        ),
      );

      expect(find.text('Bách Hóa Xanh, Nguyễn Trãi, Q.1'), findsOneWidget);
      expect(find.text('Đổi vị trí'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);

      await tester.tap(find.text('Đổi vị trí'));
      expect(tapped, isTrue);

      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(cleared, isTrue);
    });

    test('PlaceNameResolver.foldVietnamese preserves 1-to-1 length for highlighting', () {
      const s1 = 'Hồng Trà Ngô Gia';
      const s2 = 'Katinat Cao Thắng, Quận 3';
      expect(PlaceNameResolver.foldVietnamese(s1), 'hong tra ngo gia');
      expect(PlaceNameResolver.foldVietnamese(s1).length, s1.length);
      expect(PlaceNameResolver.foldVietnamese(s2), 'katinat cao thang, quan 3');
      expect(PlaceNameResolver.foldVietnamese(s2).length, s2.length);
    });

    test('PlaceNameResolver.normalizeVietnameseQuery expands common abbreviations', () {
      expect(
        PlaceNameResolver.normalizeVietnameseQuery('katinat cao thang q3 tphcm'),
        'katinat cao thang Quận 3 Hồ Chí Minh',
      );
      expect(
        PlaceNameResolver.normalizeVietnameseQuery('hong tra ngo gia p.5 q10'),
        'hong tra ngo gia Phường 5 Quận 10',
      );
    });

    test('PlaceNameResolver.rankSmartResults prioritizes full POI match & nearest branch', () {
      // Người dùng ở Quận 3, TP.HCM
      const userLat = 10.7720;
      const userLon = 106.6830;

      final katinatCandidates = [
        const LocationResult(
          placeName: 'Đường Cao Thắng, Quận 3, TP. Hồ Chí Minh',
          title: 'Đường Cao Thắng',
          subtitle: 'Quận 3, TP. Hồ Chí Minh',
          latitude: 10.7721,
          longitude: 106.6831,
          provider: 'nominatim',
        ),
        const LocationResult(
          placeName:
              'Katinat Coffee & Tea House - Cao Thắng, 91 Cao Thắng, Phường 3, Quận 3, TP. Hồ Chí Minh',
          title: 'Katinat Coffee & Tea House - Cao Thắng',
          subtitle: '91 Cao Thắng, Phường 3, Quận 3, TP. Hồ Chí Minh',
          latitude: 10.7725,
          longitude: 106.6835,
          provider: 'arcgis',
        ),
      ];

      final rankedKatinat = PlaceNameResolver.rankSmartResults(
        katinatCandidates,
        query: 'katinat cao thang',
        userLat: userLat,
        userLon: userLon,
      );
      expect(rankedKatinat.first.displayTitle, contains('Katinat'));
      expect(rankedKatinat.first.displaySubtitle, contains('91 Cao Thắng'));

      final teaCandidates = [
        const LocationResult(
          placeName: 'Hồng Trà Ngô Gia, 120 Lê Văn Sỹ, Phú Nhuận, TP. Hồ Chí Minh',
          title: 'Hồng Trà Ngô Gia',
          subtitle: '120 Lê Văn Sỹ, Phú Nhuận, TP. Hồ Chí Minh',
          latitude: 10.7930,
          longitude: 106.6780,
          provider: 'arcgis',
        ),
        const LocationResult(
          placeName: 'Hồng Trà Ngô Gia, 45 Cao Thắng, Quận 3, TP. Hồ Chí Minh',
          title: 'Hồng Trà Ngô Gia',
          subtitle: '45 Cao Thắng, Quận 3, TP. Hồ Chí Minh',
          latitude: 10.7722,
          longitude: 106.6832,
          provider: 'arcgis',
        ),
      ];

      final rankedTea = PlaceNameResolver.rankSmartResults(
        teaCandidates,
        query: 'hong tra ngo gia',
        userLat: userLat,
        userLon: userLon,
      );
      expect(rankedTea.length, 2);
      expect(rankedTea.first.displaySubtitle, contains('45 Cao Thắng'));
      expect(
        rankedTea.first.distanceMeters!,
        lessThan(rankedTea.last.distanceMeters!),
      );
    });
  });
}
