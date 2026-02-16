#!/usr/bin/env bash
#
# bootstrap-app.sh - Build and start all application services (PostgreSQL, Backend, Frontend, Nginx)
#
# Purpose
# -------
# Provide an industry-standard, single entrypoint script to:
#   - Build all Docker images
#   - Create the required Docker network
#   - Start PostgreSQL, backend, frontend, and Nginx reverse proxy containers
#   - Be idempotent (safe to run multiple times)
#   - Offer a symmetric destroy/teardown path
#
# This mirrors common production practices where:
#   - Infrastructure/bootstrap scripts encapsulate all startup logic
#   - Operators have a single command to bring the full stack up or down
#
# Usage
# -----
#   ./bootstrap-app.sh                 # Build (if needed) and start all services
#   ./bootstrap-app.sh --no-build      # Start services without rebuilding images
#   ./bootstrap-app.sh --destroy       # Stop and remove all containers and network
#   ./bootstrap-app.sh --dry-run       # Show what would be done without executing
#   ./bootstrap-app.sh --help          # Show help
#
# Author: Prince Tetteh Ayiku
# Version: 1.0.0
#

set -euo pipefail

# =============================================================================
# Script Configuration
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"

# Docker resources
DOCKER_NETWORK_NAME="${DOCKER_NETWORK_NAME:-notes-net}"

POSTGRES_CONTAINER_NAME="${POSTGRES_CONTAINER_NAME:-postgres-db}"
POSTGRES_IMAGE="${POSTGRES_IMAGE:-postgres:14-alpine}"
POSTGRES_DB="${POSTGRES_DB:-notes_db}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-your_password}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"

BACKEND_CONTAINER_NAME="${BACKEND_CONTAINER_NAME:-backend}"
BACKEND_IMAGE="${BACKEND_IMAGE:-notes-backend:latest}"
BACKEND_PORT="${BACKEND_PORT:-3001}"

FRONTEND_CONTAINER_NAME="${FRONTEND_CONTAINER_NAME:-frontend}"
FRONTEND_IMAGE="${FRONTEND_IMAGE:-notes-frontend:latest}"
FRONTEND_PORT="${FRONTEND_PORT:-3000}"

NGINX_CONTAINER_NAME="${NGINX_CONTAINER_NAME:-nginx-proxy}"
NGINX_IMAGE="${NGINX_IMAGE:-nginx-proxy:latest}"
NGINX_HOST_PORT="${NGINX_HOST_PORT:-8080}"

# Flags
DRY_RUN=false
NO_BUILD=false
DESTROY_MODE=false
VERBOSE=false

# Colors (disable if not terminal)
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' RESET=''
fi

# =============================================================================
# Logging Helpers
# =============================================================================

log_info()    { echo -e "${BLUE}[INFO]${RESET} $*"; }
log_success() { echo -e "${GREEN}${BOLD}[SUCCESS]${RESET} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error()   { echo -e "${RED}${BOLD}[ERROR]${RESET} $*" >&2; }
log_debug()   { [[ "${VERBOSE}" == "true" ]] && echo -e "${CYAN}[DEBUG]${RESET} $*" || true; }

log_step() {
  local step="$1"
  local total="$2"
  shift 2
  echo -e "\n${BOLD}[Step ${step}/${total}]${RESET} $*"
  echo "----------------------------------------"
}

# =============================================================================
# Helper Functions
# =============================================================================

show_help() {
  cat << 'EOF'

============================================================
 Application Bootstrap Script
============================================================

DESCRIPTION:
  Build and start all Dockerized services for the Nginx reverse
  proxy + full-stack notes application.

USAGE:
  ./bootstrap-app.sh [options]

OPTIONS:
  --no-build        Start services without rebuilding images
  --destroy         Stop and remove containers + network
  --dry-run         Show what would be done without executing
  --verbose, -v     Enable verbose output
  --help, -h        Show this help message

EXAMPLES:
  # Build images and start all services
  ./bootstrap-app.sh

  # Start services using existing images
  ./bootstrap-app.sh --no-build

  # Tear everything down
  ./bootstrap-app.sh --destroy

EOF
}

run_cmd() {
  # Wrapper to honor DRY_RUN flag
  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY RUN] $*"
  else
    eval "$@"
  fi
}

container_exists() {
  docker ps -a --format '{{.Names}}' | grep -q "^$1\$"
}

container_running() {
  docker ps --format '{{.Names}}' | grep -q "^$1\$"
}

image_exists() {
  docker image inspect "$1" >/dev/null 2>&1
}

# =============================================================================
# Prerequisites
# =============================================================================

