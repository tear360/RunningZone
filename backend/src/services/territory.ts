import * as turf from "@turf/turf";
import type { Feature, MultiPolygon, Polygon, Position } from "geojson";
import { db } from "../db.js";
import { FRANCE_BBOX } from "../config.js";
import type { LatLng } from "../types.js";

type PolyFeature = Feature<Polygon | MultiPolygon>;

const MIN_POINTS = 3;
const CLOSE_THRESHOLD_M = 60; // end must be within 60m of start to auto-close
const MIN_AREA_M2 = 100; // ignore tiny accidental polygons
const MAX_AREA_M2 = 50_000_000; // 50 km2 safety cap per claim

function inFrance(lat: number, lng: number): boolean {
  return (
    lat >= FRANCE_BBOX.minLat &&
    lat <= FRANCE_BBOX.maxLat &&
    lng >= FRANCE_BBOX.minLng &&
    lng <= FRANCE_BBOX.maxLng
  );
}

function toRing(points: LatLng[]): Position[] {
  return points.map((p) => [p.lng, p.lat]);
}

export function normalizeTrack(points: LatLng[]): LatLng[] {
  // Keep only points inside France bbox and drop consecutive near-duplicates.
  const filtered: LatLng[] = [];
  for (const p of points) {
    if (!Number.isFinite(p.lat) || !Number.isFinite(p.lng)) continue;
    if (!inFrance(p.lat, p.lng)) continue;
    const prev = filtered[filtered.length - 1];
    if (prev) {
      const d = turf.distance([prev.lng, prev.lat], [p.lng, p.lat], {
        units: "meters",
      });
      if (d < 2) continue;
    }
    filtered.push({ lat: p.lat, lng: p.lng, t: p.t });
  }
  return filtered;
}

export function buildClaimPolygon(points: LatLng[]): PolyFeature | null {
  const track = normalizeTrack(points);
  if (track.length < MIN_POINTS) return null;

  const first = track[0];
  const last = track[track.length - 1];
  const closeDist = turf.distance([first.lng, first.lat], [last.lng, last.lat], {
    units: "meters",
  });
  if (closeDist > CLOSE_THRESHOLD_M) return null;

  const ring = toRing(track);
  // Ensure closed ring.
  const ringFirst = ring[0];
  const ringLast = ring[ring.length - 1];
  if (ringFirst[0] !== ringLast[0] || ringFirst[1] !== ringLast[1]) {
    ring.push([...ringFirst]);
  }
  if (ring.length < 4) return null;

  let poly: Feature<Polygon> | null = null;
  try {
    poly = turf.polygon([ring]);
    // Simplify lightly to remove GPS jitter.
    poly = turf.simplify(poly, { tolerance: 0.00003, highQuality: true }) as Feature<Polygon>;
    // Clean self-intersections/bad geometry via buffer(0) trick.
    const cleaned = turf.buffer(poly, 0, { units: "meters" });
    if (!cleaned) return null;
    poly = cleaned as Feature<Polygon>;
  } catch {
    return null;
  }

  const area = turf.area(poly);
  if (!Number.isFinite(area) || area < MIN_AREA_M2 || area > MAX_AREA_M2) return null;

  // Ensure geometry is valid polygon/multipolygon
  const geom = poly.geometry;
  if (geom.type === "Polygon") return poly as Feature<Polygon>;
  if (geom.type === "MultiPolygon") return poly as unknown as Feature<MultiPolygon>;
  return null;
}

function parseTerritory(geometryJson: string): PolyFeature | null {
  try {
    const geom = JSON.parse(geometryJson) as Polygon | MultiPolygon;
    if (geom.type !== "Polygon" && geom.type !== "MultiPolygon") return null;
    return turf.feature(geom) as PolyFeature;
  } catch {
    return null;
  }
}

function asFeatureCollection(features: PolyFeature[]) {
  return turf.featureCollection(features);
}

