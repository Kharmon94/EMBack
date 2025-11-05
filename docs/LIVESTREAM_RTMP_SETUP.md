# RTMP Livestream Infrastructure

## Overview

The EncryptedMedia platform now supports RTMP livestreaming with HLS delivery. Artists can stream using OBS/Streamlabs, and fans can watch in their browsers with ~10-15 second latency.

## Architecture

```
┌─────────┐    RTMP    ┌──────────────┐   HLS/HTTP   ┌─────────┐
│   OBS   │──────────> │ RTMP Server  │────────────> │  Fans   │
│ (Artist)│  Push 1935 │ (Node.js)    │  Pull :8000  │(Browser)│
└─────────┘            └──────────────┘              └─────────┘
                              │
                              │ Webhooks
                              ↓
                       ┌──────────────┐
                       │ Rails Backend│
                       │   (API)      │
                       └──────────────┘
```

### Components

1. **RTMP Server** (`backend/streaming_server/`)
   - Node.js with `node-media-server`
   - Accepts RTMP streams on port 1935
   - Transcodes to HLS using FFmpeg
   - Serves HLS chunks on port 8000
   - Validates stream keys with backend API

2. **Rails Backend** (`backend/app/`)
   - Generates secure stream keys
   - Validates RTMP connections
   - Tracks stream status (scheduled/live/ended)
   - Manages viewer counts
   - Provides API for frontend

3. **Frontend** (`frontend/app/`)
   - Artist dashboard for stream management
   - OBS setup instructions
   - HLS video player for fans
   - Real-time status updates

## Database Schema

### Livestreams Table (Extended)

```ruby
# New columns added:
stream_key: string        # Unique secure key (32 hex chars)
rtmp_url: string         # RTMP server URL
hls_url: string          # HLS playlist URL
status: integer          # 0=scheduled, 1=live, 2=ended, 3=archived, 4=cancelled
started_at: datetime     # When stream went live
ended_at: datetime       # When stream ended
viewer_count: integer    # Current live viewers

# Indexes:
- stream_key (unique)
- status
```

### Status Flow

```
scheduled → live → ended → archived
           ↓
        cancelled
```

## API Endpoints

### For Artists

```
POST /api/v1/livestreams
  Creates livestream, returns RTMP credentials
  Response: { rtmp_url, stream_key, hls_url }

POST /api/v1/livestreams/:id/start
  Marks stream as ready to go live

POST /api/v1/livestreams/:id/stop
  Ends the stream
```

### For Fans

```
GET /api/v1/livestreams
  Browse live/upcoming streams
  Params: ?active=true, ?upcoming=true

GET /api/v1/livestreams/:id
  Get stream details
  Returns hls_url if live

GET /api/v1/livestreams/:id/status
  Check if stream is live (polling endpoint)
```

### For RTMP Server (Internal)

```
POST /api/v1/streaming/validate
  Validate stream key before accepting RTMP connection

POST /api/v1/streaming/stream_started
  Notify backend that stream went live

POST /api/v1/streaming/stream_ended
  Notify backend that stream ended
```

## Setup & Deployment

### Local Development

1. **Install Dependencies**:
   ```bash
   cd backend/streaming_server
   npm install
   ```

2. **Start RTMP Server**:
   ```bash
   npm start
   ```

3. **Start Rails Backend**:
   ```bash
   cd backend
   rails server
   ```

4. **Start Frontend**:
   ```bash
   cd frontend
   npm install  # Includes hls.js
   npm run dev
   ```

### Docker Setup

```bash
docker-compose up rtmp-server backend frontend
```

The `docker-compose.yml` includes the RTMP server with:
- Port 1935 for RTMP ingest
- Port 8000 for HLS delivery
- Volume mount for media files
- FFmpeg pre-installed

### Environment Variables

**RTMP Server** (`.env` or docker-compose):
```
RTMP_PORT=1935
HTTP_PORT=8000
BACKEND_API_URL=http://localhost:3000
FFMPEG_PATH=/usr/bin/ffmpeg
```

**Rails Backend**:
```
RTMP_HOST=localhost  # or rtmp-server in Docker
RTMP_PORT=1935
HLS_HOST=localhost
HLS_PORT=8000
```

## Artist Workflow

### 1. Create Livestream

Artist visits `/artist/livestreams/create` and fills out:
- Title
- Description
- Scheduled start time (optional)
- Token gate amount (optional)

Backend generates:
- Unique stream key
- RTMP URL: `rtmp://localhost:1935/live`
- HLS URL: `http://localhost:8000/live/{stream_key}/index.m3u8`

### 2. Configure OBS

Artist goes to `/artist/livestreams/{id}` and sees:
- RTMP Server URL
- Stream Key (hidden, copyable)
- Setup instructions

In OBS:
1. Settings → Stream
2. Service: Custom
3. Server: `rtmp://localhost:1935/live`
4. Stream Key: `{their_unique_key}`
5. Click "Start Streaming"

### 3. Go Live

When artist clicks "Start Streaming" in OBS:
1. RTMP server receives connection
2. Validates stream key with backend
3. Starts FFmpeg transcoding to HLS
4. Backend updates status to "live"
5. HLS chunks available at: `http://localhost:8000/live/{key}/index.m3u8`

### 4. End Stream

Artist can:
- Click "End Livestream" button in dashboard, OR
- Stop streaming in OBS

RTMP server notifies backend, status changes to "ended".

## Fan Workflow

### 1. Discover Streams

Fans browse `/livestreams`:
- Live streams shown with "LIVE" badge
- Upcoming streams shown with schedule
- Real-time viewer counts

### 2. Watch Stream

