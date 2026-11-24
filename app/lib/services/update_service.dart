import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../config.dart';

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final String tag;
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.tag,
  });
}

class UpdateService {
  static final UpdateService instance = UpdateService._();
  UpdateService._();

  Future<UpdateInfo?> checkForUpdate() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    final repo = AppConfig.githubRepo.trim();
    if (repo.isEmpty || repo.contains('YOUR_GITHUB_USER')) return null;

    final info = await PackageInfo.fromPlatform();
    final current = info.version; // e.g. 1.0.0

    final res = await http.get(
      Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
      headers: {'Accept': 'application/vnd.github+json', 'User-Agent': 'RunningZone'},
    );
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] as String? ?? '').trim();
    final latest = tag.startsWith('v') ? tag.substring(1) : tag;
    if (latest.isEmpty || !_isNewer(latest, current)) return null;

    final assets = (data['assets'] as List? ?? []).cast<Map<String, dynamic>>();
    final apk = assets.firstWhere(
      (a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'),
      orElse: () => {},
    );
    final url = apk['browser_download_url'] as String?;
    if (url == null || url.isEmpty) return null;

    return UpdateInfo(
      currentVersion: current,
      latestVersion: latest,
      downloadUrl: url,
      releaseNotes: (data['body'] as String? ?? '').trim(),
      tag: tag,
    );
  }

  bool _isNewer(String latest, String current) {
    List<int> parse(String v) => v
        .split('+')
        .first
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final l = parse(latest);
    final c = parse(current);
    for (var i = 0; i < 3; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }

  Future<void> downloadAndInstall(UpdateInfo update, void Function(double progress) onProgress) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/runningzone-${update.latestVersion}.apk');
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(update.downloadUrl));
      req.headers['User-Agent'] = 'RunningZone';
      final resp = await client.send(req);
      if (resp.statusCode != 200) throw Exception('Téléchargement échoué (${resp.statusCode})');
      final total = resp.contentLength ?? 0;
      var received = 0;
      final sink = file.openWrite();
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }
      await sink.close();
    } finally {
      client.close();
    }
    await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
  }
}
