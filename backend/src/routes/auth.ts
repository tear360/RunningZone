import { Router } from "express";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { z } from "zod";
import { db, type UserRow } from "../db.js";
import { config } from "../config.js";
import { requireAuth } from "../middleware/auth.js";
import type { AuthRequest } from "../types.js";

export const authRouter = Router();

const loginSchema = z.object({
  username: z.string().min(1).max(64),
  password: z.string().min(1).max(128),
});

authRouter.post("/login", (req, res) => {
  const parsed = loginSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "Invalid credentials payload" });
  const { username, password } = parsed.data;
  const user = db
    .prepare("SELECT * FROM users WHERE username = ?")
    .get(username) as UserRow | undefined;
  if (!user || !bcrypt.compareSync(password, user.password_hash)) {
    return res.status(401).json({ error: "Identifiants invalides" });
  }
  const payload = { id: user.id, username: user.username, isAdmin: !!user.is_admin };
  const token = jwt.sign(payload, config.jwtSecret, { expiresIn: "30d" });
  res.json({ token, user: payload });
});

authRouter.get("/me", requireAuth, (req: AuthRequest, res) => {
  res.json({ user: req.user });
});
