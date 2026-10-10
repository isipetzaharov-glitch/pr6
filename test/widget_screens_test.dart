// test/widget_screens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/api_exceptions.dart';
import 'package:flutter_application_1/models/order_query.dart';
import 'package:flutter_application_1/models/page_result.dart';
import 'package:flutter_application_1/models/repair_order.dart';
import 'package:flutter_application_1/repositories/order_repository.dart';
import 'package:flutter_application_1/screens/orders_screen.dart';
import 'package:flutter_application_1/state/order_list_notifier.dart';
import 'package:flutter_application_1/widgets/entity_table.dart';
import 'package:flutter_application_1/widgets/pagination_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Заглушка репозитория. Возвращает заданное состояние.
class _FakeOrderRepository implements OrderRepository {
  _FakeOrderRepository({
    this.items = const [],
    this.error,
    this.delay = Duration.zero,
  });

  final List<RepairOrder> items;
  final Object? error;
  final Duration delay;

  @override
  Future<PageResult<RepairOrder>> find(OrderQuery q) async {
    if (delay > Duration.zero) await Future.delayed(delay);
    if (error != null) throw error!;
    return PageResult(items: items, page: 1, size: 10, total: items.length);
  }

  @override
  Future<RepairOrder?> findById(int id) async => null;
  @override
  Future<RepairOrder> create(RepairOrder o) async => o;
  @override
  Future<RepairOrder> update(RepairOrder o) async => o;
  @override
  Future<void> softDelete(int id) async {}
  @override
  Future<void> hardDelete(int id) async {}
  @override
  Future<void> restore(int id) async {}
  @override
  Future<int> deleteMany(List<int> ids) async => 0;
}

RepairOrder _sample() => const RepairOrder(
  id: 1,
  title: 'Замена масла',
  vin: 'VIN0000000000001',
  year: 2020,
  clientId: 1,
  masterId: 1,
  serviceIds: [1],
  cost: 1000,
  status: 'new',
);

/// Оборачивает виджет в минимальный router + provider.
Widget _wrap(Widget child, OrderRepository repo) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (_, _) => child)],
  );
  return ChangeNotifierProvider(
    create: (_) => OrderListNotifier(repo)..load(),
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Отображается индикатор загрузки', (tester) async {
    final repo = _FakeOrderRepository(delay: const Duration(milliseconds: 500));
    await tester.pumpWidget(_wrap(const OrdersScreen(urlParams: {}), repo));
    // Проверяем, что индикатор виден на первом кадре.
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Дожидаемся завершения таймера и перерисовки.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  });

  testWidgets('Отображается пустой результат', (tester) async {
    final repo = _FakeOrderRepository(items: []);
    await tester.pumpWidget(_wrap(const OrdersScreen(urlParams: {}), repo));
    await tester.pumpAndSettle();
    expect(find.text('Ничего не найдено'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Отображается ошибка с кнопкой повтора', (tester) async {
    final repo = _FakeOrderRepository(
      error: const NetworkException('Ошибка соединения'),
    );
    await tester.pumpWidget(_wrap(const OrdersScreen(urlParams: {}), repo));
    await tester.pumpAndSettle();
    expect(find.text('Повторить'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Таблица показывает данные при успехе', (tester) async {
    final repo = _FakeOrderRepository(items: [_sample()]);
    await tester.pumpWidget(_wrap(const OrdersScreen(urlParams: {}), repo));
    await tester.pumpAndSettle();
    expect(find.text('Замена масла'), findsAtLeastNWidgets(1));
  });

  testWidgets('EntityTable и PaginationBar отображаются при успехе', (
    tester,
  ) async {
    final repo = _FakeOrderRepository(items: [_sample()]);
    await tester.pumpWidget(_wrap(const OrdersScreen(urlParams: {}), repo));
    await tester.pumpAndSettle();

    expect(find.byType(EntityTable<RepairOrder>), findsOneWidget);
    expect(find.byType(PaginationBar), findsOneWidget);
  });
}
