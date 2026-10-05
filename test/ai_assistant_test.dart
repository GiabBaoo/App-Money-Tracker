import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/services/gemini_ai_service.dart';
import 'package:money_tracker_app/services/ai_action_handler.dart';
import 'package:money_tracker_app/services/voice_service.dart';
import 'package:money_tracker_app/services/local_qwen_service.dart';
import 'package:money_tracker_app/services/ai_config_service.dart';
import 'package:money_tracker_app/services/financial_advisor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Trợ lý Mono - Unit Tests', () {
    final aiService = GeminiAiService();
    final actionHandler = AiActionHandler();
    final voiceService = VoiceService();

    test('Nhận diện câu nói thu nhập có đơn vị đ: "hôm nay được cộng thêm 36đ từ ví mono"', () async {
      final result = await aiService.parseNaturalLanguage('hôm nay được cộng thêm 36đ từ ví mono');
      expect(result.isSuccess, isTrue);
      expect(result.transactions.isNotEmpty, isTrue);
      final tx = result.transactions.first;
      expect(tx.type, equals('income'));
      expect(tx.amount, equals(36.0));
      expect(tx.walletName.toLowerCase(), contains('mo'));
    });

    test('Nhận diện thu nhập: "tài khoản momo mới được cộng 9880đ"', () async {
      final result = await aiService.parseNaturalLanguage('tài khoản momo mới được cộng 9880đ');
      expect(result.isSuccess, isTrue);
      expect(result.transactions.isNotEmpty, isTrue);
      final tx = result.transactions.first;
      expect(tx.type, equals('income'));
      expect(tx.amount, equals(9880.0));
      expect(tx.walletName.toLowerCase(), contains('mo'));
    });

    test('Nhận diện thu nhập có dấu chấm hàng nghìn: "tài khoản momo mới được cộng 9.880 đồng" (không bị 9.88)', () async {
      final result = await aiService.parseNaturalLanguage('tài khoản momo mới được cộng 9.880 đồng');
      expect(result.isSuccess, isTrue);
      expect(result.transactions.isNotEmpty, isTrue);
      final tx = result.transactions.first;
      expect(tx.type, equals('income'));
      expect(tx.amount, equals(9880.0));
      expect(tx.walletName.toLowerCase(), contains('mo'));
    });

    test('Nhận diện thu nhập bằng chữ: "tài khoản momo mới được cộng chín nghìn tám trăm tám mươi đồng"', () async {
      final result = await aiService.parseNaturalLanguage('tài khoản momo mới được cộng chín nghìn tám trăm tám mươi đồng');
      expect(result.isSuccess, isTrue);
      expect(result.transactions.isNotEmpty, isTrue);
      final tx = result.transactions.first;
      expect(tx.type, equals('income'));
      expect(tx.amount, equals(9880.0));
      expect(tx.walletName.toLowerCase(), contains('mo'));
    });

    test('Nhận diện thu nhập dấu chấm hàng nghìn: "ví momo vừa được cộng 50.000đ"', () async {
      final result = await aiService.parseNaturalLanguage('ví momo vừa được cộng 50.000đ');
      expect(result.isSuccess, isTrue);
      expect(result.transactions.isNotEmpty, isTrue);
      final tx = result.transactions.first;
      expect(tx.type, equals('income'));
      expect(tx.amount, equals(50000.0));
      expect(tx.walletName.toLowerCase(), contains('mo'));
    });

    test('VoiceService.parseVoiceCommand nhận diện đúng thu nhập ví MoMo: "tài khoản momo mới được cộng 9.880 đồng"', () {
      final res = voiceService.parseVoiceCommand('tài khoản momo mới được cộng 9.880 đồng');
      expect(res, isNotNull);
      expect(res!['type'], equals('income'));
      expect(res['amount'], equals(9880.0));
      expect(res['walletName'], equals('MoMo'));
    });

    test('VoiceService.parseVoiceCommand nhận diện số chữ: "tài khoản momo mới được cộng chín nghìn tám trăm tám mươi đồng"', () {
      final res = voiceService.parseVoiceCommand('tài khoản momo mới được cộng chín nghìn tám trăm tám mươi đồng');
      expect(res, isNotNull);
      expect(res!['type'], equals('income'));
      expect(res['amount'], equals(9880.0));
      expect(res['walletName'], equals('MoMo'));
    });

    test('Nhận diện số hỗn hợp kèm biến thể phát âm STT: "mới được nhận 9 nghìn 8 trắm 8 mưới đồng vào ví momo"', () async {
      // 1. Kiểm tra qua VoiceService offline parser
      final voiceRes = voiceService.parseVoiceCommand('mới được nhận 9 nghìn 8 trắm 8 mưới đồng vào ví momo');
      expect(voiceRes, isNotNull);
      expect(voiceRes!['type'], equals('income'));
      expect(voiceRes['amount'], equals(9880.0));
      expect(voiceRes['walletName'], equals('MoMo'));

      // 2. Kiểm tra qua GeminiAiService NL parser
      final aiRes = await aiService.parseNaturalLanguage('mới được nhận 9 nghìn 8 trắm 8 mưới đồng vào ví momo');
      expect(aiRes.isSuccess, isTrue);
      expect(aiRes.transactions.isNotEmpty, isTrue);
      final tx = aiRes.transactions.first;
      expect(tx.type, equals('income'));
      expect(tx.amount, equals(9880.0));
      expect(tx.walletName, equals('MoMo'));
    });

    test('Nhận diện kết quả Google STT tự động format có dấu + và ₫: "+9880₫ và Ví MoMo"', () async {
      // 1. Kiểm tra qua VoiceService offline parser
      final voiceRes = voiceService.parseVoiceCommand('+9880₫ và Ví MoMo');
      expect(voiceRes, isNotNull);
      expect(voiceRes!['type'], equals('income'));
      expect(voiceRes['amount'], equals(9880.0));
      expect(voiceRes['walletName'], equals('MoMo'));

      // 2. Kiểm tra qua GeminiAiService NL parser (Fast / fallback)
      final aiRes = await aiService.parseNaturalLanguage('+9880₫ và Ví MoMo');
      expect(aiRes.isSuccess, isTrue);
      expect(aiRes.transactions.isNotEmpty, isTrue);
      final tx = aiRes.transactions.first;
      expect(tx.type, equals('income'));
      expect(tx.amount, equals(9880.0));
      expect(tx.walletName, equals('MoMo'));
      expect(aiRes.aiReply, contains('cộng thêm 9.880đ vào ví MoMo'));
    });

    test('Nhận diện các biến thể định dạng dấu + và -: "+50.000₫ vào ví MoMo", "-35k ví momo"', () async {
      final plusRes = await aiService.parseNaturalLanguage('+50.000₫ vào ví MoMo');
      expect(plusRes.isSuccess, isTrue);
      expect(plusRes.transactions.first.type, equals('income'));
      expect(plusRes.transactions.first.amount, equals(50000.0));
      expect(plusRes.transactions.first.walletName, equals('MoMo'));

      final minusRes = await aiService.parseNaturalLanguage('-35k ví momo');
      expect(minusRes.isSuccess, isTrue);
      expect(minusRes.transactions.first.type, equals('expense'));
      expect(minusRes.transactions.first.amount, equals(35000.0));
      expect(minusRes.transactions.first.walletName, equals('MoMo'));
    });

    test('Nhận diện câu nói thiếu số tiền: "mới đi ăn bún bò trả bằng ví momo"', () async {
      final result = await aiService.parseNaturalLanguage('mới đi ăn bún bò trả bằng ví momo');
      expect(result.isSuccess, isTrue);
      expect(result.needsAmount, isTrue);
      expect(result.transactions.isNotEmpty, isTrue);
      final tx = result.transactions.first;
      expect(tx.type, equals('expense'));
      expect(tx.category, equals('Ăn uống'));
      expect(tx.walletName, equals('MoMo'));
    });

    test('Nhận diện lệnh đổi Theme (Sáng / Tối)', () async {
      final darkResult = await aiService.parseNaturalLanguage('chuyển giao diện tối');
      expect(darkResult.actionType, equals(AiActionType.changeTheme));
      expect(darkResult.themeMode, equals('dark'));

      final lightResult = await aiService.parseNaturalLanguage('bật chế độ sáng');
      expect(lightResult.actionType, equals(AiActionType.changeTheme));
      expect(lightResult.themeMode, equals('light'));
    });

    test('Nhận diện lệnh đổi ngôn ngữ (Tiếng Anh / Tiếng Việt)', () async {
      final enResult = await aiService.parseNaturalLanguage('chuyển sang tiếng anh');
      expect(enResult.actionType, equals(AiActionType.changeLanguage));
      expect(enResult.language, equals('en'));

      final viResult = await aiService.parseNaturalLanguage('đổi tiếng việt');
      expect(viResult.actionType, equals(AiActionType.changeLanguage));
      expect(viResult.language, equals('vi'));
    });

    test('Ranh giới bảo mật & quyền riêng tư - Từ chối can thiệp mật khẩu', () async {
      final secMsg = actionHandler.checkSecurityRestriction('đổi mật khẩu cho tôi');
      expect(secMsg, isNotNull);
      expect(secMsg, contains('mật khẩu'));

      final aiResult = await aiService.parseNaturalLanguage('hãy đổi mật khẩu giúp tôi');
      expect(aiResult.actionType, equals(AiActionType.securityRestricted));
    });

    test('Nhận diện lệnh báo cáo chi tiêu', () async {
      final reportResult = await aiService.parseNaturalLanguage('báo cáo chi tiêu tháng này');
      expect(reportResult.actionType, equals(AiActionType.spendingReport));
      expect(reportResult.reportPeriod, equals('month'));
    });

    test('Điều khiển các màn hình ứng dụng qua lệnh nhanh (Screen Navigation)', () async {
      final statRes = await aiService.parseNaturalLanguage('mở thống kê');
      expect(statRes.actionType, equals(AiActionType.navigateScreen));
      expect(statRes.navigationTarget, equals('statistics'));

      final calRes = await aiService.parseNaturalLanguage('xem lịch thu chi');
      expect(calRes.actionType, equals(AiActionType.navigateScreen));
      expect(calRes.navigationTarget, equals('calendar'));

      final walletRes = await aiService.parseNaturalLanguage('quản lý ví tiền');
      expect(walletRes.actionType, equals(AiActionType.navigateScreen));
      expect(walletRes.navigationTarget, equals('wallets'));

      final groupRes = await aiService.parseNaturalLanguage('chi tiêu nhóm');
      expect(groupRes.actionType, equals(AiActionType.navigateScreen));
      expect(groupRes.navigationTarget, equals('groupExpense'));

      final budgetRes = await aiService.parseNaturalLanguage('mục tiêu tiết kiệm');
      expect(budgetRes.actionType, equals(AiActionType.navigateScreen));
      expect(budgetRes.navigationTarget, equals('budget'));

      final catRes = await aiService.parseNaturalLanguage('danh mục thu chi');
      expect(catRes.actionType, equals(AiActionType.navigateScreen));
      expect(catRes.navigationTarget, equals('category'));

      final reportExportRes = await aiService.parseNaturalLanguage('xuất excel');
      expect(reportExportRes.actionType, equals(AiActionType.navigateScreen));
      expect(reportExportRes.navigationTarget, equals('exportReport'));

      final receiptRes = await aiService.parseNaturalLanguage('thư viện hóa đơn');
      expect(receiptRes.actionType, equals(AiActionType.navigateScreen));
      expect(receiptRes.navigationTarget, equals('receiptGallery'));

      final aiSettingsRes = await aiService.parseNaturalLanguage('cài đặt ai');
      expect(aiSettingsRes.actionType, equals(AiActionType.navigateScreen));
      expect(aiSettingsRes.navigationTarget, equals('aiSettings'));

      final accRes = await aiService.parseNaturalLanguage('thông tin tài khoản');
      expect(accRes.actionType, equals(AiActionType.navigateScreen));
      expect(accRes.navigationTarget, equals('accountInfo'));

      final supportRes = await aiService.parseNaturalLanguage('hỗ trợ khách hàng');
      expect(supportRes.actionType, equals(AiActionType.navigateScreen));
      expect(supportRes.navigationTarget, equals('support'));

      final allTxRes = await aiService.parseNaturalLanguage('tất cả giao dịch');
      expect(allTxRes.actionType, equals(AiActionType.navigateScreen));
      expect(allTxRes.navigationTarget, equals('allTransactions'));
    });

    test('Trò chuyện đơn giản & Chit-Chat thân thiện (Small Talk)', () async {
      final helloRes = await aiService.parseNaturalLanguage('chào mono');
      expect(helloRes.actionType, equals(AiActionType.generalChat));
      expect(helloRes.aiReply.toLowerCase(), contains('chào'));

      final howAreYouRes = await aiService.parseNaturalLanguage('bạn khỏe không');
      expect(howAreYouRes.actionType, equals(AiActionType.generalChat));
      expect(howAreYouRes.aiReply.toLowerCase(), contains('khỏe'));

      final whoAreYouRes = await aiService.parseNaturalLanguage('bạn là ai');
      expect(whoAreYouRes.actionType, equals(AiActionType.generalChat));
      expect(whoAreYouRes.aiReply.toLowerCase(), contains('mono'));

      final thanksRes = await aiService.parseNaturalLanguage('cảm ơn bạn nhé');
      expect(thanksRes.actionType, equals(AiActionType.generalChat));

      final byeRes = await aiService.parseNaturalLanguage('tạm biệt');
      expect(byeRes.actionType, equals(AiActionType.generalChat));
    });

    test('AiActionHandler helper methods trả về đúng tiêu đề và icon', () {
      expect(actionHandler.getScreenTitle('statistics'), contains('Thống kê'));
      expect(actionHandler.getScreenTitle('wallets'), contains('ví'));
      expect(actionHandler.getScreenTitle('budget'), contains('Ngân sách'));
      expect(actionHandler.getScreenIcon('statistics'), isNotNull);
      expect(actionHandler.getScreenIcon('wallets'), isNotNull);
    });

    test('Từ chối các thao tác riêng tư nhạy cảm: xóa tài khoản, sinh trắc học, chuyển tiền', () async {
      final delRes = await aiService.parseNaturalLanguage('xóa tài khoản của tôi');
      expect(delRes.actionType, equals(AiActionType.securityRestricted));

      final bioRes = await aiService.parseNaturalLanguage('tắt vân tay');
      expect(bioRes.actionType, equals(AiActionType.securityRestricted));

      final bankRes = await aiService.parseNaturalLanguage('chuyển tiền cho tài khoản khác');
      expect(bankRes.actionType, equals(AiActionType.securityRestricted));
    });

    test('Xử lý an toàn chuỗi rỗng và khoảng trắng không gây lỗi', () async {
      final emptyRes = await aiService.parseNaturalLanguage('');
      expect(emptyRes.isSuccess, isFalse);

      final spaceRes = await aiService.parseNaturalLanguage('   ');
      expect(spaceRes.isSuccess, isFalse);
    });

    test('Nhận diện yêu cầu tư vấn tài chính & phân bổ 50/30/20 (Financial Advice)', () async {
      final adviceRes1 = await aiService.parseNaturalLanguage('nên làm gì với số tiền còn lại');
      expect(adviceRes1.isSuccess, isTrue);
      expect(adviceRes1.actionType, equals(AiActionType.financialAdvice));
      expect(adviceRes1.aiReply, isNotEmpty);

      final adviceRes2 = await aiService.parseNaturalLanguage('đề xuất phân bổ số tiền còn lại theo 50/30/20');
      expect(adviceRes2.isSuccess, isTrue);
      expect(adviceRes2.actionType, equals(AiActionType.financialAdvice));

      final adviceRes3 = await aiService.parseNaturalLanguage('quy tắc 50 30 20');
      expect(adviceRes3.isSuccess, isTrue);
      expect(adviceRes3.actionType, equals(AiActionType.financialAdvice));
    });

    test('Nhận diện yêu cầu mẹo tiết kiệm chi tiêu (Saving Tips)', () async {
      final tipRes1 = await aiService.parseNaturalLanguage('cho tôi vài tip tiết kiệm');
      expect(tipRes1.isSuccess, isTrue);
      expect(tipRes1.actionType, equals(AiActionType.savingTips));
      expect(tipRes1.aiReply, contains('tiết kiệm'));

      final tipRes2 = await aiService.parseNaturalLanguage('làm sao để tiết kiệm tiền hiệu quả');
      expect(tipRes2.isSuccess, isTrue);
      expect(tipRes2.actionType, equals(AiActionType.savingTips));

      final tipRes3 = await aiService.parseNaturalLanguage('mẹo cắt giảm chi tiêu');
      expect(tipRes3.isSuccess, isTrue);
      expect(tipRes3.actionType, equals(AiActionType.savingTips));
    });

    test('Nhận diện yêu cầu báo cáo chi tiêu tài chính (Spending Report)', () async {
      final repRes1 = await aiService.parseNaturalLanguage('báo cáo chi tiêu tháng này');
      expect(repRes1.isSuccess, isTrue);
      expect(repRes1.actionType, equals(AiActionType.spendingReport));

      final repRes2 = await aiService.parseNaturalLanguage('hôm nay đã tiêu bao nhiêu');
      expect(repRes2.isSuccess, isTrue);
      expect(repRes2.actionType == AiActionType.spendingQuery || repRes2.actionType == AiActionType.spendingReport, isTrue);
    });

    test('Kiểm tra tính toán SpendingReportResult: thặng dư, tỷ lệ chi tiêu, tỷ lệ tiết kiệm', () {
      final reportPositive = SpendingReportResult(
        periodText: 'Tháng 9/2026',
        totalExpense: 6000000.0,
        totalIncome: 10000000.0,
        transactionCount: 5,
        topCategories: {'Ăn uống': 4000000.0, 'Mua sắm': 2000000.0},
        summaryText: 'Chi tiêu tháng này ổn định',
      );
      expect(reportPositive.netBalance, equals(4000000.0));
      expect(reportPositive.expenseRatio, equals(60.0));
      expect(reportPositive.savingsRate, equals(40.0));
      expect(reportPositive.isDeficit, isFalse);

      final reportDeficit = SpendingReportResult(
        periodText: 'Tháng 9/2026',
        totalExpense: 12000000.0,
        totalIncome: 10000000.0,
        transactionCount: 3,
        topCategories: {'Du lịch': 12000000.0},
        summaryText: 'Tháng này thâm hụt ngân sách',
      );
      expect(reportDeficit.netBalance, equals(-2000000.0));
      expect(reportDeficit.isDeficit, isTrue);
      expect(reportDeficit.savingsRate, equals(0.0));
    });

    test('Kiểm tra tính toán FinancialAdviceResult: phân bổ 50/30/20 & số dư khả dụng', () {
      final advice = FinancialAdviceResult(
        title: 'Tư vấn phân bổ tài chính',
        summaryText: 'Bạn đang có số dư 5.000.000đ.',
        totalBalance: 5000000.0,
        needs50: 2500000.0,
        wants30: 1500000.0,
        savings20: 1000000.0,
        actionableTips: ['Đặt hạn mức danh mục', 'Lập quỹ khẩn cấp'],
        targetNavigation: 'budget',
      );
      expect(advice.needs50, equals(2500000.0));
      expect(advice.wants30, equals(1500000.0));
      expect(advice.savings20, equals(1000000.0));
      expect(advice.actionableTips.length, equals(2));
      expect(advice.targetNavigation, equals('budget'));
    });

    test('Quản lý bộ nhớ hội thoại multi-turn (Conversation History)', () {
      aiService.clearHistory();
      expect(aiService.conversationHistory.isEmpty, isTrue);

      aiService.addToHistory('user', 'Chào Mono');
      aiService.addToHistory('model', 'Chào bạn! Tôi có thể giúp gì?');
      expect(aiService.conversationHistory.length, equals(2));
      expect(aiService.conversationHistory.first['role'], equals('user'));
      expect(aiService.conversationHistory.last['text'], contains('Chào bạn'));

      aiService.clearHistory();
      expect(aiService.conversationHistory.isEmpty, isTrue);
    });

    test('FIX LỖI: Nhận diện chính xác "phụng cho 15.000đ vào ví tiền mặt" là KHOẢN THU (income) danh mục Được cho/Tặng', () async {
      // 1. Kiểm tra qua GeminiAiService NL parser
      final aiRes = await aiService.parseNaturalLanguage('phụng cho 15.000đ vào ví tiền mặt');
      expect(aiRes.isSuccess, isTrue);
      expect(aiRes.transactions.isNotEmpty, isTrue);
      final tx = aiRes.transactions.first;
      expect(tx.type, equals('income'), reason: '"phụng cho" phải là khoản thu (income), không được hiểu sai thành expense');
      expect(tx.category, equals('Được cho/Tặng'));
      expect(tx.amount, equals(15000.0));
      expect(tx.description.toLowerCase(), contains('phụng cho'));
      expect(tx.walletName, equals('Tiền mặt'));

      // 2. Kiểm tra qua VoiceService voice command parser
      final voiceRes = voiceService.parseVoiceCommand('phụng cho 15.000đ vào ví tiền mặt');
      expect(voiceRes, isNotNull);
      expect(voiceRes!['type'], equals('income'));
      expect(voiceRes['category'], equals('Được cho/Tặng'));
      expect(voiceRes['amount'], equals(15000.0));
      expect(voiceRes['description'].toString().toLowerCase(), contains('phụng cho'));
      expect(voiceRes['walletName'], equals('Tiền mặt'));
    });

    test('Trợ lý Mono thông minh nhận diện các biến thể người khác cho tiền: "mẹ cho 50k vào ví momo", "bạn cho 100k tiền mặt"', () async {
      // Mẹ cho 50k vào ví MoMo
      final meChoRes = await aiService.parseNaturalLanguage('mẹ cho 50k vào ví momo');
      expect(meChoRes.transactions.isNotEmpty, isTrue);
      expect(meChoRes.transactions.first.type, equals('income'));
      expect(meChoRes.transactions.first.category, equals('Được cho/Tặng'));
      expect(meChoRes.transactions.first.amount, equals(50000.0));
      expect(meChoRes.transactions.first.walletName, equals('MoMo'));

      // Bạn cho 100k tiền mặt
      final banChoRes = await aiService.parseNaturalLanguage('bạn cho 100k tiền mặt');
      expect(banChoRes.transactions.isNotEmpty, isTrue);
      expect(banChoRes.transactions.first.type, equals('income'));
      expect(banChoRes.transactions.first.category, equals('Được cho/Tặng'));
      expect(banChoRes.transactions.first.amount, equals(100000.0));
      expect(banChoRes.transactions.first.walletName, equals('Tiền mặt'));
    });

    test('Phân biệt rõ ràng người khác cho tiền (income) với đem tiền cho/mượn/chi (expense)', () async {
      // Cho bạn mượn -> Khoản chi
      final muonResume = await aiService.parseNaturalLanguage('cho bạn mượn 50k');
      expect(muonResume.transactions.isNotEmpty, isTrue);
      expect(muonResume.transactions.first.type, equals('expense'));

      // Chi cho ăn uống -> Khoản chi
      final chiRes = await aiService.parseNaturalLanguage('chi 50k cho ăn uống');
      expect(chiRes.transactions.isNotEmpty, isTrue);
      expect(chiRes.transactions.first.type, equals('expense'));

      // Bỏ 50k vào ví -> Vẫn giữ nguyên expense theo BUG-07
      final boViRes = await aiService.parseNaturalLanguage('bỏ 50k vào ví');
      expect(boViRes.transactions.isNotEmpty, isTrue);
      expect(boViRes.transactions.first.type, equals('expense'));
    });

    test('Bóc tách thời gian & ngày tháng tiếng Việt chính xác: "hôm qua uống trà sữa 35k lúc 8h30 sáng"', () {
      final dt = voiceService.parseVietnameseDateTime('hôm qua uống trà sữa 35k lúc 8h30 sáng');
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      expect(dt['day'], equals(yesterday.day));
      expect(dt['month'], equals(yesterday.month));
      expect(dt['year'], equals(yesterday.year));
      expect(dt['hour'], equals(8));
      expect(dt['minute'], equals(30));
      expect(dt['time'], equals('08:30'));
    });

    test('Bóc tách buổi trong ngày: "tối qua ăn lẩu 150k" & "trưa nay ăn cơm 40k"', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      final toiQua = voiceService.parseVietnameseDateTime('tối qua ăn lẩu 150k');
      expect(toiQua['day'], equals(yesterday.day));
      expect(toiQua['hour'], equals(19));
      expect(toiQua['minute'], equals(30));

      final truaNay = voiceService.parseVietnameseDateTime('trưa nay ăn cơm 40k');
      expect(truaNay['day'], equals(now.day));
      expect(truaNay['hour'], equals(12));
      expect(truaNay['minute'], equals(0));
    });

    test('VoiceService.parseVoiceCommand nhận diện ngày hôm qua và giờ chính xác', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      final res = voiceService.parseVoiceCommand('hôm qua ăn phở 45k lúc 7 rưỡi');
      expect(res, isNotNull);
      expect(res!['type'], equals('expense'));
      expect(res['amount'], equals(45000.0));
      expect(res['hour'], equals(7));
      expect(res['minute'], equals(30));
      expect(res['time'], equals('07:30'));

      final parsedDate = res['date'] as DateTime;
      expect(parsedDate.day, equals(yesterday.day));
      expect(parsedDate.month, equals(yesterday.month));
      expect(parsedDate.year, equals(yesterday.year));
      expect(parsedDate.hour, equals(7));
      expect(parsedDate.minute, equals(30));
    });

    test('Trợ lý Mono parseNaturalLanguage xử lý chính xác ngày quá khứ "hôm qua mua sách 80k lúc 14h"', () async {
      final res = await aiService.parseNaturalLanguage('hôm qua mua sách 80k lúc 14h');
      expect(res.isSuccess, isTrue);
      expect(res.transactions.isNotEmpty, isTrue);
      final tx = res.transactions.first;

      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      expect(tx.date.day, equals(yesterday.day));
      expect(tx.date.month, equals(yesterday.month));
      expect(tx.date.year, equals(yesterday.year));
      expect(tx.date.hour, equals(14));
      expect(tx.date.minute, equals(0));
    });

    test('Local AI Qwen 2.5: Cấu hình mặc định kích hoạt Local Engine và Qwen 2.5 1.5B', () {
      final config = AiConfigService();
      expect(config.engineMode, equals('local_qwen'));
      expect(config.isLocalAi, isTrue);
      expect(config.localModelName, equals('qwen2.5:1.5b'));
      expect(config.isReady, isTrue);
    });

    test('Local AI Qwen 2.5: LocalQwenService bóc tách giao dịch thu chi ngoại tuyến tức thì', () async {
      final localQwen = LocalQwenService();
      final res = await localQwen.parseNaturalLanguage('hôm nay ăn phở 45k ví MoMo');
      expect(res.isSuccess, isTrue);
      expect(res.transactions.isNotEmpty, isTrue);
      final tx = res.transactions.first;
      expect(tx.type, equals('expense'));
      expect(tx.amount, equals(45000.0));
      expect(tx.walletName, equals('MoMo'));
      expect(tx.category, equals('Ăn uống'));
    });

    test('Local AI Qwen 2.5: LocalQwenService nhận diện đổi giao diện & báo cáo chi tiêu', () async {
      final localQwen = LocalQwenService();

      // Đổi dark mode
      final themeRes = await localQwen.parseNaturalLanguage('chuyển sang giao diện tối');
      expect(themeRes.actionType, equals(AiActionType.changeTheme));
      expect(themeRes.themeMode, equals('dark'));

      // Báo cáo chi tiêu
      final reportRes = await localQwen.parseNaturalLanguage('báo cáo chi tiêu hôm nay');
      expect(reportRes.actionType, equals(AiActionType.spendingReport));
      expect(reportRes.reportPeriod, equals('today'));
    });

    test('Test câu nói thực tế của người dùng: "tôi mới mua bánh mì chả cá 20.000đ"', () async {
      final voiceParsed = VoiceService().parseVoiceCommand('tôi mới mua bánh mì chả cá 20.000đ');
      expect(voiceParsed, isNotNull);
      expect(voiceParsed!['type'], equals('expense'));
      expect(voiceParsed['amount'], equals(20000.0));
      expect(voiceParsed['description'], equals('Bánh mì chả cá'));

      final res = await aiService.parseNaturalLanguage('tôi mới mua bánh mì chả cá 20.000đ');
      expect(res.transactions.isNotEmpty, isTrue);
      expect(res.transactions.first.amount, equals(20000.0));
      expect(res.transactions.first.type, equals('expense'));
      expect(res.transactions.first.description, equals('Bánh mì chả cá'));
    });

    test('Trợ lý Mono: Tra cứu chi tiêu tùy biến thời gian "mức chi tiêu của tôi 3 ngày qua là cho việc nào nhiều nhất"', () async {
      final res = await aiService.parseNaturalLanguage('mức chi tiêu của tôi 3 ngày qua là cho việc nào nhiều nhất');
      expect(res.isSuccess, isTrue);
      expect(res.actionType, equals(AiActionType.spendingQuery));
      expect(res.spendingQueryResult, isNotNull);
      expect(res.spendingQueryResult!.daysCount, equals(3));
      expect(res.spendingQueryResult!.periodDescription, equals('3 ngày qua'));
      expect(res.spendingQueryResult!.answerText.isNotEmpty, isTrue);
    });

    test('Trợ lý Mono: Tư vấn phân bổ tiền lương 50/30/20 "tôi mới nhận lương thì nên chia tiền như thế nào cho hợp lý"', () async {
      final res = await aiService.parseNaturalLanguage('tôi mới nhận lương thì nên chia tiền như thế nào cho hợp lý');
      expect(res.isSuccess, isTrue);
      // Không bị hiểu nhầm thành chia hóa đơn ăn uống nhóm (Group Bill Split)
      expect(res.actionType, isNot(equals(AiActionType.splitBill)));
      expect(res.actionType, equals(AiActionType.financialAdvice));
      expect(res.financialAdvice, isNotNull);
      final advice = res.financialAdvice!;
      expect(advice.title.toLowerCase().contains('lương') || advice.title.contains('50/30/20'), isTrue);
      expect(advice.needs50, greaterThan(0));
      expect(advice.wants30, greaterThan(0));
      expect(advice.savings20, greaterThan(0));
      expect(advice.summaryText.contains('50% Thiết yếu'), isTrue);
      expect(advice.summaryText.contains('30% Linh hoạt'), isTrue);
      expect(advice.summaryText.contains('20% Tiết kiệm'), isTrue);
    });

    test('Trợ lý Mono: Tư vấn phân bổ tiền lương có số tiền cụ thể "tôi mới nhận lương 15tr thì nên chia tiền như thế nào cho hợp lý"', () async {
      final advice = await actionHandler.generateFinancialAdvice(
        specificQuery: 'tôi mới nhận lương 15tr thì nên chia tiền như thế nào cho hợp lý',
      );
      expect(advice.totalBalance, equals(15000000.0));
      expect(advice.needs50, equals(7500000.0));
      expect(advice.wants30, equals(4500000.0));
      expect(advice.savings20, equals(3000000.0));
      expect(advice.summaryText.contains('15.000.000'), isTrue);
      expect(advice.summaryText.contains('7.500.000'), isTrue);
      expect(advice.summaryText.contains('4.500.000'), isTrue);
      expect(advice.summaryText.contains('3.000.000'), isTrue);
    });

    test('FinancialAdvisorService.queryPersonalSpending nhận diện đúng chu kỳ ngày linh hoạt', () async {
      final advisor = FinancialAdvisorService();
      
      final res3Days = await advisor.queryPersonalSpending('chi tiêu 3 ngày qua việc nào nhiều nhất');
      expect(res3Days.daysCount, equals(3));
      expect(res3Days.periodDescription, equals('3 ngày qua'));

      final res5Days = await advisor.queryPersonalSpending('mức tiêu 5 ngày gần đây');
      expect(res5Days.daysCount, equals(5));
      expect(res5Days.periodDescription, equals('5 ngày qua'));

      final res7Days = await advisor.queryPersonalSpending('đã chi những gì trong 7 ngày trước');
      expect(res7Days.daysCount, equals(7));
      expect(res7Days.periodDescription, equals('7 ngày qua'));
    });

    test('Nhận diện chính xác câu nói mua vé xe Phương Trang và thanh toán bằng ví', () async {
      const cmd = 'tôi mới mua vé xe Phương Trang hết 360.000 thanh toán bằng ví';

      // 1. VoiceService
      final voiceRes = voiceService.parseVoiceCommand(cmd);
      expect(voiceRes, isNotNull);
      expect(voiceRes!['amount'], equals(360000.0));
      expect(voiceRes['category'], equals('Di chuyển'));
      expect(voiceRes['type'], equals('expense'));
      expect(voiceRes['description'].toString().toLowerCase(), contains('vé xe phương trang'));
      expect(voiceRes['description'].toString().toLowerCase().contains('thanh toán bằng ví'), isFalse);
      expect(voiceRes['wallet'], isNotEmpty);

      // 2. GeminiAiService
      final aiRes = await aiService.parseNaturalLanguage(cmd);
      expect(aiRes.isSuccess, isTrue);
      expect(aiRes.transactions.isNotEmpty, isTrue);
      final tx = aiRes.transactions.first;
      expect(tx.amount, equals(360000.0));
      expect(tx.category, equals('Di chuyển'));
      expect(tx.type, equals('expense'));
      expect(tx.description.toLowerCase(), contains('vé xe phương trang'));
      expect(tx.description.toLowerCase().contains('thanh toán bằng ví'), isFalse);
    });

    test('Trợ lý Mono: Phân tích JSON có intent TRANSFER_MONEY và bóc tách TransferMoneyData chính xác', () {
      const jsonOutput = '''
      {
        "intent": "TRANSFER_MONEY",
        "actionType": "transferMoney",
        "reply": "✨ Mono đã ghi nhận yêu cầu chuyển tiền từ MoMo sang Techcombank.",
        "transfer": {
          "amount": 500000.0,
          "source_wallet": "MoMo",
          "target_wallet": "Techcombank",
          "fee": 1100.0,
          "note": "Chuyển tiền trả tiền trọ"
        },
        "transactions": []
      }
      ''';

      final res = aiService.parseJsonFromAiTextForTesting(jsonOutput);
      expect(res.isSuccess, isTrue);
      expect(res.actionType, equals(AiActionType.transferMoney));
      expect(res.transferData, isNotNull);
      expect(res.transferData!.amount, equals(500000.0));
      expect(res.transferData!.sourceWalletName, equals('MoMo'));
      expect(res.transferData!.targetWalletName, equals('Techcombank'));
      expect(res.transferData!.fee, equals(1100.0));
      expect(res.transferData!.note, equals('Chuyển tiền trả tiền trọ'));
      expect(res.transactions.isEmpty, isTrue);
    });

    test('Trợ lý Mono: Nhận diện lệnh rút tiền từ ATM về tiền mặt', () async {
      final res = await aiService.parseNaturalLanguage('Rút 2 triệu từ ATM về tiền mặt');
      expect(res.isSuccess, isTrue);
      expect(res.actionType, equals(AiActionType.transferMoney));
      expect(res.transferData, isNotNull);
      expect(res.transferData!.amount, equals(2000000.0));
      expect(res.transferData!.sourceWalletName.toLowerCase(), anyOf(contains('ngân hàng'), contains('atm')));
      expect(res.transferData!.targetWalletName.toLowerCase(), contains('tiền mặt'));
    });

    test('Trợ lý Mono: Lưu trữ sliding window hội thoại đa vòng (multi-turn conversation)', () {
      aiService.clearHistory();
      expect(aiService.conversationHistory.isEmpty, isTrue);

      for (int i = 1; i <= 25; i++) {
        aiService.addToHistory('user', 'Tin nhắn thứ $i');
      }

      // Giới hạn buffer tối đa 20 tin
      expect(aiService.conversationHistory.length, equals(20));
      expect(aiService.conversationHistory.first['text'], equals('Tin nhắn thứ 6'));
      expect(aiService.conversationHistory.last['text'], equals('Tin nhắn thứ 25'));
    });

    test('Trợ lý Mono: Nhận diện chính xác câu nói cộng tiền lãi vào ví: "cộng 11đ tiền lãi vào ví momo"', () async {
      final res = await aiService.parseNaturalLanguage('cộng 11đ tiền lãi vào ví momo');
      expect(res.isSuccess, isTrue);
      expect(res.transactions.isNotEmpty, isTrue);

      final tx = res.transactions.first;
      expect(tx.type, equals('income'));
      expect(tx.amount, equals(11.0));
      expect(tx.category, equals('Tiền lãi'));
      expect(tx.description.toLowerCase(), contains('tiền lãi'));
      expect(tx.walletName.toLowerCase(), contains('momo'));
    });

    test('VoiceService: Nhận diện lệnh giọng nói "cộng 11đ tiền lãi vào ví momo"', () {
      final voiceRes = VoiceService().parseVoiceCommand('cộng 11đ tiền lãi vào ví momo');
      expect(voiceRes, isNotNull);
      expect(voiceRes!['type'], equals('income'));
      expect(voiceRes['amount'], equals(11.0));
      expect(voiceRes['category'], equals('Tiền lãi'));
      expect(voiceRes['description'].toString().toLowerCase(), contains('tiền lãi'));
      expect(voiceRes['wallet'].toString().toLowerCase(), contains('momo'));
    });
  });
}
