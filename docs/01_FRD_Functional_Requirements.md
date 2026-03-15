# MLOps Model Lifecycle Management System — Detailed Requirements

**Document Version:** 1.0 (with CWE addendum supersessions — see below)  
**Status:** Draft  
**Classification:** Internal  

---

> ## ⚠ Partial Supersession Notice
>
> **Superseded by:** `MLM-CWE-001` — Configurable Workflow Engine Addendum  
> **Date:** 2024-Q4  
>
> The following sections of this document have been **partially or fully superseded** by the CWE addendum. The original content is retained for historical reference but should not be used as the authoritative specification for the areas noted:
>
> | Section | Status | Superseded By |
> |---------|--------|---------------|
> | Section 4 — Lifecycle Stage Definitions & Workflow | **Partially superseded** | CWE Section 5 (stage ordering, transition rules now template-driven) |
> | Section 5–11 — Individual Stage Requirements | **Extended** | CWE Section 4 (Base Templates define stage attributes and approval levels) |
> | Section 17 — Workflow Engine Requirements | **Fully superseded** | CWE Sections 5, 6, 7, 9 |
>
> All other sections remain authoritative. For the current workflow engine specification, refer to `MLM-CWE-001`.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Overview](#2-system-overview)
3. [Actors & Roles](#3-actors--roles)
4. [Lifecycle Stage Definitions & Workflow](#4-lifecycle-stage-definitions--workflow)
5. [Stage 1 — Model Inception](#5-stage-1--model-inception)
6. [Stage 2 — Model Development](#6-stage-2--model-development)
7. [Stage 3 — Model Validation](#7-stage-3--model-validation)
8. [Stage 4 — Model Implementation](#8-stage-4--model-implementation)
9. [Stage 5 — Model Monitoring](#9-stage-5--model-monitoring)
10. [Stage 6 — Model Versioning](#10-stage-6--model-versioning)
11. [Stage 7 — Model Retirement](#11-stage-7--model-retirement)
12. [Cross-Cutting Requirements](#12-cross-cutting-requirements)
13. [Integration Requirements](#13-integration-requirements)
14. [Non-Functional Requirements](#14-non-functional-requirements)
15. [Security & Compliance Requirements](#15-security--compliance-requirements)
16. [Data Model](#16-data-model)
17. [Workflow Engine Requirements](#17-workflow-engine-requirements)
18. [UI/UX Requirements](#18-uiux-requirements)
19. [API Requirements](#19-api-requirements)
20. [Glossary](#20-glossary)

---

## 1. Executive Summary

The **Model Operational Application (MOA)** is an enterprise-grade MLOps governance and orchestration platform designed to manage the complete lifecycle of machine learning models — from initial project inception through active deployment to eventual retirement. The system serves as the authoritative system of record for all model assets, enforcing standardized workflows, gating mechanisms, and auditability at every stage. It integrates natively with third-party development platforms (SageMaker, Databricks, MLflow), deployment targets (SageMaker Endpoints, Kubernetes, cloud functions), and monitoring solutions, while providing its own native workflow engine for lifecycle progression approvals.

---

## 2. System Overview

### 2.1 Purpose

The MOA platform will:
- Provide a **centralized registry** for all model projects across the organization.
- Enforce a **governed lifecycle workflow** with mandatory stage gates, approvals, and documentation checkpoints.
- Integrate with existing ML development and deployment platforms via standardized protocols (primarily MLflow Tracking API).
- Ensure that **only validated, approved model versions** are eligible for promotion to production deployment.
- Provide **audit trails**, role-based access control (RBAC), and compliance reporting at every stage.

### 2.2 Lifecycle Overview

```
┌──────────────┐    ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│  1. Inception │───▶│  2. Development  │───▶│  3. Validation   │───▶│ 4. Implementation│
└──────────────┘    └──────────────────┘    └──────────────────┘    └──────────────────┘
                                                                               │
┌──────────────┐    ┌──────────────────┐    ┌──────────────────┐              │
│ 7. Retirement │◀───│  6. Versioning   │◀───│  5. Monitoring   │◀────────────┘
└──────────────┘    └──────────────────┘    └──────────────────┘
```

Each stage has:
- **Entry criteria** — conditions that must be met before the stage begins.
- **Stage activities** — tasks, integrations, and documentation required within the stage.
- **Exit criteria (stage gates)** — approval and validation checkpoints required to advance.
- **Rollback conditions** — conditions that trigger regression to a prior stage.

---

## 3. Actors & Roles

| Role | Description | Key Permissions |
|------|-------------|-----------------|
| **Model Owner** | Business stakeholder who initiates and owns the model project | Create projects, approve Inception, trigger Retirement |
| **Data Scientist** | Develops and trains models | Update Development stage, submit for Validation |
| **ML Engineer** | Builds pipelines, manages deployment | Manage Implementation, configure integrations |
| **Model Validator** | Independent reviewer performing validation | Conduct validation tests, approve/reject Validation stage |
| **Risk Officer** | Reviews model risk documentation | Approve risk assessments, override governance flags |
| **MLOps Engineer** | Manages platform infrastructure and integrations | Configure platform integrations, manage monitoring rules |
| **Admin** | Platform administrator | Manage users, roles, configurations |
| **Auditor** | Read-only access for compliance review | Read all records, export audit reports |

---

## 4. Lifecycle Stage Definitions & Workflow

### 4.1 Stage Transition Rules

- Stage transitions are **unidirectional** by default (Inception → Development → ... → Retirement) unless an explicit rollback is triggered.
- Each stage transition requires **at least one approval** from a role authorized for that gate.
- A model may be **version-branched** at Development or later stages to produce a new version without re-starting Inception.
- **Only models in `Approved` state at the Validation stage** may progress to Implementation.
- The platform enforces **deployment blockers** — deployment targets must query the MOA API to confirm a model version's eligibility before deployment proceeds.

### 4.2 Stage Status Values

Each model project stage carries one of the following statuses:

| Status | Description |
|--------|-------------|
| `NOT_STARTED` | Stage not yet activated |
| `IN_PROGRESS` | Stage is actively being worked |
| `PENDING_REVIEW` | Submitted for gate review/approval |
| `APPROVED` | Stage gate passed; eligible for next stage |
| `REJECTED` | Stage gate failed; rework required |
| `ON_HOLD` | Stage paused by authorized user |
| `ROLLED_BACK` | Returned from a later stage |
| `COMPLETED` | Stage fully completed and locked |

### 4.3 Workflow Transition Diagram

```
[NOT_STARTED] → [IN_PROGRESS] → [PENDING_REVIEW] → [APPROVED] → Trigger Next Stage
                      ↑                  │
                      └──── [REJECTED] ──┘  (rework loop)
                      
[IN_PROGRESS] → [ON_HOLD] → [IN_PROGRESS]  (resume)
[APPROVED]    → [ROLLED_BACK]              (triggered from later stage)
[COMPLETED]   → immutable (audit-locked)
```

---

## 5. Stage 1 — Model Inception

### 5.1 Purpose
Capture the business problem, intended use case, risk classification, data landscape, and initial feasibility of the proposed model.

### 5.2 Entry Criteria
- Authenticated user with `Model Owner` or `Data Scientist` role.
- No prior active project for the same use case (duplicate detection required).

### 5.3 Required Artifacts

| Artifact | Description | Mandatory |
|----------|-------------|-----------|
| **Project Charter** | Business problem statement, objectives, success KPIs | Yes |
| **Use Case Description** | Detailed description of intended model use and consumers | Yes |
| **Data Availability Assessment** | Sources, volumes, access rights, PII indicators | Yes |
| **Risk Classification** | Low / Medium / High / Critical — drives validation rigor | Yes |
| **Stakeholder Registry** | Names and roles of all project stakeholders | Yes |
| **Regulatory & Compliance Scope** | Applicable regulations (FCRA, ECOA, SR 11-7, GDPR, etc.) | Yes |
| **Preliminary Feasibility Assessment** | High-level technical approach and feasibility notes | Yes |
| **Budget & Resource Estimate** | Compute, licensing, personnel estimates | No |

### 5.4 System Behavior

- **REQ-INC-001:** The system shall provide a structured project creation wizard capturing all mandatory Inception artifacts.
- **REQ-INC-002:** The system shall perform duplicate use-case detection using name similarity and tag matching, surfacing potential duplicates before project creation is finalized.
- **REQ-INC-003:** The system shall auto-assign a globally unique **Model ID** (e.g., `MOD-2024-00421`) upon project creation.
- **REQ-INC-004:** The system shall assign a **Risk Tier** (1–4) based on rule-based evaluation of the Risk Classification input (e.g., Critical = Tier 1), which governs validation requirements in Stage 3.
- **REQ-INC-005:** The system shall automatically notify all registered stakeholders upon project creation.
- **REQ-INC-006:** The system shall allow tagging of projects with organizational taxonomy (business domain, product line, regulatory flag).
- **REQ-INC-007:** The system shall support attachment of supporting documents (PDF, DOCX, XLSX) up to 50 MB per file.

### 5.5 Stage Gate — Inception Approval

- **Approver Role:** Model Owner (mandatory) + Risk Officer (if Risk Tier 1 or 2).
- **Gate Checklist:** All mandatory artifacts uploaded; risk tier assigned; stakeholder registry populated.
- **Outcome on Approval:** Stage transitions to `COMPLETED`; Stage 2 (Development) is activated to `IN_PROGRESS`.
- **Outcome on Rejection:** Stage returns to `IN_PROGRESS` with reviewer comments attached.

---

## 6. Stage 2 — Model Development

### 6.1 Purpose
Manage the technical development, experimentation, feature engineering, and training of the model, with full integration to external development platforms.

### 6.2 Entry Criteria
- Stage 1 in `COMPLETED` state.
- Development platform configuration linked (SageMaker project ARN, Databricks workspace URL, or MLflow tracking URI).

### 6.3 Required Artifacts

| Artifact | Description | Mandatory |
|----------|-------------|-----------|
| **Development Plan** | Algorithms considered, feature strategy, train/test split methodology | Yes |
| **Data Lineage Report** | Source datasets, transformations, version references | Yes |
| **Experiment Log** | All experiment runs tracked (auto-ingested via MLflow) | Yes |
| **Training Dataset Snapshot** | Reference pointer to training data (S3/ADLS path + hash) | Yes |
| **Model Card (Draft)** | Initial draft capturing model purpose, known limitations | Yes |
| **Code Repository Link** | GitHub/GitLab/Bitbucket repo URL + branch/tag reference | Yes |
| **Hyperparameter Configuration** | Final selected hyperparameters and tuning log | Yes |
| **Performance Benchmarks** | Training/validation metrics against defined baselines | Yes |
| **Bias & Fairness Assessment (Draft)** | Preliminary fairness testing results | Yes if Risk Tier 1–2 |

### 6.4 Platform Integration Requirements

#### 6.4.1 MLflow Integration (Primary)
- **REQ-DEV-001:** The system shall integrate with MLflow Tracking Server (self-hosted or managed) via the MLflow REST API to auto-ingest experiment runs, metrics, parameters, and artifacts.
- **REQ-DEV-002:** The system shall support configuration of multiple MLflow tracking URIs, enabling integration with SageMaker Experiments (which exposes an MLflow-compatible API), Databricks Managed MLflow, and self-hosted MLflow instances simultaneously.
- **REQ-DEV-003:** The system shall poll or receive webhook events from the configured MLflow server whenever a new run is logged under the linked experiment ID.
- **REQ-DEV-004:** The system shall display experiment run comparisons (metrics over runs, parameter sweeps) natively within the MOA UI, sourced from MLflow.
- **REQ-DEV-005:** The system shall allow a Data Scientist to **register a specific MLflow run** as the "candidate model" to progress through subsequent stages.
- **REQ-DEV-006:** Upon candidate model selection, the system shall snapshot the MLflow run metadata (run ID, artifact URI, metrics, parameters, model signature) and store it immutably in the MOA model registry.

#### 6.4.2 SageMaker Integration
- **REQ-DEV-010:** The system shall integrate with Amazon SageMaker via AWS SDK to list SageMaker Experiments and Training Jobs associated with the project's configured SageMaker project ARN.
- **REQ-DEV-011:** The system shall support SageMaker Model Registry as an optional downstream target — upon candidate selection, the system may auto-register the model package in a configured SageMaker Model Package Group.
- **REQ-DEV-012:** The system shall display SageMaker Training Job logs, metrics, and status within the MOA Development stage panel.

#### 6.4.3 Databricks Integration
- **REQ-DEV-015:** The system shall integrate with Databricks via the Databricks REST API and MLflow (Databricks Managed MLflow) to list experiments and runs from a configured Databricks workspace.
- **REQ-DEV-016:** The system shall support Databricks Unity Catalog model registration as an optional target upon candidate model selection.

#### 6.4.4 Generic MLflow-Compatible Platforms
- **REQ-DEV-020:** Any platform that exposes the standard MLflow Tracking REST API shall be supported by providing the tracking URI and optional authentication credentials (token or basic auth) in the project configuration.

### 6.5 System Behavior

- **REQ-DEV-030:** The system shall maintain a **Development Log** capturing all actions, comments, and artifact uploads with user attribution and timestamps.
- **REQ-DEV-031:** The system shall enforce that only one **candidate model run** is active per project at any time (selecting a new candidate supersedes the prior, with the prior archived).
- **REQ-DEV-032:** The system shall compute and display a **Development Completeness Score** based on completion of all required artifacts, surfacing outstanding items in a checklist.
- **REQ-DEV-033:** The system shall notify the Model Owner and assigned Validators when the Data Scientist submits the development stage for gate review.

### 6.6 Stage Gate — Development Approval

- **Approver Role:** Model Owner (sign-off that development meets business requirements).
- **Gate Checklist:** Candidate model registered; all mandatory artifacts uploaded; baseline performance criteria met (configurable threshold per project); code repo linked.
- **Outcome on Approval:** Stage transitions to `COMPLETED`; Stage 3 (Validation) is activated.
- **Outcome on Rejection:** Stage returns to `IN_PROGRESS`; MLflow experiments may continue; new candidate model may be selected.

---

## 7. Stage 3 — Model Validation

### 7.1 Purpose
Independent, structured validation of the candidate model against technical, business, fairness, and regulatory criteria by a validation team that is organizationally independent from the development team.

### 7.2 Entry Criteria
- Stage 2 in `COMPLETED` state.
- Candidate model registered with immutable snapshot.
- Validation team assigned (at least one assigned Validator with no development role on the project).

### 7.3 Required Validation Tests

The system shall support configuration of a **Validation Test Plan** composed of the following test categories:

| Test Category | Description | Required for Risk Tier |
|---------------|-------------|------------------------|
| **Conceptual Soundness Review** | Assessment of theoretical basis, assumptions, and methodology | All Tiers |
| **Performance Testing** | Evaluation of accuracy, AUC, RMSE, F1, or other task-specific metrics on holdout/OOT data | All Tiers |
| **Stability Testing** | Performance consistency across time periods, data slices, or segments | Tier 1–3 |
| **Sensitivity Analysis** | Impact of input variable perturbations on model output | Tier 1–3 |
| **Bias & Fairness Testing** | Disparate impact, equalized odds, demographic parity across protected classes | Tier 1–2 |
| **Explainability Testing** | SHAP/LIME feature importance analysis; compliance with explainability requirements | Tier 1–2 |
| **Adversarial Robustness** | Resistance to adversarial inputs | Tier 1 |
| **Data Quality Validation** | Validation dataset completeness, distribution vs. training data | All Tiers |
| **Regulatory Compliance Check** | Documentation completeness per applicable regulations (SR 11-7, GDPR Article 22, etc.) | All Tiers |
| **Replication Test** | Independent replication of key model outputs | Tier 1–2 |

### 7.4 System Behavior

- **REQ-VAL-001:** The system shall generate a **Validation Test Plan** from the project's Risk Tier and regulatory scope, pre-populating required test cases.
- **REQ-VAL-002:** Validators shall be able to record test results (Pass / Fail / Conditional Pass), attach supporting evidence (test scripts, notebooks, result files), and enter findings for each test case.
- **REQ-VAL-003:** The system shall prevent validation by any user who contributed to the Development stage of the same model project (conflict-of-interest enforcement).
- **REQ-VAL-004:** The system shall allow validators to raise **Model Findings** (Issues) with severity levels: Critical, Major, Minor, Informational.
- **REQ-VAL-005:** Critical and Major findings must have a documented **Remediation Plan** and resolution before the stage gate can be approved.
- **REQ-VAL-006:** The system shall generate a **Validation Summary Report** (PDF/HTML) auto-populated from all test results, findings, and metadata.
- **REQ-VAL-007:** The system shall support **re-validation workflows** — if Development is rolled back and a new candidate model is submitted, the system shall create a new validation cycle linked to the same project, carrying forward the test plan with findings reset.
- **REQ-VAL-008:** The system shall provide a **Validation Dashboard** showing: open findings by severity, test completion percentage, days in validation, and comparison of candidate model metrics vs. prior validated versions.
- **REQ-VAL-009:** The system shall support external validation team access via a dedicated Validator portal with scoped permissions (view candidate model artifacts; cannot modify Development records).

### 7.5 Stage Gate — Validation Approval

- **Approver Role:** Lead Validator (mandatory) + Risk Officer (if Risk Tier 1).
- **Gate Checklist:** All required test cases completed; zero unresolved Critical findings; all Major findings with accepted remediation plans; Validation Summary Report generated.
- **Outcome on Approval:** Model version is tagged with `VALIDATED` status in the MOA registry; Stage 4 (Implementation) is activated.
- **Outcome on Rejection:** Stage returns to Development (`ROLLED_BACK`); all validation findings attached; candidate model selection must be repeated.
- **Conditional Approval:** Supported — model may proceed to Implementation with documented conditions and a tracking remediation deadline.

---

## 8. Stage 4 — Model Implementation

### 8.1 Purpose
Manage controlled deployment of the validated model to target execution environments, including pre-production testing, production promotion, and deployment configuration management.

### 8.2 Entry Criteria
- Stage 3 in `COMPLETED` (or `APPROVED` with conditions) state.
- Model version carries `VALIDATED` registry tag.
- Deployment target configured and reachable.

### 8.3 Deployment Targets Supported

| Platform | Mechanism | Notes |
|----------|-----------|-------|
| **Amazon SageMaker Endpoint** | SageMaker SDK / Boto3 API | Real-time inference; batch transform |
| **Amazon SageMaker Serverless** | SageMaker Serverless Inference API | For spiky / infrequent workloads |
| **Databricks Model Serving** | Databricks REST API | Real-time serving via Unity Catalog |
| **Kubernetes (via Seldon / KServe)** | Kubernetes API / Helm | Self-hosted inference clusters |
| **Azure ML Endpoint** | Azure ML SDK | Optional; pluggable adapter |
| **Custom REST API** | Webhook + deployment pipeline trigger | Generic adapter for custom platforms |
| **Batch Scoring Pipeline** | SageMaker Processing / Databricks Jobs | Scheduled batch inference |

### 8.4 Deployment Eligibility Enforcement

- **REQ-IMP-001:** The system shall expose a **Deployment Eligibility API** endpoint that deployment pipelines, CI/CD systems, and deployment platforms can query before executing a deployment. The API shall return:
  - `ELIGIBLE` — model version is validated and approved for the target environment.
  - `INELIGIBLE` — reasons enumerated (not validated, validation expired, version superseded, retirement initiated).
  - `CONDITIONAL` — eligible with documented conditions; calling system must acknowledge conditions.
- **REQ-IMP-002:** The system shall support **environment-specific approvals** — a model version may be approved for staging but require an additional gate for production promotion.
- **REQ-IMP-003:** Deployment events (deploy initiated, succeeded, failed, rolled back) shall be posted back to the MOA via API or webhook, updating the Implementation stage record.
- **REQ-IMP-004:** The system shall maintain a **Deployment Registry** within the project, recording: deployment target, environment (staging/production), deployment timestamp, model version, deployed by, and deployment configuration snapshot.
- **REQ-IMP-005:** The system shall enforce that **only the current approved model version** is eligible for new deployments. If a newer validated version exists, deployments of the prior version shall require explicit override with justification.

### 8.5 Implementation Workflow

```
[Validated Model] → [Deployment Plan Creation] → [Staging Deployment]
       → [Staging Smoke Test] → [Production Promotion Gate]
       → [Production Deployment] → [Post-Deployment Verification]
       → [Stage 4 COMPLETED] → [Stage 5 Activated]
```

### 8.6 Required Artifacts

| Artifact | Description | Mandatory |
|----------|-------------|-----------|
| **Deployment Plan** | Target environment, rollout strategy (blue/green, canary, direct), rollback plan | Yes |
| **Infrastructure Configuration** | Instance types, auto-scaling rules, network configuration | Yes |
| **Integration Test Results** | Results of downstream system integration tests in staging | Yes |
| **Smoke Test Results** | Basic functional verification in target environment | Yes |
| **Runbook** | Operational runbook for model endpoint management | Yes |
| **Rollback Procedure** | Documented steps for emergency rollback | Yes |

### 8.7 System Behavior

- **REQ-IMP-010:** The system shall provide a **Deployment Configuration Builder** UI allowing ML Engineers to configure SageMaker endpoint properties (instance type, variant weights, data capture configuration) or equivalent properties for other platforms, stored as versioned configuration in MOA.
- **REQ-IMP-011:** The system shall allow triggering of deployment pipelines (GitHub Actions, AWS CodePipeline, Jenkins) via webhook from the MOA Implementation stage UI.
- **REQ-IMP-012:** The system shall support **canary deployment** tracking — recording traffic split percentages and allowing promotion to full traffic with a separate approval.
- **REQ-IMP-013:** Upon production deployment success, the system shall automatically activate **Stage 5 (Monitoring)** in parallel (Implementation remains COMPLETED; Monitoring begins IN_PROGRESS).

### 8.8 Stage Gate — Production Promotion

- **Approver Role:** ML Engineer + Model Owner.
- **Gate Checklist:** Staging deployment successful; smoke tests passed; integration tests passed; deployment plan and rollback procedure documented.
- **Outcome on Approval:** Production deployment authorized; stage progresses to `COMPLETED`.
- **Outcome on Rejection:** Deployment blocked; returned to staging resolution.

---

## 9. Stage 5 — Model Monitoring

### 9.1 Purpose
Continuous post-deployment monitoring of model performance, data drift, concept drift, prediction quality, infrastructure health, and business KPIs, with automated alerting and governed response workflows.

### 9.2 Entry Criteria
- Stage 4 `COMPLETED` (production deployment confirmed).
- Monitoring configuration defined (at least one monitor type active).

### 9.3 Monitoring Types

| Monitor Type | Description | Integration Options |
|--------------|-------------|---------------------|
| **Data Quality Monitor** | Missing values, schema violations, out-of-range inputs | SageMaker Model Monitor, custom |
| **Data Drift Monitor** | Statistical shift in input feature distributions (KS test, PSI) | SageMaker Model Monitor, Evidently AI, custom |
| **Concept Drift Monitor** | Shift in relationship between inputs and target | Evidently AI, Nannyml, custom |
| **Model Performance Monitor** | Degradation in accuracy, AUC, precision/recall over time | SageMaker Model Monitor, MLflow, custom |
| **Prediction Bias Monitor** | Emerging bias in model predictions vs. ground truth | SageMaker Clarify, custom |
| **Infrastructure Monitor** | Latency, error rate, throughput, resource utilization | CloudWatch, Datadog, Prometheus |
| **Business KPI Monitor** | Business outcome metrics linked to model outputs | Custom webhook / dashboard integration |

### 9.4 Integration Requirements

- **REQ-MON-001:** The system shall support integration with **Amazon SageMaker Model Monitor** by consuming CloudWatch metrics and SageMaker Monitor schedule outputs via CloudWatch Logs and S3 baseline comparison results.
- **REQ-MON-002:** The system shall support integration with **Evidently AI** (open-source) via its API for data drift and model performance reports.
- **REQ-MON-003:** The system shall support integration with **Datadog** for infrastructure metrics via Datadog API (metrics query endpoint).
- **REQ-MON-004:** The system shall support a **Custom Monitor Webhook** — any monitoring platform can push metric payloads to a MOA ingest endpoint, which maps the payload to the correct model project and monitor type.
- **REQ-MON-005:** The system shall support a **Monitoring Configuration Builder** allowing MLOps Engineers to define: monitor type, integration source, metric thresholds, evaluation frequency, and alerting rules.

### 9.5 Alerting & Response Workflow

- **REQ-MON-010:** The system shall define configurable **Alert Severity Levels**: `INFO`, `WARNING`, `CRITICAL`.
- **REQ-MON-011:** Upon alert trigger, the system shall:
  - Log the alert with timestamp, metric values, threshold breached, and model version.
  - Notify configured recipients via email, Slack webhook, or PagerDuty.
  - Create an **Incident Record** in MOA linked to the model project.
- **REQ-MON-012:** `CRITICAL` alerts shall trigger a mandatory **Response Workflow** with the following steps:
  1. Incident acknowledgment (ML Engineer, within SLA).
  2. Root cause investigation (documented in Incident Record).
  3. Remediation action selection: Retrain (→ triggers new Development cycle), Rollback (→ triggers prior version redeployment), Override (→ documented justification + Risk Officer approval).
  4. Incident closure with resolution notes.
- **REQ-MON-013:** The system shall maintain a **Monitoring Dashboard** per model project showing time-series charts for all active monitors, alert history, and incident log.
- **REQ-MON-014:** The system shall support **Monitoring Baselines** — statistical baselines computed from training/validation data against which drift is measured. Baselines shall be versioned and linked to the model version.
- **REQ-MON-015:** The system shall track **Ground Truth Feedback** — when actual outcomes are available post-prediction, they may be uploaded to MOA and used to compute realized performance metrics.
- **REQ-MON-016:** Performance degradation beyond a configurable threshold shall automatically recommend (and optionally trigger) a new Development cycle, creating a child version project.

### 9.6 Monitoring Continuity

- Monitoring is **continuous** and does not "complete" — it runs for the lifetime of the deployed model.
- Monitoring transitions to `ON_HOLD` state when a model is retired (Stage 7) or superseded.
- A new validated model version reuses the existing monitoring configuration by default (with option to modify).

---

## 10. Stage 6 — Model Versioning

### 10.1 Purpose
Manage the creation, tracking, and lifecycle governance of multiple model versions within a single model project, ensuring strict version control of which model versions are eligible for deployment at any given time.

### 10.2 Version Taxonomy

```
Model Project (MOD-2024-00421)
 └── Version 1.0 (Initial production model)
 └── Version 1.1 (Minor retrain — same architecture)
 └── Version 2.0 (Major architecture change)
 └── Version 2.1 (Bias remediation patch)
```

### 10.3 Version Types

| Type | Trigger | Versioning Increment |
|------|---------|----------------------|
| **Major Version** | Significant architecture change, new feature set, fundamental methodology change | X.0 |
| **Minor Version** | Retrain on new data with same architecture; hyperparameter changes | x.Y |
| **Patch Version** | Bug fix, threshold adjustment, calibration update | x.y.Z |

### 10.4 System Behavior

- **REQ-VER-001:** The system shall assign version numbers automatically using semantic versioning (MAJOR.MINOR.PATCH) based on the version type selected by the submitter.
- **REQ-VER-002:** Each version shall be an **immutable record** — once a version is registered, its linked MLflow run, training data snapshot, and validation results cannot be modified. Corrections must produce a new version.
- **REQ-VER-003:** The system shall maintain a **Version Lineage Graph** showing the parent-child relationships between versions, including which runs triggered a new version (e.g., retraining triggered by monitoring alert).
- **REQ-VER-004:** Each version shall carry an independent lifecycle status: `IN_DEVELOPMENT`, `VALIDATED`, `DEPLOYED`, `SUPERSEDED`, `RETIRED`.
- **REQ-VER-005:** When a new version is deployed to production, the prior production version shall automatically transition to `SUPERSEDED` status.
- **REQ-VER-006:** The Deployment Eligibility API (REQ-IMP-001) shall enforce that:
  - Only versions with status `VALIDATED` or `DEPLOYED` are eligible for new deployments.
  - `SUPERSEDED` versions may not be deployed without explicit override + approval.
  - `RETIRED` versions are permanently blocked from deployment.
- **REQ-VER-007:** The system shall allow **side-by-side version comparison** of metrics, parameters, validation results, and monitoring performance across any two versions.
- **REQ-VER-008:** A **New Version Workflow** shall allow an existing model project to fork a new version starting from Stage 2 (Development) while the current deployed version continues operating. The two version lifecycles run in parallel until the new version is promoted.
- **REQ-VER-009:** The system shall record **Version Promotion Events** — when a validated version is selected for production deployment, a promotion record is created with: version, environment, approver, timestamp, and rationale.
- **REQ-VER-010:** The system shall support configurable **Version Retention Policies** defining how many prior versions are retained in active registry vs. archived.

### 10.5 Model Registry

- The MOA Model Registry is the **authoritative store** for all model version metadata.
- External platforms (SageMaker Model Registry, Databricks Unity Catalog) may be used as secondary registries, but the MOA registry governs deployment eligibility.
- The MOA registry shall expose a machine-readable **Model Manifest** per version (JSON/YAML) containing: model ID, version, validation status, deployment targets, artifact URIs, expiry date, and applicable restrictions.

---

## 11. Stage 7 — Model Retirement

### 11.1 Purpose
Govern the controlled decommissioning of a model from production, ensuring all consumers are notified, monitoring is wound down, deployments are terminated, and all artifacts are archived according to retention policies.

### 11.2 Retirement Triggers

| Trigger | Initiator | Description |
|---------|-----------|-------------|
| **Supersession** | System (automatic) | A new approved major version replaces the current version |
| **Scheduled Retirement** | Model Owner | Pre-planned end-of-life date reached |
| **Emergency Retirement** | Risk Officer / Admin | Critical risk event requiring immediate decommission |
| **Regulatory Retirement** | Risk Officer | Regulatory mandate to retire the model |
| **Business Sunset** | Model Owner | Business use case no longer active |

### 11.3 Retirement Workflow

```
[Retirement Initiated] → [Retirement Plan Created] → [Stakeholder Notification]
    → [Consumer Transition Period] → [Deployment Decommission Gate]
    → [Deployments Terminated] → [Monitoring Deactivated]
    → [Artifact Archival] → [Retirement Complete]
```

### 11.4 System Behavior

- **REQ-RET-001:** The system shall require a **Retirement Plan** artifact documenting: reason for retirement, retirement date, impact assessment, successor model (if applicable), and consumer notification list.
- **REQ-RET-002:** Upon retirement initiation, the system shall automatically set the model version's deployment eligibility to `INELIGIBLE` in the Deployment Eligibility API, preventing any new deployments of the retiring version.
- **REQ-RET-003:** The system shall support a **Consumer Notification** workflow — registered consumers (downstream systems, teams) shall receive automated notification via email/Slack with retirement date and successor information.
- **REQ-RET-004:** The system shall enforce a configurable **Transition Period** (default: 30 days) during which the model remains operational but is flagged as `RETIRING`, allowing consumers to migrate. During this period, deployment eligibility returns `CONDITIONAL` with retirement notice.
- **REQ-RET-005:** At the end of the transition period, the system shall trigger a **Decommission Gate** requiring approval from the Model Owner to finalize termination of deployments.
- **REQ-RET-006:** The system shall support **automated deployment termination** — upon gate approval, a webhook/API call may be dispatched to the deployment platform (SageMaker, Databricks) to delete the endpoint/serving instance.
- **REQ-RET-007:** Upon full retirement, all model artifacts shall be transitioned to an **Archive Store** (configurable S3 bucket/path) per the organizational retention policy (minimum 7 years for Tier 1–2 models).
- **REQ-RET-008:** The system shall generate a **Model Retirement Report** containing: full lifecycle history, all versions produced, validation outcomes, production performance summary, incident history, and final retirement details.
- **REQ-RET-009:** Retired model records shall be **immutable and permanently retained** in MOA for audit purposes, even if underlying artifacts are archived.
- **REQ-RET-010:** Emergency retirement (Risk Officer) shall bypass the transition period and immediately set eligibility to `INELIGIBLE`, triggering immediate notifications and initiating rapid decommission workflow.

---

## 12. Cross-Cutting Requirements

### 12.1 Audit Trail

- **REQ-AUD-001:** Every state transition, approval, rejection, artifact upload, configuration change, and API call shall be recorded in an immutable audit log with: timestamp (UTC), user ID, action type, affected entity, before/after values, and IP address.
- **REQ-AUD-002:** Audit logs shall be exportable in JSON and CSV format, filterable by date range, user, model project, and action type.
- **REQ-AUD-003:** Audit logs shall be retained for a minimum of 10 years.
- **REQ-AUD-004:** Audit log entries shall be tamper-evident (hash-chained or stored in immutable storage).

### 12.2 Notifications

- **REQ-NOT-001:** The system shall support notification channels: email (SMTP), Slack (webhook), Microsoft Teams (webhook), and PagerDuty (for CRITICAL alerts).
- **REQ-NOT-002:** Users shall be able to configure per-project and per-role notification preferences.
- **REQ-NOT-003:** All notifications shall include a deep link to the relevant MOA project stage.

### 12.3 Search & Discovery

- **REQ-SRC-001:** The system shall provide a global model registry search with filters: business domain, risk tier, stage, deployment status, model owner, tags, and creation date range.
- **REQ-SRC-002:** The system shall expose all model metadata via a REST API for programmatic discovery.
- **REQ-SRC-003:** The system shall support full-text search across model descriptions, use case text, and artifact metadata.

---

## 13. Integration Requirements

### 13.1 Integration Architecture

All external integrations shall follow an **adapter pattern** with a plugin-style configuration, allowing new platforms to be added without core system changes.

### 13.2 Integration Configuration Model

Each integration adapter shall be configured with:
- **Platform Type** (enum: SAGEMAKER, DATABRICKS, MLFLOW_OSS, EVIDENTLY, DATADOG, GITHUB_ACTIONS, JENKINS, AZURE_ML, CUSTOM)
- **Authentication Config** (AWS Role ARN, API Token, OAuth2 credentials — stored encrypted in secrets manager)
- **Endpoint / URI**
- **Project-level mapping** (which MOA project maps to which external workspace/experiment/project)
- **Event subscriptions** (which events to ingest from the platform)
- **Action permissions** (whether MOA may trigger actions on the platform, e.g., delete endpoint)

### 13.3 Integration Summary Table

| Platform | Direction | Protocol | Use |
|----------|-----------|----------|-----|
| SageMaker Experiments | Inbound | Boto3 / MLflow API | Experiment run ingestion |
| SageMaker Model Registry | Outbound | Boto3 | Model package registration |
| SageMaker Endpoints | Outbound + Inbound | Boto3 | Deployment trigger + status |
| SageMaker Model Monitor | Inbound | CloudWatch / S3 | Monitoring metrics ingestion |
| SageMaker Clarify | Inbound | S3 report output | Bias monitoring |
| Databricks MLflow | Inbound | MLflow REST API | Experiment run ingestion |
| Databricks Model Serving | Outbound + Inbound | Databricks REST API | Deployment trigger + status |
| GitHub / GitLab | Outbound + Inbound | Webhooks / REST API | Pipeline triggers; deployment events |
| Evidently AI | Inbound | REST API / Report files | Drift and performance reports |
| Datadog | Inbound | Datadog Metrics API | Infrastructure metrics |
| Prometheus / Grafana | Inbound | Prometheus HTTP API | Infrastructure metrics |
| PagerDuty | Outbound | PagerDuty Events API v2 | CRITICAL alert escalation |
| Slack | Outbound | Incoming Webhooks | Notifications |
| JIRA | Outbound (optional) | JIRA REST API | Incident ticket creation |

---

## 14. Non-Functional Requirements

### 14.1 Performance

| Requirement | Target |
|-------------|--------|
| UI page load time (P95) | < 2 seconds |
| API response time (P95, read operations) | < 500 ms |
| API response time (P95, write/transition operations) | < 1 second |
| Experiment run ingestion latency (from MLflow event) | < 60 seconds |
| Deployment Eligibility API response time | < 200 ms |
| Concurrent users supported | 500+ |
| Model projects supported | 10,000+ |

### 14.2 Availability & Reliability

- Target uptime: **99.9%** (< 8.7 hours downtime/year).
- The Deployment Eligibility API shall target **99.99%** uptime as it is in the critical path of deployments.
- The system shall support **multi-region active-passive failover** for the Deployment Eligibility API.
- All data shall be persisted to a durable, replicated data store (e.g., Aurora PostgreSQL Multi-AZ).

### 14.3 Scalability

- The system shall support horizontal scaling of API and worker tiers.
- Monitoring metric ingestion shall be handled via an async message queue (e.g., SQS, Kafka) to decouple ingestion volume from API throughput.

### 14.4 Maintainability

- All integrations shall be implemented as independently deployable adapter modules.
- The system shall expose health check endpoints per component.
- Configuration changes (thresholds, notification rules) shall not require redeployment.

---

## 15. Security & Compliance Requirements

### 15.1 Authentication & Authorization

- **REQ-SEC-001:** The system shall support SSO via SAML 2.0 and OIDC (e.g., Okta, Azure AD, AWS IAM Identity Center).
- **REQ-SEC-002:** All API access shall require JWT bearer token authentication.
- **REQ-SEC-003:** RBAC shall be enforced at the API layer; no UI-only enforcement.
- **REQ-SEC-004:** Sensitive configuration (API keys, credentials) shall be stored in an integrated secrets manager (AWS Secrets Manager or HashiCorp Vault) — never in plain text in the database.

### 15.2 Data Security

- **REQ-SEC-010:** All data in transit shall use TLS 1.2+ encryption.
- **REQ-SEC-011:** All data at rest shall use AES-256 encryption.
- **REQ-SEC-012:** PII fields in uploaded artifacts shall be flagged via the Data Availability Assessment and subject to additional access controls.

### 15.3 Compliance

- **REQ-COM-001:** The system shall support generation of **SR 11-7 compliance documentation packages** from the model record (validation reports, performance benchmarks, model inventory).
- **REQ-COM-002:** The system shall maintain a **Model Inventory Report** exportable as CSV/PDF listing all models with: ID, name, use case, risk tier, current stage, owner, last validation date, and deployment status.
- **REQ-COM-003:** All approvals and rejections shall be digitally attributable (user ID + timestamp) and non-repudiable.

---

## 16. Data Model

### 16.1 Core Entities

```
ModelProject
├── id (UUID)
├── model_id (string, e.g., MOD-2024-00421)
├── name
├── description
├── business_domain
├── risk_tier (1–4)
├── current_stage (enum)
├── current_stage_status (enum)
├── owner_user_id
├── tags []
├── created_at, updated_at
└── ModelVersions []

ModelVersion
├── id (UUID)
├── model_project_id
├── version_string (MAJOR.MINOR.PATCH)
├── version_type (MAJOR | MINOR | PATCH)
├── status (IN_DEVELOPMENT | VALIDATED | DEPLOYED | SUPERSEDED | RETIRED)
├── mlflow_run_id
├── mlflow_tracking_uri
├── artifact_uri
├── training_data_reference
├── training_data_hash
├── metrics (JSON)
├── parameters (JSON)
├── model_signature (JSON)
├── parent_version_id (for lineage)
├── created_at
└── StageRecords []

StageRecord
├── id (UUID)
├── model_version_id
├── stage_type (enum: INCEPTION | DEVELOPMENT | VALIDATION | IMPLEMENTATION | MONITORING | VERSIONING | RETIREMENT)
├── status (enum)
├── started_at, completed_at
├── Artifacts []
├── Approvals []
├── Comments []
└── Findings []

Artifact
├── id (UUID)
├── stage_record_id
├── artifact_type (enum)
├── name
├── storage_uri
├── file_hash
├── uploaded_by
└── uploaded_at

Approval
├── id (UUID)
├── stage_record_id
├── approver_user_id
├── decision (APPROVED | REJECTED | CONDITIONAL)
├── conditions (text, if conditional)
├── comments
└── decided_at

Finding (Validation Issue)
├── id (UUID)
├── validation_stage_record_id
├── test_case_id
├── title
├── severity (CRITICAL | MAJOR | MINOR | INFORMATIONAL)
├── description
├── status (OPEN | IN_REMEDIATION | RESOLVED | ACCEPTED)
├── remediation_plan
└── resolved_at

MonitoringConfiguration
├── id (UUID)
├── model_version_id
├── monitor_type (enum)
├── integration_platform (enum)
├── configuration (JSON)
├── alert_thresholds (JSON)
├── is_active
└── created_at

MonitoringAlert
├── id (UUID)
├── monitoring_config_id
├── severity (INFO | WARNING | CRITICAL)
├── metric_name
├── metric_value
├── threshold_value
├── triggered_at
├── acknowledged_by
├── IncidentRecord_id
└── resolved_at

DeploymentRecord
├── id (UUID)
├── model_version_id
├── environment (STAGING | PRODUCTION)
├── platform (enum)
├── platform_resource_id (e.g., SageMaker endpoint name)
├── configuration_snapshot (JSON)
├── deployed_by
├── deployed_at
├── status (ACTIVE | TERMINATED | FAILED)
└── terminated_at

AuditLog
├── id (UUID)
├── timestamp
├── user_id
├── action_type
├── entity_type
├── entity_id
├── before_state (JSON)
├── after_state (JSON)
├── ip_address
└── hash (tamper-evident chain hash)
```

---

## 17. Workflow Engine Requirements

> ### ⚠ Section 17 — FULLY SUPERSEDED
> **Superseded by:** `MLM-CWE-001` — Configurable Workflow Engine, Sections 5, 6, 7, and 9  
> **Reason:** The original fixed workflow engine design has been replaced by a configurable template-driven workflow engine supporting multiple model types (Internal ML, GenAI/LLM, Vendor, Fine-Tuned) with admin-configurable stages, attribute schemas, and approval levels.  
> The content below is retained for historical reference only. **Do not use for implementation.**

### 17.1 Overview *(Superseded — see MLM-CWE-001)*

The MOA shall include an embedded **Workflow Engine** responsible for:
- Managing stage transitions and enforcing entry/exit criteria.
- Routing approval requests to the correct roles.
- Triggering automated actions (notifications, webhook calls, platform API calls) on state changes.
- Enforcing timeouts and SLA monitoring on approval tasks.

### 17.2 Requirements *(Superseded — see MLM-CWE-001)*

- **REQ-WFE-001:** Workflows shall be configurable per Risk Tier — Tier 1 workflows may require additional approvers or mandatory wait periods not required for Tier 4.
- **REQ-WFE-002:** The system shall support **parallel approval tasks** (e.g., both ML Engineer and Model Owner must approve independently before stage advances).
- **REQ-WFE-003:** The system shall support **sequential approval tasks** (e.g., Validator approves, then Risk Officer countersigns).
- **REQ-WFE-004:** The system shall enforce **approval SLAs** — configurable deadlines per stage gate, with escalation notifications when SLAs are breached.
- **REQ-WFE-005:** The system shall support **delegation** — an approver may delegate their approval authority to another authorized user for a defined period.
- **REQ-WFE-006:** The system shall support **automated transition triggers** — certain conditions (e.g., all tests passed, no open critical findings) may auto-approve a stage gate without manual action, subject to policy configuration.
- **REQ-WFE-007:** Workflow definitions shall be version-controlled — changes to workflow configuration do not retroactively affect in-progress stage records.
- **REQ-WFE-008:** The system shall provide a **Workflow Activity Feed** per project showing a chronological log of all workflow events.

---

## 18. UI/UX Requirements

### 18.1 Navigation Structure

```
Global Navigation
├── Dashboard (organization-wide model health overview)
├── Model Registry (searchable, filterable model project list)
├── My Tasks (pending approvals, open incidents assigned to me)
├── Integrations (platform configuration management)
├── Reports (compliance, inventory, audit exports)
└── Administration (users, roles, workflow configuration)

Project Navigation (within a model project)
├── Overview (current stage, key metrics, alerts)
├── Timeline (visual lifecycle progression)
├── Stage Panels (Inception | Development | Validation | Implementation | Monitoring | Versions | Retirement)
├── Audit Log
└── Settings
```

### 18.2 Key UI Requirements

- **REQ-UI-001:** The system shall display a **Visual Lifecycle Progress Bar** on every project overview, clearly indicating the current stage, completed stages, and pending gates.
- **REQ-UI-002:** The **Development Stage Panel** shall embed an MLflow experiment run table with sortable metric columns, parameter display, and a "Select as Candidate" action.
- **REQ-UI-003:** The **Validation Stage Panel** shall display a test case checklist with pass/fail indicators, finding severity badges, and inline evidence attachment.
- **REQ-UI-004:** The **Monitoring Dashboard** shall render time-series charts (using configurable time windows: 7d, 30d, 90d, custom) for all active monitor metrics.
- **REQ-UI-005:** The **Version Comparison View** shall support selecting any two versions and displaying a side-by-side diff of metrics, parameters, and validation outcomes.
- **REQ-UI-006:** All approval gates shall surface as **actionable task cards** in the approver's "My Tasks" view with direct approve/reject actions and comment fields.
- **REQ-UI-007:** The system shall support a **dark mode** UI theme.
- **REQ-UI-008:** The system shall be responsive and usable on tablet form factors (minimum 768px viewport width).

---

## 19. API Requirements

### 19.1 API Design Principles

- RESTful API with OpenAPI 3.0 specification.
- All responses in JSON.
- Versioned endpoints (`/api/v1/...`).
- Pagination via cursor-based pagination for list endpoints.
- Standard error envelope: `{ "error": { "code": string, "message": string, "details": [] } }`.

### 19.2 Core API Endpoints (Summary)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/models` | GET | List all model projects (paginated, filterable) |
| `/api/v1/models` | POST | Create new model project (Inception) |
| `/api/v1/models/{model_id}` | GET | Get model project detail |
| `/api/v1/models/{model_id}/versions` | GET | List all versions of a model |
| `/api/v1/models/{model_id}/versions/{version}` | GET | Get specific version detail |
| `/api/v1/models/{model_id}/stages/{stage}` | GET | Get stage record |
| `/api/v1/models/{model_id}/stages/{stage}/transition` | POST | Submit stage gate / trigger transition |
| `/api/v1/models/{model_id}/stages/{stage}/artifacts` | POST | Upload artifact to stage |
| `/api/v1/deployment/eligibility` | GET | **Deployment Eligibility Check** (model_id + version + environment) |
| `/api/v1/deployment/events` | POST | Receive deployment event callback |
| `/api/v1/monitoring/ingest` | POST | Ingest monitoring metric payload |
| `/api/v1/monitoring/alerts` | GET | List alerts for a model version |
| `/api/v1/audit` | GET | Query audit log (filterable) |
| `/api/v1/integrations` | GET/POST | Manage integration configurations |
| `/api/v1/reports/inventory` | GET | Export model inventory report |

### 19.3 Deployment Eligibility API Detail

```
GET /api/v1/deployment/eligibility
  ?model_id=MOD-2024-00421
  &version=1.2.0
  &environment=production
  &platform=SAGEMAKER_ENDPOINT

Response 200:
{
  "eligible": true | false,
  "status": "ELIGIBLE" | "INELIGIBLE" | "CONDITIONAL",
  "model_id": "MOD-2024-00421",
  "version": "1.2.0",
  "validation_date": "2024-11-15T10:22:00Z",
  "validation_expiry": "2025-11-15T10:22:00Z",
  "conditions": [],
  "restrictions": [],
  "ineligibility_reasons": []
}
```

---

## 20. Glossary

| Term | Definition |
|------|------------|
| **Candidate Model** | The specific MLflow run / trained model artifact selected by the Data Scientist to progress through validation and deployment |
| **Deployment Eligibility API** | The MOA API endpoint queried by deployment platforms to determine whether a specific model version is authorized for deployment |
| **Model ID** | The globally unique identifier assigned by MOA to a model project at inception |
| **Model Manifest** | A machine-readable JSON/YAML document describing a model version's status, artifact locations, and deployment eligibility |
| **Model Version** | A discrete, immutable instance of a model within a project, identified by semantic version number |
| **Risk Tier** | A 1–4 classification of model risk (1 = highest) that governs the rigor of required validation activities |
| **Stage Gate** | A mandatory checkpoint at the end of each lifecycle stage requiring documented evidence and authorized approval before the model progresses |
| **SR 11-7** | Federal Reserve / OCC supervisory guidance on model risk management, a key compliance framework for financial models |
| **Superseded** | Status of a model version that was previously deployed but has been replaced by a newer version |
| **Transition Period** | A configurable window during model retirement during which the model remains operational while consumers migrate to a successor |
| **Validation Baseline** | Statistical reference distribution computed from training/validation data, used as the reference point for drift detection |

---

*End of Requirements Document*  
*MOA v1.0 — Model Operational Application*
