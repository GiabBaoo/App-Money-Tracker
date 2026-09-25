import 'dart:async';
import '../data/repositories/transaction_repository.dart';
import '../utils/category_utils.dart';

/// Kết quả phân loại thông minh
class SmartCategoryResult {
  final String category;
  final int iconCode;
  final double confidence; // 0.0 -> 1.0
  final String matchedReason;

  const SmartCategoryResult({
    required this.category,
    required this.iconCode,
    required this.confidence,
    required this.matchedReason,
  });
}

/// Dịch vụ tự động phân loại giao dịch thông minh (Local-first & User-habit aware)
class SmartCategoryService {
  static final SmartCategoryService _instance = SmartCategoryService._internal();
  factory SmartCategoryService() => _instance;
  SmartCategoryService._internal();

  final TransactionRepository _txRepo = TransactionRepository();

  // Cache lịch sử gán danh mục từ người dùng (keyword -> category)
  final Map<String, String> _userHistoryRules = {};
  DateTime? _lastHistoryLoaded;

  // Từ điển thương hiệu, ứng dụng và dịch vụ phổ biến tại Việt Nam
  static final Map<String, List<String>> _brandDictionary = {
    'Ăn uống': [
      'phúc long', 'phuclong', 'highlands', 'the coffee house', 'starbucks', 'katinat',
      'chagee', 'koi thé', 'gong cha', 'tocotoco', 'mixue', 'cheese coffee', 'aha cafe',
      'cộng cà phê', 'cong ca phe', 'trung nguyên', 'trung nguyen', 'kfc', 'lotteria',
      'jollibee', 'mcdonald', 'pizza hut', 'domino', 'the pizza company', 'haidilao',
      'manwah', 'kichi kichi', 'gogi', 'sumobbq', 'dookki', 'golden gate', 'redsun',
      'baemin', 'shopeefood', 'grabfood', 'beamin', 'loship', 'quán cơm', 'phở', 'bún bò',
      'hủ tiếu', 'bánh mì', 'trà sữa', 'cà phê', 'cafe', 'ăn sáng', 'ăn trưa', 'ăn tối',
      'nhậu', 'lẩu', 'nướng', 'bbq', 'buffet', 'bánh tráng', 'cơm tấm'
    ],
    'Di chuyển': [
      'grab', 'grab bike', 'grab car', 'be bike', 'be car', 'be ride', 'xanh sm', 'xanhsm',
      'vinfast', 'gojek', 'mai linh', 'vina sun', 'vinasun', 'taxi', 'tiền xăng', 'petrolimex',
      'pvoil', 'gửi xe', 'vé xe', 'xe bus', 'xe buýt', 'vé tàu', 'vé máy bay', 'vietjet',
      'vietnam airlines', 'bamboo airways', 'phí cầu đường', 'epass', 'etc', 'vetc'
    ],
    'Mua sắm': [
      'shopee', 'lazada', 'tiki', 'tiktok shop', 'sendo', 'uniqlo', 'zara', 'h&m',
      'yame', 'routine', 'coolmate', 'canifa', 'winmart', 'coopmart', 'co.opmart',
      'bách hóa xanh', 'bachhoaxanh', 'lotte mart', 'aeon', 'aeon mall', 'big c', 'tops market',
      'mega market', 'circle k', '7-eleven', 'familymart', 'ministop', 'gs25', 'chợ'
    ],
    'Đồ công nghệ': [
      'thế giới di động', 'tgdd', 'dienmayxanh', 'điện máy xanh', 'fpt shop', 'fptshop',
      'cellphones', 'viettel store', 'hoanghamobile', 'hoàng hà mobile', 'gearvn',
      'an phát', 'phong vũ', 'apple', 'samsung', 'xiaomi', 'tai nghe', 'bàn phím', 'chuột máy tính'
    ],
    'Sức khỏe': [
      'pharmacity', 'long châu', 'nhà thuốc long châu', 'an khang', 'nhà thuốc',
      'bệnh viện', 'khám bệnh', 'bác sĩ', 'thuốc', 'xét nghiệm', 'nha khoa', 'răng hàm mặt',
      'phòng khám', 'tiêm chủng', 'vnvc'
    ],
    'Làm đẹp': [
      'hasaki', 'guardian', 'watsons', 'cắt tóc', 'barber', 'salon', 'spa', 'nail',
      'mỹ phẩm', 'son môi', 'chăm sóc da', 'gội đầu', 'massage'
    ],
    'Giải trí': [
      'cgv', 'bhd', 'lotte cinema', 'galaxy cinema', 'cinema', 'rạp phim', 'netflix',
      'spotify', 'youtube premium', 'apple music', 'steam', 'playstation', 'nintendo',
      'garena', 'nạp game', 'bida', 'karaoke', 'bowling', 'pub', 'bar', 'board game'
    ],
    'Học tập': [
      'học phí', 'khóa học', 'mua sách', 'nhà sách', 'fahasa', 'tiền học', 'tiếng anh',
      'ielts', 'toeic', 'udemy', 'coursera', 'văn phòng phẩm'
    ],
    'Tiền điện': [
      'tiền điện', 'evn', 'điện lực', 'hóa đơn điện', 'npc', 'cpc', 'spc'
    ],
    'Điện thoại': [
      'tiền mạng', 'internet', 'fpt telecom', 'viettel telecom', 'vnpt', 'nạp card',
      'nạp tiền điện thoại', 'gói cước 4g', '4g viettel', '4g vinaphone', '4g mobifone'
    ],
    'Tiền nhà': [
      'tiền phòng', 'tiền trọ', 'tiền thuê nhà', 'tiền nhà', 'phí quản lý chung cư', 'tiền nước'
    ],
    'Thể thao': [
      'gym', 'fitness', 'california fitness', 'elite fitness', 'yoga', 'cầu lông',
      'sân bóng', 'đá banh', 'bơi lội', 'chạy bộ', 'quần áo thể thao', 'pickleball'
    ],
    'Thú cưng': [
      'thú cưng', 'chó mèo', 'pet shop', 'thức ăn mèo', 'thức ăn chó', 'pate mèo', 'bác sĩ thú y'
    ],
    'Quà tặng': [
      'mừng cưới', 'đám cưới', 'sinh nhật', 'thôi nôi', 'quà tặng', 'lì xì', 'phong bì'
    ],
    'Tiền lương': [
      'lương', 'salary', 'chuyển lương', 'thanh toán lương', 'tạm ứng lương', 'payroll'
    ],
    'Tiền thưởng': [
      'thưởng', 'bonus', 'thưởng tết', 'thưởng quý', 'thưởng nóng'
    ],
    'Được cho/Tặng': [
      'ba mẹ cho', 'mẹ cho', 'bố cho', 'anh cho', 'chị cho', 'quà tặng từ'
    ],
    'Kinh doanh': [
      'khách hàng thanh toán', 'tiền hàng', 'bán hàng', 'doanh thu', 'tiền cọc'
    ],
  };

