// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../state/auth_notifier.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Автосервис'),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  '${user.fullName} (${user.role.label})',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthNotifier>().logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Разделы',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // «Заказы» — для master/admin. Reader и так попадает
            // на свои заказы через отдельный пункт «Мои заказы».
            if (user?.role != Role.reader)
              _tile(
                context,
                icon: Icons.build,
                title: 'Заказы',
                onTap: () => context.go('/orders'),
              ),

            // Только reader — «мои заказы»
            if (user?.role == Role.reader)
              _tile(
                context,
                icon: Icons.assignment_ind,
                title: 'Мои заказы',
                onTap: () => context.go('/my-orders'),
              ),

            // Только master и admin — клиенты и мастера
            if (auth.has(Role.master)) ...[
              _tile(
                context,
                icon: Icons.people,
                title: 'Клиенты',
                onTap: () => context.go('/clients'),
              ),
              _tile(
                context,
                icon: Icons.handyman,
                title: 'Мастера',
                onTap: () => context.go('/masters'),
              ),
              _tile(
                context,
                icon: Icons.construction,
                title: 'Услуги',
                onTap: () => context.go('/services'),
              ),
            ],

            // Только admin
            if (auth.has(Role.admin))
              _tile(
                context,
                icon: Icons.admin_panel_settings,
                title: 'Пользователи',
                onTap: () => context.go('/admin/users'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
