import '../utils/currency_format_utils.dart';

/// Chi tiết phần tiền của từng người trong hóa đơn
class SplitMemberShare {
  final String name;
  final double amount;
  final bool isPayer;
  final String? note;

  const SplitMemberShare({
    required this.name,
    required this.amount,
    this.isPayer = false,
    this.note,
  });
}

/// Kết quả phân tích và chia tiền hóa đơn
class GroupBillSplitResult {
  final String title;
  final double totalAmount;
  final String payerName;
  final int memberCount;
  final double perPersonAmount;
  final double remainderAmount;
  final List<SplitMemberShare> members;
  final String shareSummaryText;

  const GroupBillSplitResult({
    required this.title,
    required this.totalAmount,
    required this.payerName,
    required this.memberCount,
    required this.perPersonAmount,
    required this.remainderAmount,
    required this.members,
    required this.shareSummaryText,
  });
}

/// Dịch vụ tính toán và chia tiền hóa đơn nhóm thông minh
class GroupBillSplitService {
  static final GroupBillSplitService _instance = GroupBillSplitService._internal();
  factory GroupBillSplitService() => _instance;
  GroupBillSplitService._internal();

  /// Phân tích văn bản tự nhiên để trích xuất hóa đơn và danh sách người chia tiền
  /// Ví dụ:
  /// - "Chia 600k cho 4 người: An, Bình, Chi, Dũng"
  /// - "Chia tiền ăn lẩu 1tr2 cho 3 người gồm tôi, Mai, Hùng"
  /// - "Chia đều 450k cho 3 người"
  GroupBillSplitResult parseAndSplit(String text) {
    final clean = text.trim();

    // 1. Trích xuất số tiền
    final amount = _extractAmount(clean);

    // 2. Trích xuất tiêu đề hóa đơn (ví dụ: ăn lẩu, cafe, karaoke)
    final title = _extractTitle(clean);

    // 3. Trích xuất danh sách tên thành viên
    final membersNames = _extractMembers(clean);

    // 4. Trích xuất người trả tiền trước
    final payer = _extractPayer(clean);

    // Tính toán chia tiền
    return calculateSplit(
      totalAmount: amount > 0 ? amount : 100000,
      memberNames: membersNames,
      payerName: payer,
      title: title,
    );
  }

  /// Tính toán chia tiền theo thông số cụ thể
  GroupBillSplitResult calculateSplit({
    required double totalAmount,
    required List<String> memberNames,
    String payerName = 'Bạn',
    String title = 'Hóa đơn nhóm',
  }) {
    List<String> names = List.from(memberNames);
    if (names.isEmpty) {
      names = ['Bạn', 'Người 1', 'Người 2'];
    }

    String effectivePayer = payerName;
    if (!names.any((n) => n.toLowerCase() == payerName.toLowerCase())) {
      if (payerName == 'Bạn') {
        effectivePayer = names.first;
      } else {
        names.insert(0, payerName);
      }
    }

    final count = names.length;
    // Làm tròn đến nghìn đồng (1.000đ) theo tập quán VN
    final exactPerPerson = totalAmount / count;
    final roundedPerPerson = (exactPerPerson / 1000).ceil() * 1000.0;
    final totalRounded = roundedPerPerson * count;
    final remainder = totalRounded - totalAmount;

    final members = names.map((name) {
      final isPayer = name.toLowerCase() == effectivePayer.toLowerCase();
      return SplitMemberShare(
        name: name,
        amount: roundedPerPerson,
        isPayer: isPayer,
        note: isPayer ? 'Đã thanh toán trước' : 'Cần gửi lại ${CurrencyUtils.formatCurrency(roundedPerPerson)}',
      );
    }).toList();

    // Soạn tin nhắn chia sẻ mẫu cực kỳ lịch sự, văn minh gửi qua Zalo/Mess
    final summaryBuffer = StringBuffer();
    summaryBuffer.writeln('🧾 **CHI TIẾT CHIA TIỀN: $title**');
    summaryBuffer.writeln('• Tổng hóa đơn: **${CurrencyUtils.formatCurrency(totalAmount)}**');
    summaryBuffer.writeln('• Người thanh toán trước: **$effectivePayer**');
    summaryBuffer.writeln('• Số người: **$count người**');
    summaryBuffer.writeln('• Mỗi người: **${CurrencyUtils.formatCurrency(roundedPerPerson)}**');
    summaryBuffer.writeln('─────────────────');
    summaryBuffer.writeln('Danh sách cần gửi:');
    for (final m in members) {
      if (m.isPayer) {
        summaryBuffer.writeln('• ${m.name}: Đã trả toàn bộ (${CurrencyUtils.formatCurrency(totalAmount)})');
      } else {
        summaryBuffer.writeln('• ${m.name}: ${CurrencyUtils.formatCurrency(m.amount)}');
      }
    }
    summaryBuffer.writeln('\n💡 *Bạn có thể sao chép nội dung này gửi vào nhóm Zalo/Messenger nhé!*');

    return GroupBillSplitResult(
      title: title,
      totalAmount: totalAmount,
      payerName: effectivePayer,
      memberCount: count,
      perPersonAmount: roundedPerPerson,
      remainderAmount: remainder,
      members: members,
      shareSummaryText: summaryBuffer.toString(),
    );
  }

