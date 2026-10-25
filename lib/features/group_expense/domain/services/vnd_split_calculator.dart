/// Bộ tính toán phân chia chi phí nguyên đồng VND (VND Integer Split Calculator)
/// Tuân thủ nguyên tắc Bất biến GRP-I1: Tính Nguyên Đồng VND (VND Integer Indivisibility)
/// Tổng các phần chia lẻ của tất cả người tham gia phải bằng chính xác 100% tổng khoản chi.
class VndSplitCalculator {
  /// 1. Chia đều nguyên đồng (Deterministic Equal Split Algorithm)
  static Map<String, int> calculateEqualSplit({
    required int totalAmountVnd,
    required List<String> participantIds,
    required String payerId,
  }) {
    if (participantIds.isEmpty) {
      throw ArgumentError('Danh sách người tham gia không được rỗng');
    }
    if (totalAmountVnd <= 0) {
      throw ArgumentError('Tổng số tiền chi tiêu phải lớn hơn 0 đồng');
    }

    final n = participantIds.length;
    final baseShare = totalAmountVnd ~/ n; // Phép chia nguyên ~/
    final remainder = totalAmountVnd % n; // Phần dư R đồng (0 <= remainder < n)

    // Sắp xếp danh sách người tham gia một cách tất định
    final sortedParticipants = List<String>.from(participantIds)..sort();

    // Đưa payerId lên đầu ưu tiên (nếu có tham gia)
    if (sortedParticipants.contains(payerId)) {
      sortedParticipants.remove(payerId);
      sortedParticipants.insert(0, payerId);
    }

    final resultMap = <String, int>{};
    for (int i = 0; i < sortedParticipants.length; i++) {
      final userId = sortedParticipants[i];
      // R người đầu tiên gánh thêm 1 đồng lẻ
      if (i < remainder) {
        resultMap[userId] = baseShare + 1;
      } else {
        resultMap[userId] = baseShare;
      }
    }

    // Bất biến xác minh trước khi trả về
    assert(
      resultMap.values.fold<int>(0, (sum, val) => sum + val) == totalAmountVnd,
      'Bất biến vi phạm: Tổng các phần chia không bằng tổng chi tiêu!',
    );

    return resultMap;
  }

  /// 2. Chia theo Tỷ lệ % (Percentage Split - Largest Remainder Method)
  static Map<String, int> calculatePercentageSplit({
    required int totalAmountVnd,
    required Map<String, double> percentages,
    required String payerId,
  }) {
    if (percentages.isEmpty) {
      throw ArgumentError('Danh sách tỷ lệ phần trăm không được rỗng');
    }
    if (totalAmountVnd <= 0) {
      throw ArgumentError('Tổng số tiền chi tiêu phải lớn hơn 0 đồng');
    }

    final totalPercent = percentages.values.fold<double>(
      0.0,
      (sum, val) => sum + val,
    );
    if ((totalPercent - 100.0).abs() > 0.01) {
      throw ArgumentError(
        'Tổng tỷ lệ phần trăm phải bằng 100% (Hiện tại: $totalPercent%)',
      );
    }

    final baseShares = <String, int>{};
    final fractions = <String, double>{};
    int sumBase = 0;

    for (final entry in percentages.entries) {
      final exactShare = (totalAmountVnd * entry.value) / 100.0;
      final base = exactShare.floor();
      baseShares[entry.key] = base;
      fractions[entry.key] = exactShare - base;
      sumBase += base;
    }

    final remainder = totalAmountVnd - sumBase;

    // Sắp xếp các thành viên theo phần dư thập phân giảm dần.
    // Tie-break: payerId ưu tiên, sau đó theo thứ tự userId tăng dần.
    final sortedKeys = percentages.keys.toList()
      ..sort((a, b) {
        final diff = (fractions[b] ?? 0).compareTo(fractions[a] ?? 0);
        if (diff != 0) return diff;
        if (a == payerId) return -1;
        if (b == payerId) return 1;
        return a.compareTo(b);
      });

    final resultMap = Map<String, int>.from(baseShares);
    for (int i = 0; i < remainder && i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      resultMap[key] = (resultMap[key] ?? 0) + 1;
    }

    assert(
      resultMap.values.fold<int>(0, (sum, val) => sum + val) == totalAmountVnd,
      'Bất biến vi phạm: Tổng các phần chia không bằng tổng chi tiêu!',
    );

    return resultMap;
  }

  /// 3. Chia theo Tỷ phần / Số phần (Shares/Ratio Split)
  static Map<String, int> calculateSharesSplit({
    required int totalAmountVnd,
    required Map<String, int> shares,
    required String payerId,
  }) {
    if (shares.isEmpty) {
      throw ArgumentError('Danh sách số phần không được rỗng');
    }
    if (totalAmountVnd <= 0) {
      throw ArgumentError('Tổng số tiền chi tiêu phải lớn hơn 0 đồng');
    }

    final totalShares = shares.values.fold<int>(0, (sum, val) => sum + val);
    if (totalShares <= 0) {
      throw ArgumentError('Tổng số phần chia phải lớn hơn 0');
    }

    final baseShares = <String, int>{};
    final fractions = <String, double>{};
    int sumBase = 0;

    for (final entry in shares.entries) {
      final exactShare = (totalAmountVnd * entry.value) / totalShares;
      final base = exactShare.floor();
      baseShares[entry.key] = base;
      fractions[entry.key] = exactShare - base;
      sumBase += base;
    }

    final remainder = totalAmountVnd - sumBase;

    final sortedKeys = shares.keys.toList()
      ..sort((a, b) {
        final diff = (fractions[b] ?? 0).compareTo(fractions[a] ?? 0);
        if (diff != 0) return diff;
        if (a == payerId) return -1;
        if (b == payerId) return 1;
        return a.compareTo(b);
      });

    final resultMap = Map<String, int>.from(baseShares);
    for (int i = 0; i < remainder && i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      resultMap[key] = (resultMap[key] ?? 0) + 1;
    }

    assert(
      resultMap.values.fold<int>(0, (sum, val) => sum + val) == totalAmountVnd,
      'Bất biến vi phạm: Tổng các phần chia không bằng tổng chi tiêu!',
    );

    return resultMap;
  }

  /// 4. Chia theo Số tiền chỉ định chính xác (Exact Split)
  static Map<String, int> calculateExactSplit({
    required int totalAmountVnd,
    required Map<String, int> exactAmounts,
  }) {
    final sum = exactAmounts.values.fold<int>(0, (s, v) => s + v);
    if (sum != totalAmountVnd) {
      throw ArgumentError(
        'Tổng số tiền chia lẻ ($sum ₫) không khớp với tổng hóa đơn ($totalAmountVnd ₫)',
      );
    }
    return Map<String, int>.from(exactAmounts);
  }
}
