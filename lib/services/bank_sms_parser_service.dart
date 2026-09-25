import '../utils/category_utils.dart';

typedef BankSmsParseResult = BankParsedTransaction;

class BankParsedTransaction {
  final bool isIncome;
  final double amount;
  final String bankName;
  final String description;
  final String suggestedCategory;
  final int categoryIconCode;
  final double? balanceAfter;
  final String rawMessage;

  BankParsedTransaction({
    required this.isIncome,
    required this.amount,
    required this.bankName,
    required this.description,
    required this.suggestedCategory,
    required this.categoryIconCode,
    this.balanceAfter,
    required this.rawMessage,
  });

  String get type => isIncome ? 'income' : 'expense';
  String get category => suggestedCategory;
  double? get newBalance => balanceAfter;
  DateTime? get transactionDate => DateTime.now();

  Map<String, dynamic> toMap() => {
    'type': isIncome ? 'income' : 'expense',
    'amount': amount,
    'walletName': bankName,
    'description': description,
    'category': suggestedCategory,
    'categoryIconCode': categoryIconCode,
    'balanceAfter': balanceAfter,
    'rawMessage': rawMessage,
  };
}

class BankSmsParserService {
  static final BankSmsParserService _instance = BankSmsParserService._internal();
  factory BankSmsParserService() => _instance;
  BankSmsParserService._internal();

  bool isBankSmsOrNotification(String text) => isBankNotification(text);

  /// Kiểm tra xem đoạn văn bản có phải là thông báo biến động số dư / SMS ngân hàng không
  bool isBankNotification(String text) {
    final lower = text.toLowerCase();
    final bankKeywords = [
      'vietcombank', 'vcb', 'techcombank', 'tcb', 'mbbank', 'mb bank', 'mb:',
      'vpbank', 'vpb', 'acb', 'bidv', 'tpbank', 'tpb', 'sacombank', 'stb',
      'vietinbank', 'ctg', 'vib', 'ocb', 'shb', 'hdbank', 'scb', 'msb',
      'seabank', 'bac a bank', 'nam a bank', 'timo', 'cake',
      'momo', 'zalopay', 'viettelpay', 'viettel money', 'vnpay',
      'biến động số dư', 'bien dong so du', 'số dư:', 'so du:',
      'tài khoản:', 'tai khoan:', 'thanh toan thanh cong', 'thanh toán thành công',
      'đã nhận được', 'da nhan duoc', 'nạp tiền thành công', 'nap tien thanh cong',
    ];

    final hasBankName = bankKeywords.any((k) => lower.contains(k));
    final hasAmountPattern = RegExp(r'(?:\+|-)?\s*\d{1,3}(?:[.,]\d{3})+\s*(?:vnd|vnđ|đ|d)?\b', caseSensitive: false).hasMatch(text) ||
        RegExp(r'(?:giao dịch|gd|sd|số tiền|so tien|st:)\s*(?:\+|-)?\s*\d+', caseSensitive: false).hasMatch(text);

    return (hasBankName && hasAmountPattern) ||
        (lower.contains('so du') && lower.contains('vnd')) ||
        (lower.contains('số dư') && lower.contains('đ'));
  }

  /// Phân tích và trích xuất dữ liệu giao dịch từ SMS / thông báo ngân hàng
  BankParsedTransaction? parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final lower = trimmed.toLowerCase();

    // 1. Nhận diện Ngân hàng / Ví điện tử
    String bankName = _detectBankOrWallet(lower);

