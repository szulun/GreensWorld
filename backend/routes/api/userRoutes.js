import express from "express";
import { 
    createUser,
    loginUser, 
    getAllUsers, 
    getUser, 
    updateUser, 
    deleteUser,
    getCurrentUserProfile,
    upsertUserProfile,
    getFavoritePlantShops,
    addFavoritePlantShop,
    removeFavoritePlantShop,
} from "../../controllers/userControllers.js";

import { verifyIdToken } from "../../middleware/verifyIdToken.js";


const router = express.Router();

// /api/users
// Basic CRUD
router.post("/signup", createUser);
router.post("/login", loginUser);
router.get("/", getAllUsers);
router.get("/me", getCurrentUserProfile);
router.put("/profile", upsertUserProfile);
router.get("/:id", getUser);
router.put("/:id", updateUser);
router.patch("/:id", updateUser);
router.delete("/:id", deleteUser);

// New favorites routes
// New favorites routes (auth required)
router.get('/:userId/favorites/plant-shops', verifyIdToken, getFavoritePlantShops);
router.post('/:userId/favorites/plant-shops', verifyIdToken, addFavoritePlantShop);
router.delete('/:userId/favorites/plant-shops/:shopId', verifyIdToken, removeFavoritePlantShop);

export default router;