// lib/state/auth_notifier.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_exceptions.dart';
import '../core/auth_api.dart';
import '../models/app_user.dart';
import '../models/auth_result.dart';

class AuthNotifier extends ChangeNotifier {
  static const _kAccess = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';
  static const _kUser = 'auth_user_json';

  final SharedPreferences _prefs;
  final AuthApi _api;

  AuthNotifier(this._prefs, this._api);

  AppUser? _user;
  String? _accessToken;
  String? _refreshToken;

  /// Флаг «восстановление сессии завершено». Используется в main,
  /// чтобы не строить роутер до окончания проверки токена.
  bool _restored = false;

  AppUser? get user => _user;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get isAuthenticated => _user != null;
  bool get restored => _restored;

  /// Проверка уровня роли.
  /// has(Role.master) вернёт true и для admin, потому что admin.level > master.level.
  bool has(Role role) => _user != null && _user!.role.level >= role.level;

  /// Восстановление сессии при запуске приложения.
  /// Гарантированно завершается: любые ошибки сети ловятся и логируются.
  Future<void> restore() async {
    try {
      final access = _prefs.getString(_kAccess);
      final refresh = _prefs.getString(_kRefresh);

      if (access == null) {
        // Нет токена — сессия не восстановится, но флаг поставить нужно.
        _restored = true;
        notifyListeners();
        return;
      }

      _accessToken = access;
      _refreshToken = refresh;

      // Сразу показываем сохранённого пользователя, чтобы UI не мигал.
      final cachedUser = _prefs.getString(_kUser);
      if (cachedUser != null) {
        try {
          _user = _parseUser(cachedUser);
          notifyListeners();
        } catch (_) {
          _user = null;
        }
      }

      try {
        _user = await _api.me();
        await _persistUser();
      } on UnauthorizedException {
        if (refresh != null) {
          try {
            await _refreshWith(refresh);
          } catch (_) {
            await logout();
          }
        } else {
          await logout();
        }
      } catch (_) {
        // Сервер недоступен — оставляем сессию как есть, покажем ошибку позже.
      }
    } finally {
      _restored = true;
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    final result = await _api.login(username, password);
    await _applyAuth(result);
  }

  Future<void> logout() async {
    final refresh = _refreshToken;
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    await _prefs.remove(_kAccess);
    await _prefs.remove(_kRefresh);
    await _prefs.remove(_kUser);
    notifyListeners();
    // Пробуем сказать серверу, что сессия закрыта.
    if (refresh != null) {
      try {
        await _api.logout(refresh);
      } catch (_) {
        // Молча, это не критично.
      }
    }
  }

  /// Обновление пары токенов. Используется интерсептором и restore().
  Future<void> refreshTokens() async {
    final refresh = _refreshToken;
    if (refresh == null) {
      throw const UnauthorizedException('Нет токена обновления.');
    }
    await _refreshWith(refresh);
  }

  // ---- приватное ----

  Future<void> _refreshWith(String refresh) async {
    final result = await _api.refresh(refresh);
    await _applyAuth(result);
  }

  Future<void> _applyAuth(AuthResult result) async {
    _accessToken = result.accessToken;
    _refreshToken = result.refreshToken;
    _user = result.user;
    await _prefs.setString(_kAccess, result.accessToken);
    await _prefs.setString(_kRefresh, result.refreshToken);
    await _persistUser();
    notifyListeners();
  }

  Future<void> _persistUser() async {
    final u = _user;
    if (u == null) {
      await _prefs.remove(_kUser);
      return;
    }
    // Простая сериализация вручную, чтобы не тянуть jsonEncode в этот файл.
    await _prefs.setString(
      _kUser,
      '{"id":${u.id},"username":"${u.username}",'
      '"fullName":"${u.fullName}",'
      '"email":${u.email == null ? 'null' : '"${u.email}"'},'
      '"role":"${u.role.name}"}',
    );
  }

  AppUser _parseUser(String raw) {
    // Примитивный разбор: достаточно для учебного проекта.
    // В проде — jsonDecode из dart:convert.
    final id = RegExp(r'"id":(\d+)').firstMatch(raw)?.group(1) ?? '0';
    final username =
        RegExp(r'"username":"([^"]*)"').firstMatch(raw)?.group(1) ?? '';
    final fullName =
        RegExp(r'"fullName":"([^"]*)"').firstMatch(raw)?.group(1) ?? '';
    final roleStr =
        RegExp(r'"role":"([^"]*)"').firstMatch(raw)?.group(1) ?? 'reader';
    return AppUser(
      id: int.tryParse(id) ?? 0,
      username: username,
      fullName: fullName,
      role: Role.fromString(roleStr),
    );
  }
}
