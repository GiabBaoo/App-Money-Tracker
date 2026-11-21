import 'package:intl/intl.dart';
import '../models/transaction_model.dart';

/// Nhóm giao dịch theo một ngày cụ thể kèm tổng thu / chi trong ngày.
class TransactionDayGroup {
  final DateTime date;
  final List<TransactionModel> transactions;
  final double totalIncome;
  final double totalExpense;

  const TransactionDayGroup({
    required this.date,
    required this.transactions,
    required this.totalIncome,
    required this.totalExpense,
  });
}

class TimeUtils {
  static String timeAgo(DateTime? dateTime, {bool isVi = true}) {
    if (dateTime == null) return isVi ? 'Chưa cập nhật' : 'Not updated';

    final duration = DateTime.now().difference(dateTime);

    if (duration.inDays > 30) {
      return isVi
          ? 'Ngày ${dateTime.day}/${dateTime.month}/${dateTime.year}'
          : 'On ${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (duration.inDays >= 1) {
      return isVi
          ? '${duration.inDays} ngày trước'
          : '${duration.inDays} days ago';
    } else if (duration.inHours >= 1) {
      return isVi
          ? '${duration.inHours} giờ trước'
          : '${duration.inHours} hours ago';
    } else if (duration.inMinutes >= 1) {
      return isVi
          ? '${duration.inMinutes} phút trước'
          : '${duration.inMinutes} mins ago';
    } else {
      return isVi ? 'Vừa mới đây' : 'Just now';
    }
  }

  /// Nhóm danh sách giao dịch theo ngày (mới nhất trước).
  /// Nếu [maxDays] khác null, chỉ giữ tối đa [maxDays] ngày gần nhất có giao dịch.
  static List<TransactionDayGroup> groupTransactionsByDay(
    List<TransactionModel> transactions, {
    int? maxDays,
  }) {
    if (transactions.isEmpty) return const [];

    final Map<DateTime, List<TransactionModel>> bucket = {};
    for (final tx in transactions) {
      final dayKey = DateTime(tx.date.year, tx.date.month, tx.date.day);
      bucket.putIfAbsent(dayKey, () => <TransactionModel>[]).add(tx);
    }

    final sortedDays = bucket.keys.toList()..sort((a, b) => b.compareTo(a));
    final limitedDays = (maxDays != null && sortedDays.length > maxDays)
        ? sortedDays.sublist(0, maxDays)
        : sortedDays;

    return limitedDays.map((day) {
      final txs = bucket[day]!;
      double income = 0.0;
      double expense = 0.0;
      for (final tx in txs) {
        if (tx.type == 'income') {
          income += tx.amount;
        } else {
          expense += tx.amount;
        }
      }
      return TransactionDayGroup(
        date: day,
        transactions: txs,
        totalIncome: income,
        totalExpense: expense,
      );
    }).toList();
  }

  /// Nhãn ngày thân thiện: "Hôm nay - dd/MM/yyyy", "Hôm qua - ...", "Thứ Hai - ..."
  static String formatFriendlyDate(
    DateTime date, {
    bool isVi = true,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;
    final formatted = DateFormat('dd/MM/yyyy').format(date);

    if (diff == 0) {
      return isVi ? 'Hôm nay - $formatted' : 'Today - $formatted';
    } else if (diff == 1) {
      return isVi ? 'Hôm qua - $formatted' : 'Yesterday - $formatted';
    }

    const weekdayNamesVi = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    const weekdayNamesEn = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final weekday = isVi
        ? weekdayNamesVi[date.weekday - 1]
        : weekdayNamesEn[date.weekday - 1];
    return '$weekday - $formatted';
  }
}
