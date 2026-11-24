import Database from "better-sqlite3";
import fs from "node:fs";
import path from "node:path";
import bcrypt from "bcryptjs";
import { config } from "./config.js";

fs.mkdirSync(path.dirname(config.dbPath), { recursive: true });

export const db = new Database(config.dbPath);
db.pragma("journal_mode = WAL");
db.pragma("foreign_keys = ON");

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE COLLATE NOCASE,
    password_hash TEXT NOT NULL,
    is_admin INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    started_at TEXT NOT NULL DEFAULT (datetime('now')),
    ended_at TEXT,
    points_json TEXT NOT NULL DEFAULT '[]',
    distance_m REAL NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'active', -- active | completed | cancelled
    claimed_area_m2 REAL NOT NULL DEFAULT 0
  );

  CREATE TABLE IF NOT EXISTS territories (
    user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    geometry_json TEXT NOT NULL, -- GeoJSON Polygon or MultiPolygon
    area_m2 REAL NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE INDEX IF NOT EXISTS idx_runs_user_status ON runs(user_id, status);
`);

export function seedAdmin() {
  const existing = db
    .prepare("SELECT id FROM users WHERE username = ?")
    .get(config.adminUsername) as { id: number } | undefined;
  if (existing) return;
  const hash = bcrypt.hashSync(config.adminPassword, 10);
  db.prepare(
    "INSERT INTO users (username, password_hash, is_admin) VALUES (?, ?, 1)"
  ).run(config.adminUsername, hash);
  console.log(`[seed] admin user created: ${config.adminUsername}`);
}

export type UserRow = {
  id: number;
  username: string;
  password_hash: string;
  is_admin: number;
  created_at: string;
};
