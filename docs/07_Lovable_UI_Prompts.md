# Lovable.dev Prompt Templates
## Model Lifecycle Management (MLM) Platform

**Usage Guide:**
- Run prompts in sequence — each builds on the previous
- Start with Prompt 00 (Design System) before anything else
- Copy each prompt block verbatim into Lovable
- After each generation, review and refine before moving to the next
- Mark prompts with ✅ as you complete them

---

## PROMPT 00 — Design System & Global Setup
**Run this first. Everything else depends on it.**

```
Create a React + TypeScript + Tailwind CSS dark-mode enterprise SaaS application called "MLM — Model Lifecycle Management". 

Set up the following design system as CSS variables and Tailwind config:

COLORS:
Background Primary:    #0F0F0F  (--bg-primary)
Background Secondary:  #161616  (--bg-secondary)
Background Tertiary:   #1C1C1C  (--bg-tertiary)
Background Elevated:   #242424  (--bg-elevated)
Border Subtle:         #2A2A2A  (--border-subtle)
Border Default:        #374151  (--border-default)
Text Primary:          #F9FAFB  (--text-primary)
Text Secondary:        #9CA3AF  (--text-secondary)
Text Disabled:         #4B5563  (--text-disabled)
Brand Primary:         #6366F1  (--brand-primary)
Brand Secondary:       #8B5CF6  (--brand-secondary)

STATUS COLORS (background / text / border):
NOT_STARTED:   bg #1C1C1C / text #6B7280 / border #374151
IN_PROGRESS:   bg #1E3A5F / text #60A5FA / border #2563EB
PENDING_REVIEW: bg #2D2A1E / text #FBBF24 / border #D97706
APPROVED:      bg #1A2E1A / text #34D399 / border #059669
REJECTED:      bg #2D1E1E / text #F87171 / border #DC2626
ON_HOLD:       bg #2A2A2A / text #9CA3AF / border #6B7280
ROLLED_BACK:   bg #2D1E2D / text #C084FC / border #9333EA
COMPLETED:     bg #1A2E2A / text #6EE7B7 / border #047857

RISK TIER COLORS:
Tier 1: #DC2626 (Red)
Tier 2: #EA580C (Orange)
Tier 3: #CA8A04 (Amber)
Tier 4: #16A34A (Green)

ALERT SEVERITY:
CRITICAL: #DC2626
WARNING:  #D97706
INFO:     #2563EB
SUCCESS:  #059669

TYPOGRAPHY:
Font: Inter (import from Google Fonts)
Mono font: JetBrains Mono (for IDs, hashes, code)
Scale: display 32px/700, h1 24px/600, h2 18px/600, h3 14px/600, body 14px/400, caption 12px/400

SPACING: Base 4px unit (xs:4, sm:8, md:12, lg:16, xl:24, 2xl:32, 3xl:48)

Set dark mode as default (class strategy). All backgrounds use the dark palette above. No light mode needed for v1.

Create a global App layout with:
- Left sidebar (240px expanded, 56px collapsed) with toggle button
- Top bar with breadcrumb area and action slot
- Main content area (fluid, max-width 1440px, padding 32px horizontal 24px vertical)
- 12-column grid within content

The app should feel like Linear meets Datadog — information-dense, professional, no consumer-app aesthetics.
```

---

## PROMPT 01 — Sidebar Navigation
**Depends on: Prompt 00**

```
Build the MLM sidebar navigation component with these exact specifications:

STRUCTURE (top to bottom):
1. Logo area: "MLM" text logo in brand primary (#6366F1) + collapse toggle button [≡] + theme icon [☀]
2. Primary navigation items (with icons):
   - Home (house icon) — no badge
   - Dashboard (grid icon) — no badge  
   - Model Registry (list icon) — no badge
   - My Tasks (checkmark icon) — with red badge showing count "3"
3. Divider
4. "QUICK ACCESS" section label (caption size, text-secondary, uppercase)
   - 3 recent project items with dot indicator and truncated names
   - "Pin a project" link in brand primary
5. Divider
6. Utility navigation:
   - Compliance Center (clipboard icon)
   - Integration Health (lightning icon) — with orange warning badge "!"
   - Admin Console (gear icon)
7. Bottom: User profile area
   - Avatar circle with initials "BP"
   - Name "Bhavik Patel" (body text)
   - Role "ML Engineer" (caption, text-secondary)

BEHAVIOR:
- Active item: left border 2px brand-primary, background bg-tertiary
- Hover: background bg-tertiary
- Collapsed state (56px): show icons only with tooltips on hover
- Badge on My Tasks: red circle, white text, positioned top-right of icon
- Warning badge on Integration Health: orange dot

STYLING:
- Background: bg-secondary (#161616)
- Border right: border-subtle (#2A2A2A)
- Section labels: caption size, text-secondary, uppercase, letter-spacing wide
- Navigation items: 14px, text-primary, rounded-md padding lg

Make the sidebar component fully responsive — collapses to icon rail at 768px viewport.
```

---

## PROMPT 02 — StatusBadge & RiskTierBadge Components
**Depends on: Prompt 00**
**Build these early — used everywhere**

```
Create two reusable badge components for the MLM platform:

COMPONENT 1: StatusBadge
Props: status (string), size?: 'sm' | 'md' (default md)

Render a pill badge with rounded-full, using these exact color mappings:
- NOT_STARTED:    bg #1C1C1C, text #6B7280, border 1px #374151, label "Not Started"
- IN_PROGRESS:    bg #1E3A5F, text #60A5FA, border 1px #2563EB, label "In Progress"  
- PENDING_REVIEW: bg #2D2A1E, text #FBBF24, border 1px #D97706, label "Pending Review"
- APPROVED:       bg #1A2E1A, text #34D399, border 1px #059669, label "Approved"
- REJECTED:       bg #2D1E1E, text #F87171, border 1px #DC2626, label "Rejected"
- ON_HOLD:        bg #2A2A2A, text #9CA3AF, border 1px #6B7280, label "On Hold"
- ROLLED_BACK:    bg #2D1E2D, text #C084FC, border 1px #9333EA, label "Rolled Back"
- COMPLETED:      bg #1A2E2A, text #6EE7B7, border 1px #047857, label "Completed"
- ACTIVE:         bg #1A2E1A, text #34D399, border 1px #059669, label "Active"
- SUPERSEDED:     bg #242424, text #6B7280, border 1px #374151, label "Superseded"
- RETIRED:        bg #1C1C1C, text #4B5563, border 1px #374151, label "Retired"

Size sm: text 11px, padding 2px 6px
Size md: text 12px, padding 3px 8px

COMPONENT 2: RiskTierBadge
Props: tier (1 | 2 | 3 | 4), showLabel?: boolean (default true)

Render a pill badge with:
- Tier 1: bg rgba(220,38,38,0.15), text #DC2626, border 1px #DC2626, label "● Tier 1"
- Tier 2: bg rgba(234,88,12,0.15), text #EA580C, border 1px #EA580C, label "● Tier 2"
- Tier 3: bg rgba(202,138,4,0.15), text #CA8A04, border 1px #CA8A04, label "● Tier 3"
- Tier 4: bg rgba(22,163,74,0.15), text #16A34A, border 1px #16A34A, label "● Tier 4"

The dot "●" before tier number should be filled circle in the tier color.

COMPONENT 3: ModelTypeBadge
Props: type ('INTERNAL' | 'VENDOR' | 'GENAI')

- INTERNAL: bg #1E3A5F, text #60A5FA, icon: cpu, label "Internal"
- VENDOR:   bg #2D2A1E, text #FBBF24, icon: building, label "Vendor"
- GENAI:    bg #2D1E2D, text #C084FC, icon: sparkles, label "GenAI / LLM"

Show all three badges in a demo grid so I can verify the full set.
```

---

## PROMPT 03 — Model Project Card
**Depends on: Prompts 00, 02**

```
Build a ModelProjectCard component for the MLM model registry list. 

PROPS:
- modelId: string (e.g., "MOD-2024-00421")
- name: string
- description: string
- riskTier: 1 | 2 | 3 | 4
- modelType: 'INTERNAL' | 'VENDOR' | 'GENAI'
- currentStage: string (e.g., "Development")
- currentStatus: string (e.g., "IN_PROGRESS")
- businessDomain: string
- ownerName: string
- alertCount: number
- alertSeverity?: 'CRITICAL' | 'WARNING' | null
- lastActivity: string (e.g., "2 hours ago")
- onClick: () => void

LAYOUT:
Card: bg-tertiary (#1C1C1C), border border-subtle (#2A2A2A), rounded-lg, padding lg (16px)
Hover: border-color brand-primary (#6366F1), subtle box-shadow elevation-1

TOP ROW:
- Left: Model name (h2 size, text-primary, font-semibold, truncate)
- Right: RiskTierBadge + ModelTypeBadge side by side

SECOND ROW:
- modelId in JetBrains Mono, caption size, text-secondary
- " · " separator
- businessDomain in caption, text-secondary

THIRD ROW (stage + status):
- Stage label: "Stage: {currentStage}" in body-small, text-secondary
- StatusBadge with currentStatus
- If alertCount > 0: alert badge — red circle for CRITICAL, amber for WARNING
  showing count (e.g., "🔴 2" or "⚠ 1")

BOTTOM ROW:
- Left: "Owner: {ownerName}" caption, text-secondary
- Right: "Last activity: {lastActivity}" caption, text-secondary

Show a demo grid with 4 sample cards covering different tiers, stages, and alert states.
```

