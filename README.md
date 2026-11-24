# RunningZone

Application mobile (Android + iOS) de capture de territoire par la course à pied, centrée sur la carte de France.

## Fonctionnalités

- **Connexion** (pas d'inscription publique) : seuls les comptes créés par un admin peuvent se connecter.
- **Compte admin** : l'admin peut ajouter/supprimer des utilisateurs depuis l'app.
- **Carte de France** : affichage OpenStreetMap (sans Google Maps / sans services Google).
- **Course GPS** : démarrer une course, enregistrer la trace, terminer la course.
- **Capture de zone** : quand la trace forme une boucle fermée valide, la zone devient la propriété du joueur.
- **Conquête** : une nouvelle zone grignote les zones des autres joueurs (différence géométrique côté backend).
- **Classement** : classement des joueurs par surface totale possédée.
- **Auto-update Android** : l'app vérifie les releases GitHub, télécharge l'APK et propose l'installation.

## Architecture

```
runningzone/
├── backend/   # API Node.js + Express + SQLite
├── app/       # Application Flutter (Android/iOS)
└── .github/workflows/
    ├── release-android.yml  # Build APK + GitHub Release sur tag v*
    └── build-ios.yml        # Build iOS unsigned (best effort)
```

## Backend

### Prérequis

- Node.js 20+

### Installation

```bash
cd backend
cp .env.example .env
# Éditez .env (JWT_SECRET, ADMIN_PASSWORD, CORS_ORIGIN, etc.)
npm install
npm run dev
```

Production :

```bash
npm run build
npm start
```

### Variables d'environnement

| Variable | Description | Défaut |
|---|---|---|
| `PORT` | Port HTTP | `3000` |
| `JWT_SECRET` | Secret JWT (à changer en prod) | `dev-secret-change-me` |
| `DB_PATH` | Fichier SQLite | `./data/runningzone.db` |
| `ADMIN_USERNAME` | Admin créé au premier démarrage | `admin` |
| `ADMIN_PASSWORD` | Mot de passe admin initial | `admin12345` |
| `CORS_ORIGIN` | Origine CORS (`*` ou liste CSV) | `*` |

### API

- `POST /api/auth/login` — connexion, retourne JWT
- `GET /api/auth/me` — utilisateur courant
- `GET /api/admin/users` — liste utilisateurs (admin)
- `POST /api/admin/users` — créer utilisateur (admin)
- `DELETE /api/admin/users/:id` — supprimer utilisateur (admin)
- `GET /api/map/territories` — territoires GeoJSON
- `GET /api/map/leaderboard` — classement par surface
- `POST /api/runs/start` — démarrer une course
- `POST /api/runs/:id/points` — envoyer un lot de points GPS
- `POST /api/runs/:id/finish` — terminer la course et tenter la capture
- `POST /api/runs/:id/cancel` — annuler la course

### Règle de capture

Une course est capturée si :

- la trace contient suffisamment de points valides en France ;
- le point d'arrivée est proche du point de départ (boucle fermée, ~60 m) ;
- la surface est valide (>= 100 m², plafond de sécurité).

La zone capturée est soustraite aux territoires des autres joueurs puis fusionnée au territoire du joueur.

## App mobile (Flutter)

### Prérequis

- Flutter SDK stable (3.x)
- Android SDK pour Android
- Xcode/macOS pour iOS

### Configuration

L'URL backend et le repo GitHub sont injectés via `--dart-define` :

```bash
cd app
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=https://votre-backend.example.com \
  --dart-define=GITHUB_REPO=votre-user/RunningZone
```

Valeurs par défaut (dev) :

- `API_BASE_URL=http://10.0.2.2:3000` (émulateur Android -> localhost machine)
- `GITHUB_REPO=YOUR_GITHUB_USER/RunningZone`

### Build Android APK

```bash
cd app
flutter build apk --release \
  --dart-define=API_BASE_URL=https://votre-backend.example.com \
  --dart-define=GITHUB_REPO=votre-user/RunningZone
```

APK généré : `app/build/app/outputs/flutter-apk/app-release.apk`

### Compatibilité Android / sans Google Services

- **Pas de Google Maps / pas de GMS** : carte via `flutter_map` + tuiles OpenStreetMap.
- **Localisation** : `geolocator` utilise les providers de localisation Android de la plateforme.
- **minSdk 21** (Android 5.0) pour supporter les anciennes versions Android.
- L'auto-update télécharge l'APK depuis les GitHub Releases et déclenche l'installation Android (`REQUEST_INSTALL_PACKAGES`). Sur Android récent, l'utilisateur doit autoriser l'installation d'apps inconnues pour RunningZone.

### iOS

Le code Flutter est compatible iOS. Le dossier `ios/` contient les fichiers de base, mais selon votre environnement Flutter/Xcode, vous pouvez régénérer les fichiers plateforme :

```bash
cd app
flutter create --platforms=ios,android .
flutter pub get
```

Build iOS (nécessite macOS + Xcode) :

```bash
flutter build ios --release --no-codesign
```

> L'auto-update par APK ne s'applique pas à iOS. Pour iOS, distribuer via TestFlight/App Store ou MDM/Enterprise selon votre cas.

## Déploiement serveur (local + Cloudflare Tunnel)

Exemple de déploiement sur un serveur Linux :

1. Copier `backend/` sur le serveur (ex: `/home/tear/runningzone-backend`).
2. Créer `.env` (`PORT`, `JWT_SECRET`, `DB_PATH`, `ADMIN_USERNAME`, `ADMIN_PASSWORD`, `CORS_ORIGIN`).
3. Installer et builder :

```bash
npm install
npm run build
```

4. Créer un service systemd `runningzone.service` pointant vers `dist/index.js`.
5. Si `cloudflared` est géré par token/dashboard Cloudflare Zero Trust, ajouter un **Public Hostname** dans le tunnel :
   - Hostname : `run.chorizo.dpdns.org`
   - Service : `http://localhost:<PORT>`

> Ne committez jamais de mots de passe/jetons réels dans le repo. Configurez-les uniquement dans `.env` ou les secrets du serveur.

## GitHub Repo & Releases

### Mettre en place le repo

```bash
cd runningzone
git init
git add .
git commit -m "Initial RunningZone"
git branch -M main
git remote add origin https://github.com/<votre-user>/RunningZone.git
git push -u origin main
```

### Publier une release Android

1. Configurez la variable GitHub Actions `API_BASE_URL` (Settings > Secrets and variables > Actions > Variables).
2. Mettez à jour `version` dans `app/pubspec.yaml` (ex: `1.0.1+2`).
3. Créez et poussez un tag :

```bash
git tag v1.0.1
git push origin v1.0.1
```

Le workflow `.github/workflows/release-android.yml` build l'APK et crée une GitHub Release avec l'APK attaché. L'app Android compare sa version avec `tag_name` de la dernière release et propose la mise à jour.

## Sécurité / Notes de production

- Changez `JWT_SECRET` et `ADMIN_PASSWORD` avant mise en production.
- Servez le backend derrière HTTPS.
- Restreignez `CORS_ORIGIN` aux domaines/apps attendus.
- La logique de territoire est MVP : pour une production à grande échelle, prévoir PostGIS, validations anti-triche, rate limiting, et audit.
- Les tuiles OpenStreetMap sont soumises à la [politique d'utilisation OSM](https://operations.osmfoundation.org/policies/tiles/) ; pour la prod, utilisez un provider de tuiles adapté.

## Licence

À définir par le propriétaire du repo.
