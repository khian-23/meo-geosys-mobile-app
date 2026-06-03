import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';

// ---------------------------------------------------------------------------
// Local demo store — used when the backend is unreachable.
// Registered users are persisted in SharedPreferences under the key
// '_local_users' as a JSON array.  The token is a simple base64 of the email.
// ---------------------------------------------------------------------------
class _LocalStore {
  static const _usersKey = '_local_users';

  static String _token(String email) => base64UrlEncode(utf8.encode(email));

  static Future<List<Map<String, dynamic>>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usersKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>().toList();
  }

  static Future<void> _save(List<Map<String, dynamic>> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usersKey, jsonEncode(users));
  }

  static Future<Map<String, dynamic>?> findByEmail(String email) async {
    final users = await _load();
    try {
      return users.firstWhere(
          (u) => (u['email'] as String).toLowerCase() == email.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  /// Returns a fake auth response identical in shape to the real API response.
  static Future<Map<String, dynamic>> register(
      Map<String, dynamic> payload) async {
    final users = await _load();
    final email = (payload['email'] as String).toLowerCase();
    final exists =
        users.any((u) => (u['email'] as String).toLowerCase() == email);
    if (exists) {
      throw ApiException('An account with that email already exists.');
    }
    final user = {
      'id': users.length + 1,
      'first_name': payload['first_name'] ?? '',
      'middle_name': payload['middle_name'] ?? '',
      'last_name': payload['last_name'] ?? '',
      'email': email,
      'phone': payload['phone'] ?? '',
      'address': payload['address'] ?? '',
      'barangay_name': payload['barangay_name'] ?? '',
      // Store password hashed with a trivial XOR — this is purely local dev.
      '_pw': payload['password'] ?? '',
    };
    users.add(user);
    await _save(users);
    final publicUser = Map<String, dynamic>.from(user)..remove('_pw');
    return {
      'success': true,
      'token': _token(email),
      'user': publicUser,
    };
  }

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final user = await findByEmail(email);
    if (user == null) {
      throw ApiException('No account found with that email. Please register.');
    }
    if (user['_pw'] != password) {
      throw ApiException('Incorrect password.');
    }
    final publicUser = Map<String, dynamic>.from(user)..remove('_pw');
    return {
      'success': true,
      'token': _token(email),
      'user': publicUser,
    };
  }
}

// ---------------------------------------------------------------------------
// SessionController
// ---------------------------------------------------------------------------
class SessionController extends ChangeNotifier {
  SessionController() : api = ApiClient(baseUrl: _resolveBaseUrl());

  static String _resolveBaseUrl() {
    // When running as a web app (including via ngrok on iPhone),
    // call the backend relative to the same origin so we don't
    // hardcode any hostname.
    if (kIsWeb) {
      return '/MEO-Geosys/mobile_backend';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2/MEO-Geosys/mobile_backend';
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return 'http://localhost/MEO-Geosys/mobile_backend';
    }
  }

  final ApiClient api;

  String? token;
  Map<String, dynamic>? profile;
  bool isBusy = false;

  // When true the session is backed by local storage, not the remote API.
  bool get isLocalMode => _localMode;
  bool _localMode = false;

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  // -------------------------------------------------------------------------
  // Restore on startup
  // -------------------------------------------------------------------------
  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('mobile_token');
      final localMode = prefs.getBool('mobile_local_mode') ?? false;

      if (savedToken == null || savedToken.isEmpty) return;

      token = savedToken;
      _localMode = localMode;

      if (localMode) {
        // Restore profile from prefs (we serialise it on login/register).
        final profileJson = prefs.getString('mobile_profile');
        if (profileJson != null) {
          profile = jsonDecode(profileJson) as Map<String, dynamic>;
        }
      } else {
        api.token = savedToken;
        final data = await api.me();
        profile = Map<String, dynamic>.from(data['user'] as Map);
      }
    } catch (_) {
      await _clearSession();
    } finally {
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------------
  // Login — tries remote API first, falls back to local store.
  // -------------------------------------------------------------------------
  Future<void> login(String email, String password) async {
    isBusy = true;
    notifyListeners();
    try {
      // Try remote first.
      try {
        final data = await api.login(email, password);
        await _applyRemoteAuth(data);
        _localMode = false;
      } on ApiException {
        // Re-throw real API errors (wrong password, not found, etc.)
        rethrow;
      } catch (_) {
        // Network / connection error — fall back to local store.
        final data = await _LocalStore.login(email, password);
        await _applyLocalAuth(data);
        _localMode = true;
      }
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------------
  // Register — tries remote API first, falls back to local store.
  // -------------------------------------------------------------------------
  Future<void> register(Map<String, dynamic> payload) async {
    isBusy = true;
    notifyListeners();
    try {
      try {
        final data = await api.register(payload);
        await _applyRemoteAuth(data);
        _localMode = false;
      } on ApiException {
        rethrow;
      } catch (_) {
        // Network error — use local store.
        final data = await _LocalStore.register(payload);
        await _applyLocalAuth(data);
        _localMode = true;
      }
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------------
  // Logout
  // -------------------------------------------------------------------------
  Future<void> logout() async {
    await _clearSession();
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------
  Future<void> _applyRemoteAuth(Map<String, dynamic> data) async {
    token = data['token'] as String;
    profile = Map<String, dynamic>.from(data['user'] as Map);
    api.token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mobile_token', token!);
    await prefs.setBool('mobile_local_mode', false);
    await prefs.setString('mobile_profile', jsonEncode(profile));
  }

  Future<void> _applyLocalAuth(Map<String, dynamic> data) async {
    token = data['token'] as String;
    profile = Map<String, dynamic>.from(data['user'] as Map);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mobile_token', token!);
    await prefs.setBool('mobile_local_mode', true);
    await prefs.setString('mobile_profile', jsonEncode(profile));
  }

  Future<void> _clearSession() async {
    token = null;
    profile = null;
    api.token = null;
    _localMode = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mobile_token');
    await prefs.remove('mobile_local_mode');
    await prefs.remove('mobile_profile');
  }
}
