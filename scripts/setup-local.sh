#!/usr/bin/env bash
# =============================================================================
# MLM Platform — Local Development Setup
# =============================================================================
# Usage: bash scripts/setup-local.sh
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_EXAMPLE="$REPO_ROOT/api/.env.example"
ENV_FILE="$REPO_ROOT/api/.env"

# Colours
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Colour

info()    { echo -e "${CYAN}[setup]${NC} $*"; }
success() { echo -e "${GREEN}[setup]${NC} $*"; }
warn()    { echo -e "${YELLOW}[setup]${NC} $*"; }

# ---------------------------------------------------------------------------
# 1. Copy .env.example → .env (skip if already exists)
# ---------------------------------------------------------------------------
info "Checking for api/.env ..."
if [ -f "$ENV_FILE" ]; then
  warn "api/.env already exists — skipping copy. Edit it manually if needed."
else
  cp "$ENV_EXAMPLE" "$ENV_FILE"
  success "Created api/.env from api/.env.example"
  warn "Review api/.env and fill in any placeholder values before proceeding."
fi

# ---------------------------------------------------------------------------
# 2. Start Docker services
# ---------------------------------------------------------------------------
info "Starting Docker services (postgres + redis) ..."
docker compose -f "$REPO_ROOT/docker-compose.yml" up -d

# ---------------------------------------------------------------------------
# 3. Wait for PostgreSQL to be ready
# ---------------------------------------------------------------------------
POSTGRES_MAX_ATTEMPTS=30
POSTGRES_ATTEMPT=0
info "Waiting for PostgreSQL to be ready ..."

until docker compose -f "$REPO_ROOT/docker-compose.yml" exec -T postgres \
      pg_isready -U mlm -d mlm -q 2>/dev/null; do
  POSTGRES_ATTEMPT=$((POSTGRES_ATTEMPT + 1))
  if [ "$POSTGRES_ATTEMPT" -ge "$POSTGRES_MAX_ATTEMPTS" ]; then
    echo ""
    echo "ERROR: PostgreSQL did not become ready after ${POSTGRES_MAX_ATTEMPTS} attempts." >&2
    echo "Run 'docker compose logs postgres' to investigate." >&2
    exit 1
  fi
  printf "."
  sleep 2
done
echo ""
success "PostgreSQL is ready."

# ---------------------------------------------------------------------------
# 4. Next steps
# ---------------------------------------------------------------------------
echo ""
success "=== Local environment is up! ==="
echo ""
echo -e "  ${CYAN}Services${NC}"
echo "  • PostgreSQL : localhost:5432  (db=mlm  user=mlm  password=mlm_local)"
echo "  • Redis      : localhost:6379"
echo ""
echo -e "  ${CYAN}Next steps${NC}"
echo "  1.  Edit api/.env and fill in OIDC_ISSUER_URL, OIDC_AUDIENCE, and any AWS values."
echo "  2.  Create a Python virtual environment:"
echo "        cd api && python -m venv .venv && source .venv/bin/activate"
echo "  3.  Install dependencies:"
echo "        pip install -r requirements.txt"
echo "  4.  Run database migrations:"
echo "        alembic upgrade head"
echo "  5.  Start the API server:"
echo "        uvicorn app.main:app --reload --port 8000"
echo ""
echo -e "  ${CYAN}Useful commands${NC}"
echo "  • Stop services      : docker compose down"
echo "  • Destroy volumes    : docker compose down -v"
echo "  • View logs          : docker compose logs -f"
echo ""
