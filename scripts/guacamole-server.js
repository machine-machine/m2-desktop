/**
 * Guacamole-Lite Server
 *
 * Provides HTML5 remote desktop access via Apache Guacamole protocol.
 * Supports multi-user sessions - all connected users share the same desktop.
 *
 * Architecture:
 *   Browser → WebSocket (this server) → guacd → x11vnc → Xorg :0
 */

const GuacamoleLite = require('guacamole-lite');
const express = require('express');
const http = require('http');
const path = require('path');
const crypto = require('crypto');

// Configuration from environment
const PORT = parseInt(process.env.GUAC_PORT || '8080', 10);
const GUACD_HOST = process.env.GUACD_HOST || '127.0.0.1';
const GUACD_PORT = parseInt(process.env.GUACD_PORT || '4822', 10);
const VNC_HOST = process.env.VNC_HOST || '127.0.0.1';
const VNC_PORT = parseInt(process.env.VNC_PORT || '5900', 10);
const VNC_PASSWORD = process.env.VNC_PASSWORD || 'm2desktop';
const AUTH_ENABLED = process.env.GUAC_AUTH_ENABLED !== 'false';
const AUTH_USER = process.env.GUAC_AUTH_USER || 'developer';
const AUTH_PASSWORD = process.env.GUAC_AUTH_PASSWORD || VNC_PASSWORD;

// Generate a secret key for token encryption
const SECRET_KEY = process.env.GUAC_SECRET_KEY || crypto.randomBytes(32).toString('hex');

console.log('==============================================');
console.log(' Guacamole-Lite Server');
console.log('==============================================');
console.log(`Port: ${PORT}`);
console.log(`guacd: ${GUACD_HOST}:${GUACD_PORT}`);
console.log(`VNC backend: ${VNC_HOST}:${VNC_PORT}`);
console.log(`Auth enabled: ${AUTH_ENABLED}`);
console.log('');

// Create Express app for serving static files and health checks
const app = express();
const server = http.createServer(app);

// Basic auth middleware
function basicAuth(req, res, next) {
    if (!AUTH_ENABLED) {
        return next();
    }

    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Basic ')) {
        res.setHeader('WWW-Authenticate', 'Basic realm="M2 Desktop"');
        return res.status(401).send('Authentication required');
    }

    const credentials = Buffer.from(authHeader.slice(6), 'base64').toString();
    const [user, pass] = credentials.split(':');

    if (user === AUTH_USER && pass === AUTH_PASSWORD) {
        return next();
    }

    res.setHeader('WWW-Authenticate', 'Basic realm="Clawdbot Desktop"');
    return res.status(401).send('Invalid credentials');
}

// Health check endpoint (no auth)
app.get('/health', (req, res) => {
    res.json({ status: 'ok', service: 'guacamole-lite' });
});

// Serve static files (JS libraries, no auth needed)
app.use('/static', express.static(path.join(__dirname, 'static')));

// Serve static client files (exclude WebSocket path and static from auth)
app.use((req, res, next) => {
    if (req.path === '/websocket' || req.path.startsWith('/websocket') || req.path.startsWith('/static')) {
        return next();
    }
    return basicAuth(req, res, next);
});

// Generate connection token
app.get('/api/token', (req, res) => {
    // Create connection settings
    const connectionSettings = {
        connection: {
            type: 'vnc',
            settings: {
                hostname: VNC_HOST,
                port: VNC_PORT,
                password: VNC_PASSWORD,
                'enable-audio': false,
                'resize-method': 'display-update',
                'color-depth': 16,
                'cursor': 'remote',
                'clipboard-encoding': 'UTF-8',
                'swap-red-blue': false,
            }
        }
    };

    // Encrypt the token (guacamole-lite expects: base64(JSON.stringify({iv, value})))
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipheriv('aes-256-cbc', Buffer.from(SECRET_KEY, 'hex'), iv);

    let encrypted = cipher.update(JSON.stringify(connectionSettings), 'utf8', 'binary');
    encrypted += cipher.final('binary');

    // Format expected by guacamole-lite Crypt class
    const tokenData = {
        iv: Buffer.from(iv).toString('base64'),
        value: Buffer.from(encrypted, 'binary').toString('base64')
    };
    const token = Buffer.from(JSON.stringify(tokenData)).toString('base64');
    res.json({ token });
});

