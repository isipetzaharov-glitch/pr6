// lib/screens/orders_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/order_query.dart';
import '../models/repair_order.dart';
import '../state/auth_notifier.dart';
import '../state/order_list_notifier.dart';
import '../widgets/entity_table.dart';
import '../widgets/pagination_bar.dart';

class OrdersScreen extends StatefulWidget {
  final Map<String, String> urlParams;
  const OrdersScreen({super.key, required this.urlParams});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late final TextEditingController _searchCtrl;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final q = OrderQuery.fromParams(widget.urlParams);
    _searchCtrl = TextEditingController(text: q.search);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OrderListNotifier>().applyQuery(q);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final n = context.read<OrderListNotifier>();
      n.applyQuery(n.query.copyWith(search: v));
      _syncUrl(n.query);
    });
  }

  void _syncUrl(OrderQuery q) {
    if (!mounted) return;
    final uri = Uri(path: '/orders', queryParameters: q.toParams());
    context.go(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<OrderListNotifier>();
    final auth = context.watch<AuthNotifier>();

    // ← ПРАВКА: разделяем права.
    // canCreate — создавать заказ (FAB). Разрешено всем авторизованным;
    //             reader создаёт только себе (проверит сервер).
    // canModify — редактировать/удалять/выбирать строки. Только master+.
    final canCreate = auth.isAuthenticated;
    final canModify = auth.has(Role.master);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _filtersRow(context, n),
            const SizedBox(height: 8),
            if (n.hasSelection && canModify) _selectionBar(context, n),
            Expanded(child: _body(context, n, canModify)),
            if (n.status == LoadStatus.success && n.result.items.isNotEmpty)
              PaginationBar(
                page: n.result.page,
                totalPages: n.result.totalPages,
                total: n.result.total,
                size: n.result.size,
                onPageChanged: (p) {
                  n.applyQuery(n.query.copyWith(page: p));
                  _syncUrl(n.query);
                },
                onSizeChanged: (s) {
                  n.applyQuery(n.query.copyWith(size: s, page: 1));
                  _syncUrl(n.query);
                },
              ),
          ],
        ),
      ),
      // FAB показываем всем авторизованным (reader создаёт «себе»).
      floatingActionButton: canCreate
          ? FloatingActionButton(
              tooltip: 'Новый заказ',
              onPressed: () => context.go('/orders/new'),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _filtersRow(BuildContext context, OrderListNotifier n) {
    final q = n.query;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Поиск: название или VIN',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<int?>(
            initialValue: q.serviceId,
            decoration: const InputDecoration(
              labelText: 'Услуга',
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('Все')),
              DropdownMenuItem(value: 1, child: Text('ТО')),
              DropdownMenuItem(value: 2, child: Text('Двигатель')),
              DropdownMenuItem(value: 3, child: Text('Подвеска')),
              DropdownMenuItem(value: 4, child: Text('Электрика')),
              DropdownMenuItem(value: 5, child: Text('Кузов')),
            ],
            onChanged: (v) {
              n.applyQuery(n.query.copyWith(serviceId: v));
              _syncUrl(n.query);
            },
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<int?>(
            initialValue: q.masterId,
            decoration: const InputDecoration(
              labelText: 'Мастер',
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('Все')),
              DropdownMenuItem(value: 1, child: Text('Петров')),
              DropdownMenuItem(value: 2, child: Text('Сидоров')),
              DropdownMenuItem(value: 3, child: Text('Егоров')),
              DropdownMenuItem(value: 4, child: Text('Фёдоров')),
            ],
            onChanged: (v) {
              n.applyQuery(n.query.copyWith(masterId: v));
              _syncUrl(n.query);
            },
          ),
        ),
        SizedBox(
          width: 110,
          child: TextFormField(
            initialValue: q.yearFrom?.toString() ?? '',
            decoration: const InputDecoration(
              labelText: 'Год от',
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            onFieldSubmitted: (v) {
              n.applyQuery(n.query.copyWith(yearFrom: int.tryParse(v)));
              _syncUrl(n.query);
            },
          ),
        ),
        SizedBox(
          width: 110,
          child: TextFormField(
            initialValue: q.yearTo?.toString() ?? '',
            decoration: const InputDecoration(
              labelText: 'Год до',
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            onFieldSubmitted: (v) {
              n.applyQuery(n.query.copyWith(yearTo: int.tryParse(v)));
              _syncUrl(n.query);
            },
          ),
        ),
        FilterChip(
          label: const Text('Показать удалённые'),
          selected: q.includeDeleted,
          onSelected: (v) {
            n.applyQuery(n.query.copyWith(includeDeleted: v));
            _syncUrl(n.query);
          },
        ),
      ],
    );
  }

  Widget _selectionBar(BuildContext context, OrderListNotifier n) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Row(
        children: [
          Text('Выбрано: ${n.selected.length}'),
          const Spacer(),
          TextButton(
            onPressed: n.clearSelection,
            child: const Text('Снять выделение'),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await _confirm(context, 'Удалить выбранные записи?');
              if (ok == true) {
                await n.deleteSelected();
                _syncUrl(n.query);
              }
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, OrderListNotifier n, bool canModify) {
    if (n.status == LoadStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (n.status == LoadStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text(n.error ?? 'Ошибка'),
            const SizedBox(height: 8),
            FilledButton(onPressed: n.load, child: const Text('Повторить')),
          ],
        ),
      );
    }
    if (n.result.items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('Ничего не найдено'),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 600) return _cardsList(context, n, canModify);
        return EntityTable<RepairOrder>(
          items: n.result.items,
          idOf: (o) => o.id,
          selected: canModify ? n.selected : const {},
          onToggleSelect: canModify ? n.toggleSelection : null,
          sortField: n.query.sortField,
          sortAscending: n.query.sortAscending,
          onSort: (field) {
            n.applyQuery(
              n.query.copyWith(
                sortField: field,
                sortAscending: field == n.query.sortField
                    ? !n.query.sortAscending
                    : true,
              ),
            );
            _syncUrl(n.query);
          },
          columns: [
            TableColumnSpec(
              label: 'Заказ',
              sortField: 'title',
              build: (o) => Text(o.title),
            ),
            TableColumnSpec(label: 'VIN', build: (o) => Text(o.vin)),
            TableColumnSpec(
              label: 'Год',
              sortField: 'year',
              numeric: true,
              build: (o) => Text('${o.year}'),
            ),
            TableColumnSpec(
              label: 'Стоимость',
              sortField: 'cost',
              numeric: true,
              build: (o) => Text('${o.cost.toStringAsFixed(0)} ₽'),
            ),
            TableColumnSpec(
              label: 'Статус',
              sortField: 'status',
              build: (o) => Text(o.status),
            ),
          ],
          actions: (o) => [
            IconButton(
              tooltip: 'Открыть',
              onPressed: () => context.go('/orders/${o.id}'),
              icon: const Icon(Icons.visibility),
            ),
            if (canModify)
              IconButton(
                tooltip: 'Редактировать',
                onPressed: () => context.go('/orders/${o.id}/edit'),
                icon: const Icon(Icons.edit),
              ),
            if (canModify)
              IconButton(
                tooltip: 'Удалить',
                onPressed: () async {
                  final ok = await _confirm(
                    context,
                    'Удалить заказ «${o.title}»?',
                  );
                  if (ok == true) await n.softDeleteOne(o.id);
                },
                icon: const Icon(Icons.delete),
              ),
          ],
        );
      },
    );
  }

  Widget _cardsList(BuildContext context, OrderListNotifier n, bool canModify) {
    return ListView.separated(
      itemCount: n.result.items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final o = n.result.items[i];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: canModify
                ? Checkbox(
                    value: n.selected.contains(o.id),
                    onChanged: (_) => n.toggleSelection(o.id),
                  )
                : null,
            title: Text(o.title),
            subtitle: Text(
              'VIN: ${o.vin}\nГод: ${o.year} • ${o.cost.toStringAsFixed(0)} ₽',
            ),
            isThreeLine: true,
            trailing: canModify
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => context.go('/orders/${o.id}/edit'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          final ok = await _confirm(context, 'Удалить заказ?');
                          if (ok == true) await n.softDeleteOne(o.id);
                        },
                      ),
                    ],
                  )
                : null,
            onTap: () => context.go('/orders/${o.id}'),
          ),
        );
      },
    );
  }

  Future<bool?> _confirm(BuildContext context, String text) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Да'),
          ),
        ],
      ),
    );
  }
}