    // 2. Nhận diện Chiều biến động (Thu hay Chi)
    bool isIncome = false;
    if (lower.contains('nhan duoc') ||
        lower.contains('nhận được') ||
        lower.contains('duoc cong') ||
        lower.contains('được cộng') ||
        lower.contains('cong tien') ||
        lower.contains('cộng tiền') ||
        lower.contains('hoan tien') ||
        lower.contains('hoàn tiền') ||
        lower.contains('tien ve') ||
        lower.contains('tiền về') ||
        lower.contains('nap tien thanh cong') ||
        lower.contains('nạp tiền thành công')) {
      isIncome = true;
    } else if (lower.contains('thanh toan') ||
        lower.contains('thanh toán') ||
        lower.contains('tru tien') ||
        lower.contains('trừ tiền') ||
        lower.contains('chuyen tien') ||
        lower.contains('chuyển tiền') ||
        lower.contains('rut tien') ||
        lower.contains('rút tiền') ||
        lower.contains('mua hang') ||
        lower.contains('mua hàng')) {
      isIncome = false;
    } else if (RegExp(r'\+\s*\d+').hasMatch(trimmed)) {
      isIncome = true;
    } else if (RegExp(r'-\s*\d+').hasMatch(trimmed)) {
      isIncome = false;
    }

    // 3. Trích xuất Số tiền giao dịch
    double amount = 0.0;
    // Tìm các mẫu số tiền như: +500,000VND, -35.000d, GD: 100.000VND, Số tiền: 200,000 đ
    final amountRegexList = [
      RegExp(r'(?:\+|-)\s*(\d{1,3}(?:[.,]\d{3})+)\s*(?:vnd|vnđ|đ|d)?\b', caseSensitive: false),
      RegExp(r'(?:số tiền|so tien|st|gd|giao dịch|thanh toan|thanh toán)[\s:]*([+-]?\s*\d{1,3}(?:[.,]\d{3})+)\s*(?:vnd|vnđ|đ|d)?\b', caseSensitive: false),
      RegExp(r'(\d{1,3}(?:[.,]\d{3})+)\s*(?:vnd|vnđ|đ)\b', caseSensitive: false),
      RegExp(r'(?:\+|-)\s*(\d+)\s*(?:vnd|vnđ|đ|d)\b', caseSensitive: false),
    ];

    for (final regex in amountRegexList) {
      final match = regex.firstMatch(trimmed);
      if (match != null) {
        String numStr = match.group(1)!
            .replaceAll('+', '')
            .replaceAll('-', '')
            .replaceAll(' ', '')
            .replaceAll('.', '')
            .replaceAll(',', '');
        final val = double.tryParse(numStr);
        if (val != null && val > 0) {
          amount = val;
          // Nếu regex bắt được dấu + hoặc - rõ ràng
          if (match.group(0)!.contains('+')) isIncome = true;
          if (match.group(0)!.contains('-')) isIncome = false;
          break;
        }
      }
    }

    if (amount <= 0) return null;

    // 4. Trích xuất Số dư sau giao dịch (nếu có)
    double? balanceAfter;
    final balanceRegex = RegExp(r'(?:số dư|so du|sd)[\s:]*(\d{1,3}(?:[.,]\d{3})+)\s*(?:vnd|vnđ|đ|d)?\b', caseSensitive: false);
    final balMatch = balanceRegex.firstMatch(trimmed);
    if (balMatch != null) {
      final balStr = balMatch.group(1)!.replaceAll('.', '').replaceAll(',', '').trim();
      balanceAfter = double.tryParse(balStr);
    }

    // 5. Trích xuất Nội dung chi tiêu (ND / Nội dung / Merchant)
    String description = _extractDescription(trimmed, lower, isIncome, bankName);

    // 6. Gán danh mục thông minh (quét cả description và toàn văn SMS)
    String suggestedCategory = _autoCategorize('$description $trimmed', isIncome);
    final iconData = CategoryUtils.getCategoryIcon(suggestedCategory);

