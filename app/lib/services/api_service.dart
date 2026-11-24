import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/user.dart';
import '../models/territory.dart';

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  final _storage = const FlutterSecureStorage();
  String? _token;

  Future<void> loadToken() async {
    _token = await _storage.read(key: 'auth_token');
  }

  Future<void> setToken(String? token) async {
    _token = token;
    if (token == null) {
      await _storage.delete(key: 'auth_token');
    } else {
      await _storage.write(key: 'auth_token', value: token);
    }
  }

  bool get hasToken => _token != null && _token!.isNotEmpty;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  dynamic _decode(http.Response res) {
    final body = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final msg = body is Map && body['error'] is String
        ? body['error'] as String
        : 'Erreur serveur (${res.statusCode})';
    throw ApiException(msg, res.statusCode);
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await http.post(
      _uri('/api/auth/login'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password}),
    );
    final data = _decode(res) as Map<String, dynamic>;
    await setToken(data['token'] as String);
    return data;
  }

  Future<User> me() async {
    final res = await http.get(_uri('/api/auth/me'), headers: _headers);
    final data = _decode(res) as Map<String, dynamic>;
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async => setToken(null);

  Future<List<Territory>> getTerritories() async {
    final res = await http.get(_uri('/api/map/territories'), headers: _headers);
    final data = _decode(res) as Map<String, dynamic>;
    final list = data['territories'] as List;
    return list.map((e) => Territory.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<LeaderboardEntry>> getLeaderboard() async {
    final res = await http.get(_uri('/api/map/leaderboard'), headers: _headers);
    final data = _decode(res) as Map<String, dynamic>;
    final list = data['leaderboard'] as List;
    return list.map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> startRun() async {
    final res = await http.post(_uri('/api/runs/start'), headers: _headers);
    return _decode(res) as Map<String, dynamic>;
  }

  Future<void> sendPoints(int runId, List<Map<String, dynamic>> points) async {
    final res = await http.post(
      _uri('/api/runs/$runId/points'),
      headers: _headers,
      body: jsonEncode({'points': points}),
    );
    _decode(res);
  }

  Future<Map<String, dynamic>> finishRun(int runId, List<Map<String, dynamic>> points) async {
    final res = await http.post(
      _uri('/api/runs/$runId/finish'),
      headers: _headers,
      body: jsonEncode({'points': points}),
    );
    return _decode(res) as Map<String, dynamic>;
  }

  Future<void> cancelRun(int runId) async {
    final res = await http.post(_uri('/api/runs/$runId/cancel'), headers: _headers);
    _decode(res);
  }

  // Admin
  Future<List<Map<String, dynamic>>> adminGetUsers() async {
    final res = await http.get(_uri('/api/admin/users'), headers: _headers);
    final data = _decode(res) as Map<String, dynamic>;
    return (data['users'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> adminCreateUser(String username, String password, bool isAdmin) async {
    final res = await http.post(
      _uri('/api/admin/users'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password, 'isAdmin': isAdmin}),
    );
    _decode(res);
  }

  Future<void> adminDeleteUser(int id) async {
    final res = await http.delete(_uri('/api/admin/users/$id'), headers: _headers);
    _decode(res);
  }
}
