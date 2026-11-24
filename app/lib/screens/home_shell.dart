import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../state/app_scope.dart';
import 'map_screen.dart';
import 'leaderboard_screen.dart';
import 'admin_screen.dart';
import 'legal_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
  }

  Future<void> _checkUpdate() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final update = await UpdateService.instance.checkForUpdate();
      if (!mounted || update == null) return;
      final install = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Mise à jour disponible'),
          content: Text(
            'Version ${update.latestVersion} disponible (actuelle: ${update.currentVersion}).\n\n${update.releaseNotes.isEmpty ? "Nouvelle version disponible." : update.releaseNotes}',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Plus tard')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Télécharger')),
          ],
        ),
      );
      if (install == true && mounted) {
        await _downloadUpdate(update);
      }
    } catch (_) {}
  }

  Future<void> _downloadUpdate(UpdateInfo update) async {
    final progress = ValueNotifier<double>(0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (_, v, __) => AlertDialog(
          title: const Text('Téléchargement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: v > 0 ? v : null),
              const SizedBox(height: 12),
              Text('${(v * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ),
      ),
    );
    try {
      await UpdateService.instance.downloadAndInstall(update, (p) => progress.value = p);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mise à jour échouée: $e')));
      }
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final isAdmin = app.isAdmin;
    final pages = <Widget>[
      const MapScreen(),
      const LeaderboardScreen(),
      if (isAdmin) const AdminScreen(),
    ];
    final items = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Carte'),
      const NavigationDestination(icon: Icon(Icons.leaderboard_outlined), selectedIcon: Icon(Icons.leaderboard), label: 'Classement'),
      if (isAdmin)
        const NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: 'Admin'),
    ];
    if (_index >= pages.length) _index = 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RunningZone'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => app.refreshData(),
            tooltip: 'Rafraîchir',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen())),
            tooltip: 'Mentions légales',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => app.logout(),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: items,
      ),
    );
  }
}
