import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/services/gemini_ai_service.dart';
import 'package:money_tracker_app/services/ai_action_handler.dart';
import 'package:money_tracker_app/services/voice_service.dart';

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
      expect(repRes2.actionType, equals(AiActionType.spendingReport));
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
  });
}
