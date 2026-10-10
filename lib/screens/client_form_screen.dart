// lib/screens/client_form_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../models/client.dart';
import '../models/service_card.dart';
import '../repositories/client_repository.dart';
import '../utils/validators.dart';

class ClientFormScreen extends StatefulWidget {
  final int? id;
  const ClientFormScreen({super.key, this.id});

  bool get isEditing => id != null;

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lastNameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  bool _hasCard = false;
  final _cardNumberCtrl = TextEditingController();
  String _discountCategory = 'обычный';

  bool _loading = true;
  bool _saving = false;
  Map<String, String> _serverErrors = {};
  String? _uniqueEmailError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<ClientRepository>();
    if (widget.isEditing) {
      try {
        final c = await repo.findById(widget.id!);
        if (!mounted) return;
        if (c != null) {
          _lastNameCtrl.text = c.lastName;
          _firstNameCtrl.text = c.firstName;
          _emailCtrl.text = c.email;
          _phoneCtrl.text = c.phone;
          _countryCtrl.text = c.country;
          if (c.card != null) {
            _hasCard = true;
            _cardNumberCtrl.text = c.card!.number;
            _discountCategory = c.card!.discountCategory;
          }
        }
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _lastNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _countryCtrl.dispose();
    _cardNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _serverErrors = {};
      _uniqueEmailError = null;
    });

    final repo = context.read<ClientRepository>();
    final email = _emailCtrl.text.trim();

    try {
      final exists = await repo.emailExists(email, exceptId: widget.id);
      if (exists) {
        setState(() => _uniqueEmailError = 'Такой email уже используется');
        return;
      }
    } on ApiException {
      // не блокируем, проверит 422/409
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final client = Client(
        id: widget.id ?? 0,
        lastName: _lastNameCtrl.text.trim(),
        firstName: _firstNameCtrl.text.trim(),
        email: email,
        phone: _phoneCtrl.text.trim(),
        country: _countryCtrl.text.trim(),
        card: _hasCard
            ? ServiceCard(
                number: _cardNumberCtrl.text.trim(),
                issuedAt: DateTime.now(),
                discountCategory: _discountCategory,
              )
            : null,
      );
      if (widget.isEditing) {
        await repo.update(client);
      } else {
        await repo.create(client);
      }
      if (!mounted) return;
      context.go('/clients');
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() => _serverErrors = e.errors);
      _formKey.currentState!.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Проверьте выделенные поля')),
      );
    } on ConflictException catch (e) {
      if (!mounted) return;
      setState(() => _uniqueEmailError = e.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Редактирование клиента' : 'Новый клиент',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _lastNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Фамилия *',
                    border: const OutlineInputBorder(),
                    errorText: _serverErrors['lastName'],
                  ),
                  validator: (v) {
                    if (_serverErrors['lastName'] != null) {
                      return _serverErrors['lastName'];
                    }
                    final r = Validators.required(v, field: 'Фамилия');
                    if (r != null) return r;
                    return Validators.maxLength(v, 50, field: 'Фамилия');
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _firstNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Имя *',
                    border: const OutlineInputBorder(),
                    errorText: _serverErrors['firstName'],
                  ),
                  validator: (v) {
                    if (_serverErrors['firstName'] != null) {
                      return _serverErrors['firstName'];
                    }
                    return Validators.required(v, field: 'Имя');
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(
                    labelText: 'Email *',
                    border: const OutlineInputBorder(),
                    errorText: _serverErrors['email'] ?? _uniqueEmailError,
                  ),
                  validator: (v) {
                    if (_serverErrors['email'] != null) {
                      return _serverErrors['email'];
                    }
                    return Validators.email(v);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: InputDecoration(
                    labelText: 'Телефон *',
                    border: const OutlineInputBorder(),
                    errorText: _serverErrors['phone'],
                  ),
                  validator: (v) {
                    if (_serverErrors['phone'] != null) {
                      return _serverErrors['phone'];
                    }
                    return Validators.phone(v);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _countryCtrl,
                  decoration: InputDecoration(
                    labelText: 'Страна *',
                    border: const OutlineInputBorder(),
                    errorText: _serverErrors['country'],
                  ),
                  validator: (v) {
                    if (_serverErrors['country'] != null) {
                      return _serverErrors['country'];
                    }
                    return Validators.required(v, field: 'Страна');
                  },
                ),
                const SizedBox(height: 16),
                const Divider(),
                SwitchListTile(
                  title: const Text('Есть сервисная карта'),
                  subtitle: const Text('Связь 1-к-1'),
                  value: _hasCard,
                  onChanged: (v) => setState(() => _hasCard = v),
                ),
                if (_hasCard) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _cardNumberCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Номер карты *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => _hasCard
                        ? Validators.required(v, field: 'Номер карты')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _discountCategory,
                    decoration: const InputDecoration(
                      labelText: 'Категория скидки',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'обычный',
                        child: Text('Обычный'),
                      ),
                      DropdownMenuItem(
                        value: 'серебро',
                        child: Text('Серебро'),
                      ),
                      DropdownMenuItem(value: 'золото', child: Text('Золото')),
                    ],
                    onChanged: (v) =>
                        setState(() => _discountCategory = v ?? 'обычный'),
                  ),
                ],
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
    );
  }
}
