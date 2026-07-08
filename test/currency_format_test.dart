import 'package:flutter_test/flutter_test.dart';
import 'package:my_money_flutter/core/currency_format.dart';

void main() {
  group('CurrencyFormat Extension Tests', () {
    test('formats regular double values with Indian grouping and 2 decimal points', () {
      expect(1000.0.formatIndianCurrency(), '1,000.00');
      expect(100000.0.formatIndianCurrency(), '1,00,000.00');
      expect(1234567.89.formatIndianCurrency(), '12,34,567.89');
    });

    test('formats zero and negative values correctly', () {
      expect(0.0.formatIndianCurrency(), '0.00');
      expect((-500.5).formatIndianCurrency(), '-500.50');
      expect((-1234567.89).formatIndianCurrency(), '-12,34,567.89');
    });

    test('formats values with many fractional digits by rounding to 2 places', () {
      expect(100.555.formatIndianCurrency(), '100.56');
      expect(100.554.formatIndianCurrency(), '100.55');
    });
  });
}
