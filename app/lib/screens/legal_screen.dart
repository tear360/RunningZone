import 'package:flutter/material.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mentions légales')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('RunningZone', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Text('Éditeur / Auteur', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('TEAR'),
          SizedBox(height: 16),
          Text('Contact', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('tear36.mc@proton.me'),
          SizedBox(height: 16),
          Text('Hébergement', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Hébergement auto-géré par l’éditeur.'),
          SizedBox(height: 16),
          Text('Données et localisation', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text(
            'RunningZone utilise la localisation GPS uniquement pour enregistrer les courses et calculer les zones capturées, lorsque l’utilisateur démarre une course. '
            'Les données de compte (nom d’utilisateur) et les traces/zones associées sont stockées sur le serveur configuré pour l’application. '
            'Aucune inscription publique n’est proposée : les comptes sont créés par l’administrateur.',
          ),
          SizedBox(height: 16),
          Text('Propriété des zones', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text(
            'Les zones affichées dans l’application représentent un mécanisme ludique interne au jeu. Elles ne constituent pas un droit de propriété réel sur des terrains.',
          ),
          SizedBox(height: 16),
          Text('Cartographie', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Carte affichée via OpenStreetMap. © contributeurs OpenStreetMap.'),
        ],
      ),
    );
  }
}