Fan clicks stream → `/livestreams/{id}`:
- If live: HLS video player loads automatically
- If not live: Shows "Stream not started" message
- Player uses hls.js for browser compatibility
- ~10-15 second latency (standard HLS)

### 3. Real-time Updates

Page polls `/livestreams/:id/status` every 10 seconds:
- Viewer count updates
- Status changes (scheduled → live → ended)
- Auto-starts player when stream goes live

## Technical Details

### HLS Transcoding

RTMP server config:
```javascript
trans: {
  ffmpeg: '/usr/bin/ffmpeg',
  tasks: [{
    app: 'live',
    hls: true,
    hlsFlags: '[hls_time=2:hls_list_size=3:hls_flags=delete_segments]'
  }]
}
```

- 2-second segments (balance latency/compatibility)
- 3 segments in playlist (6 seconds buffered)
- Auto-delete old segments (saves disk space)

### HLS Player (hls.js)

```typescript
const hls = new Hls({
  enableWorker: true,
  lowLatencyMode: true,
  backBufferLength: 90
});
hls.loadSource(hlsUrl);
hls.attachMedia(videoElement);
```

- Works in all browsers (except Safari - uses native HLS)
- Low-latency mode for faster playback
- Automatic quality switching (future)

### Security

1. **Stream Key Validation**:
   - Generated with `SecureRandom.hex(16)` (256-bit)
   - Stored in database with unique index
   - Validated before accepting RTMP connection
   - Never shown in plain text (password field in UI)

2. **Access Control**:
   - Only artist can see their stream key
   - Only artist can start/stop their stream
   - Token-gating enforced in backend
   - Public endpoints (view, status) have no auth

### Scalability Considerations

**Current Setup** (Development/MVP):
- Single RTMP server
- Local filesystem for HLS chunks
- ~10-100 concurrent viewers per stream

**Production Recommendations**:
- CDN for HLS delivery (CloudFront, Fastly)
- S3 for HLS chunk storage
- Multiple RTMP ingest servers
- Load balancer for backend API
- Redis for viewer count tracking

## Troubleshooting

### Stream not connecting

1. Check RTMP server is running:
   ```bash
   curl http://localhost:8000
   ```

2. Check backend API is accessible:
   ```bash
   curl http://localhost:3000/api/v1/streaming/validate -X POST -d '{"stream_key":"test"}'
   ```

3. Check OBS logs for connection errors

### Video not playing

1. Check HLS URL is accessible:
   ```bash
   curl http://localhost:8000/live/{stream_key}/index.m3u8
   ```

2. Check browser console for hls.js errors

3. Verify FFmpeg is installed in RTMP server:
   ```bash
   docker exec rtmp-server ffmpeg -version
   ```

### High latency

- HLS standard latency is 10-15 seconds (3x segment duration)
- To reduce: Lower segment duration (trade-off with compatibility)
- For <3s latency: Consider WebRTC or LL-HLS (future enhancement)

## Future Enhancements

### Phase 1 (Current) ✅
- RTMP ingest
- HLS delivery
- Stream management
- Basic viewer tracking

### Phase 2 (Near-term)
- [ ] Live chat
- [ ] Tipping during streams
- [ ] Multiple quality levels
- [ ] VOD recording & replay
- [ ] Stream analytics

### Phase 3 (Long-term)
- [ ] Low-latency streaming (LL-HLS or WebRTC)
- [ ] Multi-bitrate adaptive streaming
- [ ] Co-streaming / guests
- [ ] Stream scheduling & notifications
- [ ] Clips & highlights

## File Structure

```
backend/
├── streaming_server/
│   ├── server.js           # RTMP server
│   ├── package.json        # Node dependencies
│   └── Dockerfile          # Container setup
├── app/
│   ├── models/
│   │   └── livestream.rb   # Enhanced model
│   ├── services/
│   │   └── streaming_rtmp_service.rb  # Business logic
│   └── controllers/api/v1/
│       ├── livestreams_controller.rb  # Artist/fan endpoints
│       └── streaming_controller.rb    # RTMP webhooks
└── db/migrate/
    └── *_add_livestream_fields.rb     # Schema migration

frontend/
├── components/
│   └── LivestreamPlayer.tsx      # HLS video player
└── app/
    ├── livestreams/
    │   ├── page.tsx              # Browse streams
    │   └── [id]/page.tsx         # Watch stream
    └── artist/livestreams/
        ├── create/page.tsx       # Create stream
        └── [id]/page.tsx         # Stream control panel

docker-compose.yml                # Includes rtmp-server service
```

## Testing

### Manual Testing Flow

1. Create livestream as artist
2. Copy RTMP credentials
3. Open OBS:
   - Add video source (webcam or test pattern)
   - Configure stream settings
   - Start streaming
4. Open fan view page
5. Verify:
   - Video loads within 10-15 seconds
   - Viewer count increments
   - Can see live indicator
6. Stop streaming in OBS
7. Verify status updates to "ended"

### Key Metrics

- **Time to First Frame**: Should be <15 seconds
- **Buffering**: Minimal with stable connection
- **Viewer Count**: Updates within 10 seconds
- **Status Changes**: Reflected within 10 seconds

## Support

For issues or questions:
1. Check logs: RTMP server (`docker logs rtmp-server`)
2. Check Rails logs: `backend/log/development.log`
3. Check browser console for frontend errors
4. Verify environment variables are set correctly

## Resources

- [node-media-server](https://github.com/illuspas/Node-Media-Server)
- [hls.js](https://github.com/video-dev/hls.js/)
- [OBS Studio](https://obsproject.com/)
- [HLS Specification](https://datatracker.ietf.org/doc/html/rfc8216)