check_prerequisites() {
  log_step 1 6 "Checking prerequisites"

  if ! command -v docker >/dev/null 2>&1; then
    log_error "Docker is not installed or not on PATH."
    log_error "Install Docker Desktop or Docker Engine before running this script."
    exit 1
  fi

  if ! docker info >/dev/null 2>&1; then
    log_error "Docker daemon is not running. Start Docker and retry."
    exit 1
  fi

  log_success "Docker is available and running"
}

ensure_network() {
  log_step 2 6 "Ensuring Docker network '${DOCKER_NETWORK_NAME}' exists"

  if docker network ls --format '{{.Name}}' | grep -q "^${DOCKER_NETWORK_NAME}\$"; then
    log_info "Network already exists: ${DOCKER_NETWORK_NAME}"
    return 0
  fi

  run_cmd "docker network create ${DOCKER_NETWORK_NAME}"
  log_success "Docker network created: ${DOCKER_NETWORK_NAME}"
}

# =============================================================================
# Build Images
# =============================================================================

build_images() {
  if [[ "${NO_BUILD}" == "true" ]]; then
    log_step 3 6 "Skipping image builds (--no-build)"
    return 0
  fi

  log_step 3 6 "Building Docker images"

  # Nginx
  log_info "Building Nginx image: ${NGINX_IMAGE}"
  run_cmd "cd \"${PROJECT_ROOT}/nginx\" && docker build -t ${NGINX_IMAGE} ."

  # Backend
  log_info "Building backend image: ${BACKEND_IMAGE}"
  run_cmd "cd \"${PROJECT_ROOT}/backend\" && docker build -t ${BACKEND_IMAGE} ."

  # Frontend
  log_info "Building frontend image: ${FRONTEND_IMAGE}"
  run_cmd "cd \"${PROJECT_ROOT}/frontend\" && docker build -t ${FRONTEND_IMAGE} ."

  log_success "All images built (or queued in dry-run mode)"
}

# =============================================================================
# Start Services
# =============================================================================

start_postgres() {
  log_step 4 6 "Starting PostgreSQL database"

  if container_running "${POSTGRES_CONTAINER_NAME}"; then
    log_info "PostgreSQL container already running: ${POSTGRES_CONTAINER_NAME}"
    return 0
  fi

  if container_exists "${POSTGRES_CONTAINER_NAME}"; then
    log_info "PostgreSQL container exists but is stopped. Starting..."
    run_cmd "docker start ${POSTGRES_CONTAINER_NAME}"
    log_success "PostgreSQL container started"
    return 0
  fi

  log_info "Creating new PostgreSQL container: ${POSTGRES_CONTAINER_NAME}"
  run_cmd "docker run -d \
    --name ${POSTGRES_CONTAINER_NAME} \
    --network ${DOCKER_NETWORK_NAME} \
    -e POSTGRES_DB=${POSTGRES_DB} \
    -e POSTGRES_USER=${POSTGRES_USER} \
    -e POSTGRES_PASSWORD=${POSTGRES_PASSWORD} \
    -p ${POSTGRES_PORT}:5432 \
    ${POSTGRES_IMAGE}"

  log_success "PostgreSQL container created and started"
}

start_backend() {
  log_step 5 6 "Starting backend (NestJS API)"

  if container_running "${BACKEND_CONTAINER_NAME}"; then
    log_info "Backend container already running: ${BACKEND_CONTAINER_NAME}"
    return 0
  fi

  local env_vars=(
    "-e DB_HOST=${POSTGRES_CONTAINER_NAME}"
    "-e DB_PORT=5432"
    "-e DB_NAME=${POSTGRES_DB}"
    "-e DB_USERNAME=${POSTGRES_USER}"
    "-e DB_PASSWORD=${POSTGRES_PASSWORD}"
    "-e PORT=${BACKEND_PORT}"
    "-e NODE_ENV=production"
  )

  if container_exists "${BACKEND_CONTAINER_NAME}"; then
    log_info "Backend container exists but is stopped. Removing and recreating for clean config..."
    run_cmd "docker rm -f ${BACKEND_CONTAINER_NAME}"
  fi

  run_cmd "docker run -d \
    --name ${BACKEND_CONTAINER_NAME} \
    --network ${DOCKER_NETWORK_NAME} \
    -p ${BACKEND_PORT}:3001 \
    ${env_vars[*]} \
    ${BACKEND_IMAGE}"

  log_success "Backend container started"
}

