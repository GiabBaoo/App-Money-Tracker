import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/core/errors/business_exception.dart';
import 'package:money_tracker_app/core/session/session_manager.dart';
import 'package:money_tracker_app/core/safety/destructive_ops_guard.dart';
import 'package:money_tracker_app/data/local/owned_table_ops.dart';

class _DummyOwnedOps with OwnedTableOps {}

void main() {
  group('Phase 1 Regression Tests: Security & Session Isolation', () {
    setUp(() {
      SessionManager.instance.end();
    });

    tearDown(() {
      SessionManager.instance.end();
    });

    test('SEC-01: SessionManager unauthenticated throws BusinessException when requireUid() called', () {
      expect(SessionManager.instance.state, SessionState.signedOut);
      expect(SessionManager.instance.uidOrNull, isNull);

      expect(
        () => SessionManager.instance.requireUid(),
        throwsA(
          isA<BusinessException>().having(
            (e) => e.code,
            'code',
            BusinessErrorCode.unauthenticated,
          ),
        ),
      );
    });

    test('SEC-02: SessionManager activate() sets correct UID and increments epoch', () async {
      final initialEpoch = SessionManager.instance.epoch;

      SessionSnapshot? emitted;
      final sub = SessionManager.instance.changes.listen((snapshot) {
        emitted = snapshot;
      });

      SessionManager.instance.activate('test_uid_alpha_123');

      expect(SessionManager.instance.state, SessionState.active);
      expect(SessionManager.instance.uidOrNull, 'test_uid_alpha_123');
      expect(SessionManager.instance.epoch, initialEpoch + 1);
      expect(SessionManager.instance.requireUid(), 'test_uid_alpha_123');

      await Future.delayed(Duration.zero);
      expect(emitted, isNotNull);
      expect(emitted!.uid, 'test_uid_alpha_123');
      expect(emitted!.epoch, initialEpoch + 1);

      await sub.cancel();
    });

    test('SEC-03: SessionManager beginSwitch() isolates state and invalidates reads', () {
      SessionManager.instance.activate('user_A');
      final activeEpoch = SessionManager.instance.epoch;
      expect(SessionManager.instance.uidOrNull, 'user_A');

      SessionManager.instance.beginSwitch();

      expect(SessionManager.instance.state, SessionState.switching);
      expect(SessionManager.instance.uidOrNull, isNull);
      expect(SessionManager.instance.epoch, activeEpoch + 1);
      expect(
        () => SessionManager.instance.requireUid(),
        throwsA(isA<BusinessException>()),
      );
      expect(SessionManager.instance.isStillValid(activeEpoch, 'user_A'), isFalse);
    });

    test('SEC-04: SessionManager end() clears UID and notifies listeners', () async {
      SessionManager.instance.activate('user_to_logout');

      SessionSnapshot? lastEmitted;
      final sub = SessionManager.instance.changes.listen((s) => lastEmitted = s);

      SessionManager.instance.end();

      expect(SessionManager.instance.state, SessionState.signedOut);
      expect(SessionManager.instance.uidOrNull, isNull);

      await Future.delayed(Duration.zero);
      expect(lastEmitted, isNull);

      await sub.cancel();
    });

    test('SEC-05: SessionManager.isValidUid validates input boundaries', () {
      expect(SessionManager.isValidUid('valid_user_123'), isTrue);
      expect(SessionManager.isValidUid('firebase-uid-ABC_123'), isTrue);
      expect(SessionManager.isValidUid(null), isFalse);
      expect(SessionManager.isValidUid(''), isFalse);
      expect(SessionManager.isValidUid('null'), isFalse);
      expect(SessionManager.isValidUid('NULL'), isFalse);
      expect(SessionManager.isValidUid('undefined'), isFalse);
      expect(SessionManager.isValidUid('anonymous'), isFalse);
      expect(SessionManager.isValidUid('user with spaces'), isFalse);
      expect(SessionManager.isValidUid('user@email.com'), isFalse);
      expect(SessionManager.isValidUid('a' * 129), isFalse);
      expect(SessionManager.isValidUid('a' * 128), isTrue);
    });

    test('SEC-06: DestructiveOpsGuard blocks purge operations when not explicitly enabled', () {
      expect(
        () => DestructiveOpsGuard.ensureEnabled('purgeHistoryBeforeSeptember2026'),
        throwsA(
          isA<BusinessException>().having(
            (e) => e.code,
            'code',
            BusinessErrorCode.destructiveOpDisabled,
          ),
        ),
      );
    });

    test('SEC-07: OwnedTableOps stampOwner prevents cross-tenant data pollution', () {
      final ops = _DummyOwnedOps();

      // Gán UID hợp lệ khi row chưa có UID
      final stamped = ops.stampOwner({'id': 'item_1', 'name': 'Wallet'}, 'user_456');
      expect(stamped['uid'], 'user_456');

      // Cho phép nếu row đã có đúng UID của phiên
      final sameOwner = ops.stampOwner({'id': 'item_1', 'uid': 'user_456'}, 'user_456');
      expect(sameOwner['uid'], 'user_456');

      // Chặn nếu row mang UID của tài khoản khác
      expect(
        () => ops.stampOwner({'id': 'item_1', 'uid': 'attacker_uid'}, 'user_456'),
        throwsA(
          isA<BusinessException>().having(
            (e) => e.code,
            'code',
            BusinessErrorCode.ownershipViolation,
          ),
        ),
      );
    });
  });
}

