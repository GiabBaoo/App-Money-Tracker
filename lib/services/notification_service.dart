import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // HÀM ĐẨY DỮ LIỆU ẢO (MOCK DATA) LÊN FIRESTORE THEO YÊU CẦU
  Future<void> pushMockNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      print('Người dùng chưa đăng nhập!');
      return;
    }

    final List<Map<String, dynamic>> mockData = [
      {
        'title': 'Cảnh báo chi tiêu',
        'content': 'Bạn đã chi quá hạn mức hôm nay. Hãy cân nhắc lại các khoản chi sắp tới nhé!',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'uid': uid,
      },
      {
        'title': 'Nhắc nhở ghi chép',
        'content': 'Đừng quên ghi lại các khoản chi tiêu buổi tối nhé! Việc này giúp bạn quản lý tiền tốt hơn.',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'uid': uid,
      },
      {
        'title': 'Chào mừng',
        'content': 'Chào mừng bạn đến với Money Tracker. Hãy bắt đầu hành trình quản lý tài chính ngay hôm nay!',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': true,
        'uid': uid,
      },
      {
        'title': 'Mục tiêu tài chính',
        'content': 'Bạn đang thực hiện rất tốt các mục tiêu tiết kiệm của tháng này!',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'uid': uid,
      },
    ];

    try {
      final batch = _firestore.batch();
      for (var data in mockData) {
        final docRef = _firestore.collection('notifications').doc();
        batch.set(docRef, data);
      }
      await batch.commit();
      print('Đã đẩy dữ liệu ảo thành công!');
    } catch (e) {
      print('Lỗi khi đẩy dữ liệu: $e');
    }
  }

  // Lấy danh sách thông báo của người dùng
  Stream<QuerySnapshot> getNotificationsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return _firestore
        .collection('notifications')
        .where('uid', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
