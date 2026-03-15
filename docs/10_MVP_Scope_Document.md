# MVP Scope Document
## Model Lifecycle Management (MLM) Platform

**Document ID:** MLM-MVP-001  
**Version:** 1.1  
**Status:** Draft  
**Classification:** Internal — Confidential  

**Change Log:**

| Version | Change |
|---------|--------|
| 1.0 | Initial release |
| 1.1 | Removed OpenSearch (replaced by PostgreSQL FTS); formalized custom state machine workflow engine (removed external workflow engine references) |

**Related Documents:** All MLM platform documents (MLM-FRD-001 through MLM-CWE-001)

---

## Document Control

| Version | Date | Author | Change Description |
|---------|------|--------|-------------------|
| 1.0 | 2024-Q4 | Product / Architecture Team | Initial release |

---

## Table of Contents

1. [Guiding Principles](#1-guiding-principles)
2. [Release Definitions](#2-release-definitions)
3. [Architecture Foundation — Non-Negotiable from Day 1](#3-architecture-foundation--non-negotiable-from-day-1)
4. [MVP Scope — Functional Requirements](#4-mvp-scope--functional-requirements)
5. [MVP Scope — Technical & Infrastructure](#5-mvp-scope--technical--infrastructure)
6. [MVP Scope — Integrations](#6-mvp-scope--integrations)
7. [MVP Scope — UI/UX](#7-mvp-scope--uiux)
8. [MVP Scope — Data Model](#8-mvp-scope--data-model)
9. [MVP Scope — Workflow Engine (CWE)](#9-mvp-scope--workflow-engine-cwe)
10. [V2 Scope](#10-v2-scope)
11. [V3 Scope](#11-v3-scope)
12. [Build Sequence & Milestones](#12-build-sequence--milestones)
13. [MVP Success Criteria](#13-mvp-success-criteria)
14. [Risk Register](#14-risk-register)
15. [Effort Estimates](#15-effort-estimates)

---

## 1. Guiding Principles

### 1.1 The MVP Mandate

The MLM MVP must answer one question in 90 days:

> **"Does a Data Scientist, ML Engineer, and Risk Officer at a mid-market company find enough value in MLM to pay for it?"**

Everything in the MVP is evaluated against this question. If a feature does not contribute to answering it within 90 days, it is deferred.

### 1.2 What the MVP Is

- A **working, deployable SaaS product** — not a prototype, not a demo
- Covers the **Internal ML model lifecycle** end-to-end (the most common and most clearly understood use case)
- Includes the **Deployment Eligibility Service** — this is the core technical value proposition that differentiates MLM from a spreadsheet
- Delivers **real governance value** — approvals, audit trail, and stage gate enforcement must work correctly from day 1
- Architecturally **dual-topology ready** — SaaS runs in production; customer-deployed runs from the same Helm chart

### 1.3 What the MVP Is Not

- It does not cover GenAI/LLM models (V2)
- It does not cover Vendor/3rd-party model tracking (V2)
- It does not include the Configurable Workflow Engine / Template Builder (V2)
- It does not include native real-time monitoring charts (V2)
- It does not include full ServiceNow/EventBridge provisioning integration (V2)
- It does not need to be perfect — it needs to be valuable

### 1.4 Deployment Architecture Commitment

The MVP is built **SaaS-first, customer-deployed-ready** from day 1:

- All configuration externalized (no hardcoded values)
- Schema-per-tenant multi-tenancy in Aurora
- Helm chart built alongside the application (not retrofitted later)
- `tenant_id` on all core tables from the first migration
- OIDC authentication abstracted (not Cognito-specific)

**This is not optional.** Retrofitting multi-tenancy costs 3 months. Adding it upfront costs 2 days.

---

## 2. Release Definitions

| Release | Timeline | Target Audience | Primary Goal |
|---------|----------|----------------|-------------|
| **MVP (v0.1)** | 0–90 days | 2–3 design partner organizations | Validate core value prop; first paying customers |
| **V1.0** | 90–180 days | Mid-market SaaS customers | General availability; complete Internal ML lifecycle |
| **V2.0** | 180–365 days | Enterprise + regulated industry | GenAI, Vendor models, CWE, customer-deployed |
| **V3.0** | Year 2 | Tier 1 banks, healthcare, government | Full compliance suite, air-gapped support |

### 2.1 Scope Legend

| Symbol | Meaning |
|--------|---------|
| ✅ **MVP** | Required for 90-day launch |
| 🔶 **V1** | Required for general availability (90–180 days) |
| 🔷 **V2** | Enterprise features (180–365 days) |
| 🔲 **V3** | Long-term roadmap (Year 2+) |
| ❌ **Deferred** | Not currently planned; revisit based on customer feedback |

---

## 3. Architecture Foundation — Non-Negotiable from Day 1

These are not features — they are architectural constraints that must be true from the first commit. Compromising on any of these creates technical debt that compounds with every feature added.

| Item | Requirement | Why Non-Negotiable |
|------|-------------|-------------------|
| **`tenant_id` on all tables** | Every core table includes `tenant_id UUID NOT NULL` | Retrofitting multi-tenancy later costs 3 months minimum |
| **Externalized configuration** | Zero hardcoded AWS account IDs, bucket names, auth provider URLs, secrets | Required for customer-deployed topology from day 1 |
| **OIDC abstraction** | Auth configured via OIDC provider URL + client credentials — works with Cognito, Okta, Azure AD, any OIDC provider | Customers bring their own IdP in customer-deployed |
| **Helm chart** | Application deployable via Helm from day 1 | Customer-deployed packaging artifact; also simplifies SaaS ops |
| **Terraform modules** | Infrastructure as Code for all AWS resources | Required for reproducible SaaS + customer-deployed environments |
| **Structured logging** | JSON-structured logs with trace_id, tenant_id, user_id on every log line | Required for multi-tenant debugging and SIEM integration |
| **Health endpoints** | `/health/live` and `/health/ready` on every service | Required for Kubernetes probes and operational monitoring |
| **Audit log from day 1** | Every state change writes to audit log before MVP is deployed | Audit trail cannot be retrofitted — missing entries are a compliance gap |
| **Schema-per-tenant** | Separate PostgreSQL schema per tenant in Aurora | SaaS isolation story; easy migration to dedicated DB later |
| **OPA for RBAC** | Authorization via OPA sidecar, not application code | COI rules and separation of duties must be policy, not code |

---

## 4. MVP Scope — Functional Requirements

### 4.1 Model Registry & Project Management

| Requirement | Scope | Notes |
|-------------|-------|-------|
| Create model project (Inception wizard) | ✅ MVP | Core entry point |
| Auto-generate Model ID (MOD-YYYY-NNNNN) | ✅ MVP | — |
| Duplicate project detection | ✅ MVP | Hash-based similarity check |
| Risk tier auto-calculation | ✅ MVP | Rule-based from inception inputs |
| Project metadata (name, domain, owner, tags, cost center) | ✅ MVP | — |
| Regulatory scope tagging (SR 11-7, FCRA, GDPR, etc.) | ✅ MVP | Multi-select, drives validation requirements |
| Data classification tagging (PII, Confidential, Internal) | ✅ MVP | — |
| Soft-delete projects | ✅ MVP | — |
| Model registry list view (searchable, filterable) | ✅ MVP | OpenSearch-backed |
| Model registry — filter by stage, tier, owner, domain | ✅ MVP | — |
| Model registry — sort by any column | ✅ MVP | — |
| Export model inventory (CSV) | ✅ MVP | SR 11-7 inventory requirement |
| Assign project roles (Owner, DS, ML Engineer, Validator) | ✅ MVP | — |
| Stakeholder notifications on project creation | ✅ MVP | Email only for MVP |
| Vendor model registration | 🔷 V2 | Separate template |
| GenAI model registration | 🔷 V2 | Separate template |
| Brownfield import from SageMaker | 🔶 V1 | Useful but not blocking |
| Duplicate model detection across tenants | ❌ Deferred | Cross-tenant search raises privacy concerns |

---

### 4.2 Stage 1 — Inception

| Requirement | Scope | Notes |
|-------------|-------|-------|
| Inception form (all mandatory fields) | ✅ MVP | Project charter, use case, risk inputs, data assessment |
| Artifact upload (PDF, DOCX, XLSX) | ✅ MVP | Presigned POST to S3 |
| Artifact download (presigned GET) | ✅ MVP | — |
| SHA-256 integrity verification on upload | ✅ MVP | Background worker |
| Stage gate submission | ✅ MVP | — |
| Gate approval — Model Owner | ✅ MVP | — |
| Gate approval — Risk Officer (Tier 1–2) | ✅ MVP | Conditional activation |
| Inline email approval (one-time token) | ✅ MVP | Core adoption driver |
| Slack approval | 🔶 V1 | High value but not blocking MVP |
| Approval SLA enforcement + escalation | ✅ MVP | 72h default SLA |
| Rejection with comments + return to rework | ✅ MVP | — |
| Conditional approval with documented conditions | ✅ MVP | — |
| AWS environment provisioning trigger (ServiceNow) | 🔷 V2 | EventBridge pattern |
| Manual AWS environment registration + tagging | 🔶 V1 | Tag registration UI |
| Tag compliance check (AWS Config integration) | 🔷 V2 | Post-provisioning |

---

### 4.3 Stage 2 — Development

| Requirement | Scope | Notes |
|-------------|-------|-------|
| MLflow integration (server-side proxy) | ✅ MVP | Core DS workflow |
| MLflow experiment run table (sortable, filterable) | ✅ MVP | — |
| Candidate model selection (MLflow run) | ✅ MVP | — |
| Immutable candidate snapshot on selection | ✅ MVP | metrics, params, signature, artifact URI, data hash |
| Metric snapshot charts (post-selection, from MLM data) | ✅ MVP | Recharts from stored snapshot |
| Development artifacts upload | ✅ MVP | Dev plan, data lineage, model card draft |
| Code repository link | ✅ MVP | URL field |
| Checklist completion tracking | ✅ MVP | Progress bar + gate unlock |
| Development gate (Model Owner approval) | ✅ MVP | — |
| SageMaker Experiments integration (via MLflow API) | ✅ MVP | Same MLflow proxy handles SM Experiments |
| Databricks MLflow integration | 🔶 V1 | Same adapter pattern, low extra effort |
| MLflow OSS integration | 🔶 V1 | Same adapter pattern |
| Azure ML integration | 🔷 V2 | Different SDK entirely |
| Bias & fairness assessment upload (Tier 1–2) | ✅ MVP | Conditional checklist item |
| SageMaker Model Package Group auto-registration | 🔶 V1 | After SM Registry sync design is stable |

---

### 4.4 Stage 3 — Validation

| Requirement | Scope | Notes |
|-------------|-------|-------|
| Validation test plan (9 standard categories) | ✅ MVP | Pre-populated based on risk tier |
| Record test results (PASS / CONDITIONAL / FAIL) | ✅ MVP | — |
| Attach evidence per test case | ✅ MVP | File upload |
| Raise findings (Critical, Major, Minor, Informational) | ✅ MVP | — |
| Findings tracker with severity badges | ✅ MVP | — |
| Remediation plan per finding | ✅ MVP | — |
| COI enforcement (DS cannot validate own model) | ✅ MVP | OPA policy |
| Validation gate — Lead Validator approval | ✅ MVP | — |
| Validation gate — Risk Officer countersignature (Tier 1) | ✅ MVP | Conditional activation |
| Validation Summary Report (PDF auto-generated) | 🔶 V1 | HTML first, PDF in V1 |
| Validation Summary Report (HTML) | ✅ MVP | Lightweight; sufficient for MVP |
| Assign external validators with role expiry | ✅ MVP | — |
| Re-validation workflow (after rollback) | ✅ MVP | New stage record per attempt |
| Validation dashboard (per project) | ✅ MVP | Test completion %, findings summary |
| Validation dataset registry | 🔷 V2 | GenAI-specific feature |
| LLM evaluation framework integrations | 🔷 V2 | GenAI-specific |
| Red team exercise tracking | 🔷 V2 | GenAI AUTONOMOUS models |

---

### 4.5 Stage 4 — Implementation

| Requirement | Scope | Notes |
|-------------|-------|-------|
| Deployment plan artifact | ✅ MVP | — |
| Deployment configuration builder (SageMaker Endpoint) | ✅ MVP | Instance type, scaling, strategy |
| Staging deployment trigger (webhook to CI/CD) | ✅ MVP | GitHub Actions / generic webhook |
| Staging smoke test results upload | ✅ MVP | — |
| Production promotion gate (ML Engineer + Model Owner) | ✅ MVP | Parallel approval |
| Deployment Eligibility API (DES) | ✅ MVP | **Core value prop — non-negotiable** |
| DES Redis cache | ✅ MVP | — |
| DES multi-region failover (DR) | 🔶 V1 | Important but not blocking MVP |
| Deployment event callback (CI/CD → MLM) | ✅ MVP | GitHub Actions webhook |
| Deployment record history | ✅ MVP | — |
| Canary deployment tracking | 🔶 V1 | — |
| Kubernetes / KServe deployment | 🔷 V2 | — |
| Azure ML endpoint deployment | 🔷 V2 | — |
| Databricks Model Serving | 🔶 V1 | — |
| Emergency rollback action | ✅ MVP | — |
| Deployment eligibility override (Risk Officer) | ✅ MVP | — |

---

### 4.6 Stage 5 — Monitoring

| Requirement | Scope | Notes |
|-------------|-------|-------|
| Monitor configuration UI (type, platform, thresholds) | ✅ MVP | At least 1 monitor required |
| Custom ingest API (POST /monitoring/ingest) | ✅ MVP | Generic push from any platform |
| SageMaker Model Monitor integration (inbound) | ✅ MVP | Via CloudWatch / S3 baseline results |
| Alert records (WARNING, CRITICAL) | ✅ MVP | — |
| Alert acknowledgement | ✅ MVP | — |
| Incident creation + resolution workflow | ✅ MVP | — |
| Alert notifications (email) | ✅ MVP | — |
| Alert notifications (Slack, PagerDuty) | 🔶 V1 | — |
| Monitoring summary cards per monitor type | ✅ MVP | Status + last value + threshold |
| Link-out to native monitoring platform | ✅ MVP | Datadog, CloudWatch, SM MM links |
| Native time-series charts (Timestream data) | 🔷 V2 | Significant build effort |
| Evidently AI integration | 🔶 V1 | Push via custom ingest API works already |
| Datadog integration (pull) | 🔶 V1 | — |
| Ground truth upload + realized metrics | 🔶 V1 | Important for Tier 1 governance |
| LLM monitoring (hallucination, toxicity, cost) | 🔷 V2 | GenAI-specific |
| LangSmith / Langfuse / Arize integration | 🔷 V2 | GenAI-specific |
| Human review queue for LLM outputs | 🔷 V2 | GenAI-specific |

---

### 4.7 Stage 6 — Versioning

| Requirement | Scope | Notes |
|-------------|-------|-------|
| Create new version (MAJOR / MINOR / PATCH) | ✅ MVP | — |
| Version lineage graph | 🔶 V1 | D3 visualization; complex to build |
| Version status tracking (IN_DEVELOPMENT through RETIRED) | ✅ MVP | — |
| Version side-by-side comparison (metrics, params) | ✅ MVP | Table comparison; no chart needed for MVP |
| Version status change notifications | ✅ MVP | — |
| Superseded version deployment block (DES) | ✅ MVP | — |
| Version retention policy enforcement | 🔶 V1 | — |
| Version lineage visual (D3 tree) | 🔷 V2 | Deferred; table view sufficient for MVP |

---

### 4.8 Stage 7 — Retirement

| Requirement | Scope | Notes |
|-------------|-------|-------|
| Retirement initiation (Model Owner) | ✅ MVP | — |
| Retirement plan artifact | ✅ MVP | — |
| DES immediately marks version RETIRING | ✅ MVP | — |
| Consumer notification (email) | ✅ MVP | — |
| Transition period (configurable, default 30 days) | ✅ MVP | — |
| Decommission gate (Model Owner approval) | ✅ MVP | — |
| Artifact archival to S3 Glacier | 🔶 V1 | S3 lifecycle rules; low effort |
| Automated deployment termination (SageMaker) | 🔶 V1 | Boto3 call on gate approval |
| Emergency retirement (Risk Officer) | ✅ MVP | Bypasses transition period |
| Retirement report (PDF) | 🔶 V1 | HTML first, PDF in V1 |

---

### 4.9 Cross-Cutting Features

| Requirement | Scope | Notes |
|-------------|-------|-------|
| Immutable audit log (all state changes) | ✅ MVP | Hash chain from day 1 |
| Audit log per-project view | ✅ MVP | — |
| Global audit log (Admin) | ✅ MVP | — |
| Audit log export (CSV) | ✅ MVP | — |
| Audit log export (JSON) | 🔶 V1 | — |
| Audit log archival to S3 Parquet | 🔶 V1 | Background job; not urgent for MVP |
| In-app notifications panel | ✅ MVP | — |
| Email notifications (approval requests, alerts, stage transitions) | ✅ MVP | SMTP |
| Slack notifications | 🔶 V1 | Webhook; low effort |
| MS Teams notifications | 🔶 V1 | Webhook |
| PagerDuty (CRITICAL alerts) | 🔶 V1 | — |
| Global cmd+K search | ✅ MVP | OpenSearch-backed |
| Role-based access control (OPA) | ✅ MVP | All 9 roles |
| COI enforcement (Dev cannot validate) | ✅ MVP | OPA policy |
| Self-approval prohibition | ✅ MVP | OPA policy |
| Approval delegation | 🔶 V1 | — |
| SSO (OIDC / SAML 2.0) | ✅ MVP | Abstract via OIDC; Cognito default for SaaS |
| SCIM user provisioning | 🔷 V2 | Enterprise feature |
| SR 11-7 compliance report package | 🔶 V1 | HTML first; PDF in V1 |
| Model inventory report (CSV) | ✅ MVP | — |
| EU AI Act register | 🔷 V2 | — |
| Tag compliance dashboard | 🔷 V2 | Requires AWS Config integration |
| Vendor model tracking | 🔷 V2 | Separate template |
| GenAI / LLM model tracking | 🔷 V2 | Separate template |
| Business Model Registry (SM↔MLM sync) | 🔶 V1 | Pre-registration soft check + sync Lambda |
| Configurable Workflow Engine (CWE) | 🔷 V2 | Fixed workflow sufficient for MVP |

---

## 5. MVP Scope — Technical & Infrastructure

### 5.1 Backend

| Item | Scope | Notes |
|------|-------|-------|
| FastAPI application (Python 3.11+) | ✅ MVP | — |
| OpenAPI spec (auto-generated) | ✅ MVP | Served at /api/docs |
| JWT authentication middleware | ✅ MVP | RS256 validation |
| OPA RBAC sidecar | ✅ MVP | — |
| Request ID propagation | ✅ MVP | X-Request-ID header |
| Rate limiting (per user, per API key) | ✅ MVP | Redis-backed |
| Celery worker pool | ✅ MVP | Artifact processing, MLflow sync, notification dispatch |
| SQS queues (workflow events, notifications, monitoring ingest) | ✅ MVP | 3 queues minimum |
| Dead-letter queues + alerting | ✅ MVP | — |
| Health endpoints (/health/live, /health/ready) | ✅ MVP | — |
| Structured JSON logging | ✅ MVP | With tenant_id, trace_id, user_id |
| Distributed tracing (OpenTelemetry) | 🔶 V1 | — |
| Prometheus metrics endpoint | 🔶 V1 | — |
| Feature flags (AWS AppConfig) | 🔶 V1 | — |
| Circuit breakers on integration calls | ✅ MVP | — |

### 5.2 Database

| Item | Scope | Notes |
|------|-------|-------|
| Aurora PostgreSQL 15 (Multi-AZ) | ✅ MVP | — |
| Schema-per-tenant isolation | ✅ MVP | Non-negotiable from day 1 |
| `tenant_id` on all core tables | ✅ MVP | Non-negotiable from day 1 |
| PgBouncer connection pooling | ✅ MVP | — |
| Audit log immutability (RLS + trigger) | ✅ MVP | — |
| Version snapshot immutability (trigger) | ✅ MVP | — |
| Aurora Serverless v2 (dev/staging) | ✅ MVP | Cost control in non-production |
| Aurora Global Database (DR) | 🔶 V1 | MVP uses single-region Multi-AZ |
| Automated backups (35-day retention) | ✅ MVP | — |
| PITR enabled | ✅ MVP | — |
| Manual weekly snapshots | 🔶 V1 | — |
| Audit log S3 Parquet archival | 🔶 V1 | Background job |

### 5.3 Caching & Search

| Item | Scope | Notes |
|------|-------|-------|
| ElastiCache Redis (DES cache + sessions + rate limits) | ✅ MVP | — |
| DES eligibility cache (5-min TTL) | ✅ MVP | — |
| DES cache prewarming | ✅ MVP | — |
| FAIL_OPEN / FAIL_CLOSED config | ✅ MVP | — |
| PostgreSQL FTS (tsvector + GIN index) | ✅ MVP | **Replaces OpenSearch entirely for MVP and V1. Handles model registry search, cmd+K global search, findings search. Sufficient for MLM's scale (thousands of projects per tenant).** |
| OpenSearch | ❌ Removed | Not needed. Add conditionally in V2/V3 if PostgreSQL FTS P95 > 500ms, or when cross-portfolio analytics / LLM trace search features are built. |
| Amazon Timestream | 🔷 V2 | Added when native time-series monitoring charts are built. For MVP, alert summaries stored in Aurora. |
| Monitoring metrics in Aurora (alert summaries only) | ✅ MVP | `mlm_monitoring.alert_records` in Aurora; no time-series store needed for MVP |

### 5.4 Infrastructure

| Item | Scope | Notes |
|------|-------|-------|
| AWS EKS (or ECS Fargate) | ✅ MVP | Decision: ECS Fargate for MVP (simpler ops), EKS for V1 |
| CloudFront + S3 (frontend CDN) | ✅ MVP | — |
| Application Load Balancer | ✅ MVP | — |
| VPC with public/private/data subnets | ✅ MVP | — |
| S3 buckets (artifacts, reports, audit-archive, frontend, upload-staging) | ✅ MVP | All 5 |
| S3 VPC Gateway Endpoint | ✅ MVP | — |
| AWS Secrets Manager (credentials) | ✅ MVP | — |
| AWS KMS (CMKs for Aurora, S3 artifact, audit) | ✅ MVP | 3 keys minimum |
| AWS WAF (CloudFront + ALB) | ✅ MVP | — |
| ECR (container registry) | ✅ MVP | — |
| AWS Cognito (SaaS default IdP) | ✅ MVP | Abstracted via OIDC — swap for customer IdP |
| Route 53 (DNS) | ✅ MVP | — |
| CloudWatch (logs + basic metrics) | ✅ MVP | — |
| DES multi-region failover | 🔶 V1 | — |
| Terraform (all infrastructure as code) | ✅ MVP | Non-negotiable |
| Helm chart (all application components) | ✅ MVP | Non-negotiable |
| GitHub Actions CI/CD pipeline | ✅ MVP | — |
| Container image CVE scanning | ✅ MVP | ECR Enhanced Scanning |
| Blue/green deployment | 🔶 V1 | Rolling deploy sufficient for MVP |

---

## 6. MVP Scope — Integrations

### 6.1 ML Platform Integrations

| Integration | Scope | Notes |
|-------------|-------|-------|
| MLflow REST API (server-side proxy + snapshot) | ✅ MVP | Core DS workflow |
| SageMaker Experiments (via MLflow API) | ✅ MVP | Same proxy |
| SageMaker Model Monitor (CloudWatch inbound) | ✅ MVP | Via custom ingest API |
| SageMaker Model Registry (outbound tag updates) | 🔶 V1 | After SM↔MLM sync Lambda built |
| Databricks MLflow | 🔶 V1 | Same adapter, low extra effort |
| MLflow OSS | 🔶 V1 | Same adapter |
| Azure ML | 🔷 V2 | Different SDK entirely |

### 6.2 CI/CD Integrations

| Integration | Scope | Notes |
|-------------|-------|-------|
| Generic outbound webhook (deployment pipeline trigger) | ✅ MVP | Covers GitHub Actions, Jenkins, CodePipeline |
| Inbound deployment event callback (POST /deployment/events) | ✅ MVP | — |
| GitHub Actions specific integration | ✅ MVP | HMAC webhook validation |
| Jenkins integration | 🔶 V1 | Same pattern, different auth |

### 6.3 Notification Integrations

| Integration | Scope | Notes |
|-------------|-------|-------|
| Email (SMTP) | ✅ MVP | Approval requests, alerts, stage transitions |
| Inline email approval (one-time token) | ✅ MVP | Core adoption driver |
| Slack (webhook) | 🔶 V1 | — |
| MS Teams (webhook) | 🔶 V1 | — |
| PagerDuty | 🔶 V1 | CRITICAL alerts |

### 6.4 Provisioning Integrations

| Integration | Scope | Notes |
|-------------|-------|-------|
| EventBridge custom bus (mlm-events) | 🔶 V1 | Required for ServiceNow trigger |
| ServiceNow API Destination | 🔷 V2 | EventBridge prerequisite |
| AWS Service Catalog adapter | 🔷 V2 | — |
| Manual tagging UI | 🔶 V1 | Tag registration + AWS Resource Groups API |
| AWS Config tag compliance rules | 🔷 V2 | — |

### 6.5 Registry Sync Integrations

| Integration | Scope | Notes |
|-------------|-------|-------|
| SM pre-registration soft check (Lambda) | 🔶 V1 | EventBridge SageMaker events |
| SM↔MLM bi-directional sync (Lambda) | 🔶 V1 | Governance tag updates |
| Reconciliation job (4-hour drift detection) | 🔶 V1 | — |
| Databricks Unity Catalog sync | 🔷 V2 | — |
| MLflow OSS Model Registry sync | 🔷 V2 | — |

---

## 7. MVP Scope — UI/UX

### 7.1 Navigation & Shell

| Feature | Scope | Notes |
|---------|-------|-------|
| Sidebar navigation (expanded + collapsed) | ✅ MVP | — |
| Top bar (breadcrumbs + global search) | ✅ MVP | — |
| cmd+K global search | ✅ MVP | — |
| Dark mode (primary) | ✅ MVP | — |
| Light mode | ❌ Deferred | Not planned |
| In-app notification panel | ✅ MVP | — |
| Role-adaptive home screens (all 4 variants) | ✅ MVP | Core UX differentiator |
| Quick access (pinned + recent projects) | 🔶 V1 | — |

### 7.2 Dashboard & Registry

| Feature | Scope | Notes |
|---------|-------|-------|
| Portfolio dashboard (metric cards + stage chart + model table) | ✅ MVP | — |
| Model registry list (search, filter, sort) | ✅ MVP | — |
| Model project cards | ✅ MVP | — |
| Risk tier badges | ✅ MVP | — |
| Status badges | ✅ MVP | — |
| CSV export from registry | ✅ MVP | — |

### 7.3 Project Workspace

| Feature | Scope | Notes |
|---------|-------|-------|
| Project header (persistent, all metadata) | ✅ MVP | — |
| Tab navigation (all stages) | ✅ MVP | — |
| Lifecycle map (7-stage visual progress tracker) | ✅ MVP | **Hero feature** |
| Stage checklist + completion progress bar | ✅ MVP | — |
| Gate submit button (disabled until complete) | ✅ MVP | — |
| Workflow history timeline | ✅ MVP | — |

### 7.4 Stage Panels

| Feature | Scope | Notes |
|---------|-------|-------|
| Inception stage panel (all fields + artifacts) | ✅ MVP | — |
| Development stage panel (experiments tab + candidate tab) | ✅ MVP | — |
| MLflow run table (server-side proxy data) | ✅ MVP | — |
| Candidate model detail (metrics + charts from snapshot) | ✅ MVP | — |
| Validation workbench (test plan + findings) | ✅ MVP | — |
| Record test result modal | ✅ MVP | — |
| Findings tracker | ✅ MVP | — |
| Implementation stage panel | ✅ MVP | — |
| Deployment eligibility status display | ✅ MVP | — |
| Monitoring summary panel (monitor cards + alerts) | ✅ MVP | — |
| Link-out to native monitoring platforms | ✅ MVP | — |
| Version explorer table | ✅ MVP | — |
| Version side-by-side comparison (table) | ✅ MVP | — |
| Version lineage graph (D3) | 🔷 V2 | Complex; table sufficient for MVP |
| Retirement stage panel | ✅ MVP | — |
| Native time-series monitoring charts | 🔷 V2 | Timestream + chart library |
| Prompt registry panel (GenAI) | 🔷 V2 | — |
| RAG configuration panel | 🔷 V2 | — |
| LLM monitoring dashboard | 🔷 V2 | — |
| Vendor model detail page | 🔷 V2 | — |
| Business model registry panel | 🔶 V1 | After SM sync built |

### 7.5 Approvals & Tasks

| Feature | Scope | Notes |
|---------|-------|-------|
| My Tasks page (pending approvals + findings + incidents) | ✅ MVP | — |
| Approval cards with context + decision buttons | ✅ MVP | — |
| Approval confirmation modal (consequence statement) | ✅ MVP | — |
| Inline approval landing page (email token) | ✅ MVP | — |
| Inline Slack approval | 🔶 V1 | — |
| Approval delegation UI | 🔶 V1 | — |
| SLA countdown on approval cards | ✅ MVP | — |

### 7.6 Admin & Compliance

| Feature | Scope | Notes |
|---------|-------|-------|
| User management (invite, deactivate, role assignment) | ✅ MVP | — |
| Integration configuration (MLflow, SageMaker) | ✅ MVP | — |
| Notification template management | 🔶 V1 | Hardcoded templates for MVP |
| Model inventory compliance table | ✅ MVP | — |
| SR 11-7 package generator | 🔶 V1 | HTML first |
| Global audit log viewer | ✅ MVP | — |
| Tag compliance dashboard | 🔷 V2 | — |
| Configurable Workflow Template Builder | 🔷 V2 | CWE feature |
| Integration health dashboard | 🔶 V1 | — |
| First-run onboarding wizard | ✅ MVP | Adoption critical |
| Contextual tooltips (first-time user) | ✅ MVP | — |

---

## 8. MVP Scope — Data Model

### 8.1 Schemas to Build for MVP

| Schema | Scope | Tables Included |
|--------|-------|----------------|
| `mlm_core` | ✅ MVP | model_projects, model_versions, stage_records, stage_artifacts, stage_comments |
| `mlm_workflow` | ✅ MVP | workflow_definitions (simplified fixed), approval_tasks, approval_decisions, workflow_activity_log |
| `mlm_audit` | ✅ MVP | audit_log (full hash chain from day 1) |
| `mlm_monitoring` | ✅ MVP | monitor_configurations, alert_records, incident_records (NO Timestream for MVP — alert summary in Aurora) |
| `mlm_integration` | ✅ MVP | integration_configs, mlflow_run_cache |
| `mlm_users` | ✅ MVP | users, global_role_assignments, project_role_assignments, tenants |
| `mlm_registry` | 🔶 V1 | business_model_registry, registry_sync_log, environment_records |
| `mlm_genai` | 🔷 V2 | All genai tables |
| `mlm_vendor` | 🔷 V2 | vendor_models |

### 8.2 Simplified Workflow Schema for MVP

The CWE configurable workflow engine is V2. For MVP, use a **simplified fixed workflow** that still enforces governance correctly:

```sql
-- MVP: workflow_definitions is a simple config table
-- Not the full CWE template system
-- Maps: stage_type + risk_tier → approval requirements

mlm_workflow.workflow_definitions (simplified MVP version)
  id, stage_type, risk_tier, sla_hours,
  required_approver_roles (JSONB array),
  min_approvers_per_role (JSONB),
  conflict_check_enabled, auto_approve_conditions (JSONB)

-- The CWE tables (workflow_templates, template_stage_definitions,
-- attribute_schemas, etc.) are built in V2 and migrated to
-- using the expand-and-contract pattern
```

### 8.3 Multi-Tenancy Schema Implementation

```sql
-- Every core table gets tenant_id from migration 001
-- Example:
ALTER TABLE mlm_core.model_projects
  ADD COLUMN tenant_id UUID NOT NULL
  REFERENCES mlm_users.tenants(id);

-- RLS as safety net (application enforces via session variable)
ALTER TABLE mlm_core.model_projects ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_policy ON mlm_core.model_projects
  USING (tenant_id = current_setting('app.tenant_id', TRUE)::UUID);

-- For schema-per-tenant (SaaS), each tenant gets their own schema:
-- mlm_acme_bank.model_projects
-- mlm_fidelity.model_projects
-- The tenant_id column provides secondary isolation and cross-tenant queries for Admin
```

### 8.4 Stage Attribute Values for MVP

The CWE `stage_attribute_values` table is V2. For MVP, stage-specific data is captured as structured fields on the stage_records table or as JSONB:

```sql
-- MVP: Add inception_data and development_data JSONB columns
-- to stage_records for structured capture without full CWE
-- V2 migration: extract to stage_attribute_values table

ALTER TABLE mlm_core.stage_records
  ADD COLUMN stage_data JSONB DEFAULT '{}';
-- Stores stage-specific structured data for MVP
-- Schema validation at application layer (Pydantic models)
-- CWE formalizes this into attribute_schemas in V2
```

---

## 9. MVP Scope — Workflow Engine (CWE)

### 9.1 Workflow Engine Approach

**No external workflow engine is used.** The MLM workflow engine is a custom Python state machine — the right tool for a linear human-approval governance workflow.

| Component | Technology | Purpose |
|-----------|-----------|---------|
| State machine | Python `WorkflowEngine` class | Stage transitions, approval routing, gate evaluation |
| Workflow config | JSON in PostgreSQL (`workflow_definitions`) | Per-stage approval levels, SLAs, gate rules |
| SLA monitoring | Celery beat task (every 15 min) | Detects breached deadlines, escalation notifications |
| Async events | Amazon SQS | Stage transitions → notification worker, DES cache invalidation |

See `MLM-SRD-001` Section 4.3 for the full implementation specification including Python code, JSON config schema, and SQS event catalog.

**Rejected alternatives:** Temporal (microservice orchestration — wrong tool), Camunda (heavy BPMN Java engine — wrong tool), AWS Step Functions (awkward human approval callbacks, vendor lock-in — wrong tool), Apache Airflow (data pipeline tool — wrong domain entirely).

### 9.2 CWE Configurable Template System (V2)

The full CWE (MLM-CWE-001) is a V2 feature. For MVP:

| CWE Feature | MVP Approach | V2 Migration Path |
|-------------|-------------|-------------------|
| Workflow templates | Fixed Internal ML workflow only; JSON config in DB | Add template system on top of fixed config |
| Stage definitions | Fixed 7-stage sequence | Template-driven stage sequence |
| Attribute schemas | Pydantic models per stage (application layer) | Migrate to admin-configurable attribute_schemas |
| Approval levels | Fixed per-stage JSON config in workflow_definitions | Migrate to approval_level_definitions |
| Gate rules | JSON gate_rules array in workflow_definitions | Migrate to configurable gate_rules table |
| Template builder UI | None | CWE Admin UI in V2 |
| GenAI template | None | BASE-GENAI-LLM-V1 in V2 |
| Vendor template | None | BASE-VENDOR-V1 in V2 |

**Migration commitment:** The `stage_data` JSONB column on `stage_records` is specifically designed for forward compatibility — CWE V2 formalizes these values into the attribute schema system without losing MVP data.

---

## 10. V2 Scope

V2 targets **general availability** and **enterprise readiness** (Days 180–365):

### 10.1 Platform Features

- Configurable Workflow Engine (CWE) — full template builder, all 4 base templates
- GenAI / LLM model lifecycle (BASE-GENAI-LLM-V1 template)
- Vendor / 3rd party model tracking (BASE-VENDOR-V1 template)
- Fine-tuned model template (BASE-FINE-TUNED-V1)
- Prompt registry (versioned system prompts)
- RAG configuration tracking
- LLM evaluation framework integrations (RAGAS, DeepEval, MLflow evaluate)
- LLM monitoring (hallucination, toxicity, groundedness, cost)
- LangSmith / Langfuse / Arize Phoenix integration

### 10.2 Infrastructure & Integrations

- Amazon Timestream (monitoring time-series storage)
- Native time-series monitoring charts in MLM UI
- DES multi-region active-passive failover
- SM↔MLM bi-directional registry sync (Lambda + EventBridge)
- SM pre-registration soft check
- EventBridge custom bus (mlm-events)
- ServiceNow provisioning trigger
- Manual AWS tag registration UI
- Databricks MLflow + Unity Catalog integration
- Slack inline approval
- PagerDuty CRITICAL alert integration
- SCIM user provisioning

### 10.3 Governance & Compliance

- SR 11-7 compliance report packages (PDF)
- Retirement report (PDF)
- EU AI Act register
- Ground truth upload + realized metrics
- Approval delegation UI
- Version lineage graph (D3)
- Audit log S3 Parquet archival
- Tag compliance dashboard

### 10.4 Customer-Deployed Packaging

- Helm chart fully documented and tested for customer deployment
- Terraform module for customer AWS environment setup
- Customer IdP OIDC configuration guide
- Customer-deployed support tier definition
- LTS release policy (minimum 12-month support per version)
- Self-hosted installation documentation

---

## 11. V3 Scope

V3 targets **regulated enterprise and Tier 1 financial services** (Year 2):

- Air-gapped / on-premise deployment (no internet egress required)
- JIRA Service Management provisioning integration
- Full Azure ML lifecycle integration
- GCP Vertex AI integration
- Advanced bias and fairness dashboards (per-cohort, time-series)
- NIST AI RMF full assessment module
- EU AI Act conformity assessment documentation generator
- Model risk committee workflow templates
- Cross-portfolio risk analytics (risk patterns across all models)
- Custom report builder (admin-configurable compliance reports)
- SOC 2 Type II certification
- FedRAMP authorization (US government deployments)
- Advanced RBAC (custom roles, attribute-based access control)
- API marketplace / partner integration program

---

## 12. Build Sequence & Milestones

### 12.1 90-Day MVP Build Plan

```
WEEK 1–2: Foundation
  ├── Repository setup (monorepo: api/, frontend/, infra/, helm/)
  ├── Terraform: VPC, Aurora, Redis, S3, ECR, Cognito
  ├── Database: All MVP schemas + migrations (including tenant_id)
  ├── Helm chart skeleton (configurable, no hardcoded values)
  ├── FastAPI skeleton (health endpoints, OIDC middleware, OPA sidecar)
  ├── GitHub Actions CI pipeline (lint, test, build, push to ECR)
  └── ECS Fargate deployment (staging environment working)

WEEK 3–4: Core Data Layer
  ├── mlm_core schema: model_projects, model_versions, stage_records,
  │   stage_artifacts, stage_comments
  ├── mlm_users schema: users, tenants, role_assignments
  ├── mlm_workflow schema: workflow_definitions (simplified),
  │   approval_tasks, approval_decisions, workflow_activity_log
  ├── mlm_audit schema: audit_log (hash chain + RLS)
  ├── API: CRUD for model_projects, model_versions
  └── OPA policies: all 9 roles, COI check, self-approval prohibition

WEEK 5–6: Model Registry & Inception
  ├── Model project creation (full inception form)
  ├── Risk tier auto-calculation
  ├── Artifact upload (presigned POST + worker processing + SHA-256)
  ├── Stage gate submission + approval workflow
  ├── Inline email approval (one-time token)
  ├── Approval SLA + email notifications (SMTP)
  ├── Audit log writing on all actions
  └── OpenSearch setup + model registry search

WEEK 7–8: Development Stage + MLflow Integration
  ├── MLflow server-side proxy (service account auth)
  ├── MLflow run table (polling + cache in mlflow_run_cache)
  ├── Candidate model selection + immutable snapshot
  ├── Metric snapshot storage + Recharts rendering
  ├── Development artifacts + checklist
  └── Development gate (Model Owner approval)

WEEK 9–10: Validation + DES
  ├── Validation test plan (9 categories, tier-driven)
  ├── Test result recording + evidence upload
  ├── Findings tracker (raise, remediate, resolve)
  ├── Validation gate (Lead Validator + Risk Officer for Tier 1)
  ├── COI enforcement (OPA policy active)
  ├── DES implementation (Redis cache + FAIL_OPEN/CLOSED)
  ├── DES Deployment Eligibility API (public endpoint)
  └── DES cache prewarming (SQS consumer)

WEEK 11–12: Implementation + Monitoring + Frontend
  ├── Implementation stage panel (deployment config + pipeline webhook)
  ├── Production promotion gate (parallel approval)
  ├── Deployment event callback endpoint
  ├── Monitoring configuration + alert records
  ├── Custom ingest API (POST /monitoring/ingest)
  ├── SageMaker Model Monitor inbound (CloudWatch)
  ├── Incident creation + resolution
  ├── Versioning (create, compare, DES eligibility enforcement)
  ├── Retirement workflow (initiation + transition + decommission)
  └── Lovable prompts → React frontend (all MVP UI screens)

WEEK 13 (Buffer):
  ├── End-to-end testing (full lifecycle for 2 test models)
  ├── Load testing (DES: 500 req/sec; API: 500 concurrent users)
  ├── Security review (OWASP Top 10, Trivy image scan)
  ├── Design partner onboarding (2–3 organizations)
  └── Documentation (user guide, API reference, deployment guide)
```

### 12.2 Key Milestones

| Milestone | Target Week | Definition of Done |
|-----------|------------|-------------------|
| **M1: Infrastructure Running** | Week 2 | Staging environment deployed via Terraform + Helm; health endpoints return 200 |
| **M2: First Model Project Created** | Week 5 | Full inception workflow complete; artifact uploaded; gate approved; audit log written |
| **M3: First MLflow Run Synced** | Week 8 | MLflow run appears in Development stage; candidate selected; snapshot stored |
| **M4: DES Live** | Week 10 | Deployment Eligibility API returns correct ELIGIBLE/INELIGIBLE; Redis cache working; validated model returns ELIGIBLE |
| **M5: Full Lifecycle Complete** | Week 12 | One test model completes all 7 stages inception→retirement; full audit trail correct |
| **M6: Design Partner Onboarded** | Week 13 | First external organization running their first real model project in MLM |

---

## 13. MVP Success Criteria

The MVP is successful when the following are all true:

### 13.1 Technical Criteria

| Criterion | Target | Measurement |
|-----------|--------|-------------|
| DES P95 latency | < 150ms | k6 load test: 500 RPS, 5-min sustained |
| API P95 latency (read) | < 500ms | k6 load test: 500 VUs, 10-min sustained |
| DES availability | > 99.9% (first 30 days) | CloudWatch availability metric |
| COI enforcement | 100% | Security test: DS user cannot approve own validation |
| Audit log completeness | 100% of state changes logged | E2E test: trace full lifecycle, count expected vs actual audit entries |
| Model version immutability | 0 successful modification attempts post-validation | Security test |
| Full lifecycle (Inception → Retirement) | Completes without errors | E2E regression test |

### 13.2 Product Criteria

| Criterion | Target | Measurement |
|-----------|--------|-------------|
| Design partners onboarded | ≥ 2 organizations | — |
| Real model projects created | ≥ 5 (across design partners) | Registry count |
| Approval workflow used | ≥ 10 approvals completed | Audit log query |
| DES queried by external system | ≥ 1 CI/CD pipeline integrated | DES access log |
| NPS / satisfaction | ≥ 7/10 from design partner users | Survey at week 8 and week 13 |

### 13.3 Business Criteria

| Criterion | Target |
|-----------|--------|
| First paying customer (or signed LOI) | ≥ 1 by week 13 |
| Design partners willing to be references | ≥ 1 |
| Identified V2 requirements from real usage | ≥ 5 confirmed customer requests |

---

## 14. Risk Register

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| MLflow proxy auth complexity (different platforms use different auth) | High | Medium | Build auth adapter abstraction in week 7; test against SageMaker + self-hosted MLflow before committing |
| DES availability SLA missed at launch | Medium | High | Single-region MVP with FAIL_OPEN default; multi-region in V1 |
| Schema-per-tenant migration complexity at 50+ tenants | Medium | Medium | Aurora cluster supports this; automate schema creation + migration runner |
| Lovable-generated frontend requires significant manual rework | High | Medium | Treat Lovable as scaffolding; plan 30–40% manual cleanup time in weeks 11–12 |
| Design partners don't have SR 11-7 use case | Low | High | Qualify design partners before week 1; target financial services or healthcare |
| CWE migration (V2) breaks MVP stage records | Medium | High | `stage_data` JSONB column explicitly designed for forward compatibility; test migration script before V2 build |
| Customer-deployed Helm chart untested at MVP | Medium | Medium | Test Helm chart in clean AWS account in week 12; customer-deployed design partners require this |
| Audit log hash chain performance under load | Low | Medium | Advisory lock is microsecond-range; load test audit writes at 1000 TPS; if issue, batch hash verification is fallback |
| OIDC abstraction leaks Cognito-specific assumptions | Medium | High | Code review gate: no `cognito` string in application code; only in Terraform/Helm config |

---

## 15. Effort Estimates

### 15.1 Engineering Effort (Solo or Small Team)

| Component | MVP Effort | V1 Additional | V2 Additional |
|-----------|-----------|---------------|---------------|
| Infrastructure (Terraform + Helm) | 2 weeks | 1 week | 1 week |
| Database schema + migrations | 1 week | 0.5 weeks | 2 weeks (CWE) |
| Backend API (FastAPI) | 4 weeks | 3 weeks | 4 weeks |
| MLflow integration + DES | 2 weeks | 1 week (SM sync) | 1 week |
| Workflow engine (simplified MVP) | 1 week | — | 3 weeks (CWE) |
| Frontend (Lovable + manual wiring) | 3 weeks | 2 weeks | 3 weeks |
| Testing (E2E + load + security) | 1 week | 1 week | 1 week |
| **Total** | **~14 weeks** | **~8 weeks** | **~15 weeks** |

> Note: 14 weeks vs 13-week target assumes 1 developer full-time. With 2 developers (backend + frontend split), the MVP is achievable in 10 weeks.

### 15.2 Infrastructure Cost Estimates (MVP, SaaS)

| Resource | Monthly Cost (MVP, 10 tenants) | Monthly Cost (V1, 50 tenants) |
|----------|-------------------------------|-------------------------------|
| Aurora PostgreSQL (writer + 1 reader) | ~$600 | ~$1,200 |
| ElastiCache Redis (2 nodes) | ~$150 | ~$300 |
| ECS Fargate (API + workers) | ~$200 | ~$500 |
| S3 (all buckets) | ~$50 | ~$200 |
| CloudFront + WAF | ~$50 | ~$100 |
| SQS + misc AWS services | ~$30 | ~$80 |
| **Total** | **~$1,080/mo** | **~$2,380/mo** |

> **Saving vs prior estimate:** ~$200/month (OpenSearch removed). PostgreSQL FTS handles all search needs at no additional cost.  
> At $1,080/mo infrastructure cost, SaaS pricing of $500/model/month becomes profitable at 3 active models. Even at $200/model/month, break-even is 6 models across all tenants.

**OpenSearch (if/when added in V2/V3):** ~$200–400/month additional for a 2-node cluster. Add only when PostgreSQL FTS P95 exceeds 500ms or cross-portfolio analytics feature is built.

---

*End of MVP Scope Document*  
*MLM Platform — MLM-MVP-001 v1.0*
