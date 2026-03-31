# CCE Solution Design
**Version:** 0.3 – Draft

---

## Table of Contents

1. [Overview](#1-overview)
2. [Purpose & Motivation](#2-purpose--motivation)
3. [Prerequisites](#3-prerequisites)
4. [Architecture](#4-architecture)
5. [Error Handling](#5-error-handling)
6. [Security](#6-security)
7. [Compliance Subsystem Design](#7-compliance-subsystem-design)
8. [Open Issues](#8-open-issues)

---

## 1. Overview

The **Care Coordination Engine (CCE)** is an event-driven platform addressing two fundamental challenges in primary healthcare delivery:

1. **Compliance** — Tracking protocol compliance and generating intelligence when defined conditions are met
2. **Coordination** — Enabling care handoffs across multiple independent health systems

CCE operates as an **event observer and care coordinator**. It receives events from participating systems (CHW apps, facility EMRs, disease registries, labs), tracks what has happened, compares against Compliance Protocols, and acts — either by generating intelligence events (alerts, reminders, escalations) or by coordinating cross-system handoffs.

### 1.1 Core Principle

> CCE knows **"what happened and what should have happened"** — not "what the patient's blood pressure is" or "how your EMR should work."

Each participating system remains authoritative for its own clinical data and internal workflows. CCE observes and coordinates across system boundaries but does not control individual systems.

---

## 2. Purpose & Motivation

### 2.0 The Fundamental Problem

India's health systems generate millions of events daily across RCH, NCD Portal, Nikshay, U-WIN, facility EMRs, and other systems. Yet **60-70% of patients requiring follow-up care never complete their care pathway**. Events are recorded but not coordinated, and deviations from Compliance Protocols go undetected until it's too late.

### 2.1 Compliance

> **Note — Compliance Protocol vs Clinical Protocol:**
> CCE does **not** deal with Clinical Protocols directly. Clinical Protocols define medical/clinical decision-making logic (treatment, diagnosis, test orders) — these remain entirely within participating systems and their clinicians.
>
> CCE works with **Compliance Protocols** — which define the expected care management pathway a patient should follow: what events should happen, when they should happen, and what to do when deviations occur.

CCE loads Compliance Protocols from external Knowledge Libraries and continuously compares actual events against expected care pathways.

#### 2.1.1 Compliance Tracking

CCE tracks what has happened and compares it against what should have happened.

| Capability | Description |
|---|---|
| Event Timeline | Maintains complete event history per patient journey across all participating systems |
| Protocol Comparison | Compares actual events against protocol expectations (timing, sequence, required actions) |
| Compliance Metrics | Calculates compliance rates at patient, facility, and program levels |
| Journey Visibility | Provides unified view of care pathway across system boundaries |
| Dashboard | Real-time visualization of patient journeys, compliance metrics, and care gaps via APIs |

**Example:** For an ANC protocol requiring visits at weeks 12, 20, 26, 30, 34, 36, 38, 40 — CCE tracks each visit event and calculates whether the patient is on track, ahead, or behind schedule.

#### 2.1.2 Intelligence

CCE generates intelligence — actions taken in response to events, conditions, or patterns defined in the Compliance Protocol.

> **Key principle: CCE acts; systems decide.** CCE takes action; each participating system decides whether and how to respond.

##### 2.1.2.1 Notifications

| Notification Type | Description | Example |
|---|---|---|
| Missed Events | Expected event did not occur within protocol timeline | "ANC visit due at week 20, now 5 days overdue" |
| Late Events | Event occurred but outside acceptable tolerance | "Referral appointment was 8 days late (protocol: 7 days)" |
| Out-of-Sequence | Events occurred in wrong order | "Lab results reviewed before sample collection logged" |
| Event Combinations | Specific combination of event types triggers alert | "High BP event combined with missed medication pickup event" |
| Escalations | Conditions requiring supervisor attention | "High-risk pregnancy patient missed 2 consecutive visits" |
| Reminders | Proactive alerts before events become overdue | "ANC visit due in 3 days" |

##### 2.1.2.2 Coordination

Coordination intelligence enables care handoffs across system boundaries. When an event in one system requires action in another, CCE routes the work — creating tasks, forwarding data, or triggering actions in the destination system.

> **Note:** Technically, coordination actions (send task request, route data) are defined and triggered the same way as notification actions (send alert, reminder). CCE sends these to adaptors; each adaptor translates them into records within its target system.

**Example — Hypertension Referral Pathway:**

1. CHW screens patient in mobile app → detects high blood pressure
2. Referral needed → CHW app emits referral event
3. CCE coordinates → Sends coordination event to facility adaptor; adaptor creates task in facility EMR
4. Facility receives task → Doctor reviews patient, confirms diagnosis, prescribes treatment
5. Follow-up scheduled → CCE sends coordination event to CHW app adaptor; adaptor creates follow-up task
6. CHW sees outcome → Referral status and follow-up appear in CHW's task list

#### 2.1.3 Example: High-Risk Pregnancy Follow-up

```
Day 0:  ANM identifies high-risk pregnancy
        ✓ Event logged in RCH app
        → CCE: Patient enrolled in high-risk ANC protocol, tracking initiated

Day 1:  Doctor creates referral to District Hospital
        ✓ Event logged in facility EMR
        → CCE: Tracking referral, expecting appointment within 7 days

Day 5:  No appointment event received
        → CCE: Generates "referral_pending_alert" (medium severity)

Day 8:  No appointment event received
        → CCE: Generates "referral_overdue_alert" (high severity)
        → CCE: Generates "supervisor_escalation" event

Day 10: Appointment completed
        ✓ Event logged
        → CCE: Referral loop closed (3 days late, logged for metrics)
```

### 2.2 Unified Model: Compliance + Intelligence

| Scenario | With CCE |
|---|---|
| Referral created | Task request sent to facility adaptor + completion tracked against protocol timeline |
| Patient misses follow-up | Alert generated + follow-up task request sent + escalation if needed |
| Lab results delayed | Deviation detected + notification to ordering physician + patient reminder |
| High BP during ANC visit | Referral task request sent to facility adaptor + CHW notified + completion tracked |

### 2.3 Phased Implementation

| Phase | What's Deployed | CCE Capabilities | Value Delivered |
|---|---|---|---|
| Phase 1: Compliance | Emitter Adaptor(s) only | Compliance Tracking, Dashboard | Visibility into patient journeys, compliance metrics, care gap identification |
| Phase 2: Intelligence | Add Receiver Adaptor(s) | + Notifications, Coordination | Automated alerts, escalations, cross-system task routing |

---

## 3. Prerequisites

### 3.1 Common Patient Registry (Mandatory)

A shared patient registry (Master Patient Index / Client Registry) must exist across all participating systems.

| Requirement | Description |
|---|---|
| Shared patient ID | All participating systems must use the same patient identifier (e.g., national health ID, MPI-assigned ID) |
| Patient lookup | Systems must be able to resolve the shared ID to their local patient records |
| Event correlation | Events submitted to CCE must include the shared patient ID in the context |

**Why mandatory:**
- CCE cannot perform patient matching — it relies on explicit shared identifiers
- Without a common ID, an event about "Patient A" from SmartCare cannot be linked to an action for the same patient in OpenMRS

**CCE does NOT provide:** patient registry functionality or patient matching algorithms.

> **Note:** If CCE is deployed for a **single source system only** (e.g., one CHW app with no cross-system coordination), a common patient registry is **not mandatory**.

### 3.2 Identity Provider (Mandatory)

An **OIDC/OAuth 2.0 compatible Identity Provider** must be available for authenticating participating systems. If an existing Identity Provider is not available, an instance can be set up separately from CCE setup.

---

## 4. Architecture

### 4.2 Design Principles

- **Event observer, not controller** — CCE observes events and generates intelligence; participating systems decide how to act
- **Events are triggers, not state** — Authoritative state lives within participating app resources, not event streams
- **CCE owns coordination and compliance, not clinical data** — Each system remains authoritative for its own clinical data
- **Participating systems remain autonomous** — Systems can use any internal architecture; adaptors translate between CCE and each system
- **Protocol-first** — Configurable compliance Protocols and Action Definitions; no ad-hoc logic
- **Hybrid CloudEvents + FHIR events** — Events use the CloudEvents envelope with clinical data in the data payload (preferably FHIR resources, but non-FHIR JSON is also supported)
- **Clinical Data** — Does not need to be a complete clinical record; limited to what is necessary for compliance tracking

### 4.3 Integration Interface

#### 4.3.1 Events

Participating systems emit events to CCE when clinical activities occur.

##### 4.3.1.1 Event Structure

> **Design Decision: Hybrid CloudEvents + FHIR (ADR Accepted)**

- **CloudEvents envelope** — Lightweight, standards-based structure with built-in support for idempotency, content typing, and extensibility
- **FHIR in data** — Clinical payloads use FHIR resources (Encounter, Observation, etc.) with `datacontenttype: "application/fhir+json"`. Non-FHIR JSON also supported.
- **CCE extension attributes** — Compliance tracking context carried as optional CloudEvents extension attributes (routing hints)

**Example CloudEvents message:**

```json
{
  "specversion": "1.0",
  "id": "evt-uuid-12345",
  "source": "smartcare-chw",
  "type": "org.openphc.cce.encounter",
  "subject": "ABHA-1234567890",
  "time": "2026-01-15T10:30:00Z",
  "datacontenttype": "application/fhir+json",
  "sourceeventid": "enc-991122",
  "protocolinstanceid": "pi-uuid-67890",
  "protocoldefinitionid": "anc-high-risk-v2.1",
  "actionid": "anc-visit-2",
  "facilityid": "PHC-456",
  "data": {
    "resourceType": "Encounter",
    "status": "finished",
    "class": {
      "system": "http://terminology.hl7.org/CodeSystem/v3-ActCode",
      "code": "AMB"
    },
    "type": [
      {
        "coding": [
          { "system": "http://openphc.org/encounter-types", "code": "anc-visit" }
        ]
      }
    ],
    "serviceType": {
      "coding": [
        { "system": "http://openphc.org/service-types", "code": "high-risk-anc" }
      ]
    },
    "period": {
      "start": "2026-01-15T10:00:00Z",
      "end": "2026-01-15T10:30:00Z"
    }
  }
}
```

**CloudEvents Core Attributes:**

| Attribute | Required | Description |
|---|---|---|
| `specversion` | Always | CloudEvents specification version (always "1.0") |
| `id` | Always | Unique identifier for this event (UUID). Combined with `source`, forms the CloudEvents uniqueness key for idempotency |
| `source` | Always | Identifier of the registered system emitting the event (e.g., "smartcare-chw") |
| `type` | Always | Event category (e.g., encounter, observation, referral, enrollment). Used for routing/filtering — not for step matching |
| `subject` | Always | Shared patient identifier from the common patient registry (e.g., "ABHA-1234567890") |
| `time` | Always | When the clinical activity actually occurred at the source (ISO 8601, UTC) |
| `datacontenttype` | Always | Content type of the data payload (`application/fhir+json` or `application/json`) |
| `data` | Always | The clinical payload representing the activity |

**CCE Extension Attributes (all optional):**

| Attribute | Description |
|---|---|
| `sourceeventid` | The event's ID in the source system. Combined with `source`, provides secondary idempotency key |
| `protocolinstanceid` | Explicit routing hint: which protocol instance (patient journey) this event belongs to |
| `protocoldefinitionid` | Explicit routing hint: which protocol definition this event belongs to |
| `actionid` | Explicit routing hint: which step this event fulfills. When provided with protocol context, CCE bypasses inferred step matching |
| `facilityid` | Facility where the event occurred. Used for intelligence routing and analytics |

> **Note on naming conventions:** CloudEvents extension attribute names must be lowercase with no dots, hyphens, or underscores. CCE's internal data model uses `snake_case` (e.g., `action_id`, `protocol_instance_id`). FHIR PlanDefinition uses dot-separated notation (e.g., `action.id`).

**Event Idempotency:**
- Events with the same `id` + `source` combination are accepted only once
- Duplicate submissions return success but do not modify state
- Secondary idempotency via `source` + `sourceeventid` pair

**Timestamps:**
- `time` — When the clinical activity actually happened (provided by source system)
- `received_at` — When CCE received the event (set by CCE internally, not in the CloudEvents message)

---

#### 4.3.2 Compliance Protocol

A Compliance Protocol Definition defines a care pathway as a sequence of expected clinical events with timing, dependencies, and intelligence rules.

##### 4.3.2.1 Protocol Definition Structure

Protocol definitions use the **FHIR PlanDefinition** resource as the canonical format.

> **Note:** In CCE's context, FHIR PlanDefinition is not being used to drive clinical workflows. It is being re-purposed to express expected compliance to a given workflow.

Protocol definitions are **immutable once published** (`status: "active"`). To change a protocol, publish a new version (`status: "retired"` on the old version).

##### 4.3.2.2 Why PlanDefinition

- **Standard structure** — Steps, sequencing, timing, dependencies, conditions, and action references are native PlanDefinition concepts
- **Interoperability** — Protocols can be published to FHIR registries and shared across implementations
- **Version pinning** — FHIR's canonical URL + version scheme provides built-in version pinning
- **Trigger definitions** — PlanDefinition's `TriggerDefinition` with `DataRequirement` maps naturally to CCE's resource-based matching

##### 4.3.2.3 How PlanDefinition Elements Map to Compliance Concepts

| PlanDefinition Element | Compliance Concept | Notes |
|---|---|---|
| `action.id` | Step identifier | Unique within the PlanDefinition. Referenced as `action_id` in step instances and intelligence output |
| `action.trigger` | Event matching | `TriggerDefinition` — either `type: "data-added"` with `DataRequirement` for FHIR resource matching, or `type: "named-event"` with condition for non-FHIR matching |
| `action.relatedAction` | Timing + dependencies | `relationship: "after-start"` with `offsetDuration` for timing; `relationship: "after-end"` for dependencies |
| `action.timingTiming.repeat` | Recurring steps | `count`, `frequency`, `period`, `periodUnit` for repeating actions |
| `action.requiredBehavior` | Optional steps | `"could"` for optional steps |
| Nested `action[]` with condition | Intelligence rules, actions, branches | Sub-actions with `kind: "applicability"` conditions. `definitionCanonical` references the `ActivityDefinition` to execute |
| `action.definitionCanonical` | Action definition reference | Points to an `ActivityDefinition` resource that defines what to do |

##### 4.3.2.4 Trigger Definition — Two-Tier Matching Model

| Tier | Mechanism | Purpose | Performance |
|---|---|---|---|
| Tier 1: Structural Filters | `DataRequirement` (FHIR) or `name` (non-FHIR) | Declarative field matching — resource type, coded values, date ranges, profiles | Fast and indexable. CCE indexes these at protocol load time |
| Tier 2: Condition (JSONLogic) | `condition` expression (`text/jsonlogic`) | Complex logic — cross-field comparisons, array operations, value thresholds | Expressive but evaluated at runtime only on the small candidate set from Tier 1 |

**FHIR Mode (`data-added`):**

| Field | Description |
|---|---|
| `type` | `"data-added"` |
| `data[].type` | FHIR resource type to match (e.g., `Encounter`, `Observation`, `ServiceRequest`) |
| `data[].codeFilter` | Array of coded field filters. Each specifies a `path` and a list of code values to match |
| `data[].dateFilter` | (Optional) Date field filters for temporal matching |
| `data[].profile` | (Optional) Required FHIR profiles the resource must conform to |
| `condition` | (Optional) FHIR Expression with `language: "text/jsonlogic"` for complex matching |

**Non-FHIR Mode (`named-event`):**

| Field | Description |
|---|---|
| `type` | `"named-event"` |
| `name` | A category string (e.g., `"lab-result"`, `"visit-completed"`). Used as an index key for fast pre-filtering |
| `condition` | FHIR Expression with `language: "text/jsonlogic"`. Primary matching mechanism for non-FHIR payloads |

##### 4.3.2.5 Expression Language (JSONLogic)

Expressions use JSONLogic registered as `"language": "text/jsonlogic"` within FHIR's Expression type.

| Expression | JSONLogic |
|---|---|
| `stepState == 'overdue'` | `{"==": [{"var": "stepState"}, "overdue"]}` |
| `daysOverdue > 3` | `{">": [{"var": "daysOverdue"}, 3]}` |
| `stepState == 'overdue' && daysOverdue > 3` | `{"and": [{"==": [{"var": "stepState"}, "overdue"]}, {">": [{"var": "daysOverdue"}, 3]}]}` |
| `resource.status == 'finished'` | `{"==": [{"var": "resource.status"}, "finished"]}` |
| Check resource has participants | `{">": [{"var": "resource.participant.length"}, 0]}` |

> **Alternative expression languages** (if JSONLogic proves insufficient): `FHIRPath` (`text/fhirpath`), `CQL` (`text/cql`), `FHIR Query` (`application/x-fhir-query`). Each trigger condition can declare its own language.

##### 4.3.2.6 CCE Extensions

| Extension URL | Type | Used On | Description |
|---|---|---|---|
| `http://openphc.org/fhir/StructureDefinition/tolerance-days` | `valueInteger` | `action` (step) | Grace period in days before a step is marked "overdue" |
| `http://openphc.org/fhir/StructureDefinition/intelligence-severity` | `valueCode` | Nested action (intelligence rule) | Severity level: `low`, `medium`, `high`, `critical` |
| `http://openphc.org/fhir/StructureDefinition/intelligence-target` | `valueCode` | Nested action (intelligence rule) | Who receives the intelligence output: `patient`, `assigned_worker`, `supervisor`, `facility` |

##### 4.3.2.7 Step Definition vs Step Instance

| Concept | Where Used | Description |
|---|---|---|
| `action.id` | PlanDefinition | The step definition identifier. Uniquely identifies the step within the protocol (e.g., `anc-visit-2`, `monthly-checkup`) |
| `step_instance_id` | Runtime | Unique identifier for a specific occurrence of a step for a patient (e.g., the 3rd monthly checkup) |

##### 4.3.2.8 Intelligence Rules

Intelligence rules are modeled as nested sub-actions within a PlanDefinition step action. Each rule has:
- A condition (JSONLogic expression evaluated against step runtime state)
- A `definitionCanonical` pointing to an `ActivityDefinition` (what to do)
- Extensions for `intelligence-severity` and `intelligence-target`

```json
{
  "id": "anc-visit-2-overdue-escalation",
  "title": "Escalation — supervisor (3+ days overdue)",
  "condition": [
    {
      "kind": "applicability",
      "expression": {
        "language": "text/jsonlogic",
        "expression": "{\"and\": [{\"==\": [{\"var\": \"stepState\"}, \"overdue\"]}, {\">\": [{\"var\": \"daysOverdue\"}, 3]}]}"
      }
    }
  ],
  "definitionCanonical": "ActivityDefinition/send-escalation",
  "extension": [
    { "url": "http://openphc.org/fhir/StructureDefinition/intelligence-severity", "valueCode": "high" },
    { "url": "http://openphc.org/fhir/StructureDefinition/intelligence-target", "valueCode": "supervisor" }
  ]
}
```

---

#### 4.3.3 Protocol Instances (Journeys)

A **Protocol Instance** represents a specific patient's journey through a Compliance Protocol — one enrollment, one episode of care.

> **FHIR Alignment:** A Protocol Instance is conceptually equivalent to a FHIR `CarePlan`.

##### 4.3.3.1 Why Protocol Instances Matter

A patient may be enrolled in the same protocol multiple times (e.g., Pregnancy 1 → ANC Protocol Instance A, Pregnancy 2 → ANC Protocol Instance B). Without distinct instance IDs, CCE cannot distinguish which episode an event belongs to.

##### 4.3.3.2 Protocol Instance Creation

When CCE receives an event matching a protocol's enrollment action trigger, it creates a new Protocol Instance:

```json
{
  "protocol_instance_id": "pi-uuid-67890",
  "patient_id": "ABHA-1234567890",
  "protocol_canonical": "http://openphc.org/fhir/PlanDefinition/anc-high-risk|2.1",
  "enrolled_at": "2026-01-01T00:00:00Z",
  "status": "active",
  "step_instances": []
}
```

**Progressive Step Instantiation:** Step instances are created only when their dependencies are satisfied — not all at once at enrollment.

```
Day 0 — Enrollment event arrives:
  Protocol Instance created (active)
  → anc-visit-1 instantiated as 'pending' (due: Day 14)
  → anc-visit-2 NOT instantiated yet (depends on anc-visit-1 completion)

Day 10 — anc-visit-1 completed:
  → anc-visit-1 transitions to 'completed'
  → anc-visit-2 instantiated as 'pending' (due: Day 56)
```

> **Cold Start Problem:** Protocol instances are created only when CCE observes an enrollment event. When CCE is introduced into a system that already has enrolled patients, those patients will not have protocol instances. See Section 8.1 (Brownfield Deployment).

##### 4.3.3.3 Step Instance Lifecycle

```
┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐
│ pending │──▶│   due   │──▶│ overdue │──▶│ missed  │
└─────────┘   └─────────┘   └─────────┘   └─────────┘
     │              │              │
     └──────────────┴──────────────┘
                    │
                    ▼
              ┌───────────┐
              │ completed │
              └───────────┘
     (Any state except completed/missed can also → skipped)
```

| Transition | Trigger |
|---|---|
| (created) → `pending` | Step instantiated when dependencies are satisfied |
| `pending` → `due` | Due date reached (scheduler) |
| `pending` → `completed` | Event received before due (early completion) |
| `pending` → `skipped` | Step explicitly skipped |
| `due` → `overdue` | Overdue date reached (scheduler). A deviation record is created |
| `due` → `completed` | Event received while due |
| `overdue` → `missed` | Missed date reached (scheduler). A deviation record is created |
| `overdue` → `completed` | Event received while overdue (late completion) |

##### 4.3.3.4 Protocol Version Pinning

Once created, a protocol instance is pinned to a specific PlanDefinition version via `protocol_canonical` (e.g., `PlanDefinition/anc-high-risk|2.1`). Existing instances continue using their pinned version when a new version is published. Only new enrollments use the new version.

---

#### 4.3.4 Event Processing & Matching

##### 4.3.4.2 CCE Processing Flow

```
1. Event arrives
   - Check idempotency (id + source, or source + sourceeventid)
   - If duplicate → return success, no state change
   - Record received_at timestamp
   ↓
2. Protocol Instance Resolution
   - Look up active protocol instances for this patient (subject)
   - If protocolinstanceid provided → use it directly (explicit mode)
   - If protocoldefinitionid provided → narrow to instances of that protocol
   - Otherwise → consider all active instances for this patient
   ↓
3. Step Matching (Inferred)
   - For each active protocol instance, evaluate the event's data payload
     against each step's trigger definition:
     a. Structural match — does data match the step's trigger filters?
     b. Condition match — does the JSONLogic condition evaluate to true?
     c. State filter — is this step instance in an eligible state?
        (pending, due, or overdue — not already completed or missed)
     d. Timing filter — does the event's time fall within the expected window?
   - If actionid is provided → bypass inference, validate trigger match and step state only
   ↓
4. Step Completion
   - Mark matched step instance(s) completed (completed_at = time)
   - Record on-time/late/early status
   - Evaluate intelligence rules
   ↓
5. Action Execution
   - Check step's action triggers (defined in protocol)
   - Evaluate conditions (resource fields, state, timing)
   - If condition met → execute linked action definition
```

##### 4.3.4.5 Ambiguity Handling

| Scenario | Resolution | Auto-complete? |
|---|---|---|
| Same trigger, different steps (one protocol) | Dependencies → State → Timing proximity → Fail safe | Yes, if filters resolve to one; No, if ambiguous |
| Repeating steps | Complete the current active instance; instantiate next repeat | Always yes (deterministic) |
| Cross-protocol | Complete in each protocol independently | Yes, in all matching protocols |
| Multiple instances, same protocol | Require `protocolinstanceid` | Only if extension attribute provided or single-instance match |
| Zero matches | Accept, log, no action | N/A |
| Truly unresolvable | Accept event, log, intelligence event | No — manual resolution via extension attributes |

---

#### 4.3.5 Action Definition

An Action Definition specifies what CCE does when an intelligence rule fires. Each action definition specifies:
- **Action type** — What CCE should do (e.g., send notification, create task, forward data)
- **Message template** — Content to deliver with variable placeholders resolved from the intelligence event context
- **Routing** — Which Receiver Adaptor(s) should receive the action

**Intelligence Event Output:**

```json
{
  "intelligence_type": "escalation",
  "timestamp": "2026-01-28T08:00:00Z",
  "context": {
    "patient_id": "ABHA-1234567890",
    "protocol_instance_id": "pi-uuid-67890",
    "protocol_canonical": "http://openphc.org/fhir/PlanDefinition/anc-high-risk|2.1",
    "action_id": "anc-visit-2",
    "step_instance_id": "si-uuid-11111"
  },
  "alert": {
    "action": "escalation",
    "severity": "high",
    "target": "supervisor",
    "message": "Patient Priya Sharma ANC visit is 5 days overdue"
  }
}
```

---

#### 4.3.6 API Interface

All endpoints are prefixed with `/v1/`. Breaking changes introduce a new version (`/v2/`). Previous versions remain supported for a minimum deprecation period of 6 months.

##### 4.3.6.2 Endpoints

| Operation | Description |
|---|---|
| `POST /v1/events` | Submit a CloudEvents message (with FHIR or JSON data payload) for compliance tracking |
| `POST /v1/protocol-definitions` | Register a compliance protocol definition (FHIR PlanDefinition resource) |
| `GET /v1/protocol-definitions` | List registered protocol definitions |
| `GET /v1/protocol-definitions/{id}` | Retrieve a specific PlanDefinition by ID |
| `DELETE /v1/protocol-definitions/{id}` | Remove a protocol definition (only if not in use) |
| `GET /v1/protocol-instances` | List protocol instances (filterable by patient, protocol, status, facility) |
| `GET /v1/patients/{patient_id}/protocol-tracking` | List all protocol instances being tracked for a patient |
| `GET /v1/patients/{patient_id}/protocol-tracking/{protocol_instance_id}` | Get tracking details including all step instances with current state |
| `GET /v1/patients/{patient_id}/events` | Event timeline for patient journey visualization |
| `GET /v1/protocols/{protocol_definition_id}/compliance-summary` | Aggregate compliance metrics (% on-track, overdue, missed) for a protocol |
| `GET /v1/facilities/{facility_id}/compliance-summary` | Facility-level compliance metrics across all protocols |
| `GET /v1/protocols/{protocol_definition_id}/patients` | List patients by compliance status |
| `GET /v1/intelligence/summary` | Intelligence events summary (counts by type, period) |
| `POST /v1/action-definitions` | Register an action definition |
| `GET /v1/action-definitions` | List registered action definitions |
| `GET /v1/action-definitions/{id}` | Retrieve a specific action definition by ID |
| `PUT /v1/action-definitions/{id}` | Update an existing action definition |
| `GET /v1/action-runs` | List action runs |
| `GET /v1/action-runs/{id}` | Retrieve a specific action run by ID |
| `GET /v1/action-runs/{id}/status` | Get current execution status of an action run |
| `POST /v1/action-runs/{id}:cancel` | Cancel an in-progress action run |

> **Note:** Protocol definitions (PlanDefinition) are immutable once published. `PUT` is intentionally not provided for protocol definitions.

##### 4.3.6.3 Response Envelope

**Success (list):**
```json
{
  "data": [],
  "pagination": {
    "limit": 50,
    "next_cursor": "eyJpZCI6MTIzfQ==",
    "has_more": true
  }
}
```

**Success (single resource):**
```json
{ "data": {} }
```

**Error:**
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Missing required field: 'data' must contain a valid payload",
    "details": {
      "field": "data",
      "value": null
    }
  }
}
```

**Example response — `GET /v1/patients/{patient_id}/protocol-tracking/{protocol_instance_id}`:**
```json
{
  "protocol_instance_id": "pi-uuid-67890",
  "patient_id": "ABHA-1234567890",
  "protocol_canonical": "http://openphc.org/fhir/PlanDefinition/anc-high-risk|2.1",
  "enrolled_at": "2026-01-01T00:00:00Z",
  "status": "active",
  "compliance_rate": 0.5,
  "step_instances": [
    {
      "step_instance_id": "si-uuid-001",
      "action_id": "anc-visit-1",
      "state": "completed",
      "due_date": "2026-01-15T00:00:00Z",
      "completed_at": "2026-01-13T10:30:00Z",
      "completed_by": "smartcare-chw",
      "completion_status": "on_time"
    },
    {
      "step_instance_id": "si-uuid-002",
      "action_id": "anc-visit-2",
      "state": "overdue",
      "due_date": "2026-02-26T00:00:00Z",
      "days_overdue": 5
    }
  ]
}
```

---

#### 4.3.7 Adaptors

Adaptors are **not part of CCE core**. An adaptor is a service that bridges between CCE and external systems.

- **System owners** are generally responsible for building, hosting, and maintaining adaptors
- **CCE team** may provide reference adaptors for popular systems (e.g., OpenMRS, DHIS2, Spice)

##### 4.3.7.1 Adaptor Types

| Type | Direction | Aligns With | Purpose |
|---|---|---|---|
| Emitter Adaptor | External System → CCE | Compliance Tracking | Transforms application events into CloudEvents messages and submits to CCE |
| Receiver Adaptor | CCE → External System | Intelligence | Receives intelligence events and translates to application actions |

##### 4.3.7.2 Emitter Adaptors

**Responsibilities:**
- Monitor or receive events from the source system
- Transform source data into a CloudEvents message
- Populate CloudEvents core attributes
- Submit events to CCE via `POST /v1/events`
- Handle errors and retries

> **Key simplification:** Emitter adaptors do not need to understand CCE's compliance protocol model. CCE's trigger-based matching handles routing.

**Shared Infrastructure as Emitter (Example — ABDM):**
```
┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│  RCH Portal │──▶│             │   │             │
├─────────────┤   │  ABDM HIE   │──▶│ ABDM Emitter│──▶ CCE
│  NCD Portal │──▶│   (shared)  │   │   Adaptor   │
├─────────────┤   │             │   │             │
│   Nikshay   │──▶│             │   │             │
└─────────────┘   └─────────────┘   └─────────────┘
```

##### 4.3.7.4 Intelligence Event Delivery

| Mode | How It Works | Best For |
|---|---|---|
| Webhook (Push) | CCE POSTs events to adaptor's registered URL | Simple integrations; always-online systems |
| Topic Subscription (Pull) | Adaptor subscribes to a message topic; pulls events at its own pace | Robust integrations; systems with potential downtime |

##### 4.3.7.5 Adaptor Authentication

Emitter Adaptors authenticate to CCE using standard OAuth tokens. CCE identifies the source system from the CloudEvents `source` attribute in each event.

---

## 5. Error Handling

### 5.1 API & Gateway Layer

| HTTP Status | Error Code | Cause | Handling |
|---|---|---|---|
| 400 | `VALIDATION_ERROR` | Request body fails schema validation | Caller fixes and resubmits |
| 401 | `AUTHENTICATION_FAILED` | Invalid or expired access token | Caller reauthenticates; do not retry |
| 403 | `AUTHORIZATION_FAILED` | Valid token but insufficient scope | Caller requests appropriate scopes; do not retry |
| 404 | `NOT_FOUND` | Resource does not exist | Caller verifies identifier |
| 429 | `RATE_LIMITED` | Rate limit exceeded | Retry after `Retry-After` period |
| 502/503 | `SERVICE_UNAVAILABLE` | Backend service failure | Transient; retry with backoff |

### 5.2 Event Ingestion Layer

| Error | Caller Response | CCE Handling |
|---|---|---|
| CloudEvents schema invalid | `400 VALIDATION_ERROR` | Event rejected |
| Duplicate event (`id` + `source` already exists) | `200` (idempotent acceptance) | No state change |
| Kafka publication failure | `503 SERVICE_UNAVAILABLE` | Event written to dead-letter store; automatically reprocessed when Kafka recovers |

---

## 6. Security

### 6.1 Data Security in Transit

| Communication Path | Requirement |
|---|---|
| External → CCE | HTTPS required, TLS 1.2 minimum (TLS 1.3 recommended) |
| CCE → Adaptors | HTTPS required, TLS 1.2 minimum (TLS 1.3 recommended) |
| Internal (within CCE) | TLS required between components |

- All CCE API endpoints are served over HTTPS. HTTP connections are rejected.
- CCE validates server certificates for all outbound connections.

### 6.2 Inbound Authentication and Authorization

#### 6.2.1 Authentication

- CCE delegates authentication to an external Identity Provider using **OIDC/OAuth 2.0**
- CCE does not manage users or credentials
- Participating systems obtain access tokens from the Identity Provider and include them in API requests (`Authorization: Bearer <token>`)

#### 6.2.2 Authorization

CCE includes built-in authorization using OAuth scopes.

| Scope | Grants Access To |
|---|---|
| `events:write` | Submit events to CCE (`POST /v1/events`) |
| `protocol-definitions:read` | View protocol definitions |
| `protocol-definitions:write` | Create/update/delete protocol definitions |
| `protocol-tracking:read` | View patient compliance tracking data |
| `dashboard:read` | View dashboard and analytics data |
| `action-definitions:read` | View action definitions |
| `action-definitions:write` | Create/update/delete action definitions |
| `action-runs:read` | View action runs and status |
| `action-runs:write` | Cancel action runs |
| `admin` | Full access (all scopes) |

### 6.4 Data Security at Rest

| Measure | Description |
|---|---|
| Encryption at rest | Event store is encrypted using AES-256 or equivalent |
| Retention policies | Configurable TTL per resource type or protocol |
| Access control | Event data accessible only via authorized API calls with appropriate scopes |
| Minimum necessary | Events contain only identifiers and metadata needed for compliance tracking |

### 6.5 Audit Logging

| Event Category | Examples |
|---|---|
| Authentication | Successful/failed login attempts, token validation failures |
| Resource changes | Action definition created/updated/deleted, adaptor registered/updated/deleted |
| Action execution | Action run started, step executed, action completed/failed |
| Adaptor operations | Adaptor operation invoked, success/failure response |
| Authorization | Access denied due to insufficient scope |

---

## 7. Compliance Subsystem Design

The Compliance Subsystem is the set of services responsible for ingesting care events, evaluating them against compliance protocols, persisting compliance state, and surfacing analytics. It is composed of **six services** that communicate through Kafka and REST APIs.

### 7.2 Component Descriptions

#### 7.2.1 Collector Service

| Aspect | Detail |
|---|---|
| Responsibility | Validate event structure and publish to Kafka |
| Input | Pre-authorized care events forwarded by the CCE Gateway Service |
| Output | Events published to Kafka topic(s) |
| Validation | CloudEvents schema validation (required attributes, format), duplicate detection |
| Authentication | Not handled directly — CCE Gateway Service handles this |
| Scalability | Stateless; horizontally scalable |

**Key behaviors:**
- Receives requests only from the CCE Gateway Service (not exposed externally)
- Assigns a `received_at` timestamp and `correlation_id`
- Publishes events to a partitioned Kafka topic (partitioned by `subject` / patient ID)
- Returns acknowledgement once the event is durably written to Kafka
- Dead-letters malformed events for later inspection

#### 7.2.2 Compliance Service

| Aspect | Detail |
|---|---|
| Responsibility | Match incoming events to compliance protocols and steps; track compliance state |
| Input | Events consumed from Kafka |
| Output | Updated protocol instances and step instances in the Compliance DB; intelligence triggers |
| Data Store | Compliance DB — protocol definitions, protocol instances, step instances |
| Processing Model | Consumer-group based Kafka consumption; at-least-once delivery with idempotent writes |

**Compliance DB schema:**

| Entity | Description |
|---|---|
| `plan_definition` | A FHIR PlanDefinition resource. Stored as the canonical protocol definition |
| `protocol_instance` | A specific patient's enrollment in a protocol, pinned to a PlanDefinition version |
| `step_instance` | A specific step occurrence for a patient — tracks status, matched event(s), and timing |
| `deviation` | A recorded deviation from the expected protocol pathway. Created when a step transitions to `overdue` or `missed` |

#### 7.2.3 Scheduler Service

| Aspect | Detail |
|---|---|
| Responsibility | Progress step instances through time-based state transitions; trigger time-based intelligence rules |
| Data Source | Compliance DB — reads step instances with their due dates, tolerance windows, and current states |
| Output | State transition requests to the Compliance Service; intelligence triggers |
| Processing Model | Periodic polling with configurable interval (e.g., every 5 minutes) |

**Time-based transitions:**

| Transition | Condition | Action |
|---|---|---|
| `pending` → `due` | Current time ≥ step's `due_date` | Update state to `due` |
| `due` → `overdue` | Current time ≥ `due_date` + `tolerance_days` | Update state to `overdue`; create deviation record |
| `overdue` → `missed` | Current time ≥ protocol-defined missed cutoff | Update state to `missed`; create deviation record |

**Time-based intelligence rules:**

| Rule Type | Example | How Scheduler Handles It |
|---|---|---|
| Reminders | "Send reminder 3 days before due" | Scans pending/due steps where `due_date - now ≤ 3 days`; fires intelligence trigger |
| Overdue alerts | "Alert when step is 5+ days overdue" | Scans overdue steps where `days_overdue > threshold`; fires intelligence trigger |
| Escalations | "Escalate to supervisor after 7 days overdue" | Scans overdue steps matching escalation conditions; fires intelligence trigger |

**Key behaviors:**
- Runs on configurable schedule (default: every 5 minutes)
- Idempotent — re-running the same cycle produces no duplicate transitions or intelligence events
- Tracks a high-water mark to avoid reprocessing; recovers gracefully from missed cycles
- Stateless between runs — all state is in the Compliance DB

#### 7.2.4 Analytics Service

Serves compliance analytics data — protocol adherence rates, deviation trends, facility-level summaries, and patient-level compliance timelines.

**Key capabilities:**
- Protocol adherence — % of patients completing all steps within defined windows
- Deviation analysis — Most common deviations, average delay, deviation trends over time
- Facility-level dashboards — Compliance summary per facility or geographic region
- Patient timeline — Full compliance timeline for a specific patient across all enrolled protocols
- Export — CSV, JSON for external analysis

| Phase | Data Source | Trade-off |
|---|---|---|
| Phase 1 | Compliance DB (direct) | Simpler deployment; acceptable at low-to-moderate scale |
| Phase 2 | Dedicated Analytics DB | Query performance at scale; eventual consistency with Compliance DB |

#### 7.2.5 Analytics UI Service

| Aspect | Detail |
|---|---|
| Responsibility | Render compliance dashboards and reports for end users |
| Backend | All API calls go through the CCE Gateway Service |
| Authentication | Obtains OAuth access tokens from the Identity Provider |
| Users | Program managers, district health officers, facility administrators |

**Key views:** Overview dashboard, Protocol drill-down, Facility view, Patient view, Alerts and deviations.

#### 7.2.6 CCE Gateway Service

The **single entry point** for all inbound traffic into the Compliance Subsystem.

| Aspect | Detail |
|---|---|
| Role | API gateway — single entry point for all inbound requests |
| Responsibility | Authenticate callers, authorize operations, and route requests to backend services |
| Identity Provider | Delegates token validation to the configured OAuth / OIDC provider |
| Authorization Model | Claims-based — extracts roles, scopes, and contextual claims from the token |

**Request routing:**
```
POST /v1/events                                  → Collector Service
/v1/protocol-definitions/*                       → Compliance Service
/v1/protocol-instances/*                         → Compliance Service
/v1/patients/*/protocol-tracking/*               → Compliance Service
/v1/patients/*/events                            → Compliance Service
/v1/protocols/*/compliance-summary               → Analytics Service
/v1/facilities/*/compliance-summary              → Analytics Service
/v1/protocols/*/patients                         → Analytics Service
/v1/intelligence/summary                         → Analytics Service
/v1/action-definitions/*                         → Compliance Service (provisional)
/v1/action-runs/*                                → Compliance Service (provisional)
```

### 7.3 Data Flow Summary

| Step | From | To | Mechanism | Description |
|---|---|---|---|---|
| 1 | Emitter Adaptors / Analytics UI | CCE Gateway Service | HTTP/REST | All inbound requests enter through the CCE Gateway Service |
| 2 | CCE Gateway Service | Identity Provider | HTTP/REST (OIDC) | Token validation |
| 3 | CCE Gateway Service | Collector Service | HTTP/REST (internal) | Authorized event submissions forwarded to Collector |
| 4 | CCE Gateway Service | Analytics Service | HTTP/REST (internal) | Authorized analytics queries forwarded to Analytics Service |
| 5 | Collector Service | Kafka | Kafka Producer | Validated events published to Kafka |
| 6 | Kafka | Compliance Service | Kafka Consumer | Events consumed for compliance evaluation |
| 7 | Compliance Service | Compliance DB | Database writes | Protocol/step instances created or updated |
| 8 | Scheduler Service | Compliance DB | Database reads | Scans step instances for time-based transitions |
| 9 | Scheduler Service | Compliance Service | Internal call | Sends state transition requests and time-based intelligence triggers |
| 10 | Analytics Service | Compliance DB | Database reads | Compliance data queried for analytics |

### 7.4 Deployment Considerations

- **CCE Gateway Service** — Deploy behind a load balancer with TLS termination. Stateless with short-lived token cache. Deploy multiple instances for high availability.
- **Collector Service** — Internal service. Stateless; horizontally scalable.
- **Compliance Service** — Internal service. Stateless consumers in a Kafka consumer group; scale by adding consumers (up to number of partitions).
- **Scheduler Service** — Internal service. Typically a single instance with leader election to avoid duplicate processing. Resilient to missed cycles (idempotent, catches up on next run).
- **Analytics Service** — Internal service. Stateless; horizontally scalable; may benefit from caching (e.g., Redis) for frequently requested aggregations.
- **Analytics UI Service** — Static front-end assets served via CDN or web server.
- **Kafka** — Managed Kafka cluster with partitioning by `subject` / patient ID and replication for durability.
- **Compliance DB** — Relational database (e.g., PostgreSQL) with appropriate indexing on `patient_id`, `protocol_instance_id`, and temporal fields.
- **Network topology** — CCE Gateway Service is the only service exposed on the public/external network. All backend services run on an internal network.

---

## 8. Open Issues

### 8.1 Brownfield Deployment — Existing Patient Enrollments

**Problem:**

CCE creates Protocol Instances only when it receives an enrollment event. When CCE is introduced into a source system that is already running, many patients will already be enrolled in care programs — their enrollment events occurred before CCE existed.

When these patients' ongoing clinical events arrive (e.g., ANC Visit 4 for a patient enrolled 3 months ago), CCE has no Protocol Instance for them. The event falls into zero-match handling — it is logged but no compliance tracking occurs.

**Impact:**

Until this is addressed, only new program enrollments that occur after CCE deployment will be trackable. Patients already enrolled at the time of CCE onboarding will not have compliance tracking, intelligence generation, or analytics coverage — regardless of how many clinical events their source systems emit.

> **Decision needed before first production deployment:** Approach will depend on the source system's ability to replay events, and the acceptable complexity for Emitter Adaptors.

---

*CCE Solution Design v0.3 — Draft*
