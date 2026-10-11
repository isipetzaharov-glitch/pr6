// lib/screens/app_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../state/auth_notifier.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final loc = GoRouterState.of(context).uri.toString();
    final isReader = auth.user?.role == Role.reader;

    // Индексы считаем отдельно под каждую роль,
    // чтобы не путать «Заказы» (master) и «Мои заказы» (reader).
    final int idx;
    if (isReader) {
      // reader: 0 — «Мои заказы», 1 — «Главная»
      idx = loc.startsWith('/my-orders') ? 0 : 1;
    } else {
      // master/admin: 0 — «Заказы», 1 — «Клиенты», 2 — «Мастера», 3 — «Услуги»
      idx = loc.startsWith('/clients')
          ? 1
          : loc.startsWith('/masters')
          ? 2
          : loc.startsWith('/services')
          ? 3
          : 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Автосервис'),
        actions: [
          IconButton(
            tooltip: 'Главная',
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
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
      body: Column(
        children: [
          if (auth.user != null)
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${auth.user!.fullName} (${auth.user!.role.label})',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: _buildBar(context, isReader, idx),
    );
  }

  Widget _buildBar(BuildContext context, bool isReader, int idx) {
    // Для reader — «Мои заказы» + «Главная» (минимум два пункта нужен
    // для NavigationBar, плюс удобный возврат на дашборд).
    // Для master/admin — «Заказы», «Клиенты», «Мастера», «Услуги».
    final destinations = <NavigationDestination>[
      if (isReader) ...[
        const NavigationDestination(
          icon: Icon(Icons.assignment_ind),
          label: 'Мои заказы',
        ),
        const NavigationDestination(icon: Icon(Icons.home), label: 'Главная'),
      ] else ...[
        const NavigationDestination(icon: Icon(Icons.build), label: 'Заказы'),
        const NavigationDestination(icon: Icon(Icons.people), label: 'Клиенты'),
        const NavigationDestination(
          icon: Icon(Icons.handyman),
          label: 'Мастера',
        ),
        const NavigationDestination(
          icon: Icon(Icons.construction),
          label: 'Услуги',
        ),
      ],
    ];

    return NavigationBar(
      selectedIndex: idx.clamp(0, destinations.length - 1),
      onDestinationSelected: (i) {
        if (isReader) {
          switch (i) {
            case 0:
              context.go('/my-orders');
              break;
            case 1:
              context.go('/');
              break;
          }
        } else {
          switch (i) {
            case 0:
              context.go('/orders');
              break;
            case 1:
              context.go('/clients');
              break;
            case 2:
              context.go('/masters');
              break;
            case 3:
              context.go('/services');
              break;
          }
        }
      },
      destinations: destinations,
    );
  }
}
