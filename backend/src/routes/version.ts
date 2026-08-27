import express from 'express';
import { env } from '../config.js';

const router = express.Router();

router.get('/', (req, res) => {
  res.json({
    latestVersion: env.appLatestVersion || '1.0.0',
    updateUrl: env.appUpdateUrl || 'https://staynest.top/update.html',
    forceUpdate: env.forceUpdate
  });
});

export default router;
