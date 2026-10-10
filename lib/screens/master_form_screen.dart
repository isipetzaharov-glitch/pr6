// lib/screens/master_form_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../models/master.dart';
import '../repositories/api_master_repository.dart';
import '../utils/validators.dart';

class MasterFormScreen extends StatefulWidget {
  final int? id;
  const MasterFormScreen({super.key, this.id});

  bool get isEditing => id != null;

  @override
  State<MasterFormScreen> createState() => _MasterFormScreenState();
}

class _MasterFormScreenState extends State<MasterFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _specCtrl = TextEditingController();

  bool _saving = false;
  Map<String, String> _serverErrors = {};

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      final repo = context.read<ApiMasterRepository>();
      final m = repo.all.firstWhere(
        (x) => x.id == widget.id,
        orElse: () => const Master(id: 0, fullName: '', specialization: ''),
      );
      _nameCtrl.text = m.fullName;
      _specCtrl.text = m.specialization;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _specCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _serverErrors = {});
    if (!_formKey.currentState!.validate()) return;

    final repo = context.read<ApiMasterRepository>();
    setState(() => _saving = true);

    try {
      if (widget.isEditing) {
        await repo.update(
          Master(
            id: widget.id!,
            fullName: _nameCtrl.text.trim(),
            specialization: _specCtrl.text.trim(),
          ),
        );
      } else {
        await repo.create(
          Master(
            id: 0,
            fullName: _nameCtrl.text.trim(),
            specialization: _specCtrl.text.trim(),
          ),
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() => _serverErrors = e.errors);
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
          widget.isEditing ? 'Редактирование мастера' : 'Новый мастер',
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
                    labelText: 'ФИО *',
                    border: const OutlineInputBorder(),
                    errorText: _serverErrors['fullName'],
                  ),
                  validator: (v) {
                    if (_serverErrors['fullName'] != null) {
                      return _serverErrors['fullName'];
                    }
                    return Validators.required(v, field: 'ФИО');
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _specCtrl,
                  decoration: InputDecoration(
                    labelText: 'Специализация *',
                    border: const OutlineInputBorder(),
                    errorText: _serverErrors['specialization'],
                  ),
                  validator: (v) {
                    if (_serverErrors['specialization'] != null) {
                      return _serverErrors['specialization'];
                    }
                    return Validators.required(v, field: 'Специализация');
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
