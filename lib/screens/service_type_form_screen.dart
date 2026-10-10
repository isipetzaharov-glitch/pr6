// lib/screens/service_type_form_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../models/service_type.dart';
import '../repositories/api_service_type_repository.dart';
import '../utils/validators.dart';

class ServiceTypeFormScreen extends StatefulWidget {
  final int? id;
  const ServiceTypeFormScreen({super.key, this.id});

  bool get isEditing => id != null;

  @override
  State<ServiceTypeFormScreen> createState() => _ServiceTypeFormScreenState();
}

class _ServiceTypeFormScreenState extends State<ServiceTypeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  bool _saving = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      final repo = context.read<ApiServiceTypeRepository>();
      final s = repo.all.firstWhere(
        (x) => x.id == widget.id,
        orElse: () => const ServiceType(id: 0, name: ''),
      );
      _nameCtrl.text = s.name;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _serverError = null);
    if (!_formKey.currentState!.validate()) return;

    final repo = context.read<ApiServiceTypeRepository>();
    setState(() => _saving = true);

    try {
      if (widget.isEditing) {
        await repo.update(
          ServiceType(id: widget.id!, name: _nameCtrl.text.trim()),
        );
      } else {
        await repo.create(ServiceType(id: 0, name: _nameCtrl.text.trim()));
      }
      if (!mounted) return;
      Navigator.pop(context);
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() => _serverError = e.errors['name'] ?? e.message);
      _formKey.currentState!.validate();
    } on ConflictException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Редактирование услуги' : 'Новая услуга',
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
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Название услуги *',
                    border: const OutlineInputBorder(),
                    errorText: _serverError,
                  ),
                  validator: (v) {
                    if (_serverError != null) return _serverError;
                    final r = Validators.required(v, field: 'Название');
                    if (r != null) return r;
                    return Validators.maxLength(v, 60, field: 'Название');
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
    );
  }
}
