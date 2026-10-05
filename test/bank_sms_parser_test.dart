import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/services/bank_sms_parser_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bank SMS Parser Service Tests', () {
    final parser = BankSmsParserService();

    test('1. Nhận diện chính xác SMS biến động số dư ngân hàng và bỏ qua câu nói thường', () {
      // Tin nhắn biến động thực tế từ ngân hàng
      expect(
        parser.isBankNotification('VCB: +500.000VND lúc 12:00. Số dư 5.000.000VND. ND: Chuyen tien'),
        isTrue,
      );
      expect(
        parser.isBankNotification('TK 1903... GD: -45,000VND. So du: 1,200,000VND. ND: Tra tien cafe'),
        isTrue,
      );

      // Câu nói / lệnh tự nhiên của người dùng KHÔNG phải SMS ngân hàng
      expect(
        parser.isBankNotification('Ăn sáng bún bò 35k tiền mặt'),
        isFalse,
      );
      expect(
        parser.isBankNotification('Mới bỏ 50k vào ví momo'),
        isFalse,
      );
      expect(
        parser.isBankNotification('Hôm nay được mẹ cho 200k'),
        isFalse,
      );
    });

    test('2. Phân tích SMS Vietcombank (VCB) biến động TĂNG (Thu nhập / Lương)', () {
      const vcbSms = 'VCB: SD TK 001100987654 +5,000,000VND lúc 05/10/2026. Số dư 15,400,000VND. ND: Chuyen khoan tien luong thang 10';
      final result = parser.parse(vcbSms);

      expect(result, isNotNull);
      expect(result!.bankName, equals('Vietcombank'));
      expect(result.isIncome, isTrue);
      expect(result.type, equals('income'));
      expect(result.amount, equals(5000000.0));
      expect(result.balanceAfter, equals(15400000.0));
      expect(result.suggestedCategory, equals('Tiền lương'));
      expect(result.description.toLowerCase(), contains('tien luong'));
    });

    test('3. Phân tích SMS Techcombank (TCB) biến động GIẢM (Chi tiêu mua sắm)', () {
      const tcbSms = 'TCB: TK 19033445566 GD -350,000VND 05/10/2026 14:20. SD: 4,650,000VND. ND: Thanh toan Shopee Pay';
      final result = parser.parse(tcbSms);

      expect(result, isNotNull);
      expect(result!.bankName, equals('Techcombank'));
      expect(result.isIncome, isFalse);
      expect(result.type, equals('expense'));
      expect(result.amount, equals(350000.0));
      expect(result.balanceAfter, equals(4650000.0));
      expect(result.suggestedCategory, equals('Mua sắm'));
      expect(result.description.toLowerCase(), contains('shopee'));
    });

    test('4. Phân tích SMS MB Bank biến động GIẢM (Ăn uống)', () {
      const mbSms = 'MB: TK 0123456789 -45.000VND luc 05/10/2026 07:30. So du: 2.100.000VND. ND: An sang pho bo Ha Noi';
      final result = parser.parse(mbSms);

      expect(result, isNotNull);
      expect(result!.bankName, equals('MB Bank'));
      expect(result.isIncome, isFalse);
      expect(result.type, equals('expense'));
      expect(result.amount, equals(45000.0));
      expect(result.balanceAfter, equals(2100000.0));
      expect(result.suggestedCategory, equals('Ăn uống'));
    });

    test('5. Phân tích SMS VPBank biến động GIẢM (Đổ xăng / Di chuyển)', () {
      const vpbSms = 'VPBank: TK 987654321 GD -70.000d luc 05/10/2026 10:15. SD 1.450.000d. ND: Do xang Petrolimex CHXD 12';
      final result = parser.parse(vpbSms);

      expect(result, isNotNull);
      expect(result!.bankName, equals('VPBank'));
      expect(result.isIncome, isFalse);
      expect(result.type, equals('expense'));
      expect(result.amount, equals(70000.0));
      expect(result.balanceAfter, equals(1450000.0));
      expect(result.suggestedCategory, equals('Di chuyển'));
    });

    test('6. Phân tích SMS BIDV biến động TĂNG (Hoàn tiền)', () {
      const bidvSms = 'BIDV: 05/10/2026; TK 123456; +120,000 VND; So du: 8,300,000 VND; ND: Hoan tien Tiki order';
      final result = parser.parse(bidvSms);

      expect(result, isNotNull);
      expect(result!.bankName, equals('BIDV'));
      expect(result.isIncome, isTrue);
      expect(result.type, equals('income'));
      expect(result.amount, equals(120000.0));
      expect(result.balanceAfter, equals(8300000.0));
      expect(result.suggestedCategory, equals('Hoàn tiền'));
    });

    test('7. Phân tích SMS ACB biến động GIẢM (Cafe)', () {
      const acbSms = 'ACB: TK 888999 GD -55,000 VND luc 05/10/2026. So du: 920,000 VND. ND: Cafe Highland Coffee';
      final result = parser.parse(acbSms);

      expect(result, isNotNull);
      expect(result!.bankName, equals('ACB'));
      expect(result.isIncome, isFalse);
      expect(result.type, equals('expense'));
      expect(result.amount, equals(55000.0));
      expect(result.suggestedCategory, equals('Ăn uống'));
    });

    test('8. Chuỗi rỗng hoặc không có số tiền trả về null', () {
      expect(parser.parse(''), isNull);
      expect(parser.parse('   '), isNull);
      expect(parser.parse('Vietcombank thong bao bao tri he thong ngay 05/10'), isNull);
    });
  });
}
