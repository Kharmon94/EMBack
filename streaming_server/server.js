const NodeMediaServer = require('node-media-server');
const axios = require('axios');

// Handle Railway env var format (may or may not include http://)
const BACKEND_API_URL = process.env.BACKEND_API_URL?.startsWith('http') 
  ? process.env.BACKEND_API_URL 
  : `https://${process.env.BACKEND_API_URL || 'localhost:3000'}`;
const RTMP_PORT = parseInt(process.env.RTMP_PORT || '1935');
const HTTP_PORT = parseInt(process.env.HTTP_PORT || '8000');

const config = {
  rtmp: {
    port: RTMP_PORT,
    chunk_size: 60000,
    gop_cache: true,
    ping: 30,
    ping_timeout: 60
  },
  http: {
    port: HTTP_PORT,
    mediaroot: './media',
    allow_origin: '*',
    api: true
  },
  trans: {
    ffmpeg: process.env.FFMPEG_PATH || '/usr/bin/ffmpeg',
    tasks: [
      {
        app: 'live',
        hls: true,
        hlsFlags: '[hls_time=2:hls_list_size=3:hls_flags=delete_segments]',
        hlsKeep: false, // Delete segments after they're played
        dash: false
      }
    ]
  },
  logType: 3 // 0: error, 1: normal, 2: debug, 3: verbose
};

console.log('🎥 Starting RTMP Streaming Server...');
console.log('📡 RTMP Port:', RTMP_PORT);
console.log('🌐 HTTP Port:', HTTP_PORT);
console.log('🔗 Backend API:', BACKEND_API_URL);

const nms = new NodeMediaServer(config);

// Validate stream key before allowing publish
nms.on('prePublish', async (id, StreamPath, args) => {
  console.log('[RTMP] prePublish:', id, StreamPath, args);
  
  // Extract stream key from path (/live/{stream_key})
  const streamKey = getStreamKeyFromPath(StreamPath);
  
  if (!streamKey) {
    console.log('[RTMP] Invalid stream path:', StreamPath);
    let session = nms.getSession(id);
    session.reject();
    return;
  }
  
  console.log('[RTMP] Validating stream key:', streamKey);
  
  try {
    // Validate with backend API
    const response = await axios.post(`${BACKEND_API_URL}/api/v1/streaming/validate`, {
      stream_key: streamKey
    });
    
    if (response.data.valid) {
      console.log('[RTMP] ✅ Stream key validated for:', response.data.title);
      
      // Notify backend that stream has started
      await axios.post(`${BACKEND_API_URL}/api/v1/streaming/stream_started`, {
        stream_key: streamKey
      }).catch(err => {
        console.error('[RTMP] Failed to notify stream start:', err.message);
      });
    } else {
      console.log('[RTMP] ❌ Invalid stream key:', streamKey);
      let session = nms.getSession(id);
      session.reject();
    }
  } catch (error) {
    console.error('[RTMP] Validation error:', error.message);
    // On error, reject the stream for security
    let session = nms.getSession(id);
    session.reject();
  }
});

// Notify backend when stream ends
nms.on('donePublish', async (id, StreamPath, args) => {
  console.log('[RTMP] donePublish:', id, StreamPath);
  
  const streamKey = getStreamKeyFromPath(StreamPath);
  
  if (streamKey) {
    console.log('[RTMP] Stream ended:', streamKey);
    
    try {
      // Notify backend that stream has ended
      await axios.post(`${BACKEND_API_URL}/api/v1/streaming/stream_ended`, {
        stream_key: streamKey
      });
      
      console.log('[RTMP] ✅ Backend notified of stream end');
    } catch (error) {
      console.error('[RTMP] Failed to notify stream end:', error.message);
    }
  }
});

// Log when someone starts watching
nms.on('prePlay', (id, StreamPath, args) => {
  console.log('[HLS] Viewer connected:', StreamPath);
});

// Log when someone stops watching
nms.on('donePlay', (id, StreamPath, args) => {
  console.log('[HLS] Viewer disconnected:', StreamPath);
});

// Helper function to extract stream key from path
function getStreamKeyFromPath(path) {
  // Path format: /live/{stream_key}
  const match = path.match(/\/live\/([a-zA-Z0-9]+)/);
  return match ? match[1] : null;
}

// Start the server
nms.run();

console.log('✅ RTMP Server running');
console.log(`📺 Stream to: rtmp://localhost:${RTMP_PORT}/live/{your_stream_key}`);
console.log(`🎬 Watch at: http://localhost:${HTTP_PORT}/live/{your_stream_key}/index.m3u8`);
console.log('');

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('📴 SIGTERM received, shutting down gracefully...');
  nms.stop();
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('📴 SIGINT received, shutting down gracefully...');
  nms.stop();
  process.exit(0);
});