// Serve the HTML5 client
app.get('/', (req, res) => {
    res.send(`<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>M2 Desktop</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        html, body {
            width: 100%;
            height: 100%;
            overflow: hidden;
            background: #1a1a2e;
        }
        #display {
            width: 100%;
            height: 100%;
        }
        #display canvas {
            z-index: 1 !important;
        }
        #loading {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            color: #fff;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            text-align: center;
        }
        #loading h1 { font-size: 24px; margin-bottom: 10px; }
        #loading p { font-size: 14px; opacity: 0.7; }
        .spinner {
            width: 40px;
            height: 40px;
            margin: 20px auto;
            border: 3px solid rgba(255,255,255,0.2);
            border-top-color: #fff;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        @keyframes spin { to { transform: rotate(360deg); } }
        #error {
            display: none;
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            color: #ff6b6b;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            text-align: center;
            max-width: 400px;
        }
        #error h1 { font-size: 20px; margin-bottom: 10px; }
        #error p { font-size: 14px; opacity: 0.8; }
        #reconnect {
            margin-top: 20px;
            padding: 10px 20px;
            background: #4a90d9;
            color: #fff;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 14px;
        }
        #reconnect:hover { background: #3a7bc8; }
        #status {
            position: absolute;
            bottom: 10px;
            right: 10px;
            padding: 5px 10px;
            background: rgba(0,0,0,0.5);
            color: #fff;
            font-family: monospace;
            font-size: 12px;
            border-radius: 3px;
            opacity: 0;
            transition: opacity 0.3s;
        }
        #status.visible { opacity: 1; }
    </style>
</head>
<body>
    <div id="loading">
        <h1>M2 Desktop</h1>
        <div class="spinner"></div>
        <p>Connecting to desktop...</p>
    </div>
    <div id="error">
        <h1>Connection Lost</h1>
        <p id="error-message">The connection to the desktop was interrupted.</p>
        <button id="reconnect" onclick="connect()">Reconnect</button>
    </div>
    <div id="display"></div>
    <div id="status"></div>

    <script src="/static/guacamole.min.js"></script>
    <script>
        console.log('[Guacamole] Script loaded');
        let guac;
        let connected = false;

        function showStatus(msg) {
            const status = document.getElementById('status');
            status.textContent = msg;
            status.classList.add('visible');
            setTimeout(() => status.classList.remove('visible'), 2000);
        }

        function showError(msg) {
            document.getElementById('loading').style.display = 'none';
            document.getElementById('error').style.display = 'block';
            document.getElementById('error-message').textContent = msg;
            document.getElementById('display').innerHTML = '';
        }

        async function connect() {
            console.log('[Guacamole] connect() called');
            document.getElementById('loading').style.display = 'block';
            document.getElementById('error').style.display = 'none';
            document.getElementById('display').innerHTML = '';

            try {
                // Get connection token (include credentials for basic auth)
                console.log('[Guacamole] Fetching token...');
                const tokenRes = await fetch('/api/token', { credentials: 'include' });
                console.log('[Guacamole] Token response:', tokenRes.status);
                if (!tokenRes.ok) {
                    throw new Error('Failed to get token: ' + tokenRes.status);
                }
                const { token } = await tokenRes.json();

                // Build WebSocket URL
                const wsProtocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
                const wsUrl = wsProtocol + '//' + location.host + '/websocket?token=' + encodeURIComponent(token);
                console.log('[Guacamole] WebSocket URL:', wsUrl);

                // Create Guacamole client
                console.log('[Guacamole] Creating WebSocketTunnel...');
                const tunnel = new Guacamole.WebSocketTunnel(wsUrl);
                console.log('[Guacamole] Creating Client...');
                guac = new Guacamole.Client(tunnel);

                // Add display to container
                const display = guac.getDisplay();
                const displayEl = display.getElement();
                document.getElementById('display').appendChild(displayEl);

                // Handle state changes
                console.log('[Guacamole] Setting up state handler...');
                guac.onstatechange = function(state) {
                    console.log('[Guacamole] State changed:', state);
                    switch(state) {
                        case 0: showStatus('Idle'); break;
                        case 1: showStatus('Connecting...'); break;
                        case 2: showStatus('Waiting...'); break;
                        case 3:
                            document.getElementById('loading').style.display = 'none';
                            connected = true;
                            showStatus('Connected');
                            break;
                        case 4:
                            connected = false;
                            showStatus('Disconnecting...');
                            break;
                        case 5:
                            connected = false;
                            showError('Disconnected from desktop');
                            break;
                    }
                };

                // Handle errors
                console.log('[Guacamole] Setting up error handler...');
                guac.onerror = function(error) {
                    console.error('[Guacamole] Error:', error);
                    showError(error.message || 'Connection error');
                };

                // Connect (pass empty string to avoid ?undefined being appended)
                console.log('[Guacamole] Calling guac.connect()...');
                guac.connect('');
                console.log('[Guacamole] connect() called, waiting for state changes...');

                // Handle mouse
                const mouse = new Guacamole.Mouse(displayEl);
                mouse.onmousedown = mouse.onmouseup = mouse.onmousemove = function(state) {
                    if (connected) guac.sendMouseState(state);
                };

                // Handle keyboard
                const keyboard = new Guacamole.Keyboard(document);
                keyboard.onkeydown = function(keysym) {
                    if (connected) guac.sendKeyEvent(1, keysym);
                };
                keyboard.onkeyup = function(keysym) {
                    if (connected) guac.sendKeyEvent(0, keysym);
                };

                // Handle clipboard
                guac.onclipboard = function(stream, mimetype) {
                    if (mimetype === 'text/plain') {
                        let data = '';
                        stream.onblob = function(blob) { data += atob(blob); };
                        stream.onend = function() {
                            navigator.clipboard.writeText(data).catch(() => {});
                        };
                    }
                };

                // Handle window resize
                function resize() {
                    const width = window.innerWidth;
                    const height = window.innerHeight;
                    if (connected && guac) {
                        guac.sendSize(width, height);
                    }
                }
                window.addEventListener('resize', resize);

                // Handle visibility (pause when hidden)
                document.addEventListener('visibilitychange', function() {
                    if (!connected) return;
                    // Could pause/resume streaming here if needed
                });

            } catch (err) {
                console.error('Connection failed:', err);
                showError('Failed to connect: ' + err.message);
            }
        }

        // Initial connection
        console.log('[Guacamole] Starting initial connection...');
        connect();
    </script>
</body>
</html>`);
});

