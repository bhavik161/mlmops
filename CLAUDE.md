# MLM Platform — Agent Context

## What This Is
Model Lifecycle Management platform. SaaS-first, customer-deployed-ready.
FastAPI + Aurora PostgreSQL + Redis + ECS Fargate + Terraform.

## Architecture Non-Negotiables
1. tenant_id on ALL core tables — multi-tenancy from migration 001
2. Zero hardcoded values — all config via environment variables
3. OIDC abstraction — not Cognito-specific in application code
4. No external workflow engine — custom Python state machine
5. No OpenSearch — PostgreSQL tsvector for full-text search
6. Schema-per-tenant for SaaS multi-tenancy

## Stack
- Backend: Python 3.11, FastAPI, SQLAlchemy 2.0, Alembic, Celery
- Database: Aurora PostgreSQL 15 (schema-per-tenant)
- Cache: Redis 7 (DES eligibility cache, sessions, rate limiting)
- Queue: Amazon SQS (workflow events, notifications, monitoring)
- Auth: OIDC (Cognito for SaaS; any OIDC provider for self-hosted)
- RBAC: Open Policy Agent (OPA sidecar)
- Infra: Terraform + ECS Fargate + Helm chart
- CI/CD: GitHub Actions

## Key Design Decisions
- Workflow engine: Python state machine + JSON config in PostgreSQL + Celery SLA jobs
- Search: PostgreSQL tsvector + GIN indexes (no OpenSearch until V2 trigger)
- DES: Independent service, Redis cache-first, FAIL_OPEN by default
- Audit log: Hash-chained, append-only, RLS prevents UPDATE/DELETE
- Model versions: Immutable after VALIDATED status (trigger-enforced)
- Stage records: New record per re-entry (attempt_number pattern)

## Current Status
Week 1: Terraform infrastructure complete
Week 2 in progress: FastAPI skeleton, Alembic migrations, Helm chart, CI/CD

## Naming Conventions
- Python: snake_case, type hints everywhere, Pydantic v2
- DB tables: plural snake_case (model_projects, model_versions)
- Schemas: mlm_core, mlm_workflow, mlm_audit, mlm_users, mlm_monitoring, mlm_integration, mlm_registry
- API: /api/v1/... prefix, cursor-based pagination, standard error envelope
- Branches: feat/week-N-description, fix/issue-description

## File Structure
api/app/core/     — config, logging, security utils
api/app/db/       — database connection, session management
api/app/middleware/ — JWT auth, OPA RBAC, request ID
api/app/routers/  — API route handlers
api/tests/        — pytest tests
infra/terraform/  — Terraform modules + environments
helm/mlm/         — Helm chart
```

---

## Step 5 — Week 2 Agent Prompts

Now you can ask Claude in Antigravity to continue building. Here are the exact prompts to use in sequence — each one is a complete agent task:

**Prompt 1 — FastAPI Skeleton:**
```
Build the FastAPI application skeleton for the MLM platform.

Create these files:
- api/requirements.txt (FastAPI, SQLAlchemy 2.0, Alembic, Celery, 
  asyncpg, redis, python-jose, pydantic-settings, boto3, structlog)
- api/app/main.py (FastAPI app with lifespan, CORS, middleware, routers)
- api/app/core/config.py (Pydantic Settings — all config from env vars, 
  zero hardcoded values)
- api/app/core/logging.py (structlog structured JSON logging with 
  tenant_id, trace_id, user_id on every log line)
- api/app/db/session.py (async SQLAlchemy engine + session factory, 
  tenant-aware connection using schema-per-tenant pattern)
- api/app/routers/health.py (/health/live and /health/ready endpoints — 
  ready checks DB + Redis connectivity)
- api/Dockerfile (multi-stage build, non-root user, health check)
- docker-compose.yml (local dev: postgres 15 + redis 7, with MLM schemas)

Requirements:
- No hardcoded values anywhere — all from config.py
- Health endpoints must work before DB is ready (live) and after (ready)
- Structured JSON logging on every request
- Request ID header (X-Request-ID) propagated through all log lines
```

**Prompt 2 — Database Migrations:**
```
Create the Alembic database migration setup and first migration for MLM.

Files to create:
- api/alembic.ini
- api/alembic/env.py (async migrations, schema-per-tenant aware)
- api/alembic/versions/001_initial_schemas.py

