import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/territory.dart';
import '../services/api_service.dart';
import '../services/offline_run_service.dart';

class AppState extends ChangeNotifier {
  final ApiService api = ApiService.instance;

  User? user;
  bool loading = true;
  String? error;
  List<Territory> territories = [];
  List<LeaderboardEntry> leaderboard = [];

  bool get isLoggedIn => user != null;
  bool get isAdmin => user?.isAdmin == true;

  Future<void> _saveCachedUser(User u) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user', jsonEncode({'id': u.id, 'username': u.username, 'isAdmin': u.isAdmin}));
  }

  Future<User?> _loadCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cached_user');
    if (raw == null) return null;
    try {
      return User.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    loading = true;
    notifyListeners();
    try {
      await api.loadToken();
      if (api.hasToken) {
        try {
          user = await api.me();
          await _saveCachedUser(user!);
          await refreshData();
        } catch (e) {
          if (e is ApiException && e.status == 401) {
            await api.logout();
            user = null;
          } else {
            // Offline or server unavailable: keep session if we have cached user.
            user = await _loadCachedUser();
            if (user == null) {
              // Token exists but no cache; keep a minimal session-less state.
              // Don't logout - try again next time.
            }
          }
        }
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    error = null;
    notifyListeners();
    final data = await api.login(username, password);
    user = User.fromJson(data['user'] as Map<String, dynamic>);
    await _saveCachedUser(user!);
    await refreshData();
    notifyListeners();
  }

  Future<void> logout() async {
    await api.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_user');
    user = null;
    territories = [];
    leaderboard = [];
    notifyListeners();
  }

  Future<void> refreshData() async {
    if (!isLoggedIn) return;
    // Try to sync offline runs first; ignore failures.
    try {
      await OfflineRunService.instance.syncPendingRuns(api);
    } catch (_) {}
    try {
      final results = await Future.wait([api.getTerritories(), api.getLeaderboard()]);
      territories = results[0] as List<Territory>;
      leaderboard = results[1] as List<LeaderboardEntry>;
      error = null;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }
}