---

## PROMPT 04 — Portfolio Dashboard
**Depends on: Prompts 00, 02, 03**

```
Build the MLM Portfolio Dashboard page.

PAGE HEADER:
Title "Portfolio Dashboard" (h1), right-aligned: Filter dropdown (default "All Domains") + Export button (outline style)

METRIC CARDS ROW (5 cards, equal width):
Each card: bg-tertiary, border border-subtle, rounded-lg, padding lg
- Card 1: large number "47", label "Total Models", no color accent
- Card 2: large number "12", label "Active Production", no color accent  
- Card 3: large number "8", label "Validation In Progress", no color accent
- Card 4: large number "3", label "Critical Alerts", number in #DC2626
- Card 5: large number "4", label "Retiring", number in #D97706

TWO-COLUMN SECTION (below metric cards, gap xl):

LEFT COLUMN: "MODELS BY STAGE" 
Section label: caption, text-secondary, uppercase
Horizontal bar chart — each row:
  Stage name (body-small, text-secondary, fixed 120px width)
  Bar (bg brand-primary #6366F1, rounded, height 8px, animated fill)
  Count number (body-small, text-primary, ml-sm)
Stages: Inception(6), Development(14), Validation(9), Implementation(7), Monitoring(12), Retirement(3)

RIGHT COLUMN: "MODELS BY RISK TIER"
Horizontal stacked bar showing tier distribution:
Tier 1: #DC2626  7 models
Tier 2: #EA580C  18 models  
Tier 3: #CA8A04  12 models
Tier 4: #16A34A  10 models
Below bar: legend with colored dots + labels + counts

MODEL TABLE (full width below charts):
Header: "ALL MODELS" section label + search input + Filter button
Columns: Name | Type | Stage | Status | Tier | Alerts | (action)
Use shadcn/ui Table component.
Row data (6 sample rows mixing all types):
- Fraud Scorer v2 | Internal | Validation | PENDING_REVIEW | Tier 1 | ⚠ 1
- Credit Default Pred | Internal | Development | IN_PROGRESS | Tier 2 | —
- Churn Predictor v3 | Internal | Monitoring | ACTIVE | Tier 2 | 🔴 1
- Mortgage Risk Score | Internal | Monitoring | ACTIVE | Tier 1 | —
- Tableau Einstein | Vendor | Active | UNDER_REVIEW | Tier 3 | —
- GPT-4 Claims Assist | GenAI | Monitoring | ACTIVE | Tier 1 | ⚠ 2

Each row: hover background bg-tertiary. Name is clickable link (brand primary).
Status column uses StatusBadge component. Tier column uses RiskTierBadge.
Alert column: red badge for CRITICAL count, amber for WARNING, dash for none.
```

---

## PROMPT 05 — Role-Adaptive Home Screens
**Depends on: Prompts 00, 02, 03**

```
Build 4 role-adaptive home screen variants for MLM. 
Use a tab switcher at the top (for demo purposes only — in production this is role-driven) 
to toggle between: [Data Scientist] [Risk Officer] [Model Owner] [Auditor]

HOME 1 — DATA SCIENTIST:
Greeting: "Good morning, Bhavik" (h1) + date right-aligned (text-secondary)

"MY ACTIVE PROJECTS" section + "View All" link:
Two project cards side by side (use ModelProjectCard variant — compact):
Card 1: Credit Default Predictor, Tier 2, Development IN_PROGRESS
  Sub-details: "Candidate: run-abc123", "MLflow: 14 runs synced", "Last activity: 2 hrs ago"
  Action button: "Open Development Stage" (brand-primary outline)
Card 2: Fraud Scorer v2, Tier 1, Validation PENDING_REVIEW  
  Sub-details: "3 findings open", "2 critical ⚠"
  Action button: "View Findings" (warning outline)

"RECENT ACTIVITY" section:
Timeline list, 4 items with colored left-dot indicators:
  Blue dot · MLflow run synced · Credit Default Predictor · 2m ago
  Green dot · Development gate approved · Fraud Scorer v2 · 1h ago  
  Red dot · Critical finding raised · Fraud Scorer v2 · 3h ago
  Blue dot · Candidate selected · Credit Default · Yesterday

"ENVIRONMENT STATUS" section:
Card showing: AWS Account 987654321098 · us-east-1 · ✅ Tagged
SageMaker Project: p-abc123 · MPG: credit-default-pred-mpg

HOME 2 — RISK OFFICER:
Greeting + date

4 metric cards: "3 Pending Approvals" | "2 SLA at Risk" | "1 Emergency Alert" | "7 Tier 1 Models Active"

"REQUIRES MY APPROVAL" section:
3 approval cards stacked, each with:
  - Red/amber SLA indicator bar at top
  - Model name + tier badge
  - Submitter info
  - Summary bullet points
  - [Review & Approve] + [Review & Reject] buttons

"CRITICAL ALERTS" section:
One red alert row for data drift

"TIER 1 MODEL HEALTH" summary line with [Full Report] link

HOME 3 — MODEL OWNER:
Greeting + date

"MY PORTFOLIO (6 models)" section:
Table layout: Model | Stage | Status | Alerts | Action
6 rows with dividers. Alert column shows red/amber badges. Action = [Open] button.

"PENDING MY APPROVAL" section:
One inline approval row: "Production Promotion — Fraud Scorer v2" + [Approve] [Reject] buttons inline

HOME 4 — AUDITOR:
Greeting: "Compliance Overview"

4 metric cards: "47 Total Models" | "43 Validated" | "4 Validation Overdue" | "95.3% Tag Compliance"

"TIER 1 MODELS — COMPLIANCE STATUS" table:
Columns: Model | Validated | Last Review | Next Review | Status
3 rows with status icons (✅, ⚠ Due, 🔴 Act)

"QUICK ACTIONS" section:
4 outline buttons: Export Model Inventory | Generate SR 11-7 Package | View Global Audit Log | Export Compliance Report
```

---

## PROMPT 06 — Project Header & Tab Navigation
**Depends on: Prompts 00, 02**

```
Build the MLM Model Project Header component — this appears at the top of every project page.

HEADER STRUCTURE:
Background: bg-secondary (#161616), border-bottom border-subtle
Padding: xl (24px) horizontal, md (12px) vertical

ROW 1:
Left side:
  - Project name "Credit Default Predictor" (h1, text-primary, font-semibold)
  - [⭐ Pin] button (ghost, small, icon + label)
  - [···] more options button (ghost, icon only) — opens dropdown: Export Project, Archive, Initiate Retirement

Right side:
  - [+ New Version] button (outline, brand-primary)

ROW 2 (metadata bar):
Display inline with · separators, caption size, text-secondary:
  "MOD-2024-00421"  (JetBrains Mono)
  RiskTierBadge tier=2
  ModelTypeBadge type="INTERNAL"
  "Credit Risk"
  "Owner: Jane Smith"
  "AWS: 987654321098 / us-east-1"
  "MPG: credit-default-pred-mpg"

TAB BAR (below header, full width):
Sticky to top when scrolling. Tabs:
[Overview] [Lifecycle] [Inception ✅] [Development ●] [Validation] [Implementation] [Monitoring] [Versions] [Registry] [Audit] [Settings]

Tab styling:
  - Active tab: text brand-primary, border-bottom 2px brand-primary
  - Completed stage tab: show small ✅ icon after label
  - Active/current stage tab: show small ● dot in blue (#60A5FA)
  - Not-started tabs: text text-secondary
  - Hover: text text-primary

Breadcrumb above header: "Registry › Credit Default Predictor › Development" (caption, text-secondary, with › separators, each segment clickable)
```

---

## PROMPT 07 — Lifecycle Map
**Depends on: Prompts 00, 02, 06**
**This is the hero feature — spend iteration time here**

