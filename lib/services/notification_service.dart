import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';
import '../data/repositories/notification_repository.dart';
import 'firestore_service.dart';
import 'local_notification_service.dart';

/// Dịch vụ điều phối thông báo hệ thống (System Event Notification Hub)
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationRepository _notificationRepo = NotificationRepository();

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  /// Điều phối một thông báo hệ thống (Ghi Local SQLite + Firestore + Đẩy Status bar nếu là user hiện tại)
  Future<void> dispatchNotification({
    required NotificationModel notification,
    bool pushStatusBar = true,
  }) async {
    try {
      final isCurrent = notification.uid == _currentUid;

      // 1. Ghi vào SQLite nếu thông báo dành cho người dùng hiện tại
      if (isCurrent) {
        await _notificationRepo.addNotification(notification);
      }

      // 2. Ghi trực tiếp lên Firestore
      try {
        if (isCurrent) {
          await _firestoreService.addNotification(notification);
        } else {
          await _firestoreService.addNotificationForUser(
            notification.uid,
            notification,
          );
        }
      } catch (e) {
        debugPrint('NotificationService Firestore sync error: $e');
      }

      // 3. Đẩy ra thanh trạng thái (Local Push Notification) nếu là thiết bị hiện tại
      if (isCurrent && pushStatusBar) {
        final randomId = Random().nextInt(100000);
        await LocalNotificationService.instance.showInstantNotification(
          id: randomId,
          title: notification.title,
          body: notification.description,
          payload: notification.type,
        );
      }
    } catch (e) {
      debugPrint('NotificationService dispatchNotification error: $e');
    }
  }

  /// Thông báo vượt quá hạn mức ngân sách
  Future<void> notifyBudgetExceeded({
    required String category,
    required double spent,
    required double limit,
    String? uid,
  }) async {
    final targetUid = uid ?? _currentUid;
    if (targetUid == null) return;

    final currencyFmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
    final spentStr = currencyFmt.format(spent);
    final limitStr = currencyFmt.format(limit);

    final noti = NotificationModel(
      uid: targetUid,
      iconCode: Icons.warning_amber_rounded.codePoint,
      title: 'Vượt hạn mức chi tiêu!',
      description:
          'Danh mục "$category" đã chi $spentStr, vượt hạn mức $limitStr.',
      createdAt: DateTime.now(),
      type: 'budget_exceeded',
    );

    await dispatchNotification(notification: noti);
  }

  /// Thông báo cảnh báo an toàn & bảo mật
  Future<void> notifySecurityAlert({
    required String title,
    required String message,
    String? uid,
  }) async {
    final targetUid = uid ?? _currentUid;
    if (targetUid == null) return;

    final noti = NotificationModel(
      uid: targetUid,
      iconCode: Icons.security_rounded.codePoint,
      title: title,
      description: message,
      createdAt: DateTime.now(),
      type: 'security_alert',
    );

    await dispatchNotification(notification: noti);
  }

  /// Thông báo lời mời tham gia nhóm quỹ chi tiêu
  Future<void> notifyGroupInvitation({
    required String groupName,
    required String inviterName,
    required String targetUid,
    String? groupId,
  }) async {
    final noti = NotificationModel(
      uid: targetUid,
      iconCode: Icons.group_add_rounded.codePoint,
      title: 'Lời mời tham gia nhóm chi tiêu',
      description: '$inviterName đã mời bạn tham gia nhóm "$groupName".',
      createdAt: DateTime.now(),
      type: 'group_invite',
      groupId: groupId,
      groupName: groupName,
    );

    await dispatchNotification(notification: noti);
  }

  /// Thông báo sự kiện hệ thống tùy biến
  Future<void> notifySystem({
    required String title,
    required String message,
    int? iconCode,
    String? type,
    String? uid,
  }) async {
    final targetUid = uid ?? _currentUid;
    if (targetUid == null) return;

    final noti = NotificationModel(
      uid: targetUid,
      iconCode: iconCode ?? Icons.notifications_active_rounded.codePoint,
      title: title,
      description: message,
      createdAt: DateTime.now(),
      type: type ?? 'system',
    );

    await dispatchNotification(notification: noti);
  }

  /// Lấy danh sách thông báo theo Stream
  Stream<QuerySnapshot> getNotificationsStream() {
    final uid = _currentUid;
    if (uid == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('notifications')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
