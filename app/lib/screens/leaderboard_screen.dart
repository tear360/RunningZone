import 'package:flutter/material.dart';
import '../state/app_scope.dart';

String formatArea(double m2) {
  if (m2 >= 1_000_000) return '${(m2 / 1_000_000).toStringAsFixed(2)} km²';
  if (m2 >= 10_000) return '${(m2 / 10_000).toStringAsFixed(2)} ha';
  return '${m2.toStringAsFixed(0)} m²';
}

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final entries = app.leaderboard;
    final myId = app.user?.id;
    return RefreshIndicator(
      onRefresh: app.refreshData,
      child: entries.isEmpty
          ? ListView(children: const [SizedBox(height: 120), Center(child: Text('Aucune donnée.'))])
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final e = entries[i];
                final mine = e.userId == myId;
                return Card(
                  color: mine ? Theme.of(context).colorScheme.primaryContainer : null,
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${e.rank}')),
                    title: Text(e.username, style: TextStyle(fontWeight: mine ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text(mine ? 'Toi' : 'Joueur'),
                    trailing: Text(formatArea(e.areaM2), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
    );
  }
}
