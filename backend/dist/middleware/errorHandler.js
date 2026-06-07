export function errorHandler(error, _req, res, _next) {
    console.error('API error:', error);
    res.status(500).json({ error: 'Internal server error.' });
}
//# sourceMappingURL=errorHandler.js.map