```
Build the MLM Lifecycle Map component. This is the most important visual in the product.

STAGE PROGRESS TRACKER (top section):
7 stages displayed horizontally connected by a track line:
1. Inception    2. Development    3. Validation    4. Implementation    5. Monitoring    6. Versions    7. Retirement

For each stage node:
  COMPLETED stage: filled green circle (✅ icon inside), green connector line to next
  CURRENT stage: filled blue circle (pulsing animation), blue label below, status badge
  FUTURE stage: empty circle (border only, text-secondary), grayed connector, grayed label

Sample state: Inception=COMPLETED, Development=IN_PROGRESS, rest=NOT_STARTED

Below each node:
  Stage name (body-small, text-secondary)
  Status text (caption, status color)
  Date if completed/started (caption, text-disabled)

Track line: 2px line connecting all nodes. Filled (brand-primary) for completed segments. Dashed (#374151) for future segments.

CURRENT STAGE DETAIL CARD (below tracker):
bg-tertiary, border border-default, rounded-lg, padding xl

Header row: "Stage 2: Development" (h2) + StatusBadge IN_PROGRESS right-aligned
Sub-header: "Started: November 12, 2024 · Active since: 3 days" (caption, text-secondary)

Progress bar: 
Label "Completion" + percentage "65%" right-aligned
Bar: full-width, height 8px, bg border-subtle, filled portion bg brand-primary, rounded
Animate fill on mount.

CHECKLIST (below progress bar):
Two-column grid of checklist items:
✅ Development Plan uploaded           (green check, text-primary)
✅ Code repository linked              (green check, text-primary)
✅ MLflow integration active (14 runs synced)   (green check)
✅ Candidate model selected run-abc123  (green check)
✅ Training data snapshot SHA: a3f2...  (green check)
⏳ Model card (draft) Not uploaded      (amber clock, text-secondary)
⏳ Bias & fairness assessment Not uploaded (required: Tier 2)  (amber clock, text-secondary)

GATE STATUS BAR (bottom of card):
"Gate Status: NOT SUBMITTED · 2 items outstanding"
[Submit for Gate Review] button — DISABLED state with tooltip "Complete all required items to enable"
Disabled: bg #2A2A2A, text #4B5563, cursor not-allowed
Tooltip on hover: "Outstanding: Model card, Bias & fairness assessment"

WORKFLOW HISTORY (below detail card):
Section label "WORKFLOW HISTORY" (caption, uppercase, text-secondary)
Timeline list:
  ✅ Nov 10 · Inception Approved · Jane Smith (Model Owner)
  ● Nov 10 · Development Started · System
  ● Nov 12 · MLflow integration configured · Bhavik Patel
  ● Nov 14 · Candidate selected: run-abc123 · Bhavik Patel

Each entry: colored dot left, date+action+actor inline, caption size
```

---

## PROMPT 08 — Inception Stage Panel
**Depends on: Prompts 00, 02, 06**

```
Build the MLM Inception Stage Panel.

STAGE HEADER:
"Stage 1: Inception" (h2) + StatusBadge "IN_PROGRESS" right-aligned
"Started: Nov 10, 2024 · Owner: Jane Smith · Tier 2" (caption, text-secondary below)

REQUIRED ARTIFACTS section:
Section label + "Completion: 5/7" counter right-aligned (brand-primary)

Artifact list table (no outer border — internal dividers only):
Columns: Status icon | Artifact name | File name (if uploaded) | Date | Actions

Rows:
✅ Project Charter           charter-v1.pdf         Nov 10  [Download] [Replace]
✅ Use Case Description      use-case.docx          Nov 10  [Download] [Replace]
✅ Data Availability Report  data-avail.pdf         Nov 11  [Download] [Replace]
✅ Risk Classification       "Tier 2 — auto-generated"  Nov 10  [View]
✅ Stakeholder Registry      stakeholders.xlsx      Nov 11  [Download] [Replace]
⏳ Regulatory Scope Document  —                     —       [Upload]
⏳ Feasibility Assessment     —                     —       [Upload]

✅ rows: green check icon, text-primary
⏳ rows: amber clock icon, text-secondary, italic filename placeholder

[Upload] buttons: outline small, brand-primary

UPLOAD DROPZONE (appears when clicking Upload):
Dashed border (#374151), rounded-lg, padding 2xl, center-aligned
Drag & drop icon (upload cloud)
"Drop files here or click to upload"
"Supported: PDF, DOCX, XLSX, IPYNB, MD · Max 500MB"
bg-tertiary on drag-over

COMMENTS & ACTIVITY section:
Section label + [+ Add Comment] button (ghost, right-aligned)
2 comment entries:
  Avatar "JS" + "Jane Smith" (body, text-primary) + "Nov 11" (caption, text-secondary)
  Comment text: "Data availability confirmed with DBA team."
  
  Avatar circle "SY" (system) + "System" + "Nov 10"
  "Project created. Provisioning request sent to ServiceNow (RITM0042891)."

Comment input area (shown when + Add Comment clicked):
Textarea, [Cancel] [Post Comment] buttons

GATE REVIEW section (bottom, bg-elevated border-t):
"Required approvers: Jane Smith (Model Owner) + Sarah Lee (Risk Officer)" (body-small, text-secondary)
[Submit for Gate Review] button — disabled, amber warning text below:
"⚠ Outstanding: Regulatory Scope Document, Feasibility Assessment"
```

---

## PROMPT 09 — Development Stage: Experiment Table
**Depends on: Prompts 00, 02, 06**

```
Build the MLM Development Stage Panel — Experiments tab.

TWO-COLUMN LAYOUT:
Left sidebar (200px): vertical tab list
Right content (fluid): tab content

LEFT TAB LIST (vertical):
[Experiments] — active, with blue left border
[Artifacts]
[Candidate ✓] — green checkmark indicating candidate selected
[Gate]

Each tab: body text, rounded-md, hover bg-tertiary, active: bg-tertiary + left border brand-primary

RIGHT CONTENT — EXPERIMENTS TAB:

INTEGRATION STATUS BAR:
"MLflow Experiments" label (h3) inline with:
Platform badge: "SageMaker Experiments (MLflow)" (caption, bg-tertiary, rounded)
"✅ Connected" (green, caption)
"Last sync: 2 minutes ago · 14 runs" (caption, text-secondary)
[↻ Refresh] icon button (ghost, right-aligned)

FILTERS ROW:
Search input (placeholder "Search runs...") | [Filter ▼] dropdown | [Sort: Latest ▼] dropdown

RUNS TABLE (shadcn/ui Table):
Columns: (blank/star) | Run Name | AUC | F1 Score | Created | Duration | Status | Actions

Rows (7 sample runs):
★ run-abc123  | 0.923 | 0.891 | Nov 14 | 2h 14m | ✅ | [Select as Candidate] — this is the CANDIDATE row
  run-def456  | 0.915 | 0.882 | Nov 13 | 1h 58m | ✅ | [Select as Candidate]
  run-ghi789  | 0.901 | 0.870 | Nov 13 | 2h 02m | ✅ | [Select as Candidate]
  run-jkl012  | 0.887 | 0.851 | Nov 12 | 1h 45m | ✅ | [Select as Candidate]
  run-mno345  | 0.843 | 0.810 | Nov 12 | 1h 12m | Failed | [Select as Candidate]
  run-pqr678  | —     | —     | Nov 12 | 0h 23m | Running | —
  run-stu901  | 0.831 | 0.798 | Nov 11 | 1h 38m | ✅ | [Select as Candidate]

CANDIDATE ROW STYLING:
- Gold star ★ filled icon in first column
- Background: rgba(99,102,241,0.08) (subtle brand highlight)
- Border-left 2px brand-primary
- Bold run name
- Small badge below run name: "CANDIDATE" in brand-primary pill

Status column:
✅ = green checkmark badge
Failed = red "Failed" badge  
Running = blue animated "Running" badge with spinner

Metric columns: right-aligned monospace
AUC > 0.90: text-primary
AUC 0.85-0.90: text-secondary
AUC < 0.85: text-disabled

Bottom: "Load 7 more runs..." link (brand-primary) + "[View in SageMaker Studio ↗]" external link (text-secondary, opens new tab)

EMPTY STATE (for when MLflow is disconnected):
Centered illustration area, "MLflow integration not configured"
"Connect your MLflow tracking server to see experiments here."
[Configure Integration] button (brand-primary)
```

---

## PROMPT 10 — Candidate Model Detail
**Depends on: Prompts 00, 09**

