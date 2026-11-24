import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/territory.dart';
import '../services/api_service.dart';

class AppState extends ChangeNotifier {
  final ApiService api = ApiService.instance;

  User? user;
  bool loading = true;
  String? error;
  List<Territory> territories = [];
  List<LeaderboardEntry> leaderboard = [];

  bool get isLoggedIn => user != null;
  bool get isAdmin => user?.isAdmin == true;

  Future<void> init() async {
    loading = true;
    notifyListeners();
    try {
      await api.loadToken();
      if (api.hasToken) {
        user = await api.me();
        await refreshData();
      }
    } catch (_) {
      await api.logout();
      user = null;
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
    await refreshData();
    notifyListeners();
  }

  Future<void> logout() async {
    await api.logout();
    user = null;
    territories = [];
    leaderboard = [];
    notifyListeners();
  }

  Future<void> refreshData() async {
    if (!isLoggedIn) return;
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
