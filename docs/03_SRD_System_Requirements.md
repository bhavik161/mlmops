# System Requirements Document (SRD)
## Model Lifecycle Management (MLM) Platform

**Document ID:** MLM-SRD-001  
**Version:** 1.0 (with CWE addendum supersessions — see below)  
**Status:** Draft  
**Classification:** Internal — Confidential  

**Related Documents:**
- `MLM-FRD-001` — Functional Requirements Document (mlops_model_lifecycle_requirements.md)
- `MLM-NFR-001` — NFR, Roles, Vendor & GenAI Supplement (mlops_requirements_supplement.md)
- `MLM-CWE-001` — Configurable Workflow Engine Addendum *(partially supersedes this document)*

---

> ## ⚠ Partial Supersession & Revision Notice
>
> **Date:** 2024-Q4  
>
> ### CWE Addendum Supersessions
> The following sections are superseded by `MLM-CWE-001`:
>
> | Section | Status | Superseded By |
> |---------|--------|---------------|
> | Section 4.3 — Workflow Engine Component | **Fully superseded** | CWE Section 9 — Runtime Behavior |
> | Section 4.8 — Integration Layer (workflow event routing) | **Partially superseded** | CWE Section 9.5 — Approval Task Generation |
>
> ### Architecture Revisions (Post-MVP Simplification)
> The following architectural decisions have been **revised** based on right-sizing analysis. Affected sections are marked inline:
>
> | Section | Original Decision | Revised Decision | Reason |
> |---------|------------------|-----------------|--------|
> | Section 3.3 — Component Map | OpenSearch for full-text search | **PostgreSQL FTS (tsvector + GIN index)** | MLM's search requirements (thousands of projects per tenant, simple text + faceted filter) are fully served by PostgreSQL FTS. OpenSearch adds $200–400/month infrastructure cost and operational overhead with no benefit at MLM's scale. Add conditionally in V2 if search P95 > 500ms. |
> | Section 4.3 — Workflow Engine | External workflow engine implied | **Custom Python state machine + JSON definitions in PostgreSQL + Celery** | MLM's workflow is a linear state machine with human approval routing and SLA monitoring — not a data pipeline or complex branching process. No external workflow engine (Temporal, Camunda, Step Functions) is warranted. Full specification in Section 4.3 below. |
> | Section 6.1 — Data Store Summary | OpenSearch listed as required | **Removed — replaced by PostgreSQL FTS** | See above. |
>
> All other sections remain authoritative.

---

## Document Control

| Version | Date | Author | Change Description |
|---------|------|--------|-------------------|
| 0.1 | 2024-Q4 | Architecture Team | Initial draft |
| 1.0 | 2024-Q4 | Architecture Team | Baseline release |

### Review & Approval

