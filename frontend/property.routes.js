const express = require('express');
const router = express.Router();
const propertyController = require('../controllers/property.controller');

// GET /api/properties/nearby?lat=...&lng=...&radius=10
router.get('/nearby', propertyController.getNearbyProperties);

module.exports = router;