start_frontend() {
  log_step 6 6 "Starting frontend (Next.js)"

  if container_running "${FRONTEND_CONTAINER_NAME}"; then
    log_info "Frontend container already running: ${FRONTEND_CONTAINER_NAME}"
    return 0
  fi

  local api_url="http://${NGINX_CONTAINER_NAME}:${NGINX_HOST_PORT}/api"

  if container_exists "${FRONTEND_CONTAINER_NAME}"; then
    log_info "Frontend container exists but is stopped. Removing and recreating for clean config..."
    run_cmd "docker rm -f ${FRONTEND_CONTAINER_NAME}"
  fi

  run_cmd "docker run -d \
    --name ${FRONTEND_CONTAINER_NAME} \
    --network ${DOCKER_NETWORK_NAME} \
    -e NEXT_PUBLIC_API_URL=${api_url} \
    -e PORT=${FRONTEND_PORT} \
    -p ${FRONTEND_PORT}:3000 \
    ${FRONTEND_IMAGE}"

  log_success "Frontend container started"
}

start_nginx() {
  # This is intentionally not part of the numbered steps to keep step count stable.
  log_info "Starting Nginx reverse proxy"

  if container_running "${NGINX_CONTAINER_NAME}"; then
    log_info "Nginx container already running: ${NGINX_CONTAINER_NAME}"
    return 0
  fi

  if container_exists "${NGINX_CONTAINER_NAME}"; then
    log_info "Nginx container exists but is stopped. Removing and recreating for clean config..."
    run_cmd "docker rm -f ${NGINX_CONTAINER_NAME}"
  fi

  run_cmd "docker run -d \
    --name ${NGINX_CONTAINER_NAME} \
    --network ${DOCKER_NETWORK_NAME} \
    -p ${NGINX_HOST_PORT}:80 \
    ${NGINX_IMAGE}"

  log_success "Nginx container started"
}

start_all() {
  check_prerequisites
  ensure_network
  build_images
  start_postgres
  start_backend
  start_frontend
  start_nginx

  echo ""
  log_success "All services are up and running"
  echo ""
  echo "Application entrypoints:"
  echo "  - Frontend UI:        http://localhost:${NGINX_HOST_PORT}"
  echo "  - API (via Nginx):    http://localhost:${NGINX_HOST_PORT}/api/notes"
  echo "  - Nginx health:       http://localhost:${NGINX_HOST_PORT}/nginx-health"
  echo "  - Backend health:     http://localhost:${NGINX_HOST_PORT}/health"
  echo "  - Direct backend:     http://localhost:${BACKEND_PORT}/health"
  echo ""
}

# =============================================================================
# Destroy / Teardown
# =============================================================================

destroy_all() {
  echo ""
  echo "============================================================"
  echo "  WARNING: This will stop and remove application containers "
  echo "============================================================"
  echo ""
  echo "Containers to remove (if present):"
  echo "  - ${NGINX_CONTAINER_NAME}"
  echo "  - ${BACKEND_CONTAINER_NAME}"
  echo "  - ${FRONTEND_CONTAINER_NAME}"
  echo "  - ${POSTGRES_CONTAINER_NAME}"
  echo "Network to remove (if present):"
  echo "  - ${DOCKER_NETWORK_NAME}"
  echo ""

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY RUN] Would remove containers and network"
    return 0
  fi

  read -r -p "Type 'destroy-app' to confirm: " confirm
  if [[ "${confirm}" != "destroy-app" ]]; then
    log_info "Destruction cancelled"
    exit 0
  fi

  # Stop and remove containers (ignore errors if missing)
  for c in "${NGINX_CONTAINER_NAME}" "${BACKEND_CONTAINER_NAME}" "${FRONTEND_CONTAINER_NAME}" "${POSTGRES_CONTAINER_NAME}"; do
    if container_exists "${c}"; then
      log_info "Removing container: ${c}"
      docker rm -f "${c}" >/dev/null 2>&1 || true
    else
      log_debug "Container not found (skipping): ${c}"
    fi
  done

  # Remove network
  if docker network ls --format '{{.Name}}' | grep -q "^${DOCKER_NETWORK_NAME}\$"; then
    log_info "Removing network: ${DOCKER_NETWORK_NAME}"
    docker network rm "${DOCKER_NETWORK_NAME}" >/dev/null 2>&1 || true
  fi

  log_success "All application containers and network removed"
}

# =============================================================================
# Argument Parsing
# =============================================================================

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-build)
        NO_BUILD=true
        shift
        ;;
      --destroy)
        DESTROY_MODE=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --verbose|-v)
        VERBOSE=true
        shift
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
  done
}

# =============================================================================
# Main
# =============================================================================

main() {
  parse_args "$@"

  echo ""
  echo "============================================================"
  echo "  Application Bootstrap                                     "
  echo "============================================================"
  echo ""

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_warn "DRY RUN MODE - No changes will be made"
    echo ""
  fi

  if [[ "${DESTROY_MODE}" == "true" ]]; then
    destroy_all
  else
    start_all
  fi
}

main "$@"

