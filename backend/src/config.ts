import "dotenv/config";

function required(name: string, fallback?: string): string {
  const value = process.env[name] ?? fallback;
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export const config = {
  port: Number(process.env.PORT ?? 3000),
  jwtSecret: required("JWT_SECRET", "dev-secret-change-me"),
  dbPath: process.env.DB_PATH ?? "./data/runningzone.db",
  adminUsername: required("ADMIN_USERNAME", "admin"),
  adminPassword: required("ADMIN_PASSWORD", "admin12345"),
  corsOrigin: process.env.CORS_ORIGIN ?? "*",
};

// Generous bounding box covering metropolitan France + Corsica.
export const FRANCE_BBOX = {
  minLat: 41.0,
  maxLat: 51.5,
  minLng: -5.5,
  maxLng: 10.0,
};
