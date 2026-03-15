# UI/UX Specification
## Model Lifecycle Management (MLM) Platform

**Document ID:** MLM-UX-001  
**Version:** 1.0  
**Status:** Draft  
**Classification:** Internal — Confidential  

**Related Documents:**
- `MLM-FRD-001` — Functional Requirements Document
- `MLM-SRD-001` — System Requirements Document
- `MLM-IDD-001` — Integration Design Document

---

## Document Control

| Version | Date | Author | Change Description |
|---------|------|--------|-------------------|
| 1.0 | 2024-Q4 | Product / UX Team | Baseline release |

### Review & Approval

| Role | Name | Status |
|------|------|--------|
| Product Owner | TBD | Pending |
| UX Lead | TBD | Pending |
| Engineering Lead | TBD | Pending |
| Key User Representatives | TBD | Pending |

---

## Table of Contents

1. [Design Philosophy & Principles](#1-design-philosophy--principles)
2. [Design System Foundations](#2-design-system-foundations)
3. [Information Architecture](#3-information-architecture)
4. [Navigation Model](#4-navigation-model)
5. [Role-Adaptive Home Screens](#5-role-adaptive-home-screens)
6. [Portfolio Dashboard](#6-portfolio-dashboard)
7. [Model Project — Overview & Lifecycle Map](#7-model-project--overview--lifecycle-map)
8. [Stage 1 — Inception UI](#8-stage-1--inception-ui)
9. [Stage 2 — Development UI](#9-stage-2--development-ui)
10. [Stage 3 — Validation UI](#10-stage-3--validation-ui)
11. [Stage 4 — Implementation UI](#11-stage-4--implementation-ui)
12. [Stage 5 — Monitoring UI](#12-stage-5--monitoring-ui)
13. [Stage 6 — Versioning UI](#13-stage-6--versioning-ui)
14. [Stage 7 — Retirement UI](#14-stage-7--retirement-ui)
15. [My Tasks — Approval Workflows](#15-my-tasks--approval-workflows)
16. [Inline Approval — Email & Slack](#16-inline-approval--email--slack)
17. [Vendor Model UI](#17-vendor-model-ui)
18. [GenAI / LLM Model UI](#18-genai--llm-model-ui)
19. [Business Model Registry UI](#19-business-model-registry-ui)
20. [Compliance Center](#20-compliance-center)
21. [Admin Console](#21-admin-console)
22. [Onboarding & First-Run Experience](#22-onboarding--first-run-experience)
23. [Notifications & Alert UX](#23-notifications--alert-ux)
24. [Accessibility & Responsiveness](#24-accessibility--responsiveness)
25. [Component Library Reference](#25-component-library-reference)

---

## 1. Design Philosophy & Principles

### 1.1 Core UX Mandate

MLM must serve two fundamentally different user types without compromise:

- **Power users (Data Scientists, ML Engineers)** — spend hours daily in the tool; demand density, speed, and deep integration context. They will abandon the tool if it adds friction to their workflow.
- **Governance users (Risk Officers, Validators, Model Owners)** — visit the tool for specific decision moments; demand clarity, completeness, and zero ambiguity about what action is required of them.

The design must make both groups feel the tool was built for them.

### 1.2 Design Principles

| Principle | Description | Anti-Pattern Avoided |
|-----------|-------------|---------------------|
| **Density over decoration** | Information-dense layouts with minimal whitespace waste. Every pixel serves a governance purpose. | Consumer-app aesthetic that sacrifices data density for visual beauty |
| **Friction is the enemy of governance** | Approvals, reviews, and decisions must require the minimum possible interactions. A governance tool that is hard to use becomes a governance tool that is not used. | Requiring 5 navigations to reach an approval action |
| **Context before action** | Always show the approver/reviewer the full context they need before asking for a decision. Never show an action button on a blank page. | Approval emails with no context requiring login to understand the request |
| **Status is always visible** | A user should never need to click to find out the current state of a model project. Status, blocking conditions, and next actions are always surfaced at the list level. | Status buried inside a detail page |
| **Progressive disclosure** | Show summary first; details on demand. Role-appropriate depth by default. | Overwhelming every user with every field regardless of role |
| **Audit-aware interactions** | Every significant action (submit, approve, reject, upload) surfaces a confirmation with consequence description. Users are never surprised by what was recorded. | Silent form submissions with no confirmation |
| **Fail gracefully** | Integration failures (MLflow offline, SageMaker unavailable) degrade gracefully with clear status indicators — the governance record remains usable even when integrations are down. | Entire page errors when an integration is unavailable |

### 1.3 Visual Design Direction

**Reference aesthetic:** Professional, data-dense, enterprise SaaS — comparable to **Linear** (clarity + speed) meets **Datadog** (information density + monitoring) with the governance structure of **ServiceNow's modern UI**.

- **Not** a consumer app aesthetic
- **Not** a form-heavy legacy enterprise style
- **Yes** to a dark mode first-class experience (not an afterthought)
- **Yes** to purposeful color usage — color encodes meaning (risk tier, status, severity), not decoration

### 1.4 Release Scope

| Capability | V1 | V2 |
|------------|----|----|
| Visual lifecycle progress map | ✅ | — |
| Role-adaptive home screens | ✅ | — |
| Portfolio dashboard | ✅ | — |
| Inline approval (email + Slack) | ✅ | — |
| All 7 stage UI panels | ✅ | — |
| First-run onboarding wizard | ✅ | — |
| MLflow run table (server-side proxy) | ✅ | — |
| Metric snapshot charts (post-candidate selection) | ✅ | — |
| Native real-time monitoring charts | — | ✅ |
| Mobile-optimized experience | — | ✅ (approval only) |
| Embedded third-party charts | — | ✅ |

---

## 2. Design System Foundations

### 2.1 Typography

```
Font Family:    Inter (primary), JetBrains Mono (code / IDs / hashes)

Scale:
  Display:      32px / 700 weight  — Page titles, hero metrics
  H1:           24px / 600 weight  — Section headers
  H2:           18px / 600 weight  — Panel headers, card titles
  H3:           14px / 600 weight  — Sub-section labels
  Body Large:   15px / 400 weight  — Primary body text
  Body:         14px / 400 weight  — Standard UI text
  Body Small:   13px / 400 weight  — Secondary labels, metadata
  Caption:      12px / 400 weight  — Timestamps, helper text
  Mono:         13px / 400 weight  — Model IDs, hashes, ARNs, code
```

### 2.2 Color System

#### 2.2.1 Semantic Status Colors

Status colors encode meaning system-wide. They appear on badges, progress indicators, alert banners, and table rows.

```
Status: NOT_STARTED      Background: #1C1C1C  Text: #6B7280  Border: #374151
Status: IN_PROGRESS      Background: #1E3A5F  Text: #60A5FA  Border: #2563EB
Status: PENDING_REVIEW   Background: #2D2A1E  Text: #FBBF24  Border: #D97706
Status: APPROVED         Background: #1A2E1A  Text: #34D399  Border: #059669
Status: REJECTED         Background: #2D1E1E  Text: #F87171  Border: #DC2626
Status: ON_HOLD          Background: #2A2A2A  Text: #9CA3AF  Border: #6B7280
Status: ROLLED_BACK      Background: #2D1E2D  Text: #C084FC  Border: #9333EA
Status: COMPLETED        Background: #1A2E2A  Text: #6EE7B7  Border: #047857
```

#### 2.2.2 Risk Tier Colors

Risk tier colors appear on badges, project cards, and table rows. High contrast ensures immediate visual differentiation.

```
Tier 1 (Critical):  #DC2626  (Red)     — Always high-salience
Tier 2 (High):      #EA580C  (Orange)
Tier 3 (Medium):    #CA8A04  (Amber)
Tier 4 (Low):       #16A34A  (Green)
```

#### 2.2.3 Alert Severity Colors

```
CRITICAL:  #DC2626  Red     — Requires immediate action
WARNING:   #D97706  Amber   — Requires attention
INFO:      #2563EB  Blue    — Informational
SUCCESS:   #059669  Green   — Resolved / positive
```

#### 2.2.4 Base Palette (Dark Mode Primary)

```
Background Primary:     #0F0F0F   — Main app background
Background Secondary:   #161616   — Sidebar, panels
Background Tertiary:    #1C1C1C   — Cards, inputs
Background Elevated:    #242424   — Modals, dropdowns, tooltips
Border Subtle:          #2A2A2A   — Dividers, card borders
Border Default:         #374151   — Input borders, section dividers
Text Primary:           #F9FAFB   — Primary readable text
Text Secondary:         #9CA3AF   — Labels, metadata, helper text
Text Disabled:          #4B5563   — Disabled states
Brand Primary:          #6366F1   — CTA buttons, active states, links
Brand Secondary:        #8B5CF6   — Hover states, accents
```

### 2.3 Spacing System

```
Base unit: 4px

xs:   4px    — Icon gaps, tight inline spacing
sm:   8px    — Input padding, compact card padding
md:   12px   — Standard component padding
lg:   16px   — Section padding, card padding
xl:   24px   — Panel padding, section gaps
2xl:  32px   — Page-level spacing
3xl:  48px   — Hero section spacing
```

### 2.4 Elevation & Shadows

```
Level 0 (flat):     No shadow — cards on primary background
Level 1 (raised):   0 1px 3px rgba(0,0,0,0.4) — standard cards
Level 2 (floating): 0 4px 12px rgba(0,0,0,0.5) — dropdowns, tooltips
Level 3 (modal):    0 12px 32px rgba(0,0,0,0.7) — modal dialogs
```

### 2.5 Grid & Layout

```
Layout type:      Fixed sidebar + fluid content area
Sidebar width:    240px (expanded) / 56px (collapsed)
Content max-width: 1440px
Content padding:  32px (horizontal) / 24px (vertical)
Column grid:      12-column within content area
Gutter:           16px

Breakpoints:
  md:  768px   — Minimum supported (tablet); sidebar collapses
  lg:  1024px  — Standard desktop
  xl:  1280px  — Wide desktop
  2xl: 1440px  — Max content width reached
```

---

## 3. Information Architecture

### 3.1 Full Site Map

```
MLM Platform
│
├── Home (role-adaptive)
│   ├── Data Scientist view    — My Projects + Recent Activity
│   ├── Risk Officer view      — My Approvals + Risk Dashboard
│   ├── Model Owner view       — My Portfolio + Alerts
│   └── Auditor view           — Compliance Overview
│
├── Portfolio Dashboard        — All models, health at a glance
│
├── Model Registry             — Searchable model project list
│   ├── Internal Models
│   ├── Vendor Models
│   └── GenAI / LLM Models
│
├── Model Project              — Per-project workspace
│   ├── Overview               — Status, alerts, timeline
│   ├── Lifecycle Map          — Visual 7-stage progress
│   ├── Stage Panels
│   │   ├── 1. Inception
│   │   ├── 2. Development
│   │   ├── 3. Validation
│   │   ├── 4. Implementation
│   │   ├── 5. Monitoring
│   │   ├── 6. Versions
│   │   └── 7. Retirement
│   ├── Business Registry      — SM↔MLM registry sync view
│   ├── Audit Log              — Project-scoped audit trail
│   └── Settings               — Project config, integrations, team
│
├── My Tasks                   — Pending approvals + assigned actions
│   ├── Pending Approvals
│   ├── Open Findings (assigned)
│   ├── Open Incidents (assigned)
│   └── Overdue Items
│
├── Compliance Center          — Reports, exports, regulatory views
│   ├── Model Inventory
│   ├── SR 11-7 Packages
│   ├── EU AI Act Register
│   ├── Tag Compliance
│   └── Audit Log (global)
│
├── Integration Health         — (Admin / MLOps) integration status
│   ├── Environment Provisioning
│   ├── Registry Sync Status
│   └── Adapter Health
│
└── Admin Console
    ├── Users & Roles
    ├── Integration Configuration
    ├── Workflow Configuration
    ├── Notification Templates
    └── System Settings
```

### 3.2 URL Structure

```
/                                          ← Home (role-adaptive)
/dashboard                                 ← Portfolio dashboard
/registry                                  ← Model registry list
/registry/internal                         ← Internal models
/registry/vendor                           ← Vendor models
/registry/genai                            ← GenAI / LLM models
/models/{model_id}                         ← Project overview
/models/{model_id}/lifecycle               ← Lifecycle map
/models/{model_id}/stages/inception        ← Stage panel
/models/{model_id}/stages/development      ← Stage panel
/models/{model_id}/stages/validation       ← Stage panel
/models/{model_id}/stages/implementation   ← Stage panel
/models/{model_id}/stages/monitoring       ← Stage panel
/models/{model_id}/versions                ← Version explorer
/models/{model_id}/versions/compare        ← Version comparison
/models/{model_id}/registry                ← Business registry
/models/{model_id}/audit                   ← Audit log
/models/{model_id}/settings                ← Project settings
/tasks                                     ← My tasks
/tasks/approvals                           ← Pending approvals
/compliance                                ← Compliance center
/compliance/inventory                      ← Model inventory
/compliance/audit                          ← Global audit log
/integrations                              ← Integration health
/admin                                     ← Admin console
/admin/users                               ← User management
/admin/integrations                        ← Integration config
/approve/{token}                           ← Inline approval (email link)
/new                                       ← New model project wizard
```

---

## 4. Navigation Model

### 4.1 Primary Navigation — Sidebar

The sidebar is the persistent navigation anchor. It is always visible on desktop, collapsible to icon-only mode.

```
┌─────────────────────────────────────────────────┐
│  MLM                                    [≡] [☀] │  ← Logo + collapse + theme toggle
├─────────────────────────────────────────────────┤
│                                                 │
│  [⌂]  Home                                      │  ← Role-adaptive home
│  [▦]  Dashboard                                 │  ← Portfolio health
│  [≡]  Model Registry                            │  ← Browse all models
│  [✓]  My Tasks              [3]                 │  ← Badge: pending count
│                                                 │
├─────────────────────────────────────────────────┤
│  QUICK ACCESS                                   │  ← Recent/pinned projects
│  [•]  Credit Default Pred...                    │
│  [•]  Fraud Scorer v2                           │
│  [•]  Churn Predictor                           │
│       [+ Pin a project]                         │
├─────────────────────────────────────────────────┤
│                                                 │
│  [📋]  Compliance Center                        │
│  [⚡]  Integration Health    [!]                │  ← Badge: issues
│  [⚙]  Admin Console                            │  ← Admin role only
│                                                 │
├─────────────────────────────────────────────────┤
│  [👤]  Bhavik Patel                             │  ← User menu
│        Risk Tier: ML Engineer                   │
│        [Profile] [Preferences] [Sign Out]       │
└─────────────────────────────────────────────────┘
```

**Sidebar behaviors:**
- `[≡]` collapses sidebar to 56px icon-only rail (icons + tooltips)
- Quick Access section shows last 3 visited projects + up to 5 pinned
- Badge counts update in real time via WebSocket
- Active section highlighted with left border accent (brand primary)
- Section dividers separate primary nav, quick access, and utility nav

### 4.2 Top Bar (Content Area)

The top bar sits above the content area and provides breadcrumbs, contextual search, and global actions:

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Registry > Credit Default Predictor > Development          [🔍] [+ New]│
└─────────────────────────────────────────────────────────────────────────┘
```

- Breadcrumb is always present and clickable
- `[🔍]` opens global search (cmd+K shortcut)
- `[+ New]` creates a new model project (visible to authorized roles only)

### 4.3 Global Search (cmd+K)

```
┌─────────────────────────────────────────────────────────────────────────┐
│  🔍  Search models, versions, findings, artifacts...                    │
├─────────────────────────────────────────────────────────────────────────┤
│  RECENT                                                                  │
│  [MOD] Credit Default Predictor            MOD-2024-00421  Tier 2       │
│  [MOD] Fraud Scorer v2                     MOD-2024-00387  Tier 1       │
│                                                                         │
│  QUICK FILTERS                                                          │
│  [Tier 1 Models]  [Pending My Approval]  [Production Models]           │
│  [Active Alerts]  [Validation In Progress]                              │
├─────────────────────────────────────────────────────────────────────────┤
│  RESULTS FOR "credit"                                                   │
│  [MOD] Credit Default Predictor  · Development · Tier 2 · Owner: Jane  │
│  [MOD] Credit Card Fraud Scorer  · Monitoring · Tier 1 · Owner: Mark   │
│  [VER] v1.2.0 — Credit Default Predictor  · Validated  · 2024-11-15   │
│  [FND] Finding #F-042 — Credit scoring bias · Critical · Open          │
└─────────────────────────────────────────────────────────────────────────┘
```

- Keyboard navigable (arrows + enter)
- Results grouped by type: Models, Versions, Findings, Artifacts, Users
- Quick filters jump to pre-configured registry views
- Debounced search (300ms) hits OpenSearch backend

---

## 5. Role-Adaptive Home Screens

### 5.1 Home Screen — Data Scientist / ML Engineer

**Design intent:** Show active work immediately. No dashboard padding — straight to the projects in motion.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Good morning, Bhavik                              Tuesday, Nov 15 2024 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  MY ACTIVE PROJECTS                                          [View All] │
│                                                                         │
│  ┌──────────────────────────────┐  ┌──────────────────────────────┐    │
│  │  Credit Default Predictor    │  │  Fraud Scorer v2             │    │
│  │  MOD-2024-00421  ● Tier 2   │  │  MOD-2024-00387  ● Tier 1   │    │
│  │                             │  │                             │    │
│  │  ████████████░░░░  Stage 2  │  │  ████████████████░░  Stage 3│    │
│  │  Development — IN PROGRESS  │  │  Validation — PENDING       │    │
│  │                             │  │  REVIEW                     │    │
│  │  Candidate: run-abc123      │  │                             │    │
│  │  MLflow: 14 runs synced     │  │  3 findings open            │    │
│  │  Last activity: 2 hrs ago   │  │  2 critical ⚠              │    │
│  │                             │  │                             │    │
│  │  [Open Development Stage]   │  │  [View Findings]            │    │
│  └──────────────────────────────┘  └──────────────────────────────┘    │
│                                                                         │
│  RECENT ACTIVITY                                                        │
│  ●  MLflow run run-def456 synced — Credit Default Predictor  2m ago    │
│  ✓  Development gate approved — Fraud Scorer v2              1h ago    │
│  !  Critical finding raised — Fraud Scorer v2                3h ago    │
│  ●  Candidate selected: run-abc123 — Credit Default          Yesterday │
│                                                                         │
│  ENVIRONMENT STATUS                                                     │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  Credit Default Predictor                                        │  │
│  │  AWS Account: 987654321098  ·  us-east-1  ·  ✅ Tagged          │  │
│  │  SageMaker Project: p-abc123  ·  MPG: credit-default-pred-mpg   │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Home Screen — Risk Officer

**Design intent:** What needs my attention right now? Governance actions front and center.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Good morning, Sarah                               Tuesday, Nov 15 2024 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │    3     │  │    2     │  │    1     │  │    7     │              │
│  │ Pending  │  │ SLA at   │  │Emergency │  │ Tier 1   │              │
│  │Approvals │  │  Risk    │  │  Alert   │  │ Models   │              │
│  │          │  │          │  │          │  │ Active   │              │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘              │
│                                                                         │
│  REQUIRES MY APPROVAL                                         [View All]│
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  ● Validation Gate — Fraud Scorer v2         Tier 1  ⏰ SLA: 4h │  │
│  │    Lead Validator: John Doe  ·  3 findings (1 Critical, 2 Major) │  │
│  │    [Review & Approve]  [Review & Reject]                         │  │
│  ├──────────────────────────────────────────────────────────────────┤  │
│  │  ● Inception Gate — AML Transaction Monitor  Tier 1  ⏰ SLA: 8h │  │
│  │    Owner: Mark Chen  ·  Risk Assessment attached                  │  │
│  │    [Review & Approve]  [Review & Reject]                         │  │
│  ├──────────────────────────────────────────────────────────────────┤  │
│  │  ● Risk Override Request — Credit Limit Model  Tier 2            │  │
│  │    ML Engineer: requested deployment block override               │  │
│  │    [Review Override Request]                                     │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  CRITICAL ALERTS                                                        │
│  🔴  Data drift CRITICAL — Fraud Scorer v1.2.0   Production  Now      │
│      PSI score: 0.42 (threshold: 0.25)  [View Incident]               │
│                                                                         │
│  TIER 1 MODEL HEALTH                                       [Full Report]│
│  7 models  ·  5 validated  ·  1 validation overdue  ·  1 retiring     │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.3 Home Screen — Model Owner

**Design intent:** Portfolio health at a glance. My models, their status, anything needing my attention.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Good morning, Jane                                Tuesday, Nov 15 2024 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  MY PORTFOLIO  (6 models)                                               │
│                                                                         │
│  Model                       Stage         Status       Alerts  Action  │
│  ────────────────────────────────────────────────────────────────────── │
│  Credit Default Predictor    Development   IN PROGRESS  —       [Open]  │
│  Tier 2  MOD-2024-00421                                                 │
│  ────────────────────────────────────────────────────────────────────── │
│  Fraud Scorer v2             Validation    PENDING REV  ⚠ 1    [Open]  │
│  Tier 1  MOD-2024-00387                                                 │
│  ────────────────────────────────────────────────────────────────────── │
│  Churn Predictor v3          Monitoring    ACTIVE       🔴 1    [Open]  │
│  Tier 2  MOD-2023-00291                                                 │
│  ────────────────────────────────────────────────────────────────────── │
│  Mortgage Risk Score         Monitoring    ACTIVE       —       [Open]  │
│  Tier 1  MOD-2023-00198                                                 │
│  ────────────────────────────────────────────────────────────────────── │
│  Vendor: Tableau Einstein    Active        UNDER REVIEW —       [Open]  │
│  Tier 3  VEND-2024-00042                                                │
│  ────────────────────────────────────────────────────────────────────── │
│                                                                         │
│  PENDING MY APPROVAL                                                    │
│  ●  Production Promotion — Fraud Scorer v2  [Approve] [Reject]         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.4 Home Screen — Auditor / Compliance Manager

**Design intent:** Portfolio compliance status. Quick path to reports and audit trail.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Compliance Overview                               Tuesday, Nov 15 2024 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐             │
│  │  47       │ │  43       │ │   4       │ │  95.3%    │             │
│  │  Total    │ │ Validated │ │Validation │ │  Tag      │             │
│  │  Models   │ │          │ │  Overdue  │ │Compliance │             │
│  └───────────┘ └───────────┘ └───────────┘ └───────────┘             │
│                                                                         │
│  TIER 1 MODELS — COMPLIANCE STATUS                                      │
│  Model                  Validated    Last Review    Next Review  Status │
│  Fraud Scorer v2        ✅ Yes       2024-09-15     2025-03-15   OK    │
│  Mortgage Risk Score    ✅ Yes       2024-08-01     2025-02-01   ⚠ Due │
│  AML Monitor            ❌ No        —              —            🔴 Act │
│                                                                         │
│  QUICK ACTIONS                                                          │
│  [Export Model Inventory (CSV)]   [Generate SR 11-7 Package]           │
│  [View Global Audit Log]          [Export Compliance Report (PDF)]     │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Portfolio Dashboard

Accessible from sidebar [▦ Dashboard]. Primary view for executives and governance overview.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Portfolio Dashboard                    [Filter: All Domains ▼] [Export]│
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌─────────┐ │
│  │    47     │ │    12     │ │    8      │ │    3      │ │    4    │ │
│  │   Total   │ │  Active   │ │Validation │ │ Critical  │ │Retiring │ │
│  │  Models   │ │Production │ │In Progress│ │  Alerts   │ │         │ │
│  └───────────┘ └───────────┘ └───────────┘ └───────────┘ └─────────┘ │
│                                                                         │
├──────────────────────────────────────┬──────────────────────────────────┤
│  MODELS BY STAGE                     │  MODELS BY RISK TIER             │
│                                      │                                  │
│  Inception     ████░░░░░░   6        │  Tier 1 (Critical)  ███░   7    │
│  Development   ████████░░  14        │  Tier 2 (High)      ██████ 18   │
│  Validation    █████░░░░░   9        │  Tier 3 (Medium)    ████   12   │
│  Implementation ████░░░░░░   7        │  Tier 4 (Low)       ████   10   │
│  Monitoring    ████████░░  12        │                                  │
│  Retirement    ██░░░░░░░░   3        │                                  │
│  Retired       ██░░░░░░░░   3        │  (Stacked bar —                  │
│                                      │   click to filter)               │
├──────────────────────────────────────┴──────────────────────────────────┤
│  ALL MODELS                                          [Search] [Filter ▼]│
│                                                                         │
│  Name                   Type    Stage      Status       Tier  Alerts   │
│  ──────────────────────────────────────────────────────────────────    │
│  Fraud Scorer v2        Internal Validation PENDING REV  ●1   ⚠ 1     │
│  Credit Default Pred    Internal Development IN PROGRESS ●2   —       │
│  Churn Predictor v3     Internal Monitoring  ACTIVE      ●2   🔴 1    │
│  Mortgage Risk Score    Internal Monitoring  ACTIVE      ●1   —       │
│  Tableau Einstein       Vendor   Active      UNDER REV   ●3   —       │
│  GPT-4 Claims Assist    GenAI    Monitoring  ACTIVE      ●1   ⚠ 2    │
│  AML Transaction Mon.   Internal Inception   PENDING REV ●1   —       │
│  [Load more...]                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**Dashboard behaviors:**
- Metric cards are clickable and filter the model table below
- Stage bar chart segments are clickable (filter by stage)
- Risk tier chart segments are clickable (filter by tier)
- Table supports sort by any column
- Export button generates CSV of current filtered view
- [Filter ▼] opens a filter panel: domain, owner, risk tier, stage, status, alerts, model type

---

## 7. Model Project — Overview & Lifecycle Map

### 7.1 Project Header (Persistent across all project pages)

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Credit Default Predictor                              [⭐ Pin] [···]   │
│  MOD-2024-00421  ·  ● Tier 2  ·  Credit Risk  ·  Owner: Jane Smith    │
│  AWS: 987654321098 / us-east-1  ·  MPG: credit-default-pred-mpg       │
├─────────────────────────────────────────────────────────────────────────┤
│  [Overview] [Lifecycle] [Inception] [Development] [Validation]          │
│  [Implementation] [Monitoring] [Versions] [Registry] [Audit] [Settings]│
└─────────────────────────────────────────────────────────────────────────┘
```

- Tier badge uses tier color system
- `[···]` exposes: Export Project, Archive Project, Initiate Retirement
- Tab bar highlights active stage; grayed tabs are not-yet-started stages

### 7.2 Lifecycle Map — The Hero Feature

The lifecycle map is the visual centerpiece of MLM. It should be immediately readable — a user should understand the complete state of a model project in under 5 seconds.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  LIFECYCLE MAP — Credit Default Predictor                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│    ✅          ●            ○          ○           ○          ○        │
│  INCEPTION  DEVELOPMENT  VALIDATION  IMPL.      MONITORING  VERSION   │
│  Completed  In Progress  Not Started Not Started Not Started           │
│  Nov 10     Started Nov  —           —           —                    │
│             12                                                          │
│     │           │                                                       │
│     ●───────────●───────────○───────────○───────────○                  │
│  (track line — filled segments = completed/active)                     │
│                                                                         │
│  CURRENT STAGE DETAIL                                                   │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  Stage 2: Development                         IN PROGRESS        │  │
│  │  Started: November 12, 2024  ·  Active since: 3 days            │  │
│  │                                                                  │  │
│  │  Completion:  ████████░░░░  65%                                  │  │
│  │                                                                  │  │
│  │  Checklist:                                                      │  │
│  │  ✅ Development Plan uploaded                                    │  │
│  │  ✅ Code repository linked                                       │  │
│  │  ✅ MLflow integration active  (14 runs synced)                  │  │
│  │  ✅ Candidate model selected   run-abc123                        │  │
│  │  ✅ Training data snapshot     SHA: a3f2...                      │  │
│  │  ⏳ Model card (draft)         Not uploaded                      │  │
│  │  ⏳ Bias & fairness assessment  Not uploaded (required: Tier 2)  │  │
│  │                                                                  │  │
│  │  Gate Status:  NOT SUBMITTED  (2 items outstanding)              │  │
│  │  [Submit for Gate Review]  ← disabled until checklist complete   │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  WORKFLOW HISTORY                                                       │
│  ✅  Nov 10  Inception Approved — Jane Smith (Model Owner)             │
│  ●   Nov 10  Development Started — System                              │
│  ●   Nov 12  MLflow integration configured — Bhavik Patel              │
│  ●   Nov 14  Candidate selected: run-abc123 — Bhavik Patel             │
└─────────────────────────────────────────────────────────────────────────┘
```

**Lifecycle map behaviors:**
- Stage nodes are clickable — navigates to that stage panel
- Completed stages show green checkmark + completion date
- Current stage shows blue filled circle + status badge
- Future stages show empty circle (grayed)
- Checklist completion drives the progress bar
- Gate submit button is disabled until required checklist items are complete (tooltip explains what's missing)
- Workflow history is paginated, newest first

---

## 8. Stage 1 — Inception UI

### 8.1 New Project Wizard (First-Run)

Triggered from `[+ New]` button. A multi-step wizard — not a single overwhelming form.

```
New Model Project — Step 1 of 4: Basic Information

  Project Name *
  [Credit Default Predictor                              ]

  Description *
  [ML model to predict probability of credit default at  ]
  [loan application. Used in underwriting decision flow. ]

  Business Domain *
  [Credit Risk ▼]

  Model Type *
  (●) Internal Model    — Built and trained by our team
  (○) Vendor / Embedded — Third-party tool with embedded AI
  (○) GenAI / LLM       — Foundation model or RAG system

  Tags
  [credit] [underwriting] [+ Add tag]

  ────────────────────────────────────────────────────────
  [Cancel]                              [Next: Risk & Data →]
```

```
New Model Project — Step 2 of 4: Risk & Regulatory Scope

  What decisions will this model influence? *
  (○) Informational only   — Human reviews all outputs
  (○) Decision support     — Human reviews flagged outputs
  (●) Decision making      — Model output drives decision
  (○) Autonomous           — No human review of individual outputs

  What is the impact if this model is wrong? *
  (○) Minimal — No financial or regulatory consequence
  (●) Moderate — Financial impact or operational disruption
  (○) Significant — Regulatory consequence or customer harm
  (○) Critical — Systemic risk or severe regulatory exposure

  Applicable Regulations  (select all that apply)
  [✅] SR 11-7    [✅] FCRA    [○] GDPR
  [○] EU AI Act   [○] ECOA    [○] None

  ⚙ Calculated Risk Tier:  ● Tier 2 (High)
  Based on: Decision Making + Moderate Impact + SR 11-7 applicable
  [Override Risk Tier]  ← Risk Officer only

  ────────────────────────────────────────────────────────
  [← Back]                        [Next: Data & Stakeholders →]
```

```
New Model Project — Step 3 of 4: Data & Stakeholders

  Data Sources (describe or list)
  [Credit bureau data, internal loan application data,   ]
  [income verification API                               ]

  Contains PII?  (●) Yes  (○) No
  Data Classification  [Confidential ▼]

  Model Owner *           [Jane Smith ▼]
  Data Scientist(s)       [Bhavik Patel ▼]  [+ Add]
  ML Engineer(s)          [Tom Richards ▼]  [+ Add]

  Cost Center *           [CC-4821]

  Notify stakeholders on project creation?  (●) Yes  (○) No

  ────────────────────────────────────────────────────────
  [← Back]                            [Next: AWS Environment →]
```

```
New Model Project — Step 4 of 4: AWS Environment

  Target AWS Account ID *   [987654321098]
  Target AWS Region *       [us-east-1 ▼]

  Provisioning Method
  (●) Automated — Trigger ServiceNow catalog request
  (○) Manual    — I will tag resources manually

  Requested Resources  (for automated provisioning)
  [✅] SageMaker Project
  [✅] S3 Training Data Bucket
  [✅] SageMaker Model Package Group
  [✅] IAM Roles (Data Scientist, ML Engineer)
  [○]  SageMaker Experiment

  Preview: Tags to be applied
  ┌──────────────────────────────────────────────────────┐
  │  mlm:model-id        MOD-2024-00422 (auto-assigned)  │
  │  mlm:project-name    credit-default-predictor        │
  │  mlm:risk-tier       2                               │
  │  mlm:owner-email     jane@company.com                │
  │  mlm:environment     development                     │
  │  cost-center         CC-4821                         │
  └──────────────────────────────────────────────────────┘

  ────────────────────────────────────────────────────────
  [← Back]                                  [Create Project ✓]
```

### 8.2 Inception Stage Panel

After creation, the Inception stage panel captures all required artifacts:

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Stage 1: Inception                                    IN PROGRESS ●    │
│  Started: Nov 10, 2024  ·  Owner: Jane Smith  ·  Tier 2               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  REQUIRED ARTIFACTS                              Completion: 5/7       │
│                                                                         │
│  ✅ Project Charter           charter-v1.pdf           Nov 10          │
│     [Download] [Replace]                                                │
│  ✅ Use Case Description      use-case.docx            Nov 10          │
│  ✅ Data Availability Report  data-avail.pdf           Nov 11          │
│  ✅ Risk Classification       [Tier 2 — auto-generated]                │
│  ✅ Stakeholder Registry      stakeholders.xlsx        Nov 11          │
│  ⏳ Regulatory Scope Document  [Upload]                                 │
│  ⏳ Feasibility Assessment    [Upload]                                  │
│                                                                         │
│  COMMENTS & ACTIVITY                            [+ Add Comment]        │
│  Jane Smith  Nov 11  "Data availability confirmed with DBA team."      │
│  System      Nov 10  Project created. Provisioning request sent.       │
│                                                                         │
│  GATE REVIEW                                                            │
│  Required approvers:  Jane Smith (Model Owner) + Sarah Lee (Risk Officer)│
│  [Submit for Gate Review]   ← Disabled: 2 artifacts outstanding        │
│  ⚠ Outstanding: Regulatory Scope Document, Feasibility Assessment      │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 9. Stage 2 — Development UI

The Development stage is where Data Scientists spend the most time. It must feel native to their workflow.

### 9.1 Development Stage Panel

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Stage 2: Development                                  IN PROGRESS ●    │
│  Started: Nov 12, 2024  ·  Data Scientist: Bhavik Patel                │
├──────────────────────┬──────────────────────────────────────────────────┤
│  TABS                │                                                   │
│  [Experiments] [●]  │  MLFLOW EXPERIMENTS                              │
│  [Artifacts]        │  Platform: SageMaker Experiments (MLflow)         │
│  [Candidate]  [✓]   │  Tracking URI: https://...  ·  ✅ Connected       │
│  [Gate]             │  Last sync: 2 minutes ago  ·  14 runs            │
│                     │                                    [↻ Refresh]    │
│                     │  [Search runs...]  [Filter ▼]  [Sort: Latest ▼]  │
│                     │                                                   │
│                     │  Run Name           AUC    F1    Created   Status │
│                     │  ─────────────────────────────────────────────── │
│                     │  ★ run-abc123       0.923  0.891  Nov 14  ✅     │
│                     │  (CANDIDATE)                                      │
│                     │  ─────────────────────────────────────────────── │
│                     │  run-def456         0.915  0.882  Nov 13  ✅     │
│                     │  run-ghi789         0.901  0.870  Nov 13  ✅     │
│                     │  run-jkl012         0.887  0.851  Nov 12  ✅     │
│                     │  run-mno345         0.843  0.810  Nov 12  Failed │
│                     │  [Load 9 more runs...]                            │
│                     │                                                   │
│                     │  [View in SageMaker Studio ↗]                    │
└──────────────────────┴──────────────────────────────────────────────────┘
```

### 9.2 Candidate Model Detail

When a run is selected and candidate is registered:

```
┌─────────────────────────────────────────────────────────────────────────┐
│  CANDIDATE MODEL                                           ★ SELECTED  │
│  run-abc123  ·  Registered: Nov 14, 2024  ·  By: Bhavik Patel         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  PERFORMANCE METRICS          PARAMETERS                               │
│  AUC:            0.923        learning_rate:   0.01                    │
│  F1 Score:       0.891        max_depth:       6                       │
│  Precision:      0.887        n_estimators:    500                     │
│  Recall:         0.895        subsample:       0.8                     │
│  Log Loss:       0.214                                                  │
│                                                                         │
│  TRAINING METRICS OVER EPOCHS                                           │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  1.0 ┤                                              ╭────────    │  │
│  │  0.9 ┤                              ╭───────────────╯            │  │
│  │  0.8 ┤                    ╭─────────╯                            │  │
│  │  0.7 ┤          ╭─────────╯                                      │  │
│  │  0.6 ┤ ╭────────╯                                                │  │
│  │      └──────────────────────────────────────────────────────     │  │
│  │         0    100    200    300    400    500 epochs               │  │
│  │      — AUC (train)    ·· AUC (validation)                       │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│  (Rendered from MLM-stored snapshot — no MLflow dependency)            │
│                                                                         │
│  ARTIFACT REFERENCES                                                    │
│  Model artifact:    s3://mlm-dev-credit.../model.tar.gz  [Copy URI]   │
│  Training data:     s3://mlm-dev-credit.../train-2024... [Copy URI]   │
│  Data hash (SHA):   a3f2c8d9...  ✅ Verified                           │
│                                                                         │
│  MODEL SIGNATURE                                                        │
│  Inputs:   [feature_1: float, feature_2: float, ...  +12 more]        │
│  Outputs:  [probability: float, label: int]                            │
│                                                                         │
│  [Change Candidate]   [View in SageMaker Studio ↗]                    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 10. Stage 3 — Validation UI

### 10.1 Validation Workbench

The most complex stage UI — designed for validators doing structured, evidence-backed testing.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Stage 3: Validation                              PENDING REVIEW ●      │
│  Validators: John Doe (Lead), Lisa Park ·  Tier 2 Test Plan           │
├──────────────────────────────────────────────────────────────────────── │
│  TABS:  [Test Plan] [Findings (3)] [Evidence] [Report] [Gate]           │
├─────────────────────────────────────────────────────────────────────────┤
│  TEST PLAN                                    Completion: 6/9  (67%)   │
│                                                                         │
│  Category                          Status    Result    Evidence        │
│  ────────────────────────────────────────────────────────────────────  │
│  Conceptual Soundness Review        ✅ Done   PASS      [2 files]      │
│  Performance Testing                ✅ Done   PASS      [1 file]       │
│  Stability Testing                  ✅ Done   PASS      [3 files]      │
│  Sensitivity Analysis               ✅ Done   PASS      [1 file]       │
│  Bias & Fairness Testing            ✅ Done   COND.PASS [2 files]      │
│  Explainability Testing             ✅ Done   PASS      [1 file]       │
│  Data Quality Validation            ⏳ In Progress  —   —              │
│  Regulatory Compliance Check        ⏳ Not Started  —   —              │
│  Replication Test                   ⏳ Not Started  —   —              │
│                                                                         │
│  [Record Test Result — Data Quality]                                    │
└─────────────────────────────────────────────────────────────────────────┘
```

### 10.2 Record Test Result Modal

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Record Test Result: Bias & Fairness Testing                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Result *                                                               │
│  (○) PASS            — All criteria met without conditions              │
│  (●) CONDITIONAL PASS — Criteria met with documented conditions         │
│  (○) FAIL            — Criteria not met; finding raised                │
│                                                                         │
│  Conditions (required for Conditional Pass) *                           │
│  [Disparate impact ratio for protected class A is 0.82, above          ]│
│  [the 0.80 threshold, but bias remediation plan required within        ]│
│  [30 days of deployment.                                               ]│
│                                                                         │
│  Attach Evidence * (required)                                           │
│  [📎 Drop files or click to upload]                                     │
│  bias-fairness-report-2024-11-14.pdf  ·  2.4 MB  ✅                   │
│  shap-analysis-output.html            ·  1.1 MB  ✅                   │
│                                                                         │
│  Raise Finding?                                                         │
│  [○] No finding      [●] Yes — raise finding alongside result          │
│                                                                         │
│  Finding Title:  [Disparate impact ratio requires remediation plan]    │
│  Severity:       [● Major ▼]                                           │
│                                                                         │
│  [Cancel]                                        [Save Test Result]    │
└─────────────────────────────────────────────────────────────────────────┘
```

### 10.3 Findings Tracker

```
┌─────────────────────────────────────────────────────────────────────────┐
│  FINDINGS                          [+ Raise Finding]  [Export CSV]     │
│  3 total  ·  0 Critical  ·  2 Major  ·  1 Minor                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ●MAJOR  F-042  Disparate impact ratio requires remediation plan        │
│  Raised by: John Doe  ·  Nov 14  ·  Status: IN_REMEDIATION             │
│  Remediation: "Bias monitoring configured; plan submitted Nov 15"       │
│  [View Details]  [Mark Resolved]                                        │
│  ────────────────────────────────────────────────────────────────────  │
│  ●MAJOR  F-043  Training data vintage mismatch in Q3 sample             │
│  Raised by: Lisa Park  ·  Nov 13  ·  Status: OPEN                      │
│  No remediation plan yet.  ⚠ Required before gate approval             │
│  [View Details]  [Add Remediation Plan]                                 │
│  ────────────────────────────────────────────────────────────────────  │
│  ●MINOR  F-044  Model card missing inference latency benchmarks         │
│  Raised by: John Doe  ·  Nov 14  ·  Status: OPEN                       │
│  [View Details]  [Add Remediation Plan]                                 │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 11. Stage 4 — Implementation UI

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Stage 4: Implementation                              IN PROGRESS ●     │
├──────────────────────────────────────────────────────────────────────── │
│  TABS:  [Deployment Plan] [Staging] [Production] [Deployments]          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  DEPLOYMENT CONFIGURATION          Platform: SageMaker Endpoint        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  Instance Type:    ml.m5.xlarge (4 vCPU, 16GB)                  │  │
│  │  Initial Count:    2 instances (auto-scale: 2–10)                │  │
│  │  Strategy:         Blue / Green                                  │  │
│  │  Data Capture:     Enabled (10% sample → S3)                     │  │
│  │  Endpoint Name:    credit-default-pred-v120-prod                  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  DEPLOYMENT PIPELINE                                                    │
│  ✅ Staging deployment        Completed Nov 15 10:30  [View Logs ↗]    │
│  ✅ Smoke tests               PASSED (12/12)          [View Results]   │
│  ✅ Integration tests         PASSED (45/45)          [View Results]   │
│  ⏳ Production Promotion Gate  PENDING APPROVAL                         │
│                                                                         │
│  DEPLOYMENT ELIGIBILITY CHECK                                           │
│  Model: MOD-2024-00421  ·  v1.2.0  ·  production                      │
│  Status: ✅ ELIGIBLE                                                    │
│  Validation date: Nov 15, 2024  ·  Expiry: Nov 15, 2025               │
│                                                                         │
│  PRODUCTION PROMOTION GATE                                              │
│  Requires: Tom Richards (ML Engineer) + Jane Smith (Model Owner)        │
│  Tom Richards: ✅ Approved (Nov 15 11:00)                               │
│  Jane Smith:   ⏳ Pending                                               │
│  [Send Reminder to Jane Smith]                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 12. Stage 5 — Monitoring UI

### 12.1 Monitoring Dashboard

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Stage 5: Monitoring                 ACTIVE ●    [Configure Monitors]  │
│  Deployed: Nov 16, 2024  ·  Endpoint: credit-default-pred-v120-prod    │
│  [Time Window: 30d ▼]                                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  MONITOR STATUS                                                         │
│  ✅ Data Quality      Last check: 5m ago  ·  PASS                      │
│  ⚠ Data Drift        Last check: 5m ago  ·  WARNING — PSI: 0.18       │
│  ✅ Model Performance  Last check: 1h ago  ·  PASS — AUC: 0.919        │
│  ✅ Infrastructure     Last check: 1m ago  ·  PASS — Latency: 42ms     │
│  [View in Datadog ↗]  [View in CloudWatch ↗]                           │
│                                                                         │
│  ACTIVE ALERTS                                         [View All]      │
│  ⚠ WARNING  Data drift — feature_age_of_account   Nov 15  [Acknowledge]│
│                                                                         │
│  PERFORMANCE TREND  (V1: link-out to native monitoring)                 │
│  AUC at deployment:  0.923  ·  Current AUC:  0.919  ·  Δ -0.004       │
│  [Full Performance Dashboard in SageMaker Model Monitor ↗]             │
│                                                                         │
│  INCIDENTS                                         [+ Create Incident] │
│  No open incidents                                                      │
│                                                                         │
│  GROUND TRUTH UPLOADS                              [Upload Ground Truth]│
│  Last upload: Nov 10  ·  Coverage: Oct 2024 actuals                    │
│  Realized AUC (Oct): 0.917  ✅ Within tolerance                        │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 13. Stage 6 — Versioning UI

### 13.1 Version Explorer

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Versions — Credit Default Predictor               [+ New Version]     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  VERSION LINEAGE                                                        │
│                                                                         │
│  v1.0.0 ────► v1.1.0 ────► v1.2.0 (current, deployed)                 │
│                   │                                                     │
│                   └──────► v2.0.0 (in development)                     │
│                                                                         │
│  VERSION TABLE                                        [Compare Versions]│
│                                                                         │
│  Version  Status       AUC    Deployed    Validated   Action           │
│  ──────────────────────────────────────────────────────────────────    │
│  v2.0.0   IN_DEVELOPMENT  —    —          —          [View Dev Stage]  │
│  v1.2.0   DEPLOYED     0.923  Nov 16     Nov 15      [Active]         │
│  v1.1.0   SUPERSEDED   0.910  Sep 12     Sep 10      [View Details]   │
│  v1.0.0   SUPERSEDED   0.895  Jun 5      Jun 3       [View Details]   │
│                                                                         │
│  [Compare v1.1.0 vs v1.2.0]                                            │
└─────────────────────────────────────────────────────────────────────────┘
```

### 13.2 Version Comparison View

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Version Comparison:   [v1.1.0 ▼]  vs  [v1.2.0 ▼]                    │
├─────────────────────────────────────────────────────────────────────────┤
│                          v1.1.0          v1.2.0         Change         │
│  ────────────────────────────────────────────────────────────────────  │
│  METRICS                                                                │
│  AUC                    0.910           0.923          ↑ +0.013  ✅    │
│  F1 Score               0.872           0.891          ↑ +0.019  ✅    │
│  Precision              0.869           0.887          ↑ +0.018  ✅    │
│  Log Loss               0.241           0.214          ↓ -0.027  ✅    │
│                                                                         │
│  PARAMETERS                                                             │
│  learning_rate          0.01            0.01           — same          │
│  max_depth              5               6              ↑ changed       │
│  n_estimators           300             500            ↑ changed       │
│                                                                         │
│  VALIDATION                                                             │
│  Bias & Fairness        PASS            COND. PASS     ⚠ changed       │
│  Performance            PASS            PASS           — same          │
│  Stability              PASS            PASS           — same          │
│                                                                         │
│  TRAINING DATA                                                          │
│  Dataset                2024-Q2         2024-Q3        ↑ updated       │
│  Row count              2.1M            2.8M           ↑ +700K         │
│                                                                         │
│  DEPLOYMENT                                                             │
│  Deployed               Sep 12          Nov 16         — —             │
│  Superseded             Nov 16          Active         — —             │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 14. Stage 7 — Retirement UI

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Stage 7: Retirement                             INITIATED ●            │
│  Initiated: Nov 20, 2024  ·  By: Jane Smith  ·  Reason: Supersession  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  RETIREMENT TIMELINE                                                    │
│  ✅  Nov 20  Retirement initiated — Jane Smith                          │
│  ✅  Nov 20  Eligibility API: model marked RETIRING                     │
│  ✅  Nov 20  Consumer notifications sent (14 registered consumers)      │
│  ⏳  Dec 20  Transition period ends (30 days)                           │
│  ○   Dec 20  Decommission gate                                          │
│  ○   Dec 20  Deployments terminated                                     │
│  ○   Dec 20  Monitoring deactivated                                     │
│  ○   Dec 20  Artifact archival                                          │
│                                                                         │
│  CONSUMER STATUS                                          14 consumers  │
│  ✅ 11 consumers acknowledged retirement notice                         │
│  ⚠   3 consumers have not acknowledged                                  │
│  [Send Reminder to Unacknowledged Consumers]                            │
│                                                                         │
│  RETIREMENT PLAN                                                        │
│  Reason:      Superseded by v2.0.0                                      │
│  Successor:   MOD-2024-00421 v2.0.0                                    │
│  [retirement-plan.pdf]  [View Retirement Report Draft]                  │
│                                                                         │
│  DECOMMISSION GATE  (available Dec 20)                                  │
│  [Approve Decommission]  — Available after transition period            │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 15. My Tasks — Approval Workflows

### 15.1 My Tasks Page

The task-centric view for approvers. This is the primary landing for Risk Officers.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  My Tasks                                                               │
│  [Pending Approvals (3)] [Open Findings (2)] [Incidents (1)] [Overdue] │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  PENDING APPROVALS                                      Sorted: SLA ↑  │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  🔴 SLA: 4 hours remaining                                       │  │
│  │  Validation Gate — Fraud Scorer v2           Tier 1             │  │
│  │  MOD-2024-00387  ·  Submitted by: John Doe (Lead Validator)     │  │
│  │  Nov 15, 2024 09:00                                             │  │
│  │                                                                  │  │
│  │  Summary:                                                        │  │
│  │  • 9/9 test cases completed  ·  0 Critical  ·  1 Major finding  │  │
│  │  • Major finding: F-042 — Bias remediation plan attached        │  │
│  │  • Validation report: validation-summary-v2.pdf                 │  │
│  │                                                                  │  │
│  │  [📄 View Validation Report]  [📋 View Full Stage]              │  │
│  │                                                                  │  │
│  │  Decision Comment (optional)                                     │  │
│  │  [                                                            ]  │  │
│  │                                                                  │  │
│  │  [✅ Approve]     [⚠ Conditional Approve]     [❌ Reject]      │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  ⚠ SLA: 8 hours remaining                                       │  │
│  │  Inception Gate — AML Transaction Monitor    Tier 1             │  │
│  │  MOD-2024-00441  ·  Submitted by: Mark Chen (Model Owner)       │  │
│  │  [📄 View Documents]  [✅ Approve]  [❌ Reject]                 │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

### 15.2 Approval Confirmation Modal

Every approval/rejection triggers a confirmation with consequence statement — no silent actions.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Confirm: Approve Validation Gate                                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  You are approving the Validation Gate for:                             │
│  Fraud Scorer v2  ·  v2.0.0  ·  MOD-2024-00387                        │
│                                                                         │
│  What happens next:                                                     │
│  ✅  Model version v2.0.0 will be tagged VALIDATED                      │
│  ✅  Deployment eligibility will be granted for staging                 │
│  ✅  Stage 4 (Implementation) will be activated                         │
│  ✅  Model Owner and ML Engineer will be notified                       │
│  ✅  This approval will be recorded in the immutable audit log          │
│                                                                         │
│  Your comment:                                                          │
│  "Validation complete. Bias remediation plan accepted. Proceed          │
│  with staging deployment."                                              │
│                                                                         │
│  ⚠ This action cannot be undone. Your identity (Sarah Lee) and        │
│    timestamp will be permanently recorded.                              │
│                                                                         │
│  [Cancel]                                      [Confirm Approval ✅]   │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 16. Inline Approval — Email & Slack

### 16.1 Email Notification Design

Approval request emails are designed to provide full context and enable one-click decisions without requiring login.

```
Subject: [MLM] ⏰ Approval Required: Validation Gate — Fraud Scorer v2 (SLA: 8hrs)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  MLM — Model Lifecycle Management
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Your approval is required for the following gate:

  Model:    Fraud Scorer v2           (MOD-2024-00387)
  Version:  v2.0.0
  Stage:    Validation Gate
  Risk:     ● Tier 1 (Critical)
  Submitted by:  John Doe (Lead Validator)
  SLA:      8 hours remaining

  ─────────────────────────────────────────────────────
  VALIDATION SUMMARY
  ─────────────────────────────────────────────────────
  Test cases completed:  9 / 9
  Critical findings:     0
  Major findings:        1 (with remediation plan)
  Minor findings:        2

  Major Finding: F-042 — Disparate impact ratio
  Remediation:   Bias monitoring configured; plan attached

  ─────────────────────────────────────────────────────

  ┌─────────────────────┐  ┌─────────────────────────┐
  │   ✅ APPROVE        │  │   ❌ REJECT              │
  │                     │  │                         │
  │ https://mlm.co/...  │  │ https://mlm.co/...      │
  │ (one-time token)    │  │ (one-time token)         │
  └─────────────────────┘  └─────────────────────────┘

  These links expire in 8 hours.
  For conditional approval or to add comments:
  → View Full Stage: https://mlm.company.com/models/...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Model Lifecycle Management Platform
  This action will be recorded in the audit log.
```

### 16.2 Inline Approval Landing Page

When approver clicks [APPROVE] from email without being logged in:

```
┌─────────────────────────────────────────────────────────────────────────┐
│  MLM — Quick Approval                                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  You are approving:                                                     │
│                                                                         │
│  Validation Gate — Fraud Scorer v2                                      │
│  MOD-2024-00387  ·  v2.0.0  ·  Tier 1                                 │
│                                                                         │
│  Approving as:  Sarah Lee (Risk Officer)                               │
│  Token expires: 2 hours 14 minutes                                      │
│                                                                         │
│  Add a comment (optional):                                              │
│  [                                                                   ]  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │  By clicking Confirm, you are:                                    │ │
│  │  • Approving the Validation Gate for Fraud Scorer v2 v2.0.0      │ │
│  │  • Granting deployment eligibility for staging environment        │ │
│  │  • Recording this decision in the immutable audit log             │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│               [Cancel]      [✅ Confirm Approval]                       │
│                                                                         │
│  Want full context first?  [View Full Validation Stage →]              │
└─────────────────────────────────────────────────────────────────────────┘
```

### 16.3 Slack Notification Design

```
┌─────────────────────────────────────────────────────────────────────────┐
│  🔔 MLM Approval Required                                               │
│                                                                         │
│  Validation Gate approval needed for:                                   │
│  *Fraud Scorer v2* (MOD-2024-00387 · v2.0.0)                          │
│  Risk: 🔴 Tier 1 · Submitted by: John Doe                             │
│  ⏰ SLA: 8 hours remaining                                             │
│                                                                         │
│  Summary: 9/9 tests complete · 0 Critical · 1 Major (remediated)      │
│                                                                         │
│  [✅ Approve]  [❌ Reject]  [View Full Stage ↗]                        │
│                                                                         │
│  Slack approvals use one-time secure tokens. Expires in 8 hours.       │
└─────────────────────────────────────────────────────────────────────────┘
```

Slack action buttons call MLM API with one-time token — no browser redirect required for simple approve/reject.

---

## 17. Vendor Model UI

Vendor models use a simplified, card-based layout — not the full 7-stage lifecycle panel.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Tableau Einstein Analytics                        VEND-2024-00042      │
│  Vendor Model  ·  ● Tier 3  ·  Sales Analytics  ·  Status: ACTIVE     │
├──────────────────────────────────────────────────────────────────────── │
│  TABS:  [Overview] [Due Diligence] [Risk Assessment] [Reviews] [Audit]  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  VENDOR INFORMATION                                                     │
│  Provider:         Tableau / Salesforce                                 │
│  Product:          Tableau 2024.1                                       │
│  Capability:       Sales forecasting, anomaly detection on dashboards   │
│  Hosting:          Vendor cloud (Salesforce infrastructure)             │
│  Data sent:        Aggregated sales metrics — NO PII                   │
│  Contract Ref:     MSA-2024-TAB-001                                     │
│  DPA confirmed:    ✅ Yes — data does not leave US region               │
│  Model training:   ✅ Opted out of Tableau model training               │
│                                                                         │
│  REVIEW SCHEDULE                                                        │
│  Last review:      March 2024  ·  Next review: March 2025  ✅ OK       │
│  Review Owner:     Mark Chen                                            │
│  [Schedule Review]                                                      │
│                                                                         │
│  DUE DILIGENCE DOCUMENTS                                                │
│  ✅ Tableau SOC 2 Type II Report 2024        [Download]                │
│  ✅ Model Methodology Overview (Tableau)     [Download]                │
│  ⏳ Independent benchmark results            [Upload]                   │
│                                                                         │
│  USAGE VOLUME  (manual / API)                                           │
│  Nov 2024:  ~4,200 forecasts generated                                  │
│  [Update Usage]                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 18. GenAI / LLM Model UI

GenAI models extend the standard stage panels with LLM-specific components.

### 18.1 Prompt Registry Panel (within Development Stage)

```
┌─────────────────────────────────────────────────────────────────────────┐
│  PROMPT REGISTRY                                    [+ New Version]     │
│  Active in production: v2.1.0  ·  Last changed: Nov 12                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Version  Status       Changed By    Date      Notes                   │
│  ──────────────────────────────────────────────────────────────────    │
│  v2.1.0   ● DEPLOYED   Bhavik Patel  Nov 12   Added refusal handling   │
│  v2.0.0   SUPERSEDED   Bhavik Patel  Oct 28   Improved claim context   │
│  v1.0.0   SUPERSEDED   Bhavik Patel  Sep 5    Initial prompt           │
│                                                                         │
│  CURRENT SYSTEM PROMPT (v2.1.0)                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  You are an insurance claims assistant. You help policyholders  │  │
│  │  understand their claim status and next steps. You must:        │  │
│  │  1. Only use information from the provided context              │  │
│  │  2. Never speculate about claim outcomes                        │  │
│  │  3. Decline to answer questions unrelated to the claim          │  │
│  │  [Expand...]                                                    │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│  [Edit Prompt]  ← Creates new prompt version; triggers review          │
│                                                                         │
│  GUARDRAIL CONFIGURATION                                                │
│  AWS Bedrock Guardrail:  gr-abc123  ·  ✅ Active                       │
│  Content filters:  HATE, INSULTS, SEXUAL (all blocked)                 │
│  PII redaction:    SSN, Credit Card, Phone — enabled                   │
│  [View Guardrail in Bedrock ↗]                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 18.2 LLM Monitoring Panel

```
┌─────────────────────────────────────────────────────────────────────────┐
│  LLM Monitoring — GPT-4 Claims Assistant          [Time: 30d ▼]        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐   │
│  │  94.2%   │ │  0.8%    │ │  $1,240  │ │  3.2%    │ │  4.1/5   │   │
│  │Grounds.  │ │Hallucin. │ │ Cost/mo  │ │ Refusal  │ │ Feedback │   │
│  │  ✅ OK   │ │  ✅ OK   │ │  ✅ OK   │ │  ✅ OK   │ │  ✅ OK   │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘   │
│                                                                         │
│  ACTIVE ALERTS                                                          │
│  ⚠ Hallucination rate spike detected on Nov 12  [View Incident]        │
│    Rate: 2.1% (threshold: 1.5%) — resolved Nov 13                      │
│                                                                         │
│  PRODUCTION SAMPLE REVIEW QUEUE                                         │
│  12 outputs pending human review                [Open Review Queue]    │
│  Average score: 4.2/5  ·  Last reviewed: Nov 14                       │
│                                                                         │
│  TOKEN BUDGET                                                           │
│  Monthly budget: $2,000  ·  Used: $1,240 (62%)  ·  Projected: $1,890  │
│  ████████████████████░░░░░░░░░░░░░  62%                               │
│                                                                         │
│  KNOWLEDGE BASE (RAG)                                                   │
│  Last updated: Nov 10  ·  Documents: 2,847  ·  Status: ✅ Current      │
│  Staleness threshold: 14 days  ·  Next scheduled update: Nov 24        │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 19. Business Model Registry UI

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Business Model Registry — Credit Default Predictor                    │
│  SM Model Package Group: credit-default-predictor-mpg                  │
│  Last sync: 3 min ago  ·  Status: ✅ IN_SYNC                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  VERSION       MLM STATUS     SM STATUS        SYNC     ELIGIBLE       │
│  ──────────────────────────────────────────────────────────────────    │
│  v1.2.0   ✅ VALIDATED    SM: Approved     ✅ IN_SYNC  ✅ Yes           │
│           Validated: Nov 15  Validated: Nov 15                         │
│  v1.1.0   ⚫ SUPERSEDED   SM: Approved     ✅ IN_SYNC  ❌ No            │
│  v1.0.0   ⚫ SUPERSEDED   SM: Rejected     ✅ IN_SYNC  ❌ No            │
│                                                                         │
│  UNLINKED REGISTRATIONS                                                 │
│  None outstanding                                                       │
│                                                                         │
│  SYNC LOG                                                 [View All]   │
│  ✅ Nov 15 10:32  MLM→SM: validation-status tag updated  v1.2.0       │
│  ✅ Nov 15 10:30  SM→MLM: ModelPackage registered        v1.2.0       │
│  ✅ Nov 10 14:10  Reconciliation: 0 drift found          —             │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 20. Compliance Center

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Compliance Center                                                      │
│  [Model Inventory] [SR 11-7] [EU AI Act] [Tag Compliance] [Audit Log]  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  MODEL INVENTORY                                         [Export CSV]  │
│  47 models  ·  As of: Nov 15, 2024 11:00 UTC                           │
│                                                                         │
│  Model ID         Name                  Type    Tier  Stage      Val.  │
│  ──────────────────────────────────────────────────────────────────    │
│  MOD-2024-00421  Credit Default Pred.  Internal  2   Development  ❌   │
│  MOD-2024-00387  Fraud Scorer v2       Internal  1   Validation   ⏳   │
│  MOD-2023-00291  Churn Predictor v3    Internal  2   Monitoring   ✅   │
│  MOD-2023-00198  Mortgage Risk Score   Internal  1   Monitoring   ✅   │
│  VEND-2024-00042 Tableau Einstein      Vendor    3   Active        —   │
│  GENAI-2024-00012 Claims Assistant     GenAI     1   Monitoring   ✅   │
│  [Export full list...]                                                  │
│                                                                         │
│  SR 11-7 COMPLIANCE PACKAGES                          [Generate New]   │
│  Fraud Scorer v2         Generated Nov 15  [Download PDF]              │
│  Mortgage Risk Score     Generated Oct 1   [Download PDF]              │
│  [Generate for model...]                                                │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 21. Admin Console

### 21.1 Integration Configuration

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Admin → Integration Configuration                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  PROVISIONING INTEGRATIONS                          [+ Add Integration] │
│                                                                         │
│  ServiceNow                                                             │
│  API Destination: mlm-servicenow-provisioning  ·  ✅ Connected         │
│  Last event: 2 hours ago  ·  Success rate: 98.2%                       │
│  [Test Connection]  [Edit]  [Disable]                                   │
│                                                                         │
│  ML PLATFORM INTEGRATIONS                                               │
│  SageMaker (Account: 987654321098)     ✅ Connected  [Test] [Edit]     │
│  Databricks (workspace: company.cloud) ⚠ Degraded   [Test] [Edit]     │
│  MLflow OSS (tracking.company.com)     ✅ Connected  [Test] [Edit]     │
│                                                                         │
│  MONITORING INTEGRATIONS                                                │
│  SageMaker Model Monitor               ✅ Active     [Configure]       │
│  Datadog (link-out only)               ✅ Active     [Configure]       │
│  Custom Ingest API                     ✅ Active  12 sources  [View]   │
│                                                                         │
│  NOTIFICATION CHANNELS                                                  │
│  Email (SMTP)    ✅ Active  smtp.company.com                           │
│  Slack           ✅ Active  #mlm-notifications                         │
│  PagerDuty       ✅ Active  Service: MLM Critical                      │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 22. Onboarding & First-Run Experience

### 22.1 Empty State — First Login

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Welcome to MLM, Bhavik                                                 │
│  Let's get your first model project set up.                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│              ┌──────────────────────────────────────┐                  │
│              │                                      │                  │
│              │     🚀 Start your first project       │                  │
│              │                                      │                  │
│              │  Track your ML model from idea to    │                  │
│              │  production with full governance.    │                  │
│              │                                      │                  │
│              │  [Create Model Project]              │                  │
│              │                                      │                  │
│              └──────────────────────────────────────┘                  │
│                                                                         │
│  OR: Already have models in SageMaker or Databricks?                   │
│  [Import from SageMaker Model Registry]                                 │
│  [Browse existing models in your organization]                          │
│                                                                         │
│  GETTING STARTED                                                        │
│  📖 5-minute quick start guide                                          │
│  🎬 Platform walkthrough video                                          │
│  📋 What is a Risk Tier? Understanding MLM governance                  │
└─────────────────────────────────────────────────────────────────────────┘
```

### 22.2 Contextual Tooltips

First-time users see contextual tooltips on key UI elements. Dismissible; stored in user preferences.

```
  ┌─────────────────────────────────────────────┐
  │ 💡 Risk Tier                            [×] │
  │                                             │
  │ MLM automatically calculates a Risk Tier    │
  │ (1–4) based on the model's autonomy level,  │
  │ decision impact, and applicable regulations.│
  │ Tier 1 models require the most rigorous     │
  │ validation and oversight.                   │
  │                                             │
  │ [Learn more]          [Got it]              │
  └─────────────────────────────────────────────┘
```

---

## 23. Notifications & Alert UX

### 23.1 In-App Notification Panel

Clicking the bell icon in the top bar opens a sliding notification panel:

```
┌─────────────────────────────────────────────┐
│  Notifications              [Mark all read] │
│  [All] [Approvals] [Alerts] [System]        │
├─────────────────────────────────────────────┤
│  🔴  CRITICAL   2 min ago                   │
│  Data drift threshold breached              │
│  Fraud Scorer v2 — Production               │
│  [View Incident]                            │
├─────────────────────────────────────────────┤
│  ✅  APPROVED   1 hour ago                  │
│  Development gate approved                  │
│  Credit Default Predictor v1.2.0            │
│  Approved by: Jane Smith                    │
├─────────────────────────────────────────────┤
│  📋  APPROVAL   3 hours ago                 │
│  Your approval needed: Inception Gate       │
│  AML Transaction Monitor                    │
│  SLA: 5 hours remaining                     │
│  [Review & Decide]                          │
├─────────────────────────────────────────────┤
│  ●  SYNC   Today 09:15                      │
│  MLflow sync: 14 runs synced               │
│  Credit Default Predictor                   │
└─────────────────────────────────────────────┘
```

### 23.2 Alert Banner (In-Page)

For CRITICAL alerts on a project the user is currently viewing:

```
┌─────────────────────────────────────────────────────────────────────────┐
│  🔴 CRITICAL ALERT — Data drift detected in production                 │
│  PSI score: 0.42 (threshold: 0.25) on feature: age_of_account         │
│  Detected: 2 minutes ago  [View Incident]  [Acknowledge]     [Dismiss] │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 24. Accessibility & Responsiveness

### 24.1 Accessibility Standards

| Requirement | Specification |
|-------------|--------------|
| Standard | WCAG 2.1 Level AA |
| Color contrast | Minimum 4.5:1 for body text; 3:1 for large text and UI components |
| Keyboard navigation | All primary workflows completable via keyboard only |
| Focus indicators | Visible focus rings on all interactive elements (min 2px, high contrast) |
| Screen readers | All interactive elements have descriptive aria-labels; status changes announced via aria-live |
| Form validation | Error messages associated with inputs via aria-describedby; errors listed at top of form on submission |
| Motion | Respect prefers-reduced-motion; no auto-playing animations |
| Alt text | All meaningful images and icons have descriptive alt text |

### 24.2 Responsive Behavior

| Viewport | Layout Behavior |
|----------|----------------|
| 1440px+ | Full layout; sidebar expanded; multi-column content |
| 1280px | Full layout; sidebar expanded; slight content compression |
| 1024px | Full layout; sidebar can collapse to icons |
| 768px (tablet min) | Sidebar collapses to icon rail; single-column content; tap targets ≥ 44px |
| < 768px | Not supported in V1; show "please use desktop" message |

**Tablet-specific considerations:**
- Approval workflows are the primary tablet use case — approval cards are full-width with large tap targets
- Data tables switch to card-list view on tablet
- Modals are full-screen on tablet

### 24.3 Loading & Error States

Every data-fetching component has three states explicitly designed:

```
LOADING STATE:
  Skeleton screens (not spinners) — maintain layout during load
  Skeleton uses animated gradient shimmer
  Target: < 500ms before content appears (API P95)

EMPTY STATE:
  Contextual illustration + clear explanation + primary action
  Example: "No MLflow runs yet. Configure your tracking URI to
           start seeing experiments here. [Configure Integration]"

ERROR STATE:
  Clear error message (what happened, not technical jargon)
  Retry action where applicable
  Integration errors degrade gracefully:
    "MLflow integration is temporarily unavailable.
     Showing last synced data from 5 minutes ago. [Retry]"
```

---

## 25. Component Library Reference

### 25.1 Core Components

| Component | Usage | Key Variants |
|-----------|-------|-------------|
| `StatusBadge` | Stage status, version status | NOT_STARTED, IN_PROGRESS, PENDING_REVIEW, APPROVED, REJECTED, COMPLETED |
| `RiskTierBadge` | Model risk tier | Tier 1–4 (color-coded) |
| `ModelTypeBadge` | Internal / Vendor / GenAI | Icon + label |
| `AlertBanner` | In-page alert | CRITICAL, WARNING, INFO, SUCCESS |
| `StageProgress` | Lifecycle progress bar | 7-step; filled/active/empty states |
| `GateSubmitPanel` | Stage gate submission | Checklist + submit button |
| `ApprovalCard` | Task list approval card | With/without SLA indicator |
| `ArtifactUploader` | File upload | Drag-drop + presigned POST |
| `ArtifactList` | Artifact table | Download, replace, view actions |
| `FindingCard` | Validation finding | Severity badge + status + remediation |
| `RunTable` | MLflow experiment runs | Sortable, filterable, selectable |
| `MetricChart` | Performance metrics | Line chart; Recharts / ECharts |
| `VersionLineage` | Version tree visualization | D3 or ECharts tree layout |
| `VersionComparison` | Side-by-side version diff | Metric delta indicators |
| `MonitorSummaryCard` | Monitor type status | Status + last value + threshold |
| `PromptVersionCard` | Prompt version display | Diff view, deploy status |
| `ComplianceTable` | Model inventory table | Export, filter, sort |
| `ConfirmModal` | Destructive action confirmation | Consequence list + confirm CTA |
| `TagComplianceRow` | Resource tag status | Compliant / Non-compliant |
| `TimelineEntry` | Workflow activity log | Icon + actor + timestamp |

### 25.2 Form Patterns

```
FIELD LABEL PLACEMENT:   Always above input (never inline placeholder-only)
REQUIRED FIELDS:         Asterisk (*) after label
HELPER TEXT:             Below input, secondary text color
VALIDATION TIMING:       On blur (not on keystroke) for most fields;
                         real-time for character counts
ERROR MESSAGES:          Below input, error color, specific not generic
                         ❌ "Invalid input"
                         ✅ "Project name must be between 3 and 80 characters"
MULTI-STEP FORMS:        Step indicator at top; back/next navigation;
                         progress preserved on back navigation
DISABLED STATES:         Grayed out with tooltip explaining why disabled
```

### 25.3 Data Table Patterns

```
All data tables support:
  Column sorting (click header; toggles asc/desc/default)
  Pagination OR infinite scroll (configurable per table)
  Row-level actions (hover to reveal or always visible for primary action)
  Bulk selection (checkbox column) where bulk actions exist
  CSV export of current view
  Column visibility toggle (hide/show columns)
  Sticky header on scroll
  Empty state with context-appropriate message
  Loading skeleton (not spinner) while fetching
```

---

*End of UI/UX Specification*  
*MLM Platform — UX v1.0*
