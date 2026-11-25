import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/services/midnight_sync_service.dart';
import 'package:money_tracker_app/services/sync_service.dart';

void main() {
  group('MidnightSyncService scheduling logic', () {
    test('isWithinMidnightWindow allows 00:00-02:59 and blocks 03:00-23:59', () {
      expect(
        MidnightSyncService.isWithinMidnightWindow(DateTime(2026, 11, 24, 0, 0)),
        isTrue,
      );
      expect(
        MidnightSyncService.isWithinMidnightWindow(DateTime(2026, 11, 24, 2, 59)),
        isTrue,
      );
      expect(
        MidnightSyncService.isWithinMidnightWindow(DateTime(2026, 11, 24, 3, 0)),
        isFalse,
      );
      expect(
        MidnightSyncService.isWithinMidnightWindow(DateTime(2026, 11, 24, 9, 15)),
        isFalse,
      );
      expect(
        MidnightSyncService.isWithinMidnightWindow(DateTime(2026, 11, 24, 23, 59)),
        isFalse,
      );
    });

    test('computeNextScheduleTime schedules today 00:00:05 if before 00:00:05 and not done', () {
      final now = DateTime(2026, 11, 24, 0, 0, 1);
      final next = MidnightSyncService.computeNextScheduleTime(
        now,
        lastBackedUpDateKey: '2026-11-23',
      );
      expect(next, DateTime(2026, 11, 24, 0, 0, 5));
    });

    test('computeNextScheduleTime schedules tomorrow 00:00:05 during daytime', () {
      final now = DateTime(2026, 11, 24, 9, 30);
      final next = MidnightSyncService.computeNextScheduleTime(
        now,
        lastBackedUpDateKey: '2026-11-23',
      );
      expect(next, DateTime(2026, 11, 25, 0, 0, 5));
    });

    test('computeNextScheduleTime schedules tomorrow 00:00:05 if today already backed up', () {
      final now = DateTime(2026, 11, 24, 0, 0, 1);
      final next = MidnightSyncService.computeNextScheduleTime(
        now,
        lastBackedUpDateKey: '2026-11-24',
      );
      expect(next, DateTime(2026, 11, 25, 0, 0, 5));
    });

    test('dailyBackupIdForDate and formatDisplayDate format deterministically', () {
      expect(
        MidnightSyncService.dailyBackupIdForDate('2026-11-23'),
        'daily_2026-11-23',
      );
      expect(
        MidnightSyncService.formatDisplayDate('2026-11-23'),
        '23/11/2026',
      );
    });
  });

  group('CloudBackupTypeX.fromWire', () {
    test('parses explicit wire values', () {
      expect(
        CloudBackupTypeX.fromWire('auto_daily'),
        CloudBackupType.autoDaily,
      );
      expect(
        CloudBackupTypeX.fromWire('pre_restore'),
        CloudBackupType.preRestore,
      );
      expect(CloudBackupTypeX.fromWire('manual'), CloudBackupType.manual);
    });

    test('infers type for legacy backup documents', () {
      expect(
        CloudBackupTypeX.fromWire(null, docId: 'daily_2026-11-23'),
        CloudBackupType.autoDaily,
      );
      expect(
        CloudBackupTypeX.fromWire(null, label: 'Sao lưu tự động 00:00'),
        CloudBackupType.autoDaily,
      );
      expect(
        CloudBackupTypeX.fromWire(null, label: 'Sao lưu an toàn trước khi khôi phục'),
        CloudBackupType.preRestore,
      );
      expect(
        CloudBackupTypeX.fromWire(null, label: 'Sao lưu thủ công'),
        CloudBackupType.manual,
      );
    });
  });

  group('CloudBackupSummary.displayTitle', () {
    test('replaces legacy 00:00 autoDaily label with date-formatted title without 00:00', () {
      final backup = CloudBackupSummary(
        id: 'legacy_auto',
        backedUpAt: DateTime(2026, 11, 23, 9, 15),
        backedUpAtMs: DateTime(2026, 11, 23, 9, 15).millisecondsSinceEpoch,
        walletCount: 1,
        transactionCount: 5,
        budgetCount: 0,
        goalCount: 0,
        totalBalance: 100000,
        wallets: const [],
        label: 'Sao lưu tự động 00:00',
        backupType: CloudBackupType.autoDaily,
        dateKey: '2026-11-23',
      );

      final viTitle = backup.displayTitle(isVi: true);
      final enTitle = backup.displayTitle(isVi: false);

      expect(viTitle, 'Sao lưu tự động • 23/11/2026');
      expect(enTitle, 'Daily Auto Backup • 23/11/2026');
      expect(viTitle.contains('00:00'), isFalse);
      expect(enTitle.contains('00:00'), isFalse);
    });

    test('formats preRestore and manual labels properly in VI and EN', () {
      final preRestore = CloudBackupSummary(
        id: 'pre_1',
        backedUpAt: DateTime(2026, 11, 23, 14, 0),
        backedUpAtMs: DateTime(2026, 11, 23, 14, 0).millisecondsSinceEpoch,
        walletCount: 1,
        transactionCount: 1,
        budgetCount: 0,
        goalCount: 0,
        totalBalance: 50000,
        wallets: const [],
        label: 'Sao lưu an toàn trước khi khôi phục',
        backupType: CloudBackupType.preRestore,
      );
      expect(preRestore.displayTitle(isVi: true), 'Sao lưu trước khi khôi phục');
      expect(preRestore.displayTitle(isVi: false), 'Pre-Restore Safety Backup');

      final manualDefault = CloudBackupSummary(
        id: 'man_1',
        backedUpAt: DateTime(2026, 11, 23, 15, 0),
        backedUpAtMs: DateTime(2026, 11, 23, 15, 0).millisecondsSinceEpoch,
        walletCount: 1,
        transactionCount: 1,
        budgetCount: 0,
        goalCount: 0,
        totalBalance: 50000,
        wallets: const [],
        label: 'Sao lưu thủ công',
        backupType: CloudBackupType.manual,
      );
      expect(manualDefault.displayTitle(isVi: true), 'Sao lưu thủ công');
      expect(manualDefault.displayTitle(isVi: false), 'Manual Backup');

      final manualCustom = CloudBackupSummary(
        id: 'man_2',
        backedUpAt: DateTime(2026, 11, 23, 16, 0),
        backedUpAtMs: DateTime(2026, 11, 23, 16, 0).millisecondsSinceEpoch,
        walletCount: 1,
        transactionCount: 1,
        budgetCount: 0,
        goalCount: 0,
        totalBalance: 50000,
        wallets: const [],
        label: 'Trước khi đổi máy',
        backupType: CloudBackupType.manual,
      );
      expect(manualCustom.displayTitle(isVi: true), 'Trước khi đổi máy');
      expect(manualCustom.displayTitle(isVi: false), 'Trước khi đổi máy');
    });
  });
}
