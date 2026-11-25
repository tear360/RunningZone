import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'api_service.dart';

class PendingRun {
  final String localId;
  final List<Map<String, dynamic>> points;
  final String createdAt;

  PendingRun({required this.localId, required this.points, required this.createdAt});

  Map<String, dynamic> toJson() => {
        'localId': localId,
        'points': points,
        'createdAt': createdAt,
      };

  factory PendingRun.fromJson(Map<String, dynamic> json) {
    return PendingRun(
      localId: json['localId'] as String,
      points: (json['points'] as List).cast<Map<String, dynamic>>(),
      createdAt: json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}

class OfflineRunService {
  static final OfflineRunService instance = OfflineRunService._();
  OfflineRunService._();

  bool _syncing = false;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/pending_runs.json');
  }

  Future<List<PendingRun>> getPendingRuns() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final raw = jsonDecode(await f.readAsString());
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => PendingRun.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveAll(List<PendingRun> runs) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(runs.map((e) => e.toJson()).toList()));
  }

  Future<void> enqueue(PendingRun run) async {
    final runs = await getPendingRuns();
    runs.removeWhere((r) => r.localId == run.localId);
    runs.add(run);
    await _saveAll(runs);
  }

  Future<void> remove(String localId) async {
    final runs = await getPendingRuns();
    runs.removeWhere((r) => r.localId == localId);
    await _saveAll(runs);
  }

  Future<int> syncPendingRuns(ApiService api) async {
    if (_syncing) return 0;
    _syncing = true;
    var synced = 0;
    try {
      final runs = await getPendingRuns();
      for (final run in runs) {
        try {
          final started = await api.startRun();
          final runId = (started['run'] as Map<String, dynamic>)['id'] as int;
          // Send points in batches of 500
          for (var i = 0; i < run.points.length; i += 500) {
            final end = (i + 500 < run.points.length) ? i + 500 : run.points.length;
            await api.sendPoints(runId, run.points.sublist(i, end));
          }
          await api.finishRun(runId, run.points);
          await remove(run.localId);
          synced++;
        } catch (_) {
          // Keep in queue for next attempt (network/server issue).
        }
      }
    } finally {
      _syncing = false;
    }
    return synced;
  }
}