```
Build the MLM Candidate Model Detail panel shown in the Development Stage → Candidate tab.

CANDIDATE HEADER:
"CANDIDATE MODEL" label (caption, uppercase, text-secondary)
Right-aligned: "★ SELECTED" badge (gold/amber bg, gold text)
Run ID: "run-abc123" in JetBrains Mono (h2, text-primary)
"Registered: Nov 14, 2024 · By: Bhavik Patel" (caption, text-secondary)
[Change Candidate] button (ghost, small, amber text) + [View in SageMaker Studio ↗] (ghost, external link icon)

TWO-COLUMN GRID:

LEFT: PERFORMANCE METRICS
Section label (caption, uppercase, text-secondary)
Metric rows:
  AUC:        0.923  (large, brand-primary, monospace)
  F1 Score:   0.891
  Precision:  0.887
  Recall:     0.895
  Log Loss:   0.214  (lower = better, add "↓ better" hint in caption)
Each row: metric name (body-small, text-secondary) + value (body, text-primary, monospace, right-aligned)

RIGHT: PARAMETERS  
learning_rate:   0.01
max_depth:       6
n_estimators:    500
subsample:       0.8
Same row styling as metrics.

TRAINING METRICS CHART (full width below):
Section label "TRAINING METRICS OVER EPOCHS"
Line chart using Recharts (LineChart):
- X axis: epochs 0 to 500
- Two lines: AUC (train) in brand-primary #6366F1, AUC (validation) in dashed #8B5CF6
- Y axis: 0.5 to 1.0
- Chart background: bg-tertiary
- Grid lines: border-subtle (#2A2A2A)
- Tooltip: bg-elevated, dark styled
- Legend below chart: colored dots + labels
- Use synthetic data that shows training curve converging around epoch 300, 
  validation slightly below train (realistic overfitting pattern)
Caption below: "(Rendered from MLM-stored snapshot — independent of MLflow availability)" (caption, text-disabled, italic)

ARTIFACT REFERENCES section:
Two rows with copy button:
  Model artifact:  s3://mlm-dev-credit.../model.tar.gz  [📋 Copy URI]
  Training data:   s3://mlm-dev-credit.../train-2024... [📋 Copy URI]
  Data hash (SHA): "a3f2c8d9e5f1..."  ✅ Verified  (green verified badge)
All URIs in JetBrains Mono, truncated with ellipsis.

MODEL SIGNATURE section:
"Inputs:" label + scrollable tag list: [feature_1: float] [feature_2: float] [feature_3: int] ... [+12 more] (clickable to expand)
"Outputs:" label + tags: [probability: float] [label: int]
Tags: rounded pill, bg-tertiary, border border-subtle, body-small
```

---

## PROMPT 11 — Validation Workbench
**Depends on: Prompts 00, 02, 06**

```
Build the MLM Validation Stage Panel — Validation Workbench.

STAGE HEADER:
"Stage 3: Validation" + StatusBadge "PENDING_REVIEW" right-aligned
"Validators: John Doe (Lead), Lisa Park · Tier 2 Test Plan" (caption, text-secondary)

HORIZONTAL TABS:
[Test Plan] [Findings (3)] [Evidence] [Report] [Gate]
Active: Test Plan

TEST PLAN TAB:
Section header: "TEST PLAN" label + "Completion: 6/9 (67%)" right-aligned in amber (#FBBF24)
Progress bar: 67% filled, amber color

Test cases table:
Columns: Category | Status | Result | Evidence | Action

Rows (9 test cases):
Conceptual Soundness Review    ✅ Done    PASS          [2 files]    [View]
Performance Testing            ✅ Done    PASS          [1 file]     [View]
Stability Testing              ✅ Done    PASS          [3 files]    [View]
Sensitivity Analysis           ✅ Done    PASS          [1 file]     [View]
Bias & Fairness Testing        ✅ Done    COND. PASS    [2 files]    [View]
Explainability Testing         ✅ Done    PASS          [1 file]     [View]
Data Quality Validation        ⏳ In Progress  —         —           [Record Result]
Regulatory Compliance Check    ○ Not Started  —          —           [Record Result]
Replication Test               ○ Not Started  —          —           [Record Result]

Status column:
✅ Done: green check badge
⏳ In Progress: blue spinner badge
○ Not Started: gray circle badge

Result column:
PASS: green "PASS" badge (bg #1A2E1A, text #34D399)
COND. PASS: amber "Cond. Pass" badge (bg #2D2A1E, text #FBBF24)
FAIL: red badge
— : dash, text-disabled

[Record Result] button: outline small, brand-primary
[View] button: ghost small, text-secondary

RECORD TEST RESULT MODAL (shown when clicking Record Result):
Modal title: "Record Test Result: Data Quality Validation"
Radio group "Result":
  ○ PASS — All criteria met without conditions
  ● CONDITIONAL PASS — Criteria met with documented conditions  
  ○ FAIL — Criteria not met; finding raised
  
Conditions textarea (visible when Conditional Pass selected):
Label "Conditions (required for Conditional Pass) *"
Placeholder: "Describe the conditions..."

File upload area: dashed border, "Attach Evidence (required)", drag-drop
Uploaded files shown as chips with file icon + name + size + ✅

"Raise Finding?" radio:
  ○ No finding
  ● Yes — raise finding alongside result

Finding fields (when Yes selected):
  Title input: [Disparate impact ratio requires remediation plan]
  Severity dropdown: [● Major ▼] options: Critical/Major/Minor/Informational

Footer: [Cancel] (ghost) + [Save Test Result] (brand-primary filled)
```

---

## PROMPT 12 — Findings Tracker
**Depends on: Prompts 00, 11**

```
Build the MLM Findings Tracker — shown in Validation Stage → Findings tab.

FINDINGS HEADER:
"FINDINGS" section label + "[+ Raise Finding]" button (outline, brand-primary) + "[Export CSV]" button (ghost)
Summary line: "3 total · 0 Critical · 2 Major · 1 Minor" 
Color-coded counts: Critical in #DC2626, Major in #D97706, Minor in #CA8A04

FINDINGS LIST (stacked cards with dividers):

FINDING CARD 1 (Major, In Remediation):
Top: severity badge "● MAJOR" (amber) + finding ID "F-042" (JetBrains Mono, text-secondary) + status badge "IN_REMEDIATION" (blue)
Title: "Disparate impact ratio requires remediation plan" (body, text-primary, semi-bold)
Meta row: "Raised by: John Doe · Nov 14 · Status: IN_REMEDIATION" (caption, text-secondary)
Remediation text: "Bias monitoring configured; plan submitted Nov 15" (body-small, text-secondary, italic, left border 2px #059669)
Actions: [View Details] (ghost) + [Mark Resolved] (outline, green)

FINDING CARD 2 (Major, Open — no remediation):
Top: "● MAJOR" badge + "F-043" + "OPEN" status in red
Title: "Training data vintage mismatch in Q3 sample"
Meta: "Raised by: Lisa Park · Nov 13"
Warning callout (amber bg, amber border): 
"⚠ No remediation plan attached. Required before gate approval can proceed."
Actions: [View Details] + [Add Remediation Plan] (outline, amber)

FINDING CARD 3 (Minor, Open):
Top: "● MINOR" badge (caption size, lighter) + "F-044" + "OPEN"
Title: "Model card missing inference latency benchmarks"
Meta: "Raised by: John Doe · Nov 14"
Actions: [View Details] + [Add Remediation Plan]

SEVERITY BADGES styling:
CRITICAL: bg rgba(220,38,38,0.15), text #DC2626, border #DC2626
MAJOR: bg rgba(217,119,6,0.15), text #D97706, border #D97706  
MINOR: bg rgba(202,138,4,0.15), text #CA8A04, border #CA8A04
INFORMATIONAL: bg rgba(37,99,235,0.15), text #60A5FA, border #2563EB

EMPTY STATE (when no findings):
Centered green checkmark icon
"No findings raised"
"All validation tests passed without issues."
```

---

## PROMPT 13 — My Tasks / Approval Center
**Depends on: Prompts 00, 02**

```
Build the MLM My Tasks page — the primary view for Risk Officers and approvers.

PAGE HEADER:
"My Tasks" (h1, text-primary)
Horizontal tab bar: [Pending Approvals (3)] [Open Findings (2)] [Incidents (1)] [Overdue (1)]
Active tab: Pending Approvals — badge counts in colored pills

PENDING APPROVALS TAB:
Sort control: "Sorted: SLA ↑" (caption, text-secondary, right-aligned, clickable)

APPROVAL CARD 1 (Critical SLA):
Red top border 3px + "🔴 SLA: 4 hours remaining" banner (red bg rgba(220,38,38,0.1), red text, full width of card, rounded-t-lg, padding sm)
Card body (bg-tertiary, border border-default, rounded-b-lg, padding xl):
  Header row: "Validation Gate" pill (caption, bg brand-primary text, rounded) + "— Fraud Scorer v2" (h2, text-primary) + RiskTierBadge tier=1 right
  Meta: "MOD-2024-00387 · Submitted by: John Doe (Lead Validator)" (caption, text-secondary)
  "Nov 15, 2024 09:00" (caption, text-disabled)
  
  Divider
  
  "Summary:" label (body-small, semi-bold)
  Bullet list (body-small):
    • 9/9 test cases completed · 0 Critical · 1 Major finding
    • Major finding: F-042 — Bias remediation plan attached
    • Validation report: validation-summary-v2.pdf
  
  Links row: [📄 View Validation Report] (ghost, text-secondary) + [📋 View Full Stage] (ghost, text-secondary)
  
  Divider
  
  Comment area:
  "Decision Comment (optional)" label (caption, text-secondary)
  Textarea (2 rows, bg-elevated, border border-default, placeholder "Add context for your decision...")
  
  Decision buttons row (right-aligned, gap md):
  [✅ Approve] — bg #1A2E1A, text #34D399, border #059669, hover brighten
  [⚠ Conditional] — bg #2D2A1E, text #FBBF24, border #D97706
  [❌ Reject] — bg #2D1E1E, text #F87171, border #DC2626

APPROVAL CARD 2 (Warning SLA):
Amber top border 3px + "⚠ SLA: 8 hours remaining" amber banner
Card (compressed — less detail, collapsed by default):
"Inception Gate — AML Transaction Monitor · Tier 1 · Mark Chen"
[📄 View Documents] (ghost) + [✅ Approve] (outline green) + [❌ Reject] (outline red)
[Expand for details ▼] toggle link

APPROVAL CARD 3 (No SLA pressure):
No SLA banner. Gray left border.
"Risk Override Request — Credit Limit Model · Tier 2"
"ML Engineer requested deployment block override for staging"
[Review Override Request] (outline amber, full width)

CONFIRMATION MODAL (when Approve clicked):
Modal overlay (bg-primary/80 backdrop-blur)
Modal card: bg-elevated, rounded-xl, border border-default, max-w-md, padding 2xl

Title: "Confirm: Approve Validation Gate" (h2)
Subtext: "You are approving the Validation Gate for:"
Model detail box (bg-tertiary, rounded, padding md):
  "Fraud Scorer v2 · v2.0.0 · MOD-2024-00387"

"What happens next:" label (body-small, semi-bold, text-secondary)
List with ✅ icons:
  ✅ Model version v2.0.0 will be tagged VALIDATED
  ✅ Deployment eligibility granted for staging
  ✅ Stage 4 (Implementation) will be activated
  ✅ Model Owner and ML Engineer will be notified
  ✅ Recorded in the immutable audit log

Comment preview (if comment entered): italic, text-secondary, quoted

Warning notice (amber bg, amber border, rounded, padding md):
"⚠ This action cannot be undone. Your identity (Sarah Lee) and timestamp will be permanently recorded."

Footer: [Cancel] (ghost) + [Confirm Approval ✅] (filled green)
```

