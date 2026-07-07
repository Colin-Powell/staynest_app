/**
 * Centralized error handler to ensure all API errors follow the same format.
 */
export const errorHandler = (err, req, res, _next) => {
    const statusCode = err.statusCode || 500;
    const errorCode = err.code || 'INTERNAL_SERVER_ERROR';
    // Log error for server-side monitoring
    console.error(`[Error] ${req.method} ${req.path} - ${statusCode}: ${err.message}`);
    res.status(statusCode).json({
        success: false,
        code: errorCode,
        message: err.message || 'An unexpected error occurred',
        details: err.details || null,
        ...(process.env.NODE_ENV !== 'production' && { stack: err.stack }),
    });
};
//# sourceMappingURL=errorHandler.js.map