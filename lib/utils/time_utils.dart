class TimeUtils {
  static String timeAgo(DateTime? dateTime, {bool isVi = true}) {
    if (dateTime == null) return isVi ? 'Chưa cập nhật' : 'Not updated';
    
    final duration = DateTime.now().difference(dateTime);
    
    if (duration.inDays > 30) {
      return isVi
          ? 'Ngày ${dateTime.day}/${dateTime.month}/${dateTime.year}'
          : 'On ${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (duration.inDays >= 1) {
      return isVi ? '${duration.inDays} ngày trước' : '${duration.inDays} days ago';
    } else if (duration.inHours >= 1) {
      return isVi ? '${duration.inHours} giờ trước' : '${duration.inHours} hours ago';
    } else if (duration.inMinutes >= 1) {
      return isVi ? '${duration.inMinutes} phút trước' : '${duration.inMinutes} mins ago';
    } else {
      return isVi ? 'Vừa mới đây' : 'Just now';
    }
  }
}
