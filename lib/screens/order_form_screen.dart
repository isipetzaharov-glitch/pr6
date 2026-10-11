// lib/screens/order_form_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../logic/discount.dart';
import '../models/app_user.dart';
import '../models/client.dart';
import '../models/repair_order.dart';
import '../repositories/order_repository.dart';
import '../state/auth_notifier.dart';
import '../state/dictionaries_notifier.dart';
import '../utils/validators.dart';

class OrderFormScreen extends StatefulWidget {
  final int? id;
  const OrderFormScreen({super.key, this.id});

  bool get isEditing => id != null;

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _vinCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _costCtrl = TextEditingController();

  int? _clientId;
  Client? _selectedClient;
  int? _masterId;
  List<int> _serviceIds = [];
  String _status = 'new';

  /// true, если текущий пользователь — reader.
  /// Reader создаёт заказ только на себя и НЕ задаёт цену/статус:
  ///   - клиент фиксирован,
  ///   - стоимость скрыта (её поставит мастер),
  ///   - статус всегда 'new'.
  bool _isReader = false;

  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  bool _dirty = false;

  Map<String, String> _serverErrors = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dict = context.read<DictionariesNotifier>();
    final repo = context.read<OrderRepository>();
    final auth = context.read<AuthNotifier>();

    await dict.ensureLoaded();

    _isReader = auth.user?.role == Role.reader;

    if (widget.isEditing) {
      try {
        final order = await repo.findById(widget.id!);
        if (!mounted) return;
        if (order != null) {
          _titleCtrl.text = order.title;
          _vinCtrl.text = order.vin;
          _yearCtrl.text = order.year.toString();
          _costCtrl.text = order.cost.toStringAsFixed(0);
          _clientId = order.clientId;
          _masterId = order.masterId;
          _serviceIds = [...order.serviceIds];
          _status = order.status;

          try {
            _selectedClient = dict.clients.firstWhere(
              (c) => c.id == order.clientId,
            );
          } catch (_) {
            _selectedClient = null;
          }
        } else {
          _loadError = 'Заказ не найден';
        }
      } on ApiException catch (e) {
        if (!mounted) return;
        _loadError = e.message;
      }
    } else if (_isReader) {
      // Reader создаёт заказ только на себя.
      final myId = auth.user?.clientId;
      if (myId == null) {
        _loadError = 'Учётная запись не привязана к клиенту автосервиса';
      } else {
        _clientId = myId;
        try {
          _selectedClient = dict.clients.firstWhere((c) => c.id == myId);
        } catch (_) {
          _selectedClient = null;
        }
        // Цена и статус — не его забота.
        _costCtrl.text = '0';
        _status = 'new';
      }
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _vinCtrl.dispose();
    _yearCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _goBack() {
    if (!mounted) return;
    if (_isReader) {
      GoRouter.of(context).go('/my-orders');
    } else {
      GoRouter.of(context).go('/orders');
    }
  }

  Future<void> _save() async {
    setState(() => _serverErrors = {});
    if (!_formKey.currentState!.validate()) return;
    if (_clientId == null) {
      _snack('Выберите клиента');
      return;
    }
    if (_masterId == null) {
      _snack('Выберите мастера');
      return;
    }
    if (_serviceIds.isEmpty) {
      _snack('Выберите хотя бы одну услугу');
      return;
    }

    final auth = context.read<AuthNotifier>();
    // Для reader жёстко фиксируем clientId, cost и status.
    final effectiveClientId = _isReader ? auth.user!.clientId! : _clientId!;
    final effectiveCost = _isReader
        ? 0.0
        : double.parse(_costCtrl.text.replaceAll(',', '.'));
    final effectiveStatus = _isReader ? 'new' : _status;

    final repo = context.read<OrderRepository>();
    setState(() => _saving = true);

    try {
      final order = RepairOrder(
        id: widget.id ?? 0,
        title: _titleCtrl.text.trim(),
        vin: _vinCtrl.text.trim(),
        year: int.parse(_yearCtrl.text),
        clientId: effectiveClientId,
        masterId: _masterId!,
        serviceIds: _serviceIds,
        cost: effectiveCost,
        status: effectiveStatus,
      );
      if (widget.isEditing) {
        await repo.update(order);
      } else {
        await repo.create(order);
      }
      _dirty = false;
      if (!mounted) return;
      _snack(widget.isEditing ? 'Изменения сохранены' : 'Заказ создан');
      _goBack();
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() => _serverErrors = e.errors);
      _formKey.currentState!.validate();
      _snack('Проверьте выделенные поля');
    } on ConflictException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } on UnauthorizedException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Есть несохранённые изменения'),
        content: const Text('Уйти без сохранения?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Остаться'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Уйти'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _handleBack() async {
    if (!_dirty) {
      _goBack();
      return;
    }
    final ok = await _confirmExit();
    if (!ok) return;
    _goBack();
  }

