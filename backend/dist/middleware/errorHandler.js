export function errorHandler(error, req, res, next) {
    console.error('API error:', error);
    res.status(500).json({ error: 'Internal server error.' });
}
//# sourceMappingURL=errorHandler.js.map