import 'dart:async';
import '../errors/business_exception.dart';

enum SessionState { signedOut, switching, active }

class SessionSnapshot {
  final String uid;
  final int epoch;
  const SessionSnapshot(this.uid, this.epoch);
}

class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  // Firebase UID (email/password) = 28 ký tự [A-Za-z0-9]; nới tới 128 cho custom token.
  static final RegExp _uidPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static const _reserved = {'null', 'undefined', 'anonymous'};

  String? _uid;
  int _epoch = 0;
  SessionState _state = SessionState.signedOut;
  final _ctrl = StreamController<SessionSnapshot?>.broadcast();

  Stream<SessionSnapshot?> get changes => _ctrl.stream;
  int get epoch => _epoch;
  SessionState get state => _state;

  static bool isValidUid(String? uid) =>
      uid != null &&
      _uidPattern.hasMatch(uid) &&
      !_reserved.contains(uid.toLowerCase());

  /// Dùng cho thao tác ĐỌC: null nghĩa là trả về rỗng.
  String? get uidOrNull =>
      (_state == SessionState.active && isValidUid(_uid)) ? _uid : null;

  /// Dùng cho thao tác GHI: throw nếu không có phiên hợp lệ.
  String requireUid() {
    final uid = uidOrNull;
    if (uid == null) {
      throw const BusinessException(
        BusinessErrorCode.unauthenticated,
        'Không có phiên đăng nhập hợp lệ',
      );
    }
    return uid;
  }

  /// Gọi TRƯỚC khi đăng xuất/đổi tài khoản: chặn mọi ghi mới, vô hiệu epoch cũ.
  void beginSwitch() {
    _state = SessionState.switching;
    _epoch++;
    _ctrl.add(null);
  }

  void activate(String uid) {
    if (!isValidUid(uid)) {
      throw BusinessException(
        BusinessErrorCode.invalidUid,
        'UID không hợp lệ: "$uid"',
      );
    }
    _uid = uid;
    _state = SessionState.active;
    _epoch++;
    _ctrl.add(SessionSnapshot(uid, _epoch));
  }

  void end() {
    _uid = null;
    _state = SessionState.signedOut;
    _epoch++;
    _ctrl.add(null);
  }

  bool isStillValid(int epoch, String uid) =>
      _state == SessionState.active && _epoch == epoch && _uid == uid;
}
