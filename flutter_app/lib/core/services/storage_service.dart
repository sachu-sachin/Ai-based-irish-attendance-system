import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod/riverpod.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();

  // Storage keys
  static const String _tokenKey = 'auth_token';
  static const String _usernameKey = 'username';
  static const String _roleKey = 'role';
  static const String _rememberMeKey = 'remember_me';
  static const String _baseUrlKey = 'base_url';
  static const String _themeModeKey = 'theme_mode';

  // Authentication
  Future<void> saveAuthToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getAuthToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> removeAuthToken() async {
    await _storage.delete(key: _tokenKey);
  }

  Future<void> saveUserInfo(String username, String role) async {
    await Future.wait([
      _storage.write(key: _usernameKey, value: username),
      _storage.write(key: _roleKey, value: role),
    ]);
  }

  Future<String?> getUsername() async {
    return await _storage.read(key: _usernameKey);
  }

  Future<String?> getRole() async {
    return await _storage.read(key: _roleKey);
  }

  Future<void> removeUserInfo() async {
    await Future.wait([
      _storage.delete(key: _usernameKey),
      _storage.delete(key: _roleKey),
    ]);
  }

  // Remember me
  Future<void> setRememberMe(bool remember) async {
    await _storage.write(key: _rememberMeKey, value: remember.toString());
  }

  Future<bool> getRememberMe() async {
    final value = await _storage.read(key: _rememberMeKey);
    return value == 'true';
  }

  // Base URL
  Future<void> saveBaseUrl(String url) async {
    await _storage.write(key: _baseUrlKey, value: url);
  }

  Future<String> getBaseUrl() async {
    return await _storage.read(key: _baseUrlKey) ??
        'http://192.168.157.61:8001';
  }

  // Theme mode
  Future<void> setThemeMode(String themeMode) async {
    await _storage.write(key: _themeModeKey, value: themeMode);
  }

  Future<String?> getThemeMode() async {
    return await _storage.read(key: _themeModeKey);
  }

  // Clear all data
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }
}

// Provider
final storageServiceProvider =
    Provider<StorageService>((ref) => StorageService());