  @override
  Widget build(BuildContext context) {
    final dict = context.watch<DictionariesNotifier>();

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_loadError!)),
      );
    }

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _confirmExit();
        if (!ok) return;
        _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isEditing ? 'Редактирование заказа' : 'Новый заказ',
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              onChanged: _markDirty,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Название работ *',
                      border: const OutlineInputBorder(),
                      errorText: _serverErrors['title'],
                    ),
                    validator: (v) {
                      final r = Validators.required(v, field: 'Название');
                      if (r != null) return r;
                      return Validators.maxLength(v, 100, field: 'Название');
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _vinCtrl,
                    decoration: InputDecoration(
                      labelText: 'VIN *',
                      border: const OutlineInputBorder(),
                      errorText: _serverErrors['vin'],
                    ),
                    validator: (v) {
                      if (_serverErrors['vin'] != null) {
                        return _serverErrors['vin'];
                      }
                      return Validators.vin(v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _yearCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Год выпуска *',
                      border: const OutlineInputBorder(),
                      errorText: _serverErrors['year'],
                    ),
                    validator: (v) {
                      if (_serverErrors['year'] != null) {
                        return _serverErrors['year'];
                      }
                      return Validators.intRange(v, 1970, 2100, field: 'Год');
                    },
                  ),

                  // ← ПРАВКА: для reader'а поле «Стоимость» скрыто —
                  // цену поставит мастер/admin при обработке заказа.
                  if (!_isReader) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _costCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Стоимость, ₽ *',
                        border: const OutlineInputBorder(),
                        errorText: _serverErrors['cost'],
                      ),
                      validator: (v) {
                        if (_serverErrors['cost'] != null) {
                          return _serverErrors['cost'];
                        }
                        return Validators.positiveDouble(v, field: 'Стоимость');
                      },
                    ),
                    _CostSummary(
                      baseCost: double.tryParse(
                        _costCtrl.text.replaceAll(',', '.'),
                      ),
                      discountCategory: _selectedClient?.card?.discountCategory,
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Стоимость и статус заказа определит мастер '
                              'после осмотра автомобиля.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(),
                  const Text(
                    'Связи',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Для reader'а дропдаун «Клиент» заблокирован.
                  DropdownButtonFormField<int>(
                    initialValue: _clientId,
                    decoration: InputDecoration(
                      labelText: 'Клиент *',
                      border: const OutlineInputBorder(),
                      errorText: _serverErrors['clientId'],
                      helperText: _isReader
                          ? 'Заказ оформляется только на вас'
                          : null,
                    ),
                    items: _isReader
                        ? [
                            if (_selectedClient != null)
                              DropdownMenuItem(
                                value: _selectedClient!.id,
                                child: Text(_selectedClient!.fullName),
                              ),
                          ]
                        : dict.clients
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.fullName),
                                ),
                              )
                              .toList(),
                    onChanged: _isReader
                        ? null
                        : (v) {
                            setState(() {
                              _clientId = v;
                              _selectedClient = v == null
                                  ? null
                                  : dict.clients.firstWhere((c) => c.id == v);
                            });
                            _markDirty();
                          },
                    validator: (v) => v == null ? 'Выберите клиента' : null,
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<int>(
                    initialValue: _masterId,
                    decoration: InputDecoration(
                      labelText: 'Мастер *',
                      border: const OutlineInputBorder(),
                      errorText: _serverErrors['masterId'],
                    ),
                    items: dict.masters
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(m.fullName),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() => _masterId = v);
                      _markDirty();
                    },
                    validator: (v) => v == null ? 'Выберите мастера' : null,
                  ),
                  const SizedBox(height: 12),

                  FormField<List<int>>(
                    initialValue: _serviceIds,
                    validator: (v) {
                      if (_serverErrors['serviceIds'] != null) {
                        return _serverErrors['serviceIds'];
                      }
                      return (v == null || v.isEmpty)
                          ? 'Выберите хотя бы одну услугу'
                          : null;
                    },
                    builder: (field) {
                      return InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Услуги *',
                          border: const OutlineInputBorder(),
                          errorText: field.errorText,
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: dict.serviceTypes.map((s) {
                            final selected = field.value!.contains(s.id);
                            return FilterChip(
                              label: Text(s.name),
                              selected: selected,
                              onSelected: (_) {
                                final next = [...field.value!];
                                selected ? next.remove(s.id) : next.add(s.id);
                                field.didChange(next);
                                setState(() => _serviceIds = next);
                                _markDirty();
                              },
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),

                  // ← ПРАВКА: для reader'а «Статус» заблокирован на 'new'.
                  // Он физически не может поставить «в работе» или «завершён».
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _isReader ? 'new' : _status,
                    decoration: InputDecoration(
                      labelText: 'Статус *',
                      border: const OutlineInputBorder(),
                      errorText: _serverErrors['status'],
                      helperText: _isReader
                          ? 'Новый заказ всегда начинается со статуса «Новый»'
                          : null,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'new', child: Text('Новый')),
                      DropdownMenuItem(
                        value: 'in_progress',
                        child: Text('В работе'),
                      ),
                      DropdownMenuItem(value: 'done', child: Text('Завершён')),
                    ],
                    onChanged: _isReader
                        ? null // заблокировано
                        : (v) {
                            setState(() => _status = v ?? 'new');
                            _markDirty();
                          },
                  ),
                  const SizedBox(height: 24),

                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(widget.isEditing ? 'Сохранить' : 'Создать'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CostSummary extends StatelessWidget {
  final double? baseCost;
  final String? discountCategory;

  const _CostSummary({required this.baseCost, required this.discountCategory});

  @override
  Widget build(BuildContext context) {
    if (baseCost == null || baseCost! <= 0) {
      return const SizedBox.shrink();
    }

    final rate = DiscountCalculator.rateFor(discountCategory);
    final discount = DiscountCalculator.discountAmount(
      baseCost: baseCost!,
      discountCategory: discountCategory,
    );
    final total = DiscountCalculator.finalCost(
      baseCost: baseCost!,
      discountCategory: discountCategory,
    );

    final label = discountCategory == null
        ? 'Без карты (0%)'
        : 'Карта «$discountCategory» (${(rate * 100).toStringAsFixed(0)}%)';

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Категория скидки: $label',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            'Скидка: ${discount.toStringAsFixed(2)} ₽',
            style: const TextStyle(fontSize: 13),
          ),
          Text(
            'Итого к оплате: ${total.toStringAsFixed(2)} ₽',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
        ],
      ),
    );
  }
}
