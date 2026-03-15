# Storage Architecture Document (SAD)
## Model Lifecycle Management (MLM) Platform

**Document ID:** MLM-SAD-001  
**Version:** 1.0  
**Status:** Draft  
**Classification:** Internal — Confidential  

**Related Documents:**
- `MLM-SRD-001` — System Requirements Document
- `MLM-FRD-001` — Functional Requirements Document
- `MLM-NFR-001` — NFR, Roles, Vendor & GenAI Supplement

---

## Document Control

| Version | Date | Author | Change Description |
|---------|------|--------|-------------------|
| 1.0 | 2024-Q4 | Architecture Team | Baseline release |

### Review & Approval

| Role | Name | Status |
|------|------|--------|
| Enterprise Architect | TBD | Pending |
| Cloud Infrastructure Lead | TBD | Pending |
| Security Architect | TBD | Pending |
| DBA / Data Engineer | TBD | Pending |
| FinOps Lead | TBD | Pending |

---

## Table of Contents

1. [Overview & Principles](#1-overview--principles)
2. [Storage Landscape](#2-storage-landscape)
3. [Object Storage — Amazon S3](#3-object-storage--amazon-s3)
4. [Relational Database — Aurora PostgreSQL](#4-relational-database--aurora-postgresql)
5. [Time-Series Storage — Amazon Timestream](#5-time-series-storage--amazon-timestream)
6. [Search Engine Storage — Amazon OpenSearch](#6-search-engine-storage--amazon-opensearch)
7. [Cache — Amazon ElastiCache for Redis](#7-cache--amazon-elasticache-for-redis)
8. [Message Queue Storage — Amazon SQS](#8-message-queue-storage--amazon-sqs)
9. [Artifact Storage Design](#9-artifact-storage-design)
10. [Backup & Recovery Storage](#10-backup--recovery-storage)
11. [Multi-Region Storage Strategy](#11-multi-region-storage-strategy)
12. [Storage Security](#12-storage-security)
13. [Storage Lifecycle & Retention](#13-storage-lifecycle--retention)
14. [Storage Sizing & Capacity Planning](#14-storage-sizing--capacity-planning)
15. [Cost Optimization Strategy](#15-cost-optimization-strategy)
16. [Storage Monitoring & Alerting](#16-storage-monitoring--alerting)

---

## 1. Overview & Principles

### 1.1 Purpose

This document defines the complete storage architecture for the MLM platform, covering object storage, relational databases, time-series storage, search indexes, caching, message queues, and artifact management. It establishes bucket/index/schema designs, lifecycle policies, access patterns, sizing estimates, security controls, and cost optimization strategies.

### 1.2 Storage Architecture Principles

| Principle | Description |
|-----------|-------------|
| **Separation of metadata and artifacts** | MLM stores governance metadata internally; raw artifact files (model weights, notebooks, evidence files) are stored in S3 with MLM holding only the reference URI and content hash |
| **Tiered storage by access frequency** | Hot data (active projects, recent metrics) in high-performance stores; warm data (completed projects, older metrics) in lower-cost tiers; cold data (audit archives, retired models) in glacier/deep archive |
| **Immutability for compliance data** | Audit logs and validated model snapshots use S3 Object Lock and database-level write protection to prevent tampering |
| **Right-sizing by data type** | Each data category uses the purpose-built store best suited to its access patterns — time-series data in Timestream, not PostgreSQL; full-text search in OpenSearch, not Postgres text search |
| **Encryption everywhere** | All data encrypted at rest (AES-256, KMS CMK where applicable) and in transit (TLS 1.3) — no exceptions |
| **Cost visibility** | Each S3 bucket, database, and storage tier is tagged for cost allocation, enabling per-customer and per-feature cost tracking |
| **No data loss on failure** | All storage tiers use replication, Multi-AZ, or equivalent durability mechanisms; RPO < 5 minutes for transactional data |

### 1.3 Storage Technology Selection Rationale

| Store | Selected Technology | Rejected Alternatives | Rationale |
|-------|--------------------|-----------------------|-----------|
| Relational DB | Aurora PostgreSQL | MySQL, CockroachDB, DynamoDB | ACID transactions critical for workflow state + audit; PostgreSQL row-level security for immutability enforcement; Aurora provides managed HA/failover |
| Time-series | Amazon Timestream | InfluxDB, TimescaleDB, Prometheus + Thanos | Serverless scaling, native AWS integration, automatic tiering (memory → magnetic), no cluster management overhead |
| Search | Amazon OpenSearch | Elasticsearch (self-hosted), Typesense, Algolia | Managed service, native AWS IAM auth, VPC support, compatible with Elasticsearch client libraries |
| Cache | ElastiCache Redis | Memcached, DynamoDB DAX | Redis supports complex data structures (sorted sets for leaderboards, hashes for DES cache), pub/sub for real-time notifications, cluster mode for HA |
| Object store | Amazon S3 | Azure Blob, GCS, MinIO | Platform default; S3 Object Lock for compliance; S3 Intelligent-Tiering for cost optimization; cross-region replication built-in |
| Message queue | Amazon SQS | RabbitMQ, Kafka, ActiveMQ | Managed service, no infrastructure overhead; FIFO queues for ordered workflow events; SQS scales transparently; Kafka added only if throughput exceeds SQS limits |

---

## 2. Storage Landscape

### 2.1 Storage Map by Data Category

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                         MLM STORAGE LANDSCAPE                                    │
│                                                                                  │
│  TRANSACTIONAL DATA                    ANALYTICAL / TIME-SERIES DATA            │
│  ┌─────────────────────────────┐       ┌──────────────────────────────────┐     │
│  │   Aurora PostgreSQL          │       │      Amazon Timestream            │     │
│  │                             │       │                                  │     │
│  │  • Model projects           │       │  • Monitoring metrics            │     │
│  │  • Model versions           │       │  • Alert history                 │     │
│  │  • Stage records            │       │  • LLM evaluation metrics        │     │
│  │  • Workflow state           │       │  • Performance trends            │     │
│  │  • Approvals / findings     │       │                                  │     │
│  │  • User / role records      │       └──────────────────────────────────┘     │
│  │  • Integration configs      │                                                │
│  │  • Audit log (append-only)  │       SEARCH INDEX                            │
│  │  • Notification log         │       ┌──────────────────────────────────┐     │
│  └─────────────────────────────┘       │      Amazon OpenSearch           │     │
│                                        │                                  │     │
│  CACHE                                 │  • Model project full-text       │     │
│  ┌─────────────────────────────┐       │  • Artifact metadata             │     │
│  │   ElastiCache Redis          │       │  • Audit log search index        │     │
│  │                             │       │  • Vendor model catalog          │     │
│  │  • DES eligibility cache    │       └──────────────────────────────────┘     │
│  │  • API session tokens       │                                                │
│  │  • Rate limit counters      │       ASYNC MESSAGING                         │
│  │  • WebSocket presence       │       ┌──────────────────────────────────┐     │
│  │  • Short-lived query cache  │       │         Amazon SQS               │     │
│  └─────────────────────────────┘       │                                  │     │
│                                        │  • Workflow events (FIFO)        │     │
│  OBJECT STORAGE                        │  • Monitoring ingest queue       │     │
│  ┌─────────────────────────────┐       │  • Notification dispatch queue   │     │
│  │         Amazon S3            │       │  • Integration sync queue        │     │
│  │                             │       │  • Dead-letter queues (DLQ)      │     │
│  │  Bucket per purpose:        │       └──────────────────────────────────┘     │
│  │  • Artifacts                │                                                │
│  │  • Reports                  │                                                │
│  │  • Audit archive            │                                                │
│  │  • Frontend assets          │                                                │
│  │  • Temp / presigned uploads │                                                │
│  └─────────────────────────────┘                                                │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Data Flow to Storage

```
User Action / External Event
         │
         ▼
   MLM Backend API
         │
         ├──► Aurora PostgreSQL    (governance metadata, workflow state, audit)
         │
         ├──► SQS Queue           (async tasks: notifications, sync jobs)
         │         │
         │         ▼
         │    Worker Pool
         │         │
         │         ├──► Timestream   (monitoring metrics processed by workers)
         │         ├──► OpenSearch   (search index updates)
         │         └──► SQS          (downstream events)
         │
         ├──► S3 (presigned URL)   (artifact files uploaded directly by client)
         │
         └──► ElastiCache Redis    (cache invalidation on state changes)
```

---

## 3. Object Storage — Amazon S3

### 3.1 Bucket Architecture

MLM uses **purpose-specific S3 buckets** rather than a single bucket with prefix separation. This enables independent bucket policies, lifecycle rules, Object Lock configurations, and access controls per data category.

#### 3.1.1 Bucket Inventory

| Bucket Name Pattern | Purpose | Object Lock | Versioning | Replication |
|---------------------|---------|-------------|------------|-------------|
| `mlm-{env}-artifacts` | Model artifacts, validation evidence, uploaded documents | Off | Enabled | Cross-region |
| `mlm-{env}-reports` | Generated compliance reports, audit exports, inventory exports | Off | Enabled | Cross-region |
| `mlm-{env}-audit-archive` | Long-term audit log archive (Parquet) | COMPLIANCE (10yr) | Enabled | Cross-region |
| `mlm-{env}-frontend` | Static frontend SPA assets (CloudFront origin) | Off | Off | Off |
| `mlm-{env}-upload-staging` | Temporary presigned upload landing zone | Off | Off | Off |
| `mlm-{env}-integration-cache` | MLflow sync cache, platform adapter output files | Off | Off | Off |
| `mlm-{env}-backups` | Aurora manual snapshots exported, Timestream exports | Off | Enabled | Cross-region |
| `mlm-{env}-terraform-state` | Terraform remote state | Off | Enabled | Cross-region |

`{env}` = `prod` | `staging` | `dev`

#### 3.1.2 Bucket Naming Convention

```
mlm-{env}-{purpose}[-{region-suffix}]

Examples:
  mlm-prod-artifacts
  mlm-prod-audit-archive
  mlm-staging-artifacts
  mlm-prod-reports-eu-west-1   ← cross-region replica bucket
```

All bucket names are globally unique — use organization prefix if needed:
```
  {org}-mlm-prod-artifacts
```

#### 3.1.3 Bucket Configuration Details

**`mlm-{env}-artifacts`**
```
Purpose:         Stores all user-uploaded artifact files associated with model
                 project lifecycle stages (validation evidence, notebooks, model
                 cards, deployment plans, runbooks, etc.)
                 
Versioning:      Enabled — preserves prior versions of overwritten artifacts
                 (rare but possible for updated documents)
                 
Object Lock:     Disabled (artifacts may need to be superseded;
                 immutability enforced at metadata level in Aurora)
                 
Encryption:      SSE-KMS (CMK: mlm-artifacts-key)

CORS:            Configured for presigned URL direct uploads from MLM frontend
                 (AllowedOrigins: MLM domain only)

Public Access:   All public access blocked

Access:          MLM Backend role (presigned URL generation only)
                 Direct client upload via presigned POST (15-minute expiry)

Lifecycle Rules:
  - Incomplete multipart uploads → abort after 2 days
  - Objects tagged retention:short → expire after 30 days
                 (used for temp files, superseded drafts)
  - Objects not accessed in 90 days → transition to S3 IA
  - Objects not accessed in 365 days → transition to S3 Glacier IR
  - Non-current versions → expire after 90 days
```

**`mlm-{env}-audit-archive`**
```
Purpose:         Long-term archive of audit log records exported from Aurora
                 PostgreSQL as Parquet files for cost-effective retention
                 and Athena-based compliance queries.

Versioning:      Enabled

Object Lock:     COMPLIANCE mode, 10-year retention
                 (Objects cannot be deleted or modified by anyone,
                 including the AWS account root)

Encryption:      SSE-KMS (CMK: mlm-audit-key — separate key from artifacts)

Public Access:   All public access blocked

Access:          MLM Audit Archival Job role (PutObject only)
                 Auditor role (GetObject, via IAM policy scoped to Athena)
                 No application runtime role has GetObject access
                 (audit archive is for compliance queries only)

Lifecycle Rules:
  - No transitions (Object Lock prevents deletion;
    retain on COMPLIANCE tier for full 10 years)
  - After 10 years: Object Lock expires →
    transition to S3 Glacier Deep Archive
```

**`mlm-{env}-reports`**
```
Purpose:         Generated reports: SR 11-7 compliance packages, model
                 inventory exports, validation summary PDFs, retirement reports.

Versioning:      Enabled (track report regenerations)

Object Lock:     Disabled (reports are regenerable)

Encryption:      SSE-KMS (CMK: mlm-reports-key)

Public Access:   Blocked

Access:          MLM Backend role (PutObject for generation)
                 Authenticated users via presigned GET URL (15-minute expiry)
                 Auditor and Compliance Manager roles (broader access)

Lifecycle Rules:
  - Reports not accessed in 180 days → S3 IA
  - Reports not accessed in 365 days → S3 Glacier IR
  - Non-current versions expire after 30 days
```

**`mlm-{env}-upload-staging`**
```
Purpose:         Temporary landing zone for presigned POST uploads before
                 the backend processes and moves the file to the artifacts bucket.

Versioning:      Disabled

Object Lock:     Disabled

Encryption:      SSE-S3 (standard; temporary files)

Public Access:   Blocked

Access:          MLM Backend role (GetObject, DeleteObject for post-processing)
                 Direct client upload via presigned POST

Lifecycle Rules:
  - All objects expire after 2 days
    (any object not processed within 2 days is automatically deleted)
  - Incomplete multipart uploads → abort after 1 day
```

**`mlm-{env}-frontend`**
```
Purpose:         Static frontend SPA assets (HTML, JS, CSS bundles).
                 Origin for CloudFront distribution.

Versioning:      Disabled (CloudFront cache invalidation handles updates)

Object Lock:     Disabled

Encryption:      SSE-S3

Public Access:   Blocked (CloudFront OAC — Origin Access Control — only)

Access:          CloudFront OAC (GetObject)
                 CI/CD deployment role (PutObject, DeleteObject)

Lifecycle Rules:
  - No lifecycle rules (assets replaced on each deployment)
```

### 3.2 S3 Prefix Structure

#### 3.2.1 Artifacts Bucket Prefix Design

```
mlm-{env}-artifacts/
├── projects/
│   └── {model_id}/                          ← e.g., MOD-2024-00421/
│       ├── versions/
│       │   └── {version}/                   ← e.g., 1.2.0/
│       │       ├── inception/
│       │       │   ├── {artifact_id}-project-charter.pdf
│       │       │   └── {artifact_id}-risk-assessment.pdf
│       │       ├── development/
│       │       │   ├── {artifact_id}-model-card-draft.md
│       │       │   └── {artifact_id}-dev-plan.docx
│       │       ├── validation/
│       │       │   ├── {artifact_id}-validation-report.pdf
│       │       │   ├── {artifact_id}-test-evidence-notebook.ipynb
│       │       │   └── findings/
│       │       │       └── {finding_id}-evidence.pdf
│       │       ├── implementation/
│       │       │   ├── {artifact_id}-deployment-plan.pdf
│       │       │   └── {artifact_id}-runbook.md
│       │       └── retirement/
│       │           └── {artifact_id}-retirement-report.pdf
│       └── shared/                          ← project-level shared docs
│           └── {artifact_id}-stakeholder-registry.xlsx
└── vendor/
    └── {vendor_model_id}/
        └── {artifact_id}-vendor-due-diligence.pdf
```

#### 3.2.2 Reports Bucket Prefix Design

```
mlm-{env}-reports/
├── compliance/
│   ├── sr117/
│   │   └── {year}/
│   │       └── {report_id}-sr117-package-{model_id}.pdf
│   └── eu-ai-act/
│       └── {year}/
│           └── {report_id}-eu-ai-act-{model_id}.pdf
├── inventory/
│   └── {year}/
│       └── {month}/
│           └── {report_id}-model-inventory-{date}.csv
├── validation-summaries/
│   └── {model_id}/
│       └── {version}/
│           └── {report_id}-validation-summary.pdf
└── retirement/
    └── {model_id}/
        └── {report_id}-retirement-report.pdf
```

#### 3.2.3 Audit Archive Bucket Prefix Design

```
mlm-{env}-audit-archive/
└── audit-log/
    └── year={YYYY}/
        └── month={MM}/
            └── day={DD}/
                └── audit-{YYYY-MM-DD}-{shard}.parquet
                    ← Hive-partitioned for efficient Athena queries
                    ← Each file: ~100k audit records, ~50MB compressed
```

### 3.3 S3 Access Patterns

| Access Pattern | Mechanism | TTL / Notes |
|----------------|-----------|-------------|
| User uploads artifact file | Presigned POST URL (backend generates, client uploads directly) | 15-minute URL expiry; max file size: 500MB enforced via presigned POST policy |
| User downloads artifact file | Presigned GET URL (backend generates on request) | 15-minute URL expiry; URL logged in audit |
| Backend reads artifact for processing | IAM role (s3:GetObject via VPC endpoint) | No internet egress; VPC endpoint enforced via bucket policy |
| Compliance report download | Presigned GET URL with role check | 60-minute expiry; scoped to Auditor / Compliance Manager roles |
| Audit archive Athena query | Athena + Glue Data Catalog | Auditor role assumed; queries logged in CloudTrail |
| Frontend asset delivery | CloudFront OAC → S3 | CDN cached; no direct S3 access |
| CI/CD deployment | IAM role (s3:PutObject, s3:DeleteObject on frontend bucket) | Pipeline role; MFA delete on bucket for additional protection |

### 3.4 S3 VPC Endpoint Configuration

All S3 access from MLM application tiers (EKS pods, Lambda functions) shall use **S3 Gateway VPC Endpoints** — traffic does not traverse the public internet:

```
VPC → S3 Gateway Endpoint → S3 (private routing)

Bucket Policy Condition (enforces VPC-only access for artifact/audit buckets):
{
  "Condition": {
    "StringNotEquals": {
      "aws:SourceVpc": "vpc-{mlm-vpc-id}"
    }
  },
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:*",
  "Resource": [
    "arn:aws:s3:::mlm-prod-artifacts",
    "arn:aws:s3:::mlm-prod-artifacts/*",
    "arn:aws:s3:::mlm-prod-audit-archive",
    "arn:aws:s3:::mlm-prod-audit-archive/*"
  ]
}
```

Exception: Presigned URLs for external users (uploaders/downloaders) bypass this condition via the presigned URL mechanism — the restriction applies to IAM role-based API calls only.

---

## 4. Relational Database — Aurora PostgreSQL

### 4.1 Cluster Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│              Aurora PostgreSQL Cluster — Primary Region             │
│                                                                     │
│  ┌──────────────────┐   ┌──────────────────┐  ┌────────────────┐   │
│  │  Writer Instance │   │  Reader 1         │  │  Reader 2      │   │
│  │  (r6g.2xlarge)   │   │  (r6g.2xlarge)   │  │  (r6g.xlarge)  │   │
│  │                  │   │                  │  │                │   │
│  │  Accepts:        │   │  Serves:         │  │  Serves:       │   │
│  │  • All writes    │   │  • API reads     │  │  • DES queries │   │
│  │  • Workflow state│   │  • Search sync   │  │  • Report gen  │   │
│  │  • Audit inserts │   │  • Dashboards    │  │                │   │
│  └──────────────────┘   └──────────────────┘  └────────────────┘   │
│                                                                     │
│  Cluster Endpoint:  mlm-cluster.cluster-{id}.{region}.rds.amazonaws.com  │
│  Reader Endpoint:   mlm-cluster.cluster-ro-{id}.{region}.rds.amazonaws.com│
│  Storage:           Aurora Serverless v2 auto-scaling (min 2 ACU, max 128 ACU)│
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │  Aurora Global Database replication
                              │  (< 1 second replication lag)
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│              Aurora PostgreSQL Cluster — DR Region                  │
│                                                                     │
│  ┌──────────────────┐   ┌──────────────────┐                       │
│  │  Secondary Writer│   │  Reader (DR)      │                       │
│  │  (r6g.2xlarge)   │   │  (r6g.xlarge)    │                       │
│  │  (standby; read- │   │  (DES failover   │                       │
│  │   only normally) │   │   target)         │                       │
│  └──────────────────┘   └──────────────────┘                       │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 Instance Sizing

| Instance | Type | vCPU | RAM | Purpose | Notes |
|----------|------|------|-----|---------|-------|
| Writer | r6g.2xlarge | 8 | 64 GB | All writes + complex queries | Graviton2; memory-optimized for PG shared buffers |
| Reader 1 | r6g.2xlarge | 8 | 64 GB | API reads, search sync | Same size as writer for burst headroom |
| Reader 2 | r6g.xlarge | 4 | 32 GB | DES queries, report generation | Lighter workload; separate endpoint |
| DR Writer | r6g.2xlarge | 8 | 64 GB | Standby; promotes on failover | Matches primary writer |
| DR Reader | r6g.xlarge | 4 | 32 GB | DES failover reads | Pre-configured as DES secondary target |

Aurora Serverless v2 auto-scaling (ACU range: 2–128) is used for storage — no pre-provisioning required. Storage scales automatically in 10 GB increments.

### 4.3 PostgreSQL Configuration

**Key Parameter Group Settings:**

```ini
# Memory
shared_buffers                 = 16GB          # 25% of instance RAM
effective_cache_size           = 48GB          # 75% of instance RAM
work_mem                       = 64MB          # Per sort/hash operation
maintenance_work_mem           = 2GB           # VACUUM, index builds

# Connections (managed via PgBouncer)
max_connections                = 200           # PgBouncer pool connects
                                               # (application sees unlimited via PgBouncer)

# WAL & Replication
wal_level                      = replica
max_wal_senders                = 10
wal_keep_size                  = 1GB

# Performance
random_page_cost               = 1.1           # SSD-optimized (Aurora storage)
effective_io_concurrency       = 200           # SSD parallel I/O
default_statistics_target      = 250           # Better query plans

# Logging (for query analysis)
log_min_duration_statement     = 1000          # Log queries > 1s
log_checkpoints                = on
log_lock_waits                 = on
log_temp_files                 = 10240         # Log temp files > 10MB

# Immutability enforcement
row_security                   = on            # Enable RLS globally
```

### 4.4 PgBouncer Connection Pooling Configuration

```ini
[pgbouncer]
pool_mode = transaction               # Transaction-level pooling

[mlm_api_pool]
host = mlm-cluster.cluster-{id}.rds.amazonaws.com
port = 5432
dbname = mlm
pool_size = 50                        # Backend API pool
max_client_conn = 500                 # Max API connections to PgBouncer

[mlm_worker_pool]
host = mlm-cluster.cluster-{id}.rds.amazonaws.com
port = 5432
dbname = mlm
pool_size = 100                       # Worker pool (larger for batch jobs)

[mlm_des_pool]
host = mlm-cluster.cluster-ro-{id}.rds.amazonaws.com  # Reader endpoint
port = 5432
dbname = mlm
pool_size = 20                        # DES lightweight read queries
```

### 4.5 Schema Storage Allocation Estimates

| Schema | Tables | Est. Row Count (Y1) | Est. Storage (Y1) | Est. Storage (Y3) |
|--------|--------|--------------------|--------------------|-------------------|
| `mlm_core` | 12 | 5M | 15 GB | 45 GB |
| `mlm_workflow` | 8 | 10M | 8 GB | 25 GB |
| `mlm_audit` | 1 | 50M | 40 GB | 180 GB |
| `mlm_monitoring` | 6 | 2M | 3 GB | 10 GB |
| `mlm_users` | 5 | 100K | 500 MB | 1 GB |
| `mlm_integration` | 6 | 500K | 2 GB | 6 GB |
| `mlm_notifications` | 3 | 5M | 5 GB | 15 GB |
| `mlm_registry` | 4 | 1M | 2 GB | 6 GB |
| `mlm_genai` | 8 | 3M | 10 GB | 30 GB |
| `mlm_vendor` | 5 | 200K | 1 GB | 3 GB |
| **Indexes** | — | — | ~50% of table size | — |
| **Total (incl. indexes)** | — | — | **~130 GB** | **~470 GB** |

> Note: Audit log (mlm_audit) dominates storage growth — rows are never deleted, only archived to S3. Hot Aurora storage is for the recent 2-year rolling window; older records archived to S3 Parquet.

### 4.6 Audit Log Archival Job

To control Aurora storage growth, a nightly archival job exports audit records older than the hot retention threshold:

```
Archival Job (nightly, 02:00 UTC)
  1. SELECT audit records WHERE timestamp < (NOW() - INTERVAL '2 years')
     AND archived = false
     LIMIT 500,000                    ← batch to avoid long-running transaction
  2. Convert batch to Parquet (Apache Arrow)
  3. Upload to mlm-{env}-audit-archive/audit-log/year={Y}/month={M}/day={D}/
  4. UPDATE audit records SET archived = true, archive_s3_uri = {uri}
     WHERE id IN (batch_ids)
     ← archived=true records are excluded from active queries
  5. After 30-day grace period: DELETE archived records from Aurora
     ← Preserves Parquet in S3 indefinitely; frees Aurora storage
```

### 4.7 Key Indexes

```sql
-- Model project discovery
CREATE INDEX idx_model_projects_status_domain 
  ON mlm_core.model_projects(current_stage, business_domain, risk_tier);

CREATE INDEX idx_model_projects_owner 
  ON mlm_core.model_projects(owner_user_id, current_stage);

-- Version eligibility (critical for DES)
CREATE INDEX idx_model_versions_eligibility 
  ON mlm_core.model_versions(model_project_id, status, version_string);

-- Audit log queries
CREATE INDEX idx_audit_log_entity 
  ON mlm_audit.audit_log(entity_type, entity_id, timestamp DESC);

CREATE INDEX idx_audit_log_user_time 
  ON mlm_audit.audit_log(user_id, timestamp DESC);

-- Workflow approvals pending
CREATE INDEX idx_approvals_pending 
  ON mlm_workflow.approval_tasks(assigned_role, status, sla_deadline)
  WHERE status = 'PENDING';

-- Monitoring alerts active
CREATE INDEX idx_alerts_active 
  ON mlm_monitoring.alert_records(model_version_id, severity, triggered_at DESC)
  WHERE resolved_at IS NULL;

-- Version lineage traversal
CREATE INDEX idx_version_parent 
  ON mlm_core.model_versions(parent_version_id)
  WHERE parent_version_id IS NOT NULL;
```

---

## 5. Time-Series Storage — Amazon Timestream

### 5.1 Timestream Architecture

```
Timestream Database: mlm-monitoring

Tables:
├── model_metrics          ← primary monitoring metric data
├── llm_metrics            ← LLM-specific metrics (tokens, hallucination, cost)
├── infrastructure_metrics ← latency, error rate, throughput per endpoint
└── evaluation_metrics     ← LLM evaluation run results (periodic, not streaming)
```

### 5.2 Table Configurations

**`model_metrics` table:**
```
Memory Store Retention:   7 days    ← hot tier; in-memory; sub-second query
Magnetic Store Retention: 2 years   ← warm tier; SSD; second-range query latency

Dimensions (tag keys):
  model_id          ← MOD-2024-00421
  model_version     ← 1.2.0
  monitor_type      ← DATA_DRIFT | DATA_QUALITY | PERFORMANCE | BIAS
  environment       ← production | staging
  source_platform   ← SAGEMAKER_MM | EVIDENTLY | DATADOG | CUSTOM
  metric_group      ← feature_name (for per-feature drift metrics)

Measures (metric values):
  metric_value      ← DOUBLE
  sample_count      ← BIGINT
  threshold         ← DOUBLE (threshold at time of measurement)
  alert_triggered   ← BOOLEAN
```

**`llm_metrics` table:**
```
Memory Store Retention:   7 days
Magnetic Store Retention: 1 year

Dimensions:
  model_id, model_version, environment
  llm_provider      ← OPENAI | ANTHROPIC | BEDROCK | SELF_HOSTED
  base_model        ← gpt-4o | claude-3-5-sonnet | llama-3.1
  prompt_version    ← v1.2.0 (prompt registry version)

Measures:
  input_tokens          BIGINT
  output_tokens         BIGINT
  cost_usd              DOUBLE
  latency_ms            DOUBLE
  hallucination_score   DOUBLE
  toxicity_score        DOUBLE
  groundedness_score    DOUBLE
  user_feedback_score   DOUBLE
  refusal_rate          DOUBLE
```

### 5.3 Query Patterns

```sql
-- Recent drift trend for a model version (dashboard)
SELECT BIN(time, 1h) AS hour, AVG(metric_value) AS avg_drift, 
       MAX(metric_value) AS max_drift
FROM mlm-monitoring.model_metrics
WHERE model_id = 'MOD-2024-00421'
  AND model_version = '1.2.0'
  AND monitor_type = 'DATA_DRIFT'
  AND time >= ago(30d)
GROUP BY BIN(time, 1h)
ORDER BY hour DESC

-- LLM cost burn rate (budget alert evaluation)
SELECT SUM(cost_usd) AS total_cost_usd
FROM mlm-monitoring.llm_metrics
WHERE model_id = 'MOD-2024-00421'
  AND time >= date_trunc('MONTH', now())
```

### 5.4 Timestream Capacity Estimates

| Table | Write Rate (steady) | Write Rate (peak) | Memory Store Size (7d) | Magnetic Store Size (2yr) |
|-------|--------------------|--------------------|------------------------|--------------------------|
| model_metrics | 5,000 records/min | 50,000 records/min | ~50 GB | ~18 TB |
| llm_metrics | 1,000 records/min | 10,000 records/min | ~10 GB | ~3.6 TB |
| infrastructure_metrics | 2,000 records/min | 20,000 records/min | ~20 GB | ~7 TB |
| evaluation_metrics | 10 records/min | 100 records/min | ~1 GB | ~360 GB |

> Timestream pricing is per GB written and per GB stored (memory vs magnetic tiers) — no provisioning required. Magnetic store provides significant cost advantage over memory store for long-term retention.

### 5.5 Timestream Data Export for Long-Term Archive

Monitoring data older than the magnetic store retention period (2 years) is exported to S3 and queryable via Athena:

```
Timestream Scheduled Query (monthly)
  → Export metrics older than 23 months
  → Write to S3: mlm-{env}-backups/timestream-export/
      year={YYYY}/month={MM}/
      model-metrics-{YYYY-MM}.parquet
  → Register in Glue Data Catalog
  → Queryable via Athena for regulatory lookback
```

---

## 6. Search Engine Storage — Amazon OpenSearch

### 6.1 Cluster Configuration

```
Domain:          mlm-search-{env}
Engine:          OpenSearch 2.11
Instance type:   r6g.large.search (per data node)
Data nodes:      3 (Multi-AZ across 3 AZs)
Master nodes:    3 dedicated (m6g.large.search)
Storage per node: 500 GB gp3 EBS
Total storage:   1.5 TB (replicated; effective: 750 GB usable with 1 replica)
```

### 6.2 Index Design

| Index | Documents | Shards | Replicas | Refresh Interval | Notes |
|-------|-----------|--------|----------|-----------------|-------|
| `mlm-model-projects` | 50K | 3 | 1 | 30s | Main discovery index |
| `mlm-model-versions` | 500K | 5 | 1 | 30s | Version search + filter |
| `mlm-artifacts` | 2M | 5 | 1 | 60s | Artifact metadata search |
| `mlm-audit-log` | 50M | 10 | 1 | 5min | Audit search (recent 90d) |
| `mlm-vendor-models` | 10K | 2 | 1 | 60s | Vendor catalog search |
| `mlm-findings` | 500K | 3 | 1 | 30s | Validation findings search |

### 6.3 Index Mapping (Model Projects)

```json
{
  "mappings": {
    "properties": {
      "model_id":         { "type": "keyword" },
      "name":             { "type": "text", "analyzer": "standard",
                           "fields": { "keyword": { "type": "keyword" } } },
      "description":      { "type": "text", "analyzer": "standard" },
      "use_case":         { "type": "text", "analyzer": "standard" },
      "business_domain":  { "type": "keyword" },
      "risk_tier":        { "type": "integer" },
      "model_type":       { "type": "keyword" },
      "current_stage":    { "type": "keyword" },
      "current_status":   { "type": "keyword" },
      "owner_user_id":    { "type": "keyword" },
      "owner_name":       { "type": "text" },
      "tags":             { "type": "keyword" },
      "regulatory_scope": { "type": "keyword" },
      "created_at":       { "type": "date" },
      "updated_at":       { "type": "date" }
    }
  },
  "settings": {
    "number_of_shards":   3,
    "number_of_replicas": 1,
    "refresh_interval":   "30s"
  }
}
```

### 6.4 Index Lifecycle Management (ILM)

**Audit Log Index (high-volume, rolling):**
```
Policy: mlm-audit-log-ilm

Hot phase (0–90 days):
  - Index rollover: when index > 50 GB or 30M docs
  - Priority: 100 (fastest recovery)

Warm phase (90 days):
  - Move to warm nodes (lower-cost instances)
  - Force merge to 1 segment (read-only optimization)
  - Replica: 0 (reduce storage; cold data)

Delete phase (> 90 days):
  - Delete from OpenSearch
  - (Parquet archive in S3 serves long-term query needs via Athena)
```

### 6.5 OpenSearch Update Strategy

Aurora → OpenSearch synchronization uses a **change data capture (CDC) approach** via Debezium (PostgreSQL logical replication) or a worker-based polling pattern:

```
Option A (preferred): Worker-based polling
  Aurora triggers → notify SQS queue on INSERT/UPDATE to indexed tables
  Worker consumer reads SQS → upserts to OpenSearch
  Lag: < 30 seconds for model project updates

Option B: Debezium CDC (if higher consistency required)
  PostgreSQL WAL → Debezium connector → Kafka topic → OpenSearch Sink connector
  Lag: < 5 seconds
  Added complexity: requires Kafka cluster
```

---

## 7. Cache — Amazon ElastiCache for Redis

### 7.1 Cluster Configuration

```
Cluster Mode:    Enabled (3 shards × 1 replica = 6 nodes total)
Node type:       cache.r7g.large (13.07 GB RAM per node)
Total memory:    ~78 GB across cluster (39 GB effective per shard group)
Multi-AZ:        Enabled (replicas in different AZs)
Encryption:      At-rest (KMS) + in-transit (TLS)
Auth:            Redis AUTH token
Engine:          Redis 7.x
```

### 7.2 Key Space Design

All Redis keys follow a structured naming convention:

```
{namespace}:{scope}:{identifier}[:{sub-key}]
```

#### 7.2.1 DES Eligibility Cache

```
Key pattern:   des:elig:{model_id}:{version}:{environment}
Value:         JSON serialized EligibilityResult
TTL:           300 seconds (5 minutes)
Eviction:      allkeys-lru (DES cache shard)
Memory budget: ~2 GB (50K active versions × ~40KB per entry)

Example:
  Key:   des:elig:MOD-2024-00421:1.2.0:production
  Value: {
    "eligible": true,
    "status": "ELIGIBLE",
    "validation_date": "2024-11-15T10:22:00Z",
    "conditions": [],
    "cached_at": "2024-12-01T14:30:00Z"
  }
```

#### 7.2.2 Session / JWT Cache

```
Key pattern:   session:{user_id}:{token_jti}
Value:         Session metadata (last_active, roles_snapshot)
TTL:           900 seconds (15 minutes, matching JWT access token expiry)
Purpose:       Fast token validation without DB lookup on every request
Memory budget: ~500 MB (50K concurrent users × ~10KB per session)
```

#### 7.2.3 API Rate Limiting

```
Key pattern:   ratelimit:user:{user_id}:{window_minute}
               ratelimit:apikey:{api_key_id}:{window_minute}
Value:         Integer (request count)
TTL:           60 seconds (sliding window via INCR + EXPIRE)
Memory budget: Minimal (~100 MB)
```

#### 7.2.4 Query Result Cache

```
Key pattern:   qcache:{hash_of_query_params}
Value:         Serialized API response (JSON)
TTL:           Varies by endpoint:
               - /api/v1/models (list)       → 30 seconds
               - /api/v1/models/{id}         → 10 seconds
               - /api/v1/reports/inventory   → 300 seconds
               - Search results              → 60 seconds
Memory budget: ~5 GB
Eviction:      allkeys-lru
Cache invalidation: Key deleted on write to affected entity
```

#### 7.2.5 WebSocket Presence

```
Key pattern:   ws:presence:{user_id}
Value:         Set of {connection_id, subscribed_project_ids[]}
TTL:           30 seconds (refreshed on heartbeat)
Purpose:       Track which users are viewing which project stages
               for real-time update push
Memory budget: ~200 MB
```

#### 7.2.6 Worker Distributed Locks

```
Key pattern:   lock:job:{job_type}:{job_id}
Value:         {worker_id, acquired_at}
TTL:           Job-specific (e.g., 300s for MLflow sync jobs)
Purpose:       Prevent duplicate job execution across worker instances
               (Redlock pattern)
```

### 7.3 Redis Shard Allocation

| Shard | Primary Use | Memory Allocation | Eviction Policy |
|-------|-------------|------------------|----------------|
| Shard 1 | DES eligibility cache + session cache | ~13 GB | `allkeys-lru` |
| Shard 2 | Query result cache + search cache | ~13 GB | `allkeys-lru` |
| Shard 3 | Rate limiting + locks + WebSocket presence | ~5 GB | `volatile-lru` |

---

## 8. Message Queue Storage — Amazon SQS

### 8.1 Queue Inventory

| Queue Name | Type | Purpose | Visibility Timeout | Retention | DLQ |
|------------|------|---------|-------------------|-----------|-----|
| `mlm-{env}-workflow-events.fifo` | FIFO | Workflow state transition events (ordering critical) | 60s | 4 days | `mlm-{env}-workflow-events-dlq.fifo` |
| `mlm-{env}-monitoring-ingest` | Standard | Monitoring metric payloads from ingest API | 300s | 4 days | `mlm-{env}-monitoring-ingest-dlq` |
| `mlm-{env}-notifications` | Standard | Notification dispatch tasks (email, Slack, Teams) | 60s | 1 day | `mlm-{env}-notifications-dlq` |
| `mlm-{env}-integration-sync` | Standard | MLflow polling results, platform sync tasks | 120s | 4 days | `mlm-{env}-integration-sync-dlq` |
| `mlm-{env}-audit-export` | Standard | Audit archival job batches | 600s | 4 days | `mlm-{env}-audit-export-dlq` |
| `mlm-{env}-des-cache-invalidation` | Standard | DES cache invalidation events on version status change | 30s | 1 day | — |

### 8.2 DLQ Strategy

All queues (except DES cache invalidation, which is best-effort) have a corresponding Dead-Letter Queue:

```
Max receives before DLQ:  3 (standard queues) / 5 (FIFO queues)

DLQ Retention:            14 days (time for investigation + replay)

DLQ Alert:                CloudWatch alarm triggers on DLQ depth > 0
                          → PagerDuty alert to on-call engineer

DLQ Replay:               Admin UI provides DLQ replay capability
                          (re-enqueue DLQ messages to source queue)
```

### 8.3 Message Size Limits

SQS has a 256 KB per-message limit. Large payloads use the **Extended Client Library** pattern:

```
If payload > 200 KB:
  1. Upload payload to mlm-{env}-integration-cache/sqs-payloads/{message_id}
  2. Enqueue SQS message with S3 pointer:
     { "s3_bucket": "...", "s3_key": "...", "size_bytes": N }
  3. Consumer: detect S3 pointer → fetch from S3 → process → delete S3 object

Applicable queues: monitoring-ingest (large batch payloads), integration-sync
```

---

## 9. Artifact Storage Design

### 9.1 Artifact Upload Flow (Presigned POST)

MLM uses **presigned POST** for artifact uploads to avoid routing large files through the application server:

```
1. Client requests upload URL
   POST /api/v1/models/{id}/stages/{stage}/artifacts/upload-url
   Body: { filename, content_type, size_bytes, artifact_type }

2. Backend validates:
   - User has write permission for this stage
   - File type is allowed (PDF, DOCX, XLSX, IPYNB, MD, PNG, JPG, CSV, ZIP)
   - size_bytes ≤ 500 MB

3. Backend generates presigned POST:
   - Target: mlm-{env}-upload-staging/{staging_key}
   - Conditions:
     ["content-length-range", 1, 524288000]  ← max 500MB
     ["starts-with", "$Content-Type", ""]
     {"x-amz-meta-upload-id": upload_id}
   - Expiry: 15 minutes

4. Backend creates pending artifact record in Aurora:
   { id, stage_record_id, upload_id, status: PENDING, staging_s3_key }

5. Backend returns presigned POST fields to client

6. Client uploads directly to S3 (bypasses MLM backend)
   POST https://mlm-{env}-upload-staging.s3.amazonaws.com/
   Fields: {presigned POST fields + file content}

7. S3 triggers EventBridge → SQS → Worker:
   Worker processes: validate upload → compute SHA-256 hash
   → move from staging to artifacts bucket
   → update artifact record (status: AVAILABLE, s3_uri, content_hash)
   → notify user via WebSocket
```

### 9.2 Artifact Reference Model

Artifact files are never stored in the MLM database directly. The database stores:

```sql
artifacts (mlm_core schema)
├── id              UUID
├── stage_record_id UUID  → FK to stage_records
├── artifact_type   ENUM  → PROJECT_CHARTER | VALIDATION_REPORT | etc.
├── display_name    TEXT  → User-visible filename
├── s3_bucket       TEXT  → mlm-prod-artifacts
├── s3_key          TEXT  → projects/MOD-2024-00421/versions/1.2.0/validation/...
├── s3_version_id   TEXT  → S3 object version ID (for versioned bucket)
├── content_hash    TEXT  → SHA-256 of file content (integrity verification)
├── size_bytes      BIGINT
├── content_type    TEXT  → application/pdf
├── status          ENUM  → PENDING | AVAILABLE | SUPERSEDED | DELETED
├── uploaded_by     UUID
├── uploaded_at     TIMESTAMPTZ
└── access_log      JSONB → last 10 access events (user, timestamp)
```

### 9.3 Artifact Access Control

```
Download authorization flow:

1. Client: GET /api/v1/models/{id}/stages/{stage}/artifacts/{artifact_id}/download

2. Backend:
   a. Validate JWT
   b. Check RBAC: does this user have read access to this stage?
   c. Check artifact status = AVAILABLE
   d. Generate presigned GET URL:
      Source: mlm-{env}-artifacts/{s3_key}
      Expiry: 15 minutes
      ResponseContentDisposition: attachment; filename="{display_name}"
   e. Log access event to artifact.access_log (JSONB update)
   f. INSERT audit_log record (action: ARTIFACT_DOWNLOADED)
   g. Return: { presigned_url, expires_at }

3. Client: GET {presigned_url} → file download directly from S3
```

### 9.4 Artifact Integrity Verification

```
On upload completion (worker):
  1. Download file from staging S3 key
  2. Compute SHA-256 hash of content
  3. Compare against user-provided hash (if supplied in upload request)
  4. Store hash in artifact record
  5. If hash mismatch: mark artifact FAILED, notify user

On download (optional, configurable per artifact type):
  1. After presigned URL generation, background worker fetches S3 object
  2. Recomputes SHA-256 hash
  3. Compares against stored hash
  4. If mismatch: alert security team (possible S3 object tampering)
  → For VALIDATED model artifacts: integrity verification is mandatory on each download
```

---

## 10. Backup & Recovery Storage

### 10.1 Aurora PostgreSQL Backup

```
Automated Backups:
  Retention:    35 days (maximum for Aurora)
  Backup window: 02:00–03:00 UTC daily
  PITR:         Enabled (point-in-time recovery to any second within retention window)
  Storage:      Aurora Backup Storage (same region; automatic)

Manual Snapshots (for long-term compliance):
  Frequency:    Weekly (Sundays 03:00 UTC) + on every production release
  Retention:    1 year (stored as Aurora snapshots)
  Cross-region: Copied to DR region after creation

Snapshot Export to S3 (for very long-term retention):
  Frequency:    Monthly
  Format:       Apache Parquet (exported via Aurora → S3 export feature)
  Destination:  mlm-{env}-backups/aurora-exports/{YYYY}/{MM}/
  Retention:    7 years (Glacier transition after 1 year)
  Queryable via: Athena (for compliance lookback queries)
```

### 10.2 Timestream Backup

Timestream does not support direct snapshots. Long-term backup strategy:

```
Scheduled Export Job (weekly):
  → Timestream Scheduled Query exports all data older than 90 days
  → Parquet files written to: mlm-{env}-backups/timestream/{table}/{year}/{month}/
  → Glue Data Catalog updated for Athena accessibility
  → S3 Lifecycle: transition to Glacier IR after 1 year
```

### 10.3 OpenSearch Backup

```
Automated Snapshots:
  Frequency:    Daily (managed by OpenSearch Service)
  Retention:    14 days (in S3 managed by OpenSearch Service)
  
Manual Snapshots:
  Frequency:    Weekly
  Destination:  mlm-{env}-backups/opensearch/{YYYY}/{MM}/
  Retention:    90 days (index can be rebuilt from Aurora/Timestream if needed)
```

### 10.4 Redis Backup

```
Redis Cluster Backup (RDB snapshots):
  Frequency:    Daily (02:30 UTC)
  Retention:    7 days
  Storage:      ElastiCache managed S3 bucket
  
Recovery:      Redis data is reconstructible — DES cache rewarms on restart;
               rate limit counters reset (acceptable); session tokens
               require re-authentication (acceptable; 15-min tokens)
               
Note:          Redis is a cache layer — full data reconstruction from Aurora
               is preferred over Redis backup restoration for most scenarios.
```

### 10.5 S3 Versioning & MFA Delete

```
Buckets with versioning enabled:
  mlm-{env}-artifacts       → MFA Delete: Enabled (prod only)
  mlm-{env}-audit-archive   → MFA Delete: Enabled (+ Object Lock)
  mlm-{env}-reports         → MFA Delete: Disabled
  mlm-{env}-backups         → MFA Delete: Enabled (prod only)

MFA Delete requires:
  → AWS account root credentials + MFA device
  → Prevents accidental or malicious deletion of versioned objects
  → Only applies to permanent deletion of object versions
```

### 10.6 Recovery Time Targets per Store

| Store | Recovery Method | RTO | RPO |
|-------|----------------|-----|-----|
| Aurora (primary region) | Automatic Multi-AZ failover | < 60 seconds | 0 (synchronous replication) |
| Aurora (DR region) | Global DB promotion + DNS update | < 15 minutes | < 1 second |
| Aurora (data restore) | PITR from automated backup | < 2 hours | Point-in-time |
| Timestream | Rebuild from S3 export (Athena) | < 4 hours | Last weekly export |
| OpenSearch | Snapshot restore | < 1 hour | Last daily snapshot |
| Redis | Auto-failover to replica | < 30 seconds | Last RDB snapshot (< 24hr) |
| S3 | Cross-region replica promotion | < 5 minutes | Near-real-time (async) |

---

## 11. Multi-Region Storage Strategy

### 11.1 Region Topology

```
PRIMARY REGION (us-east-1 — default)
├── Aurora PostgreSQL Writer + 2 Readers
├── Amazon Timestream (primary)
├── Amazon OpenSearch (primary cluster)
├── ElastiCache Redis (primary cluster)
├── SQS Queues (primary)
├── S3 Buckets (primary)
└── DES (primary deployment)

DR REGION (us-west-2 — default DR)
├── Aurora Global DB secondary (read-only; promotes on failover)
├── Amazon Timestream (separate; weekly export from primary)
├── Amazon OpenSearch (NOT replicated; rebuilt from Aurora on DR activation)
├── ElastiCache Redis (NOT replicated; rebuilt from Aurora on DR activation)
├── SQS Queues (NOT replicated; messages in primary lost if region fails)
├── S3 Buckets (cross-region replicas — see below)
└── DES (warm standby — reads from Aurora DR reader)
```

### 11.2 S3 Cross-Region Replication

```
Replication Rule Configuration:

Source Bucket             Destination Bucket                 Replicated?  Notes
─────────────────────────────────────────────────────────────────────────────────
mlm-prod-artifacts        mlm-prod-artifacts-us-west-2       Yes          Full replication
mlm-prod-audit-archive    mlm-prod-audit-archive-us-west-2   Yes          Full; Object Lock replicated
mlm-prod-reports          mlm-prod-reports-us-west-2         Yes          Full replication
mlm-prod-backups          mlm-prod-backups-us-west-2         Yes          Full replication
mlm-prod-frontend         (Not replicated)                   No           CloudFront global CDN covers this
mlm-prod-upload-staging   (Not replicated)                   No           Transient; 2-day TTL
mlm-prod-integration-cache(Not replicated)                   No           Reconstructible

Replication SLA:
  Objects replicated within 15 minutes of creation (S3 RTC — Replication Time Control)
  S3 RTC enabled for audit-archive and artifacts buckets
  Replication metrics and alerts: S3 Replication Time Control CloudWatch metrics
```

### 11.3 DR Activation Procedure

```
Trigger: Primary region (us-east-1) declared unavailable

Step 1  (< 5 min):   Update Route 53 health check → DES DNS failover to us-west-2
Step 2  (< 5 min):   Promote Aurora Global DB secondary → new primary writer in us-west-2
Step 3  (< 10 min):  Update DES us-west-2 connection string → point to promoted Aurora
Step 4  (< 15 min):  Deploy Backend API to us-west-2 EKS (warm standby)
                     → connect to promoted Aurora + regional SQS + S3 replicas
Step 5  (< 20 min):  Update CloudFront API origin → us-west-2 ALB
Step 6  (< 30 min):  Validate DR environment via smoke test suite
Step 7  (ongoing):   Monitoring + incident communication

RTO target: < 1 hour (full application)
            < 15 minutes (DES only — critical path)
```

---

## 12. Storage Security

### 12.1 KMS Key Architecture

MLM uses **separate KMS Customer Managed Keys (CMKs)** per data sensitivity tier:

```
KMS Key Aliases and Usage:

alias/mlm-db-key
  Used by:    Aurora PostgreSQL (storage encryption)
  Key policy: MLM backend role (encrypt/decrypt), DBA role (key management)
  Rotation:   Annual (automatic)

alias/mlm-artifacts-key
  Used by:    mlm-{env}-artifacts S3 bucket (SSE-KMS)
  Key policy: MLM backend role (encrypt/decrypt for presigned URL)
              Upload staging Lambda role
  Rotation:   Annual

alias/mlm-audit-key
  Used by:    mlm-{env}-audit-archive S3 bucket (SSE-KMS)
              Aurora audit schema (column encryption via pgcrypto)
  Key policy: Audit archival job role (encrypt), Auditor role (decrypt for Athena)
              NO application runtime role has decrypt access
  Rotation:   Annual (manual rotation with re-encryption job)

alias/mlm-cache-key
  Used by:    ElastiCache Redis (at-rest encryption)
  Key policy: MLM backend role (encrypt/decrypt)
  Rotation:   Annual

alias/mlm-reports-key
  Used by:    mlm-{env}-reports S3 bucket
  Key policy: MLM backend role, Auditor role, Compliance Manager role
  Rotation:   Annual
```

### 12.2 S3 Bucket Security Baseline

Applied to all MLM S3 buckets:

```json
{
  "PublicAccessBlockConfiguration": {
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
  },
  "BucketEncryption": "SSE-KMS (CMK per bucket)",
  "BucketVersioning": "Enabled (per table above)",
  "BucketLogging": {
    "TargetBucket": "mlm-{env}-access-logs",
    "TargetPrefix": "{bucket-name}/"
  },
  "EventNotifications": "S3 EventBridge → artifact processing pipeline"
}
```

**Deny HTTP (enforce TLS) bucket policy (applied to all buckets):**
```json
{
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:*",
  "Resource": ["arn:aws:s3:::mlm-{env}-*", "arn:aws:s3:::mlm-{env}-*/*"],
  "Condition": { "Bool": { "aws:SecureTransport": "false" } }
}
```

### 12.3 Database Security

```
Network:
  Aurora SG: allows inbound TCP 5432 from App Tier SG only
             NO public accessibility
  
Authentication:
  IAM database authentication (token-based; no static passwords)
  PgBouncer uses IAM auth; applications connect to PgBouncer only
  
Row-Level Security:
  mlm_audit.audit_log: INSERT only; UPDATE/DELETE blocked via RLS policy
  mlm_core.model_versions: UPDATE blocked on immutable fields post-VALIDATED

Encryption:
  In-transit: SSL enforced via Aurora parameter ssl=1 + rds.force_ssl=1
  At-rest: AES-256 via alias/mlm-db-key

Secrets:
  DB credentials stored in AWS Secrets Manager (alias: mlm/{env}/db/pgbouncer)
  Rotated automatically every 30 days via Secrets Manager rotation Lambda
```

### 12.4 Redis Security

```
Network:       Redis SG: allows inbound TCP 6379 from App Tier SG only
Auth:          Redis AUTH token (stored in Secrets Manager)
               Rotated every 90 days
Encryption:    At-rest: alias/mlm-cache-key
               In-transit: TLS 1.2+ enforced
ACL:           Redis 7 ACLs configured per service:
               - mlm-api-user: access keys des:*, session:*, qcache:*, ratelimit:*
               - mlm-worker-user: access keys lock:*, qcache:*
               - mlm-des-user: access keys des:elig:* (read-write), session:* (read-only)
```

---

## 13. Storage Lifecycle & Retention

### 13.1 Master Retention Policy

| Data Category | Store | Hot Retention | Warm Retention | Cold Archive | Delete Policy |
|---------------|-------|--------------|----------------|-------------|---------------|
| Model project metadata | Aurora | Indefinite (active) | — | Never | Soft-delete only |
| Model version metadata | Aurora | Indefinite | — | Never | Never (immutable) |
| Stage records + approvals | Aurora | Indefinite | — | Never | Never |
| Audit log (Aurora) | Aurora | 2 years | — | S3 Parquet (10yr) | Archive; never physically delete |
| Audit log (S3 archive) | S3 + Object Lock | — | — | 10 years (COMPLIANCE) | After 10yr: Glacier Deep Archive |
| Monitoring metrics (raw) | Timestream memory | 7 days | Timestream magnetic (2yr) | S3 Parquet (7yr) | Auto-tiered |
| Artifact files (active projects) | S3 Standard | 90 days | S3 IA (1yr) | S3 Glacier IR (7yr) | Per retention policy |
| Artifact files (retired Tier 1–2) | S3 Standard | — | S3 IA | 7 years minimum | Admin-controlled |
| Generated reports | S3 Standard | 180 days | S3 IA (1yr) | S3 Glacier IR (3yr) | Auto-expire after 3yr |
| Notification logs | Aurora | 90 days | — | Deleted | Auto-purge after 90d |
| Integration adapter logs | Aurora | 30 days | — | Deleted | Auto-purge after 30d |
| Upload staging files | S3 | 2 days | — | Deleted | Auto-expire (lifecycle rule) |
| Redis cache data | Redis | TTL-managed | — | — | On TTL expiry |
| SQS messages | SQS | 4 days (max) | — | — | Auto-deleted after retention |
| OpenSearch audit index | OpenSearch | 90 days | — | S3 Parquet | ILM delete after 90d |
| Aurora automated backups | Aurora Backup | 35 days | — | — | Auto-deleted |
| Aurora manual snapshots | Aurora Snapshots | 1 year | — | S3 Parquet (7yr) | Annual export then delete |
| User personal data | Aurora | Active account | — | ANONYMIZED | GDPR: anonymize on account deletion |

### 13.2 S3 Lifecycle Rule Templates

**Artifacts Bucket Lifecycle Rules:**
```json
[
  {
    "ID": "abort-incomplete-multipart",
    "Status": "Enabled",
    "AbortIncompleteMultipartUpload": { "DaysAfterInitiation": 2 }
  },
  {
    "ID": "transition-to-ia",
    "Status": "Enabled",
    "Filter": { "And": { "Tags": [{"Key": "project-status", "Value": "active"}] } },
    "Transitions": [{ "Days": 90, "StorageClass": "STANDARD_IA" }]
  },
  {
    "ID": "transition-retired-to-glacier",
    "Status": "Enabled",
    "Filter": { "And": { "Tags": [{"Key": "project-status", "Value": "retired"}] } },
    "Transitions": [
      { "Days": 30, "StorageClass": "GLACIER_IR" },
      { "Days": 2555, "StorageClass": "DEEP_ARCHIVE" }
    ]
  },
  {
    "ID": "expire-noncurrent",
    "Status": "Enabled",
    "NoncurrentVersionExpiration": { "NoncurrentDays": 90 }
  }
]
```

Object tagging strategy — MLM backend tags S3 objects on upload:
```
project-status:   active | retired | archived
risk-tier:        1 | 2 | 3 | 4
artifact-type:    validation-report | deployment-plan | model-card | ...
model-id:         MOD-2024-00421
```

---

## 14. Storage Sizing & Capacity Planning

### 14.1 Year 1–3 Capacity Projections

Assumptions: 500 model projects at launch; 50% YoY growth; avg. 5 versions per project; 3 monitoring metrics per model per minute; 10 artifacts per stage.

| Store | Y1 Size | Y2 Size | Y3 Size | Growth Driver |
|-------|---------|---------|---------|---------------|
| Aurora PostgreSQL | 130 GB | 280 GB | 470 GB | Audit log dominates |
| Timestream (magnetic) | 18 TB | 54 TB | 130 TB | Metric frequency × model count |
| OpenSearch | 750 GB | 1.5 TB | 2.5 TB | Audit index + artifact metadata |
| Redis | 25 GB | 40 GB | 65 GB | DES cache + query cache |
| S3 (artifacts) | 2 TB | 6 TB | 15 TB | Uploaded files per stage |
| S3 (audit archive) | 500 GB | 1.5 TB | 4 TB | Exported audit Parquet |
| S3 (reports) | 200 GB | 600 GB | 1.5 TB | Generated reports |
| S3 (backups) | 1 TB | 3 TB | 8 TB | Aurora exports + Timestream export |
| SQS | Minimal | Minimal | Minimal | Transient; auto-managed |

### 14.2 Storage Cost Estimates (AWS us-east-1, 2024 pricing)

| Store | Y1 Monthly Cost | Y3 Monthly Cost | Notes |
|-------|----------------|----------------|-------|
| Aurora PostgreSQL (writer + 2 readers) | ~$1,800 | ~$2,400 | Storage auto-scales; compute fixed |
| Amazon Timestream | ~$3,500 | ~$12,000 | Magnetic store dominates; write costs significant |
| Amazon OpenSearch (3 × r6g.large) | ~$600 | ~$800 | EBS storage additional |
| ElastiCache Redis (6 nodes) | ~$900 | ~$1,200 | Cluster mode |
| S3 (all buckets, blended tier) | ~$800 | ~$3,500 | Tiering reduces cost significantly |
| S3 replication (cross-region) | ~$200 | ~$800 | Data transfer + storage in DR region |
| SQS | ~$50 | ~$200 | Per-request pricing |
| KMS (API calls) | ~$100 | ~$200 | Key API calls |
| **Total Storage** | **~$7,950/mo** | **~$21,100/mo** | Excludes compute (EKS) |

### 14.3 Capacity Triggers

| Trigger | Threshold | Action |
|---------|-----------|--------|
| Aurora storage utilization | > 70% of provisioned | Review audit archival pace; accelerate S3 export |
| Aurora CPU (writer) | > 75% sustained | Add read replica; review query optimization |
| Timestream write throttling | Any occurrence | Scale up consumer workers; review metric ingestion batching |
| OpenSearch storage | > 70% of provisioned | Add data nodes or increase EBS volume |
| Redis memory | > 80% cluster memory | Increase node size or add shard |
| S3 costs | > 20% MoM increase | Review lifecycle rule effectiveness; audit large uploads |

---

## 15. Cost Optimization Strategy

### 15.1 S3 Intelligent-Tiering

For the artifacts bucket where access patterns are unpredictable (some projects heavily accessed; others not), **S3 Intelligent-Tiering** is applied after the initial 90-day active period:

```
S3 Intelligent-Tiering tiers (automatic):
  Frequent Access tier:        Objects accessed recently (no retrieval fee)
  Infrequent Access tier:      Objects not accessed for 30+ days (40% cost savings)
  Archive Instant Access tier: Objects not accessed for 90+ days (68% savings)
  Archive Access tier:         Objects not accessed for 180+ days (95% savings)

Monthly monitoring fee: $0.0025 per 1,000 objects
Break-even vs Standard-IA: ~6,000 objects per $15 savings threshold
```

### 15.2 Timestream Cost Controls

Timestream write costs dominate the monitoring budget. Optimizations:

```
1. Metric Batching:
   Ingest workers batch metric writes: 100 records per Timestream batch write
   (vs 1 per write) → reduces write request count by 100×

2. Sampling:
   High-frequency metrics (infra: every 60s) downsampled to 5-minute resolution
   in Timestream via Scheduled Queries → reduces storage by 5×

3. Aggressive Memory→Magnetic Transition:
   Memory store: 7 days (minimum required for real-time dashboards)
   Magnetic store: lower cost; sufficient for historical trend queries

4. Metric Pruning:
   MLOps Engineers can configure per-metric retention overrides
   Low-value metrics (e.g., verbose debug metrics) set to 90-day retention
   vs default 2-year
```

### 15.3 Aurora Cost Optimization

```
1. Aurora Serverless v2 for dev/staging:
   Dev and staging use Aurora Serverless v2 (scales to 0 ACUs when idle)
   → eliminates cost during off-hours for non-production environments

2. Reserved Instances for production:
   3-year reserved instances for writer + Reader 1 (predictable baseline)
   → ~40% savings vs on-demand

3. Read Replica Right-Sizing:
   Reader 2 (DES queries) uses smaller r6g.xlarge vs r6g.2xlarge for Reader 1
   → DES queries are lightweight index lookups; large instance unnecessary

4. Audit Archival:
   Aggressive 2-year hot retention → archive to S3 Parquet
   S3 Glacier IR for archived audit: $0.004/GB vs Aurora $0.10/GB
   → 25× storage cost reduction for cold audit data
```

### 15.4 Storage Tagging for Cost Allocation

All storage resources are tagged for cost allocation reporting:

```
Tags applied to all storage resources:
  Environment:    prod | staging | dev
  Product:        mlm
  Component:      aurora | timestream | opensearch | redis | s3-artifacts | etc.
  CostCenter:     {customer billing code or internal team}
  DataTier:       hot | warm | cold
```

AWS Cost Explorer configured with tag-based cost allocation reports, enabling:
- Per-environment cost breakdown (prod vs staging vs dev)
- Per-component cost tracking (storage type breakdown)
- Monthly trend alerts (> 15% MoM increase triggers review)

---

## 16. Storage Monitoring & Alerting

### 16.1 Storage Health Metrics

| Metric | Source | Warning | Critical | Alert Recipient |
|--------|--------|---------|----------|----------------|
| Aurora FreeStorageSpace | CloudWatch | < 20 GB | < 5 GB | DBA + On-call |
| Aurora WriteThroughput | CloudWatch | > 200 MB/s | > 400 MB/s | DBA |
| Aurora ReadLatency (P95) | CloudWatch | > 50ms | > 100ms | DBA |
| Aurora DatabaseConnections | CloudWatch | > 150 | > 180 | DBA |
| Aurora ReplicationLag | CloudWatch | > 30s | > 120s | DBA |
| Redis EngineCPUUtilization | CloudWatch | > 70% | > 90% | Infra team |
| Redis FreeableMemory | CloudWatch | < 20% | < 10% | Infra team |
| Redis CacheMisses (DES shard) | CloudWatch | > 30% | > 50% | MLOps team |
| OpenSearch ClusterStatus | CloudWatch | Yellow | Red | Infra team |
| OpenSearch FreeStorageSpace | CloudWatch | < 20% | < 10% | Infra team |
| Timestream SystemErrors | CloudWatch | > 0 | > 10/min | MLOps team |
| S3 4xxErrors (artifacts) | CloudWatch | > 100/hr | > 500/hr | Backend team |
| SQS ApproximateAgeOfOldestMessage | CloudWatch | > 5min (workflow) | > 15min | On-call |
| SQS NumberOfMessagesSentToDLQ | CloudWatch | > 0 | > 100 | On-call |
| S3 replication latency | CloudWatch (S3 RTC) | > 5min | > 15min | Infra team |
| Aurora backup failure | CloudWatch Events | — | Any failure | DBA + On-call |

### 16.2 Storage Capacity Dashboard

A dedicated **Storage Capacity Dashboard** (Grafana / CloudWatch Dashboard) shall display:

- Aurora storage utilization (current + 30-day trend + projected 90-day trajectory)
- Timestream memory store vs magnetic store utilization
- OpenSearch storage per index + cluster free space
- Redis memory utilization per shard
- S3 bucket sizes (per bucket, per storage class)
- Monthly storage cost (actual vs budget)
- S3 lifecycle transition volumes (bytes moved to IA / Glacier per day)
- Audit archival job status (last run, records archived, S3 size written)

---

*End of Storage Architecture Document*  
*MLM Platform — SAD v1.0*