Migration 001 must create:
1. All 9 PostgreSQL schemas: mlm_core, mlm_workflow, mlm_audit, 
   mlm_users, mlm_monitoring, mlm_integration, mlm_registry, 
   mlm_vendor, mlm_genai
2. mlm_users.tenants table (id, name, slug, is_active, created_at)
3. mlm_users.users table with tenant_id
4. mlm_core.model_projects with ALL columns from the data model 
   including tenant_id UUID NOT NULL
5. mlm_core.model_versions with immutability trigger
6. mlm_core.stage_records with is_current partial unique index
7. mlm_audit.audit_log with RLS policy (INSERT only for app role, 
   UPDATE/DELETE blocked by trigger)
8. All required PostgreSQL ENUMs
9. PostgreSQL tsvector column + GIN index on model_projects for FTS

The tenant_id column must be on every table in mlm_core and mlm_workflow.
```

**Prompt 3 — GitHub Actions CI/CD:**
```
Create GitHub Actions workflows for the MLM platform.

Files to create:
- .github/workflows/ci.yml
  On: PR to develop or main
  Jobs: lint (ruff + mypy), test (pytest with testcontainers for 
  postgres+redis), build docker image, security scan (trivy + bandit)
  Must fail PR if CRITICAL CVEs found in image

- .github/workflows/deploy-staging.yml
  On: push to develop branch
  Jobs: build + tag image as staging-{sha}, push to ECR, 
  update ECS service (api + des + worker), run smoke test 
  (curl /health/ready), notify on failure

Use GitHub Actions OIDC for AWS authentication (no stored AWS credentials).
ECR repo URLs come from Terraform outputs stored as GitHub variables.
```

**Prompt 4 — Helm Chart:**
```
Create the Helm chart for MLM. This chart must deploy identically to 
both SaaS (ECS — for reference) and customer-deployed (EKS).

Files to create:
- helm/mlm/Chart.yaml
- helm/mlm/values.yaml (all defaults — no hardcoded values)
- helm/mlm/values-staging.yaml (staging overrides)
- helm/mlm/templates/deployment-api.yaml
- helm/mlm/templates/deployment-des.yaml  
- helm/mlm/templates/deployment-worker.yaml
- helm/mlm/templates/service-api.yaml
- helm/mlm/templates/service-des.yaml
- helm/mlm/templates/configmap.yaml (non-secret config)
- helm/mlm/templates/ingress.yaml
- helm/mlm/templates/hpa-api.yaml
- helm/mlm/templates/hpa-des.yaml
- helm/mlm/templates/_helpers.tpl

Requirements:
- All secrets injected via environment variables (not baked in)
- OIDC_ISSUER_URL must be configurable (customer brings own IdP)
- Health probes on /health/live (liveness) and /health/ready (readiness)
- DES gets its own deployment with higher minReplicas than API
- Resource requests/limits from values.yaml
```

---

## Step 6 — How to Use the Agent Effectively

A few tips specific to MLM's complexity:

**Be specific about files, not just concepts:**
```
❌ "Build the auth middleware"
✅ "Create api/app/middleware/auth.py — JWT validation using python-jose,
    RS256 only, public key fetched from OIDC_ISSUER_URL/.well-known/jwks.json
    on startup and cached. Extract tenant_id, user_id, roles[] from claims.
    Inject into request.state for downstream handlers."
```

**Reference your CLAUDE.md explicitly when it matters:**
```
"Following the architecture in CLAUDE.md — no external workflow engine,
 PostgreSQL tsvector for search — create the model registry search endpoint..."
```

**Use the terminal panel to verify as you go:**
```
After each prompt completes:
  cd api && python -m pytest tests/ -v
  docker-compose up -d && curl http://localhost:8000/health/ready
```

**Commit after each working prompt:**
Antigravity generates Artifacts — task lists, implementation plans, code diffs — allowing you to verify the agent's logic before it executes.  Review the diff, then:
```
git add .
git commit -m "feat: week-2 fastapi skeleton with health endpoints"
```

---

## The Workflow Going Forward
```
Claude.ai (this chat)          Antigravity IDE
─────────────────────          ───────────────
Architecture decisions    →    Implementation
Document generation       →    Code generation
Design questions          →    File creation + testing
"What should I build?"    →    "Build this specific thing"