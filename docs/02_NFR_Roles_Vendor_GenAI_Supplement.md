# MOA Requirements Supplement
## Non-Functional Requirements · Role Matrix · Third-Party Model Tracking · GenAI/LLM/SLM Capabilities

**Document Version:** 1.0  
**Supplements:** `mlops_model_lifecycle_requirements.md` v1.0  
**Status:** Draft  

---

## Table of Contents

1. [Detailed Non-Functional Requirements](#1-detailed-non-functional-requirements)
2. [Role Matrix & Permission Design](#2-role-matrix--permission-design)
3. [Third-Party & Vendor Model Tracking](#3-third-party--vendor-model-tracking)
4. [GenAI, LLM & SLM Requirements](#4-genai-llm--slm-requirements)

---

## 1. Detailed Non-Functional Requirements

### 1.1 Performance NFRs

#### 1.1.1 Response Time

| Scenario | Target (P50) | Target (P95) | Target (P99) | Notes |
|----------|-------------|-------------|-------------|-------|
| UI page load (initial, authenticated) | < 1.0s | < 2.0s | < 3.5s | Includes API + render |
| UI page load (subsequent, cached) | < 0.4s | < 0.8s | < 1.5s | Client-side caching |
| REST API — list/read operations | < 150ms | < 500ms | < 900ms | Excludes external I/O |
| REST API — write/transition operations | < 300ms | < 800ms | < 1.5s | Includes DB write + audit |
| Deployment Eligibility API | < 50ms | < 150ms | < 200ms | Cache-first; critical path |
| MLflow experiment sync (polling) | — | < 60s lag | < 120s lag | Background ingest |
| Monitoring metric ingest (async queue) | — | < 30s end-to-end | < 90s | Queue-buffered |
| Report generation (inventory/compliance) | < 5s | < 15s | < 30s | Async with progress indicator |
| Audit log query (30-day window) | < 500ms | < 2s | < 5s | Indexed by timestamp + entity |
| Search (full-text, 10k+ projects) | < 300ms | < 800ms | < 1.5s | Elasticsearch / OpenSearch |

#### 1.1.2 Throughput

| Component | Target Throughput | Burst Capacity |
|-----------|------------------|----------------|
| REST API (aggregate) | 1,000 req/sec sustained | 3,000 req/sec (60s) |
| Deployment Eligibility API | 500 req/sec sustained | 2,000 req/sec |
| Monitoring metric ingest | 10,000 metric events/sec | 50,000 events/sec |
| Concurrent active users (UI) | 500 | 1,000 |
| Concurrent API consumers | 200 | 500 |
| Model projects in registry | 50,000+ | — |
| Model versions per project | 1,000+ | — |

#### 1.1.3 Data Volume

- Audit log: support 10M+ entries with < 2s query on indexed fields.
- Monitoring time-series: support 1B+ metric data points with efficient windowed aggregation.
- Artifact metadata: support 500K+ artifact records; physical files stored externally (S3/ADLS).

---

### 1.2 Availability & Reliability NFRs

| Component | Availability SLA | Rationale |
|-----------|-----------------|-----------|
| Deployment Eligibility API | 99.99% (< 52 min/year) | Deployment pipelines block on this; outage = deployment halt |
| Core MOA Application (UI + API) | 99.9% (< 8.7 hrs/year) | Operational governance platform |
| Monitoring Ingest Pipeline | 99.5% (< 44 hrs/year) | Async queue buffers brief outages |
| Background Workers (sync jobs) | 99.0% | Best-effort; catch-up on recovery |
| Reporting / Batch Exports | 99.0% | Non-real-time; retryable |

#### 1.2.1 Fault Tolerance Requirements

- **REQ-NFR-AVL-001:** The Deployment Eligibility API shall maintain a local read-through cache of model eligibility decisions (TTL: 5 minutes) so that a database unavailability does not immediately block deployments. Stale-cache behavior shall be configurable: `FAIL_OPEN` (allow with warning) or `FAIL_CLOSED` (block with alert).
- **REQ-NFR-AVL-002:** The system shall implement circuit breakers on all outbound integration calls (SageMaker, Databricks, MLflow) with configurable open/closed/half-open thresholds.
- **REQ-NFR-AVL-003:** All asynchronous operations (metric ingestion, notification delivery, platform sync) shall use persistent message queues (SQS or Kafka) with at-least-once delivery guarantees and dead-letter queues for failed messages.
- **REQ-NFR-AVL-004:** The system shall support a **degraded mode** — if integration adapters are offline, core lifecycle management (stage transitions, approvals, artifact uploads) shall continue operating with integration features temporarily suspended.
- **REQ-NFR-AVL-005:** Planned maintenance windows shall not exceed 30 minutes and shall be achievable via rolling deployments with zero user-facing downtime.

#### 1.2.2 Disaster Recovery

| Metric | Target |
|--------|--------|
| Recovery Time Objective (RTO) | < 1 hour (core app); < 15 min (Eligibility API) |
| Recovery Point Objective (RPO) | < 5 minutes (transactional data); < 1 hour (monitoring time-series) |
| Backup Frequency | Continuous (WAL-based) for primary DB; hourly snapshots for secondary stores |
| Backup Retention | 30 days online; 7 years in cold archive |
| DR Test Frequency | Quarterly full DR drill |

---

### 1.3 Scalability NFRs

- **REQ-NFR-SCL-001:** All stateless application tiers (API servers, workers) shall be horizontally scalable without architectural changes, deployable on Kubernetes with HPA (Horizontal Pod Autoscaler) or equivalent.
- **REQ-NFR-SCL-002:** The monitoring ingest pipeline shall support **consumer group scaling** — additional consumer instances may be added to the queue consumer pool to increase ingest throughput without redeployment.
- **REQ-NFR-SCL-003:** The database tier shall support read replicas for read-heavy operations (search, reporting, eligibility cache warm) to avoid read pressure on the primary write instance.
- **REQ-NFR-SCL-004:** Time-series monitoring data shall be stored in a purpose-built time-series store (e.g., Amazon Timestream, InfluxDB, or Prometheus with Thanos) separate from the relational store to enable independent scaling.
- **REQ-NFR-SCL-005:** The system shall support **multi-tenancy** at the organizational unit (OU) level — large enterprises may segment model projects by business unit with logically isolated data scopes while sharing infrastructure.
- **REQ-NFR-SCL-006:** Full-text search shall use a dedicated search engine (Amazon OpenSearch or Elasticsearch) that can be independently scaled from the primary data store.

---

### 1.4 Observability NFRs

- **REQ-NFR-OBS-001:** The system shall expose **structured application logs** (JSON, ECS or OTEL format) for all API requests, background jobs, integration calls, and workflow transitions. Logs shall include: trace ID, span ID, user ID, model ID, duration, and outcome.
- **REQ-NFR-OBS-002:** The system shall expose **Prometheus-compatible metrics** for all key operational indicators (request rate, error rate, latency P50/P95/P99, queue depth, cache hit/miss, integration adapter health).
- **REQ-NFR-OBS-003:** The system shall implement **distributed tracing** (OpenTelemetry) across API, worker, and integration tiers, exportable to Jaeger, AWS X-Ray, or Datadog APM.
- **REQ-NFR-OBS-004:** An **operational dashboard** (Grafana or equivalent) shall be provided out-of-box covering: API health, DB performance, queue depths, integration adapter status, and cache metrics.
- **REQ-NFR-OBS-005:** All background job executions shall produce a **job execution record** with status, duration, items processed, and error details, queryable via API.
- **REQ-NFR-OBS-006:** The system shall emit **structured audit events** to a SIEM-compatible stream (CloudWatch Logs, Splunk HEC, or Elastic) for security monitoring.

---

### 1.5 Maintainability & Operability NFRs

- **REQ-NFR-MNT-001:** The system shall support **zero-downtime deployments** via blue/green or rolling deployment strategies, with automated rollback on health check failure.
- **REQ-NFR-MNT-002:** All configuration parameters (thresholds, SLAs, notification templates, workflow rules) shall be manageable via an **Admin UI or API** without code changes or redeployment.
- **REQ-NFR-MNT-003:** Integration adapter configurations (credentials, endpoints, project mappings) shall be updatable at runtime via the Admin UI, with changes taking effect within 60 seconds.
- **REQ-NFR-MNT-004:** The system shall support a **feature flag framework** enabling gradual rollout and instant kill-switch of new features without redeployment.
- **REQ-NFR-MNT-005:** Database schema migrations shall be backward-compatible (expand-and-contract pattern) ensuring the prior application version can run against a migrated schema.
- **REQ-NFR-MNT-006:** All infrastructure shall be defined as **Infrastructure as Code** (Terraform or AWS CDK), version-controlled, and deployable via CI/CD pipeline.
- **REQ-NFR-MNT-007:** A **data archival job** shall automatically move completed project records older than a configurable age to a cheaper storage tier, with the ability to restore on-demand.

---

### 1.6 Usability NFRs

- **REQ-NFR-USA-001:** First-time users shall be able to complete a model project creation (Stage 1 Inception) without external documentation, guided by in-app tooltips and contextual help.
- **REQ-NFR-USA-002:** All destructive or irreversible actions (stage rollback, retirement, version deprecation) shall require explicit confirmation dialogs with consequence description.
- **REQ-NFR-USA-003:** The system shall provide **inline validation** on all form inputs, surfacing errors before submission rather than on server response.
- **REQ-NFR-USA-004:** Loading states, processing indicators, and async operation status shall be surfaced at all times — no silent waits.
- **REQ-NFR-USA-005:** All data tables shall support **export to CSV** as a standard action.
- **REQ-NFR-USA-006:** The system shall comply with **WCAG 2.1 Level AA** accessibility standards.
- **REQ-NFR-USA-007:** The system shall support **keyboard navigation** for all primary workflows.

---

### 1.7 Portability & Interoperability NFRs

- **REQ-NFR-PRT-001:** The system shall be deployable on AWS, Azure, and GCP cloud environments using containerized workloads (Docker/Kubernetes), with cloud-specific managed service adapters (RDS vs. Azure DB, S3 vs. Azure Blob, etc.).
- **REQ-NFR-PRT-002:** The system shall export all model registry data in an open, documented JSON schema to prevent vendor lock-in.
- **REQ-NFR-PRT-003:** All public APIs shall conform to OpenAPI 3.0 specification, published and versioned in a developer portal.
- **REQ-NFR-PRT-004:** The system shall support **SCIM 2.0** for automated user provisioning/deprovisioning from enterprise identity providers.

---

### 1.8 Data Retention & Privacy NFRs

| Data Category | Active Retention | Archive Retention | Delete Policy |
|---------------|-----------------|-------------------|---------------|
| Model project records | Indefinite (while active) | 7 years post-retirement | Never auto-delete |
| Audit logs | 2 years (hot) | 10 years (cold) | Immutable; legal hold override |
| Monitoring metrics (raw) | 90 days (hot) | 2 years (cold) | Auto-archive after 90 days |
| Monitoring metrics (aggregated) | 2 years (hot) | 7 years (cold) | — |
| Uploaded artifacts (metadata) | Indefinite | — | Follows model record |
| Uploaded artifacts (files) | Per retention policy | 7 years (Tier 1–2) | Admin-controlled |
| User activity logs | 1 year (hot) | 3 years (cold) | GDPR deletion on user removal |
| Notification logs | 90 days | — | Auto-purge |

- **REQ-NFR-PRV-001:** The system shall support **data subject access requests (DSAR)** — ability to export all personal data associated with a user ID.
- **REQ-NFR-PRV-002:** The system shall support **right to erasure** for user personal data (name, email, activity) while preserving anonymized audit trail integrity (user ID replaced with `ANONYMIZED_USER`).
- **REQ-NFR-PRV-003:** PII in uploaded artifacts shall not be extracted or indexed by the platform — the system stores artifact metadata only; PII handling obligations remain with the document owner.

---

## 2. Role Matrix & Permission Design

### 2.1 Role Hierarchy

```
┌─────────────────────────────────────────────────────┐
│                      Admin                          │  ← Platform-level superuser
├─────────────────────────────────────────────────────┤
│  Risk Officer  │  Compliance Manager  │  Auditor    │  ← Oversight roles (cross-project)
├─────────────────────────────────────────────────────┤
│   Model Owner  │  Model Validator     │             │  ← Project-level governance
├─────────────────────────────────────────────────────┤
│  Data Scientist  │  ML Engineer  │  MLOps Engineer  │  ← Project-level delivery
├─────────────────────────────────────────────────────┤
│                 Read-Only Viewer                     │  ← Baseline access
└─────────────────────────────────────────────────────┘
```

Roles are **additive** — a user may hold multiple roles. Permissions are the union of all assigned roles. Project-level roles are scoped to specific model projects; platform-level roles apply globally.

---

### 2.2 Role Definitions

#### 2.2.1 Admin
**Scope:** Platform-wide  
**Description:** Full platform control. Manages users, roles, integrations, workflow configuration, and system settings. Not intended for day-to-day model work.

#### 2.2.2 Risk Officer
**Scope:** Platform-wide (all projects)  
**Description:** Reviews and approves risk classifications, model risk documentation, and Tier 1–2 validation outcomes. Can trigger emergency retirement. Can override governance flags. Does not develop or validate models.

#### 2.2.3 Compliance Manager
**Scope:** Platform-wide (read) + approval on compliance gate  
**Description:** Ensures regulatory documentation completeness. Approves compliance checkpoints for regulated models. Generates and reviews compliance reports. Cannot modify model records.

#### 2.2.4 Auditor
**Scope:** Platform-wide read-only  
**Description:** Full read access to all project records, audit logs, validation reports, and monitoring data. Export access to all reports. No write capabilities. Activity is itself logged.

#### 2.2.5 Model Owner
**Scope:** Project-level (assigned per project)  
**Description:** Business accountable owner for the model project. Approves Inception, Development gate, and Production Promotion. Initiates and approves Retirement. Does not perform technical development or validation.

#### 2.2.6 Model Validator
**Scope:** Project-level (assigned per validation cycle)  
**Description:** Performs independent validation. Can access all development artifacts and candidate model metadata for review. Cannot modify Development stage records. Raises findings, records test results, approves/rejects Validation gate. **Enforced restriction:** cannot hold Data Scientist or ML Engineer role on the same project.

#### 2.2.7 Data Scientist
**Scope:** Project-level  
**Description:** Develops and trains models. Manages Development stage artifacts. Configures MLflow/platform integrations at the project level. Selects candidate model. Submits Development stage for gate review. Cannot approve their own gate.

#### 2.2.8 ML Engineer
**Scope:** Project-level  
**Description:** Builds deployment pipelines, manages Implementation stage. Configures deployment targets. Approves Production Promotion (jointly with Model Owner). Manages deployment records. Responds to and resolves deployment-related monitoring incidents.

#### 2.2.9 MLOps Engineer
**Scope:** Project-level + platform integration management  
**Description:** Manages platform-wide integration configurations (shared SageMaker accounts, Databricks workspaces). Configures monitoring rules and integration adapters at the project level. Manages monitoring configurations and alert rules. Does not approve lifecycle gates.

#### 2.2.10 Read-Only Viewer
**Scope:** Project-level (assigned per project)  
**Description:** Can view all project records, artifacts metadata, monitoring dashboards, and audit logs for assigned projects. Cannot perform any write operations. Useful for executive stakeholders, external reviewers, or downstream consumers who need visibility.

---

### 2.3 Permissions Matrix

Legend: ✅ Full access | 🔶 Conditional / limited | ❌ No access | 👁 Read-only

#### 2.3.1 Project Management

| Permission | Admin | Risk Officer | Compliance Mgr | Auditor | Model Owner | Data Scientist | ML Engineer | MLOps Engineer | Validator | Viewer |
|------------|-------|-------------|----------------|---------|-------------|----------------|-------------|----------------|-----------|--------|
| Create Model Project | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| View Project (assigned) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| View All Projects | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Edit Project Metadata | ✅ | ❌ | ❌ | ❌ | ✅ | 🔶 Dev stage only | ❌ | ❌ | ❌ | ❌ |
| Assign Roles to Project | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Archive Project | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Delete Project (Admin only) | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

#### 2.3.2 Stage 1 — Inception

| Permission | Admin | Risk Officer | Compliance Mgr | Auditor | Model Owner | Data Scientist | ML Engineer | MLOps Engineer | Validator | Viewer |
|------------|-------|-------------|----------------|---------|-------------|----------------|-------------|----------------|-----------|--------|
| Complete Inception Form | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Upload Inception Artifacts | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Assign Risk Tier | ✅ | ✅ | ❌ | ❌ | 🔶 Tier 3-4 | ❌ | ❌ | ❌ | ❌ | ❌ |
| Approve Inception Gate (Tier 3–4) | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Approve Inception Gate (Tier 1–2) | ✅ | ✅ | ❌ | ❌ | ✅ (joint) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Reject Inception Gate | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| View Inception Records | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 👁 | 👁 | 👁 | 👁 |

#### 2.3.3 Stage 2 — Development

| Permission | Admin | Risk Officer | Compliance Mgr | Auditor | Model Owner | Data Scientist | ML Engineer | MLOps Engineer | Validator | Viewer |
|------------|-------|-------------|----------------|---------|-------------|----------------|-------------|----------------|-----------|--------|
| Configure Dev Platform Integration | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Upload Dev Artifacts | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Select Candidate Model (MLflow run) | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Submit for Dev Gate Review | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Approve Dev Gate | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| View Dev Artifacts | ✅ | 👁 | 👁 | 👁 | ✅ | ✅ | ✅ | ✅ | ✅ | 👁 |
| View MLflow Experiments (within project) | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | 👁 |

#### 2.3.4 Stage 3 — Validation

| Permission | Admin | Risk Officer | Compliance Mgr | Auditor | Model Owner | Data Scientist | ML Engineer | MLOps Engineer | Validator | Viewer |
|------------|-------|-------------|----------------|---------|-------------|----------------|-------------|----------------|-----------|--------|
| Assign Validators | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Record Test Results | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Raise Finding | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Resolve Finding | ✅ | 🔶 Critical | ❌ | ❌ | ❌ | ✅ (own) | ✅ (own) | ❌ | ✅ (accept) | ❌ |
| Approve Validation Gate (Lead Validator) | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (Lead) | ❌ |
| Countersign Validation (Tier 1) | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| View Validation Report | ✅ | ✅ | ✅ | ✅ | ✅ | 👁 | 👁 | ❌ | ✅ | 👁 |
| Reject Validation (rollback to Dev) | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (Lead) | ❌ |

#### 2.3.5 Stage 4 — Implementation

| Permission | Admin | Risk Officer | Compliance Mgr | Auditor | Model Owner | Data Scientist | ML Engineer | MLOps Engineer | Validator | Viewer |
|------------|-------|-------------|----------------|---------|-------------|----------------|-------------|----------------|-----------|--------|
| Configure Deployment Target | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Trigger Staging Deployment | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Approve Production Promotion Gate | ✅ | ❌ | ❌ | ❌ | ✅ (joint) | ❌ | ✅ (joint) | ❌ | ❌ | ❌ |
| Trigger Production Deployment | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ |
| View Deployment Records | ✅ | ✅ | ✅ | ✅ | ✅ | 👁 | ✅ | ✅ | 👁 | 👁 |
| Emergency Rollback (deployed version) | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Override Deployment Block | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

#### 2.3.6 Stage 5 — Monitoring

| Permission | Admin | Risk Officer | Compliance Mgr | Auditor | Model Owner | Data Scientist | ML Engineer | MLOps Engineer | Validator | Viewer |
|------------|-------|-------------|----------------|---------|-------------|----------------|-------------|----------------|-----------|--------|
| Configure Monitor Rules | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ |
| View Monitoring Dashboard | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 👁 | 👁 |
| Acknowledge Alert | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Create Incident Record | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Close Incident Record | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Upload Ground Truth Data | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Modify Alert Thresholds | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ |

#### 2.3.7 Versioning & Retirement

| Permission | Admin | Risk Officer | Compliance Mgr | Auditor | Model Owner | Data Scientist | ML Engineer | MLOps Engineer | Validator | Viewer |
|------------|-------|-------------|----------------|---------|-------------|----------------|-------------|----------------|-----------|--------|
| Create New Model Version | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Supersede Version (manual) | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Initiate Retirement | ✅ | ✅ (emergency) | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Approve Retirement Decommission | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Emergency Retirement | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| View Retirement Report | ✅ | ✅ | ✅ | ✅ | ✅ | 👁 | 👁 | 👁 | 👁 | 👁 |

#### 2.3.8 Platform Administration

| Permission | Admin | Risk Officer | Compliance Mgr | Auditor | All Others |
|------------|-------|-------------|----------------|---------|------------|
| Manage Users | ✅ | ❌ | ❌ | ❌ | ❌ |
| Manage Roles & Assignments | ✅ | ❌ | ❌ | ❌ | ❌ |
| Configure Global Integrations | ✅ | ❌ | ❌ | ❌ | ❌ |
| Configure Workflow Rules | ✅ | 🔶 Risk rules | ❌ | ❌ | ❌ |
| Export Audit Logs | ✅ | 👁 | 👁 | ✅ | ❌ |
| Generate Compliance Reports | ✅ | ✅ | ✅ | ✅ | ❌ |
| View System Health Dashboard | ✅ | ❌ | ❌ | ❌ | ❌ |
| Manage Data Retention Policies | ✅ | ❌ | 🔶 | ❌ | ❌ |

---

### 2.4 Special Role Constraints

- **REQ-ROLE-001:** The **Conflict of Interest (COI) Rule** — a user assigned as Data Scientist or ML Engineer on a model project during the Development stage shall be automatically blocked from serving as Model Validator for the same project in the same validation cycle. The system shall enforce this at assignment time and at test-result submission time.
- **REQ-ROLE-002:** **Separation of Duties** — no single user may approve both the Development gate and the Validation gate for the same model version.
- **REQ-ROLE-003:** **Self-Approval Prohibition** — a user who submits a stage for review cannot be the sole approver of that review. If no other authorized approver exists, the system shall flag an escalation to Admin.
- **REQ-ROLE-004:** **Delegation Audit** — all approvals made under delegation shall be attributed to both the delegate and the delegating approver in the audit log.
- **REQ-ROLE-005:** **Temporary Role Elevation** — a Risk Officer may grant time-limited (max 48 hours) elevated access to specific project records for incident investigation, with full audit trail.
- **REQ-ROLE-006:** **Role Expiry** — project-scoped roles may be assigned with an expiry date (e.g., external validator engaged for 90 days). Upon expiry, access is automatically revoked and the user notified.

---

## 3. Third-Party & Vendor Model Tracking

### 3.1 Overview

Not all models used by an organization are developed internally. Many business tools embed AI/ML capabilities provided by the vendor — for example:

- **Tableau** embedding Tableau Einstein Analytics models for anomaly detection or forecasting.
- **Salesforce Einstein** providing lead scoring or churn prediction models.
- **Microsoft Copilot / Power BI** using Microsoft-hosted models for natural language querying.
- **ServiceNow Predictive Intelligence** for ticket classification.
- **Workday Adaptive Planning** models for workforce forecasting.
- **Custom vendor-supplied models** delivered as black-box endpoints, libraries, or embedded tool features.

These models are outside the organization's direct control but still represent **model risk exposure** — they influence decisions, process organizational data, and may be subject to regulatory model inventory requirements (e.g., SR 11-7 requires inventorying all models in use, including vendor models).

The MOA shall support a **Vendor/Third-Party Model Tracking** capability that provides inventory and governance visibility without requiring the full internal lifecycle workflow.

---

### 3.2 Third-Party Model Taxonomy

| Category | Description | Examples |
|----------|-------------|----------|
| **Embedded Vendor Models** | AI capabilities built into a licensed software product | Tableau Einstein, Salesforce Einstein, Power BI AI Insights |
| **API-Delivered Models** | Models consumed via external API as a service | OpenAI API, AWS Comprehend, Google Cloud Vision |
| **Vendor-Supplied Custom Models** | Models built by a vendor specifically for the organization | Consulting firm-developed scoring models, vendor-trained classifiers |
| **Open-Source Pre-Trained Models** | Publicly available pre-trained models used without retraining | Hugging Face model hub models used directly in production |
| **Regulatory/Third-Party Scores** | Credit bureau scores, risk scores from data providers | FICO score, LexisNexis scores |

---

### 3.3 Vendor Model Registration

- **REQ-VND-001:** The system shall provide a **Vendor Model Registration** workflow distinct from the internal lifecycle workflow. The registration form shall capture:
  - **Vendor/Provider Name** — organization supplying the model.
  - **Product/Tool Name** — software product in which the model is embedded (e.g., "Tableau 2024.1").
  - **Model Capability Description** — what the model does in the context of the tool (e.g., "Anomaly detection on sales time-series data").
  - **Model Type** — classification, regression, forecasting, NLP, CV, GenAI, etc.
  - **Data Inputs** — what organizational data is processed by the model.
  - **Output/Decision** — what output or decision the model influences.
  - **Business Use Case** — how the output is used within the organization.
  - **Usage Scope** — which teams, business units, or processes consume the model.
  - **Hosting Location** — vendor-hosted (cloud), on-premise, embedded in software.
  - **Data Residency** — where organizational data is sent (relevant for privacy/compliance).
  - **Contractual Reference** — vendor contract or license agreement reference.
  - **Risk Classification** — inherent risk tier (assigned by Risk Officer; defaults to Tier 3 unless escalated).
  - **Regulatory Applicability** — applicable regulations based on use case.

- **REQ-VND-002:** Vendor model records shall be assigned a MOA Model ID in the same global registry, with a `VENDOR` model type flag distinguishing them from internal models.
- **REQ-VND-003:** Vendor model records shall appear in the **Model Inventory Report** alongside internal models, with a clear vendor flag and abbreviated lifecycle status.

---

### 3.4 Vendor Model Lifecycle States

Vendor models do not follow the full 7-stage lifecycle. They have a simplified state model:

```
[REGISTERED] → [ACTIVE_IN_USE] → [UNDER_REVIEW] → [ACTIVE_IN_USE]
                                                 → [RESTRICTED]
                                                 → [DECOMMISSIONED]
```

| State | Description |
|-------|-------------|
| `REGISTERED` | Vendor model inventoried; not yet confirmed in active use |
| `ACTIVE_IN_USE` | Confirmed in production use by the organization |
| `UNDER_REVIEW` | Triggered by risk event, vendor update, or periodic review cycle |
| `RESTRICTED` | Use permitted with documented restrictions/compensating controls |
| `DECOMMISSIONED` | Tool retired or vendor model replaced; no longer in use |

---

### 3.5 Vendor Model Governance Activities

Although the full validation and monitoring lifecycle is not required for vendor models, the system shall support the following lightweight governance activities:

- **REQ-VND-010:** **Vendor Due Diligence Tracking** — ability to attach and track vendor-provided documentation: model cards, technical specifications, audit reports (SOC 2, ISO 27001), bias assessments, and accuracy benchmarks provided by the vendor.
- **REQ-VND-011:** **Periodic Review Scheduling** — the system shall support configurable periodic review schedules (annually by default for Tier 3 vendor models; semi-annually for Tier 1–2). At review due date, the system shall create a review task assigned to the Model Owner and Risk Officer.
- **REQ-VND-012:** **Vendor Model Change Tracking** — the system shall allow logging of vendor-initiated model updates (version changes, methodology updates) that are communicated via release notes or vendor notifications, with impact assessment notes.
- **REQ-VND-013:** **Risk Assessment Attachment** — for Tier 1–2 vendor models, a structured risk assessment form shall be required, capturing: known model limitations, compensating controls in place, exit/replacement plan, and escalation triggers.
- **REQ-VND-014:** **Usage Volume Tracking** — the system shall support manual or API-based recording of usage metrics (number of predictions/decisions made per period) for inventory completeness.
- **REQ-VND-015:** **Incident Tracking** — vendor model incidents (e.g., vendor announces model defect, unexpected outputs observed) shall be loggable against the vendor model record with the same incident workflow as internal models.
- **REQ-VND-016:** **Comparative Benchmarking Flag** — for critical vendor models, the system shall support recording of independent shadow tests performed by the organization to validate vendor-stated performance, without requiring a full validation workflow.
- **REQ-VND-017:** **Decommission Workflow** — when a vendor model is decommissioned (tool retired, contract ended), a lightweight decommission workflow shall capture: reason, date, successor solution, and affected use cases.

---

### 3.6 Vendor Model vs. Internal Model — Feature Comparison

| Capability | Internal Model | Vendor Model |
|------------|---------------|--------------|
| Model Registry & Inventory | ✅ Full | ✅ Simplified |
| 7-Stage Lifecycle Workflow | ✅ Full | ❌ Not applicable |
| Simplified State Tracking | ✅ | ✅ |
| Validation Workflow | ✅ Full | 🔶 Optional shadow test only |
| MLflow / Platform Integration | ✅ | ❌ |
| Deployment Management | ✅ | ❌ (vendor-managed) |
| Monitoring Integration | ✅ Full | 🔶 Incident log + manual metrics only |
| Periodic Review Scheduling | ✅ | ✅ |
| Risk Assessment | ✅ Required per tier | ✅ Required per tier |
| Audit Trail | ✅ Full | ✅ Full |
| Compliance Reporting | ✅ | ✅ |
| Vendor Due Diligence Docs | ❌ | ✅ |
| Regulatory Inventory Inclusion | ✅ | ✅ |

---

## 4. GenAI, LLM & SLM Requirements

### 4.1 Overview

Large Language Models (LLMs), Small Language Models (SLMs), and Generative AI systems present governance, validation, and monitoring challenges fundamentally different from traditional ML models. MOA shall support a **GenAI Model Lifecycle** that adapts the standard 7-stage workflow with GenAI-specific requirements at every stage, while sharing the same registry, versioning, and audit infrastructure.

GenAI model types covered:

| Type | Description | Examples |
|------|-------------|----------|
| **Foundation Model (External API)** | Third-party LLM consumed via API | GPT-4o via OpenAI API, Claude via Anthropic API, Gemini via Google API |
| **Fine-Tuned Model** | Foundation model fine-tuned on organizational data | Fine-tuned Llama 3, domain-adapted Mistral |
| **RAG System** | Retrieval-Augmented Generation pipeline using a foundation model + vector store | Internal knowledge base QA system |
| **Agentic System** | Multi-step orchestrated LLM workflow with tool use | AI agents with function calling, LangGraph pipelines |
| **SLM / Edge Model** | Small language model deployed on-device or in latency-sensitive environments | Phi-3, Gemma 2B for on-premise use |
| **Multi-Modal Model** | Models handling image, audio, or video inputs in addition to text | GPT-4V, Gemini 1.5 Pro |
| **Embedding Model** | Models producing vector representations for semantic search or similarity | text-embedding-3, Titan Embeddings |

---

### 4.2 GenAI-Specific Inception Requirements

In addition to standard Inception artifacts, GenAI projects shall capture:

- **REQ-GEN-INC-001:** **GenAI Use Case Classification** — the system shall require classification of the GenAI use case along two dimensions:
  - *Autonomy Level*: Assistive (human reviews all outputs) | Augmentative (human reviews flagged outputs) | Autonomous (model acts without human review).
  - *Output Type*: Informational | Decision-Support | Decision-Making | Content Generation | Code Generation | Process Automation.
- **REQ-GEN-INC-002:** **Foundation Model Selection Rationale** — if using an external foundation model (API-based), the Inception record shall capture: provider, model name/version, licensing terms, data processing agreement (DPA) reference, and data residency confirmation.
- **REQ-GEN-INC-003:** **Human-in-the-Loop (HITL) Design** — required declaration of where human oversight is applied in the GenAI workflow, and what escalation triggers exist for model-generated content.
- **REQ-GEN-INC-004:** **Prohibited Use Declaration** — explicit documentation of use cases the GenAI system is NOT permitted to perform (e.g., "this system shall not make credit decisions autonomously").
- **REQ-GEN-INC-005:** **AI Risk Classification Override** — Autonomous + Decision-Making GenAI systems shall be automatically escalated to Risk Tier 1 regardless of other risk factors, requiring Risk Officer review at Inception.

---

### 4.3 GenAI-Specific Development Requirements

- **REQ-GEN-DEV-001:** **Prompt Engineering Registry** — the system shall provide a structured **Prompt Registry** within the Development stage, allowing Data Scientists to version-control system prompts, few-shot examples, and prompt templates. Each prompt version shall be stored immutably with: version ID, content, author, creation date, and associated model version.
- **REQ-GEN-DEV-002:** **Prompt Versioning** — changes to production system prompts shall trigger a **Patch Version** increment (x.y.Z) in the model versioning system, and shall require a re-validation of affected test cases if the prompt change impacts safety or decision logic.
- **REQ-GEN-DEV-003:** **RAG Configuration Tracking** — for RAG systems, the Development stage shall capture: vector store type (Pinecone, pgvector, OpenSearch, FAISS, ChromaDB), embedding model reference, chunking strategy, retrieval configuration (top-K, similarity threshold), and knowledge base dataset reference (with version hash).
- **REQ-GEN-DEV-004:** **Fine-Tuning Lineage** — for fine-tuned models, the Development stage shall capture: base foundation model ID and version, fine-tuning dataset reference (with PII assessment), fine-tuning methodology (LoRA, QLoRA, full fine-tune), and PEFT configuration.
- **REQ-GEN-DEV-005:** **LLM Experiment Tracking** — the system shall support MLflow integration for LLM experiment tracking via MLflow's LLM evaluation APIs (`mlflow.evaluate()`) and the MLflow Prompt Engineering UI, ingesting evaluation metrics alongside standard experiment runs.
- **REQ-GEN-DEV-006:** **Agent Workflow Definition** — for agentic systems, the Development stage shall require documentation of: agent architecture (single agent vs. multi-agent), tools/functions available to the agent, memory/context management approach, and maximum execution depth/loop limits.

---

### 4.4 GenAI-Specific Validation Requirements

GenAI validation goes beyond quantitative performance metrics and requires structured evaluation of safety, reliability, and responsible AI properties.

#### 4.4.1 Mandatory GenAI Validation Test Categories

| Test Category | Description | Required For |
|---------------|-------------|--------------|
| **Functional Accuracy** | Task-specific accuracy on curated evaluation dataset (QA pairs, summarization ROUGE, code correctness, etc.) | All GenAI |
| **Hallucination Rate Assessment** | Factual accuracy evaluation; % of outputs containing fabricated or unsupported claims | All GenAI (informational/decision) |
| **Groundedness Testing (RAG)** | % of RAG responses fully grounded in retrieved context vs. model fabrication | RAG systems |
| **Toxicity & Safety Testing** | Automated + human evaluation for toxic, harmful, or inappropriate outputs | All GenAI |
| **Prompt Injection Resistance** | Testing for susceptibility to adversarial prompt injections that override system instructions | All GenAI with external input |
| **Jailbreak Resistance** | Testing resistance to attempts to bypass safety guardrails | All GenAI (Autonomous Tier) |
| **Bias & Fairness Evaluation** | Differential performance across demographic groups; stereotype amplification testing | Decision-Support / Decision-Making |
| **PII Leakage Testing** | Evaluation for inadvertent disclosure of PII from training data or RAG knowledge base | All GenAI processing PII |
| **Consistency & Reproducibility** | Variance in outputs across repeated identical inputs; temperature sensitivity | Decision-Support / Decision-Making |
| **Context Length Degradation** | Performance consistency across short vs. long context inputs | All LLM |
| **Latency & Cost Profiling** | Token usage per query, latency distribution, cost per 1K queries | All GenAI (pre-production) |
| **Agentic Safety Testing** | Testing for unintended tool use, runaway loops, unintended data exfiltration | Agentic Systems |
| **Regulatory Compliance (AI-specific)** | EU AI Act risk classification compliance, NIST AI RMF alignment | All GenAI (Tier 1–2) |

- **REQ-GEN-VAL-001:** The system shall maintain a **GenAI Evaluation Dataset Registry** allowing validators to register curated evaluation datasets (golden QA sets, adversarial prompt sets, bias evaluation sets) with version control, separate from training data.
- **REQ-GEN-VAL-002:** The system shall support integration with **LLM evaluation frameworks** to auto-ingest evaluation results: MLflow `mlflow.evaluate()`, RAGAS (for RAG evaluation), DeepEval, Giskard, and PromptFlow evaluation.
- **REQ-GEN-VAL-003:** The system shall support recording of **Human Evaluation (HITL Validation)** results — structured human evaluation rubrics (e.g., correctness, helpfulness, safety, tone) completed by the validation team, with inter-rater reliability tracking.
- **REQ-GEN-VAL-004:** Hallucination rate thresholds shall be configurable by use case type — a lower threshold is enforced for Decision-Making use cases than for Assistive use cases.
- **REQ-GEN-VAL-005:** Any GenAI system with an Autonomy Level of `Autonomous` shall require a mandatory **Red Team Exercise** (adversarial testing by an independent team) as part of the validation gate, with red team findings recorded in the Finding tracker.

---

### 4.5 GenAI-Specific Implementation Requirements

- **REQ-GEN-IMP-001:** **Guardrail Configuration Tracking** — the system shall record the guardrail configuration applied at deployment: content filters, PII redaction rules, topic blocklists, output length limits, and provider-specific safety settings (e.g., AWS Bedrock Guardrails configuration ID, Azure Content Safety policy name).
- **REQ-GEN-IMP-002:** **Rate Limit & Quota Tracking** — for API-based foundation models, the system shall allow recording of configured rate limits, token quotas, and fallback behavior (e.g., fallback to alternative model on rate limit).
- **REQ-GEN-IMP-003:** **Model Serving Configuration** — for self-hosted LLMs, the system shall capture: inference framework (vLLM, TGI, TensorRT-LLM), quantization level, hardware configuration (GPU type, count), and serving endpoint configuration.
- **REQ-GEN-IMP-004:** **Prompt Version Deployment Lock** — the specific prompt version active at deployment shall be locked in the deployment record. A prompt version change in production shall trigger a notification and require explicit approval per the Prompt Versioning policy (REQ-GEN-DEV-002).
- **REQ-GEN-IMP-005:** **A/B Testing Support for LLMs** — the system shall support recording and tracking of LLM A/B test configurations (e.g., model A vs. model B, prompt variant A vs. B) with traffic split percentages and evaluation metric targets, linked to the Implementation stage.

---

### 4.6 GenAI-Specific Monitoring Requirements

LLM/GenAI monitoring requires qualitative and behavioral monitoring in addition to standard quantitative metric monitoring.

#### 4.6.1 LLM-Specific Monitor Types

| Monitor Type | Description | Integration Options |
|--------------|-------------|---------------------|
| **Hallucination Rate Monitor** | Ongoing sampling + automated evaluation of factual accuracy of outputs | LangSmith, Langfuse, Phoenix (Arize), Custom |
| **Toxicity Monitor** | Automated safety scoring of production outputs (sampled) | AWS Bedrock Guardrails, Azure Content Safety, Perspective API |
| **Groundedness Monitor (RAG)** | Ongoing evaluation of retrieval relevance and response groundedness | RAGAS metrics via Langfuse/Phoenix |
| **PII Detection Monitor** | Detection of PII in model inputs or outputs in production | AWS Comprehend, Azure AI Language, Presidio |
| **Token Usage & Cost Monitor** | Track token consumption, cost per request, and quota burn rate | Provider APIs (OpenAI Usage API, Bedrock CloudWatch) |
| **Latency Monitor** | P50/P95/P99 inference latency, time-to-first-token | Standard infra monitoring |
| **User Feedback Monitor** | Collection and tracking of thumbs up/down, explicit ratings from end users | Custom feedback capture + MOA ingest |
| **Prompt Injection Attempt Monitor** | Detection of adversarial prompt patterns in production inputs | Custom classifiers, Rebuff, Lakera Guard |
| **Knowledge Base Staleness Monitor** | RAG knowledge base last-updated date; alert when stale beyond threshold | MOA-managed metadata |
| **Model Drift Monitor (LLM)** | Behavioral drift detection — shift in output length, topic distribution, sentiment profile | Phoenix/Arize embedding drift, custom |
| **Refusal Rate Monitor** | Track rate at which the model refuses or declines to respond — anomalous spikes may indicate misconfiguration or adversarial activity | LangSmith / Custom |

- **REQ-GEN-MON-001:** The system shall integrate with **LLM observability platforms** — LangSmith, Langfuse, Arize Phoenix, and Helicone — via their respective APIs to ingest trace-level LLM call data, aggregate into monitoring metrics, and surface in the MOA monitoring dashboard.
- **REQ-GEN-MON-002:** The system shall support **production sampling** — configurable sampling rate (default 5%) of production LLM inputs and outputs for offline evaluation, stored securely and subject to PII policies.
- **REQ-GEN-MON-003:** Sampled production outputs shall be evaluatable via the **Human Review Queue** — a lightweight UI allowing assigned reviewers to score sampled outputs against quality rubrics, with results feeding back into the monitoring dashboard.
- **REQ-GEN-MON-004:** The system shall support **knowledge base freshness monitoring** for RAG systems — alerting when the indexed knowledge base has not been updated beyond a configurable staleness threshold.
- **REQ-GEN-MON-005:** Token cost monitoring shall include **budget alerting** — configurable monthly token spend budgets with WARNING (80% consumed) and CRITICAL (95% consumed) alerts.
- **REQ-GEN-MON-006:** The system shall support recording of **user feedback signals** (explicit ratings, thumbs up/down, correction submissions) from consuming applications via a feedback ingest API, aggregated into quality trend metrics.

---

### 4.7 GenAI Versioning Considerations

- **REQ-GEN-VER-001:** For API-based foundation models, a **Provider Model Version Change** (e.g., OpenAI deprecates `gpt-4-0613` and migrates to `gpt-4-0125`) shall be treated as a mandatory version review event — the system shall support recording the provider's change notice, an impact assessment, and (for Tier 1–2) a re-validation of affected test cases.
- **REQ-GEN-VER-002:** **Prompt version** and **RAG knowledge base version** shall both be tracked independently as sub-components of the model version record. A production change to either shall be logged as a version event.
- **REQ-GEN-VER-003:** The system shall track **model deprecation notices** from foundation model providers — allowing teams to register provider deprecation announcements and linking them to a required migration timeline and action plan.
- **REQ-GEN-VER-004:** For fine-tuned models, a change in the underlying base model version shall trigger a **Major Version** increment and require a new Development → Validation cycle.

---

### 4.8 GenAI Retirement Considerations

- **REQ-GEN-RET-001:** When an externally hosted foundation model version is deprecated by the provider and the organization has been using it, the retirement workflow shall be automatically suggested if a deployment record references the deprecated model version.
- **REQ-GEN-RET-002:** Retirement of a RAG system shall include a **knowledge base decommission checklist** — ensuring the vector store and associated document repositories are cleaned up or transferred per data retention policy.
- **REQ-GEN-RET-003:** For agentic systems, retirement documentation shall include an **agent capability impact assessment** — which automated workflows or business processes will be impacted.

---

### 4.9 GenAI Responsible AI & Regulatory Compliance

- **REQ-GEN-RAI-001:** The system shall include a **Responsible AI (RAI) Assessment** module within the Validation stage for GenAI projects, structured around the **NIST AI Risk Management Framework (AI RMF)** functions: GOVERN, MAP, MEASURE, MANAGE.
- **REQ-GEN-RAI-002:** For EU-based deployments or EU-regulated use cases, the system shall support collection of **EU AI Act** classification evidence: prohibited use check, high-risk system classification, conformity assessment documentation, and transparency obligations log.
- **REQ-GEN-RAI-003:** The system shall generate a **GenAI Model Card** (extended from the standard draft model card in Development) covering: model purpose, training data provenance, known limitations, evaluation results (including safety metrics), intended and prohibited uses, and human oversight design. This shall be a required artifact for all GenAI Validation stage completions.
- **REQ-GEN-RAI-004:** For Decision-Making GenAI systems, the system shall require documentation of **explainability approach** — how a human can understand why the system produced a specific output (chain-of-thought logging, attention visualization, or structured rationale capture).
- **REQ-GEN-RAI-005:** The system shall support **AI Incident Registry** integration — critical GenAI incidents (harmful output, safety failure, bias event) shall be loggable to an organization-wide AI Incident Registry, separate from the per-project incident log, for cross-portfolio risk pattern analysis.

---

### 4.10 GenAI Model Tracking for Third-Party GenAI Tools

Many vendor tools now embed GenAI capabilities. The Vendor Model Tracking framework (Section 3) applies, with these GenAI-specific extensions:

- **REQ-GEN-VND-001:** Vendor GenAI registrations shall additionally capture: underlying foundation model (if disclosed), data sent to vendor for inference (and whether it leaves the organization's cloud boundary), opt-out from vendor model training using organizational data (and contractual confirmation), and content safety policies applied by the vendor.
- **REQ-GEN-VND-002:** For GenAI vendor tools with `Autonomous` or `Decision-Making` capability classifications, a **Vendor GenAI Risk Assessment** (structured questionnaire) shall be mandatory at registration, requiring Risk Officer approval.
- **REQ-GEN-VND-003:** The system shall track **vendor GenAI policy changes** — when a vendor updates its AI safety policies, data use terms, or underlying model, a review task shall be created for the Model Owner and Risk Officer.

---

### 4.11 LLM Evaluation Framework Integrations

| Framework | Integration Type | Metrics Ingested |
|-----------|-----------------|-----------------|
| **MLflow `mlflow.evaluate()`** | API — results auto-ingested to Development / Validation stage | toxicity, perplexity, ROUGE, BLEU, semantic similarity, custom |
| **RAGAS** | API / file output | faithfulness, answer relevance, context recall, context precision, hallucination |
| **DeepEval** | API / CI webhook | G-Eval scores, hallucination, bias, toxicity, answer correctness |
| **Giskard** | API | vulnerability scan results, bias test results, robustness metrics |
| **LangSmith** | API | run traces, feedback scores, evaluation dataset results, latency, token counts |
| **Langfuse** | API | trace data, quality scores, user feedback, cost per trace |
| **Arize Phoenix** | API | embedding drift, retrieval quality, hallucination scores, cluster analysis |
| **Helicone** | API | cost, latency, error rate, user feedback |
| **Prompt Flow (Azure)** | API | evaluation run results, groundedness, coherence, fluency, relevance |

---

*End of Supplement Document*  
*MOA Requirements Supplement v1.0*
