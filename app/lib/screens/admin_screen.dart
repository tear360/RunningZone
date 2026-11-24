import 'package:flutter/material.dart';
import '../state/app_scope.dart';
import 'leaderboard_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final users = await AppScope.read(context).api.adminGetUsers();
      setState(() => _users = users);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createUser() async {
    final username = TextEditingController();
    final password = TextEditingController();
    bool isAdmin = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Ajouter un utilisateur'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: username, decoration: const InputDecoration(labelText: 'Nom d\'utilisateur')),
              const SizedBox(height: 8),
              TextField(controller: password, decoration: const InputDecoration(labelText: 'Mot de passe'), obscureText: true),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: isAdmin,
                onChanged: (v) => setD(() => isAdmin = v ?? false),
                title: const Text('Admin'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Créer')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await AppScope.read(context).api.adminCreateUser(username.text.trim(), password.text, isAdmin);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Utilisateur créé')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _deleteUser(int id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer utilisateur'),
        content: Text('Supprimer $name ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AppScope.read(context).api.adminDeleteUser(id);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: _users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final u = _users[i];
            final isAdmin = u['isAdmin'] == true;
            return Card(
              child: ListTile(
                leading: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person),
                title: Text(u['username'] as String),
                subtitle: Text('${isAdmin ? "Admin" : "Joueur"} • ${formatArea((u['areaM2'] as num).toDouble())}'),
                trailing: isAdmin
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteUser(u['id'] as int, u['username'] as String),
                      ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createUser,
        icon: const Icon(Icons.person_add),
        label: const Text('Ajouter'),
      ),
    );
  }
}