// Initialize guacamole-lite WebSocket server on /websocket path
const wsOptions = {
    server: server,
    path: '/websocket'  // Explicit path to avoid conflict with Express routes
};

const guacServer = new GuacamoleLite(
    wsOptions,
    {
        host: GUACD_HOST,
        port: GUACD_PORT,
    },
    {
        crypt: {
            cypher: 'aes-256-cbc',
            key: Buffer.from(SECRET_KEY, 'hex'),
        },
        log: {
            level: process.env.GUAC_LOG_LEVEL || 'NORMAL',
        },
        connectionDefaultSettings: {
            vnc: {
                'enable-audio': true,
                'resize-method': 'display-update',
            }
        }
    }
);

// Track connected clients for multi-user info
let clientCount = 0;
guacServer.on('open', (client) => {
    clientCount++;
    console.log(`Client connected (total: ${clientCount})`);
});

guacServer.on('close', (client) => {
    clientCount--;
    console.log(`Client disconnected (total: ${clientCount})`);
});

guacServer.on('error', (client, error) => {
    console.error('Guacamole error:', error);
});

// Start server
server.listen(PORT, '0.0.0.0', () => {
    console.log(`Guacamole-lite server listening on port ${PORT}`);
    console.log(`Multi-user sessions enabled - all users share the same desktop`);
});
