import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  final StorageService _storageService;
  final ApiService _apiService;

  AuthService(this._storageService, this._apiService);

  // Getters
  Future<bool> get isAuthenticated async {
    final token = await _storageService.getAuthToken();
    if (token == null) return false;
    try {
      return !JwtDecoder.isExpired(token);
    } catch (e) {
      return false;
    }
  }

  Future<String?> get username => _storageService.getUsername();
  Future<String?> get role => _storageService.getRole();

  // Login
  Future<LoginResult> login(String username, String password,
      {bool rememberMe = false}) async {
    try {
      print('AuthService: Attempting login for $username');
      final response = await _apiService.login(LoginRequest(
        username: username,
        password: password,
      ));

      final userMap = response.user;
      final uname = userMap['username'] as String? ?? username;
      final urole = userMap['role'] as String? ?? 'admin';

      await _storageService.saveAuthToken(response.accessToken);
      await _storageService.saveUserInfo(uname, urole);
      await _storageService.setRememberMe(rememberMe);

      return LoginResult.success(uname, urole);
    } on DioException catch (e) {
      final url = '${_apiService.dio.options.baseUrl}/auth/login';
      print(
          'AuthService: DioException - Type: ${e.type}, Message: ${e.message}');
      print('AuthService: DioException - response: ${e.response?.data}');
      if (e.response?.statusCode == 401) {
        return LoginResult.failure('Invalid username or password', url: url);
      } else if (e.response?.statusCode == 403) {
        return LoginResult.failure('Account is inactive', url: url);
      } else {
        return LoginResult.failure('Network error (${e.type}): ${e.message}',
            url: url);
      }
    } catch (e) {
      final url = '${_apiService.dio.options.baseUrl}/auth/login';
      print('AuthService: Unexpected exception - $e, URL: $url');
      return LoginResult.failure('An unexpected error occurred: $e', url: url);
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _apiService.logout();
    } catch (e) {
      print('Logout API call failed: $e');
    }
    await _storageService.removeAuthToken();
    await _storageService.removeUserInfo();
  }

  // Change password
  Future<PasswordChangeResult> changePassword(
      String currentPassword, String newPassword) async {
    try {
      await _apiService.changePassword(PasswordChangeRequest(
        currentPassword: currentPassword,
        newPassword: newPassword,
      ));
      return PasswordChangeResult.success();
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        return PasswordChangeResult.failure('Current password is incorrect');
      } else {
        return PasswordChangeResult.failure('Network error: ${e.message}');
      }
    } catch (e) {
      return PasswordChangeResult.failure('An unexpected error occurred');
    }
  }

  bool get isAdmin => false; // sync stub; real check done via role in storage
}

// ─── Result classes ───────────────────────────

class LoginResult {
  final bool success;
  final String? username;
  final String? role;
  final String? error;
  final String? url;

  // Keep a legacy `user` getter for the login screen which calls result.success
  LoginResult._(
      {required this.success, this.username, this.role, this.error, this.url});

  factory LoginResult.success(String username, String role) =>
      LoginResult._(success: true, username: username, role: role);

  factory LoginResult.failure(String error, {String? url}) =>
      LoginResult._(success: false, error: error, url: url);
}

class PasswordChangeResult {
  final bool success;
  final String? error;

  PasswordChangeResult._({required this.success, this.error});

  factory PasswordChangeResult.success() =>
      PasswordChangeResult._(success: true);
  factory PasswordChangeResult.failure(String error) =>
      PasswordChangeResult._(success: false, error: error);
}

// ─── Providers ────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  final apiService = ref.read(apiServiceProvider);
  return AuthService(storageService, apiService);
});

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(AuthState.initial()) {
    _init();
  }

  Future<void> _init() async {
    final isAuthenticated = await _authService.isAuthenticated;
    final username = await _authService.username;
    final role = await _authService.role;

    state = state.copyWith(
      isLoading: false,
      isAuthenticated: isAuthenticated,
      username: username,
      role: role,
      isAdmin: role == 'admin',
    );
  }

  Future<void> refreshAuth() => _init();
}

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? username;
  final String? role;
  final bool isAdmin;

  AuthState({
    required this.isLoading,
    required this.isAuthenticated,
    this.username,
    this.role,
    required this.isAdmin,
  });

  factory AuthState.initial() =>
      AuthState(isLoading: true, isAuthenticated: false, isAdmin: false);

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? username,
    String? role,
    bool? isAdmin,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      username: username ?? this.username,
      role: role ?? this.role,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}