  /// Tải lịch sử phân loại cá nhân của người dùng từ 100 giao dịch gần nhất
  Future<void> _ensureHistoryLoaded() async {
    final now = DateTime.now();
    if (_lastHistoryLoaded != null && now.difference(_lastHistoryLoaded!).inMinutes < 15) {
      return;
    }

    try {
      final recentTx = await _txRepo.getAllTransactions(limit: 100);
      _userHistoryRules.clear();

      for (final tx in recentTx) {
        final desc = tx.description.trim().toLowerCase();
        if (desc.isNotEmpty && tx.category.isNotEmpty) {
          // Lưu ánh xạ mô tả -> danh mục người dùng đã chọn
          _userHistoryRules[desc] = tx.category;
          // Lưu thêm các cụm từ ngắn
          final words = desc.split(RegExp(r'\s+'));
          if (words.length >= 2 && words.length <= 4) {
            _userHistoryRules[desc] = tx.category;
          }
        }
      }
      _lastHistoryLoaded = now;
    } catch (_) {}
  }

  /// Phân loại thông minh dựa trên văn bản mô tả / tin nhắn / người nhận
  Future<SmartCategoryResult> predictCategory({
    required String text,
    bool isIncome = false,
  }) async {
    await _ensureHistoryLoaded();

    final cleanText = text.trim().toLowerCase();
    if (cleanText.isEmpty) {
      final defaultCat = isIncome ? 'Thu khác' : 'Ăn uống';
      return SmartCategoryResult(
        category: defaultCat,
        iconCode: CategoryUtils.getCategoryIcon(defaultCat).codePoint,
        confidence: 0.3,
        matchedReason: 'Mặc định',
      );
    }

    // 1. Kiểm tra thói quen người dùng trước (Ưu tiên cao nhất)
    if (_userHistoryRules.containsKey(cleanText)) {
      final cat = _userHistoryRules[cleanText]!;
      return SmartCategoryResult(
        category: cat,
        iconCode: CategoryUtils.getCategoryIcon(cat).codePoint,
        confidence: 0.95,
        matchedReason: 'Dựa trên thói quen ghi chép trước đây của bạn',
      );
    }

    for (final entry in _userHistoryRules.entries) {
      if (entry.key.length >= 4 && cleanText.contains(entry.key)) {
        return SmartCategoryResult(
          category: entry.value,
          iconCode: CategoryUtils.getCategoryIcon(entry.value).codePoint,
          confidence: 0.88,
          matchedReason: 'Học từ mục tương tự bạn từng lưu ("${entry.key}")',
        );
      }
    }

    // 2. Kiểm tra từ điển thương hiệu & dịch vụ Việt Nam
    for (final entry in _brandDictionary.entries) {
      final category = entry.key;
      final keywords = entry.value;

      for (final kw in keywords) {
        if (cleanText.contains(kw)) {
          return SmartCategoryResult(
            category: category,
            iconCode: CategoryUtils.getCategoryIcon(category).codePoint,
            confidence: 0.90,
            matchedReason: 'Nhận diện thương hiệu/dịch vụ "$kw"',
          );
        }
      }
    }

    // 3. Quy tắc ngữ cảnh cơ bản
    if (isIncome) {
      if (cleanText.contains('lương') || cleanText.contains('salary')) {
        return _buildResult('Tiền lương', 0.9, 'Từ khóa nhận diện thu nhập');
      }
      if (cleanText.contains('thưởng') || cleanText.contains('bonus')) {
        return _buildResult('Tiền thưởng', 0.9, 'Từ khóa thưởng');
      }
      if (cleanText.contains('lãi') || cleanText.contains('interest')) {
        return _buildResult('Tiền lãi', 0.85, 'Tiền lãi tiết kiệm/đầu tư');
      }
      return _buildResult('Thu khác', 0.5, 'Thu nhập khác');
    }

    // Mặc định chi tiêu
    return _buildResult('Ăn uống', 0.4, 'Danh mục chi tiêu phổ biến');
  }

  SmartCategoryResult _buildResult(String category, double confidence, String reason) {
    return SmartCategoryResult(
      category: category,
      iconCode: CategoryUtils.getCategoryIcon(category).codePoint,
      confidence: confidence,
      matchedReason: reason,
    );
  }
}
