FROM node:18-bullseye

# Install FFmpeg
RUN apt-get update && \
    apt-get install -y ffmpeg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Verify FFmpeg installation and make it executable
RUN ffmpeg -version && \
    chmod +x /usr/bin/ffmpeg /usr/bin/ffprobe

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy server code
COPY server.js ./

# Create media directory for HLS chunks
RUN mkdir -p /app/media

# Expose ports
EXPOSE 1935 8000

# Set environment variables
ENV FFMPEG_PATH=/usr/bin/ffmpeg
ENV NODE_ENV=production

# Start server
CMD ["node", "server.js"]

