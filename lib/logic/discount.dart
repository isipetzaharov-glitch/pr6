// lib/logic/discount.dart

/// Содержательная особенность предметной области:
/// расчёт итоговой стоимости заказа с учётом категории скидки
/// по сервисной карте клиента.
///
/// Правила автосервиса:
///   - клиент без карты платит полную стоимость;
///   - категория «серебро» — скидка 5%;
///   - категория «золото»  — скидка 10%.
class DiscountCalculator {
  /// Возвращает коэффициент скидки (0.0, 0.05 или 0.10).
  static double rateFor(String? category) {
    return switch (category) {
      'серебро' => 0.05,
      'золото' => 0.10,
      _ => 0.0,
    };
  }

  /// Итоговая стоимость с учётом скидки.
  /// Округляется до копеек, чтобы избежать проблем с плавающей точкой.
  static double finalCost({
    required double baseCost,
    required String? discountCategory,
  }) {
    final rate = rateFor(discountCategory);
    final discounted = baseCost * (1 - rate);
    return double.parse(discounted.toStringAsFixed(2));
  }

  /// Размер скидки в рублях.
  static double discountAmount({
    required double baseCost,
    required String? discountCategory,
  }) {
    final rate = rateFor(discountCategory);
    final amount = baseCost * rate;
    return double.parse(amount.toStringAsFixed(2));
  }
}
