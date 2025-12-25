import express from 'express';
import { getAllPlants, createPlant, updatePlant, deletePlant } from '../controllers/plant.controller.js';

const router = express.Router();

// Get all plants
router.get('/', getAllPlants);

// Create a new plant
router.post('/', createPlant);

// Update a plant
router.put('/:id', updatePlant);

// Delete a plant
router.delete('/:id', deletePlant);

export default router; 