export function applyClaim(userId: number, claim: PolyFeature): { claimedAreaM2: number; totalAreaM2: number } {
  const claimArea = turf.area(claim);
  const rows = db
    .prepare("SELECT user_id, geometry_json FROM territories")
    .all() as { user_id: number; geometry_json: string }[];

  const updateOther = db.prepare(
    "UPDATE territories SET geometry_json = ?, area_m2 = ?, updated_at = datetime('now') WHERE user_id = ?"
  );
  const deleteOther = db.prepare("DELETE FROM territories WHERE user_id = ?");
  const upsertOwner = db.prepare(`
    INSERT INTO territories (user_id, geometry_json, area_m2, updated_at)
    VALUES (?, ?, ?, datetime('now'))
    ON CONFLICT(user_id) DO UPDATE SET
      geometry_json = excluded.geometry_json,
      area_m2 = excluded.area_m2,
      updated_at = datetime('now')
  `);

  let ownerTerritory: PolyFeature | null = null;

  const tx = db.transaction(() => {
    for (const row of rows) {
      const existing = parseTerritory(row.geometry_json);
      if (!existing) continue;
      if (row.user_id === userId) {
        ownerTerritory = existing;
        continue;
      }
      // Subtract claim from other user's territory.
      let diff: PolyFeature | null = null;
      try {
        diff = turf.difference(asFeatureCollection([existing, claim])) as PolyFeature | null;
      } catch {
        diff = existing;
      }
      if (!diff || !diff.geometry) {
        deleteOther.run(row.user_id);
        continue;
      }
      const area = turf.area(diff);
      if (area < 1) {
        deleteOther.run(row.user_id);
      } else {
        updateOther.run(JSON.stringify(diff.geometry), area, row.user_id);
      }
    }

    // Union claim into owner's territory.
    let merged: PolyFeature = claim;
    if (ownerTerritory) {
      try {
        const u = turf.union(asFeatureCollection([ownerTerritory, claim])) as PolyFeature | null;
        if (u) merged = u;
      } catch {
        // keep claim only merged fallback - better to at least union by featureCollection combine
        try {
          const combined = turf.combine(asFeatureCollection([ownerTerritory, claim]));
          const feat = combined.features[0];
          const gtype = feat?.geometry?.type as string | undefined;
          if (feat && (gtype === 'Polygon' || gtype === 'MultiPolygon')) {
            merged = turf.feature(feat.geometry as Polygon | MultiPolygon) as PolyFeature;
          }
        } catch {
          // ignore
        }
      }
    }

    const totalAreaM2 = turf.area(merged);
    upsertOwner.run(userId, JSON.stringify(merged.geometry), totalAreaM2);
    return { claimedAreaM2: claimArea, totalAreaM2 };
  });

  return tx();
}

export function getAllTerritories() {
  const rows = db
    .prepare(
      `SELECT t.user_id, u.username, t.geometry_json, t.area_m2, t.updated_at
       FROM territories t JOIN users u ON u.id = t.user_id
       ORDER BY t.area_m2 DESC`
    )
    .all() as Array<{
    user_id: number;
    username: string;
    geometry_json: string;
    area_m2: number;
    updated_at: string;
  }>;
  return rows.map((r) => ({
    userId: r.user_id,
    username: r.username,
    geometry: JSON.parse(r.geometry_json),
    areaM2: r.area_m2,
    updatedAt: r.updated_at,
  }));
}

export function getLeaderboard() {
  const rows = db
    .prepare(
      `SELECT u.id as user_id, u.username,
              COALESCE(t.area_m2, 0) as area_m2,
              t.updated_at
       FROM users u
       LEFT JOIN territories t ON t.user_id = u.id
       ORDER BY area_m2 DESC, u.username ASC`
    )
    .all() as Array<{ user_id: number; username: string; area_m2: number; updated_at: string | null }>;
  return rows.map((r, i) => ({
    rank: i + 1,
    userId: r.user_id,
    username: r.username,
    areaM2: r.area_m2,
    updatedAt: r.updated_at,
  }));
}
