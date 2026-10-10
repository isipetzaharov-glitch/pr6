// test/validators_test.dart
import 'package:flutter_application_1/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.required', () {
    test('пустая строка отклоняется', () {
      expect(Validators.required('', field: 'Поле'), isNotNull);
    });
    test('строка из пробелов отклоняется', () {
      expect(Validators.required('   ', field: 'Поле'), isNotNull);
    });
    test('null отклоняется', () {
      expect(Validators.required(null, field: 'Поле'), isNotNull);
    });
    test('нормальная строка принимается', () {
      expect(Validators.required('Заказ №1', field: 'Поле'), isNull);
    });
  });

  group('Validators.vin', () {
    test('короткий VIN отклоняется', () {
      expect(Validators.vin('VIN123'), isNotNull);
    });
    test('длинный VIN отклоняется', () {
      expect(Validators.vin('VIN000000000000000000'), isNotNull);
    });
    test('17-символьный VIN принимается', () {
      // Ровно 17 символов: VIN (3) + 14 цифр.
      expect(Validators.vin('VIN00000000000001'), isNull);
    });
    test('пустой VIN отклоняется', () {
      expect(Validators.vin(''), isNotNull);
    });
  });

  group('Validators.email', () {
    test('пустой email отклоняется', () {
      expect(Validators.email(''), isNotNull);
    });
    test('email без @ отклоняется', () {
      expect(Validators.email('user.mail.ru'), isNotNull);
    });
    test('email без домена отклоняется', () {
      expect(Validators.email('user@'), isNotNull);
    });
    test('корректный email принимается', () {
      expect(Validators.email('user@mail.ru'), isNull);
    });
  });

  group('Validators.positiveDouble', () {
    test('ноль отклоняется', () {
      expect(Validators.positiveDouble('0'), isNotNull);
    });
    test('отрицательное отклоняется', () {
      expect(Validators.positiveDouble('-100'), isNotNull);
    });
    test('нечисловое отклоняется', () {
      expect(Validators.positiveDouble('abc'), isNotNull);
    });
    test('положительное принимается', () {
      expect(Validators.positiveDouble('100.5'), isNull);
    });
    test('запятая как разделитель принимается', () {
      expect(Validators.positiveDouble('100,5'), isNull);
    });
  });

  group('Validators.intRange', () {
    test('значение ниже диапазона отклоняется', () {
      expect(Validators.intRange('1900', 1970, 2100), isNotNull);
    });
    test('значение выше диапазона отклоняется', () {
      expect(Validators.intRange('2200', 1970, 2100), isNotNull);
    });
    test('значение внутри диапазона принимается', () {
      expect(Validators.intRange('2020', 1970, 2100), isNull);
    });
    test('нечисловое отклоняется', () {
      expect(Validators.intRange('abc', 1970, 2100), isNotNull);
    });
  });

  group('Validators.phone', () {
    test('короткий телефон отклоняется', () {
      expect(Validators.phone('123'), isNotNull);
    });
    test('корректный телефон принимается', () {
      expect(Validators.phone('+7-900-100-01-01'), isNull);
    });
  });
}
