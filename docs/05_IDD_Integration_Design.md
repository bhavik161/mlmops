# Integration Design Document (IDD)
## Environment Provisioning & Model Registry Synchronization
### Model Lifecycle Management (MLM) Platform

**Document ID:** MLM-IDD-001  
**Version:** 1.0  
**Status:** Draft  
**Classification:** Internal — Confidential  

**Related Documents:**
- `MLM-SRD-001` — System Requirements Document (Section 9: Integration Architecture)
- `MLM-FRD-001` — Functional Requirements Document (Section 13: Integration Requirements)
- `MLM-SAD-001` — Storage Architecture Document

---

## Document Control

| Version | Date | Author | Change Description |
|---------|------|--------|-------------------|
| 1.0 | 2024-Q4 | Architecture Team | Baseline release |

### Review & Approval

| Role | Name | Status |
|------|------|--------|
| Enterprise Architect | TBD | Pending |
| MLOps Lead | TBD | Pending |
| Cloud Infrastructure Lead | TBD | Pending |
| Security Architect | TBD | Pending |

---

## Table of Contents

1. [Overview & Design Philosophy](#1-overview--design-philosophy)
2. [Integration Architecture](#2-integration-architecture)
3. [AWS Tagging Taxonomy](#3-aws-tagging-taxonomy)
4. [Environment Provisioning Integration](#4-environment-provisioning-integration)
5. [EventBridge Event Bus Design](#5-eventbridge-event-bus-design)
6. [Provisioning Tool Adapters](#6-provisioning-tool-adapters)
7. [Manual Tagging Fallback](#7-manual-tagging-fallback)
8. [Tag Compliance & Lineage Enforcement](#8-tag-compliance--lineage-enforcement)
9. [SageMaker ↔ MLM Registry Synchronization](#9-sagemaker--mlm-registry-synchronization)
10. [Business Model Registry Design](#10-business-model-registry-design)
11. [Pre-Registration Soft Check](#11-pre-registration-soft-check)
12. [Bi-Directional Sync Design](#12-bi-directional-sync-design)
13. [Conflict Resolution & Source of Truth](#13-conflict-resolution--source-of-truth)
14. [Future Registry Extensions](#14-future-registry-extensions)
15. [Error Handling & Observability](#15-error-handling--observability)
16. [Security Considerations](#16-security-considerations)

---

## 1. Overview & Design Philosophy

### 1.1 Purpose

This document defines the integration design for two closely related but distinct integration domains within the MLM platform:

1. **Environment Provisioning Integration** — How MLM triggers the provisioning of AWS environments when a model project is approved at the Inception stage, including the AWS tagging taxonomy that enables governance lineage across all provisioned resources.

2. **Model Registry Synchronization** — How the MLM Business Model Registry (the governance authority) stays synchronized with the SageMaker Model Registry (the technical artifact registry), including the pre-registration soft-check workflow and ongoing bi-directional sync as model versions evolve.

### 1.2 Core Design Principles

| Principle | Description |
|-----------|-------------|
| **MLM does not own provisioning** | MLM's responsibility ends at publishing a well-structured event. How that event becomes a provisioned AWS environment — whether via ServiceNow, Terraform Cloud, AWS Service Catalog, or any other tool — is entirely the consuming system's concern |
| **Event bus as the integration contract** | MLM publishes to an EventBridge custom bus. Provisioning tools subscribe. Adding new tools requires no MLM code changes — only new EventBridge rules and API destinations |
| **Soft governance, hard auditability** | The SM pre-registration check is a soft block — governance processes should never hard-stop engineering work. However, every deviation is logged, tracked, and surfaced in MLM with a required remediation path |
| **MLM is the business registry; SM is the technical registry** | They serve complementary roles. Conflicts resolve in MLM's favor for governance decisions; SM's favor for artifact and deployment decisions |
| **Tags are the lineage fabric** | AWS resource tags are the connective tissue linking every cloud resource (S3 bucket, SageMaker experiment, training job, endpoint, IAM role) back to the MLM model project. Tag compliance is enforced, not optional |
| **Extensibility by design** | Every integration point is designed to accommodate future provisioning tools and ML registries (Databricks Unity Catalog, Azure ML, MLflow OSS) without architectural changes |

### 1.3 Integration Scope

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    INTEGRATION SCOPE — THIS DOCUMENT                        │
│                                                                             │
│  MLM Platform                                                               │
│  ┌──────────────────────────┐                                               │
│  │   Inception Stage        │──── Approval Event ────► EventBridge Bus     │
│  │   (Stage Gate Approved)  │                               │               │
│  └──────────────────────────┘                               │               │
│                                                             ▼               │
│  ┌──────────────────────────┐                    ┌──────────────────────┐   │
│  │   Business Model         │◄──── Sync ────────►│  ServiceNow          │   │
│  │   Registry               │                    │  (or future tools)   │   │
│  │                          │                    └──────────────────────┘   │
│  │   ┌──────────────────┐   │                               │               │
│  │   │ Pre-Registration │   │                               ▼               │
│  │   │ Soft Check       │   │                    ┌──────────────────────┐   │
│  │   └──────────────────┘   │                    │  AWS Environment     │   │
│  └──────────────────────────┘                    │  (Tagged Resources)  │   │
│           ▲        │                             └──────────────────────┘   │
│           │        │ Sync                                                    │
│           │        ▼                                                         │
│  ┌────────────────────────────┐                                             │
│  │  SageMaker Model Registry  │                                             │
│  │  (Technical Registry)      │                                             │
│  └────────────────────────────┘                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Integration Architecture

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         MLM INTEGRATION ARCHITECTURE                            │
│                                                                                 │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                    DOMAIN 1: ENVIRONMENT PROVISIONING                     │  │
│  │                                                                           │  │
│  │  MLM Platform          EventBridge              Provisioning Tools        │  │
│  │  ┌───────────┐         ┌──────────────────────┐                          │  │
│  │  │ Inception │ publish │  Custom Event Bus     │  ┌───────────────────┐  │  │
│  │  │ Approval  ├────────►│  (mlm-events)         ├─►│  ServiceNow       │  │  │
│  │  │ Gate      │  event  │                       │  │  (Catalog Request)│  │  │
│  │  └───────────┘         │  Rules:               │  └───────────────────┘  │  │
│  │                        │  inception.approved   ├─►┌───────────────────┐  │  │
│  │  ┌───────────┐         │  stage.transitioned   │  │  Jira / Custom    │  │  │
│  │  │ Tag       │         │  version.validated    │  │  (future)         │  │  │
│  │  │ Compliance│         │  model.retired        ├─►└───────────────────┘  │  │
│  │  │ Dashboard │         │                       │  ┌───────────────────┐  │  │
│  │  └───────────┘         │  Archive Rule:        │  │  SQS Audit Archive│  │  │
│  │                        │  *.* → SQS            ├─►│  (all events)     │  │  │
│  │                        └──────────────────────┘  └───────────────────┘  │  │
│  │                                                                           │  │
│  │  Fallback (no automation):                                                │  │
│  │  Admin/User → MLM Tag Registration UI → AWS Tagging API                 │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                                                                 │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                    DOMAIN 2: REGISTRY SYNCHRONIZATION                     │  │
│  │                                                                           │  │
│  │  Data Scientist                                                           │  │
│  │       │                                                                   │  │
│  │       │ 1. Selects experiment for production                              │  │
│  │       ▼                                                                   │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐     │  │
│  │  │              Pre-Registration Soft Check                         │     │  │
│  │  │  (Lambda hook on SM Model Package Group)                         │     │  │
│  │  │                                                                   │     │  │
│  │  │  2. Check: is this experiment linked to an MLM project?          │     │  │
│  │  │     ├── LINKED → proceed; sync to MLM Business Registry         │     │  │
│  │  │     └── UNLINKED → warn; flag in MLM; require remediation        │     │  │
│  │  └───────────────────────────────────────────────────────────────  ┘     │  │
│  │                  │                          │                             │  │
│  │                  ▼                          ▼                             │  │
│  │  ┌──────────────────────┐    ┌──────────────────────────────────────┐   │  │
│  │  │  SageMaker Model     │    │  MLM Business Model Registry          │   │  │
│  │  │  Registry            │◄──►│  (Governance Authority)              │   │  │
│  │  │  (Technical)         │    │                                      │   │  │
│  │  │                      │    │  • Links SM versions to MLM projects  │   │  │
│  │  │  Model Package Groups│    │  • Tracks validation status           │   │  │
│  │  │  Model Packages      │    │  • Governs deployment eligibility     │   │  │
│  │  │  Model Package Vers. │    │  • Maintains full version lineage     │   │  │
│  │  └──────────────────────┘    └──────────────────────────────────────┘   │  │
│  │           │                                    ▲                         │  │
│  │           │  EventBridge (SM events)           │  MLM Sync Lambda        │  │
│  │           └────────────────────────────────────┘                         │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 AWS Services Used

| Service | Role |
|---------|------|
| **Amazon EventBridge** (custom bus) | MLM event publication and routing to provisioning tools |
| **EventBridge API Destinations** | Outbound HTTP calls to ServiceNow and other external tools |
| **AWS Lambda** | SM pre-registration hook, sync processor, tag compliance checker |
| **Amazon SQS** | Event archive queue; dead-letter handling for failed integrations |
| **AWS Resource Groups Tagging API** | Tag application and compliance verification across AWS resources |
| **AWS Config** | Continuous tag compliance monitoring; custom rules for MLM tag presence |
| **Amazon SageMaker** | Source of technical model registry events (via EventBridge integration) |
| **AWS Secrets Manager** | ServiceNow credentials, external tool API keys |
| **Amazon CloudWatch** | Integration health metrics, Lambda error rates, sync lag |

---

## 3. AWS Tagging Taxonomy

### 3.1 Design Rationale

Tags serve four distinct governance purposes in MLM:

1. **Lineage** — trace any AWS resource back to its originating MLM model project
2. **Cost Allocation** — FinOps cost attribution by model, team, and risk tier
3. **Compliance** — AWS Config rules verify tag presence on regulated resources
4. **Discovery** — AWS Resource Groups enable querying all resources for a model project

### 3.2 Required Tags

These tags are mandatory on all AWS resources provisioned within a model project environment. MLM publishes these in the provisioning event payload. AWS Config rules flag non-compliance.

| Tag Key | Format | Example | Description | Who Sets |
|---------|--------|---------|-------------|----------|
| `mlm:model-id` | `MOD-{YYYY}-{5-digit}` | `MOD-2024-00421` | Globally unique MLM model identifier | MLM (auto) |
| `mlm:project-name` | Lowercase, hyphenated | `credit-default-predictor` | Human-readable project name | MLM (auto) |
| `mlm:risk-tier` | `1` \| `2` \| `3` \| `4` | `2` | MLM risk tier (1=highest) | MLM (auto) |
| `mlm:business-domain` | Lowercase, hyphenated | `credit-risk` | Business domain taxonomy | MLM (auto) |
| `mlm:owner-email` | Email address | `bhavik@company.com` | Model owner email | MLM (auto) |
| `mlm:environment` | `development` \| `staging` \| `production` | `development` | Environment stage | MLM (auto) |
| `mlm:stage` | Stage name | `development` | Current MLM lifecycle stage | MLM (auto) |
| `cost-center` | Alphanumeric | `CC-4821` | FinOps cost allocation code | MLM (from Inception form) |
| `Environment` | `prod` \| `staging` \| `dev` | `dev` | Standard AWS environment tag | MLM (auto) |

### 3.3 Recommended Tags

Populated when available; enriched as the model progresses through stages.

| Tag Key | Format | Example | When Added | Description |
|---------|--------|---------|------------|-------------|
| `mlm:version` | Semantic version | `1.2.0` | Development stage | Current model version under development |
| `mlm:regulatory-scope` | Comma-separated codes | `sr117,gdpr` | Inception (if applicable) | Applicable regulatory frameworks |
| `mlm:data-classification` | `pii` \| `confidential` \| `internal` \| `public` | `pii` | Inception (from data assessment) | Data sensitivity of training/inference data |
| `mlm:model-type` | `internal` \| `vendor` \| `genai` | `internal` | Inception | Model category |
| `mlm:sm-model-package-group` | ARN or name | `credit-default-v1` | Development (when SM linked) | Linked SageMaker Model Package Group name |
| `mlm:validation-status` | `not-validated` \| `validated` \| `conditional` | `validated` | Validation stage | Current validation status |
| `mlm:last-validated-date` | `YYYY-MM-DD` | `2024-11-15` | Validation stage | Date of last successful validation |

### 3.4 Tag Inheritance Strategy

When a model project progresses through stages, tags are enriched and propagated:

```
Stage:        Tags Added / Updated
─────────────────────────────────────────────────────────────
Inception     mlm:model-id, mlm:project-name, mlm:risk-tier,
Approved  →   mlm:business-domain, mlm:owner-email,
              mlm:environment=development, mlm:stage=development,
              mlm:data-classification, mlm:regulatory-scope,
              cost-center

Development   mlm:version (when candidate selected),
Active    →   mlm:stage=development,
              mlm:sm-model-package-group (when SM linked)

Validation    mlm:validation-status=validated (on approval),
Approved  →   mlm:last-validated-date,
              mlm:stage=validation→implementation

Deployed  →   mlm:environment=production,
              mlm:stage=implementation,
              mlm:validation-status=validated

Retired   →   mlm:environment=retired,
              mlm:stage=retirement
```

MLM maintains a **Tag Update Job** triggered on each stage transition that calls the AWS Resource Groups Tagging API to update tags across all registered resources for the model project.

### 3.5 Lineage Query Patterns

With the tagging taxonomy in place, the following governance lineage queries become possible:

```bash
# Query 1: All AWS resources for a specific model project
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=mlm:model-id,Values=MOD-2024-00421

# Query 2: All production resources for Tier 1 models
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=mlm:risk-tier,Values=1 \
               Key=mlm:environment,Values=production

# Query 3: All resources with PII data classification
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=mlm:data-classification,Values=pii

# Query 4: Cost Explorer — monthly spend by model ID
aws ce get-cost-and-usage \
  --granularity MONTHLY \
  --filter '{"Tags": {"Key": "mlm:model-id", "Values": ["MOD-2024-00421"]}}' \
  --metrics BlendedCost

# Query 5: All unvalidated models currently in production (governance alert)
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=mlm:environment,Values=production \
               Key=mlm:validation-status,Values=not-validated
```

---

## 4. Environment Provisioning Integration

### 4.1 Overview

When a model project's Inception stage gate is approved in MLM, the platform publishes a structured event to the EventBridge custom bus. External provisioning tools subscribe to this event and handle the actual environment setup. MLM has no knowledge of or dependency on how the provisioning is implemented.

### 4.2 Provisioning Trigger Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    INCEPTION APPROVAL → PROVISIONING FLOW                   │
│                                                                             │
│  1. Model Owner approves Inception gate in MLM                              │
│           │                                                                 │
│           ▼                                                                 │
│  2. MLM Workflow Engine: stage transitions to COMPLETED                     │
│           │                                                                 │
│           ▼                                                                 │
│  3. MLM Event Publisher: builds InceptionApproved event payload             │
│     (within same DB transaction as gate approval)                           │
│           │                                                                 │
│           ▼                                                                 │
│  4. MLM publishes to EventBridge custom bus (mlm-events)                   │
│           │                                                                 │
│           ▼                                                                 │
│  5. EventBridge routes to configured targets:                               │
│     ├─► ServiceNow API Destination (if configured)                         │
│     ├─► SQS Audit Archive (always)                                          │
│     └─► Additional targets (future)                                         │
│           │                                                                 │
│  6a. ServiceNow receives event:                                             │
│      → Creates catalog item / change request                                │
│      → Triggers provisioning workflow                                        │
│      → Provisions AWS environment (SageMaker Project, S3, IAM, etc.)       │
│      → Applies MLM tags to provisioned resources                            │
│      → Calls back MLM API: POST /api/v1/provisioning/callback               │
│           │                                                                 │
│  6b. No automation available:                                               │
│      → MLM sets project to PENDING_ENVIRONMENT status                       │
│      → Admin receives notification: "Manual tagging required"               │
│      → Admin uses MLM Tag Registration UI                                   │
│           │                                                                 │
│  7. MLM receives callback (or manual registration):                         │
│     → Records environment_id, provisioned resources, tag verification       │
│     → Activates Development stage                                           │
│     → Notifies Data Scientist: "Environment ready"                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.3 InceptionApproved Event Schema

This is the canonical event published by MLM upon Inception stage approval. All provisioning tools consume this contract.

```json
{
  "version": "0",
  "id": "a8f3b2c1-4d5e-6f7a-8b9c-0d1e2f3a4b5c",
  "source": "com.mlm.platform",
  "detail-type": "MLM.Inception.Approved",
  "time": "2024-11-15T10:22:00Z",
  "region": "us-east-1",
  "account": "123456789012",
  "detail": {
    "event_version": "1.0",
    "event_id": "evt-00421-20241115-001",
    "model_project": {
      "model_id": "MOD-2024-00421",
      "project_name": "credit-default-predictor",
      "display_name": "Credit Default Predictor v1",
      "description": "ML model to predict probability of credit default at application",
      "risk_tier": 2,
      "business_domain": "credit-risk",
      "model_type": "INTERNAL",
      "regulatory_scope": ["SR117", "FCRA"],
      "data_classification": "PII"
    },
    "ownership": {
      "owner_email": "bhavik@company.com",
      "owner_name": "Bhavik Patel",
      "team": "Risk Analytics",
      "cost_center": "CC-4821"
    },
    "provisioning_request": {
      "target_aws_account_id": "987654321098",
      "target_aws_region": "us-east-1",
      "requested_resources": [
        "SAGEMAKER_PROJECT",
        "S3_DATA_BUCKET",
        "IAM_ROLES",
        "SAGEMAKER_MODEL_PACKAGE_GROUP",
        "SAGEMAKER_EXPERIMENT"
      ],
      "environment": "development",
      "tags": {
        "mlm:model-id": "MOD-2024-00421",
        "mlm:project-name": "credit-default-predictor",
        "mlm:risk-tier": "2",
        "mlm:business-domain": "credit-risk",
        "mlm:owner-email": "bhavik@company.com",
        "mlm:environment": "development",
        "mlm:stage": "development",
        "mlm:data-classification": "pii",
        "mlm:regulatory-scope": "sr117,fcra",
        "cost-center": "CC-4821",
        "Environment": "dev"
      }
    },
    "callback": {
      "url": "https://mlm.company.com/api/v1/provisioning/callback",
      "auth_type": "BEARER_TOKEN",
      "token_secret_arn": "arn:aws:secretsmanager:us-east-1:123456789012:secret:mlm/provisioning/callback-token",
      "correlation_id": "MOD-2024-00421-prov-20241115"
    },
    "approved_by": {
      "user_id": "usr-00042",
      "name": "Jane Smith",
      "role": "MODEL_OWNER"
    },
    "approved_at": "2024-11-15T10:22:00Z"
  }
}
```

### 4.4 Provisioning Callback API

When the provisioning tool completes environment setup, it calls back to MLM:

```
POST /api/v1/provisioning/callback
Authorization: Bearer {callback_token}

Request Body:
{
  "correlation_id": "MOD-2024-00421-prov-20241115",
  "model_id": "MOD-2024-00421",
  "status": "SUCCESS" | "PARTIAL" | "FAILED",
  "provisioned_at": "2024-11-15T10:45:00Z",
  "provisioning_tool": "SERVICE_NOW",
  "provisioning_reference": "RITM0042891",  ← ServiceNow request item number
  "aws_account_id": "987654321098",
  "aws_region": "us-east-1",
  "provisioned_resources": [
    {
      "resource_type": "SAGEMAKER_PROJECT",
      "resource_id": "p-abc123xyz",
      "arn": "arn:aws:sagemaker:us-east-1:987654321098:project/credit-default-predictor",
      "tagged": true
    },
    {
      "resource_type": "S3_BUCKET",
      "resource_id": "mlm-dev-credit-default-data",
      "arn": "arn:aws:s3:::mlm-dev-credit-default-data",
      "tagged": true
    },
    {
      "resource_type": "SAGEMAKER_MODEL_PACKAGE_GROUP",
      "resource_id": "credit-default-predictor-mpg",
      "arn": "arn:aws:sagemaker:...:model-package-group/credit-default-predictor-mpg",
      "tagged": true,
      "metadata": {
        "sm_model_package_group_name": "credit-default-predictor-mpg"
      }
    }
  ],
  "partial_failures": [],
  "error_detail": null
}

Response: 200 OK
{
  "data": {
    "model_id": "MOD-2024-00421",
    "environment_record_id": "env-00421-001",
    "development_stage_status": "IN_PROGRESS",
    "data_scientist_notified": true
  }
}
```

### 4.5 Environment Record

MLM maintains an `environment_record` per model project, updated via the callback:

```
mlm_integration.environment_records
├── id                        UUID
├── model_project_id          UUID
├── aws_account_id            TEXT
├── aws_region                TEXT
├── provisioning_tool         ENUM  (SERVICE_NOW | MANUAL | AWS_SERVICE_CATALOG | CUSTOM)
├── provisioning_reference    TEXT  (e.g., ServiceNow RITM number)
├── provisioning_status       ENUM  (PENDING | SUCCESS | PARTIAL | FAILED | MANUAL)
├── provisioned_at            TIMESTAMPTZ
├── provisioned_resources     JSONB (array of resource records)
├── sm_project_id             TEXT  (SageMaker Project ID when available)
├── sm_model_package_group    TEXT  (SM Model Package Group name)
├── tag_compliance_status     ENUM  (COMPLIANT | NON_COMPLIANT | PENDING_CHECK)
├── tag_compliance_checked_at TIMESTAMPTZ
├── tag_compliance_detail     JSONB (per-resource compliance results)
└── updated_at                TIMESTAMPTZ
```

---

## 5. EventBridge Event Bus Design

### 5.1 Custom Event Bus

```
Event Bus Name:  mlm-events
AWS Account:     {MLM platform account}
Description:     MLM platform governance event bus
Resource Policy: Allows cross-account publishing from MLM app role
                 Allows cross-account subscriptions (for multi-account setups)
```

### 5.2 MLM Event Catalog

All events published by MLM follow the naming convention: `MLM.{Domain}.{Action}`

| Event Name | Trigger | Key Payload Fields |
|------------|---------|-------------------|
| `MLM.Inception.Approved` | Inception gate approved | model_id, provisioning_request, tags, callback |
| `MLM.Inception.Rejected` | Inception gate rejected | model_id, rejection_reason |
| `MLM.Development.CandidateSelected` | MLflow run selected as candidate | model_id, version, mlflow_run_id, tracking_uri |
| `MLM.Development.Approved` | Development gate approved | model_id, version, candidate_summary |
| `MLM.Validation.Started` | Validation stage activated | model_id, version, assigned_validators |
| `MLM.Validation.Approved` | Validation gate approved | model_id, version, validation_summary |
| `MLM.Validation.Rejected` | Validation gate rejected | model_id, version, findings_summary |
| `MLM.Implementation.StagingApproved` | Staging promotion approved | model_id, version, deployment_config |
| `MLM.Implementation.ProductionApproved` | Production promotion approved | model_id, version, deployment_config |
| `MLM.Implementation.Deployed` | Deployment confirmed (callback) | model_id, version, environment, platform_resource_id |
| `MLM.Version.Created` | New model version initialized | model_id, version, version_type, parent_version |
| `MLM.Version.StatusChanged` | Version status updated | model_id, version, old_status, new_status |
| `MLM.Monitoring.AlertTriggered` | Monitoring alert fired | model_id, version, severity, metric, threshold |
| `MLM.Monitoring.IncidentCreated` | Incident record created | model_id, version, incident_id, severity |
| `MLM.Registry.SyncRequested` | SM↔MLM sync needed | model_id, version, sync_direction, trigger |
| `MLM.Registry.Unlinked` | SM registration without MLM link | sm_model_package_arn, detection_method |
| `MLM.Retirement.Initiated` | Retirement workflow started | model_id, version, retirement_reason, transition_period_days |
| `MLM.Retirement.Completed` | Model fully retired | model_id, version, retired_at |
| `MLM.Tag.NonCompliant` | Tag compliance violation detected | model_id, resource_arn, missing_tags |

### 5.3 EventBridge Rules

```
Rule 1: mlm-provisioning-trigger
  Event Pattern:
    { "source": ["com.mlm.platform"],
      "detail-type": ["MLM.Inception.Approved"] }
  Targets:
    - ServiceNow API Destination (if configured)
    - AWS Service Catalog (alternative; if configured)
    - SQS: mlm-prod-provisioning-events (always; for audit + replay)

Rule 2: mlm-registry-sync
  Event Pattern:
    { "source": ["com.mlm.platform"],
      "detail-type": [
        "MLM.Development.CandidateSelected",
        "MLM.Validation.Approved",
        "MLM.Validation.Rejected",
        "MLM.Version.StatusChanged",
        "MLM.Retirement.Completed"
      ] }
  Targets:
    - Lambda: mlm-sm-registry-sync (SM registry update)
    - SQS: mlm-prod-registry-events (audit)

Rule 3: mlm-tag-enrichment
  Event Pattern:
    { "source": ["com.mlm.platform"],
      "detail-type": [
        "MLM.Development.CandidateSelected",
        "MLM.Validation.Approved",
        "MLM.Implementation.Deployed",
        "MLM.Retirement.Initiated"
      ] }
  Targets:
    - Lambda: mlm-tag-updater (enriches tags on stage transition)

Rule 4: mlm-all-events-archive
  Event Pattern:
    { "source": ["com.mlm.platform"] }
  Targets:
    - SQS: mlm-prod-event-archive (DLQ-backed; full audit trail)
    - CloudWatch Logs: /mlm/events (30-day hot retention)

Rule 5: mlm-external-notifications
  Event Pattern:
    { "source": ["com.mlm.platform"],
      "detail-type": [
        "MLM.Monitoring.AlertTriggered",
        "MLM.Retirement.Initiated",
        "MLM.Tag.NonCompliant"
      ] }
  Targets:
    - Lambda: mlm-notification-dispatcher
```

### 5.4 Adding a New Provisioning Tool

When a new tool needs to receive provisioning events (e.g., JIRA Service Management, AWS Service Catalog), the process is:

```
Step 1: Create EventBridge API Destination
  Name:          mlm-jira-provisioning
  Endpoint:      https://company.atlassian.net/rest/servicedeskapi/...
  Auth type:     API_KEY (stored in Secrets Manager)
  Rate limit:    50 req/sec

Step 2: Create EventBridge Connection
  Name:          mlm-jira-connection
  Auth type:     API_KEY
  Secret ARN:    arn:aws:secretsmanager:...:mlm/integrations/jira-api-key

Step 3: Add target to Rule 1 (mlm-provisioning-trigger)
  Target type:   EventBridge API Destination
  Destination:   mlm-jira-provisioning
  Input transformer: (optional — reshape payload to JIRA format)

Step 4: Register in MLM Admin console
  Tool type:     JIRA_SERVICE_MANAGEMENT
  Callback URL:  https://mlm.company.com/api/v1/provisioning/callback
  Enabled:       true

Zero MLM code changes required.
```

### 5.5 Input Transformer — ServiceNow Format

EventBridge input transformers reshape the MLM event payload to the format expected by the target tool without requiring code changes:

```json
{
  "InputTemplate": {
    "short_description": "MLM Environment Provisioning Request — <model_id>",
    "description": "Model Lifecycle Management environment provisioning for project: <project_name>. Risk Tier: <risk_tier>. Owner: <owner_email>.",
    "category": "ML Platform",
    "subcategory": "Environment Provisioning",
    "priority": "<snow_priority>",
    "requested_for": "<owner_email>",
    "variables": {
      "mlm_model_id": "<model_id>",
      "mlm_risk_tier": "<risk_tier>",
      "mlm_business_domain": "<business_domain>",
      "aws_account_id": "<target_aws_account_id>",
      "aws_region": "<aws_region>",
      "requested_resources": "<requested_resources>",
      "mlm_tags": "<tags>",
      "callback_url": "<callback_url>",
      "correlation_id": "<correlation_id>"
    }
  },
  "InputPathsMap": {
    "model_id":              "$.detail.model_project.model_id",
    "project_name":          "$.detail.model_project.project_name",
    "risk_tier":             "$.detail.model_project.risk_tier",
    "business_domain":       "$.detail.model_project.business_domain",
    "owner_email":           "$.detail.ownership.owner_email",
    "target_aws_account_id": "$.detail.provisioning_request.target_aws_account_id",
    "aws_region":            "$.detail.provisioning_request.target_aws_region",
    "requested_resources":   "$.detail.provisioning_request.requested_resources",
    "tags":                  "$.detail.provisioning_request.tags",
    "callback_url":          "$.detail.callback.url",
    "correlation_id":        "$.detail.callback.correlation_id",
    "snow_priority":         "$.detail.model_project.risk_tier"
  }
}
```

---

## 6. Provisioning Tool Adapters

### 6.1 ServiceNow Adapter

```
Integration Type:    EventBridge API Destination → ServiceNow REST API
SNOW API Used:       Service Catalog API (create catalog request)
                     or Table API (create incident/change request)
Authentication:      OAuth2 (client_credentials) — credentials in Secrets Manager
Rate Limiting:       50 req/sec (EventBridge API Destination config)
Retry Policy:        3 retries, exponential backoff (EventBridge managed)
DLQ:                 SQS DLQ for failed deliveries

ServiceNow Catalog Item:
  Name:              "MLM Environment Provisioning"
  Variables:         Populated from EventBridge input transformer
  Workflow:          SNOW workflow handles AWS provisioning
                     (e.g., calls AWS via CloudFormation StackSets,
                     Terraform Cloud API, or AWS Service Catalog)
  Callback:          SNOW workflow calls MLM callback URL on completion

SNOW → MLM mapping:
  RITM number → provisioning_reference in MLM environment_record
  SNOW state  → provisioning_status in MLM (PENDING/SUCCESS/FAILED)
```

### 6.2 AWS Service Catalog Adapter (Alternative/Complement to SNOW)

For organizations that self-serve AWS provisioning without ServiceNow:

```
Integration Type:    EventBridge → Lambda → AWS Service Catalog
Lambda:              mlm-service-catalog-provisioner
  - Receives MLM.Inception.Approved event
  - Calls ServiceCatalog:ProvisionProduct API
  - Product: "MLM Model Development Environment"
    (pre-defined CloudFormation product with parameterized inputs)
  - Parameters: model_id, risk_tier, aws_account_id, tags
  - Tracks provisioning via DescribeRecord polling
  - On completion: calls MLM callback API

Service Catalog Product (CloudFormation):
  Provisions:
    ├── SageMaker Project (with MLM tags)
    ├── S3 Bucket for training data (with MLM tags)
    ├── SageMaker Experiments container
    ├── SageMaker Model Package Group
    ├── IAM Roles (Data Scientist, ML Engineer — scoped to model project)
    └── CloudWatch Log Groups (tagged)
```

### 6.3 Future Provisioning Tools

The EventBridge pattern supports any future tool with no MLM changes:

| Future Tool | Integration Method |
|-------------|------------------|
| Jira Service Management | EventBridge API Destination → Jira REST API |
| Backstage (internal developer portal) | EventBridge → Backstage scaffolder API |
| Terraform Cloud | EventBridge → Lambda → Terraform Cloud API (workspace run trigger) |
| HashiCorp Nomad | EventBridge → Lambda → Nomad Jobs API |
| Custom internal portal | EventBridge API Destination → custom REST endpoint |

---

## 7. Manual Tagging Fallback

### 7.1 When Manual Tagging Applies

Manual tagging is required when:
- No provisioning tool integration is configured for the MLM deployment
- The automated provisioning fails or is partially successful
- Resources were provisioned before MLM was adopted (brownfield onboarding)
- The provisioning tool does not support the callback mechanism

### 7.2 Tag Registration UI

MLM provides a **Tag Registration** panel within the Inception stage (after approval) and Development stage:

```
Tag Registration Panel — Project: Credit Default Predictor (MOD-2024-00421)

Environment Status: ⚠ PENDING_ENVIRONMENT

Step 1: Enter AWS Account & Region
  AWS Account ID: [_______________]
  AWS Region:     [_______________]

Step 2: Register Existing Resources (or enter resource ARNs manually)
  [Discover Resources]  ← Calls AWS Resource Groups Tagging API
                          filtered by partial tags if any exist
  
  Discovered / Manual Resources:
  ┌────────────────────────────────────────────────────────────────┐
  │ Resource Type             │ Resource ID / ARN        │ Tagged? │
  ├────────────────────────────────────────────────────────────────┤
  │ SageMaker Project         │ p-abc123xyz              │ ❌ No   │
  │ S3 Bucket (training data) │ my-credit-model-data     │ ❌ No   │
  │ SM Model Package Group    │ credit-mpg-v1            │ ❌ No   │
  └────────────────────────────────────────────────────────────────┘

Step 3: Apply MLM Tags
  [Apply Tags to All Resources]  ← Calls AWS Resource Groups Tagging API
                                   to apply the standard MLM tag set
  
  Tags to be applied:
  mlm:model-id      = MOD-2024-00421      ✓
  mlm:project-name  = credit-default-... ✓
  mlm:risk-tier     = 2                  ✓
  [... all required tags ...]

Step 4: Confirm & Activate Development Stage
  [Confirm Environment Registration]
```

### 7.3 Brownfield Resource Discovery

For organizations onboarding existing ML projects into MLM:

```
Brownfield Discovery Flow:

1. MLM Admin provides:
   - AWS Account ID
   - AWS Region
   - Partial identifier (SageMaker Project name, S3 bucket prefix, etc.)

2. MLM calls AWS Resource Groups Tagging API:
   GET /tags?tagFilters (partial match on existing resource names)
   + SageMaker ListProjects, ListExperiments, ListModelPackageGroups
   + S3 ListBuckets (filtered by naming convention)

3. MLM presents discovered resources for admin confirmation

4. Admin confirms + maps to existing MLM model project

5. MLM applies missing tags and creates environment_record

6. MLM links any existing SageMaker Model Package Group to the
   MLM project (triggering the SM↔MLM registry sync)
```

---

## 8. Tag Compliance & Lineage Enforcement

### 8.1 AWS Config Rule — MLM Tag Compliance

A custom AWS Config rule enforces MLM tag presence on regulated resource types:

```python
# AWS Config Rule: mlm-required-tags-compliance
# Trigger: Configuration change on tagged resource types

REQUIRED_TAGS = [
    "mlm:model-id",
    "mlm:risk-tier",
    "mlm:owner-email",
    "mlm:environment",
    "cost-center"
]

MONITORED_RESOURCE_TYPES = [
    "AWS::SageMaker::Model",
    "AWS::SageMaker::Endpoint",
    "AWS::SageMaker::TrainingJob",
    "AWS::SageMaker::ModelPackage",
    "AWS::SageMaker::ModelPackageGroup",
    "AWS::S3::Bucket",
    "AWS::IAM::Role"
]

def evaluate_compliance(resource):
    resource_tags = resource.get("tags", {})
    missing_tags = [
        tag for tag in REQUIRED_TAGS
        if tag not in resource_tags
    ]
    if missing_tags:
        return "NON_COMPLIANT", f"Missing tags: {missing_tags}"
    return "COMPLIANT", None
```

### 8.2 Tag Compliance Enforcement Levels

| Resource Type | Missing Tag Action | Risk Tier Override |
|---------------|-------------------|-------------------|
| SageMaker Endpoint (production) | Block deployment via DES check | Tier 1: hard block |
| SageMaker Model Package | Warn in MLM; flag in registry | Tier 1-2: block SM→MLM sync |
| SageMaker Training Job | Log non-compliance; notify owner | All tiers: warn only |
| S3 Bucket | Log non-compliance; notify admin | All tiers: warn only |

### 8.3 Tag Compliance Dashboard

MLM includes a **Tag Compliance Dashboard** (Admin → Tag Compliance):

```
Tag Compliance Dashboard

Total Resources Monitored:    1,247
Compliant:                    1,189  (95.3%)
Non-Compliant:                   58   (4.7%)  ← Requires action
Unregistered (no mlm:model-id):  12   (1.0%)  ← Unknown resources

Non-Compliant Resources (sorted by risk):
┌─────────────────────────────────────────────────────────────────────────┐
│ Model ID        │ Resource              │ Missing Tags    │ Action      │
├─────────────────────────────────────────────────────────────────────────┤
│ MOD-2024-00401  │ sm-endpoint-prod-v1   │ mlm:validation- │ [Fix Tags]  │
│ (Tier 1)        │                       │ status          │             │
├─────────────────────────────────────────────────────────────────────────┤
│ UNREGISTERED    │ s3://team-model-data  │ mlm:model-id,   │ [Register]  │
│                 │                       │ mlm:risk-tier   │             │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 9. SageMaker ↔ MLM Registry Synchronization

### 9.1 Registry Roles and Responsibilities

| Aspect | SageMaker Model Registry | MLM Business Registry |
|--------|--------------------------|----------------------|
| **Primary purpose** | Technical artifact management — model packages, approval status for deployment | Business governance — model project tracking, validation evidence, risk, compliance |
| **Source of truth for** | Model artifact URIs, container images, inference configs, SM deployment approval | Validation status, risk tier, regulatory compliance, business owner, version lineage |
| **Conflict authority** | Technical deployment decisions | Governance decisions — validation, retirement, risk |
| **Who manages** | ML Engineers, Data Scientists | Model Owners, Validators, Risk Officers |
| **Populated by** | SageMaker training jobs, MLflow, manual registration | MLM lifecycle workflow |
| **Consumed by** | SageMaker Endpoints, Pipelines, deployment automation | MLM DES, compliance reports, audit |

### 9.2 Sync Events Taxonomy

```
Direction: SM → MLM (SM is trigger)
  Trigger Event                   MLM Action
  ─────────────────────────────────────────────────────────────
  ModelPackage registered in SM   Check if linked to MLM project
                                  → LINKED: update MLM version record
                                  → UNLINKED: create unlinked alert
  ModelPackage status → Approved  Inform MLM (informational only;
                                  MLM validation status governs DES)
  ModelPackage status → Rejected  Log in MLM development stage
  New ModelPackageGroup created   Check for MLM project linkage

Direction: MLM → SM (MLM is trigger)
  Trigger Event                   SM Action
  ─────────────────────────────────────────────────────────────
  MLM Validation Approved         Update SM ModelPackage metadata
                                  tag: mlm:validation-status=validated
                                  tag: mlm:last-validated-date
  MLM Version → SUPERSEDED        Update SM ModelPackage tag:
                                  mlm:validation-status=superseded
  MLM Retirement Approved         Update SM ModelPackage status
                                  → SM status: Rejected (blocks SM deployment)
                                  tag: mlm:environment=retired
  MLM Version Registered          (if SM MPG exists) register corresponding
                                  ModelPackage in SM if not already present
```

---

## 10. Business Model Registry Design

### 10.1 Purpose

The MLM Business Model Registry is the governance layer that sits above the SageMaker Model Registry. It maintains the business context, governance status, and cross-platform linkage for every model version.

### 10.2 Registry Data Schema

```sql
-- Core registry table (mlm_registry schema)
CREATE TABLE mlm_registry.business_model_registry (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    model_project_id            UUID NOT NULL REFERENCES mlm_core.model_projects(id),
    model_version_id            UUID NOT NULL REFERENCES mlm_core.model_versions(id),
    
    -- MLM governance fields
    mlm_version_string          TEXT NOT NULL,          -- e.g., 1.2.0
    mlm_validation_status       TEXT NOT NULL,          -- VALIDATED | NOT_VALIDATED | CONDITIONAL | RETIRED
    mlm_validation_date         TIMESTAMPTZ,
    mlm_validation_expiry       TIMESTAMPTZ,
    mlm_risk_tier               INTEGER,
    mlm_deployment_eligible     BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- SageMaker linkage
    sm_model_package_group_name TEXT,                   -- SM MPG name
    sm_model_package_arn        TEXT,                   -- SM Model Package ARN
    sm_model_package_version    INTEGER,                -- SM version number
    sm_approval_status          TEXT,                   -- Approved | Rejected | PendingManualApproval
    sm_linked_at                TIMESTAMPTZ,
    sm_link_method              TEXT,                   -- AUTO_TAGGED | MANUAL | CALLBACK
    
    -- Sync state
    sync_status                 TEXT NOT NULL DEFAULT 'IN_SYNC',
                                                        -- IN_SYNC | MLM_AHEAD | SM_AHEAD | CONFLICT
    last_synced_at              TIMESTAMPTZ,
    sync_conflict_detail        JSONB,
    
    -- Artifact references
    mlflow_run_id               TEXT,
    mlflow_tracking_uri         TEXT,
    artifact_uri                TEXT,                   -- S3 URI of model artifact
    training_data_uri           TEXT,
    training_data_hash          TEXT,
    
    -- AWS environment
    aws_account_id              TEXT,
    aws_region                  TEXT,
    sm_project_id               TEXT,
    
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Linkage history (full audit of SM↔MLM link events)
CREATE TABLE mlm_registry.registry_sync_log (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    registry_entry_id           UUID REFERENCES mlm_registry.business_model_registry(id),
    event_type                  TEXT NOT NULL,
    direction                   TEXT NOT NULL,          -- MLM_TO_SM | SM_TO_MLM
    trigger_event               TEXT,                   -- EventBridge event name
    before_state                JSONB,
    after_state                 JSONB,
    sync_success                BOOLEAN NOT NULL,
    error_detail                TEXT,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### 10.3 Registry View — MLM UI

The Business Model Registry is accessible in the MLM UI as a dedicated panel:

```
Business Model Registry
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Project: Credit Default Predictor  (MOD-2024-00421)

┌─────────────────────────────────────────────────────────────────────┐
│ Version │ MLM Status   │ SM Package ARN           │ Sync    │ Elig. │
├─────────────────────────────────────────────────────────────────────┤
│ 1.2.0   │ ✅ VALIDATED  │ sm::.../model-pkg/v3     │ IN_SYNC │ ✅ Yes│
│ 1.1.0   │ ⚠ SUPERSEDED │ sm::.../model-pkg/v2     │ IN_SYNC │ ❌ No │
│ 1.0.0   │ 🔴 RETIRED   │ sm::.../model-pkg/v1     │ IN_SYNC │ ❌ No │
└─────────────────────────────────────────────────────────────────────┘

SM Model Package Group: credit-default-predictor-mpg
AWS Account: 987654321098  |  Region: us-east-1
Last Sync:   2024-11-15 10:30 UTC  |  Status: ✅ IN_SYNC
```

---

## 11. Pre-Registration Soft Check

### 11.1 Design Philosophy

The pre-registration check is a **soft governance gate** — it does not block the Data Scientist from registering a model in SageMaker. Blocking engineering work for governance processes violates the principle that governance should enable, not obstruct. Instead:

- Registration proceeds regardless
- MLM detects the registration (via EventBridge)
- If linked to an MLM project → sync proceeds normally
- If unlinked → MLM flags the registration, creates a remediation task, notifies the Model Owner and MLOps Engineer, and requires the linkage to be established within a configurable SLA (default: 5 business days)
- Unlinked models are visible in the MLM Compliance Dashboard and cannot achieve `VALIDATED` status in MLM until linked

### 11.2 Soft Check Implementation

```
Implementation: Lambda function triggered by SageMaker EventBridge events
Function Name:  mlm-sm-preregistration-check
Trigger:        EventBridge rule on AWS SageMaker events

EventBridge Rule:
  Event Pattern:
    {
      "source": ["aws.sagemaker"],
      "detail-type": ["SageMaker Model Package State Change"],
      "detail": {
        "ModelPackageStatus": ["Completed"]
      }
    }
```

### 11.3 Pre-Registration Check Lambda Logic

```python
def handler(event, context):
    """
    Triggered on SM Model Package registration.
    Performs soft-check linkage to MLM project.
    Does NOT block registration — runs asynchronously.
    """
    detail = event["detail"]
    model_package_arn = detail["ModelPackageArn"]
    model_package_group = detail["ModelPackageGroupName"]

    # Step 1: Fetch tags from the SM Model Package
    tags = sagemaker.list_tags(ResourceArn=model_package_arn)
    mlm_model_id = get_tag(tags, "mlm:model-id")
    mlm_version = get_tag(tags, "mlm:version")

    # Step 2: Also check SM Model Package Group tags
    # (tags may be at group level, not package level)
    if not mlm_model_id:
        group_arn = get_model_package_group_arn(model_package_group)
        group_tags = sagemaker.list_tags(ResourceArn=group_arn)
        mlm_model_id = get_tag(group_tags, "mlm:model-id")

    # Step 3: Check MLM for linkage
    if mlm_model_id:
        mlm_project = mlm_api.get_project(mlm_model_id)
        if mlm_project:
            # LINKED — proceed with sync
            mlm_api.link_sm_registration(
                model_id=mlm_model_id,
                sm_model_package_arn=model_package_arn,
                sm_model_package_group=model_package_group,
                link_method="AUTO_TAGGED"
            )
            publish_event("MLM.Registry.Linked", {
                "model_id": mlm_model_id,
                "sm_model_package_arn": model_package_arn
            })
            return {"status": "LINKED", "model_id": mlm_model_id}
        else:
            # Model ID tag present but no matching MLM project
            return handle_unlinked(model_package_arn, model_package_group,
                                   reason="MODEL_ID_NOT_FOUND")
    else:
        # No MLM tags at all
        return handle_unlinked(model_package_arn, model_package_group,
                               reason="NO_MLM_TAGS")


def handle_unlinked(model_package_arn, model_package_group, reason):
    """Creates unlinked alert in MLM and remediation task."""

    # Create unlinked registration record in MLM
    mlm_api.create_unlinked_registration(
        sm_model_package_arn=model_package_arn,
        sm_model_package_group=model_package_group,
        detection_reason=reason,
        remediation_sla_days=5
    )

    # Publish event to MLM event bus
    publish_event("MLM.Registry.Unlinked", {
        "sm_model_package_arn": model_package_arn,
        "sm_model_package_group": model_package_group,
        "reason": reason
    })

    # Notify MLOps team
    notify_team(
        channel="mlops-alerts",
        message=f"⚠ Unlinked SM registration detected: {model_package_group}. "
                f"Please link to an MLM project within 5 business days."
    )

    return {"status": "UNLINKED", "reason": reason}
```

### 11.4 Manual Linkage UI

When an unlinked SM registration is detected, the MLM UI surfaces a linkage workflow:

```
Unlinked Registrations — Compliance Action Required

┌────────────────────────────────────────────────────────────────────────┐
│ SM Model Package Group  │ Detected        │ SLA       │ Action         │
├────────────────────────────────────────────────────────────────────────┤
│ fraud-scorer-v2-mpg     │ 2024-11-10      │ 2 days ⚠  │ [Link to MLM]  │
│ churn-pred-experimental │ 2024-11-14      │ 4 days    │ [Link to MLM]  │
└────────────────────────────────────────────────────────────────────────┘

[Link to MLM] flow:
  1. Select existing MLM project  OR  "Create new MLM project for this"
  2. Confirm version mapping:
     SM Model Package Group: fraud-scorer-v2-mpg
     → Links to MLM Project: Fraud Transaction Scorer (MOD-2024-00387)
     → MLM Version: 2.0.0 (create new) / 1.3.0 (link to existing)
  3. MLM applies tags to SM Model Package retroactively
  4. Sync job runs to align registry records
  5. Unlinked alert resolved
```

---

## 12. Bi-Directional Sync Design

### 12.1 SM → MLM Sync (SageMaker is source)

```
Trigger: SageMaker EventBridge event (Model Package status change)

Lambda: mlm-sm-to-mlm-sync

Flow:
  1. Receive SM EventBridge event
  2. Identify MLM model via mlm:model-id tag on SM Model Package
  3. Map SM state to MLM registry update:
     
     SM Event                    MLM Action
     ─────────────────────────────────────────────────────
     ModelPackage COMPLETED      Update sm_model_package_arn in registry
                                 Set sm_approval_status = PendingManualApproval
                                 Update sync_status, last_synced_at

     ModelPackage Approved       Add informational note to MLM Dev stage
                                 (SM approval ≠ MLM validation approval)
                                 Update sm_approval_status = Approved

     ModelPackage Rejected       Add note to MLM Dev stage
                                 If no MLM validation: set sync_status = SM_AHEAD

     New version in SM MPG       If linked: check if MLM version exists
                                 → Yes: link and sync
                                 → No: create unlinked alert (new version
                                       registered without MLM tracking)

  4. Update mlm_registry.business_model_registry
  5. Write to mlm_registry.registry_sync_log
  6. If conflict detected: set sync_status = CONFLICT → notify MLOps
```

### 12.2 MLM → SM Sync (MLM is source)

```
Trigger: MLM EventBridge event (governance status change)

Lambda: mlm-to-sm-sync

Flow:
  1. Receive MLM EventBridge event
  2. Look up linked SM Model Package ARN from business_model_registry
  3. Apply changes to SM Model Package:

     MLM Event                   SM Action
     ─────────────────────────────────────────────────────
     MLM.Validation.Approved     Add/update SM Model Package tags:
                                   mlm:validation-status = validated
                                   mlm:last-validated-date = {date}
                                   mlm:validator = {user_id}
                                 Add metadata to SM Model Package description

     MLM.Validation.Rejected     Add/update SM tags:
                                   mlm:validation-status = rejected
                                 Add note to SM Model Package description

     MLM.Version.StatusChanged   Update corresponding SM tag:
       → SUPERSEDED              mlm:validation-status = superseded
       → RETIRED                 Update SM ModelPackage approval_status
                                   → Rejected (prevents SM-native deployment)
                                 Add/update tag:
                                   mlm:environment = retired

     MLM.Retirement.Completed    SM ModelPackage → Rejected status
                                 Tags updated: mlm:environment = retired
                                 Metadata note: "Retired via MLM {date}"

  4. Update sync_status = IN_SYNC, last_synced_at
  5. Write to registry_sync_log
```

### 12.3 Sync Lambda Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Sync Lambda Design                                │
│                                                                     │
│  EventBridge Event                                                  │
│       │                                                             │
│       ▼                                                             │
│  mlm-registry-sync-router (Lambda)                                  │
│  ├── Determine sync direction (SM→MLM or MLM→SM)                   │
│  ├── Look up registry entry (business_model_registry)               │
│  ├── Validate preconditions                                          │
│  │   (e.g., SM link exists before attempting SM update)             │
│  ├── Execute sync operation                                          │
│  │   ├── SM→MLM: call MLM Registry Service API                     │
│  │   └── MLM→SM: call SageMaker Boto3 API                         │
│  ├── Handle errors:                                                  │
│  │   ├── Retryable (SM throttling): raise → SQS retry              │
│  │   └── Non-retryable (no SM link): log + notify                  │
│  ├── Write sync log entry                                            │
│  └── Publish sync result event to EventBridge                       │
│                                                                     │
│  Error handling:                                                    │
│  SQS with DLQ (mlm-prod-registry-sync-dlq)                         │
│  Max retries: 3 (exponential backoff: 30s, 90s, 270s)              │
│  DLQ depth alert: CloudWatch → PagerDuty on depth > 0              │
└─────────────────────────────────────────────────────────────────────┘
```

### 12.4 Scheduled Reconciliation Job

In addition to event-driven sync, a **scheduled reconciliation job** runs every 4 hours to detect and resolve drift between SM and MLM registries that may have been missed by event-driven sync (e.g., due to Lambda failures or missed events):

```
Reconciliation Job (every 4 hours, Celery beat)

For each entry in business_model_registry where sm_model_package_arn IS NOT NULL:

  1. Fetch current SM Model Package state via Boto3
  2. Compare against MLM registry entry:
     - sm_approval_status matches?
     - mlm:validation-status tag matches MLM validation status?
     - mlm:environment tag matches MLM deployment status?

  3. If drift detected:
     → Set sync_status = CONFLICT or MLM_AHEAD or SM_AHEAD
     → Log to registry_sync_log with before/after states
     → Apply MLM-authoritative values to SM (MLM wins)
     → Send drift notification to MLOps team

  4. Update last_synced_at, sync_status = IN_SYNC on success

SLA: All drift resolved within 4 hours of occurrence
     Persistent conflicts (> 24 hours) → escalate to Risk Officer
```

---

## 13. Conflict Resolution & Source of Truth

### 13.1 Conflict Decision Matrix

| Conflict Scenario | Resolution | Authority | Action |
|------------------|------------|-----------|--------|
| SM says model is Approved; MLM says NOT_VALIDATED | MLM wins | MLM | Apply NOT_VALIDATED tag to SM; DES returns INELIGIBLE |
| MLM says VALIDATED; SM says Rejected | MLM wins for governance; SM wins for SM-native deployments | Split | MLM updates tags; log conflict; notify MLOps |
| SM has a new version; MLM has no matching version | SM wins (new version registered) | SM | Create unlinked alert in MLM; require linkage |
| MLM retires model; SM still shows Approved | MLM wins | MLM | Force SM ModelPackage to Rejected; apply retired tags |
| SM ModelPackage deleted; MLM has record | MLM wins (retains record) | MLM | Set sm_model_package_arn = NULL; log deletion; notify |
| Sync job failed; registry out of sync > 4 hours | Reconciliation job corrects | MLM | Auto-correct on next reconciliation run |

### 13.2 Authority Boundary Statement

```
┌─────────────────────────────────────────────────────────────────────┐
│ MLM IS AUTHORITATIVE FOR:                                           │
│  • Whether a model is validated and deployment-eligible             │
│  • Risk tier and regulatory classification                          │
│  • Retirement decisions (MLM retirement overrides SM approval)      │
│  • Business owner and stakeholder attribution                       │
│  • Validation evidence and findings                                 │
│  • Version lineage and parentage                                    │
│                                                                     │
│ SAGEMAKER IS AUTHORITATIVE FOR:                                     │
│  • Model artifact storage URI (S3 location of model files)          │
│  • Container image URI for inference                                │
│  • Inference specification and serving configuration                │
│  • SageMaker-native deployment configurations                       │
│  • Training job metadata and compute configuration                  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 14. Future Registry Extensions

### 14.1 Databricks Unity Catalog

When Databricks is added as a development platform:

```
Sync Pattern: Identical to SM pattern but using Databricks REST API

Trigger:     Databricks model registered in Unity Catalog
             → EventBridge (via Databricks webhook → API Gateway → EventBridge)

Lambda:      mlm-databricks-uc-sync

Linkage:     mlm:model-id tag on Unity Catalog model
             OR manual linkage via MLM UI

business_model_registry additions:
  databricks_model_name      TEXT  (Unity Catalog model name)
  databricks_model_version   INTEGER
  databricks_model_uri       TEXT  (models:/model-name/version)
  databricks_workspace_url   TEXT
```

### 14.2 MLflow OSS Model Registry

```
Sync Pattern: Polling-based (MLflow does not emit EventBridge events natively)

Polling Job:  Every 5 minutes, poll MLflow registered models API
              GET {tracking_uri}/api/2.0/mlflow/registered-models/search

Linkage:      MLflow registered model tag: mlm.model-id
              MLflow run tag: mlm.project-id

business_model_registry additions:
  mlflow_registered_model_name TEXT
  mlflow_model_version         INTEGER
  mlflow_model_uri             TEXT  (models:/name/version)
  mlflow_tracking_uri          TEXT
```

### 14.3 Azure ML Model Registry

```
Sync Pattern: Azure EventGrid events → Azure Function → MLM API

Trigger:      Azure ML model registered event
              → Azure EventGrid → Azure Function → POST /api/v1/registry/sync

Linkage:      Azure ML model tag: mlm-model-id (same taxonomy)

business_model_registry additions:
  azure_ml_model_name         TEXT
  azure_ml_model_version      INTEGER
  azure_ml_workspace_id       TEXT
  azure_ml_model_uri          TEXT
```

### 14.4 Extension Pattern

All future registries follow the same pattern:

```
1. External registry emits event (EventBridge, EventGrid, webhook, or polling)
2. MLM sync Lambda receives event
3. Lambda checks mlm:model-id tag for linkage
4. LINKED → sync registry record
   UNLINKED → create unlinked alert + remediation task
5. MLM publishes governance events back to external registry
6. Scheduled reconciliation catches missed events
7. business_model_registry extended with new platform columns
```

---

## 15. Error Handling & Observability

### 15.1 Error Categories

| Error Category | Examples | Handling |
|----------------|---------|---------|
| **Transient — retry** | EventBridge delivery failure, SM API throttling, MLM API timeout | Automatic retry with exponential backoff (managed by EventBridge + SQS) |
| **Provisioning failure** | ServiceNow unavailable, callback timeout | DLQ; admin alert; manual fallback triggered |
| **Sync conflict** | SM and MLM states irreconcilable | Log conflict; notify MLOps; MLM authority applied; escalate if persistent |
| **Unlinked registration** | SM model registered without MLM tags | Unlinked alert created; remediation SLA started; MLOps notified |
| **Tag non-compliance** | Required tags missing on resource | Config rule triggers; MLM Tag Compliance Dashboard updated; owner notified |
| **Callback timeout** | Provisioning tool does not call back within SLA | After 24h: alert admin; auto-move to PENDING_ENVIRONMENT; manual resolution |

### 15.2 Monitoring Metrics

| Metric | Source | Alert Threshold |
|--------|--------|----------------|
| `mlm.provisioning.events.published` | CloudWatch custom metric | — |
| `mlm.provisioning.callbacks.received` | CloudWatch | — |
| `mlm.provisioning.callbacks.timedout` | CloudWatch | > 0 in 1 hour → notify admin |
| `mlm.registry.sync.lag_minutes` | CloudWatch | > 30 min WARNING; > 120 min CRITICAL |
| `mlm.registry.unlinked.count` | CloudWatch | > 0 → notify MLOps |
| `mlm.registry.conflicts.active` | CloudWatch | > 0 WARNING; > 5 CRITICAL |
| `mlm.tags.noncompliant.count` | AWS Config | > 0 Tier 1-2 → CRITICAL |
| `mlm.sync.lambda.errors` | CloudWatch Lambda | > 5/hr → notify MLOps |
| `mlm.sync.dlq.depth` | CloudWatch SQS | > 0 → PagerDuty |

### 15.3 Integration Health Dashboard

A dedicated **Integration Health Dashboard** in MLM (Admin → Integration Health):

```
Integration Health
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Environment Provisioning
  ServiceNow Adapter:        ✅ Active  |  Last event: 2 min ago
  Pending callbacks:         3          |  Oldest: 4 hours ⚠
  Failed (DLQ):              0

Registry Synchronization
  SM → MLM sync:             ✅ Healthy  |  Lag: < 1 min
  MLM → SM sync:             ✅ Healthy  |  Lag: < 1 min
  Unlinked registrations:    2           |  [View & Resolve]
  Active conflicts:          0
  Last reconciliation:       12 min ago  |  Drift found: 0

Tag Compliance
  Compliant resources:       1,189 / 1,247  (95.3%)
  Non-compliant (Tier 1-2):  0               ✅
  Non-compliant (Tier 3-4):  58              ⚠  [View Details]
  Unregistered resources:    12              ⚠  [View Details]
```

---

## 16. Security Considerations

### 16.1 EventBridge Security

```
Custom Bus Resource Policy:
  Allow: events:PutEvents
  Principal: arn:aws:iam::{mlm-account}:role/mlm-backend-role
  Deny: all others (explicit deny on cross-account unless authorized)

API Destination Credentials:
  Stored in: AWS Secrets Manager
  Path:      mlm/integrations/{tool-name}/api-key
  Rotation:  Every 90 days (automated where supported)
  Access:    EventBridge service role only (no application runtime access)

Callback Token:
  Generated per provisioning request (not reusable)
  Stored in: Secrets Manager (TTL: 48 hours)
  One-time use: invalidated after first successful callback
  Validation: MLM validates token + correlation_id match
```

### 16.2 SM Integration IAM

```
Lambda Execution Role: mlm-sync-lambda-role
Permissions:
  sagemaker:DescribeModelPackage
  sagemaker:ListModelPackages
  sagemaker:UpdateModelPackage (for status updates on retirement)
  sagemaker:AddTags (for tag enrichment)
  sagemaker:ListTags
  resourcegroupstaggingapi:GetResources
  resourcegroupstaggingapi:TagResources

Explicitly DENIED:
  sagemaker:DeleteModelPackage
  sagemaker:DeleteModelPackageGroup
  sagemaker:CreateEndpoint
  (MLM sync role cannot create or delete SM resources)
```

### 16.3 Cross-Account Tag Access

For organizations where the MLM platform account differs from the model development AWS account:

```
Model Dev Account (987654321098)
  Resource-based policy on SM Model Package Group:
    Allow: sagemaker:ListTags, sagemaker:AddTags, sagemaker:DescribeModelPackage
    Principal: arn:aws:iam::{mlm-account}:role/mlm-sync-lambda-role
    Condition: aws:SourceAccount = {mlm-account}

MLM Platform Account (123456789012)
  Lambda assumes cross-account role:
    sts:AssumeRole → arn:aws:iam::{dev-account}:role/MLM-CrossAccount-Access
    External ID: {mlm-installation-id}  (prevents confused deputy attack)
```

---

*End of Integration Design Document*  
*MLM Platform — IDD v1.0*
