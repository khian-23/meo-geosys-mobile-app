import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';

class SessionController extends ChangeNotifier {
  SessionController()
      : api = ApiClient(baseUrl: _resolveBaseUrl());

  static String _resolveBaseUrl() {
    if (kIsWeb) {
      return 'http://localhost/MEO-Geosys/mobile_backend';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2/MEO-Geosys/mobile_backend';
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return 'http://localhost/MEO-Geosys/mobile_backend';
      case TargetPlatform.iOS:
        return 'http://localhost/MEO-Geosys/mobile_backend';
      case TargetPlatform.fuchsia:
        return 'http://localhost/MEO-Geosys/mobile_backend';
    }
  }

  final ApiClient api;

  String? token;
  Map<String, dynamic>? profile;
  bool isBusy = false;

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('mobile_token');
      if (savedToken == null || savedToken.isEmpty) return;

      token = savedToken;
      api.token = savedToken;
      final data = await api.me();
      profile = Map<String, dynamic>.from(data['user'] as Map);
    } catch (_) {
      token = null;
      profile = null;
      api.token = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('mobile_token');
    } finally {
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    isBusy = true;
    notifyListeners();
    try {
      final data = await api.login(email, password);
      token = data['token'] as String;
      profile = Map<String, dynamic>.from(data['user'] as Map);
      api.token = token;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mobile_token', token!);
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> register(Map<String, dynamic> payload) async {
    isBusy = true;
    notifyListeners();
    try {
      final data = await api.register(payload);
      token = data['token'] as String;
      profile = Map<String, dynamic>.from(data['user'] as Map);
      api.token = token;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mobile_token', token!);
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    token = null;
    profile = null;
    api.token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mobile_token');
    notifyListeners();
  }
}
