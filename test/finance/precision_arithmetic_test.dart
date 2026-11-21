import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/utils/finance_precision.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Suite 1: Precision Arithmetic & IEEE 754 Elimination', () {
    test('TC-PREC-01: Phép cộng dồn giá trị 0.1 USD không phát sinh sai số trôi', () {
      double sum = 0.0;
      for (int i = 0; i < 10000; i++) {
        sum = FinancePrecision.add(sum, 0.1, currency: 'USD');
      }
      expect(sum, equals(1000.0));
      expect(FinancePrecision.areEqual(sum, 1000.0), isTrue);
    });

    test('TC-PREC-02: Làm tròn tiền tệ VND luôn là số nguyên (Zero-Decimal Currency)', () {
      expect(
        FinancePrecision.roundCurrency(125000.49, currency: 'VND'),
        equals(125000.0),
      );
      expect(
        FinancePrecision.roundCurrency(125000.50, currency: 'VND'),
        equals(125001.0),
      );
      expect(
        FinancePrecision.roundCurrency(99999.99, currency: 'VND'),
        equals(100000.0),
      );
    });

    test('TC-PREC-03: Làm tròn ngoại tệ (USD, EUR) luôn đúng 2 chữ số thập phân', () {
      expect(
        FinancePrecision.roundCurrency(45.678, currency: 'USD'),
        equals(45.68),
      );
      expect(
        FinancePrecision.roundCurrency(45.672, currency: 'USD'),
        equals(45.67),
      );
      expect(
        FinancePrecision.roundCurrency(10.005, currency: 'EUR'),
        equals(10.01),
      );
    });

    test('TC-PREC-04: Phép tính số học an toàn add, subtract, multiply', () {
      // 0.1 + 0.2 trong IEEE 754 là 0.30000000000000004
      final resultAdd = FinancePrecision.add(0.1, 0.2, currency: 'USD');
      expect(resultAdd, equals(0.3));

      // 1.0 - 0.9 trong IEEE 754 là 0.09999999999999998
      final resultSub = FinancePrecision.subtract(1.0, 0.9, currency: 'USD');
      expect(resultSub, equals(0.1));

      // 0.14 * 100
      final resultMul = FinancePrecision.multiply(0.14, 100, currency: 'USD');
      expect(resultMul, equals(14.0));
    });

    test('TC-PREC-05: So sánh tài chính với ngưỡng epsilon', () {
      expect(FinancePrecision.areEqual(100.00001, 100.0), isTrue);
      expect(FinancePrecision.areEqual(100.001, 100.0), isFalse);

      expect(FinancePrecision.isGreaterThan(100.001, 100.0), isTrue);
      expect(FinancePrecision.isGreaterThan(100.00001, 100.0), isFalse);

      expect(FinancePrecision.isLessThan(99.999, 100.0), isTrue);
      expect(FinancePrecision.isLessThan(99.99999, 100.0), isFalse);

      expect(FinancePrecision.isZero(0.000001), isTrue);
      expect(FinancePrecision.isZero(0.01), isFalse);

      expect(FinancePrecision.isPositive(0.001), isTrue);
      expect(FinancePrecision.isPositive(-0.001), isFalse);
    });
  });
}
