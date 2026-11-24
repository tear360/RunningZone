import express from "express";
import cors from "cors";
import helmet from "helmet";
import { config } from "./config.js";
import { seedAdmin } from "./db.js";
import { authRouter } from "./routes/auth.js";
import { adminRouter } from "./routes/admin.js";
import { mapRouter } from "./routes/map.js";
import { runsRouter } from "./routes/runs.js";

seedAdmin();

const app = express();
app.use(helmet());
app.use(
  cors({
    origin: config.corsOrigin === "*" ? true : config.corsOrigin.split(",").map((s) => s.trim()),
    credentials: true,
  })
);
app.use(express.json({ limit: "4mb" }));

app.get("/api/health", (_req, res) => {
  res.json({ ok: true, name: "RunningZone", version: "1.0.0" });
});

app.use("/api/auth", authRouter);
app.use("/api/admin", adminRouter);
app.use("/api/map", mapRouter);
app.use("/api/runs", runsRouter);

app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(err);
  res.status(500).json({ error: "Internal server error" });
});

app.listen(config.port, "0.0.0.0", () => {
  console.log(`RunningZone backend listening on http://0.0.0.0:${config.port}`);
});