| Role | Name | Status |
|------|------|--------|
| Enterprise Architect | TBD | Pending |
| Product Owner | TBD | Pending |
| Lead Engineer | TBD | Pending |
| Security Architect | TBD | Pending |
| Risk Officer | TBD | Pending |

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [System Context](#2-system-context)
3. [System Architecture Overview](#3-system-architecture-overview)
4. [Component Architecture](#4-component-architecture)
5. [Deployment Architecture](#5-deployment-architecture)
6. [Data Architecture](#6-data-architecture)
7. [Interface Specifications](#7-interface-specifications)
8. [Security Architecture](#8-security-architecture)
9. [Integration Architecture](#9-integration-architecture)
10. [System Constraints](#10-system-constraints)
11. [System Quality Attributes](#11-system-quality-attributes)
12. [Operational Requirements](#12-operational-requirements)
13. [Acceptance Criteria](#13-acceptance-criteria)
14. [Requirements Traceability Matrix](#14-requirements-traceability-matrix)
15. [Assumptions & Dependencies](#15-assumptions--dependencies)
16. [Risks & Mitigations](#16-risks--mitigations)

---

## 1. Introduction

### 1.1 Purpose

This System Requirements Document (SRD) defines the system-level design, architecture, component decomposition, interface specifications, and technical constraints for the **Model Lifecycle Management (MLM) Platform**. It translates the functional and non-functional requirements defined in the FRD and NFR supplement into a concrete system blueprint that guides engineering design, infrastructure provisioning, and implementation decisions.

This document is the authoritative reference for:
- Engineering teams designing and building MLM components.
- DevOps and cloud infrastructure teams provisioning the deployment environment.
- Integration teams connecting MLM to external ML platforms.
- Security and compliance teams reviewing the system design.
- QA teams defining system-level test strategies.

### 1.2 Scope

The MLM platform encompasses:
- A web-based governance and orchestration application managing the full model lifecycle.
- A Model Registry serving as the authoritative store for all model project and version metadata.
- A Deployment Eligibility Service enforcing deployment governance.
- A Workflow Engine managing stage transitions and approvals.
- An Integration Layer connecting to external ML development, deployment, and monitoring platforms.
- A Monitoring Ingest Pipeline consuming metrics from external monitoring platforms.
- An Audit & Compliance subsystem maintaining tamper-evident records.

**Out of scope:**
- Model training execution (delegated to integrated platforms — SageMaker, Databricks).
- Model inference execution (delegated to deployment targets).
- Data engineering pipelines producing training data.
- Business intelligence or analytics beyond model performance dashboards.

### 1.3 Definitions & Abbreviations

| Term | Definition |
|------|------------|
| MLM | Model Lifecycle Management — the platform described in this document |
| SRD | System Requirements Document |
| FRD | Functional Requirements Document |
| MOA | Model Operational Application — the product name for MLM |
| DES | Deployment Eligibility Service |
| WFE | Workflow Engine |
| API GW | API Gateway |
| IAM | Identity and Access Management |
| RBAC | Role-Based Access Control |
| CDN | Content Delivery Network |
| WAF | Web Application Firewall |
| HA | High Availability |
| DR | Disaster Recovery |
| RTO | Recovery Time Objective |
| RPO | Recovery Point Objective |
| MLflow | Open-source ML experiment tracking platform |
| RAG | Retrieval-Augmented Generation |
| LLM | Large Language Model |
| SLM | Small Language Model |

---

## 2. System Context

### 2.1 System Context Diagram

```
                        ┌─────────────────────────────────────────────────────────┐
                        │                   EXTERNAL USERS                         │
                        │  Data Scientist │ ML Engineer │ Validator │ Model Owner  │
                        │  Risk Officer  │ MLOps Engr │ Auditor  │ Admin        │
                        └────────────────────────┬────────────────────────────────┘
                                                 │ HTTPS (Browser / Mobile)
                        ┌────────────────────────▼────────────────────────────────┐
                        │              IDENTITY PROVIDER (SSO)                    │
                        │        Okta / Azure AD / AWS IAM Identity Center        │
                        └────────────────────────┬────────────────────────────────┘
                                                 │ SAML 2.0 / OIDC
                                                 │
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                          MLM PLATFORM SYSTEM BOUNDARY                                │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                         MLM Application Core                                │    │
│  │  UI │ API Gateway │ Workflow Engine │ Model Registry │ Eligibility Service  │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
└──────────────────────────────────────────────────────────────────────────────────────┘
          │                    │                    │                    │
          │                    │                    │                    │
    ┌─────▼──────┐    ┌────────▼───────┐   ┌───────▼──────┐   ┌───────▼────────┐
    │  ML DEV    │    │  DEPLOYMENT    │   │  MONITORING  │   │  NOTIFICATION  │
    │ PLATFORMS  │    │  PLATFORMS     │   │  PLATFORMS   │   │  CHANNELS      │
    │            │    │                │   │              │   │                │
    │ SageMaker  │    │ SageMaker Ep.  │   │ SageMaker MM │   │ Slack          │
    │ Databricks │    │ Databricks Srv │   │ Evidently AI │   │ MS Teams       │
    │ MLflow OSS │    │ Kubernetes     │   │ Datadog      │   │ PagerDuty      │
    │ Azure ML   │    │ Azure ML EP    │   │ Prometheus   │   │ Email (SMTP)   │
    └────────────┘    └────────────────┘   └──────────────┘   └────────────────┘
          │                    │                    │
    ┌─────▼──────┐    ┌────────▼───────┐   ┌───────▼──────┐
    │  CI/CD     │    │  SECRETS       │   │  LLM OBS.    │
    │  SYSTEMS   │    │  MANAGEMENT    │   │  PLATFORMS   │
    │            │    │                │   │              │
    │ GitHub Act.│    │ AWS Secrets Mgr│   │ LangSmith    │
    │ CodePipeln │    │ HashiCorp Vault │   │ Langfuse     │
    │ Jenkins    │    └────────────────┘   │ Arize Phoenix│
    └────────────┘                         └──────────────┘
```

### 2.2 System Boundary Definition

The MLM platform is responsible for all governance, orchestration, and metadata management activities. It does **not** execute model training, host model inference, or store raw model artifact files directly — these responsibilities remain with external platforms. The MLM platform stores **references** (URIs, checksums) to artifacts hosted on external storage (S3, ADLS, GCS).

### 2.3 External System Interfaces Summary

| External System | Interface Type | Direction | Purpose |
|----------------|---------------|-----------|---------|
| Identity Provider (Okta/AzureAD) | SAML 2.0 / OIDC | Inbound | User authentication & SSO |
| SCIM Provider | SCIM 2.0 REST | Inbound | Automated user provisioning |
| SageMaker Experiments | MLflow REST API + Boto3 | Inbound | Experiment run ingestion |
| SageMaker Model Registry | Boto3 | Outbound | Model package registration |
| SageMaker Endpoints | Boto3 | Bidirectional | Deploy trigger + status callback |
| SageMaker Model Monitor | CloudWatch Metrics + S3 | Inbound | Monitor results ingestion |
| SageMaker Clarify | S3 (report output) | Inbound | Bias report ingestion |
| Databricks Workspace | Databricks REST API + MLflow | Bidirectional | Experiment sync + deployment |
| Databricks Unity Catalog | Databricks REST API | Outbound | Model registration |
| MLflow OSS Tracking Server | MLflow REST API | Inbound | Experiment run ingestion |
| Kubernetes / KServe | Kubernetes API | Bidirectional | Deployment + status |
| Azure ML | Azure ML SDK REST | Bidirectional | Experiment + deployment |
| GitHub Actions / GitLab CI | Webhook (outbound) + REST (inbound) | Bidirectional | Pipeline trigger + event callback |
| Jenkins | REST API | Bidirectional | Pipeline trigger + event callback |
| Evidently AI | REST API + file output | Inbound | Drift + performance reports |
| Datadog | Datadog Metrics API | Inbound | Infrastructure metrics |
| Prometheus | HTTP API | Inbound | Infrastructure metrics |
| LangSmith | REST API | Inbound | LLM trace + evaluation data |
| Langfuse | REST API | Inbound | LLM trace + quality scores |
| Arize Phoenix | REST API | Inbound | Embedding drift + LLM metrics |
| PagerDuty | Events API v2 | Outbound | Critical alert escalation |
| Slack | Incoming Webhooks | Outbound | Notifications |
| Microsoft Teams | Incoming Webhooks | Outbound | Notifications |
| Email (SMTP) | SMTP | Outbound | Notifications |
| AWS Secrets Manager / Vault | REST API | Inbound | Credentials retrieval |
| Artifact Storage (S3/ADLS) | S3 API / ADLS REST | Bidirectional | Artifact file storage + retrieval |
| JIRA (optional) | JIRA REST API | Outbound | Incident ticket creation |
| SIEM (Splunk / CloudWatch) | HTTP Event Collector | Outbound | Audit event streaming |

---

## 3. System Architecture Overview

### 3.1 Architecture Style

The MLM platform follows a **modular monolith with async event processing** architecture pattern:

- The **core application** (API, workflow engine, registry, UI) is a modular monolith deployed as a set of containerized services — this prioritizes operational simplicity and transactional consistency for governance workflows over microservice complexity.
- **Integration adapters** are independently deployable modules following the Adapter/Plugin pattern, allowing new platform integrations without core changes.
- **Async workloads** (metric ingestion, notification delivery, platform sync jobs) are decoupled from the synchronous API via a persistent message queue.
- The **Deployment Eligibility Service (DES)** is deployed as an independent, separately scaled service due to its distinct availability SLA (99.99%) and latency requirements (< 150ms P95).

### 3.2 Architecture Principles

| Principle | Rationale |
|-----------|-----------|
| **Governance immutability** | Audit records, validated model snapshots, and approval records are write-once and must be protected from modification at the storage layer |
| **Fail-safe deployment eligibility** | DES failures must not silently allow ineligible deployments; explicit FAIL_OPEN / FAIL_CLOSED policy is required |
| **Platform-agnostic integration** | Integration adapters are pluggable; the core system has no hard dependencies on any specific ML platform |
| **Defense in depth** | Security controls applied at network, application, data, and audit layers independently |
| **Configuration over code** | Workflow rules, thresholds, notification templates, and retention policies are configuration — not code changes |
| **Separation of concerns** | Governance metadata (MLM) vs. artifact storage (S3/ADLS) vs. execution (SageMaker/Databricks) are cleanly separated |

### 3.3 High-Level Component Map

> **Revision Note:** OpenSearch has been removed from the data layer. Full-text search is handled by PostgreSQL tsvector + GIN indexes (sufficient for MLM's scale). The "Workflow Engine" component is a custom Python state machine — not an external tool. See Section 4.3 for the full specification.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            MLM PLATFORM                                     │
│                                                                             │
│  ┌──────────────┐  ┌──────────────────────────────────────────────────┐    │
│  │   Frontend   │  │                  Backend Core                    │    │
│  │              │  │  ┌────────────┐  ┌──────────┐  ┌─────────────┐  │    │
│  │  React/Vite  │  │  │ API        │  │ Workflow │  │  Model      │  │    │
│  │  SPA         │◄─►  │ Gateway    │  │ State    │  │  Registry   │  │    │
│  │              │  │  │ (FastAPI)  │  │ Machine  │  │  Service    │  │    │
│  └──────────────┘  │  └────────────┘  │ (Python) │  └─────────────┘  │    │
│                    │  ┌────────────┐  └──────────┘  ┌─────────────┐  │    │
│                    │  │ Auth &     │  ┌──────────┐  │  Audit &    │  │    │
│                    │  │ RBAC (OPA) │  │ Notif.   │  │  Compliance │  │    │
│                    │  │            │  │ Service  │  │  Service    │  │    │
│                    │  └────────────┘  └──────────┘  └─────────────┘  │    │
│                    └──────────────────────────────────────────────────┘    │
│                                                                             │
│  ┌──────────────────────┐  ┌──────────────────────────────────────────┐    │
│  │  Deployment          │  │         Integration Layer                │    │
│  │  Eligibility         │  │  ┌──────────┐ ┌──────────┐ ┌─────────┐  │    │
│  │  Service (DES)       │  │  │SageMaker │ │Databricks│ │ MLflow  │  │    │
│  │  [Independent        │  │  │ Adapter  │ │ Adapter  │ │ Adapter │  │    │
│  │   deployment]        │  │  └──────────┘ └──────────┘ └─────────┘  │    │
│  └──────────────────────┘  │  ┌──────────┐ ┌──────────┐ ┌─────────┐  │    │
│                             │  │Monitoring│ │ CI/CD    │ │ GenAI   │  │    │
│  ┌──────────────────────┐  │  │ Adapter  │ │ Adapter  │ │ Adapter │  │    │
│  │  Async Processing    │  │  └──────────┘ └──────────┘ └─────────┘  │    │
│  │  ┌────────────────┐  │  └──────────────────────────────────────────┘    │
│  │  │  SQS Queues    │  │                                                  │
│  │  │  • workflow    │  │  ┌──────────────────────────────────────────┐    │
│  │  │  • monitoring  │  │  │              Data Layer                  │    │
│  │  │  • notify      │  │  │  ┌──────────────────────┐ ┌──────────┐  │    │
│  │  │  • DLQs        │  │  │  │  Aurora PostgreSQL    │ │  Redis   │  │    │
│  │  └────────────────┘  │  │  │                      │ │  Cache   │  │    │
│  │  ┌────────────────┐  │  │  │  • Governance data   │ │          │  │    │
│  │  │ Celery Workers │  │  │  │  • Full-text search  │ │  • DES   │  │    │
│  │  │  • MLflow sync │  │  │  │    (tsvector + GIN)  │ │    cache │  │    │
│  │  │  • Artifact    │  │  │  │  • Workflow state     │ │  • Rate  │  │    │
│  │  │    processing  │  │  │  │  • Audit log          │ │    limit │  │    │
│  │  │  • SLA monitor │  │  │  │  • JSON workflow cfg  │ │  • Sess. │  │    │
│  │  │  • Notif.      │  │  │  └──────────────────────┘ └──────────┘  │    │
│  │  └────────────────┘  │  │  ┌──────────────────────┐               │    │
│  └──────────────────────┘  │  │  S3 (Artifact Store) │               │    │
│                             │  └──────────────────────┘               │    │
│                             └──────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘

Data stores: Aurora PostgreSQL + Redis + S3 + SQS
(OpenSearch removed — PostgreSQL FTS handles all search requirements)
```

---

## 4. Component Architecture

### 4.1 Frontend (SPA)

**Technology:** React 18+ with TypeScript, Vite build tooling  
**Hosting:** AWS CloudFront + S3 (static asset delivery)  
**State Management:** React Query (server state) + Zustand (client state)  
**UI Component Library:** Shadcn/ui + Tailwind CSS  
**Charting:** Recharts (standard metrics) + ECharts (monitoring time-series)  
**Authentication:** Auth0 / Cognito hosted UI (SSO redirect) + JWT stored in httpOnly cookie  

**Key Frontend Modules:**

| Module | Description |
|--------|-------------|
| `app-shell` | Layout, navigation, auth context, global error boundary |
| `model-registry` | Project list, search, filtering, model cards |
| `lifecycle-manager` | Stage panels, workflow progression, gate submission |
| `experiment-explorer` | MLflow run table, metric comparison, candidate selection |
| `validation-workbench` | Test plan, findings tracker, evidence upload |
| `deployment-console` | Deployment configuration, status tracking, promotion gates |
| `monitoring-dashboard` | Time-series charts, alert feed, incident management |
| `version-explorer` | Version lineage graph, side-by-side comparison |
| `vendor-tracker` | Third-party model registration and review |
| `genai-workbench` | Prompt registry, RAG config, LLM evaluation results |
| `admin-console` | Users, roles, integrations, workflow configuration |
| `compliance-center` | Report generation, audit log explorer, inventory export |

**SRD-FE-001:** The frontend shall be a Single Page Application (SPA) communicating exclusively with the MLM Backend API via HTTPS. No backend logic shall be implemented in the frontend.  
**SRD-FE-002:** The frontend build pipeline shall produce a content-hashed static asset bundle deployable to any CDN-fronted object storage.  
**SRD-FE-003:** The frontend shall implement route-level code splitting to minimize initial bundle size (target: initial bundle < 200KB gzipped).  
**SRD-FE-004:** All API communication shall use the centralized API client with automatic JWT refresh, retry with exponential backoff (max 3 retries), and global error handling.  
**SRD-FE-005:** The frontend shall implement optimistic UI updates for approval actions, with rollback on server error.

---

### 4.2 API Gateway / Backend API

**Technology:** Python 3.11+ / FastAPI  
**Deployment:** Containerized (Docker), orchestrated on Kubernetes (EKS) or ECS Fargate  
**API Style:** RESTful, OpenAPI 3.0 compliant  
**Authentication Middleware:** JWT validation (RS256), OIDC token introspection  
**Authorization Middleware:** RBAC enforcement via policy engine (OPA — Open Policy Agent)  

**Responsibilities:**
- Authenticate all incoming requests.
- Enforce RBAC policies via OPA before routing to service layer.
- Route requests to appropriate service modules.
- Validate request payloads (Pydantic schemas).
- Serialize responses (consistent envelope format).
- Produce structured access logs and distributed traces.
- Rate limiting per authenticated user and per API key.

**SRD-API-001:** All API endpoints shall be prefixed with `/api/v{N}/` where N is the major version number, enabling non-breaking version coexistence.  
**SRD-API-002:** All responses shall use a standard envelope:
```json
{
  "data": { ... },
  "meta": { "page": 1, "per_page": 20, "total": 450, "request_id": "uuid" },
  "errors": []
}
```
**SRD-API-003:** All list endpoints shall support cursor-based pagination via `cursor` and `limit` query parameters.  
**SRD-API-004:** The API shall implement request ID propagation — a `X-Request-ID` header shall be accepted on inbound requests and included in all responses and log entries.  
**SRD-API-005:** Rate limiting shall be enforced: 1,000 req/min per authenticated user; 10,000 req/min per API key (service-to-service); with `429 Too Many Requests` responses including `Retry-After` headers.  
**SRD-API-006:** API documentation shall be auto-generated via FastAPI's OpenAPI integration and served at `/api/docs` (Swagger UI) and `/api/redoc`.

---

### 4.3 Workflow Engine (WFE)

> **⚠ PARTIALLY SUPERSEDED — See `MLM-CWE-001` Section 9 — Runtime Behavior**  
> The stage definitions and approval configuration are superseded by CWE for V2. The core state machine implementation described here is authoritative for MVP and V1. The technology choices (Python, Celery, Redis, SQS) remain valid across all releases.

**Technology:** Custom Python state machine embedded in the Backend Core — no external workflow engine  
**Persistence:** Workflow state in Aurora PostgreSQL (`stage_records`, `approval_tasks`, `approval_decisions`)  
**Workflow config:** JSON definitions stored in `mlm_workflow.workflow_definitions` table  
**Async scheduling:** Celery + Redis (SLA deadline monitoring, notification dispatch)  
**Event propagation:** SQS (stage transition events → downstream workers)

#### 4.3.1 Why No External Workflow Engine

MLM's workflow is a **linear state machine with human approval routing** — not a data pipeline, not a microservice choreographer, not a BPMN process engine. External tools (Temporal, Camunda, Apache Airflow, AWS Step Functions) add infrastructure overhead, operational complexity, and learning curve without delivering meaningful value for this specific pattern.

```
What MLM workflow actually does:
  ✓ Transition stage_records between status values
  ✓ Create approval_task records and route to correct roles
  ✓ Evaluate JSON gate rules (checklist complete, no critical findings)
  ✓ Monitor SLA deadlines (Celery scheduled task, every 15 minutes)
  ✓ Publish SQS events on transitions (notifications, DES cache invalidation)

What it does NOT need:
  ✗ DAG-based execution (Airflow/Prefect — data pipeline tools)
  ✗ Distributed saga orchestration (Temporal — microservice tool)
  ✗ BPMN engine (Camunda — heavy Java infrastructure)
  ✗ Managed state machines (Step Functions — vendor lock-in, awkward human tasks)
```

#### 4.3.2 State Machine Implementation

The workflow engine is implemented as two Python service classes:

**`WorkflowEngine`** — handles all stage and approval transitions synchronously within API request scope:

```python
class WorkflowEngine:
    """
    Manages stage lifecycle state transitions and approval routing.
    All methods execute within a database transaction.
    State is Aurora PostgreSQL. No external dependencies.
    """

    def submit_stage_for_review(
        self, stage_record_id: UUID, submitter_id: UUID
    ) -> StageRecord:
        stage = self.repo.get_stage_record(stage_record_id)
        config = self.load_workflow_config(
            stage_type=stage.stage_type,
            risk_tier=stage.project.risk_tier,
            template_snapshot=stage.project.workflow_template_snapshot  # V2 CWE
        )
        # Evaluate exit conditions (gate rules)
        violations = self.evaluate_gate_rules(stage, config['gate_rules'])
        if violations:
            raise GateSubmissionBlockedError(violations)

        # Transition stage
        stage.status = StageStatus.PENDING_REVIEW
        stage.gate_status = GateStatus.PENDING
        stage.submitted_at = utcnow()
        stage.submitted_by = submitter_id

        # Create approval tasks for all activated levels
        for level in config['approval_levels']:
            if self.evaluate_activation_condition(level, stage):
                self.create_approval_task(stage, level)

        # Audit + event (within same transaction)
        self.audit.write('STAGE_SUBMITTED_FOR_REVIEW', stage, submitter_id)
        self.events.enqueue('MLM.Stage.SubmittedForReview', stage)  # SQS
        return stage  # caller commits transaction

    def process_approval_decision(
        self, task_id: UUID, approver_id: UUID,
        decision: ApprovalDecision, comments: str
    ) -> ApprovalTask:
        task = self.repo.get_approval_task(task_id)

        # OPA authorization (COI + self-approval + role check)
        self.opa.authorize('approval.decide', {
            'user': approver_id,
            'task': task,
            'project': task.stage_record.project
        })

        # Record decision (immutable — no updates ever)
        self.repo.create_approval_decision(task_id, approver_id, decision, comments)
        task.approvals_received += 1

        # Re-evaluate gate completion
        outcome = self.evaluate_gate_completion(task.stage_record)

        if outcome == GateOutcome.APPROVED:
            self._approve_gate(task.stage_record)
            self._activate_next_stage(task.stage_record.model_version)

        elif outcome == GateOutcome.REJECTED:
            self._reject_gate(task.stage_record, comments)

        # GateOutcome.PENDING_MORE_APPROVALS: no action, await more decisions

        self.audit.write('APPROVAL_DECISION_RECORDED', task, approver_id)
        self.events.enqueue('MLM.Approval.DecisionRecorded', task)
        return task

    def rollback_to_stage(
        self, model_version_id: UUID, target_stage: StageType,
        reason: str, initiator_id: UUID
    ) -> StageRecord:
        # Invalidate current attempt for target stage
        prior = self.repo.get_current_stage_record(model_version_id, target_stage)
        if prior:
            prior.is_current = False
            prior.status = StageStatus.ROLLED_BACK
            prior.rollback_reason = reason

        # Create new attempt (attempt_number increments)
        new_record = self.repo.create_stage_record(
            model_version_id=model_version_id,
            stage_type=target_stage,
            attempt_number=(prior.attempt_number + 1) if prior else 1,
            triggered_by=StageTrigger.ROLLBACK,
            parent_record_id=prior.id if prior else None
        )

        self.audit.write('STAGE_ROLLED_BACK', new_record, initiator_id)
        self.events.enqueue('MLM.Stage.RolledBack', new_record)
        return new_record
```

**`WorkflowScheduler`** — Celery periodic task handling SLA monitoring and recurring stage triggers:

```python
@celery.task(name='workflow.check_sla_deadlines')
def check_sla_deadlines():
    """
    Runs every 15 minutes via Celery beat.
    Checks all PENDING approval tasks for SLA breaches.
    """
    breached_tasks = db.query("""
        SELECT id, stage_record_id, required_role, sla_deadline,
               escalation_role, sla_breached
        FROM mlm_workflow.approval_tasks
        WHERE status = 'PENDING'
          AND sla_breached = FALSE
          AND sla_deadline < NOW()
    """)

    for task in breached_tasks:
        db.execute("""
            UPDATE mlm_workflow.approval_tasks
            SET sla_breached = TRUE
            WHERE id = $1
        """, task.id)
        notification_service.send_sla_breach_alert(task)
        audit.write('APPROVAL_SLA_BREACHED', task)
```

#### 4.3.3 JSON Workflow Configuration

Workflow behavior is driven by JSON configuration stored in `mlm_workflow.workflow_definitions`. This is loaded once per stage submission — no live queries during approval processing:

```json
{
  "stage_type": "VALIDATION",
  "version": 1,
  "risk_tier_configs": {
    "1": {
      "sla_hours": 120,
      "approval_levels": [
        {
          "level": 1,
          "type": "SINGLE_APPROVER",
          "role": "MODEL_VALIDATOR",
          "min_approvers": 1,
          "sla_hours": 96,
          "conflict_check": true,
          "exclude_contributors_from_stage": "DEVELOPMENT",
          "self_approval_allowed": false,
          "inline_approval_enabled": true,
          "activation_condition": { "type": "ALWAYS" }
        },
        {
          "level": 2,
          "type": "SINGLE_APPROVER",
          "role": "RISK_OFFICER",
          "min_approvers": 1,
          "sla_hours": 48,
          "conflict_check": false,
          "self_approval_allowed": false,
          "inline_approval_enabled": true,
          "activation_condition": {
            "type": "TIER_FILTER",
            "risk_tiers": [1, 2]
          }
        }
      ],
      "gate_rules": [
        {
          "code": "no_open_critical_findings",
          "type": "FINDING_COUNT",
          "severity": "CRITICAL",
          "statuses": ["OPEN", "IN_REMEDIATION"],
          "operator": "equals",
          "value": 0,
          "failure_action": "BLOCK",
          "failure_message": "All Critical findings must be resolved before gate submission."
        },
        {
          "code": "checklist_complete",
          "type": "CHECKLIST_COMPLETION",
          "operator": "equals",
          "value": 100,
          "failure_action": "BLOCK",
          "failure_message": "All required checklist items must be complete."
        }
      ]
    },
    "3": {
      "sla_hours": 72,
      "approval_levels": [
        {
          "level": 1,
          "type": "SINGLE_APPROVER",
          "role": "MODEL_VALIDATOR",
          "min_approvers": 1,
          "sla_hours": 48,
          "conflict_check": true,
          "exclude_contributors_from_stage": "DEVELOPMENT",
          "activation_condition": { "type": "ALWAYS" }
        }
      ],
      "gate_rules": [
        {
          "code": "checklist_complete",
          "type": "CHECKLIST_COMPLETION",
          "operator": "equals",
          "value": 100,
          "failure_action": "BLOCK"
        }
      ]
    }
  }
}
```

#### 4.3.4 SQS Event Catalog

All workflow transitions publish events to SQS for downstream consumers (notification worker, DES cache invalidation, audit archival trigger):

| Event | Published When | Consumers |
|-------|---------------|-----------|
| `MLM.Stage.Activated` | New stage record created | Notification worker |
| `MLM.Stage.SubmittedForReview` | Stage submitted for gate | Notification worker (approver alert) |
| `MLM.Stage.GateApproved` | All approval levels complete, APPROVED | Notification worker, next-stage activator |
| `MLM.Stage.GateRejected` | Any level REJECTED | Notification worker |
| `MLM.Stage.RolledBack` | Stage rolled back to prior attempt | Notification worker |
| `MLM.Approval.TaskCreated` | New approval task created | Notification worker (inline token email) |
| `MLM.Approval.DecisionRecorded` | Approver decision recorded | Notification worker |
| `MLM.Approval.SLABreached` | SLA deadline passed | Notification worker (escalation) |
| `MLM.Version.StatusChanged` | model_versions.status changes | DES cache invalidation, registry sync |
| `MLM.Model.Retired` | Retirement complete | DES cache invalidation |

**SRD-WFE-001 (revised):** The workflow engine shall be implemented as a Python state machine class with no external workflow engine dependency. All state is persisted in Aurora PostgreSQL within atomic transactions.  
**SRD-WFE-002:** All state transitions shall publish events to SQS for async downstream processing (notifications, DES cache invalidation). Event publishing is within the same database transaction as the state change — publish-on-commit pattern using transactional outbox if needed.  
**SRD-WFE-003:** SLA monitoring shall run as a Celery beat task every 15 minutes, querying `approval_tasks WHERE status='PENDING' AND sla_deadline < NOW() AND sla_breached = FALSE`.  
**SRD-WFE-004:** Workflow configuration (approval levels, gate rules, SLAs) shall be stored as JSON in `mlm_workflow.workflow_definitions` and loaded at stage submission time. Changes to configuration do not affect in-progress stage records.  
**SRD-WFE-005:** All approval decisions are recorded as immutable `approval_decisions` records — no UPDATE or DELETE permitted. Enforced by trigger.

---

### 4.4 Model Registry Service

**Technology:** Python service module within backend core  
**Persistence:** Primary RDBMS (Aurora PostgreSQL)  
**Search:** OpenSearch (full-text and faceted search)  

**Responsibilities:**
- Maintain authoritative records for all model projects and versions.
- Enforce model version immutability after registration.
- Generate globally unique Model IDs.
- Compute and serve the Model Manifest for each version.
- Feed the Deployment Eligibility Service with version eligibility data.
- Maintain version lineage graph.
- Expose search and discovery APIs.

**SRD-REG-001:** Model version registration shall be atomic — either all version metadata (MLflow snapshot, training data reference, parameters, metrics) is committed or none is. Partial version records are not permitted.  
**SRD-REG-002:** After a model version transitions to `VALIDATED`, `DEPLOYED`, or `RETIRED` status, core metadata fields (MLflow run ID, artifact URI, training data hash, validation results reference) shall be write-protected at the database layer (trigger-enforced immutability).  
**SRD-REG-003:** The Registry shall maintain a materialized summary table updated on each version status change, used by the DES cache warm process to minimize eligibility lookup latency.  
**SRD-REG-004:** Version lineage shall be represented as an adjacency list (parent_version_id foreign key) supporting efficient graph traversal for lineage visualization.

---

### 4.5 Deployment Eligibility Service (DES)

**Technology:** Lightweight Python service (FastAPI), independently deployed  
**Deployment:** Separate Kubernetes Deployment / ECS Service with independent HPA  
**Caching:** Redis with configurable TTL (default: 5 minutes)  
**Database:** Read replica of primary RDBMS  

**This service is the most availability-critical component of the platform (target: 99.99%).**

**Architecture:**

```
Deployment Pipeline / CI-CD
         │
         │  GET /eligibility?model_id=X&version=Y&env=production
         ▼
┌────────────────────────────────────────┐
│     Deployment Eligibility Service     │
│                                        │
│  1. Check Redis cache → HIT: return    │
│  2. Cache MISS: query Read Replica     │
│  3. Evaluate eligibility rules         │
│  4. Write result to cache (TTL=5min)   │
│  5. Return eligibility response        │
│                                        │
│  Fallback (DB unavailable):            │
│  - FAIL_OPEN: return CONDITIONAL       │
│    with staleness warning              │
│  - FAIL_CLOSED: return INELIGIBLE      │
│    with service_degraded flag          │
└────────────────────────────────────────┘
         │
         ▼  Read-only
┌────────────────────┐   ┌──────────────┐
│  Aurora Read       │   │  Redis       │
│  Replica           │   │  Cache       │
└────────────────────┘   └──────────────┘
```

**SRD-DES-001:** The DES shall have no synchronous dependencies on the primary application API or write database — it reads exclusively from a read replica and Redis cache.  
**SRD-DES-002:** The DES shall support **cache prewarming** — on startup and on each model version status change event (consumed from the message queue), the DES shall proactively populate the cache for all active model versions.  
**SRD-DES-003:** The DES shall expose a health endpoint (`/health`) returning cache connectivity status, read replica connectivity status, cache hit rate (last 5 min), and fail mode configuration.  
**SRD-DES-004:** The DES shall log every eligibility check with: model_id, version, environment, result, cache_hit (bool), latency_ms, and calling_system (from JWT `client_id` claim).  
**SRD-DES-005:** The DES shall support multi-region active-passive deployment — a secondary DES instance in a failover region shall be warm-standby with DNS failover via Route 53 health checks.

---

### 4.6 Notification Service

**Technology:** Python async service, Celery worker  
**Queue:** SQS (or Kafka topic) for notification tasks  
**Channels:** SMTP, Slack Webhooks, MS Teams Webhooks, PagerDuty Events API  

**SRD-NOT-001:** All notifications shall be template-driven with configurable content per notification type, editable via Admin UI without redeployment.  
**SRD-NOT-002:** Notification delivery failures shall be retried with exponential backoff (max 5 attempts over 2 hours) before moving to dead-letter queue.  
**SRD-NOT-003:** All notification dispatches shall be recorded in the notification log (recipient, channel, template, timestamp, delivery status).  
**SRD-NOT-004:** Users shall be able to manage notification preferences per notification type and channel via the UI, stored in the user preferences table.  
**SRD-NOT-005:** Notification templates shall support variable substitution: `{{model_id}}`, `{{stage}}`, `{{approver_name}}`, `{{deep_link}}`, etc.

---

### 4.7 Audit & Compliance Service

**Technology:** Python service module; writes to dedicated audit store  
**Storage:** Immutable append-only table in Aurora PostgreSQL + archive stream to S3  
**SIEM Integration:** CloudWatch Logs / Splunk HEC / Elastic  

**SRD-AUD-001:** Audit records shall be written synchronously within the same database transaction as the triggering action — audit log write failure shall roll back the triggering action.  
**SRD-AUD-002:** Audit records shall include a SHA-256 hash of the record content + the hash of the prior record (hash chain) enabling tamper detection.  
**SRD-AUD-003:** The audit table shall use PostgreSQL row-level security ensuring no application role can UPDATE or DELETE audit records — only INSERT is permitted.  
**SRD-AUD-004:** Audit records older than the hot retention period shall be automatically archived to S3 in Parquet format, queryable via Athena for long-term compliance queries.  
**SRD-AUD-005:** The Compliance Report Generator shall produce SR 11-7 model inventory reports, validation summary packages, and audit trail exports as PDF and CSV, with digital signature metadata (generated by, timestamp, record count).

---

### 4.8 Integration Layer

**Technology:** Python adapter modules, independently loadable  
**Communication:** Outbound HTTP (adapter → platform); Inbound webhooks (platform → MLM API); Inbound queue consumers (platform metrics → SQS)  

Each adapter implements a standard interface:

```python
class PlatformAdapter(ABC):
    def health_check(self) -> AdapterHealth
    def list_experiments(self, project_ref: str) -> List[Experiment]
    def get_run(self, run_id: str) -> ExperimentRun
    def register_model(self, version: ModelVersion) -> RegistrationResult
    def trigger_deployment(self, config: DeploymentConfig) -> DeploymentResult
    def get_deployment_status(self, deployment_id: str) -> DeploymentStatus
    def terminate_deployment(self, deployment_id: str) -> TerminationResult
```

**SRD-INT-001:** All outbound integration calls shall be wrapped with circuit breakers (Hystrix-pattern) with configurable thresholds per adapter.  
**SRD-INT-002:** Integration adapter credentials shall never be stored in the application database in plaintext — all credentials are stored in AWS Secrets Manager / Vault and retrieved at runtime.  
**SRD-INT-003:** Each adapter shall produce structured integration logs (adapter type, operation, target platform, latency, outcome, error detail) queryable via the Admin UI.  
**SRD-INT-004:** Integration adapter configuration changes (endpoint URL, credential rotation) shall take effect within 60 seconds without service restart.  
**SRD-INT-005:** The Integration Layer shall support a **Test Connection** action per configured adapter, verifiable from the Admin UI.

---

### 4.9 Monitoring Ingest Pipeline

**Technology:** Celery workers consuming from SQS/Kafka; Python processing  
**Input:** SQS queue / Kafka topic receiving metric events  
**Storage:** Amazon Timestream (time-series) + Aurora PostgreSQL (alert records, incident records)  

**Ingest Flow:**

```
External Monitor        MLM Ingest API          Message Queue        Worker Pool
(SageMaker MM /   →   POST /monitoring/ingest →  SQS/Kafka topic →  Consumer group
 Evidently / etc)                                                       │
                                                                        ▼
                                                              Validate payload
                                                              Map to model version
                                                              Write to Timestream
                                                              Evaluate alert rules
                                                              Trigger alerts if breach
```

**SRD-MIP-001:** The ingest API endpoint shall be a lightweight, stateless endpoint that validates the payload schema and enqueues to the message queue without performing any synchronous processing — target response time < 50ms.  
**SRD-MIP-002:** Worker consumers shall be horizontally scalable — additional consumer instances shall be deployable without configuration changes.  
**SRD-MIP-003:** Alert rule evaluation shall occur within the worker after writing the metric to Timestream — it shall compare the metric against all active alert rules for the model version and create alert records for any breaches.  
**SRD-MIP-004:** The ingest pipeline shall support **backpressure signaling** — if the queue depth exceeds a configurable threshold, the ingest API shall return `429 Too Many Requests` to allow producers to throttle.  
**SRD-MIP-005:** Failed metric processing (after retry exhaustion) shall be written to a dead-letter queue and trigger an operational alert to the MLOps team.

---

## 5. Deployment Architecture

### 5.1 Target Deployment Platform

Primary deployment target: **Amazon Web Services (AWS)**  
Alternative targets (via configuration): Microsoft Azure, Google Cloud Platform  

All components are containerized and Kubernetes-native, with cloud-specific managed service adapters (Aurora on AWS / Azure Database for PostgreSQL on Azure / Cloud SQL on GCP, etc.).

### 5.2 AWS Reference Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              AWS Account — MLM Platform                         │
│                                                                                 │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │                         Route 53 (DNS)                                   │   │
│  └──────────────────────────┬─────────────────────────────────┬─────────────┘   │
│                             │                                 │                 │
│  ┌──────────────────────────▼──────────┐  ┌──────────────────▼─────────────┐   │
│  │    CloudFront + WAF                 │  │  DES — Route 53 Health Check   │   │
│  │    (Frontend CDN + API protection)  │  │  + CloudFront (DES endpoint)   │   │
│  └──────────────────────────┬──────────┘  └──────────────────┬─────────────┘   │
│                             │                                 │                 │
│  ┌──────────────────────────▼─────────────────────────────────▼─────────────┐   │
│  │                      VPC (Multi-AZ)                                      │   │
│  │                                                                           │   │
│  │  ┌──────────────────────────────────────────────────────────────────┐    │   │
│  │  │                    Public Subnets (2 AZs)                        │    │   │
│  │  │  ┌──────────────────────────────────────────────────────────┐    │    │   │
│  │  │  │                Application Load Balancer                  │    │    │   │
│  │  │  └──────────────────────────┬───────────────────────────────┘    │    │   │
│  │  └──────────────────────────────│────────────────────────────────────┘    │   │
│  │                                 │                                          │   │
│  │  ┌──────────────────────────────▼───────────────────────────────────┐    │   │
│  │  │                  Private App Subnets (2 AZs)                     │    │   │
│  │  │                                                                   │    │   │
│  │  │  ┌───────────────────────────────────────────────────────────┐   │    │   │
│  │  │  │               Amazon EKS Cluster                          │   │    │   │
│  │  │  │  ┌─────────────┐ ┌──────────────┐ ┌───────────────────┐  │   │    │   │
│  │  │  │  │  Backend    │ │  DES Pods    │ │  Worker Pool      │  │   │    │   │
│  │  │  │  │  API Pods   │ │  (isolated   │ │  (Celery)         │  │   │    │   │
│  │  │  │  │  (HPA: 3-20)│ │  node group) │ │  (HPA: 2-50)      │  │   │    │   │
│  │  │  │  └─────────────┘ └──────────────┘ └───────────────────┘  │   │    │   │
│  │  │  └───────────────────────────────────────────────────────────┘   │    │   │
│  │  └──────────────────────────────────────────────────────────────────┘    │   │
│  │                                                                           │   │
│  │  ┌──────────────────────────────────────────────────────────────────┐    │   │
│  │  │                  Private Data Subnets (2 AZs)                    │    │   │
│  │  │                                                                   │    │   │
│  │  │  ┌───────────────┐  ┌──────────────┐  ┌──────────────────────┐  │    │   │
│  │  │  │ Aurora PG     │  │  ElastiCache │  │  Amazon SQS          │  │    │   │
│  │  │  │ Multi-AZ      │  │  Redis       │  │  (Queues + DLQs)     │  │    │   │
│  │  │  │ (Writer +     │  │  (DES cache  │  │                      │  │    │   │
│  │  │  │  2 Readers)   │  │   + sessions │  │  ← Full-text search  │  │    │   │
│  │  │  │               │  │   + rate lim)│  │    via PostgreSQL     │  │    │   │
│  │  │  │  Full-text    │  │              │  │    tsvector; no      │  │    │   │
│  │  │  │  search via   │  └──────────────┘  │    OpenSearch needed  │  │    │   │
│  │  │  │  tsvector     │                    └──────────────────────┘  │    │   │
│  │  │  └───────────────┘                                               │    │   │
│  │  │                                                                   │    │   │
│  │  │  ┌──────────────────────────────────────────────────────────┐    │    │   │
│  │  │  │  S3 (Artifact store + audit archive + report export)     │    │    │   │
│  │  │  └──────────────────────────────────────────────────────────┘    │    │   │
│  │  └──────────────────────────────────────────────────────────────────┘    │   │
│  └───────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌──────────────────────────┐  ┌───────────────────────┐  ┌─────────────────┐  │
│  │  AWS Secrets Manager     │  │  AWS KMS              │  │  AWS CloudWatch  │  │
│  │  (Integration credentials│  │  (Encryption keys)    │  │  (Logs + Metrics)│  │
│  │   + app secrets)         │  │                       │  │                 │  │
│  └──────────────────────────┘  └───────────────────────┘  └─────────────────┘  │
│                                                                                 │
│  ┌──────────────────────────┐  ┌───────────────────────┐                       │
│  │  AWS Cognito /           │  │  ECR                  │                       │
│  │  IAM Identity Center     │  │  (Container registry) │                       │
│  │  (SSO + JWT issuance)    │  │                       │                       │
│  └──────────────────────────┘  └───────────────────────┘                       │
└─────────────────────────────────────────────────────────────────────────────────┘

         ┌─────────────────────────────────────────────┐
         │          DR Region (Active-Passive)          │
         │  Aurora Global DB secondary                  │
         │  DES standby deployment                      │
         │  S3 cross-region replication                 │
         └─────────────────────────────────────────────┘
```

### 5.3 Kubernetes Resource Specifications

| Component | Min Replicas | Max Replicas (HPA) | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|-------------|-------------------|-------------|----------------|-----------|--------------|
| Backend API | 3 | 20 | 500m | 512Mi | 2000m | 2Gi |
| DES | 3 | 10 | 250m | 256Mi | 1000m | 1Gi |
| Celery Workers | 2 | 50 | 500m | 1Gi | 2000m | 4Gi |
| Frontend (if served from K8s) | 2 | 10 | 100m | 128Mi | 500m | 512Mi |

DES pods shall run on a **dedicated node group** with node affinity rules preventing co-location with batch worker pods, ensuring DES latency is not affected by CPU-intensive worker processing.

### 5.4 CI/CD Pipeline Architecture

```
Developer Push → GitHub PR
        │
        ▼
GitHub Actions Workflow
├── Lint + Type Check (Ruff, mypy)
├── Unit Tests (pytest, coverage > 80%)
├── Integration Tests (TestContainers)
├── Security Scan (Bandit, Trivy image scan, OWASP dependency check)
├── Build Docker Image
├── Push to ECR (tagged: branch-sha)
│
├── [On PR merge to main]
│   ├── Build + tag :staging
│   ├── Deploy to Staging EKS namespace
│   ├── Run E2E test suite (Playwright)
│   └── Notify QA for exploratory testing
│
└── [On release tag]
    ├── Build + tag :vX.Y.Z + :latest
    ├── Blue/Green deployment to Production EKS
    ├── Smoke test against Production
    ├── Promote green → traffic switch
    └── Notify stakeholders
```

**SRD-CICD-001:** All production deployments shall use blue/green strategy with automated rollback on health check failure within 5 minutes.  
**SRD-CICD-002:** Container images shall be scanned for HIGH and CRITICAL CVEs before pushing to ECR; builds with CRITICAL CVEs shall fail the pipeline.  
**SRD-CICD-003:** Database migrations shall run as Kubernetes Jobs in the pre-deployment phase, with automatic rollback of the deployment if migration fails.  
**SRD-CICD-004:** All infrastructure changes shall be applied via Terraform Cloud with plan approval required before apply on the production workspace.

---

## 6. Data Architecture

### 6.1 Data Store Summary

> **Revision:** OpenSearch has been removed. Full-text search is handled by PostgreSQL tsvector + GIN indexes. Amazon Timestream is deferred to V2 (added when native time-series charts are built). For MVP and V1, monitoring alert summaries are stored in Aurora.

| Store | Technology | Purpose | Data Characteristics | Release |
|-------|------------|---------|---------------------|---------|
| **Primary RDBMS** | Aurora PostgreSQL 15 (Multi-AZ) | All transactional data — model records, workflow state, approvals, users, audit, full-text search | Structured, relational, ACID, low-latency reads/writes, tsvector FTS | ✅ MVP |
| **Cache** | Amazon ElastiCache for Redis 7 | DES eligibility cache, session store, rate limit counters | Low-latency key-value, TTL-managed | ✅ MVP |
| **Message Queue** | Amazon SQS | Async task queue, monitoring ingest, notification queue, workflow events | Durable, at-least-once, FIFO for ordered events | ✅ MVP |
| **Object Storage** | Amazon S3 | Artifact files, report exports, audit archive, static frontend assets | Durable, versioned, lifecycle-managed | ✅ MVP |
| **Time-Series Store** | Amazon Timestream | Monitoring metric time-series data (when native charts are built) | High-volume append-only, time-windowed queries, auto-tiered | 🔷 V2 |

**Full-text search implementation (PostgreSQL tsvector):**

```sql
-- Model project search index (created at schema migration time)
ALTER TABLE mlm_core.model_projects
  ADD COLUMN search_vector tsvector GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce(name, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(description, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(business_domain, '')), 'C')
  ) STORED;

CREATE INDEX idx_model_projects_fts
  ON mlm_core.model_projects USING GIN (search_vector);

-- Faceted filtering uses standard B-tree indexes on
-- current_stage, risk_tier, owner_user_id, model_type
-- No search engine needed for MLM's query patterns
```

**When to add OpenSearch (V2/V3 trigger criteria):**
- Model registry search P95 latency exceeds 500ms at scale
- Cross-portfolio analytics feature is built (aggregations across all models)
- LLM input/output trace search is added (governance investigations)
- Audit log grows beyond 10M rows with complex analytical query patterns

### 6.2 Database Schema Organization

The Aurora PostgreSQL database is organized into logical schemas:

```
mlm_core          — model projects, versions, stage records, artifacts, approvals
mlm_workflow      — workflow definitions, approval tasks, activity log
mlm_monitoring    — monitoring configs, alert rules, alert records, incidents
mlm_registry      — model registry summary, version eligibility cache table
mlm_audit         — audit log (immutable, row-level security enforced)
mlm_integration   — integration configurations, adapter logs, sync state
mlm_users         — users, roles, project assignments, preferences, sessions
mlm_notifications — notification templates, dispatch log, user preferences
mlm_vendor        — vendor model records, review history, due diligence docs
mlm_genai         — prompt registry, RAG config, LLM evaluation results
```

### 6.3 Key Schema Decisions

**SRD-DB-001:** The `mlm_audit.audit_log` table shall have a PostgreSQL trigger that prevents UPDATE and DELETE operations, raising an exception if attempted by any role including the application role.  

**SRD-DB-002:** Model version core fields shall use a PostgreSQL trigger to enforce immutability after status transitions past `IN_DEVELOPMENT`:
```sql
-- Fields protected after VALIDATED status:
-- mlflow_run_id, artifact_uri, training_data_hash, model_signature, metrics, parameters
```

**SRD-DB-003:** All foreign keys referencing `model_versions` shall use `ON DELETE RESTRICT` — model versions shall never be physically deleted (soft-delete via status field only).  

**SRD-DB-004:** The `mlm_registry.version_eligibility_summary` materialized view shall be refreshed automatically via trigger on `model_versions.status` change and consumed by the DES read replica.  

**SRD-DB-005:** PII-adjacent fields (user names, emails in approvals) shall be stored in a separate `mlm_users` schema with column-level encryption for sensitive fields (pgcrypto).  

**SRD-DB-006:** Database connection pooling shall use PgBouncer in transaction pooling mode, with pool sizing: API tier (max 50 connections), Worker tier (max 100 connections), DES (max 20 connections on read replica).

### 6.4 Data Flow Diagrams

#### 6.4.1 Model Version Registration Flow

```
Data Scientist (UI)
      │
      │  POST /api/v1/models/{id}/development/candidate
      ▼
Backend API
      │
      ├── Validate JWT + RBAC (Data Scientist role on project)
      ├── Call MLflow Adapter: get_run(mlflow_run_id)
      │       └── MLflow Tracking Server ──► return run metadata
      ├── Compute training_data_hash from dataset reference
      ├── BEGIN TRANSACTION
      │   ├── INSERT model_versions record (status=IN_DEVELOPMENT)
      │   ├── INSERT mlflow_snapshot (immutable)
      │   ├── Deactivate prior candidate (if exists)
      │   ├── INSERT audit_log record
      │   └── COMMIT
      ├── Enqueue: notify_stakeholders event → SQS
      └── Return: 201 Created + model_version record
```

#### 6.4.2 Deployment Eligibility Check Flow

```
CI/CD Pipeline / Deployment Platform
      │
      │  GET /eligibility?model_id=X&version=1.2.0&env=production
      ▼
DES (Deployment Eligibility Service)
      │
      ├── Check Redis cache key: eligibility:{model_id}:{version}:{env}
      │   ├── HIT: return cached response (latency ~5ms)
      │   └── MISS:
      │         ├── Query Aurora Read Replica: version_eligibility_summary
      │         ├── Evaluate eligibility rules:
      │         │   ├── status == VALIDATED or DEPLOYED?
      │         │   ├── validation not expired?
      │         │   ├── not RETIRED or SUPERSEDED?
      │         │   └── environment-specific approval exists?
      │         ├── Write result to Redis (TTL=5min)
      │         └── Return eligibility response
      │
      └── Log eligibility_check event (async, non-blocking)
```

#### 6.4.3 Monitoring Metric Ingest Flow

```
External Monitor (SageMaker MM / Evidently / Custom)
      │
      │  POST /api/v1/monitoring/ingest  {metric_payload}
      ▼
Ingest API (lightweight endpoint)
      │
      ├── Validate API key (service-to-service auth)
      ├── Validate payload schema (Pydantic)
      ├── Enqueue to SQS: monitoring_ingest queue
      └── Return: 202 Accepted (< 50ms target)

            │
            ▼  (async, consumer worker)
      Worker Pool
            │
            ├── Deserialize + enrich payload
            ├── Map to model_version_id (via integration config)
            ├── Write to Amazon Timestream (metric record)
            ├── Load active alert rules for model version
            ├── Evaluate each rule: metric_value vs threshold
            ├── For each breach:
            │   ├── INSERT alert_record (Aurora)
            │   ├── Enqueue: notification_dispatch event → SQS
            │   └── If CRITICAL: enqueue incident_create event
            └── Acknowledge SQS message
```

---

## 7. Interface Specifications

### 7.1 REST API — Core Endpoints (Detailed)

#### 7.1.1 Model Project Endpoints

```
GET    /api/v1/models
  Query params: cursor, limit(default:20, max:100), status, risk_tier,
                domain, owner_id, stage, search, tags[], sort_by, sort_dir
  Response: { data: [ModelProjectSummary], meta: PaginationMeta }

POST   /api/v1/models
  Body: CreateModelProjectRequest
    { name, description, business_domain, use_case, risk_inputs,
      stakeholders[], regulatory_scope[], tags[], model_type: INTERNAL|VENDOR|GENAI }
  Response: 201 { data: ModelProject }

GET    /api/v1/models/{model_id}
  Response: { data: ModelProject + current_stage_detail + active_alerts_count }

PATCH  /api/v1/models/{model_id}
  Body: UpdateModelProjectRequest (name, description, tags, owner_id only)
  Response: { data: ModelProject }
```

#### 7.1.2 Model Version Endpoints

```
GET    /api/v1/models/{model_id}/versions
  Query params: status, cursor, limit
  Response: { data: [ModelVersionSummary], meta: PaginationMeta }

POST   /api/v1/models/{model_id}/versions
  Body: CreateVersionRequest
    { version_type: MAJOR|MINOR|PATCH, parent_version_id?, description }
  Response: 201 { data: ModelVersion }

GET    /api/v1/models/{model_id}/versions/{version}
  Response: { data: ModelVersion + stage_records + deployment_records + monitoring_summary }

GET    /api/v1/models/{model_id}/versions/{version}/manifest
  Response: { data: ModelManifest }  ← machine-readable eligibility + artifact refs

GET    /api/v1/models/{model_id}/versions/{version}/lineage
  Response: { data: VersionLineageGraph }  ← nodes + edges for lineage visualization

GET    /api/v1/models/{model_id}/versions/compare
  Query params: version_a, version_b
  Response: { data: VersionComparison }  ← side-by-side metrics, params, validation
```

#### 7.1.3 Stage & Workflow Endpoints

```
GET    /api/v1/models/{model_id}/versions/{version}/stages/{stage_type}
  Response: { data: StageRecord + artifacts + approvals + findings }

POST   /api/v1/models/{model_id}/versions/{version}/stages/{stage_type}/submit
  Body: { comments?, idempotency_key }
  Response: { data: StageRecord }  ← transitions to PENDING_REVIEW

POST   /api/v1/models/{model_id}/versions/{version}/stages/{stage_type}/approve
  Body: { decision: APPROVED|REJECTED|CONDITIONAL, conditions?, comments,
          idempotency_key }
  Response: { data: ApprovalRecord }

POST   /api/v1/models/{model_id}/versions/{version}/stages/{stage_type}/rollback
  Body: { reason, target_stage: DEVELOPMENT|INCEPTION }
  Response: { data: StageRecord }

GET    /api/v1/models/{model_id}/versions/{version}/stages/{stage_type}/activity
  Response: { data: [WorkflowActivityEvent] }
```

#### 7.1.4 Deployment Eligibility API

```
GET    /api/v1/deployment/eligibility
  Query params: model_id (required), version (required), environment (required),
                platform (optional)
  Auth: Bearer JWT (service-to-service client credentials grant)
  Response:
    200 {
      "eligible": true,
      "status": "ELIGIBLE" | "INELIGIBLE" | "CONDITIONAL",
      "model_id": "MOD-2024-00421",
      "version": "1.2.0",
      "environment": "production",
      "validation_date": "ISO8601",
      "validation_expiry": "ISO8601 | null",
      "validator": "user_id",
      "conditions": ["string"],
      "restrictions": ["string"],
      "ineligibility_reasons": [
        { "code": "NOT_VALIDATED", "message": "string" }
      ],
      "cache_hit": true,
      "checked_at": "ISO8601"
    }
  Error codes:
    MODEL_NOT_FOUND, VERSION_NOT_FOUND, INVALID_ENVIRONMENT,
    SERVICE_DEGRADED (DES fallback mode)

POST   /api/v1/deployment/events
  Body: DeploymentEventPayload
    { model_id, version, environment, platform, event_type: STARTED|SUCCEEDED|FAILED|ROLLED_BACK,
      platform_resource_id, deployed_by?, timestamp, metadata: {} }
  Auth: Bearer JWT (service-to-service)
  Response: 202 Accepted
```

#### 7.1.5 Monitoring Ingest API

```
POST   /api/v1/monitoring/ingest
  Auth: API Key (X-Api-Key header)
  Body: MonitoringMetricPayload
    { integration_id, model_id?, model_version?,
      metrics: [
        { name, value, unit, timestamp, dimensions: {} }
      ],
      source_platform, batch_id? }
  Response: 202 { data: { batch_id, enqueued_count } }

POST   /api/v1/monitoring/ingest/batch
  Body: { payloads: [MonitoringMetricPayload] }  ← batch up to 500 metrics
  Response: 202 { data: { batch_id, enqueued_count, rejected_count } }
```

### 7.2 Webhook Interfaces

#### 7.2.1 Inbound Webhooks (MLM receives)

| Source | Endpoint | Event Types | Authentication |
|--------|----------|-------------|----------------|
| GitHub Actions | `POST /webhooks/cicd/github` | deployment.started, deployment.completed, deployment.failed | HMAC-SHA256 signature |
| GitLab CI | `POST /webhooks/cicd/gitlab` | deployment.started, deployment.completed, deployment.failed | Secret token header |
| Jenkins | `POST /webhooks/cicd/jenkins` | build.started, build.completed | Basic auth |
| SageMaker (CloudWatch Events) | `POST /webhooks/aws/cloudwatch` | training.completed, endpoint.created, monitor.violation | AWS SNS HMAC |
| Databricks | `POST /webhooks/databricks` | job.completed, model.registered | Shared secret |

#### 7.2.2 Outbound Webhooks (MLM sends)

| Target | Trigger | Payload |
|--------|---------|---------|
| CI/CD Pipeline | Stage approved (Implementation gate) | `{ model_id, version, action: DEPLOY, target_env, config_uri }` |
| Deployment Platform | Retirement decommission approved | `{ model_id, version, action: TERMINATE, platform_resource_id }` |
| Custom Receiver | Any configurable event (per project) | Configurable payload template |

### 7.3 MLflow Integration API Contract

MLM integrates with MLflow via the MLflow REST API (v2):

```
# Experiment listing
GET {mlflow_tracking_uri}/api/2.0/mlflow/experiments/search
  Params: filter_string="tags.mlm_project_id = '{project_id}'"

# Run retrieval
GET {mlflow_tracking_uri}/api/2.0/mlflow/runs/get
  Params: run_id={mlflow_run_id}

# Model registration (to MLflow Model Registry)
POST {mlflow_tracking_uri}/api/2.0/mlflow/registered-models/create
POST {mlflow_tracking_uri}/api/2.0/mlflow/model-versions/create

# Auth: Bearer token (Databricks) or basic auth (OSS MLflow)
```

MLM tags convention for MLflow runs to enable auto-association:
```
mlm.project_id    = MOD-2024-00421
mlm.version       = 1.2.0
mlm.environment   = development
```

---

## 8. Security Architecture

### 8.1 Security Zones

```
Zone 1 — Public Edge
  CloudFront (WAF + DDoS protection) → ALB
  
Zone 2 — Application Tier (Private Subnet)
  EKS node groups → Backend API, DES, Workers
  No direct internet access; egress via NAT Gateway
  
Zone 3 — Data Tier (Private Subnet — further restricted)
  Aurora, ElastiCache, Timestream, OpenSearch
  No access from public subnets; SG allows only App tier
  
Zone 4 — Management
  Bastion host (SSM Session Manager only; no SSH keys)
  CI/CD pipeline access via IAM role assumption
```

### 8.2 Authentication Flow

```
User (Browser)
    │
    │  1. Navigate to MLM UI
    ▼
CloudFront
    │
    │  2. Unauthenticated → redirect to IdP
    ▼
Identity Provider (Okta / Azure AD)
    │
    │  3. SAML assertion / OIDC code
    ▼
AWS Cognito (or Auth0)
    │
    │  4. Exchange for JWT (access token + refresh token)
    │     Access token: 15-minute expiry
    │     Refresh token: 8-hour expiry (httpOnly cookie)
    ▼
MLM Frontend
    │
    │  5. API requests: Authorization: Bearer {access_token}
    ▼
MLM Backend API
    │
    │  6. Validate JWT signature (RS256, public key from JWKS endpoint)
    │  7. Extract claims: sub, email, roles[], project_assignments[]
    │  8. Forward to OPA policy engine for RBAC decision
    ▼
OPA (Open Policy Agent)
    │
    │  9. Evaluate: allowed(action, resource, user_claims)?
    └── 10. Allow / Deny
```

### 8.3 Service-to-Service Authentication

External systems (CI/CD pipelines, monitoring platforms) that call MLM APIs use **OAuth2 Client Credentials** flow:

```
CI/CD Pipeline
    │
    │  POST /oauth/token
    │  { client_id, client_secret, grant_type: client_credentials, scope: eligibility:read }
    ▼
Cognito / Auth0
    │
    │  Return: access_token (JWT, 1-hour expiry, scoped claims)
    ▼
CI/CD Pipeline
    │
    │  GET /api/v1/deployment/eligibility?...
    │  Authorization: Bearer {access_token}
    ▼
MLM DES
```

### 8.4 RBAC Policy Engine

MLM uses **Open Policy Agent (OPA)** with Rego policies for authorization:

```rego
# Example: only validators not involved in development may record test results
allow {
  input.action == "validation.record_test_result"
  input.user.roles[_] == "MODEL_VALIDATOR"
  not user_is_developer_on_project(input.user.id, input.resource.project_id)
}

user_is_developer_on_project(user_id, project_id) {
  development_contributors[project_id][_] == user_id
}
```

**SRD-SEC-001:** OPA policies shall be version-controlled in the application repository and loaded into OPA at deployment time. Policy updates require code review and deployment.  
**SRD-SEC-002:** All OPA decisions shall be logged with: user_id, action, resource, decision (allow/deny), matched_policy, timestamp.  
**SRD-SEC-003:** The OPA sidecar shall run within each API pod, ensuring policy evaluation is synchronous and does not add network latency.

### 8.5 Encryption Specifications

| Data | Encryption at Rest | Encryption in Transit |
|------|-------------------|----------------------|
| Aurora PostgreSQL | AES-256 (AWS KMS CMK) | TLS 1.3 (enforced via parameter group) |
| ElastiCache Redis | AES-256 (AWS KMS CMK) | TLS 1.3 (in-transit encryption enabled) |
| S3 buckets | SSE-S3 (default) or SSE-KMS (audit + artifact buckets) | TLS 1.3 (S3 enforced via bucket policy) |
| Timestream | AES-256 (AWS managed) | TLS 1.3 |
| API communication | — | TLS 1.3 (CloudFront + ALB termination; re-encrypted to pods) |
| Secrets in Secrets Manager | AES-256 (KMS CMK) | TLS |
| Inter-service (within K8s) | mTLS via Istio service mesh | mTLS |

### 8.6 Vulnerability Management

**SRD-SEC-010:** Container images shall be scanned weekly by Amazon ECR Enhanced Scanning (Snyk). HIGH and CRITICAL findings shall generate a JIRA ticket and be remediated within 14 days (CRITICAL: 72 hours).  
**SRD-SEC-011:** Penetration testing shall be conducted annually by an independent third party. OWASP Top 10 shall be verified at each major release.  
**SRD-SEC-012:** SAST (Bandit) and dependency scanning (pip-audit, Safety) shall run in the CI pipeline; HIGH findings block merges.

---

## 9. Integration Architecture

### 9.1 Integration Configuration Storage

Integration configurations are stored in `mlm_integration.integration_configs`:

```
integration_configs
├── id (UUID)
├── name
├── platform_type (enum)
├── scope: GLOBAL | PROJECT
├── project_id (null if GLOBAL)
├── endpoint_url
├── auth_type (API_KEY | OAUTH2_CLIENT | AWS_ROLE | BASIC)
├── credentials_secret_arn (reference to Secrets Manager)
├── config_json (platform-specific configuration)
├── is_active
├── last_health_check_at
├── last_health_check_status
├── created_by
└── updated_at
```

### 9.2 MLflow Sync Architecture

MLM uses a **polling + webhook hybrid** for MLflow run ingestion:

```
Primary: Polling (every 60s)
  Worker Job: poll_mlflow_experiments
    FOR each active project with MLflow integration:
      GET {tracking_uri}/api/2.0/mlflow/runs/search
        filter: "experiment_id = '{exp_id}' AND start_time > {last_sync_time}"
      FOR each new run:
        Upsert to mlm_integration.mlflow_run_cache
        Notify UI via WebSocket (if user viewing Development stage)

Secondary: Webhook (where supported — Databricks MLflow)
  Databricks Registry Webhook → POST /webhooks/databricks
    Trigger: MODEL_REGISTERED event
    Action: immediate run cache update + UI push notification
```

### 9.3 SageMaker Integration Details

```
┌─────────────────────────────────────────────────────────────┐
│               SageMaker Integration Adapter                  │
│                                                             │
│  IAM Role: arn:aws:iam::{account}:role/MLM-SageMaker-Role  │
│  Permissions:                                               │
│    sagemaker:ListExperiments                                │
│    sagemaker:ListTrials                                     │
│    sagemaker:DescribeTrainingJob                            │
│    sagemaker:CreateModelPackage                             │
│    sagemaker:DescribeEndpoint                               │
│    sagemaker:CreateEndpoint (if deployment trigger enabled) │
│    sagemaker:DeleteEndpoint (if retirement trigger enabled) │
│    cloudwatch:GetMetricData (for Monitor metrics)           │
│    s3:GetObject (for Monitor baseline results)              │
└─────────────────────────────────────────────────────────────┘
```

Cross-account SageMaker access (customer environments) shall use **IAM role assumption** with external ID validation, avoiding the need for long-lived credentials.

---

## 10. System Constraints

### 10.1 Technology Constraints

| Constraint | Specification |
|------------|--------------|
| **Backend language** | Python 3.11+ |
| **Frontend language** | TypeScript 5.x |
| **Container runtime** | Docker (OCI-compliant) |
| **Orchestration** | Kubernetes 1.28+ |
| **Primary database** | PostgreSQL 15+ (Aurora or compatible) |
| **Minimum TLS version** | TLS 1.2 (TLS 1.3 preferred) |
| **Browser support** | Chrome 110+, Firefox 110+, Safari 16+, Edge 110+ |
| **Minimum viewport** | 768px width (tablet) |
| **API protocol** | HTTPS only; HTTP redirects to HTTPS |
| **Authentication standard** | OIDC / SAML 2.0 only; no local username/password accounts |

### 10.2 Regulatory & Compliance Constraints

| Constraint | Impact |
|------------|--------|
| **Audit log immutability** | Database-enforced; cannot be relaxed by configuration |
| **Model version immutability post-validation** | Database-enforced; cannot be overridden by API |
| **COI enforcement (SR 11-7)** | System-enforced; cannot be bypassed by any role except Admin with full audit |
| **Data residency** | Default AWS region must be configurable; cross-region replication for DR must respect same-geography constraint |
| **PII in audit logs** | User identifiers (IDs, emails) in audit logs are subject to GDPR right to erasure via anonymization |

### 10.3 Operational Constraints

- The platform shall support a maximum of **50,000 model projects** in a single deployment instance. Beyond this, horizontal sharding by organizational unit is required.
- Artifact files are **not stored within MLM** — the platform stores metadata and S3/ADLS URIs only. Customers must provision their own object storage.
- The monitoring ingest pipeline requires customer monitoring platforms to push metrics to MLM — pull-based monitoring collection is not supported in the base architecture.

---

## 11. System Quality Attributes

### 11.1 Performance

Refer to NFR Supplement Section 1.1 for full performance targets. Key system-level design decisions supporting performance:

- DES Redis cache with 5-minute TTL reduces Aurora query load for eligibility checks by an estimated 95%+ under steady-state traffic.
- Monitoring metric ingest is fully asynchronous — the API response is returned before any processing occurs, ensuring ingest endpoint latency is independent of processing volume.
- Full-text search is delegated to OpenSearch, preventing search queries from impacting primary RDBMS performance.
- Aurora read replicas serve all DES queries, search sync, and reporting queries — write operations are isolated to the primary writer.

### 11.2 Reliability

- Aurora Multi-AZ ensures automatic failover to standby replica (< 60 seconds) with no data loss.
- ElastiCache Redis cluster mode with automatic failover (< 30 seconds).
- SQS message visibility timeout set to 5 minutes; messages are re-processed if workers fail mid-processing.
- EKS pod disruption budgets ensure minimum 2 replicas remain available during node maintenance for Backend API and DES.

### 11.3 Maintainability

- All workflow rules, alert thresholds, notification templates, and retention policies are database-stored configuration — changes deploy without application redeployment.
- Integration adapters are independently deployable modules — new platforms can be added by implementing the adapter interface and adding a configuration entry.
- Feature flags (AWS AppConfig or LaunchDarkly) enable gradual rollout of new features.

---

## 12. Operational Requirements

### 12.1 Monitoring & Alerting (Platform Operations)

The MLM platform shall be monitored using the following operational dashboards and alerts:

| Metric | Warning Threshold | Critical Threshold | Alert Recipient |
|--------|------------------|-------------------|----------------|
| API error rate (5xx) | > 1% | > 5% | On-call engineer |
| API P95 latency | > 1s | > 3s | On-call engineer |
| DES P95 latency | > 200ms | > 500ms | On-call engineer + escalation |
| DES cache hit rate | < 70% | < 50% | MLOps team |
| SQS queue depth (monitoring ingest) | > 10,000 | > 50,000 | MLOps team |
| SQS dead-letter queue depth | > 0 | > 100 | On-call engineer |
| Aurora CPU utilization | > 70% | > 90% | DBA + On-call |
| Aurora replication lag | > 30s | > 120s | DBA |
| Worker pod restarts | > 5/hr | > 20/hr | On-call engineer |
| Failed notification deliveries | > 10/hr | > 100/hr | Platform team |

### 12.2 Backup & Recovery Procedures

**SRD-OPS-001:** Aurora automated backups shall be configured with 30-day retention and point-in-time recovery enabled. Weekly manual snapshots shall be retained for 1 year.  
**SRD-OPS-002:** A DR drill shall be conducted quarterly, testing: Aurora Global Database promotion, DES failover to secondary region, and application recovery from backup, with results documented.  
**SRD-OPS-003:** S3 audit archive bucket shall have versioning enabled and Object Lock (COMPLIANCE mode, 10-year retention) for immutable audit storage.

### 12.3 Runbook Requirements

The following operational runbooks shall be produced and maintained:

| Runbook | Trigger |
|---------|---------|
| DES Failover Procedure | DES primary region unavailable |
| Database Failover | Aurora primary failure |
| Deployment Eligibility Cache Flush | Stale eligibility data detected |
| Monitoring Ingest Pipeline Recovery | DLQ depth spike |
| Emergency Model Version Block | Security incident requiring immediate eligibility block |
| Integration Credential Rotation | Scheduled or emergency credential rotation |
| Performance Degradation Diagnosis | API latency SLA breach |

---

## 13. Acceptance Criteria

Acceptance criteria define the testable conditions that must be satisfied before a system component or feature is considered production-ready.

### 13.1 System-Level Acceptance Criteria

| ID | Criterion | Test Type | Pass Condition |
|----|-----------|-----------|----------------|
| AC-SYS-001 | Deployment Eligibility API returns correct ELIGIBLE response for a validated model version | Automated E2E | HTTP 200, status=ELIGIBLE, latency < 150ms |
| AC-SYS-002 | Deployment Eligibility API returns INELIGIBLE for a non-validated version | Automated E2E | HTTP 200, status=INELIGIBLE, ineligibility_reasons non-empty |
| AC-SYS-003 | Deployment Eligibility API returns INELIGIBLE for a RETIRED version | Automated E2E | HTTP 200, status=INELIGIBLE, code=VERSION_RETIRED |
| AC-SYS-004 | Stage transition from Development to Validation is blocked without required artifacts | Automated E2E | HTTP 422, error code=MISSING_REQUIRED_ARTIFACTS |
| AC-SYS-005 | COI enforcement blocks a development team member from submitting validation test results | Automated E2E | HTTP 403, error code=CONFLICT_OF_INTEREST |
| AC-SYS-006 | Audit log entry is created for every stage transition | Automated + Manual | Audit entry exists with correct fields within 1s of transition |
| AC-SYS-007 | Audit log entries cannot be modified or deleted via API | Security test | PUT/DELETE /audit/... returns 405 Method Not Allowed |
| AC-SYS-008 | MLflow experiment runs are ingested within 60 seconds of creation on tracked tracking server | Integration test | Run appears in MLM UI within 60s of MLflow log_run call |
| AC-SYS-009 | Monitoring alert fires within 90 seconds of threshold breach metric being ingested | Integration test | Alert record created within 90s of ingest API POST |
| AC-SYS-010 | DES continues serving cached responses during Aurora primary failure (FAIL_OPEN mode) | DR test | Eligibility responses continue during simulated DB failover |
| AC-SYS-011 | New model project creation notifies all registered stakeholders | Automated E2E | Notification dispatch records created for all stakeholders |
| AC-SYS-012 | System supports 500 concurrent users with API P95 < 500ms | Load test | k6 load test: 500 VUs, 10-min sustained, P95 < 500ms, error rate < 0.1% |
| AC-SYS-013 | Deployment Eligibility API handles 500 req/sec with P95 < 150ms | Load test | k6 load test: 500 RPS, 5-min sustained, P95 < 150ms |
| AC-SYS-014 | A user without Model Validator role cannot approve a validation gate | Security test | HTTP 403 on approval attempt by non-validator |
| AC-SYS-015 | Full model lifecycle (Inception → Retirement) completes with correct state transitions and full audit trail | E2E regression | All 7 stages transition correctly; audit log contains entry per transition |

### 13.2 Integration Acceptance Criteria

| ID | Criterion | Pass Condition |
|----|-----------|----------------|
| AC-INT-001 | SageMaker Training Job metrics are visible in MLM Development stage panel | Training job metrics appear in UI within 60s |
| AC-INT-002 | SageMaker Model Monitor violation triggers MLM CRITICAL alert | Alert created in MLM within 90s of CloudWatch alarm |
| AC-INT-003 | Databricks MLflow experiment runs sync correctly to MLM | Runs appear in MLM within 60s |
| AC-INT-004 | GitHub Actions deployment event updates MLM Implementation stage | Deployment record status updates within 30s of webhook receipt |
| AC-INT-005 | LangSmith trace metrics appear in MLM GenAI monitoring dashboard | Metrics visible within 5 minutes of LangSmith sync |

---

## 14. Requirements Traceability Matrix

The following matrix traces System Requirements back to Functional Requirements (FRD) and forward to test coverage.

| SRD Req ID | FRD Req ID | Description | Component | Test Coverage |
|------------|-----------|-------------|-----------|---------------|
| SRD-FE-001 | REQ-UI-001 | SPA with no backend logic in frontend | Frontend | Unit + E2E |
| SRD-API-001 | REQ-IMP-001 | Versioned API endpoints | API Gateway | Contract test |
| SRD-API-004 | REQ-AUD-001 | Request ID in all audit logs | API Gateway | Automated |
| SRD-WFE-001 | REQ-WFE-007 | Workflow definition versioning | WFE | Unit + Integration |
| SRD-WFE-002 | REQ-WFE-003 | Sequential approval support | WFE | E2E |
| SRD-WFE-003 | REQ-WFE-004 | SLA monitoring + escalation | WFE + Scheduler | Integration |
| SRD-REG-001 | REQ-VER-002 | Atomic version registration | Registry | Unit + Integration |
| SRD-REG-002 | REQ-VER-002 | Immutability after VALIDATED status | Registry + DB | Security + DB test |
| SRD-DES-001 | REQ-IMP-001 | DES independent from write DB | DES | Architecture review |
| SRD-DES-002 | REQ-IMP-001 | DES cache prewarming | DES | Integration |
| SRD-DES-005 | NFR-AVL-001 | Multi-region DES failover | DES + Infra | DR drill |
| SRD-AUD-001 | REQ-AUD-001 | Audit written in same transaction | Audit Service | Integration |
| SRD-AUD-002 | REQ-AUD-004 | Hash-chained audit records | Audit Service | Unit |
| SRD-AUD-003 | REQ-AUD-004 | Row-level security on audit table | DB | Security test |
| SRD-INT-002 | REQ-SEC-004 | No plaintext credentials in DB | Integration Layer | Security audit |
| SRD-MIP-001 | REQ-MON-004 | Ingest API < 50ms | Ingest API | Load test |
| SRD-SEC-001 | REQ-SEC-003 | RBAC at API layer | RBAC / OPA | Security test |
| SRD-SEC-003 | REQ-SEC-003 | OPA sidecar for policy eval | OPA | Architecture review |
| SRD-DB-001 | REQ-AUD-004 | Audit table write-only trigger | DB | DB unit test |
| SRD-DB-002 | REQ-VER-002 | Version field immutability trigger | DB | DB unit test |
| SRD-CICD-002 | REQ-SEC-010 | Critical CVE blocks pipeline | CI/CD | Pipeline test |

---

## 15. Assumptions & Dependencies

### 15.1 Assumptions

| ID | Assumption | Risk if Invalid |
|----|-----------|----------------|
| A-001 | Customer environments have an OIDC/SAML-compatible identity provider | MLM cannot be deployed without SSO — local auth fallback would require significant additional development |
| A-002 | Customers use AWS as the primary cloud platform for ML workloads | Integration adapters prioritize AWS services; Azure/GCP adapters are secondary priority |
| A-003 | Customers' ML development platforms expose an MLflow-compatible REST API | Non-MLflow platforms require custom adapter development outside standard scope |
| A-004 | Artifact files (model weights, datasets) are stored in S3 or ADLS — MLM stores URIs only | If customers expect MLM to store large binary files directly, storage architecture must change |
| A-005 | Monitoring platforms can push metrics to MLM via HTTP — pull-based collection is not in scope | Customers using monitoring systems that cannot push (e.g., on-prem systems without egress) require additional integration work |
| A-006 | Network connectivity exists between MLM deployment and customer ML platforms | Air-gapped environments require a different deployment topology |
| A-007 | Customers will provision and manage their own database instances in their cloud account | SaaS-mode with shared database requires multi-tenancy schema isolation work |

### 15.2 External Dependencies

| Dependency | Version / Spec | Risk | Mitigation |
|------------|---------------|------|------------|
| MLflow REST API | v2.0+ | Breaking changes in future MLflow versions could break experiment sync | Pin adapter to MLflow API v2.0 contract; test against MLflow 2.x releases |
| AWS SageMaker Boto3 API | Latest stable | AWS API deprecations | Use stable Boto3 resource APIs; monitor AWS SDK changelog |
| Databricks REST API | 2.0 | Databricks API versioning changes | Use versioned Databricks REST API; monitor deprecation notices |
| FastAPI | 0.100+ | FastAPI major version changes | Pin in requirements.txt; test upgrades in staging |
| Aurora PostgreSQL | 15.x | PostgreSQL major version upgrade | Use AWS-managed Aurora; schedule upgrades with testing |
| OPA (Open Policy Agent) | 0.57+ | Policy language (Rego) changes | Pin OPA version; test policy evaluation on upgrade |

---

## 16. Risks & Mitigations

| ID | Risk | Probability | Impact | Mitigation |
|----|------|-------------|--------|------------|
| R-001 | DES outage blocks all customer deployments if FAIL_CLOSED configured | Low | Critical | Multi-region DES deployment; FAIL_OPEN as default with policy override option; caching reduces DB dependency |
| R-002 | MLflow API changes break experiment sync for a platform version | Medium | High | Version-pin API contracts; integration tests run against multiple MLflow versions in CI |
| R-003 | Audit log hash chain corruption due to concurrent inserts | Low | High | Serialize audit inserts via advisory lock; periodic hash chain integrity verification job |
| R-004 | Monitoring ingest SQS backlog during large-scale customer adoption | Medium | Medium | Auto-scaling consumer group; DLQ with alerting; backpressure signaling on ingest API |
| R-005 | OPA policy evaluation latency impacts API response times | Low | Medium | OPA sidecar (in-process); policy caching; benchmark on policy complexity growth |
| R-006 | Customer IAM misconfiguration causes SageMaker integration failures | High | Medium | Integration health check UI; clear IAM policy templates in documentation; adapter error messages include remediation hints |
| R-007 | GenAI evaluation framework APIs change rapidly (LangSmith, Langfuse) | High | Medium | Thin adapter layer per framework; monitor changelog; design ingest API to accept generic metric payloads as fallback |
| R-008 | Regulatory requirements (SR 11-7, EU AI Act) evolve post-launch | Medium | High | Modular compliance report templates; configurable validation test plan requirements; regulatory scope as configuration |

---

*End of System Requirements Document*  
*MLM Platform — SRD v1.0*
