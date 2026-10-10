// lib/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'models/app_user.dart';
import 'screens/app_shell.dart';
import 'screens/client_details_screen.dart';
import 'screens/client_form_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/forbidden_screen.dart';
import 'screens/login_screen.dart';
import 'screens/master_form_screen.dart';
import 'screens/masters_screen.dart';
import 'screens/my_orders_screen.dart';
import 'screens/order_details_screen.dart';
import 'screens/order_form_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/register_screen.dart';
import 'screens/service_type_form_screen.dart';
import 'screens/service_types_screen.dart';
import 'screens/users_screen.dart';
import 'state/auth_notifier.dart';

GoRouter buildRouter(AuthNotifier auth) {
  return GoRouter(
    refreshListenable: auth,
    // Начинаем с /login. Если пользователь уже авторизован,
    // глобальный redirect ниже отправит его на /.
    initialLocation: '/login',
    redirect: (context, state) {
      final loggedIn = auth.isAuthenticated;
      final target = state.matchedLocation;
      final isPublic = target == '/login' || target == '/register';

      // НЕ редиректим с публичных экранов, если пользователь
      // не авторизован. Иначе получится бесконечный цикл.
      if (isPublic) {
        if (loggedIn) return '/';
        return null;
      }

      // Не авторизован и идёт на закрытый экран → на /login,
      // запомнив исходный адрес.
      if (!loggedIn) {
        final from = Uri.encodeComponent(state.uri.toString());
        return '/login?from=$from';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (c, s) => LoginScreen(from: s.uri.queryParameters['from']),
      ),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),

      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          // ---- Главная ----
          GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),

          // ---- Экран отказа — доступен любому авторизованному ----
          GoRoute(
            path: '/forbidden',
            builder: (_, _) => const ForbiddenScreen(),
          ),

          // ---- Заказы ----
          GoRoute(
            path: '/orders',
            builder: (context, state) =>
                OrdersScreen(urlParams: state.uri.queryParameters),
            routes: [
              GoRoute(path: 'new', builder: (_, _) => const OrderFormScreen()),
              GoRoute(
                path: ':id/edit',
                builder: (_, s) => OrderFormScreen(
                  id: int.tryParse(s.pathParameters['id'] ?? ''),
                ),
              ),
              GoRoute(
                path: ':id',
                builder: (_, s) =>
                    OrderDetailsScreen(id: int.parse(s.pathParameters['id']!)),
              ),
            ],
          ),

          // ---- Мои заказы — только reader ----
          GoRoute(
            path: '/my-orders',
            builder: (_, _) => const MyOrdersScreen(),
            redirect: (_, _) =>
                auth.user?.role == Role.reader ? null : '/forbidden',
          ),

          // ---- Клиенты — master и admin ----
          GoRoute(
            path: '/clients',
            redirect: (_, _) => auth.has(Role.master) ? null : '/forbidden',
            builder: (_, _) => const ClientsScreen(),
            routes: [
              GoRoute(path: 'new', builder: (_, _) => const ClientFormScreen()),
              GoRoute(
                path: ':id/edit',
                builder: (_, s) => ClientFormScreen(
                  id: int.tryParse(s.pathParameters['id'] ?? ''),
                ),
              ),
              GoRoute(
                path: ':id',
                builder: (_, s) =>
                    ClientDetailsScreen(id: int.parse(s.pathParameters['id']!)),
              ),
            ],
          ),

          // ---- Мастера — master и admin ----
          GoRoute(
            path: '/masters',
            redirect: (_, _) => auth.has(Role.master) ? null : '/forbidden',
            builder: (_, _) => const MastersScreen(),
            routes: [
              GoRoute(path: 'new', builder: (_, _) => const MasterFormScreen()),
              GoRoute(
                path: ':id/edit',
                builder: (_, s) => MasterFormScreen(
                  id: int.tryParse(s.pathParameters['id'] ?? ''),
                ),
              ),
            ],
          ),

          // ---- Услуги — master и admin ----
          GoRoute(
            path: '/services',
            redirect: (_, _) => auth.has(Role.master) ? null : '/forbidden',
            builder: (_, _) => const ServiceTypesScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) => const ServiceTypeFormScreen(),
              ),
              GoRoute(
                path: ':id/edit',
                builder: (_, s) => ServiceTypeFormScreen(
                  id: int.tryParse(s.pathParameters['id'] ?? ''),
                ),
              ),
            ],
          ),

          // ---- Пользователи — только admin ----
          GoRoute(
            path: '/admin/users',
            redirect: (_, _) => auth.has(Role.admin) ? null : '/forbidden',
            builder: (_, _) => const UsersScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (c, s) =>
        Scaffold(body: Center(child: Text('Страница не найдена: ${s.uri}'))),
  );
}
