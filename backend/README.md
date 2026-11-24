# RunningZone Backend

API Node.js/Express + SQLite pour RunningZone.

## Prérequis

- Node.js 20+

## Installation

```bash
cd backend
cp .env.example .env
# Éditez .env : changez JWT_SECRET, ADMIN_PASSWORD, etc.
npm install
npm run dev
```

En production :

```bash
npm run build
npm start
```

## Variables d'environnement

Voir `.env.example`.

- `ADMIN_USERNAME` / `ADMIN_PASSWORD` : compte admin créé automatiquement au premier démarrage.
- `DB_PATH` : chemin du fichier SQLite.
- `CORS_ORIGIN` : origine autorisée, `*` en dev, ou liste séparée par des virgules.

## API principale

- `POST /api/auth/login` - connexion
- `GET /api/auth/me` - utilisateur courant
- `GET /api/admin/users` - liste utilisateurs (admin)
- `POST /api/admin/users` - créer utilisateur (admin)
- `DELETE /api/admin/users/:id` - supprimer utilisateur (admin)
- `GET /api/map/territories` - territoires de tous les joueurs
- `GET /api/map/leaderboard` - classement par surface possédée
- `POST /api/runs/start` - démarrer une course
- `POST /api/runs/:id/points` - envoyer des points GPS
- `POST /api/runs/:id/finish` - terminer et revendiquer la zone
- `POST /api/runs/:id/cancel` - annuler
