// test/discount_test.dart
import 'package:flutter_application_1/logic/discount.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscountCalculator.rateFor', () {
    test('без карты — 0%', () {
      expect(DiscountCalculator.rateFor(null), 0.0);
      expect(DiscountCalculator.rateFor('неизвестно'), 0.0);
    });
    test('серебро — 5%', () {
      expect(DiscountCalculator.rateFor('серебро'), 0.05);
    });
    test('золото — 10%', () {
      expect(DiscountCalculator.rateFor('золото'), 0.10);
    });
  });

  group('DiscountCalculator.finalCost', () {
    test('без карты итог равен базовой стоимости', () {
      expect(
        DiscountCalculator.finalCost(baseCost: 1000, discountCategory: null),
        1000.0,
      );
    });
    test('серебро: 1000 → 950', () {
      expect(
        DiscountCalculator.finalCost(
          baseCost: 1000,
          discountCategory: 'серебро',
        ),
        950.0,
      );
    });
    test('золото: 1000 → 900', () {
      expect(
        DiscountCalculator.finalCost(
          baseCost: 1000,
          discountCategory: 'золото',
        ),
        900.0,
      );
    });
    test('округление до копеек', () {
      // 333.33 * 0.9 = 299.997 → должно стать 300.00
      expect(
        DiscountCalculator.finalCost(
          baseCost: 333.33,
          discountCategory: 'золото',
        ),
        300.0,
      );
    });
    test('цена ноль даёт ноль', () {
      expect(
        DiscountCalculator.finalCost(baseCost: 0, discountCategory: 'золото'),
        0.0,
      );
    });
  });

  group('DiscountCalculator.discountAmount', () {
    test('серебро: скидка 50 с 1000', () {
      expect(
        DiscountCalculator.discountAmount(
          baseCost: 1000,
          discountCategory: 'серебро',
        ),
        50.0,
      );
    });
    test('золото: скидка 100 с 1000', () {
      expect(
        DiscountCalculator.discountAmount(
          baseCost: 1000,
          discountCategory: 'золото',
        ),
        100.0,
      );
    });
    test('без карты скидка ноль', () {
      expect(
        DiscountCalculator.discountAmount(
          baseCost: 1000,
          discountCategory: null,
        ),
        0.0,
      );
    });
  });
}
