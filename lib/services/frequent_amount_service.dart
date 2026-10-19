import '../models/transaction_model.dart';

/// Kết quả phân tích thói quen giao dịch lặp lại theo mức tiền
class HabitRecurringPattern {
  final String category;
  final String description;
  final int count;

  const HabitRecurringPattern({
    required this.category,
    required this.description,
    required this.count,
  });
}

/// Dịch vụ phân tích thói quen giao dịch và gợi ý số tiền / danh mục quen thuộc
class FrequentAmountService {
  /// Tìm thói quen giao dịch quen thuộc tương ứng với mức tiền người dùng vừa nhập
  /// Phục vụ tự động điền danh mục và nội dung khi gõ đúng số tiền lặp lại (>= minOccurrences)
  static HabitRecurringPattern? findRecurringPattern({
    required List<TransactionModel> transactions,
    required bool isIncome,
    required double amount,
    int minOccurrences = 2,
    int days = 90,
  }) {
    if (amount <= 0 || transactions.isEmpty) return null;

    final targetType = isIncome ? 'income' : 'expense';
    final cutoffDate = DateTime.now().subtract(Duration(days: days));

    // Lọc các giao dịch có cùng loại và cùng số tiền
    var matched = transactions.where((tx) {
      if (tx.type != targetType) return false;
      if ((tx.amount - amount).abs() > 0.01) return false;
      return tx.date.isAfter(cutoffDate);
    }).toList();

    // Mở rộng toàn bộ lịch sử nếu trong 90 ngày chưa đủ minOccurrences
    if (matched.length < minOccurrences) {
      matched = transactions.where((tx) {
        if (tx.type != targetType) return false;
        return (tx.amount - amount).abs() <= 0.01;
      }).toList();
    }

    if (matched.length < minOccurrences) return null;

    // Gom nhóm theo category
    final Map<String, List<TransactionModel>> categoryGroups = {};
    for (final tx in matched) {
      final cat = tx.category.trim();
      if (cat.isEmpty) continue;
      categoryGroups.putIfAbsent(cat, () => []).add(tx);
    }

    if (categoryGroups.isEmpty) return null;

    // Tìm danh mục có số lần xuất hiện cao nhất
    String? topCategory;
    int maxCount = 0;
    categoryGroups.forEach((cat, txList) {
      if (txList.length > maxCount) {
        maxCount = txList.length;
        topCategory = cat;
      }
    });

    if (topCategory == null || maxCount < minOccurrences) return null;

    // Trong danh mục chiến thắng, tìm nội dung (ghi chú) phổ biến nhất hoặc gần nhất
    final txsInTopCategory = categoryGroups[topCategory]!;
    final Map<String, int> descCounts = {};
    final Map<String, DateTime> descLatestDate = {};

    for (final tx in txsInTopCategory) {
      final desc = tx.description.trim();
      if (desc.isNotEmpty) {
        descCounts[desc] = (descCounts[desc] ?? 0) + 1;
        final prevDate = descLatestDate[desc];
        if (prevDate == null || tx.date.isAfter(prevDate)) {
          descLatestDate[desc] = tx.date;
        }
      }
    }

    String topDescription = '';
    if (descCounts.isNotEmpty) {
      final sortedDescs = descCounts.keys.toList();
      sortedDescs.sort((a, b) {
        final countCmp = descCounts[b]!.compareTo(descCounts[a]!);
        if (countCmp != 0) return countCmp;
        return descLatestDate[b]!.compareTo(descLatestDate[a]!);
      });
      topDescription = sortedDescs.first;
    }

    return HabitRecurringPattern(
      category: topCategory!,
      description: topDescription,
      count: maxCount,
    );
  }

  /// Lấy danh sách các mức tiền quen thuộc (sắp xếp theo tần suất xuất hiện và độ mới)
  static List<double> getFrequentAmounts({
    required List<TransactionModel> transactions,
    required bool isIncome,
    String? category,
    int days = 90,
    int maxResults = 4,
  }) {
    if (transactions.isEmpty) return const [];

    final targetType = isIncome ? 'income' : 'expense';
    final normalizedCategory = category?.trim().toLowerCase();
    final cutoffDate = DateTime.now().subtract(Duration(days: days));

    var filtered = transactions.where((tx) {
      if (tx.type != targetType) return false;
      if (tx.amount <= 0) return false;
      if (normalizedCategory != null && normalizedCategory.isNotEmpty) {
        if (tx.category.trim().toLowerCase() != normalizedCategory) return false;
      }
      return tx.date.isAfter(cutoffDate);
    }).toList();

    if (filtered.length < 2) {
      filtered = transactions.where((tx) {
        if (tx.type != targetType) return false;
        if (tx.amount <= 0) return false;
        if (normalizedCategory != null && normalizedCategory.isNotEmpty) {
          if (tx.category.trim().toLowerCase() != normalizedCategory) return false;
        }
        return true;
      }).toList();
    }

    if (filtered.isEmpty) return const [];

    final Map<double, int> countMap = {};
    final Map<double, DateTime> latestDateMap = {};

    for (final tx in filtered) {
      final amt = tx.amount;
      countMap[amt] = (countMap[amt] ?? 0) + 1;
      final existingDate = latestDateMap[amt];
      if (existingDate == null || tx.date.isAfter(existingDate)) {
        latestDateMap[amt] = tx.date;
      }
    }

    final distinctAmounts = countMap.keys.toList();
    distinctAmounts.sort((a, b) {
      final countCompare = countMap[b]!.compareTo(countMap[a]!);
      if (countCompare != 0) return countCompare;
      return latestDateMap[b]!.compareTo(latestDateMap[a]!);
    });

    return distinctAmounts.take(maxResults).toList();
  }
}
