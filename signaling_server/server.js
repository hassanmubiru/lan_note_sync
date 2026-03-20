// LanNote Sync — WebRTC Signaling Server v2
// Full-featured: rooms, relay fallback, health/metrics, CORS, graceful shutdown
// Run: node server.js  |  PORT=3000 node server.js

'use strict';
const { createServer } = require('http');
const { Server }       = require('socket.io');

const PORT        = parseInt(process.env.PORT  || '3000', 10);
const CORS_ORIGIN = process.env.CORS_ORIGIN   || '*';
const LOG_LEVEL   = process.env.LOG_LEVEL     || 'info';

// ── In-memory state ────────────────────────────────────────────────────────────

/** @type {Map<string, {socketId:string, deviceId:string, deviceName:string, roomId:string, joinedAt:number}>} */
const devices = new Map();   // deviceId → device info

/** @type {Map<string, Set<string>>} */
const rooms   = new Map();   // roomId   → Set<deviceId>

const stats = { connections: 0, messages: 0, relays: 0 };

// ── HTTP server ────────────────────────────────────────────────────────────────

const httpServer = createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', CORS_ORIGIN);

  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      status: 'ok',
      uptime: Math.floor(process.uptime()),
      devices: devices.size,
      rooms:   rooms.size,
      stats,
      timestamp: new Date().toISOString(),
    }));
  }

  if (req.url === '/rooms') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    const roomList = [...rooms.entries()].map(([id, members]) => ({
      id,
      memberCount: members.size,
      members: [...members],
    }));
    return res.end(JSON.stringify({ rooms: roomList }));
  }

  res.writeHead(404); res.end('Not found');
});

// ── Socket.IO ──────────────────────────────────────────────────────────────────

const io = new Server(httpServer, {
  path: '/socket.io',
  cors: { origin: CORS_ORIGIN, methods: ['GET', 'POST'] },
  transports: ['websocket', 'polling'],
  pingInterval: 10_000,
  pingTimeout:   5_000,
});

const log = (level, ...args) => {
  const levels = ['debug', 'info', 'warn', 'error'];
  if (levels.indexOf(level) >= levels.indexOf(LOG_LEVEL)) {
    console.log(`[${level.toUpperCase()}]`, ...args);
  }
};

io.on('connection', socket => {
  stats.connections++;
  let myDeviceId = null;
  let myRoomId   = null;

  log('info', `Socket connected: ${socket.id}`);

  // ── Join room ──────────────────────────────────────────────────────────────
  socket.on('join-room', data => {
    stats.messages++;
    myDeviceId = data.deviceId;
    myRoomId   = data.room || data.roomId || 'default';

    if (!myDeviceId) return;

    // Store device
    devices.set(myDeviceId, {
      socketId:   socket.id,
      deviceId:   myDeviceId,
      deviceName: data.deviceName || 'Unknown',
      roomId:     myRoomId,
      joinedAt:   Date.now(),
    });

    // Join Socket.IO room
    socket.join(myRoomId);
    if (!rooms.has(myRoomId)) rooms.set(myRoomId, new Set());
    rooms.get(myRoomId).add(myDeviceId);

    log('info', `${data.deviceName} (${myDeviceId}) joined room "${myRoomId}"`);

    // Send current peers to newcomer
    const existingPeers = [...rooms.get(myRoomId)]
      .filter(id => id !== myDeviceId)
      .map(id => {
        const d = devices.get(id);
        return d ? { deviceId: d.deviceId, deviceName: d.deviceName } : null;
      })
      .filter(Boolean);

    socket.emit('peers-in-room', existingPeers);

    // Notify others
    socket.to(myRoomId).emit('peer-joined', {
      deviceId:   myDeviceId,
      deviceName: data.deviceName || 'Unknown',
    });
  });

  // ── WebRTC signaling ───────────────────────────────────────────────────────
  const relay = (event, data) => {
    stats.messages++;
    const target   = data.target;
    const targetDev = devices.get(target);
    if (!targetDev) {
      socket.emit('peer-unavailable', { target, event });
      return;
    }
    io.to(targetDev.socketId).emit(event, { ...data, from: myDeviceId });
    log('debug', `${event}: ${myDeviceId} → ${target}`);
  };

  socket.on('offer',         data => relay('offer',         data));
  socket.on('answer',        data => relay('answer',        data));
  socket.on('ice-candidate', data => relay('ice-candidate', data));

  // ── Relay fallback (when data channel unavailable) ─────────────────────────
  socket.on('relay', data => {
    stats.relays++;
    relay('relay', data);
  });

  // ── Note sync (room broadcast) ─────────────────────────────────────────────
  socket.on('note-sync', data => {
    stats.messages++;
    if (myRoomId) {
      socket.to(myRoomId).emit('note-update', { ...data, from: myDeviceId });
    }
  });

  // ── Cursor positions (room broadcast) ─────────────────────────────────────
  socket.on('cursor', data => {
    if (myRoomId) socket.to(myRoomId).emit('cursor', { ...data, from: myDeviceId });
  });

  // ── Update note count ─────────────────────────────────────────────────────
  socket.on('update-meta', data => {
    if (myDeviceId && devices.has(myDeviceId)) {
      const dev = devices.get(myDeviceId);
      Object.assign(dev, data);
      if (myRoomId) socket.to(myRoomId).emit('peer-meta', { deviceId: myDeviceId, ...data });
    }
  });

  // ── Disconnect ─────────────────────────────────────────────────────────────
  socket.on('disconnect', reason => {
    log('info', `Socket ${socket.id} disconnected (${reason})`);
    if (myDeviceId) {
      devices.delete(myDeviceId);
      if (myRoomId) {
        rooms.get(myRoomId)?.delete(myDeviceId);
        if (rooms.get(myRoomId)?.size === 0) rooms.delete(myRoomId);
        io.to(myRoomId).emit('peer-left', { deviceId: myDeviceId });
      }
    }
  });
});

// ── Start ──────────────────────────────────────────────────────────────────────

httpServer.listen(PORT, '0.0.0.0', () => {
  console.log(`
╔═══════════════════════════════════════════════════════╗
║  LanNote Sync — Signaling Server v2                   ║
║                                                       ║
║  Port:      ${PORT.toString().padEnd(46)}║
║  Health:    http://localhost:${PORT}/health            ║
║  Rooms:     http://localhost:${PORT}/rooms             ║
║  CORS:      ${CORS_ORIGIN.padEnd(46)}║
╚═══════════════════════════════════════════════════════╝
`);
});

// ── Graceful shutdown ──────────────────────────────────────────────────────────

const shutdown = () => {
  console.log('\nShutting down signaling server…');
  io.emit('server-shutdown', { message: 'Server restarting', retry: 5000 });
  setTimeout(() => {
    httpServer.close(() => { console.log('Done.'); process.exit(0); });
  }, 500);
};

process.on('SIGTERM', shutdown);
process.on('SIGINT',  shutdown);