---

## PROMPT 14 — Implementation Stage
**Depends on: Prompts 00, 02, 06**

```
Build the MLM Implementation Stage Panel.

STAGE HEADER:
"Stage 4: Implementation" + StatusBadge "IN_PROGRESS"
"Version: v1.2.0 · Platform: SageMaker Endpoint · Started: Nov 15" (caption, text-secondary)

HORIZONTAL TABS: [Deployment Plan] [Staging] [Production] [Deployments]
Active: Production tab

DEPLOYMENT CONFIGURATION card (bg-tertiary, border, rounded-lg):
Header: "DEPLOYMENT CONFIGURATION" + "Platform: SageMaker Endpoint" badge (right)
Grid 2x2:
  Instance Type:    ml.m5.xlarge (4 vCPU, 16GB)
  Initial Count:    2 instances (auto-scale: 2–10)
  Strategy:         Blue / Green
  Data Capture:     Enabled (10% sample → S3)
Endpoint Name: "credit-default-pred-v120-prod" (JetBrains Mono, text-secondary)
[Edit Configuration] button (ghost, small, right-aligned)

DEPLOYMENT PIPELINE section:
"DEPLOYMENT PIPELINE" section label
Vertical step list:
  ✅ Staging deployment      Completed Nov 15 10:30    [View Logs ↗]
  ✅ Smoke tests             PASSED (12/12)            [View Results]
  ✅ Integration tests       PASSED (45/45)            [View Results]
  ⏳ Production Promotion Gate  PENDING APPROVAL       —

Step styling:
  Completed: green filled circle + green connector line down + text-primary
  Active/Pending: amber pulsing circle + text-primary
  Future: gray circle + text-secondary

DEPLOYMENT ELIGIBILITY CHECK card:
bg: rgba(26,46,26,0.5), border #059669, rounded-lg, padding lg
"DEPLOYMENT ELIGIBILITY CHECK" label (caption, uppercase, text-secondary)
Row: "Model: MOD-2024-00421 · v1.2.0 · production"
Status: large "✅ ELIGIBLE" (text #34D399, h3)
"Validation date: Nov 15, 2024 · Expiry: Nov 15, 2025" (caption, text-secondary)

PRODUCTION PROMOTION GATE card:
bg-elevated, border border-default, rounded-lg, padding xl
"PRODUCTION PROMOTION GATE" header
"Requires approval from:" (body-small, text-secondary)
Two approver rows:
  ✅ Tom Richards (ML Engineer) — "Approved Nov 15 11:00" — green check
  ⏳ Jane Smith (Model Owner)  — "Pending" — amber clock
  
"1 of 2 approvals received" progress: half-filled bar, amber
[Send Reminder to Jane Smith] button (outline, amber, full width)
Note: "Gate will auto-advance when all approvals are received." (caption, text-secondary, italic)
```

---

## PROMPT 15 — Monitoring Dashboard
**Depends on: Prompts 00, 02, 06**

```
Build the MLM Monitoring Stage Panel.

STAGE HEADER:
"Stage 5: Monitoring" + "ACTIVE" green badge right
"Deployed: Nov 16, 2024 · Endpoint: credit-default-pred-v120-prod" (caption)
Time window selector right-aligned: [7d] [30d] [90d] [Custom] — 30d active
[Configure Monitors] button (outline, right)

MONITOR STATUS GRID (2x3 or 3x2 grid of monitor cards):
Each card: bg-tertiary, border, rounded-lg, padding lg

Card 1 — Data Quality:
  "Data Quality" label (body-small, semi-bold)
  Status: "✅ PASS" (green)
  "Last check: 5m ago" (caption, text-secondary)
  Metric: "Missing values: 0.1%" (body, text-primary)
  
Card 2 — Data Drift:
  "Data Drift" label
  Status: "⚠ WARNING" (amber)
  "Last check: 5m ago" (caption)
  Metric: "PSI: 0.18" (amber, body) + "(threshold: 0.15)" (caption, text-secondary)
  ← amber left border on this card to indicate warning state

Card 3 — Model Performance:
  "Model Performance" label  
  Status: "✅ PASS"
  "Last check: 1h ago"
  Metric: "AUC: 0.919 (baseline: 0.923)" + "Δ -0.004" (text-secondary)

Card 4 — Infrastructure:
  "Infrastructure" label
  Status: "✅ PASS"
  "Last check: 1m ago"
  Metrics: "Latency P95: 42ms · Error rate: 0.02%"

Card 5 — Prediction Bias:
  "Prediction Bias" label
  Status: "✅ PASS"
  "Last check: 6h ago"
  "Disparate impact: 0.91 (threshold: 0.80)"

External links row below grid:
[View in Datadog ↗] (ghost, external icon) + [View in CloudWatch ↗] (ghost, external icon) + [View in SageMaker MM ↗] (ghost)

ACTIVE ALERTS section:
"ACTIVE ALERTS" label + "[View All]" right
Single alert row (amber bg, amber border-l 3px, rounded, padding md):
"⚠ WARNING · Data drift detected · feature: age_of_account · Nov 15 · Production"
[Acknowledge] button (outline, amber, small) + [Create Incident] (ghost, small)

PERFORMANCE SUMMARY card (v1 — no live charts, link-out):
bg-tertiary, border, rounded-lg, padding lg
"PERFORMANCE TREND" label
Three inline metrics:
  "AUC at deployment: 0.923" → "Current AUC: 0.919" → "Δ -0.004 (-0.4%)" (green, within tolerance)
Muted callout box:
"Full performance dashboard available in SageMaker Model Monitor"
[Open SageMaker Model Monitor ↗] button (outline, full width)

INCIDENTS section:
"INCIDENTS" label + [+ Create Incident] button (outline, small)
Empty state: "No open incidents · ✅ All clear" (green icon, centered)

GROUND TRUTH section:
"GROUND TRUTH UPLOADS" label + [Upload Ground Truth] button (outline)
Status row: "Last upload: Nov 10 · Coverage: Oct 2024 actuals"
Result: "Realized AUC (Oct): 0.917 · ✅ Within tolerance (±0.01)" (green)
```

---

## PROMPT 16 — Version Explorer & Comparison
**Depends on: Prompts 00, 02**

