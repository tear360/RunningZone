import { Router } from "express";
import bcrypt from "bcryptjs";
import { z } from "zod";
import { db, type UserRow } from "../db.js";
import { requireAuth, requireAdmin } from "../middleware/auth.js";

export const adminRouter = Router();

adminRouter.use(requireAuth, requireAdmin);

const createUserSchema = z.object({
  username: z.string().min(2).max(64).regex(/^[a-zA-Z0-9_.-]+$/, "Username invalide"),
  password: z.string().min(6).max(128),
  isAdmin: z.boolean().optional().default(false),
});

adminRouter.get("/users", (_req, res) => {
  const users = db
    .prepare(
      `SELECT u.id, u.username, u.is_admin, u.created_at, COALESCE(t.area_m2, 0) as area_m2
       FROM users u LEFT JOIN territories t ON t.user_id = u.id
       ORDER BY u.created_at DESC`
    )
    .all() as Array<{ id: number; username: string; is_admin: number; created_at: string; area_m2: number }>;
  res.json({
    users: users.map((u) => ({
      id: u.id,
      username: u.username,
      isAdmin: !!u.is_admin,
      createdAt: u.created_at,
      areaM2: u.area_m2,
    })),
  });
});

adminRouter.post("/users", (req, res) => {
  const parsed = createUserSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.issues[0]?.message ?? "Invalid payload" });
  }
  const { username, password, isAdmin } = parsed.data;
  const existing = db.prepare("SELECT id FROM users WHERE username = ?").get(username) as { id: number } | undefined;
  if (existing) return res.status(409).json({ error: "Nom d'utilisateur déjà pris" });
  const hash = bcrypt.hashSync(password, 10);
  const info = db
    .prepare("INSERT INTO users (username, password_hash, is_admin) VALUES (?, ?, ?)")
    .run(username, hash, isAdmin ? 1 : 0);
  res.status(201).json({
    user: { id: Number(info.lastInsertRowid), username, isAdmin: !!isAdmin },
  });
});

adminRouter.delete("/users/:id", (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) return res.status(400).json({ error: "Invalid id" });
  const user = db.prepare("SELECT id, is_admin FROM users WHERE id = ?").get(id) as UserRow | undefined;
  if (!user) return res.status(404).json({ error: "User not found" });
  if (user.is_admin) return res.status(400).json({ error: "Impossible de supprimer un admin" });
  db.prepare("DELETE FROM users WHERE id = ?").run(id);
  res.json({ ok: true });
});