  double _extractAmount(String text) {
    // 600k, 600.000, 1tr2, 1.5 triệu, 500k
    final trMatch = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:tr|triệu|trieu)\s*(\d+)?', caseSensitive: false).firstMatch(text);
    if (trMatch != null) {
      final mainPart = double.tryParse(trMatch.group(1)!.replaceAll(',', '.')) ?? 0;
      final subPart = trMatch.group(2) != null ? (double.tryParse(trMatch.group(2)!) ?? 0) : 0;
      if (subPart > 0) {
        return mainPart * 1000000 + subPart * 100000;
      }
      return mainPart * 1000000;
    }

    final kMatch = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:k|nghìn|ngàn|nghin)', caseSensitive: false).firstMatch(text);
    if (kMatch != null) {
      final val = double.tryParse(kMatch.group(1)!.replaceAll(',', '.')) ?? 0;
      return val * 1000;
    }

    final numMatch = RegExp(r'(\d{1,3}(?:[.,]\d{3})+|\d{4,})').firstMatch(text);
    if (numMatch != null) {
      final raw = numMatch.group(1)!.replaceAll(RegExp(r'[.,]'), '');
      return double.tryParse(raw) ?? 0;
    }

    return 0;
  }

  String _extractTitle(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('ăn lẩu') || lower.contains('lẩu')) return 'Ăn lẩu';
    if (lower.contains('tiền ăn') || lower.contains('ăn uống') || lower.contains('ăn trưa') || lower.contains('ăn tối')) {
      return 'Bữa ăn chung';
    }
    if (lower.contains('cafe') || lower.contains('cà phê') || lower.contains('trà sữa')) return 'Đi cafe';
    if (lower.contains('karaoke') || lower.contains('hát')) return 'Karaoke';
    if (lower.contains('du lịch') || lower.contains('đi chơi')) return 'Chuyến đi chơi';
    if (lower.contains('tiền phòng') || lower.contains('tiền nhà') || lower.contains('tiền điện')) return 'Hóa đơn sinh hoạt';
    return 'Hóa đơn nhóm';
  }

  List<String> _extractMembers(String text) {
    final members = <String>[];

    // 1. Kiểm tra định dạng có dấu hai chấm: "cho 4 người: An, Bình, Cường, Dũng"
    final colonMatch = RegExp(r':\s*([^.]+)', caseSensitive: false).firstMatch(text);
    if (colonMatch != null) {
      final rawNames = colonMatch.group(1)!.split(RegExp(r'[,;\n]|(?:\s+và\s+)'));
      for (final n in rawNames) {
        final clean = n.trim();
        if (clean.isNotEmpty && clean.length <= 20) {
          members.add(clean.toLowerCase() == 'tôi' || clean.toLowerCase() == 'mình' ? 'Bạn' : clean);
        }
      }
      if (members.isNotEmpty) return members;
    }

    // 2. Kiểm tra "gồm tôi, Mai, Nam"
    final gomMatch = RegExp(r'gồm\s+([^.]+)', caseSensitive: false).firstMatch(text);
    if (gomMatch != null) {
      final raw = gomMatch.group(1)!;
      final parts = raw.split(RegExp(r'[,;\n]|(?:\s+và\s+)'));
      for (final p in parts) {
        final clean = p.trim();
        if (clean.isNotEmpty && !clean.contains('người') && clean.length <= 20) {
          members.add(clean.toLowerCase() == 'tôi' || clean.toLowerCase() == 'mình' ? 'Bạn' : clean);
        }
      }
      if (members.length >= 2) return members;
    }

    // 3. Kiểm tra "cho N người" -> Tạo danh sách tự động
    final countMatch = RegExp(r'(\d+)\s*người', caseSensitive: false).firstMatch(text);
    if (countMatch != null) {
      final count = int.tryParse(countMatch.group(1)!) ?? 3;
      members.add('Bạn');
      for (int i = 1; i < count && i < 15; i++) {
        members.add('Người $i');
      }
      return members;
    }

    return ['Bạn', 'Người 1', 'Người 2'];
  }

  String _extractPayer(String text) {
    final lower = text.toLowerCase();
    final payerMatch = RegExp(r'(?:do|người trả|bởi)\s+([a-zA-ZÀ-ỹ\s]+)', caseSensitive: false).firstMatch(lower);
    if (payerMatch != null) {
      final name = payerMatch.group(1)!.trim();
      if (name.isNotEmpty && name.length <= 20) {
        return name[0].toUpperCase() + name.substring(1);
      }
    }
    return 'Bạn';
  }
}