```
Build two components: Version Explorer table and Version Comparison view.

COMPONENT 1: VERSION EXPLORER

Header: "Versions — Credit Default Predictor" (h1) + [+ New Version] button (brand-primary filled, right)

VERSION LINEAGE DIAGRAM:
Simple horizontal tree using CSS/SVG:
  v1.0.0 ──→ v1.1.0 ──→ v1.2.0  [DEPLOYED badge, green]
                  └──→ v2.0.0  [IN DEVELOPMENT badge, blue]

Node styling: rounded boxes, bg-tertiary, border brand-primary for deployed node
Arrow lines: #374151 color, 1px
Labels below nodes: version string in JetBrains Mono

VERSION TABLE below lineage:
"VERSION TABLE" label + [Compare Versions] button (outline, right)
Columns: Version | Status | AUC | Deployed | Validated | Action

Rows:
v2.0.0  IN_DEVELOPMENT  —      —        —          [View Dev Stage]
v1.2.0  DEPLOYED        0.923  Nov 16   Nov 15     [Active ●]
v1.1.0  SUPERSEDED      0.910  Sep 12   Sep 10     [View Details]
v1.0.0  SUPERSEDED      0.895  Jun 5    Jun 3      [View Details]

v1.2.0 row: subtle blue bg highlight (rgba(99,102,241,0.05)), "Current Production" badge inline
Status uses StatusBadge component.
Version strings in JetBrains Mono.

COMPONENT 2: VERSION COMPARISON VIEW

Header: "Version Comparison" 
Two version selectors side by side: [v1.1.0 ▼] vs [v1.2.0 ▼]

Comparison table (3 columns: Metric | v1.1.0 | v1.2.0 | Change):

Section: METRICS
AUC              | 0.910  | 0.923  | ↑ +0.013  ✅
F1 Score         | 0.872  | 0.891  | ↑ +0.019  ✅
Precision        | 0.869  | 0.887  | ↑ +0.018  ✅
Log Loss         | 0.241  | 0.214  | ↓ -0.027  ✅ (lower is better)

Section: PARAMETERS
learning_rate    | 0.01   | 0.01   | — same
max_depth        | 5      | 6      | ↑ changed (amber)
n_estimators     | 300    | 500    | ↑ changed (amber)

Section: VALIDATION
Bias & Fairness  | PASS   | COND.PASS | ⚠ changed (amber warning)
Performance      | PASS   | PASS      | — same
Stability        | PASS   | PASS      | — same

Section: TRAINING DATA
Dataset          | 2024-Q2 | 2024-Q3  | ↑ updated
Row count        | 2.1M    | 2.8M     | ↑ +700K

Change column styling:
↑ positive improvement: text #34D399 + ✅ icon
↓ improvement (log loss): text #34D399 + ✅ icon  
⚠ changed/degraded: text #FBBF24 + ⚠ icon
— same: text-disabled
Section headers: caption, uppercase, text-secondary, full-width bg-tertiary row
```

---

## PROMPT 17 — Global Search (cmd+K)
**Depends on: Prompts 00, 02**

```
Build the MLM Global Search modal triggered by cmd+K keyboard shortcut.

TRIGGER: 
Add a keyboard listener for cmd+K (Mac) / ctrl+K (Windows) that opens the search modal.
Also add a search icon button [🔍] in the top bar that triggers it.

MODAL OVERLAY:
Full-screen backdrop: bg-primary/70 backdrop-blur-sm
Modal card: centered, top 20% of viewport, max-w-2xl, bg-elevated, border border-default, rounded-xl, shadow-2xl

SEARCH INPUT (top of modal):
Large search input (h-12, text-lg)
Left icon: magnifying glass (text-secondary)
Placeholder: "Search models, versions, findings, artifacts..."
Right: [ESC] keyboard hint badge (text-disabled, caption)
Border-bottom border-subtle — no outer border on input itself
Auto-focus on open

EMPTY STATE (before typing):

"RECENT" section label (caption, uppercase, text-secondary, padding sm)
2 recent items:
  [🔷 MOD] "Credit Default Predictor" right-aligned: "MOD-2024-00421" (mono, text-disabled) + RiskTierBadge tier=2
  [🔷 MOD] "Fraud Scorer v2"          right-aligned: "MOD-2024-00387" (mono, text-disabled) + RiskTierBadge tier=1

"QUICK FILTERS" section label
Horizontal scrollable pill buttons:
[Tier 1 Models] [Pending My Approval] [Production Models] [Active Alerts] [Validation In Progress]
Pill: bg-tertiary, border border-subtle, body-small, rounded-full, hover bg brand-primary/10

RESULTS STATE (while typing "credit"):

"RESULTS FOR 'credit'" section label
Grouped results:

MODELS (2 results):
  [🔷] "Credit Default Predictor" · Development · Tier 2 · Owner: Jane
  [🔷] "Credit Card Fraud Scorer" · Monitoring · Tier 1 · Owner: Mark

VERSIONS (1 result):
  [📦] "v1.2.0 — Credit Default Predictor" · Validated · 2024-11-15

FINDINGS (1 result):
  [⚠] "Finding F-042 — Credit scoring bias" · Critical · Open

Each result row:
  Left icon (type indicator colored square/circle)
  Primary text (body, text-primary) — search term highlighted in brand-primary
  Meta info (caption, text-secondary)
  Keyboard navigation: highlighted row gets bg-tertiary

KEYBOARD NAVIGATION:
Arrow up/down: move selection
Enter: navigate to selected item and close modal
Escape: close modal

Footer bar:
"↑↓ navigate · ↵ select · esc close" (caption, text-disabled, padding sm, border-top border-subtle)
```

---

## PROMPT 18 — Notification Panel
**Depends on: Prompts 00, 02**

```
Build the MLM in-app notification panel (sliding panel from top-right).

TRIGGER:
Bell icon button in top bar. Badge showing unread count "4" in red.
Click toggles panel open/closed.

PANEL:
Position: fixed, top 56px (below top bar), right 0, width 380px
Height: max-h-[80vh], overflow-y-auto
bg-elevated, border-l border-b border-subtle, rounded-bl-xl
Shadow: shadow-2xl
Smooth slide-in animation from right (transform + opacity)

PANEL HEADER:
"Notifications" (h3, text-primary) left
"Mark all read" button (ghost, caption, brand-primary) right
Horizontal filter tabs: [All(4)] [Approvals(1)] [Alerts(2)] [System(1)]
Active tab: All — underline brand-primary

NOTIFICATION ITEMS (stacked, each with border-bottom border-subtle):

Item 1 — CRITICAL (unread — dot indicator):
  Left: red circle icon 🔴
  Content:
    "CRITICAL · 2 min ago" (caption, red #DC2626, semi-bold)
    "Data drift threshold breached" (body, text-primary)
    "Fraud Scorer v2 — Production" (body-small, text-secondary)
  Right: [View Incident →] (caption, brand-primary link)
  Background: rgba(220,38,38,0.05) — unread tint

Item 2 — APPROVED (read):
  Left: green circle ✅
  "APPROVED · 1 hour ago" (caption, text #34D399)
  "Development gate approved" (body, text-primary)
  "Credit Default Predictor v1.2.0 · Approved by: Jane Smith" (body-small, text-secondary)

Item 3 — APPROVAL REQUEST (unread):
  Left: amber bell 🔔
  "APPROVAL REQUIRED · 3 hours ago" (caption, amber)
  "Your approval needed: Inception Gate" (body, text-primary, semi-bold)
  "AML Transaction Monitor · SLA: 5 hours remaining" (body-small, text-secondary)
  [Review & Decide →] button (outline, amber, small, full-width mt-sm)

Item 4 — SYNC (read):
  Left: blue sync icon ↻
  "SYNC · Today 09:15" (caption, text-secondary)
  "MLflow sync: 14 runs synced" (body, text-primary)
  "Credit Default Predictor" (body-small, text-secondary)

Empty state:
  Bell icon (large, text-disabled)
  "You're all caught up!"
  "No new notifications." (text-secondary)

Footer:
[View all notifications →] link (brand-primary, centered, padding md, border-top)
```

---

## PROMPT 19 — Vendor Model Card
**Depends on: Prompts 00, 02**

```
Build the Vendor Model detail page for MLM — simpler than internal model, card-based layout.

PAGE HEADER (reuse ProjectHeader component):
"Tableau Einstein Analytics" (h1)
"VEND-2024-00042 · ● Tier 3 · Sales Analytics · Status: ACTIVE"
ModelTypeBadge type="VENDOR"

TABS: [Overview] [Due Diligence] [Risk Assessment] [Reviews] [Audit]
Active: Overview

TWO-COLUMN LAYOUT (60/40 split):

LEFT COLUMN:

VENDOR INFORMATION card (bg-tertiary, border, rounded-lg, padding xl):
Section label "VENDOR INFORMATION" (caption, uppercase)
Info rows (label left, value right):
  Provider:          Tableau / Salesforce
  Product:           Tableau 2024.1
  Model Capability:  Sales forecasting, anomaly detection on dashboards
  Hosting:           Vendor cloud (Salesforce infrastructure)
  Data Sent:         Aggregated sales metrics — NO PII (green "No PII" badge)
  Contract Ref:      MSA-2024-TAB-001 (mono)
  DPA Confirmed:     ✅ Yes — data stays in US region (green check)
  Vendor Training:   ✅ Opted out of Tableau model training (green check)

STATE MACHINE card (below vendor info):
"CURRENT STATUS" label
Horizontal state flow with arrows:
[REGISTERED] → [ACTIVE_IN_USE ●] → [UNDER_REVIEW] → [RESTRICTED] / [DECOMMISSIONED]

Current state "ACTIVE_IN_USE" highlighted: bg brand-primary/20, border brand-primary
Other states: bg-tertiary, border border-subtle, text-secondary
State circles connected by → arrows (#374151)

[Initiate Review] button (outline, amber, below state diagram)

RIGHT COLUMN:

REVIEW SCHEDULE card:
"REVIEW SCHEDULE" section label
Last review:   March 2024
Next review:   March 2025  ← show green "✅ OK · 4 months away" badge
Review Owner:  Mark Chen
[Schedule Review] button (outline, brand-primary, full width)

DUE DILIGENCE DOCUMENTS card:
"DUE DILIGENCE DOCUMENTS" label
List:
  ✅ Tableau SOC 2 Type II Report 2024     [Download]
  ✅ Model Methodology Overview (Tableau)  [Download]
  ⏳ Independent benchmark results         [Upload]  ← amber, not yet uploaded

USAGE VOLUME card:
"USAGE VOLUME" label + [Update Usage] button (ghost, small, right)
"Nov 2024: ~4,200 forecasts generated" (body, text-primary)
"Oct 2024: ~3,800 forecasts" (body-small, text-secondary)
Simple bar showing monthly trend (last 3 months, inline mini bars)

INCIDENTS card (below usage):
"INCIDENTS" label + [+ Log Incident] button (ghost, small, right)
Empty state: "No incidents logged ✅"
```

