import { Router } from "express";
import { z } from "zod";
import * as turf from "@turf/turf";
import { db } from "../db.js";
import { requireAuth } from "../middleware/auth.js";
import type { AuthRequest, LatLng } from "../types.js";
import { applyClaim, buildClaimPolygon, normalizeTrack } from "../services/territory.js";

export const runsRouter = Router();
runsRouter.use(requireAuth);

const pointSchema = z.object({
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
  t: z.number().optional(),
});

const pointsSchema = z.array(pointSchema).max(20000);

function getActiveRun(userId: number) {
  return db
    .prepare("SELECT * FROM runs WHERE user_id = ? AND status = 'active' ORDER BY id DESC LIMIT 1")
    .get(userId) as any;
}

function computeDistanceM(points: LatLng[]): number {
  if (points.length < 2) return 0;
  const coords = points.map((p) => [p.lng, p.lat]);
  try {
    return turf.length(turf.lineString(coords), { units: "meters" });
  } catch {
    return 0;
  }
}

runsRouter.get("/current", (req: AuthRequest, res) => {
  const run = getActiveRun(req.user!.id);
  if (!run) return res.json({ run: null });
  res.json({
    run: {
      id: run.id,
      startedAt: run.started_at,
      status: run.status,
      points: JSON.parse(run.points_json),
      distanceM: run.distance_m,
    },
  });
});

runsRouter.post("/start", (req: AuthRequest, res) => {
  const existing = getActiveRun(req.user!.id);
  if (existing) return res.status(409).json({ error: "Une course est déjà en cours", runId: existing.id });
  const info = db
    .prepare("INSERT INTO runs (user_id, status, points_json) VALUES (?, 'active', '[]')")
    .run(req.user!.id);
  res.status(201).json({ run: { id: Number(info.lastInsertRowid), status: "active", points: [], distanceM: 0 } });
});

runsRouter.post("/:id/points", (req: AuthRequest, res) => {
  const id = Number(req.params.id);
  const run = db.prepare("SELECT * FROM runs WHERE id = ? AND user_id = ?").get(id, req.user!.id) as any;
  if (!run) return res.status(404).json({ error: "Course introuvable" });
  if (run.status !== "active") return res.status(400).json({ error: "Course non active" });
  const parsed = pointsSchema.safeParse(req.body.points ?? req.body);
  if (!parsed.success) return res.status(400).json({ error: "Points invalides" });
  const existing = JSON.parse(run.points_json) as LatLng[];
  const merged = [...existing, ...parsed.data].slice(-20000);
  const distanceM = computeDistanceM(merged);
  db.prepare("UPDATE runs SET points_json = ?, distance_m = ? WHERE id = ?").run(
    JSON.stringify(merged),
    distanceM,
    id
  );
  res.json({ ok: true, pointCount: merged.length, distanceM });
});

runsRouter.post("/:id/finish", (req: AuthRequest, res) => {
  const id = Number(req.params.id);
  const run = db.prepare("SELECT * FROM runs WHERE id = ? AND user_id = ?").get(id, req.user!.id) as any;
  if (!run) return res.status(404).json({ error: "Course introuvable" });
  if (run.status !== "active") return res.status(400).json({ error: "Course non active" });

  const bodySchema = z.object({ points: pointsSchema.optional() });
  const parsed = bodySchema.safeParse(req.body ?? {});
  if (!parsed.success) return res.status(400).json({ error: "Payload invalide" });

  const points = normalizeTrack(parsed.data.points ?? (JSON.parse(run.points_json) as LatLng[]));
  const distanceM = computeDistanceM(points);
  const claim = buildClaimPolygon(points);

  if (!claim) {
    db.prepare(
      "UPDATE runs SET status = 'completed', ended_at = datetime('now'), points_json = ?, distance_m = ?, claimed_area_m2 = 0 WHERE id = ?"
    ).run(JSON.stringify(points), distanceM, id);
    return res.json({
      ok: true,
      claimed: false,
      reason:
        "La trace ne forme pas une zone valide. Ferme la boucle (retour près du départ) en restant en France.",
      distanceM,
      claimedAreaM2: 0,
    });
  }

  const result = applyClaim(req.user!.id, claim);
  db.prepare(
    "UPDATE runs SET status = 'completed', ended_at = datetime('now'), points_json = ?, distance_m = ?, claimed_area_m2 = ? WHERE id = ?"
  ).run(JSON.stringify(points), distanceM, result.claimedAreaM2, id);

  res.json({
    ok: true,
    claimed: true,
    distanceM,
    claimedAreaM2: result.claimedAreaM2,
    totalAreaM2: result.totalAreaM2,
  });
});

runsRouter.post("/:id/cancel", (req: AuthRequest, res) => {
  const id = Number(req.params.id);
  const run = db.prepare("SELECT * FROM runs WHERE id = ? AND user_id = ?").get(id, req.user!.id) as any;
  if (!run) return res.status(404).json({ error: "Course introuvable" });
  if (run.status !== "active") return res.status(400).json({ error: "Course non active" });
  db.prepare("UPDATE runs SET status = 'cancelled', ended_at = datetime('now') WHERE id = ?").run(id);
  res.json({ ok: true });
});
