import app from './app.js';
import { env } from './config.js';
import { startCronJobs } from './services/cron.js';
import './services/queue.js';
import './workers/mediaWorker.js';
async function startServer() {
    // Use an explicit HTTP server so we can attach Socket.IO
    const http = await import('http');
    const server = http.createServer(app);
    // Initialize Socket.IO
    try {
        const { initSocket } = await import('./socket.js');
        initSocket(server);
        console.log('Socket.IO initialized');
    }
    catch (err) {
        console.warn('Socket.IO initialization skipped or failed:', err);
    }
    startCronJobs();
    server.listen(env.port, () => {
        console.log(`staynest backend listening on http://localhost:${env.port}`);
    });
}
startServer().catch((error) => {
    console.error('Backend startup failed:', error);
    process.exit(1);
});
//# sourceMappingURL=index.js.map