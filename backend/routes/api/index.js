import express from "express";
import userRoutes from './userRoutes.js';
import aiRoutes from './aiRoutes.js';
import plantShopsRoutes from './plantShops.routes.js';


const router = express.Router();

router.use('/users', userRoutes);
router.use('/ai', aiRoutes);
router.use('/plant-shops', plantShopsRoutes);
export default router;
