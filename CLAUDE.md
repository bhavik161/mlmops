# MLM Platform — Agent Context

## What This Is
Model Lifecycle Management platform. SaaS-first, customer-deployed-ready.
FastAPI + Aurora PostgreSQL + Redis + ECS Fargate + Terraform.

## Full Specification Documents
All detailed specs are in the docs/ folder. Read the relevant 
document BEFORE writing code for that area.

| Area | Document |
|------|----------|
| Functional requirements (all stages) | docs/01_FRD_Functional_Requirements.md |
| Roles, permissions, GenAI, Vendor | docs/02_NFR_Roles_Vendor_GenAI_Supplement.md |
| System architecture, API contracts | docs/03_SRD_System_Requirements.md |
| Storage (S3, Aurora, Redis design) | docs/04_SAD_Storage_Architecture.md |
| Integrations (EventBridge, SM sync) | docs/05_IDD_Integration_Design.md |
| UI/UX all screens | docs/06_UX_Specification.md |
| Lovable frontend prompts | docs/07_Lovable_UI_Prompts.md |
| Database schema, all tables, indexes | docs/08_DMD_Data_Model.md |
| Workflow engine, approval templates | docs/09_CWE_Configurable_Workflow_Engine.md |
| MVP scope — what to build now | docs/10_MVP_Scope_Document.md |

## Architecture Non-Negotiables
1. tenant_id on ALL core tables — multi-tenancy from migration 001
2. Zero hardcoded values — all config via environment variables
3. OIDC abstraction — not Cognito-specific in application code
4. No external workflow engine — custom Python state machine
5. No OpenSearch — PostgreSQL tsvector for full-text search
6. Schema-per-tenant for SaaS multi-tenancy

## Stack
- Backend: Python 3.11, FastAPI, SQLAlchemy 2.0, Alembic, Celery
- Database: Aurora PostgreSQL 16.3 (0 ACU, auto-pause, schema-per-tenant)
- Cache: Redis 7 cache.t3.micro (DES cache, sessions, rate limiting)
- Queue: Amazon SQS (workflow events, notifications, monitoring)
- Auth: OIDC (Cognito for SaaS; any OIDC provider for self-hosted)
- RBAC: Open Policy Agent (OPA sidecar)
- Infra: Terraform + ECS Fargate + Helm chart
- CI/CD: GitHub Actions

## Key Design Decisions
- Workflow: Python state machine + JSON config in PostgreSQL + Celery SLA jobs
- Search: PostgreSQL tsvector + GIN indexes (no OpenSearch)
- DES: Independent service, Redis cache-first, FAIL_OPEN default
- Audit log: Hash-chained, append-only, RLS prevents UPDATE/DELETE
- Model versions: Immutable after VALIDATED (trigger-enforced)
- Stage records: New record per re-entry (attempt_number pattern)

## Current Build Status
- Week 1: Terraform infrastructure ✅
- Week 2: FastAPI skeleton, migrations, local dev setup (IN PROGRESS)

## Naming Conventions
- Python: snake_case, type hints everywhere, Pydantic v2
- DB tables: plural snake_case in correct schema
- Schemas: mlm_core, mlm_workflow, mlm_audit, mlm_users,
           mlm_monitoring, mlm_integration, mlm_registry,
           mlm_vendor, mlm_genai
- API: /api/v1/... prefix, cursor-based pagination
- Branches: feat/week-N-description

## Repo Structure
api/app/core/      — config, logging, security utils
api/app/db/        — database connection, session management
api/app/middleware/ — JWT auth, OPA RBAC, request ID
api/app/routers/   — API route handlers
api/tests/         — pytest tests
infra/terraform/   — Terraform modules + environments
helm/mlm/          — Helm chart
docs/              — All requirement and architecture documents
```

---

## Updated Prompt Template

With this in place, every Antigravity prompt becomes:
```
Read CLAUDE.md for project context.
Read docs/08_DMD_Data_Model.md for the exact table 
definitions before writing any database code.

Now create the Alembic migration for...