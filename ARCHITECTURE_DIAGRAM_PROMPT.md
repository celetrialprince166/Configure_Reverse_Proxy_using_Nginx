# Docker Reverse Proxy Architecture Diagram Prompt

Create a professional Docker container architecture diagram titled "Nginx Reverse Proxy with Full-Stack Application - Container Architecture"

LAYOUT (16:9 Landscape, White Background):

TOP FLOW (User Entry - Left to Right):
[👤 User/Client Browser] → "HTTP/HTTPS" → [🌐 Internet] → [Port 8080] → [Nginx Reverse Proxy Container]

NGINX REVERSE PROXY CONTAINER (Top Center - Blue Tint Background):
┌─────────────────────────────────────────────────────────────────────┐
│                    Nginx Reverse Proxy Container                    │
│                    (nginx:1.25-alpine, Port 8080:80)                │
│                                                                     │
│ ┌──────────────────────────────────────────────────────────────┐   │
│ │ Nginx Configuration Features:                                 │   │
│ │                                                               │   │
│ │ 🔒 Security:                                                  │   │
│ │   • X-Frame-Options: SAMEORIGIN                              │   │
│ │   • X-Content-Type-Options: nosniff                          │   │
│ │   • X-XSS-Protection: 1; mode=block                          │   │
│ │   • Referrer-Policy: strict-origin-when-cross-origin          │   │
│ │   • Server tokens: off                                        │   │
│ │                                                               │   │
│ │ ⚡ Performance:                                               │   │
│ │   • Gzip compression (level 6)                               │   │
│ │   • Keepalive connections (32 per upstream)                  │   │
│ │   • Sendfile optimization                                     │   │
│ │   • Static asset caching (60m)                                │   │
│ │                                                               │   │
│ │ 🛡️ Rate Limiting:                                            │   │
│ │   • API routes: 10 req/s (burst: 20)                         │   │
│ │   • General routes: 30 req/s (burst: 50)                     │   │
│ │                                                               │   │
│ │ 📊 Logging:                                                   │   │
│ │   • Custom log format with upstream times                    │   │
│ │   • X-Forwarded-For header tracking                          │   │
│ │   • Request ID tracking                                      │   │
│ └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│ ┌──────────────────────────────────────────────────────────────┐   │
│ │ Location-Based Routing:                                      │   │
│ │                                                               │   │
│ │ /api/*          → backend_api upstream                       │   │
│ │ /health         → backend_api upstream                       │   │
│ │ /notes          → backend_api upstream                       │   │
│ │ /               → frontend_app upstream                       │   │
│ │ /_next/static   → frontend_app (cached)                      │   │
│ │ /nginx-health   → Internal health check                     │   │
│ └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│ ┌──────────────────┐         ┌──────────────────┐                │
│ │ Upstream:        │         │ Upstream:         │                │
│ │ backend_api      │         │ frontend_app      │                │
│ │ server backend:  │         │ server frontend:  │                │
│ │   3001           │         │   3000            │                │
│ │ keepalive 32     │         │ keepalive 32      │                │
│ └──────────────────┘         └──────────────────┘                │
└─────────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
                    ▼                   ▼

DOCKER NETWORK LAYER (Center - Light Gray Background):
┌─────────────────────────────────────────────────────────────────────┐
│                    Docker Bridge Network (Default)                   │
│                    Internal DNS Resolution                          │
│                                                                     │
│  Container Name Resolution:                                         │
│  • backend:3001  → Resolves to backend container IP                │
│  • frontend:3000 → Resolves to frontend container IP               │
│                                                                     │
│  Network Isolation:                                                 │
│  • Containers communicate via internal network                      │
│  • Only Nginx exposed to host (port 8080)                          │
│  • Backend/Frontend not directly accessible from host              │
└─────────────────────────────────────────────────────────────────────┘
                    │                   │
                    ▼                   ▼

BACKEND CONTAINER (Left - Orange Tint Background):
┌─────────────────────────────────────────────────────────────────────┐
│              Backend Container - NestJS API                         │
│              (node:20-alpine, Multi-stage Build)                    │
│                                                                     │
│ ┌──────────────────────────────────────────────────────────────┐   │
│ │ Build Stages:                                                │   │
│ │                                                               │   │
│ │ Stage 1: Dependencies                                        │   │
│ │   • Install production dependencies only                      │   │
│ │                                                               │   │
│ │ Stage 2: Builder                                             │   │
│ │   • Install all dependencies (including dev)                 │   │
│ │   • TypeScript compilation                                   │   │
│ │   • Build application (dist/)                                │   │
│ │                                                               │   │
│ │ Stage 3: Production                                           │   │
│ │   • Copy only production dependencies                         │   │
│ │   • Copy built application                                   │   │
│ │   • Non-root user: nestjs (UID 1001)                        │   │
│ │   • Final image size: ~250MB                                 │   │
│ └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│ ┌──────────────────────────────────────────────────────────────┐   │
│ │ Application Runtime:                                          │   │
│ │                                                               │   │
│ │ • Port: 3001 (internal)                                       │   │
│ │ • Framework: NestJS (Node.js 20.x + TypeScript)             │   │
│ │ • Health Check: GET /health (wget, 10s interval)            │   │
│ │ • Environment: Production                                     │   │
│ │                                                               │   │
│ │ REST API Endpoints:                                          │   │
│ │   GET    /api/notes          - List all notes                │   │
│ │   GET    /api/notes/:id      - Get single note                │   │
│ │   POST   /api/notes          - Create note                    │   │
│ │   PUT    /api/notes/:id      - Update note                   │   │
│ │   PUT    /api/notes/:id/pin  - Toggle pin                    │   │
│ │   DELETE /api/notes/:id      - Delete note                   │   │
│ │   GET    /health              - Health check                  │   │
│ │                                                               │   │
│ │ Features:                                                     │   │
│ │   • TypeORM for database operations                          │   │
│ │   • CORS enabled                                             │   │
│ │   • Request validation                                       │   │
│ │   • Error handling                                           │   │
│ └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼ Database Connection
                    ┌──────────────────────┐
                    │                      │
                    │  PostgreSQL Database │
                    │  (External/Container)│
                    │                      │
                    │  • Port: 5432        │
                    │  • Database: notes_db│
                    │  • Encrypted at rest │
                    │  • Connection pool   │
                    │                      │
                    └──────────────────────┘

FRONTEND CONTAINER (Right - Green Tint Background):
┌─────────────────────────────────────────────────────────────────────┐
│              Frontend Container - Next.js Application               │
│              (node:20-alpine, Multi-stage Build)                    │
│                                                                     │
│ ┌──────────────────────────────────────────────────────────────┐   │
│ │ Build Stages:                                                │   │
│ │                                                               │   │
│ │ Stage 1: Dependencies                                        │   │
│ │   • Install all npm dependencies                             │   │
│ │                                                               │   │
│ │ Stage 2: Builder                                             │   │
│ │   • Copy source code                                         │   │
│ │   • Next.js build (standalone output)                        │   │
│ │   • Static optimization                                      │   │
│ │                                                               │   │
│ │ Stage 3: Production                                           │   │
│ │   • Copy standalone output                                   │   │
│ │   • Copy static assets (.next/static)                        │   │
│ │   • Non-root user: nextjs (UID 1001)                        │   │
│ │   • Final image size: ~300MB                                 │   │
│ └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│ ┌──────────────────────────────────────────────────────────────┐   │
│ │ Application Runtime:                                          │   │
│ │                                                               │   │
│ │ • Port: 3000 (internal)                                       │   │
│ │ • Framework: Next.js 13.5.6 (React 18 + TypeScript)          │   │
│ │ • Health Check: GET / (wget, 10s interval)                   │   │
│ │ • Environment: Production                                     │   │
│ │                                                               │   │
│ │ React Components:                                            │   │
│ │   • NotesList.tsx    - Display notes with CRUD actions      │   │
│ │   • NoteForm.tsx     - Create/edit note form                 │   │
│ │   • SearchBar.tsx    - Search and filter functionality      │   │
│ │                                                               │   │
│ │ Features:                                                     │   │
│ │   • Server-side rendering (SSR)                              │   │
│ │   • Static site generation                                   │   │
│ │   • Client-side state management                             │   │
│ │   • API integration via /api/* endpoints                     │   │
│ │   • Category filtering                                       │   │
│ │   • Search functionality                                     │   │
│ └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘

REQUEST FLOW DIAGRAM (Bottom Section - Full Width):
┌─────────────────────────────────────────────────────────────────────┐
│                         Request Flow                                │
│                                                                     │
│  [Client]                                                           │
│    │                                                                │
│    │ HTTP GET http://localhost:8080/api/notes                      │
│    ▼                                                                │
│  [Nginx Reverse Proxy]                                             │
│    │                                                                │
│    │ 1. Receives request on port 8080                             │
│    │ 2. Evaluates location blocks                                  │
│    │ 3. Matches /api/* → routes to backend_api upstream           │
│    │ 4. Applies rate limiting (10 req/s)                          │
│    │ 5. Adds security headers                                      │
│    │ 6. Forwards via Docker DNS: backend:3001                      │
│    ▼                                                                │
│  [Backend Container]                                               │
│    │                                                                │
│    │ 1. NestJS receives request                                    │
│    │ 2. TypeORM queries PostgreSQL                                 │
│    │ 3. Returns JSON response                                      │
│    ▼                                                                │
│  [Nginx Reverse Proxy]                                             │
│    │                                                                │
│    │ 1. Receives response from backend                             │
│    │ 2. Applies gzip compression                                   │
│    │ 3. Adds caching headers                                       │
│    │ 4. Logs request with upstream times                          │
│    ▼                                                                │
│  [Client]                                                           │
│    │                                                                │
│    │ Receives compressed JSON response                             │
│                                                                     │
│  Frontend Request Flow:                                            │
│  [Client] → [Nginx] → [Frontend:3000] → [Next.js SSR] → [Client] │
└─────────────────────────────────────────────────────────────────────┘

SECURITY & MONITORING (Bottom Right Corner):
┌─────────────────────────────────────────────────────────────────────┐
│                    Security & Monitoring                            │
│                                                                     │
│ 🔐 Security Features:                                               │
│   • Non-root users in all containers (UID 1001)                    │
│   • Minimal Alpine Linux base images                               │
│   • Security headers (XSS, Clickjacking protection)               │
│   • Rate limiting (DDoS protection)                                 │
│   • Network isolation (Docker bridge)                              │
│                                                                     │
│ 📊 Health Checks:                                                   │
│   • Nginx: /nginx-health (30s interval)                          │
│   • Backend: /health (10s interval, 60s start period)              │
│   • Frontend: / (10s interval, 30s start period)                   │
│                                                                     │
│ 📝 Logging:                                                         │
│   • Nginx access logs with upstream metrics                        │
│   • Nginx error logs                                               │
│   • Application logs (stdout/stderr)                              │
│   • Docker container logs                                          │
└─────────────────────────────────────────────────────────────────────┘

LEGEND (Bottom Left Corner):
┌─────────────────────────────────────────────────────────────────────┐
│ Legend                                                              │
│ ━━━━━▶ HTTP Request Flow (Blue)                                    │
│ ═════▶ Database Query Flow (Purple)                                │
│ ─ ─ ─ ▶ Docker Network Communication (Green Dashed)                │
│ 🔐 Encrypted                                                        │
│ 🔒 Security Feature                                                 │
│ ⚡ Performance Optimization                                         │
│ 📊 Monitoring/Health Check                                          │
└─────────────────────────────────────────────────────────────────────┘

STYLING GUIDELINES:
- **Docker Blue**: #0DB7ED for Docker-related elements
- **Nginx Green**: #009639 for Nginx container
- **Node.js Green**: #339933 for Node.js containers
- **PostgreSQL Blue**: #336791 for database
- **Section Backgrounds**: 
  - Nginx: Light blue tint (#E6F3FF)
  - Backend: Light orange tint (#FFF4E6)
  - Frontend: Light green tint (#E6FFE6)
  - Network: Light gray (#F5F5F5)
- **Text Color**: Dark gray (#333333) for readability
- **Borders**: 2px solid, rounded corners (4px radius)
- **Font**: Clean sans-serif (similar to Inter or Roboto)
- **Icons**: Use official Docker, Nginx, Node.js, PostgreSQL icons where available
- **Shadows**: Subtle drop shadows on containers (2px offset, 4px blur, rgba(0,0,0,0.1))
- **High Contrast**: Ensure all text is readable on colored backgrounds

ANNOTATIONS TO INCLUDE:
- "Port 8080:80" on Nginx container (host:container mapping)
- "Port 3001 (internal)" on Backend container
- "Port 3000 (internal)" on Frontend container
- "Docker DNS Resolution" on network layer
- "Multi-stage Build" on both application containers
- "Non-root User (UID 1001)" on all containers
- "Alpine Linux Base" on all containers
- "Rate Limiting: 10 req/s API, 30 req/s General" on Nginx
- "Gzip Compression Level 6" on Nginx
- "Health Checks Enabled" on all containers
- "TypeORM + PostgreSQL" on backend
- "Next.js Standalone Output" on frontend
- "Encrypted at Rest" on database connection

CONTAINER DETAILS TO VISUALIZE:
1. **Nginx Container**:
   - Official Nginx logo
   - Version: 1.25-alpine
   - Port mapping: 8080:80
   - Health check endpoint visible
   - Configuration file icon

2. **Backend Container**:
   - Node.js logo
   - NestJS framework icon
   - TypeScript logo
   - Multi-stage build visualization (3 stages)
   - Port 3001 label
   - Health check icon

3. **Frontend Container**:
   - Node.js logo
   - Next.js logo
   - React logo
   - Multi-stage build visualization (3 stages)
   - Port 3000 label
   - Health check icon

4. **PostgreSQL Database**:
   - PostgreSQL elephant logo
   - Port 5432
   - Database icon with "notes_db" label
   - Connection pool visualization

5. **Docker Network**:
   - Docker network icon
   - Bridge network visualization
   - DNS resolution arrows
   - Network isolation boundary

TECHNICAL ACCURACY REQUIREMENTS:
- Show actual port numbers (8080, 3001, 3000, 5432)
- Display correct container names (nginx-proxy, backend, frontend)
- Include accurate upstream definitions (backend:3001, frontend:3000)
- Show multi-stage build process with 3 distinct stages
- Display security features accurately (non-root users, security headers)
- Include rate limiting values (10 req/s API, 30 req/s general)
- Show health check intervals correctly
- Display image sizes (~250MB backend, ~300MB frontend, ~50MB Nginx)

VISUAL HIERARCHY:
- User/Client at top left (largest)
- Nginx Reverse Proxy as central hub (prominent)
- Backend and Frontend containers side-by-side (equal size)
- Database below backend (connected)
- Network layer clearly separating external/internal
- Request flow arrows showing direction and type
- Security and monitoring section as supporting information

This diagram should clearly communicate:
1. How requests flow through the system
2. Container architecture and relationships
3. Security and performance features
4. Docker networking and DNS resolution
5. Multi-stage build optimization
6. Production-ready configuration details