    return BankParsedTransaction(
      isIncome: isIncome,
      amount: amount,
      bankName: bankName,
      description: description,
      suggestedCategory: suggestedCategory,
      categoryIconCode: iconData.codePoint,
      balanceAfter: balanceAfter,
      rawMessage: trimmed,
    );
  }

  String _detectBankOrWallet(String lower) {
    if (lower.contains('vietcombank') || lower.contains('vcb')) return 'Vietcombank';
    if (lower.contains('techcombank') || lower.contains('tcb')) return 'Techcombank';
    if (lower.contains('mbbank') || lower.contains('mb bank') || lower.contains('mb:')) return 'MB Bank';
    if (lower.contains('vpbank') || lower.contains('vpb')) return 'VPBank';
    if (lower.contains('acb')) return 'ACB';
    if (lower.contains('bidv')) return 'BIDV';
    if (lower.contains('tpbank') || lower.contains('tpb')) return 'TPBank';
    if (lower.contains('sacombank') || lower.contains('stb')) return 'Sacombank';
    if (lower.contains('vietinbank') || lower.contains('ctg')) return 'VietinBank';
    if (lower.contains('vib')) return 'VIB';
    if (lower.contains('ocb')) return 'OCB';
    if (lower.contains('shb')) return 'SHB';
    if (lower.contains('hdbank') || lower.contains('hdb')) return 'HDBank';
    if (lower.contains('scb')) return 'SCB';
    if (lower.contains('msb')) return 'MSB';
    if (lower.contains('seabank')) return 'SeABank';
    if (lower.contains('timo')) return 'Timo';
    if (lower.contains('cake')) return 'Cake';
    if (lower.contains('momo')) return 'MoMo';
    if (lower.contains('zalopay')) return 'ZaloPay';
    if (lower.contains('viettel money') || lower.contains('viettelpay')) return 'Viettel Money';
    if (lower.contains('vnpay')) return 'VNPay';
    return 'Ngân hàng';
  }

  String _extractDescription(String text, String lower, bool isIncome, String bankName) {
    // Tìm các cụm sau ND: hoặc Nội dung: hoặc Tại (dùng \b để tránh khớp nhầm với đuôi VND)
    final ndRegex = RegExp(r'\b(?:nd|nội dung|noi dung|ly do|lý do|tại|tai)[\s:]+([^\.]+)', caseSensitive: false);
    final match = ndRegex.firstMatch(text);
    if (match != null) {
      String nd = match.group(1)!.trim();
      // Làm sạch các chuỗi thừa
      nd = nd.replaceAll(RegExp(r'\b(ref|mã gd|so du|sd|ref no)\b.*', caseSensitive: false), '').trim();
      if (nd.isNotEmpty && nd.length > 2) {
        if (nd.length > 50) nd = nd.substring(0, 50);
        return nd;
      }
    }

    // Nhận diện theo tên thương hiệu quen thuộc trong câu
    final commonMerchants = [
      'Grab', 'Shopee', 'Lazada', 'TikTok Shop', 'Tiki',
      'Phúc Long', 'Highlands Coffee', 'Katinat', 'Starbucks', 'Gong Cha',
      'The Coffee House', 'Mixue', 'Lotteria', 'KFC', 'Jollibee',
      'Circle K', 'GS25', 'FamilyMart', 'WinMart', 'Co.opmart', 'Bách Hóa Xanh',
      'Pharmacity', 'Long Châu', 'An Khang', 'CGV', 'Lotte Cinema',
      'Netflix', 'Spotify', 'Apple', 'Google', 'EVN', 'Petrolimex',
    ];

    for (var m in commonMerchants) {
      if (lower.contains(m.toLowerCase())) {
        return m;
      }
    }

    if (isIncome) {
      return 'Tiền vào tài khoản $bankName';
    } else {
      return 'Thanh toán qua $bankName';
    }
  }

  String _autoCategorize(String desc, bool isIncome) {
    if (isIncome) {
      final lower = desc.toLowerCase();
      if (lower.contains('luong') || lower.contains('lương') || lower.contains('salary')) return 'Tiền lương';
      if (lower.contains('thuong') || lower.contains('thưởng') || lower.contains('bonus')) return 'Tiền thưởng';
      if (lower.contains('lai') || lower.contains('lãi') || lower.contains('interest')) return 'Tiền lãi';
      if (lower.contains('cho') || lower.contains('tang') || lower.contains('tặng')) return 'Được cho/Tặng';
      if (lower.contains('hoan') || lower.contains('hoàn') || lower.contains('refund')) return 'Hoàn tiền';
      return 'Thu khác';
    }

    final lower = desc.toLowerCase();

    // Ăn uống
    if (lower.contains('coffee') || lower.contains('cà phê') || lower.contains('tra sua') || lower.contains('trà sữa') ||
        lower.contains('bun') || lower.contains('bún') || lower.contains('pho') || lower.contains('phở') ||
        lower.contains('com') || lower.contains('cơm') || lower.contains('pizza') || lower.contains('kfc') ||
        lower.contains('lotteria') || lower.contains('jollibee') || lower.contains('phúc long') ||
        lower.contains('highlands') || lower.contains('katinat') || lower.contains('starbucks') ||
        lower.contains('grabfood') || lower.contains('shopeefood') || lower.contains('food') ||
        lower.contains('nha hang') || lower.contains('nhà hàng') || lower.contains('quan an') || lower.contains('quán ăn')) {
      return 'Ăn uống';
    }

    // Di chuyển
    if (lower.contains('grab') || lower.contains('be') || lower.contains('xanh sm') || lower.contains('gojek') ||
        lower.contains('xang') || lower.contains('xăng') || lower.contains('petrolimex') ||
        lower.contains('gui xe') || lower.contains('gửi xe') || lower.contains('ve xe') || lower.contains('vé xe') ||
        lower.contains('taxi') || lower.contains('vietnam airlines') || lower.contains('vietjet') || lower.contains('ve may bay')) {
      return 'Di chuyển';
    }

    // Mua sắm
    if (lower.contains('shopee') || lower.contains('lazada') || lower.contains('tiki') || lower.contains('tiktok') ||
        lower.contains('zara') || lower.contains('uniqlo') || lower.contains('circle k') || lower.contains('gs25') ||
        lower.contains('familymart') || lower.contains('winmart') || lower.contains('bach hoa xanh') || lower.contains('bách hóa xanh') ||
        lower.contains('sieu thi') || lower.contains('siêu thị') || lower.contains('co.op') || lower.contains('mua sam') || lower.contains('mua sắm')) {
      return 'Mua sắm';
    }

    // Hóa đơn & Tiện ích
    if (lower.contains('evn') || lower.contains('tien dien') || lower.contains('tiền điện') ||
        lower.contains('tien nuoc') || lower.contains('tiền nước') || lower.contains('internet') ||
        lower.contains('fpt') || lower.contains('viettel') || lower.contains('vnpt') || lower.contains('nap dt') || lower.contains('nạp đt')) {
      return 'Tiền điện';
    }

    // Sức khỏe
    if (lower.contains('pharmacity') || lower.contains('long chau') || lower.contains('long châu') ||
        lower.contains('an khang') || lower.contains('thuoc') || lower.contains('thuốc') ||
        lower.contains('benh vien') || lower.contains('bệnh viện') || lower.contains('phong kham') || lower.contains('phòng khám')) {
      return 'Sức khỏe';
    }

    // Giải trí
    if (lower.contains('cgv') || lower.contains('lotte') || lower.contains('cinema') || lower.contains('phim') ||
        lower.contains('netflix') || lower.contains('spotify') || lower.contains('youtube') ||
        lower.contains('game') || lower.contains('steam') || lower.contains('billiards')) {
      return 'Giải trí';
    }

    // Nhà cửa
    if (lower.contains('tien phong') || lower.contains('tiền phòng') || lower.contains('tien nha') || lower.contains('tiền nhà')) {
      return 'Tiền nhà';
    }

    return 'Chi khác';
  }
}
