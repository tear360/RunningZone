import { Router } from "express";
import { requireAuth } from "../middleware/auth.js";
import { getAllTerritories, getLeaderboard } from "../services/territory.js";

export const mapRouter = Router();

mapRouter.use(requireAuth);

mapRouter.get("/territories", (_req, res) => {
  res.json({ territories: getAllTerritories() });
});

mapRouter.get("/leaderboard", (_req, res) => {
  res.json({ leaderboard: getLeaderboard() });
});
