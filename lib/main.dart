// lib/main.dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'core/auth_api.dart';
import 'repositories/api_client_repository.dart';
import 'repositories/api_master_repository.dart';
import 'repositories/api_repair_order_repository.dart';
import 'repositories/api_service_type_repository.dart';
import 'repositories/client_repository.dart';
import 'repositories/order_repository.dart';
import 'router.dart';
import 'state/auth_notifier.dart';
import 'state/client_list_notifier.dart';
import 'state/dictionaries_notifier.dart';
import 'state/order_list_notifier.dart';
import 'widgets/inactivity_watcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // usePathUrlStrategy может бросить исключение, если в web/index.html
  // тег <base> без завершающего слэша. Оборачиваем в try/catch,
  // чтобы приложение всё равно запустилось.
  try {
    usePathUrlStrategy();
  } catch (e) {
    debugPrint('usePathUrlStrategy failed: $e');
  }

  final prefs = await SharedPreferences.getInstance();

  late AuthNotifier auth;
  late AuthApi authApi;

  final dio = buildDio(
    tokenProvider: () => auth.accessToken,
    refreshHandler: () async {
      try {
        await auth.refreshTokens();
        return true;
      } catch (_) {
        await auth.logout();
        return false;
      }
    },
  );

  authApi = AuthApi(dio);
  auth = AuthNotifier(prefs, authApi);

  // Не блокируем runApp на сетевом запросе: восстановление сессии
  // идёт в фоне, UI показывается сразу.
  unawaited(auth.restore());

  runApp(
    MultiProvider(
      providers: [
        Provider<SharedPreferences>.value(value: prefs),
        Provider<Dio>.value(value: dio),
        Provider<AuthApi>.value(value: authApi),
        ChangeNotifierProvider<AuthNotifier>.value(value: auth),

        ProxyProvider<Dio, OrderRepository>(
          update: (_, d, _) => ApiRepairOrderRepository(d),
        ),
        ProxyProvider<Dio, ClientRepository>(
          update: (_, d, _) => ApiClientRepository(d),
        ),
        ProxyProvider<Dio, ApiMasterRepository>(
          update: (_, d, _) => ApiMasterRepository(d),
        ),
        ProxyProvider<Dio, ApiServiceTypeRepository>(
          update: (_, d, _) => ApiServiceTypeRepository(d),
        ),

        ChangeNotifierProvider(
          create: (ctx) => OrderListNotifier(ctx.read<OrderRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => ClientListNotifier(ctx.read<ClientRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => DictionariesNotifier(
            ctx.read<ClientRepository>(),
            ctx.read<ApiMasterRepository>(),
            ctx.read<ApiServiceTypeRepository>(),
          ),
        ),
      ],
      child: const AutoServiceApp(),
    ),
  );
}

class AutoServiceApp extends StatefulWidget {
  const AutoServiceApp({super.key});

  @override
  State<AutoServiceApp> createState() => _AutoServiceAppState();
}

class _AutoServiceAppState extends State<AutoServiceApp> {
  GoRouter? _router;
  AuthNotifier? _authForRouter;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();

    // Пока восстановление сессии не завершено — свой Material-экран
    // загрузки. Это гарантирует, что Flutter построил первый кадр.
    if (!auth.restored) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Автосервис',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 16),
                CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      );
    }

    // GoRouter создаём один раз и переиспользуем.
    // Новый экземпляр создаётся только если AuthNotifier подменили
    // (в этом проекте такого не происходит, но проверка есть).
    if (_router == null || _authForRouter != auth) {
      _authForRouter = auth;
      _router = buildRouter(auth);
    }

    return MaterialApp.router(
      title: 'Автосервис',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      routerConfig: _router!,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        if (!auth.isAuthenticated) return content;

        return InactivityWatcher(
          timeout: const Duration(minutes: 3),
          warningBefore: const Duration(seconds: 30),
          onWarning: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Сессия завершится через 30 секунд без активности',
                ),
                duration: Duration(seconds: 5),
              ),
            );
          },
          onTimeout: () async {
            await auth.logout();
          },
          child: content,
        );
      },
    );
  }
}
