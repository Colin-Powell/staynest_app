const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth_controller');

router.post('/login', (req, res) => authController.login(req, res));
router.post('/refresh', (req, res) => authController.refresh(req, res));
router.post('/logout', (req, res) => authController.logout(req, res));

module.exports = router;