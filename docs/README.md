# MLM Platform — Requirements & Architecture Documents
## Complete Document Set v1.1

**Project:** Model Lifecycle Management (MLM) Platform  
**Last Updated:** March 2026  
**Status:** Baseline — MVP build-ready  

---

## Document Index

| # | File | Document ID | Description | Status |
|---|------|-------------|-------------|--------|
| 01 | `01_FRD_Functional_Requirements.md` | MLM-FRD-001 | Functional requirements for all 7 lifecycle stages, integrations, monitoring, versioning, retirement | ✅ With CWE supersession notices |
| 02 | `02_NFR_Roles_Vendor_GenAI_Supplement.md` | MLM-NFR-001 | Non-functional requirements, full role/permission matrix, vendor model tracking, GenAI/LLM requirements | ✅ Current |
| 03 | `03_SRD_System_Requirements.md` | MLM-SRD-001 | System architecture, component design, AWS deployment, security architecture, API contracts | ✅ Updated: OpenSearch removed, workflow engine clarified |
| 04 | `04_SAD_Storage_Architecture.md` | MLM-SAD-001 | S3 bucket design, Aurora config, Redis design, lifecycle policies, backup/DR, cost optimization | ✅ Current |
| 05 | `05_IDD_Integration_Design.md` | MLM-IDD-001 | AWS tagging taxonomy, EventBridge provisioning, ServiceNow adapter, SM↔MLM registry sync | ✅ Current |
| 06 | `06_UX_Specification.md` | MLM-UX-001 | Full UI/UX spec — design system, all 20+ screens, role-adaptive home, lifecycle map, approval flows | ✅ Current |
| 07 | `07_Lovable_UI_Prompts.md` | — | 24 Lovable.dev prompt templates for building the frontend — one per major screen/component | ✅ Current |
| 08 | `08_DMD_Data_Model.md` | MLM-DMD-001 | Logical + physical data model, ERDs, all table definitions, indexes, immutability controls | ✅ With CWE extension notices |
| 09 | `09_CWE_Configurable_Workflow_Engine.md` | MLM-CWE-001 | Configurable workflow templates, attribute schema system, approval levels, 4 base templates | ✅ Current |
| 10 | `10_MVP_Scope_Document.md` | MLM-MVP-001 | MVP vs V2 vs V3 scope for every requirement, 13-week build plan, success criteria | ✅ v1.1 — OpenSearch removed, workflow engine clarified |

---

## Key Architecture Decisions (Summary)

| Decision | Choice | Reason |
|----------|--------|--------|
| **Search** | PostgreSQL tsvector + GIN index | Sufficient for MLM scale; no OpenSearch until V2 trigger |
| **Workflow engine** | Custom Python state machine + JSON config + Celery | Linear approval workflow doesn't need Temporal/Camunda/Step Functions |
| **Multi-tenancy** | Schema-per-tenant (Aurora) + tenant_id on all tables | SaaS isolation story; easy customer-deployed migration |
| **Deployment** | SaaS-first, customer-deployed-ready from day 1 | All config externalized; same Docker images, same Helm chart |
| **Auth** | OIDC abstraction (Cognito default for SaaS) | Customers bring their own IdP for self-hosted |
| **Artifact storage** | S3 only (MLM stores URIs + SHA-256 hashes) | No large files in database |
| **Audit log** | Hash-chained, Aurora RLS (INSERT only) | SR 11-7 tamper-evident requirement |
| **Model versions** | Immutable after VALIDATED (trigger-enforced) | Governance and audit defensibility |
| **Stage history** | New record per re-entry (attempt_number) | SR 11-7 requires full attempt history |
| **DES availability** | 99.99% target; Redis cache-first; FAIL_OPEN default | Critical path for all deployment pipelines |

---

## Document Relationships

```
FRD (01)  ←── What the system must do
NFR (02)  ←── How well + who can do what + GenAI/Vendor scope
SRD (03)  ←── How the system is built  [supersedes FRD §17, CWE supersedes §4.3]
SAD (04)  ←── Storage design (S3, Aurora, Redis)
IDD (05)  ←── Integration design (EventBridge, SM sync, tagging)
UX  (06)  ←── UI/UX specification
UI  (07)  ←── Lovable.dev build prompts
DMD (08)  ←── Data model [extended by CWE]
CWE (09)  ←── Workflow engine [supersedes FRD §17, SRD §4.3, DMD §4]
MVP (10)  ←── Build scope + sequence + success criteria
```

---

## MVP Infrastructure (Week 1)

The Terraform infrastructure (separate download: `mlm-week1-infrastructure.zip`) contains:
- `infra/terraform/modules/` — networking, aurora, redis, s3, ecr, ecs, cognito
- `infra/terraform/environments/staging/` — staging root module
- `README.md` — setup and deployment guide

---

## What's Next (Week 2)

Build in Antigravity IDE using Claude Sonnet:
1. FastAPI skeleton (main.py, config, health endpoints, auth middleware)
2. Alembic migrations (all schemas + tenant_id + immutability triggers)
3. Helm chart (templates for api, des, worker)
4. GitHub Actions CI/CD (lint, test, build, deploy)
5. docker-compose.yml (local dev environment)
