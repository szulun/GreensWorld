import { Router } from "express";
import { getNearbyPlantShops } from "../../controllers/plantShops.controller.js";

const r = Router();
// Get nearby plant shops
r.get("/nearby", getNearbyPlantShops);

// Get detailed info for a specific plant shop
//r.get("/:placeId", getPlantShopDetails);
export default r;
