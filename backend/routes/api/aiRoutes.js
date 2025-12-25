import express from 'express';
import {
  getCareTipsFromKeyword,
  getCareTipsFromPhoto,
  diagnosePlant,
  generalChat
} from '../../controllers/aiControllers.js';

const router = express.Router();

router.post('/keyword', getCareTipsFromKeyword);
router.post('/photo', getCareTipsFromPhoto);
router.post('/diagnose', diagnosePlant);
router.post('/general-chat', generalChat);

export default router;