---

## PROMPT 20 — Admin Console: Integration Health
**Depends on: Prompts 00, 02**

```
Build the MLM Admin Console — Integration Health page.

PAGE HEADER:
"Integration Health" (h1)
Subtitle: "Monitor all platform integrations and provisioning status" (body, text-secondary)
Last updated: "Auto-refreshes every 30s · Last: just now" (caption, text-secondary, right-aligned)

THREE SECTIONS (stacked, each as card):

SECTION 1: ENVIRONMENT PROVISIONING
Card header: "Environment Provisioning" (h2) + overall status badge "✅ Healthy" or "⚠ Degraded"

ServiceNow adapter row:
Left: colored status dot (green) + "ServiceNow" (body, text-primary, semi-bold)
Center: "API Destination: mlm-servicenow-provisioning · Last event: 2 hours ago · Success rate: 98.2%"
Right: [Test Connection] (outline, small) + [Edit] (ghost, small) + [Disable] (ghost, small, red text)

Metrics row below:
3 mini metric chips: "14 total events" | "13 successful" | "1 failed (DLQ)"
[View DLQ] link in brand-primary if DLQ count > 0

Pending Callbacks subsection:
"Pending callbacks: 3 · Oldest: 4 hours ⚠" (amber, with link [View Pending])
Progress: 3 awaiting response from ServiceNow

SECTION 2: ML PLATFORM INTEGRATIONS
Card header: "ML Platform Integrations" (h2)

Adapter rows (3 rows with status):
Row 1: ✅ "SageMaker (Account: 987654321098)" 
  "14 projects linked · Last sync: 3 min ago · 0 errors"
  [Test] [Edit] buttons

Row 2: ⚠ "Databricks (workspace: company.cloud)"
  "Connection degraded — authentication error · Last success: 2h ago"
  [Reconnect] (outline, amber) [Edit] (ghost)
  Amber warning callout: "Token may have expired. Check connection settings."
  
Row 3: ✅ "MLflow OSS (tracking.company.com)"
  "8 projects linked · Last sync: 5 min ago · 0 errors"
  [Test] [Edit]

Registry Sync Status subsection:
2 metric chips: "Unlinked registrations: 2 ⚠ [Resolve]" | "Active conflicts: 0 ✅"
Last reconciliation: "12 min ago · 0 drift found" (caption, text-secondary)

SECTION 3: MONITORING & NOTIFICATION CHANNELS
Card header: "Monitoring & Notifications" (h2)

5 rows:
✅ SageMaker Model Monitor   "Active · 12 monitor schedules · 3 active alerts"
✅ Datadog (link-out)        "Active · Link-out configured"
✅ Custom Ingest API         "Active · 12 active sources · 8,421 metrics today"
✅ Email (SMTP)              "smtp.company.com · Last sent: 5 min ago"
✅ Slack                     "#mlm-notifications · Last sent: 2 min ago"
✅ PagerDuty                 "Service: MLM Critical · 1 open incident"

[+ Add Integration] button (brand-primary filled, right-aligned, bottom of page)
```

---

## PROMPT 21 — First-Run Onboarding
**Depends on: Prompts 00**

```
Build the MLM first-run onboarding experience — shown when a new user logs in with no projects.

EMPTY STATE PAGE (full content area, no sidebar content):

Center-aligned hero section:

Large subtle illustration area (use CSS/SVG geometric shapes — no external images):
  Circular nodes connected by lines suggesting a workflow/lifecycle
  Use brand colors at low opacity as decoration
  Subtle animated pulse on the nodes

Heading: "Welcome to MLM, Bhavik" (display size, text-primary, font-bold)
Subheading: "Track your ML models from idea to production with full governance." (h2, text-secondary, font-normal, max-w-md, text-center)

PRIMARY CTA CARD (bg-tertiary, border border-default, rounded-2xl, padding 2xl, max-w-sm):
Icon: 🚀 (large emoji or Lucide rocket icon, brand-primary)
Title: "Start your first project" (h2)
Body: "Create a model project to begin tracking it through the full lifecycle — from inception to deployment." (body, text-secondary)
[Create Model Project] button (brand-primary filled, full width, large h-12)

OR SECTION:
"──── or ────" divider (text-secondary, caption)

Two secondary action rows:
[⬆ Import from SageMaker Model Registry] (outline, full-width, max-w-sm)
[👥 Browse models in your organization] (ghost, full-width, max-w-sm)

GETTING STARTED SECTION (below, max-w-2xl, margin-top 3xl):
"GETTING STARTED" section label (caption, uppercase, text-secondary, text-center)

Three-column guide cards:
Card 1: 📖 icon + "Quick Start Guide" + "Up and running in 5 minutes" + [Read →] link
Card 2: 🎬 icon + "Platform Walkthrough" + "Video tour of all 7 lifecycle stages" + [Watch →] link
Card 3: 📋 icon + "Understanding Risk Tiers" + "How MLM governs models by risk" + [Learn →] link

Each guide card: bg-tertiary, border border-subtle, rounded-lg, padding lg, hover border-brand-primary

CONTEXTUAL TOOLTIP COMPONENT (reusable):
Floating tooltip card: bg-elevated, border border-subtle, rounded-lg, padding md, max-w-xs, shadow-lg
Header row: 💡 icon + title (body, semi-bold) + [×] close button (ghost, icon, right)
Body: description text (body-small, text-secondary)
Footer: [Learn more] link (brand-primary, caption) + [Got it] button (outline, caption, small)
Pointer arrow at bottom (CSS triangle)

Show the tooltip demoed on the page, positioned near a "Risk Tier" label with content:
"MLM automatically calculates a Risk Tier (1–4) based on the model's decision autonomy, impact level, and applicable regulations. Tier 1 models require the most rigorous validation and oversight."
```

---

## PROMPT 22 — Inline Approval Landing Page
**Depends on: Prompts 00**

```
Build the MLM inline approval landing page — accessed via one-time token link from email or Slack.

This page is shown WITHOUT the main app sidebar/navigation. It's a standalone, minimal page.

PAGE BACKGROUND: bg-primary (#0F0F0F), centered layout

HEADER (minimal):
Top bar: "MLM" logo (text, brand-primary) left only. No navigation.

MAIN CARD (center of page, max-w-md, bg-elevated, border border-default, rounded-2xl, shadow-2xl, padding 2xl):

Top section — what you're approving:
Small label: "APPROVAL REQUEST" (caption, uppercase, brand-primary, letter-spacing wide)
Title: "Validation Gate Approval" (h1, text-primary)

Model detail box (bg-tertiary, rounded-lg, padding lg, mt-md):
  Model name: "Fraud Scorer v2" (h2, text-primary)
  Row: "MOD-2024-00387" (mono, text-secondary) + " · " + "v2.0.0" + RiskTierBadge tier=1
  Row: "Submitted by: John Doe (Lead Validator)"
  Row: "Nov 15, 2024 09:00"

Divider

Summary section:
"VALIDATION SUMMARY" label (caption, uppercase, text-secondary)
3 summary items with icon:
  ✅ 9/9 test cases completed
  ⚠  1 Major finding — with remediation plan attached
  📄 Validation report available

Divider

Comment field:
"Add a comment (optional)" label (caption, text-secondary)
Textarea (3 rows, bg-tertiary, border border-subtle, placeholder "Your decision comment...")

Consequence notice (bg-tertiary, border border-subtle, rounded-lg, padding md):
Body-small, text-secondary:
"By confirming, you are approving this gate. Your identity (Sarah Lee) and timestamp will be permanently recorded in the immutable audit log."

Action buttons (full width, stacked, gap md):
[✅ Confirm Approval] — large h-12, bg #059669, text white, rounded-lg, font-semibold, hover bg #047857
[❌ Reject] — large h-12, bg #2D1E1E, text #F87171, border #DC2626, rounded-lg, font-semibold

Secondary link below:
"Want full context first? View the complete Validation Stage →" (brand-primary, caption, text-center, mt-md)

TOKEN STATUS BAR (bottom of card, border-top border-subtle):
"🔒 Secure one-time link · Expires in 7 hours 43 minutes" (caption, text-disabled, text-center, padding-sm)

SUCCESS STATE (after clicking Confirm):
Replace card content with:
Large ✅ green circle animation (scale + fade in)
"Approved!" (h1, text #34D399)
"Your decision has been recorded." (body, text-secondary)
"Fraud Scorer v2 · Validation Gate · Approved by Sarah Lee · Nov 15 2024 14:23 UTC" (caption, text-disabled, mono)
[View in MLM Platform →] (outline, brand-primary, mt-xl)

EXPIRED TOKEN STATE:
⛔ icon (red, large)
"This link has expired" (h1)
"Approval links are valid for 8 hours and can only be used once." (body, text-secondary)
[Sign in to MLM to review pending approvals →] (brand-primary link)
```

