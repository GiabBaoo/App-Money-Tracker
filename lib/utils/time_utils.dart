class TimeUtils {
  static String timeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'Chưa cập nhật';
    
    final duration = DateTime.now().difference(dateTime);
    
    if (duration.inDays > 30) {
      return 'Cập nhật ngày ${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (duration.inDays >= 1) {
      return 'Đã đổi ${duration.inDays} ngày trước';
    } else if (duration.inHours >= 1) {
      return 'Đã đổi ${duration.inHours} giờ trước';
    } else if (duration.inMinutes >= 1) {
      return 'Đã đổi ${duration.inMinutes} phút trước';
    } else {
      return 'Vừa mới đổi';
    }
  }
}
