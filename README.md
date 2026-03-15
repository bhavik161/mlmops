# MLM — Model Lifecycle Management Platform

Enterprise ML governance platform. SaaS-first, customer-deployed-ready.

## Repository Structure

```
mlm/
├── api/                    # FastAPI backend
│   ├── app/
│   │   ├── core/          # Config, logging, security utilities
│   │   ├── db/            # Database connection, migrations (Alembic)
│   │   ├── middleware/    # Auth (JWT/OIDC), RBAC (OPA), request ID
│   │   ├── routers/       # API route handlers
│   │   └── main.py        # FastAPI app entrypoint
│   ├── tests/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── alembic.ini
│
├── infra/
│   └── terraform/
│       ├── modules/       # Reusable Terraform modules
│       │   ├── networking/  # VPC, subnets, NAT, SGs
│       │   ├── aurora/      # Aurora PostgreSQL cluster
│       │   ├── redis/       # ElastiCache Redis
│       │   ├── s3/          # S3 buckets (artifacts, audit, frontend, etc.)
│       │   ├── ecr/         # ECR repositories
│       │   ├── ecs/         # ECS Fargate cluster + services
│       │   ├── cognito/     # Cognito user pool (SaaS default IdP)
│       │   └── iam/         # IAM roles for ECS tasks, DES, workers
│       └── environments/
│           ├── staging/     # Staging environment root module
│           └── prod/        # Production environment root module
│
├── helm/
│   └── mlm/               # Helm chart (same chart for SaaS + customer-deployed)
│       ├── Chart.yaml
│       ├── values.yaml    # Defaults (override per environment)
│       └── templates/     # K8s manifests (Deployment, Service, ConfigMap, etc.)
│
├── .github/
│   └── workflows/
│       ├── ci.yml         # PR: lint, test, build, security scan
│       └── deploy.yml     # Push to main: deploy to staging
│
└── scripts/
    ├── setup-local.sh     # Local development setup
    └── db-migrate.sh      # Run Alembic migrations
```

## Architecture Commitments (Non-Negotiable)

1. **Zero hardcoded values** — all config via environment variables / Helm values
2. **`tenant_id` on all core tables** — multi-tenancy from migration 001
3. **OIDC abstraction** — Cognito for SaaS default; customers bring their own IdP
4. **Helm chart** — same chart deploys to SaaS (ECS) and customer-deployed (EKS)
5. **Terraform everything** — no manual AWS console actions

## Week 1 Milestone

Staging environment deployed. Health endpoints returning 200.

```
GET /health/live   → 200 {"status": "ok"}
GET /health/ready  → 200 {"status": "ok", "db": "ok", "cache": "ok"}
```

## Quick Start (Local Development)

```bash
# 1. Copy env template
cp api/.env.example api/.env

# 2. Start local dependencies (Postgres + Redis)
docker-compose up -d

# 3. Run migrations
./scripts/db-migrate.sh

# 4. Start API
cd api && uvicorn app.main:app --reload --port 8000

# 5. Check health
curl http://localhost:8000/health/live
curl http://localhost:8000/health/ready
```

## Deploy to Staging

```bash
# 1. Configure AWS credentials
export AWS_PROFILE=mlm-staging

# 2. Apply Terraform
cd infra/terraform/environments/staging
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# 3. Build + push container
./scripts/build-push.sh staging

# 4. Deploy via Helm (ECS uses Task Definition; Helm for K8s customers)
helm upgrade --install mlm ./helm/mlm \
  --namespace mlm \
  --values helm/mlm/values-staging.yaml
```

## Environment Variables

All configuration is injected — never hardcoded. See `api/.env.example` for full list.

Key variables:
```
DATABASE_URL          Aurora PostgreSQL connection string (from Secrets Manager)
REDIS_URL             ElastiCache endpoint
OIDC_ISSUER_URL       OIDC provider (Cognito, Okta, Azure AD)
OIDC_AUDIENCE         JWT audience claim
AWS_REGION            Deployment region
S3_ARTIFACTS_BUCKET   Artifact storage bucket
S3_REPORTS_BUCKET     Generated reports bucket
S3_AUDIT_BUCKET       Audit archive bucket
APP_ENV               staging | prod
LOG_LEVEL             INFO | DEBUG
FAIL_OPEN_MODE        true | false (DES fallback behavior)
```
