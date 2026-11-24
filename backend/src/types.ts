import type { Request } from "express";

export interface AuthUser {
  id: number;
  username: string;
  isAdmin: boolean;
}

export interface AuthRequest extends Request {
  user?: AuthUser;
}

export type LatLng = { lat: number; lng: number; t?: number };
