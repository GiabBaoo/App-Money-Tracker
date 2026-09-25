import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/services/bank_sms_parser_service.dart';
import 'package:money_tracker_app/services/group_bill_split_service.dart';
import 'package:money_tracker_app/services/smart_category_service.dart';

void main() {
  group('1. BankSmsParserService Tests', () {
    final parser = BankSmsParserService();

    test('Bóc tách biến động số dư Vietcombank', () {
      const sms = 'VCB 12/05/26 14:30 TK 0123456789 -500,000 VND Ref 987654. ND: Phuc Long Coffee. So du: 15,200,000 VND';
      expect(parser.isBankSmsOrNotification(sms), isTrue);

      final result = parser.parse(sms);
      expect(result, isNotNull);
      expect(result!.bankName, equals('Vietcombank'));
      expect(result.type, equals('expense'));
      expect(result.amount, equals(500000));
      expect(result.category, equals('Ăn uống'));
      expect(result.newBalance, equals(15200000));
    });

    test('Bóc tách biến động số dư MB Bank tiền vào', () {
      const sms = 'MB: TK 1234567890 +15,000,000VND vao 05/09/2026. ND: Cong ty ABC tra luong T8. SD: 25,000,000VND';
      expect(parser.isBankSmsOrNotification(sms), isTrue);

      final result = parser.parse(sms);
      expect(result, isNotNull);
      expect(result!.bankName, equals('MB Bank'));
      expect(result.type, equals('income'));
      expect(result.amount, equals(15000000));
      expect(result.category, equals('Tiền lương'));
      expect(result.newBalance, equals(25000000));
    });

    test('Bóc tách biến động số dư MoMo chi tiêu Grab', () {
      const sms = 'Giao dịch MoMo: Bạn đã thanh toán 42.000đ cho Grab Bike. Mã GD: 998877';
      expect(parser.isBankSmsOrNotification(sms), isTrue);

      final result = parser.parse(sms);
      expect(result, isNotNull);
      expect(result!.bankName, equals('MoMo'));
      expect(result.type, equals('expense'));
      expect(result.amount, equals(42000));
      expect(result.category, equals('Di chuyển'));
    });
  });

  group('2. GroupBillSplitService Tests', () {
    final splitService = GroupBillSplitService();

    test('Chia đều 600k cho 4 người có danh sách tên', () {
      const input = 'Chia 600k cho 4 người: An, Bình, Cường, Dũng';
      final result = splitService.parseAndSplit(input);

      expect(result.totalAmount, equals(600000));
      expect(result.memberCount, equals(4));
      expect(result.perPersonAmount, equals(150000));
      expect(result.members.length, equals(4));
      expect(result.shareSummaryText.contains('150.000'), isTrue);
    });

    test('Chia tiền ăn lẩu 1tr2 cho 3 người', () {
      const input = 'Chia tiền ăn lẩu 1.200.000đ cho 3 người gồm tôi, Mai, Nam';
      final result = splitService.parseAndSplit(input);

      expect(result.totalAmount, equals(1200000));
      expect(result.perPersonAmount, equals(400000));
      expect(result.title, equals('Ăn lẩu'));
    });
  });

  group('3. SmartCategoryService Tests', () {
    final smartCat = SmartCategoryService();

    test('Nhận diện thương hiệu trà sữa và cà phê', () async {
      final resPhucLong = await smartCat.predictCategory(text: 'Uống Phúc Long với bạn');
      expect(resPhucLong.category, equals('Ăn uống'));

      final resKatinat = await smartCat.predictCategory(text: 'Katinat Saigon Cafe');
      expect(resKatinat.category, equals('Ăn uống'));
    });

    test('Nhận diện dịch vụ di chuyển công nghệ', () async {
      final resXanhSM = await smartCat.predictCategory(text: 'Đi Xanh SM đến công ty');
      expect(resXanhSM.category, equals('Di chuyển'));
    });

    test('Nhận diện mua sắm thương mại điện tử', () async {
      final resShopee = await smartCat.predictCategory(text: 'Đơn hàng Shopee áo sơ mi');
      expect(resShopee.category, equals('Mua sắm'));
    });

    test('Nhận diện hiệu thuốc sức khỏe', () async {
      final resPharmacity = await smartCat.predictCategory(text: 'Mua vitamin tại Pharmacity');
      expect(resPharmacity.category, equals('Sức khỏe'));
    });
  });
}