---

## PROMPT 23 — GenAI Prompt Registry Panel
**Depends on: Prompts 00, 02**

```
Build the MLM GenAI Prompt Registry panel — shown within the Development stage for GenAI model types.

PANEL HEADER:
"PROMPT REGISTRY" section label (caption, uppercase, text-secondary)
Right: [+ New Prompt Version] button (outline, brand-primary, small)
Status line: "Active in production: v2.1.0 · Last changed: Nov 12" (body-small, text-secondary)

PROMPT VERSIONS TABLE:
Columns: Version | Status | Changed By | Date | Notes | Actions

Rows:
v2.1.0  DEPLOYED    Bhavik Patel  Nov 12  "Added refusal handling"     [View] [Compare]
v2.0.0  SUPERSEDED  Bhavik Patel  Oct 28  "Improved claim context"     [View] [Compare]
v1.0.0  SUPERSEDED  Bhavik Patel  Sep 5   "Initial production prompt"  [View] [Compare]

v2.1.0 row: bg rgba(99,102,241,0.05), "DEPLOYED" badge in green
SUPERSEDED rows: text-secondary, italic status text

CURRENT SYSTEM PROMPT PREVIEW (expandable card):
Card: bg-tertiary, border border-subtle, rounded-lg
Header: "CURRENT SYSTEM PROMPT (v2.1.0)" label + [Edit Prompt] button (outline, amber, small, right)
  Warning near Edit button: "(⚠ Creates new version · triggers re-validation)" — tooltip on hover

Prompt content area (bg-elevated, rounded, padding lg, font-mono, text-sm, text-secondary, max-h-32 with gradient fade):
"You are an insurance claims assistant. You help policyholders understand their claim status and next steps. You must:
1. Only use information from the provided context
2. Never speculate about claim outcomes
3. Decline to answer questions unrelated to the claim..."

[Expand full prompt ▼] toggle link (brand-primary, caption, mt-sm)

GUARDRAIL CONFIGURATION card (below prompt):
"GUARDRAIL CONFIGURATION" section label
Status row: "AWS Bedrock Guardrail: gr-abc123 · ✅ Active" — with green dot
Content filters row: three colored badges: [HATE: Blocked 🚫] [INSULTS: Blocked 🚫] [SEXUAL: Blocked 🚫]
PII Redaction row: "SSN, Credit Card, Phone — enabled ✅"
[View Guardrail in Bedrock ↗] link (text-secondary, caption, external icon)

PROMPT DIFF VIEW (shown when Compare clicked — modal):
Modal title: "Prompt Comparison: v2.0.0 → v2.1.0"
Side-by-side text diff:
Left (v2.0.0): red highlighted removed lines
Right (v2.1.0): green highlighted added lines
Standard code diff styling (like GitHub diff view but dark themed)
[Close] button
```

---

## PROMPT 24 — Business Model Registry Panel
**Depends on: Prompts 00, 02**

```
Build the MLM Business Model Registry panel — shown in the project Registry tab.

PANEL HEADER:
"Business Model Registry" (h2)
Meta: "SM Model Package Group: credit-default-predictor-mpg" (body-small, text-secondary, JetBrains Mono for group name)
Status row: "Last sync: 3 min ago · Status: ✅ IN_SYNC" (caption, text-secondary)
Right: [Sync Now ↻] button (ghost, small) + [View in SageMaker ↗] external link (ghost, small)

REGISTRY TABLE:
Columns: Version | MLM Status | SM Status | Sync | Eligible | Actions

Rows:
v1.2.0  ✅ VALIDATED    SM: Approved     ✅ IN_SYNC  ✅ Yes  [View Details]
v1.1.0  ⚫ SUPERSEDED   SM: Approved     ✅ IN_SYNC  ❌ No   [View Details]
v1.0.0  ⚫ SUPERSEDED   SM: Rejected     ✅ IN_SYNC  ❌ No   [View Details]

MLM Status column: StatusBadge variants
SM Status column: plain text with colored dot: Approved=green, Rejected=red, PendingManualApproval=amber
Sync column: "✅ IN_SYNC" green or "⚠ MLM_AHEAD" amber or "🔴 CONFLICT" red
Eligible column: ✅ Yes (green) or ❌ No (red muted)
v1.2.0 row: subtle bg-brand-primary/5 highlight (current deployed)

UNLINKED REGISTRATIONS section:
If none: "✅ No unlinked registrations — all SM packages linked to MLM projects" (green, small)

If some exist (demo alternate state):
⚠ amber callout card:
"2 Unlinked SM Registrations Detected"
Body: "The following SageMaker Model Packages were registered without MLM tracking. Please link them to an MLM project within 5 business days."
Table: Package Group | Detected | SLA | Action
  fraud-scorer-v2-mpg       | Nov 10  | 2 days ⚠  | [Link to MLM]
  churn-pred-experimental   | Nov 14  | 4 days     | [Link to MLM]

SYNC LOG section:
"SYNC LOG" section label + [View All] right
3 log entries:
✅ Nov 15 10:32 · MLM→SM: validation-status tag updated · v1.2.0
✅ Nov 15 10:30 · SM→MLM: ModelPackage registered · v1.2.0
✅ Nov 10 14:10 · Reconciliation: 0 drift found

Each entry: colored dot + timestamp (mono) + direction badge (MLM→SM blue / SM→MLM amber) + description + version chip
```

---

## SEQUENCING GUIDE

Run prompts in this order for best results:

```
FOUNDATION (run first):
  00 → Design System & Layout
  01 → Sidebar Navigation  
  02 → Badge Components (StatusBadge, RiskTierBadge, ModelTypeBadge)

REGISTRY & NAVIGATION:
  03 → Model Project Card
  04 → Portfolio Dashboard
  07 → Global Search (cmd+K)

HOME SCREENS:
  05 → Role-Adaptive Home Screens
  06 → Project Header & Tab Navigation

PROJECT LIFECYCLE:
  07 → Lifecycle Map  ← Hero feature, spend iteration time here
  08 → Inception Stage Panel
  09 → Development: Experiment Table
  10 → Candidate Model Detail
  11 → Validation Workbench
  12 → Findings Tracker
  13 → My Tasks / Approval Center
  14 → Implementation Stage
  15 → Monitoring Dashboard
  16 → Version Explorer & Comparison

SPECIALIZED VIEWS:
  17 → Notifications Panel
  18 → (skip — handled in 05)
  19 → Vendor Model Card
  20 → Admin: Integration Health
  21 → First-Run Onboarding
  22 → Inline Approval Landing Page
  23 → GenAI Prompt Registry
  24 → Business Model Registry

ESTIMATED LOVABLE SESSIONS: 24 prompts
ESTIMATED TIME:              8–12 hours of iteration
ESTIMATED COVERAGE:          ~80% of V1 UI
REMAINING 20% (manual code): D3 lineage graph, WebSocket badges, 
                              cmd+K API wiring, inline approval token logic
```

---

## TIPS FOR ITERATION

After each prompt generation:

1. **Check component reuse** — Lovable sometimes regenerates existing components. If it does, explicitly say: "Reuse the StatusBadge and RiskTierBadge components built earlier."

2. **Enforce the color system** — If colors drift, paste this reminder: "All backgrounds must use the MLM dark color system: bg-primary #0F0F0F, bg-secondary #161616, bg-tertiary #1C1C1C. Text primary #F9FAFB, secondary #9CA3AF."

3. **Fix font inconsistencies** — If Inter isn't applied: "Apply Inter font globally via @import. All model IDs, hashes, and URIs should use JetBrains Mono."

4. **Request specific states** — Always ask for loading skeleton, empty state, and error state variants: "Also show the loading skeleton state for this table, and an empty state for when there are no results."

5. **Component extraction prompt** (use when a component appears inline that should be reusable): "Extract the finding severity badge as a standalone FindingSeverityBadge component that I can reuse across the Validation and Tasks pages."
```

---

*End of Lovable.dev Prompt Templates*  
*MLM Platform — 24 Prompts · V1 Coverage ~80%*
