// lib/screens/order_details_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../logic/discount.dart';
import '../models/client.dart';
import '../models/repair_order.dart';
import '../repositories/client_repository.dart';
import '../repositories/order_repository.dart';

class OrderDetailsScreen extends StatelessWidget {
  final int id;
  const OrderDetailsScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final ordersRepo = context.read<OrderRepository>();
    final clientsRepo = context.read<ClientRepository>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Заказ #$id'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/orders'),
        ),
      ),
      body: FutureBuilder<(RepairOrder?, Client?)>(
        future: _loadAll(ordersRepo, clientsRepo),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data;
          if (data == null || data.$1 == null) {
            return const Center(child: Text('Заказ не найден'));
          }

          final order = data.$1!;
          final client = data.$2;

          final discount = DiscountCalculator.discountAmount(
            baseCost: order.cost,
            discountCategory: client?.card?.discountCategory,
          );
          final total = DiscountCalculator.finalCost(
            baseCost: order.cost,
            discountCategory: client?.card?.discountCategory,
          );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  _row('VIN', order.vin),
                  _row('Год выпуска', '${order.year}'),
                  _row('Статус', order.status),
                  if (client != null) _row('Клиент', client.fullName),
                  if (client?.card != null)
                    _row('Категория скидки', client!.card!.discountCategory),

                  const SizedBox(height: 16),
                  const Divider(),
                  _row('Стоимость', '${order.cost.toStringAsFixed(2)} ₽'),
                  _row('Скидка', '${discount.toStringAsFixed(2)} ₽'),
                  _row(
                    'Итого к оплате',
                    '${total.toStringAsFixed(2)} ₽',
                    bold: true,
                  ),

                  if (order.isDeleted)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Удалён (в корзине)',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<(RepairOrder?, Client?)> _loadAll(
    OrderRepository ordersRepo,
    ClientRepository clientsRepo,
  ) async {
    final order = await ordersRepo.findById(id);
    if (order == null) return (null, null);
    final client = await clientsRepo.findById(order.clientId);
    return (order, client);
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: bold ? Colors.indigo : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
