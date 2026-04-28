-- =============================================================================
-- CCE DEMO DATA — demo_data.sql
-- =============================================================================
-- Purpose  : Populate realistic backdated demo records for insights-ui screens
-- Sources  : ebuzima-direct | ebuzima
-- Patients : 12 patients across 4 facilities in Zambia
-- Protocols: ANC High-Risk | EPI Child 0-5 | Hypertension Management
-- Date range: ~180 days backdated from execution date (NOW())
-- Idempotent: All INSERTs use ON CONFLICT DO NOTHING (safe to re-run)
-- =============================================================================
-- MENU COVERAGE
--   Dashboard        → event counts, protocol enrollments, deviation KPIs
--   Compliance       → step completion rates, on-time vs late vs missed
--   Protocol Analytics → step-analytics, completion funnel, enrollment trends
--   Patient List     → compliance-status, at-risk hotspots, repeat deviations
--   Patient Detail   → timeline, protocol tracking, events, deviations
--   Deviations       → OVERDUE + MISSED deviations, trends, resolution rate
--   Event Volume     → by resource type, facility, practitioner, source
--   Source Comparison → ebuzima-direct vs ebuzima overlap/unique
--   Facility Analytics → ranking by compliance rate / deviation count

-- =============================================================================
-- CLEANUP — remove existing data (respecting FK order) for clean re-insert
-- =============================================================================
\echo '--- Cleaning existing data ---'
DELETE FROM audit_log;
DELETE FROM deviation;
DELETE FROM step_instance;
DELETE FROM event_log;
DELETE FROM protocol_instance;
DELETE FROM trigger_index;
DELETE FROM protocol_definition;
DELETE FROM inbound_event;
--   Ingestion Pipeline → funnel, rejections, source quality, pipeline loss
--   Exports          → compliance report generation
-- =============================================================================
-- EVENTS-BY-SOURCE MISMATCH SCENARIOS (for demo highlight):
--   MS-1 : Patients P07-P09 send via ebuzima ONLY (direct gap)
--   MS-2 : Patient P10 — Encounter ACCEPTED from direct, REJECTED from openhim
--   MS-3 : Patient P11 — same cloudevents_id sent by both sources → DUPLICATE
--   MS-4 : Patient P12 — Observation present in direct, ZERO_MATCH in openhim
--   MS-5 : ebuzima sends INVALID_FHIR for Immunization (rejected)
-- =============================================================================

-- Execution order: run Section 1 against cce_collector DB,
--                  run Section 2 against cce_compliance DB.

-- =============================================================================
-- SECTION 1 : COLLECTOR SERVICE  →  cce_collector database
-- =============================================================================

\echo '--- [1/1] Inserting inbound_event records ---'

INSERT INTO inbound_event (
    id, cloudevents_id, source, type, spec_version, subject,
    event_time, data_content_type, facility_id, correlation_id,
    source_event_id, raw_payload, status, rejection_reason,
    error_details, received_at
) VALUES

-- ─────────────────────────────────────────────────────────────────────────────
-- FACILITY 0001 | ebuzima-direct | P01-P03 | ANC encounters (ACCEPTED)
-- ─────────────────────────────────────────────────────────────────────────────
('1e000001-0000-0000-0000-000000000001','evt-eb-d-0001','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0001-1001',
 NOW()-INTERVAL '175 days','application/fhir+json','FAC-0001',
 'corr-d-000001','src-d-1001',
 '{"resourceType":"Encounter","id":"enc-p01-v1","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1001"},
   "period":{"start":"2025-10-08T08:30:00Z","end":"2025-10-08T09:15:00Z"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '175 days'),

('1e000002-0000-0000-0000-000000000001','evt-eb-d-0002','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0001-1001',
 NOW()-INTERVAL '133 days','application/fhir+json','FAC-0001',
 'corr-d-000002','src-d-1002',
 '{"resourceType":"Encounter","id":"enc-p01-v2","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1001"},
   "period":{"start":"2025-11-19T09:00:00Z","end":"2025-11-19T09:45:00Z"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '133 days'),

('1e000003-0000-0000-0000-000000000001','evt-eb-d-0003','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0001-1001',
 NOW()-INTERVAL '91 days','application/fhir+json','FAC-0001',
 'corr-d-000003','src-d-1003',
 '{"resourceType":"Encounter","id":"enc-p01-v3","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1001"},
   "period":{"start":"2025-12-31T08:00:00Z","end":"2025-12-31T08:50:00Z"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '91 days'),

-- P01 - Observation (blood pressure) via direct
('1e000004-0000-0000-0000-000000000001','evt-eb-d-0004','ebuzima-direct',
 'org.openphc.cce.observation','1.0','260225-0001-1001',
 NOW()-INTERVAL '91 days','application/fhir+json','FAC-0001',
 'corr-d-000004','src-d-1004',
 '{"resourceType":"Observation","id":"obs-p01-bp3","status":"final",
   "code":{"coding":[{"system":"http://loinc.org","code":"55284-4","display":"Blood pressure"}]},
   "subject":{"reference":"Patient/260225-0001-1001"},
   "valueQuantity":{"value":138,"unit":"mmHg","system":"http://unitsofmeasure.org","code":"mm[Hg]"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '91 days'),

-- P02 - ANC encounters via direct
('1e000005-0000-0000-0000-000000000001','evt-eb-d-0005','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0001-1002',
 NOW()-INTERVAL '168 days','application/fhir+json','FAC-0001',
 'corr-d-000005','src-d-2001',
 '{"resourceType":"Encounter","id":"enc-p02-v1","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1002"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '168 days'),

('1e000006-0000-0000-0000-000000000001','evt-eb-d-0006','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0001-1002',
 NOW()-INTERVAL '126 days','application/fhir+json','FAC-0001',
 'corr-d-000006','src-d-2002',
 '{"resourceType":"Encounter","id":"enc-p02-v2","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1002"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '126 days'),

-- P02 - LATE ANC visit (missed window, will show deviation)
('1e000007-0000-0000-0000-000000000001','evt-eb-d-0007','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0001-1002',
 NOW()-INTERVAL '62 days','application/fhir+json','FAC-0001',
 'corr-d-000007','src-d-2003',
 '{"resourceType":"Encounter","id":"enc-p02-v3","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1002"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '62 days'),

-- P03 - ANC via direct
('1e000008-0000-0000-0000-000000000001','evt-eb-d-0008','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0001-1003',
 NOW()-INTERVAL '155 days','application/fhir+json','FAC-0001',
 'corr-d-000008','src-d-3001',
 '{"resourceType":"Encounter","id":"enc-p03-v1","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1003"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '155 days'),

-- ─────────────────────────────────────────────────────────────────────────────
-- FACILITY 0002 | ebuzima | P01-P06 | Parallel source for same patients
-- ─────────────────────────────────────────────────────────────────────────────
('1e000009-0000-0000-0000-000000000001','evt-eb-oh-0001','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0001-1001',
 NOW()-INTERVAL '175 days','application/fhir+json','FAC-0002',
 'corr-oh-000001','src-oh-1001',
 '{"resourceType":"Encounter","id":"enc-p01-v1-oh","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1001"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '175 days'),

-- P01 - openhim ANC visit 2 (NOT sent via direct — mismatch MS-1 partial)
('1e000010-0000-0000-0000-000000000001','evt-eb-oh-0002','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0001-1001',
 NOW()-INTERVAL '49 days','application/fhir+json','FAC-0002',
 'corr-oh-000002','src-oh-1002',
 '{"resourceType":"Encounter","id":"enc-p01-v4-oh","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1001"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '49 days'),

-- P02 openhim
('1e000011-0000-0000-0000-000000000001','evt-eb-oh-0003','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0001-1002',
 NOW()-INTERVAL '168 days','application/fhir+json','FAC-0002',
 'corr-oh-000003','src-oh-2001',
 '{"resourceType":"Encounter","id":"enc-p02-v1-oh","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1002"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '168 days'),

-- P04-P06 - EPI (Immunization) via openhim
('1e000012-0000-0000-0000-000000000001','evt-eb-oh-0004','ebuzima',
 'org.openphc.cce.immunization','1.0','260225-0002-2001',
 NOW()-INTERVAL '160 days','application/fhir+json','FAC-0002',
 'corr-oh-000004','src-oh-4001',
 '{"resourceType":"Immunization","id":"imm-p04-bcg","status":"completed",
   "vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"19","display":"BCG"}]},
   "patient":{"reference":"Patient/260225-0002-2001"},
   "occurrenceDateTime":"2025-10-23T10:00:00Z"}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '160 days'),

('1e000013-0000-0000-0000-000000000001','evt-eb-oh-0005','ebuzima',
 'org.openphc.cce.immunization','1.0','260225-0002-2001',
 NOW()-INTERVAL '118 days','application/fhir+json','FAC-0002',
 'corr-oh-000005','src-oh-4002',
 '{"resourceType":"Immunization","id":"imm-p04-opv0","status":"completed",
   "vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"02","display":"OPV"}]},
   "patient":{"reference":"Patient/260225-0002-2001"},
   "occurrenceDateTime":"2025-12-05T10:00:00Z"}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '118 days'),

('1e000014-0000-0000-0000-000000000001','evt-eb-oh-0006','ebuzima',
 'org.openphc.cce.immunization','1.0','260225-0002-2001',
 NOW()-INTERVAL '76 days','application/fhir+json','FAC-0002',
 'corr-oh-000006','src-oh-4003',
 '{"resourceType":"Immunization","id":"imm-p04-penta1","status":"completed",
   "vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"132","display":"Pentavalent"}]},
   "patient":{"reference":"Patient/260225-0002-2001"},
   "occurrenceDateTime":"2026-01-16T11:00:00Z"}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '76 days'),

('1e000015-0000-0000-0000-000000000001','evt-eb-oh-0007','ebuzima',
 'org.openphc.cce.immunization','1.0','260225-0002-2002',
 NOW()-INTERVAL '150 days','application/fhir+json','FAC-0002',
 'corr-oh-000007','src-oh-5001',
 '{"resourceType":"Immunization","id":"imm-p05-bcg","status":"completed",
   "vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"19","display":"BCG"}]},
   "patient":{"reference":"Patient/260225-0002-2002"},
   "occurrenceDateTime":"2025-11-02T09:30:00Z"}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '150 days'),

-- P06 - HTN encounter via openhim
('1e000016-0000-0000-0000-000000000001','evt-eb-oh-0008','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0003-3001',
 NOW()-INTERVAL '140 days','application/fhir+json','FAC-0003',
 'corr-oh-000008','src-oh-6001',
 '{"resourceType":"Encounter","id":"enc-p06-htn1","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"htn-followup"}]}],
   "subject":{"reference":"Patient/260225-0003-3001"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '140 days'),

('1e000017-0000-0000-0000-000000000001','evt-eb-oh-0009','ebuzima',
 'org.openphc.cce.observation','1.0','260225-0003-3001',
 NOW()-INTERVAL '140 days','application/fhir+json','FAC-0003',
 'corr-oh-000009','src-oh-6002',
 '{"resourceType":"Observation","id":"obs-p06-bp1","status":"final",
   "code":{"coding":[{"system":"http://loinc.org","code":"55284-4","display":"Blood pressure"}]},
   "subject":{"reference":"Patient/260225-0003-3001"},
   "valueQuantity":{"value":162,"unit":"mmHg"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '140 days'),

('1e000018-0000-0000-0000-000000000001','evt-eb-oh-0010','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0003-3001',
 NOW()-INTERVAL '98 days','application/fhir+json','FAC-0003',
 'corr-oh-000010','src-oh-6003',
 '{"resourceType":"Encounter","id":"enc-p06-htn2","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"htn-followup"}]}],
   "subject":{"reference":"Patient/260225-0003-3001"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '98 days'),

-- ─────────────────────────────────────────────────────────────────────────────
-- MS-1: P07-P09 — ONLY ebuzima sends (no direct equivalent)
--       Showcases gap in ebuzima-direct coverage
-- ─────────────────────────────────────────────────────────────────────────────
('1e000019-0000-0000-0000-000000000001','evt-eb-oh-0011','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0003-3002',
 NOW()-INTERVAL '145 days','application/fhir+json','FAC-0003',
 'corr-oh-000011','src-oh-7001',
 '{"resourceType":"Encounter","id":"enc-p07-anc1","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0003-3002"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '145 days'),

('1e000020-0000-0000-0000-000000000001','evt-eb-oh-0012','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0003-3002',
 NOW()-INTERVAL '103 days','application/fhir+json','FAC-0003',
 'corr-oh-000012','src-oh-7002',
 '{"resourceType":"Encounter","id":"enc-p07-anc2","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0003-3002"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '103 days'),

('1e000021-0000-0000-0000-000000000001','evt-eb-oh-0013','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0003-3003',
 NOW()-INTERVAL '138 days','application/fhir+json','FAC-0003',
 'corr-oh-000013','src-oh-8001',
 '{"resourceType":"Encounter","id":"enc-p08-anc1","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0003-3003"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '138 days'),

('1e000022-0000-0000-0000-000000000001','evt-eb-oh-0014','ebuzima',
 'org.openphc.cce.immunization','1.0','260225-0004-4001',
 NOW()-INTERVAL '130 days','application/fhir+json','FAC-0004',
 'corr-oh-000014','src-oh-9001',
 '{"resourceType":"Immunization","id":"imm-p09-bcg","status":"completed",
   "vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"19","display":"BCG"}]},
   "patient":{"reference":"Patient/260225-0004-4001"},
   "occurrenceDateTime":"2025-11-22T08:00:00Z"}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '130 days'),

-- ─────────────────────────────────────────────────────────────────────────────
-- MS-2: P10 — ACCEPTED from direct, same event REJECTED from openhim
--       (INVALID_FHIR — missing required status field in openhim payload)
-- ─────────────────────────────────────────────────────────────────────────────
('1e000023-0000-0000-0000-000000000001','evt-eb-d-0020','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0004-4002',
 NOW()-INTERVAL '120 days','application/fhir+json','FAC-0004',
 'corr-d-020001','src-d-10001',
 '{"resourceType":"Encounter","id":"enc-p10-anc1","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0004-4002"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '120 days'),

('1e000024-0000-0000-0000-000000000001','evt-eb-oh-0020','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0004-4002',
 NOW()-INTERVAL '120 days','application/fhir+json','FAC-0004',
 'corr-oh-020001','src-oh-10001',
 '{"resourceType":"Encounter","id":"enc-p10-anc1-oh","type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],"subject":{"reference":"Patient/260225-0004-4002"}}'::jsonb,
 'REJECTED','INVALID_FHIR',
 'FHIR validation error: Encounter.status is required and must not be null. Path: Encounter.status',
 NOW()-INTERVAL '120 days'),

-- P10 later visit - direct only
('1e000025-0000-0000-0000-000000000001','evt-eb-d-0021','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0004-4002',
 NOW()-INTERVAL '78 days','application/fhir+json','FAC-0004',
 'corr-d-020002','src-d-10002',
 '{"resourceType":"Encounter","id":"enc-p10-anc2","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0004-4002"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '78 days'),

-- ─────────────────────────────────────────────────────────────────────────────
-- MS-3: P11 — Same cloudevents_id from both sources → one is DUPLICATE
--       Demonstrates deduplication by (cloudevents_id, source) key
-- ─────────────────────────────────────────────────────────────────────────────
('1e000026-0000-0000-0000-000000000001','evt-shared-0001','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0004-4003',
 NOW()-INTERVAL '110 days','application/fhir+json','FAC-0004',
 'corr-d-030001','src-d-11001',
 '{"resourceType":"Encounter","id":"enc-p11-anc1","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0004-4003"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '110 days'),

-- openhim re-sends same event (different source → allowed, NOT duplicate)
('1e000027-0000-0000-0000-000000000001','evt-shared-0001','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0004-4003',
 NOW()-INTERVAL '110 days','application/fhir+json','FAC-0004',
 'corr-oh-030001','src-oh-11001',
 '{"resourceType":"Encounter","id":"enc-p11-anc1","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0004-4003"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '110 days'),

-- openhim retries same event → DUPLICATE
('1e000028-0000-0000-0000-000000000001','evt-shared-0001-retry','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0004-4003',
 NOW()-INTERVAL '109 days','application/fhir+json','FAC-0004',
 'corr-oh-030002','src-oh-11001',
 '{"resourceType":"Encounter","id":"enc-p11-anc1","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0004-4003"}}'::jsonb,
 'DUPLICATE',NULL,NULL, NOW()-INTERVAL '109 days'),

-- P11 second encounter — direct only (openhim gap)
('1e000029-0000-0000-0000-000000000001','evt-eb-d-0030','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0004-4003',
 NOW()-INTERVAL '68 days','application/fhir+json','FAC-0004',
 'corr-d-030003','src-d-11002',
 '{"resourceType":"Encounter","id":"enc-p11-anc2","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0004-4003"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '68 days'),

-- ─────────────────────────────────────────────────────────────────────────────
-- MS-4: P12 — Observation via direct (ACCEPTED), openhim sends MISSING_SUBJECT
-- ─────────────────────────────────────────────────────────────────────────────
('1e000030-0000-0000-0000-000000000001','evt-eb-d-0040','ebuzima-direct',
 'org.openphc.cce.observation','1.0','260225-0004-4004',
 NOW()-INTERVAL '95 days','application/fhir+json','FAC-0004',
 'corr-d-040001','src-d-12001',
 '{"resourceType":"Observation","id":"obs-p12-bp1","status":"final",
   "code":{"coding":[{"system":"http://loinc.org","code":"55284-4"}]},
   "subject":{"reference":"Patient/260225-0004-4004"},
   "valueQuantity":{"value":145,"unit":"mmHg"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '95 days'),

('1e000031-0000-0000-0000-000000000001','evt-eb-oh-0040','ebuzima',
 'org.openphc.cce.observation','1.0',NULL,
 NOW()-INTERVAL '95 days','application/fhir+json','FAC-0004',
 'corr-oh-040001','src-oh-12001',
 '{"resourceType":"Observation","id":"obs-p12-bp1-oh","status":"final",
   "code":{"coding":[{"system":"http://loinc.org","code":"55284-4"}]},
   "valueQuantity":{"value":145,"unit":"mmHg"}}'::jsonb,
 'REJECTED','MISSING_SUBJECT',
 'subject field missing; required for patient routing',
 NOW()-INTERVAL '95 days'),

-- ─────────────────────────────────────────────────────────────────────────────
-- MS-5: ebuzima sends INVALID_FHIR for Immunization batch
-- ─────────────────────────────────────────────────────────────────────────────
('1e000032-0000-0000-0000-000000000001','evt-eb-oh-0050','ebuzima',
 'org.openphc.cce.immunization','1.0','260225-0002-2003',
 NOW()-INTERVAL '85 days','application/fhir+json','FAC-0002',
 'corr-oh-050001','src-oh-13001',
 '{"resourceType":"Immunization","id":"imm-p06-penta2","vaccineCode":{},"patient":{"reference":"Patient/260225-0002-2003"}}'::jsonb,
 'REJECTED','INVALID_FHIR',
 'FHIR validation: Immunization.status required. Immunization.vaccineCode.coding must not be empty.',
 NOW()-INTERVAL '85 days'),

-- ─────────────────────────────────────────────────────────────────────────────
-- Additional ACCEPTED events to build volume for dashboard metrics
-- ─────────────────────────────────────────────────────────────────────────────
('1e000033-0000-0000-0000-000000000001','evt-eb-d-0050','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0003-3001',
 NOW()-INTERVAL '56 days','application/fhir+json','FAC-0003',
 'corr-d-056001','src-d-6004',
 '{"resourceType":"Encounter","id":"enc-p06-htn3","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"htn-followup"}]}],
   "subject":{"reference":"Patient/260225-0003-3001"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '56 days'),

('1e000034-0000-0000-0000-000000000001','evt-eb-d-0051','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0003-3001',
 NOW()-INTERVAL '14 days','application/fhir+json','FAC-0003',
 'corr-d-014001','src-d-6005',
 '{"resourceType":"Encounter","id":"enc-p06-htn4","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"htn-followup"}]}],
   "subject":{"reference":"Patient/260225-0003-3001"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '14 days'),

('1e000035-0000-0000-0000-000000000001','evt-eb-oh-0060','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0003-3002',
 NOW()-INTERVAL '61 days','application/fhir+json','FAC-0003',
 'corr-oh-061001','src-oh-7003',
 '{"resourceType":"Encounter","id":"enc-p07-anc3","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0003-3002"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '61 days'),

('1e000036-0000-0000-0000-000000000001','evt-eb-oh-0061','ebuzima',
 'org.openphc.cce.immunization','1.0','260225-0002-2001',
 NOW()-INTERVAL '34 days','application/fhir+json','FAC-0002',
 'corr-oh-034001','src-oh-4004',
 '{"resourceType":"Immunization","id":"imm-p04-penta2","status":"completed",
   "vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"132","display":"Pentavalent"}]},
   "patient":{"reference":"Patient/260225-0002-2001"},
   "occurrenceDateTime":"2026-02-26T10:00:00Z"}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '34 days'),

('1e000037-0000-0000-0000-000000000001','evt-eb-oh-0062','ebuzima',
 'org.openphc.cce.immunization','1.0','260225-0002-2002',
 NOW()-INTERVAL '108 days','application/fhir+json','FAC-0002',
 'corr-oh-108001','src-oh-5002',
 '{"resourceType":"Immunization","id":"imm-p05-opv0","status":"completed",
   "vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"02","display":"OPV"}]},
   "patient":{"reference":"Patient/260225-0002-2002"},
   "occurrenceDateTime":"2025-12-14T09:00:00Z"}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '108 days'),

-- INVALID_ENVELOPE — missing type
('1e000038-0000-0000-0000-000000000001','evt-eb-d-0099','ebuzima-direct',
 '','1.0','260225-0001-1001',
 NOW()-INTERVAL '30 days','application/fhir+json','FAC-0001',
 'corr-d-099001',NULL,
 '{"resourceType":"Encounter","id":"enc-bad-type","status":"finished"}'::jsonb,
 'REJECTED','INVALID_ENVELOPE',
 'CloudEvents validation: type field is required and must not be empty',
 NOW()-INTERVAL '30 days'),

-- UNSUPPORTED_CONTENT_TYPE
('1e000039-0000-0000-0000-000000000001','evt-eb-oh-0099','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0001-1003',
 NOW()-INTERVAL '22 days','application/xml','FAC-0001',
 'corr-oh-099001',NULL,
 '{"raw":"<Encounter xmlns=\"http://hl7.org/fhir\"><status value=\"finished\"/></Encounter>"}'::jsonb,
 'REJECTED','UNSUPPORTED_CONTENT_TYPE',
 'datacontenttype ''application/xml'' is not supported. Must be application/fhir+json or application/json',
 NOW()-INTERVAL '22 days'),

-- Recent events — last 7 days (for "today / this week" dashboard tiles)
('1e000040-0000-0000-0000-000000000001','evt-eb-d-1001','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0001-1002',
 NOW()-INTERVAL '5 days','application/fhir+json','FAC-0001',
 'corr-d-1001','src-d-2004',
 '{"resourceType":"Encounter","id":"enc-p02-v4","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1002"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '5 days'),

('1e000041-0000-0000-0000-000000000001','evt-eb-oh-1001','ebuzima',
 'org.openphc.cce.immunization','1.0','260225-0004-4001',
 NOW()-INTERVAL '3 days','application/fhir+json','FAC-0004',
 'corr-oh-1001','src-oh-9002',
 '{"resourceType":"Immunization","id":"imm-p09-opv0","status":"completed",
   "vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"02","display":"OPV"}]},
   "patient":{"reference":"Patient/260225-0004-4001"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '3 days'),

('1e000042-0000-0000-0000-000000000001','evt-eb-d-1002','ebuzima-direct',
 'org.openphc.cce.observation','1.0','260225-0003-3001',
 NOW()-INTERVAL '2 days','application/fhir+json','FAC-0003',
 'corr-d-1002','src-d-6006',
 '{"resourceType":"Observation","id":"obs-p06-bp4","status":"final",
   "code":{"coding":[{"system":"http://loinc.org","code":"55284-4"}]},
   "subject":{"reference":"Patient/260225-0003-3001"},
   "valueQuantity":{"value":128,"unit":"mmHg"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '2 days')
ON CONFLICT DO NOTHING;


-- =============================================================================
-- SOURCE COMPARISON PAIRED EVENTS
-- =============================================================================
-- Both sources deliver the same clinical events on most days (MATCH).
-- On 3 days there are intentional gaps (1-2 events unique to one source)
-- to showcase data delivery consistency monitoring.
--
-- MATCHING days: Mar 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 25, 27, 30
-- MISMATCH days:
--   Mar 16 — extra Encounter from ebuzima-direct only (openhim gap)
--   Mar 24 — existing direct Encounter has no openhim companion
--   Mar 29 — existing openhim Immunization has no direct companion
-- =============================================================================

\echo '--- [1/2] Inserting source comparison paired events ---'

-- Mar 4: P01 encounter — BOTH MATCH
INSERT INTO inbound_event (id, cloudevents_id, source, type, spec_version, subject,
  event_time, data_content_type, facility_id, correlation_id, raw_payload, status, received_at)
VALUES
('2e000001-0000-0000-0000-000000000001','evt-sc-d-001','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0001-1001',
 NOW()-INTERVAL '28 days','application/fhir+json','FAC-0001','corr-sc-001',
 '{"resourceType":"Encounter","id":"enc-sc-001","status":"finished","subject":{"reference":"Patient/260225-0001-1001"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '28 days'),
('2e000001-0000-0000-0000-000000000002','evt-sc-oh-001','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0001-1001',
 NOW()-INTERVAL '28 days' + INTERVAL '3 seconds','application/fhir+json','FAC-0001','corr-sc-001',
 '{"resourceType":"Encounter","id":"enc-sc-001","status":"finished","subject":{"reference":"Patient/260225-0001-1001"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '28 days' + INTERVAL '5 seconds')
ON CONFLICT DO NOTHING;

-- Mar 6: P04 immunization — BOTH MATCH
INSERT INTO inbound_event (id, cloudevents_id, source, type, spec_version, subject,
  event_time, data_content_type, facility_id, correlation_id, raw_payload, status, received_at)
VALUES
('2e000002-0000-0000-0000-000000000001','evt-sc-d-002','ebuzima-direct',
 'org.openphc.cce.immunization','1.0','260225-0002-2001',
 NOW()-INTERVAL '26 days','application/fhir+json','FAC-0002','corr-sc-002',
 '{"resourceType":"Immunization","id":"imm-sc-002","status":"completed","patient":{"reference":"Patient/260225-0002-2001"},"vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"132"}]}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '26 days'),
('2e000002-0000-0000-0000-000000000002','evt-sc-oh-002','ebuzima',
 'org.openphc.cce.immunization','1.0','260225-0002-2001',
 NOW()-INTERVAL '26 days' + INTERVAL '2 seconds','application/fhir+json','FAC-0002','corr-sc-002',
 '{"resourceType":"Immunization","id":"imm-sc-002","status":"completed","patient":{"reference":"Patient/260225-0002-2001"},"vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"132"}]}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '26 days' + INTERVAL '4 seconds')
ON CONFLICT DO NOTHING;

-- Mar 8: P06 encounter — BOTH MATCH
INSERT INTO inbound_event (id, cloudevents_id, source, type, spec_version, subject,
  event_time, data_content_type, facility_id, correlation_id, raw_payload, status, received_at)
VALUES
('2e000003-0000-0000-0000-000000000001','evt-sc-d-003','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0003-3001',
 NOW()-INTERVAL '24 days','application/fhir+json','FAC-0003','corr-sc-003',
 '{"resourceType":"Encounter","id":"enc-sc-003","status":"finished","subject":{"reference":"Patient/260225-0003-3001"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '24 days'),
('2e000003-0000-0000-0000-000000000002','evt-sc-oh-003','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0003-3001',
 NOW()-INTERVAL '24 days' + INTERVAL '4 seconds','application/fhir+json','FAC-0003','corr-sc-003',
 '{"resourceType":"Encounter","id":"enc-sc-003","status":"finished","subject":{"reference":"Patient/260225-0003-3001"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '24 days' + INTERVAL '6 seconds')
ON CONFLICT DO NOTHING;

-- Mar 10: P02 encounter — BOTH MATCH
INSERT INTO inbound_event (id, cloudevents_id, source, type, spec_version, subject,
  event_time, data_content_type, facility_id, correlation_id, raw_payload, status, received_at)
VALUES
('2e000004-0000-0000-0000-000000000001','evt-sc-d-004','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0001-1002',
 NOW()-INTERVAL '22 days','application/fhir+json','FAC-0001','corr-sc-004',
 '{"resourceType":"Encounter","id":"enc-sc-004","status":"finished","subject":{"reference":"Patient/260225-0001-1002"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '22 days'),
('2e000004-0000-0000-0000-000000000002','evt-sc-oh-004','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0001-1002',
 NOW()-INTERVAL '22 days' + INTERVAL '1 second','application/fhir+json','FAC-0001','corr-sc-004',
 '{"resourceType":"Encounter","id":"enc-sc-004","status":"finished","subject":{"reference":"Patient/260225-0001-1002"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '22 days' + INTERVAL '3 seconds')
ON CONFLICT DO NOTHING;

-- Mar 12: P07 encounter — BOTH MATCH
INSERT INTO inbound_event (id, cloudevents_id, source, type, spec_version, subject,
  event_time, data_content_type, facility_id, correlation_id, raw_payload, status, received_at)
VALUES
('2e000005-0000-0000-0000-000000000001','evt-sc-d-005','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0003-3002',
 NOW()-INTERVAL '20 days','application/fhir+json','FAC-0003','corr-sc-005',
 '{"resourceType":"Encounter","id":"enc-sc-005","status":"finished","subject":{"reference":"Patient/260225-0003-3002"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '20 days'),
('2e000005-0000-0000-0000-000000000002','evt-sc-oh-005','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0003-3002',
 NOW()-INTERVAL '20 days' + INTERVAL '2 seconds','application/fhir+json','FAC-0003','corr-sc-005',
 '{"resourceType":"Encounter","id":"enc-sc-005","status":"finished","subject":{"reference":"Patient/260225-0003-3002"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '20 days' + INTERVAL '4 seconds')
ON CONFLICT DO NOTHING;

-- Mar 14: P09 immunization — BOTH MATCH
INSERT INTO inbound_event (id, cloudevents_id, source, type, spec_version, subject,
  event_time, data_content_type, facility_id, correlation_id, raw_payload, status, received_at)
VALUES
('2e000006-0000-0000-0000-000000000001','evt-sc-d-006','ebuzima-direct',
 'org.openphc.cce.immunization','1.0','260225-0004-4001',
 NOW()-INTERVAL '18 days','application/fhir+json','FAC-0004','corr-sc-006',
 '{"resourceType":"Immunization","id":"imm-sc-006","status":"completed","patient":{"reference":"Patient/260225-0004-4001"},"vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"19"}]}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '18 days'),
('2e000006-0000-0000-0000-000000000002','evt-sc-oh-006','ebuzima',
 'org.openphc.cce.immunization','1.0','260225-0004-4001',
 NOW()-INTERVAL '18 days' + INTERVAL '3 seconds','application/fhir+json','FAC-0004','corr-sc-006',
 '{"resourceType":"Immunization","id":"imm-sc-006","status":"completed","patient":{"reference":"Patient/260225-0004-4001"},"vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"19"}]}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '18 days' + INTERVAL '5 seconds')
ON CONFLICT DO NOTHING;

-- Mar 16: P01 observation BOTH MATCH + P02 encounter DIRECT ONLY (openhim gap)
INSERT INTO inbound_event (id, cloudevents_id, source, type, spec_version, subject,
  event_time, data_content_type, facility_id, correlation_id, raw_payload, status, received_at)
VALUES
('2e000007-0000-0000-0000-000000000001','evt-sc-d-007','ebuzima-direct',
 'org.openphc.cce.observation','1.0','260225-0001-1001',
 NOW()-INTERVAL '16 days','application/fhir+json','FAC-0001','corr-sc-007',
 '{"resourceType":"Observation","id":"obs-sc-007","status":"final","code":{"coding":[{"system":"http://loinc.org","code":"55284-4"}]},"subject":{"reference":"Patient/260225-0001-1001"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '16 days'),
('2e000007-0000-0000-0000-000000000002','evt-sc-oh-007','ebuzima',
 'org.openphc.cce.observation','1.0','260225-0001-1001',
 NOW()-INTERVAL '16 days' + INTERVAL '2 seconds','application/fhir+json','FAC-0001','corr-sc-007',
 '{"resourceType":"Observation","id":"obs-sc-007","status":"final","code":{"coding":[{"system":"http://loinc.org","code":"55284-4"}]},"subject":{"reference":"Patient/260225-0001-1001"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '16 days' + INTERVAL '4 seconds'),
-- DIRECT ONLY — openhim missed this one (delivery gap)
('2e000008-0000-0000-0000-000000000001','evt-sc-d-008','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0001-1002',
 NOW()-INTERVAL '16 days' + INTERVAL '6 hours','application/fhir+json','FAC-0001','corr-sc-008',
 '{"resourceType":"Encounter","id":"enc-sc-008","status":"finished","subject":{"reference":"Patient/260225-0001-1002"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '16 days' + INTERVAL '6 hours')
ON CONFLICT DO NOTHING;

-- Openhim companions for existing direct-only events (creates matches)

-- Mar 18: openhim encounter for P06 (companion to existing direct evt-eb-d-0051)
INSERT INTO inbound_event (id, cloudevents_id, source, type, spec_version, subject,
  event_time, data_content_type, facility_id, correlation_id, raw_payload, status, received_at)
VALUES
('2e000009-0000-0000-0000-000000000001','evt-sc-oh-009','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0003-3001',
 NOW()-INTERVAL '14 days' + INTERVAL '3 seconds','application/fhir+json','FAC-0003','corr-sc-009',
 '{"resourceType":"Encounter","id":"enc-sc-009","status":"finished","subject":{"reference":"Patient/260225-0003-3001"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '14 days' + INTERVAL '5 seconds')
ON CONFLICT DO NOTHING;

-- Mar 20: openhim encounter for P01 (companion to existing direct evt-eb-d-2007)
INSERT INTO inbound_event (id, cloudevents_id, source, type, spec_version, subject,
  event_time, data_content_type, facility_id, correlation_id, raw_payload, status, received_at)
VALUES
('2e000010-0000-0000-0000-000000000001','evt-sc-oh-010','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0001-1001',
 NOW()-INTERVAL '12 days' + INTERVAL '3 seconds','application/fhir+json','FAC-0001','corr-sc-010',
 '{"resourceType":"Encounter","id":"enc-sc-010","status":"finished","subject":{"reference":"Patient/260225-0001-1001"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '12 days' + INTERVAL '4 seconds')
ON CONFLICT DO NOTHING;

-- Mar 22: openhim observation for P06 (companion to existing direct evt-eb-d-2008)
INSERT INTO inbound_event (id, cloudevents_id, source, type, spec_version, subject,
  event_time, data_content_type, facility_id, correlation_id, raw_payload, status, received_at)
VALUES
('2e000011-0000-0000-0000-000000000001','evt-sc-oh-011','ebuzima',
 'org.openphc.cce.observation','1.0','260225-0003-3001',
 NOW()-INTERVAL '10 days' + INTERVAL '3 seconds','application/fhir+json','FAC-0003','corr-sc-011',
 '{"resourceType":"Observation","id":"obs-sc-011","status":"final","code":{"coding":[{"system":"http://loinc.org","code":"55284-4"}]},"subject":{"reference":"Patient/260225-0003-3001"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '10 days' + INTERVAL '5 seconds')
ON CONFLICT DO NOTHING;

-- Mar 27: openhim encounter for P02 (companion to existing direct evt-eb-d-1001)
INSERT INTO inbound_event (id, cloudevents_id, source, type, spec_version, subject,
  event_time, data_content_type, facility_id, correlation_id, raw_payload, status, received_at)
VALUES
('2e000012-0000-0000-0000-000000000001','evt-sc-oh-012','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0001-1002',
 NOW()-INTERVAL '5 days' + INTERVAL '3 seconds','application/fhir+json','FAC-0001','corr-sc-012',
 '{"resourceType":"Encounter","id":"enc-sc-012","status":"finished","subject":{"reference":"Patient/260225-0001-1002"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '5 days' + INTERVAL '5 seconds')
ON CONFLICT DO NOTHING;

-- Mar 30: openhim observation for P06 (companion to existing direct evt-eb-d-1002)
INSERT INTO inbound_event (id, cloudevents_id, source, type, spec_version, subject,
  event_time, data_content_type, facility_id, correlation_id, raw_payload, status, received_at)
VALUES
('2e000013-0000-0000-0000-000000000001','evt-sc-oh-013','ebuzima',
 'org.openphc.cce.observation','1.0','260225-0003-3001',
 NOW()-INTERVAL '2 days' + INTERVAL '3 seconds','application/fhir+json','FAC-0003','corr-sc-013',
 '{"resourceType":"Observation","id":"obs-sc-013","status":"final","code":{"coding":[{"system":"http://loinc.org","code":"55284-4"}]},"subject":{"reference":"Patient/260225-0003-3001"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '2 days' + INTERVAL '5 seconds')
ON CONFLICT DO NOTHING;

-- Direct companion for existing openhim-only event

-- Mar 25: direct immunization for P04 (companion to existing openhim evt-eb-oh-2006)
INSERT INTO inbound_event (id, cloudevents_id, source, type, spec_version, subject,
  event_time, data_content_type, facility_id, correlation_id, raw_payload, status, received_at)
VALUES
('2e000014-0000-0000-0000-000000000001','evt-sc-d-014','ebuzima-direct',
 'org.openphc.cce.immunization','1.0','260225-0002-2001',
 NOW()-INTERVAL '7 days' + INTERVAL '3 seconds','application/fhir+json','FAC-0002','corr-sc-014',
 '{"resourceType":"Immunization","id":"imm-sc-014","status":"completed","patient":{"reference":"Patient/260225-0002-2001"},"vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"132"}]}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '7 days' + INTERVAL '5 seconds')
ON CONFLICT DO NOTHING;

-- INTENTIONAL GAPS (no companion added):
-- Mar 24: existing direct encounter for P10 (evt-eb-d-2009)  — NO openhim
-- Mar 29: existing openhim immunization for P09 (evt-eb-oh-1001)  — NO direct
-- Mar 16: new direct encounter for P02 (evt-sc-d-008)  — NO openhim


-- =============================================================================
-- SECTION 2 : COMPLIANCE SERVICE  →  cce_compliance database
-- =============================================================================

\echo '--- [2/1] Inserting protocol_definition records ---'

INSERT INTO protocol_definition (id, url, version, status, definition, loaded_at)
VALUES

-- ANC High-Risk Monitoring (6 visits, monthly)
('0d000001-0000-0000-0000-000000000001',
 'http://openphc.org/fhir/PlanDefinition/anc-high-risk',
 '1.0',
 'ACTIVE',
 '{
   "resourceType":"PlanDefinition",
   "url":"http://openphc.org/fhir/PlanDefinition/anc-high-risk",
   "version":"1.0",
   "status":"active",
   "title":"ANC High-Risk Monitoring Protocol",
   "description":"Monthly antenatal care visits for high-risk pregnancies with BP monitoring",
   "action":[
     {"id":"anc-enrollment","title":"ANC Enrollment",
      "trigger":[{"type":"data-added","data":[{"type":"Encounter","codeFilter":[{"path":"type","code":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}]}]}],
      "requiredBehavior":"must"},
     {"id":"anc-visit-1","title":"ANC Visit 1 (8 weeks)",
      "trigger":[{"type":"data-added","data":[{"type":"Encounter","codeFilter":[{"path":"type","code":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}]}]}],
      "relatedAction":[{"actionId":"anc-enrollment","relationship":"after-start","offsetDuration":{"value":8,"unit":"wk"}}],
      "extension":[{"url":"http://openphc.org/fhir/StructureDefinition/tolerance-days","valueInteger":7}],
      "requiredBehavior":"must"},
     {"id":"anc-visit-2","title":"ANC Visit 2 (12 weeks)",
      "trigger":[{"type":"data-added","data":[{"type":"Encounter","codeFilter":[{"path":"type","code":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}]}]}],
      "relatedAction":[{"actionId":"anc-enrollment","relationship":"after-start","offsetDuration":{"value":12,"unit":"wk"}}],
      "extension":[{"url":"http://openphc.org/fhir/StructureDefinition/tolerance-days","valueInteger":7}],
      "requiredBehavior":"must"},
     {"id":"anc-visit-3","title":"ANC Visit 3 (20 weeks)",
      "trigger":[{"type":"data-added","data":[{"type":"Encounter","codeFilter":[{"path":"type","code":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}]}]}],
      "relatedAction":[{"actionId":"anc-enrollment","relationship":"after-start","offsetDuration":{"value":20,"unit":"wk"}}],
      "extension":[{"url":"http://openphc.org/fhir/StructureDefinition/tolerance-days","valueInteger":7}],
      "requiredBehavior":"must"},
     {"id":"anc-visit-4","title":"ANC Visit 4 (28 weeks)",
      "trigger":[{"type":"data-added","data":[{"type":"Encounter","codeFilter":[{"path":"type","code":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}]}]}],
      "relatedAction":[{"actionId":"anc-enrollment","relationship":"after-start","offsetDuration":{"value":28,"unit":"wk"}}],
      "extension":[{"url":"http://openphc.org/fhir/StructureDefinition/tolerance-days","valueInteger":7}],
      "requiredBehavior":"must"},
     {"id":"anc-bp-check","title":"BP Monitoring (every visit)",
      "trigger":[{"type":"data-added","data":[{"type":"Observation","codeFilter":[{"path":"code","code":[{"system":"http://loinc.org","code":"55284-4"}]}]}]}],
      "requiredBehavior":"could"}
   ]
 }'::jsonb,
 NOW()-INTERVAL '200 days'),

-- EPI Child 0-5 (immunization schedule)
('0d000002-0000-0000-0000-000000000001',
 'http://openphc.org/fhir/PlanDefinition/epi-child-0-5',
 '1.0',
 'ACTIVE',
 '{
   "resourceType":"PlanDefinition",
   "url":"http://openphc.org/fhir/PlanDefinition/epi-child-0-5",
   "version":"1.0",
   "status":"active",
   "title":"EPI Child Immunization Protocol (0-5 years)",
   "description":"Zambia EPI immunization schedule for children under 5",
   "action":[
     {"id":"epi-enrollment","title":"Birth Registration / BCG",
      "trigger":[{"type":"data-added","data":[{"type":"Immunization","codeFilter":[{"path":"vaccineCode","code":[{"system":"http://hl7.org/fhir/sid/cvx","code":"19"}]}]}]}],
      "requiredBehavior":"must"},
     {"id":"epi-opv0","title":"OPV0 (at birth)",
      "trigger":[{"type":"data-added","data":[{"type":"Immunization","codeFilter":[{"path":"vaccineCode","code":[{"system":"http://hl7.org/fhir/sid/cvx","code":"02"}]}]}]}],
      "relatedAction":[{"actionId":"epi-enrollment","relationship":"after-start","offsetDuration":{"value":0,"unit":"d"}}],
      "extension":[{"url":"http://openphc.org/fhir/StructureDefinition/tolerance-days","valueInteger":14}],
      "requiredBehavior":"must"},
     {"id":"epi-penta1","title":"Pentavalent 1 (6 weeks)",
      "trigger":[{"type":"data-added","data":[{"type":"Immunization","codeFilter":[{"path":"vaccineCode","code":[{"system":"http://hl7.org/fhir/sid/cvx","code":"132"}]}]}]}],
      "relatedAction":[{"actionId":"epi-enrollment","relationship":"after-start","offsetDuration":{"value":6,"unit":"wk"}}],
      "extension":[{"url":"http://openphc.org/fhir/StructureDefinition/tolerance-days","valueInteger":7}],
      "requiredBehavior":"must"},
     {"id":"epi-penta2","title":"Pentavalent 2 (10 weeks)",
      "trigger":[{"type":"data-added","data":[{"type":"Immunization","codeFilter":[{"path":"vaccineCode","code":[{"system":"http://hl7.org/fhir/sid/cvx","code":"132"}]}]}]}],
      "relatedAction":[{"actionId":"epi-enrollment","relationship":"after-start","offsetDuration":{"value":10,"unit":"wk"}}],
      "extension":[{"url":"http://openphc.org/fhir/StructureDefinition/tolerance-days","valueInteger":7}],
      "requiredBehavior":"must"},
     {"id":"epi-penta3","title":"Pentavalent 3 (14 weeks)",
      "trigger":[{"type":"data-added","data":[{"type":"Immunization","codeFilter":[{"path":"vaccineCode","code":[{"system":"http://hl7.org/fhir/sid/cvx","code":"132"}]}]}]}],
      "relatedAction":[{"actionId":"epi-enrollment","relationship":"after-start","offsetDuration":{"value":14,"unit":"wk"}}],
      "extension":[{"url":"http://openphc.org/fhir/StructureDefinition/tolerance-days","valueInteger":7}],
      "requiredBehavior":"must"}
   ]
 }'::jsonb,
 NOW()-INTERVAL '200 days'),

-- Hypertension Management (monthly follow-ups)
('0d000003-0000-0000-0000-000000000001',
 'http://openphc.org/fhir/PlanDefinition/htn-management',
 '1.0',
 'ACTIVE',
 '{
   "resourceType":"PlanDefinition",
   "url":"http://openphc.org/fhir/PlanDefinition/htn-management",
   "version":"1.0",
   "status":"active",
   "title":"Hypertension Management Protocol",
   "description":"Monthly follow-up protocol for hypertensive patients including BP monitoring",
   "action":[
     {"id":"htn-enrollment","title":"HTN Diagnosis Encounter",
      "trigger":[{"type":"data-added","data":[{"type":"Encounter","codeFilter":[{"path":"type","code":[{"system":"http://openphc.org/encounter-types","code":"htn-followup"}]}]}]}],
      "requiredBehavior":"must"},
     {"id":"htn-followup-1","title":"HTN Follow-up 1 (1 month)",
      "trigger":[{"type":"data-added","data":[{"type":"Encounter","codeFilter":[{"path":"type","code":[{"system":"http://openphc.org/encounter-types","code":"htn-followup"}]}]}]}],
      "relatedAction":[{"actionId":"htn-enrollment","relationship":"after-start","offsetDuration":{"value":1,"unit":"mo"}}],
      "extension":[{"url":"http://openphc.org/fhir/StructureDefinition/tolerance-days","valueInteger":7}],
      "requiredBehavior":"must"},
     {"id":"htn-followup-2","title":"HTN Follow-up 2 (2 months)",
      "trigger":[{"type":"data-added","data":[{"type":"Encounter","codeFilter":[{"path":"type","code":[{"system":"http://openphc.org/encounter-types","code":"htn-followup"}]}]}]}],
      "relatedAction":[{"actionId":"htn-enrollment","relationship":"after-start","offsetDuration":{"value":2,"unit":"mo"}}],
      "extension":[{"url":"http://openphc.org/fhir/StructureDefinition/tolerance-days","valueInteger":7}],
      "requiredBehavior":"must"},
     {"id":"htn-followup-3","title":"HTN Follow-up 3 (3 months)",
      "trigger":[{"type":"data-added","data":[{"type":"Encounter","codeFilter":[{"path":"type","code":[{"system":"http://openphc.org/encounter-types","code":"htn-followup"}]}]}]}],
      "relatedAction":[{"actionId":"htn-enrollment","relationship":"after-start","offsetDuration":{"value":3,"unit":"mo"}}],
      "extension":[{"url":"http://openphc.org/fhir/StructureDefinition/tolerance-days","valueInteger":7}],
      "requiredBehavior":"must"},
     {"id":"htn-bp-check","title":"BP Measurement (every visit)",
      "trigger":[{"type":"data-added","data":[{"type":"Observation","codeFilter":[{"path":"code","code":[{"system":"http://loinc.org","code":"55284-4"}]}]}]}],
      "requiredBehavior":"could"}
   ]
 }'::jsonb,
 NOW()-INTERVAL '200 days')
ON CONFLICT DO NOTHING;


-- ─────────────────────────────────────────────────────────────────────────────
\echo '--- [2/2] Inserting trigger_index records ---'
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO trigger_index
    (resource_type, path, code_system, code_value, protocol_definition_id, action_id)
VALUES
-- ANC protocol triggers
('Encounter','type','http://openphc.org/encounter-types','anc-visit',
 '0d000001-0000-0000-0000-000000000001','anc-enrollment'),
('Encounter','type','http://openphc.org/encounter-types','anc-visit',
 '0d000001-0000-0000-0000-000000000001','anc-visit-1'),
('Encounter','type','http://openphc.org/encounter-types','anc-visit',
 '0d000001-0000-0000-0000-000000000001','anc-visit-2'),
('Encounter','type','http://openphc.org/encounter-types','anc-visit',
 '0d000001-0000-0000-0000-000000000001','anc-visit-3'),
('Encounter','type','http://openphc.org/encounter-types','anc-visit',
 '0d000001-0000-0000-0000-000000000001','anc-visit-4'),
('Observation','code','http://loinc.org','55284-4',
 '0d000001-0000-0000-0000-000000000001','anc-bp-check'),

-- EPI protocol triggers
('Immunization','vaccineCode','http://hl7.org/fhir/sid/cvx','19',
 '0d000002-0000-0000-0000-000000000001','epi-enrollment'),
('Immunization','vaccineCode','http://hl7.org/fhir/sid/cvx','02',
 '0d000002-0000-0000-0000-000000000001','epi-opv0'),
('Immunization','vaccineCode','http://hl7.org/fhir/sid/cvx','132',
 '0d000002-0000-0000-0000-000000000001','epi-penta1'),
('Immunization','vaccineCode','http://hl7.org/fhir/sid/cvx','132',
 '0d000002-0000-0000-0000-000000000001','epi-penta2'),
('Immunization','vaccineCode','http://hl7.org/fhir/sid/cvx','132',
 '0d000002-0000-0000-0000-000000000001','epi-penta3'),

-- HTN protocol triggers
('Encounter','type','http://openphc.org/encounter-types','htn-followup',
 '0d000003-0000-0000-0000-000000000001','htn-enrollment'),
('Encounter','type','http://openphc.org/encounter-types','htn-followup',
 '0d000003-0000-0000-0000-000000000001','htn-followup-1'),
('Encounter','type','http://openphc.org/encounter-types','htn-followup',
 '0d000003-0000-0000-0000-000000000001','htn-followup-2'),
('Encounter','type','http://openphc.org/encounter-types','htn-followup',
 '0d000003-0000-0000-0000-000000000001','htn-followup-3'),
('Observation','code','http://loinc.org','55284-4',
 '0d000003-0000-0000-0000-000000000001','htn-bp-check')
ON CONFLICT DO NOTHING;


-- ─────────────────────────────────────────────────────────────────────────────
\echo '--- [2/3] Inserting protocol_instance records ---'
-- ─────────────────────────────────────────────────────────────────────────────
-- Patients:
--   P01 260225-0001-1001  ANC  FAC-0001  (ACTIVE)
--   P02 260225-0001-1002  ANC  FAC-0001  (ACTIVE)
--   P03 260225-0001-1003  ANC  FAC-0001  (ACTIVE)
--   P04 260225-0002-2001  EPI  FAC-0002  (ACTIVE)
--   P05 260225-0002-2002  EPI  FAC-0002  (ACTIVE)
--   P06 260225-0003-3001  HTN  FAC-0003  (ACTIVE)
--   P07 260225-0003-3002  ANC  FAC-0003  (ACTIVE - openhim only)
--   P08 260225-0003-3003  ANC  FAC-0003  (ACTIVE - openhim only)
--   P09 260225-0004-4001  EPI  FAC-0004  (ACTIVE - openhim only)
--   P10 260225-0004-4002  ANC  FAC-0004  (ACTIVE - direct primary)
--   P11 260225-0004-4003  ANC  FAC-0004  (ACTIVE - dual source)
--   P12 260225-0004-4004  HTN  FAC-0004  (ACTIVE - source mismatch)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO protocol_instance
    (id, patient_id, protocol_canonical, protocol_definition_id,
     enrolled_at, status, created_at, updated_at)
VALUES
-- ANC instances
('01000001-0000-0000-0000-000000000001','260225-0001-1001',
 'http://openphc.org/fhir/PlanDefinition/anc-high-risk|1.0',
 '0d000001-0000-0000-0000-000000000001',
 NOW()-INTERVAL '175 days','ACTIVE',
 NOW()-INTERVAL '175 days',NOW()-INTERVAL '91 days'),

('01000002-0000-0000-0000-000000000001','260225-0001-1002',
 'http://openphc.org/fhir/PlanDefinition/anc-high-risk|1.0',
 '0d000001-0000-0000-0000-000000000001',
 NOW()-INTERVAL '168 days','ACTIVE',
 NOW()-INTERVAL '168 days',NOW()-INTERVAL '5 days'),

('01000003-0000-0000-0000-000000000001','260225-0001-1003',
 'http://openphc.org/fhir/PlanDefinition/anc-high-risk|1.0',
 '0d000001-0000-0000-0000-000000000001',
 NOW()-INTERVAL '155 days','ACTIVE',
 NOW()-INTERVAL '155 days',NOW()-INTERVAL '155 days'),

-- EPI instances
('01000004-0000-0000-0000-000000000001','260225-0002-2001',
 'http://openphc.org/fhir/PlanDefinition/epi-child-0-5|1.0',
 '0d000002-0000-0000-0000-000000000001',
 NOW()-INTERVAL '160 days','ACTIVE',
 NOW()-INTERVAL '160 days',NOW()-INTERVAL '34 days'),

('01000005-0000-0000-0000-000000000001','260225-0002-2002',
 'http://openphc.org/fhir/PlanDefinition/epi-child-0-5|1.0',
 '0d000002-0000-0000-0000-000000000001',
 NOW()-INTERVAL '150 days','ACTIVE',
 NOW()-INTERVAL '150 days',NOW()-INTERVAL '108 days'),

-- HTN instances
('01000006-0000-0000-0000-000000000001','260225-0003-3001',
 'http://openphc.org/fhir/PlanDefinition/htn-management|1.0',
 '0d000003-0000-0000-0000-000000000001',
 NOW()-INTERVAL '140 days','ACTIVE',
 NOW()-INTERVAL '140 days',NOW()-INTERVAL '2 days'),

-- ANC - openhim-only patients
('01000007-0000-0000-0000-000000000001','260225-0003-3002',
 'http://openphc.org/fhir/PlanDefinition/anc-high-risk|1.0',
 '0d000001-0000-0000-0000-000000000001',
 NOW()-INTERVAL '145 days','ACTIVE',
 NOW()-INTERVAL '145 days',NOW()-INTERVAL '61 days'),

('01000008-0000-0000-0000-000000000001','260225-0003-3003',
 'http://openphc.org/fhir/PlanDefinition/anc-high-risk|1.0',
 '0d000001-0000-0000-0000-000000000001',
 NOW()-INTERVAL '138 days','ACTIVE',
 NOW()-INTERVAL '138 days',NOW()-INTERVAL '138 days'),

-- EPI - openhim-only patient
('01000009-0000-0000-0000-000000000001','260225-0004-4001',
 'http://openphc.org/fhir/PlanDefinition/epi-child-0-5|1.0',
 '0d000002-0000-0000-0000-000000000001',
 NOW()-INTERVAL '130 days','ACTIVE',
 NOW()-INTERVAL '130 days',NOW()-INTERVAL '3 days'),

-- ANC - direct primary (P10)
('01000010-0000-0000-0000-000000000001','260225-0004-4002',
 'http://openphc.org/fhir/PlanDefinition/anc-high-risk|1.0',
 '0d000001-0000-0000-0000-000000000001',
 NOW()-INTERVAL '120 days','ACTIVE',
 NOW()-INTERVAL '120 days',NOW()-INTERVAL '78 days'),

-- ANC - dual source (P11)
('01000011-0000-0000-0000-000000000001','260225-0004-4003',
 'http://openphc.org/fhir/PlanDefinition/anc-high-risk|1.0',
 '0d000001-0000-0000-0000-000000000001',
 NOW()-INTERVAL '110 days','ACTIVE',
 NOW()-INTERVAL '110 days',NOW()-INTERVAL '68 days'),

-- HTN - source mismatch (P12)
('01000012-0000-0000-0000-000000000001','260225-0004-4004',
 'http://openphc.org/fhir/PlanDefinition/htn-management|1.0',
 '0d000003-0000-0000-0000-000000000001',
 NOW()-INTERVAL '95 days','ACTIVE',
 NOW()-INTERVAL '95 days',NOW()-INTERVAL '95 days')
ON CONFLICT DO NOTHING;


-- ─────────────────────────────────────────────────────────────────────────────
\echo '--- [2/4] Inserting step_instance records ---'
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO step_instance (
    id, protocol_instance_id, action_id, repeat_index, state,
    due_date, overdue_date, missed_date,
    completed_at, completed_by_source, completion_status, matched_event_id,
    required_behavior, created_at, updated_at
) VALUES

-- ── P01 (260225-0001-1001) — ANC — 3 completed, 1 overdue ──────────────────
('51000001-0000-0000-0000-000000000001',
 '01000001-0000-0000-0000-000000000001','anc-enrollment',0,'COMPLETED',
 NOW()-INTERVAL '175 days',NOW()-INTERVAL '168 days',NULL,
 NOW()-INTERVAL '175 days','ebuzima-direct','ON_TIME',
 'e1000001-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '175 days',NOW()-INTERVAL '175 days'),

('51000002-0000-0000-0000-000000000001',
 '01000001-0000-0000-0000-000000000001','anc-visit-1',0,'COMPLETED',
 NOW()-INTERVAL '119 days',NOW()-INTERVAL '112 days',NULL,
 NOW()-INTERVAL '133 days','ebuzima-direct','LATE',
 'e1000002-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '119 days',NOW()-INTERVAL '133 days'),

('51000003-0000-0000-0000-000000000001',
 '01000001-0000-0000-0000-000000000001','anc-visit-2',0,'COMPLETED',
 NOW()-INTERVAL '79 days',NOW()-INTERVAL '72 days',NULL,
 NOW()-INTERVAL '91 days','ebuzima-direct','LATE',
 'e1000003-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '79 days',NOW()-INTERVAL '91 days'),

-- BP check (optional, completed)
('51000004-0000-0000-0000-000000000001',
 '01000001-0000-0000-0000-000000000001','anc-bp-check',0,'COMPLETED',
 NULL,NULL,NULL,
 NOW()-INTERVAL '91 days','ebuzima-direct','ON_TIME',
 'e1000004-0000-0000-0000-000000000001','could',
 NOW()-INTERVAL '91 days',NOW()-INTERVAL '91 days'),

-- visit-3 — OVERDUE (due 35 days ago, tolerance expired 28 days ago)
('51000005-0000-0000-0000-000000000001',
 '01000001-0000-0000-0000-000000000001','anc-visit-3',0,'OVERDUE',
 NOW()-INTERVAL '35 days',NOW()-INTERVAL '28 days',NOW()-INTERVAL '14 days',
 NULL,NULL,NULL,NULL,'must',
 NOW()-INTERVAL '175 days',NOW()-INTERVAL '28 days'),

-- visit-4 — PENDING
('51000006-0000-0000-0000-000000000001',
 '01000001-0000-0000-0000-000000000001','anc-visit-4',0,'PENDING',
 NOW()+INTERVAL '21 days',NOW()+INTERVAL '28 days',NOW()+INTERVAL '42 days',
 NULL,NULL,NULL,NULL,'must',
 NOW()-INTERVAL '175 days',NOW()-INTERVAL '175 days'),

-- ── P02 (260225-0001-1002) — ANC — 2 completed on time, 1 late, 1 DUE ─────
('51000007-0000-0000-0000-000000000001',
 '01000002-0000-0000-0000-000000000001','anc-enrollment',0,'COMPLETED',
 NOW()-INTERVAL '168 days',NOW()-INTERVAL '161 days',NULL,
 NOW()-INTERVAL '168 days','ebuzima-direct','ON_TIME',
 'e1000005-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '168 days',NOW()-INTERVAL '168 days'),

('51000008-0000-0000-0000-000000000001',
 '01000002-0000-0000-0000-000000000001','anc-visit-1',0,'COMPLETED',
 NOW()-INTERVAL '112 days',NOW()-INTERVAL '105 days',NULL,
 NOW()-INTERVAL '126 days','ebuzima-direct','LATE',
 'e1000006-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '112 days',NOW()-INTERVAL '126 days'),

('51000009-0000-0000-0000-000000000001',
 '01000002-0000-0000-0000-000000000001','anc-visit-2',0,'COMPLETED',
 NOW()-INTERVAL '56 days',NOW()-INTERVAL '49 days',NULL,
 NOW()-INTERVAL '62 days','ebuzima-direct','LATE',
 'e1000007-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '56 days',NOW()-INTERVAL '62 days'),

-- anc-visit-3 DUE (recent visit window)
('51000010-0000-0000-0000-000000000001',
 '01000002-0000-0000-0000-000000000001','anc-visit-3',0,'DUE',
 NOW()-INTERVAL '5 days',NOW()+INTERVAL '2 days',NOW()+INTERVAL '16 days',
 NULL,NULL,NULL,NULL,'must',
 NOW()-INTERVAL '168 days',NOW()-INTERVAL '5 days'),

-- ── P03 (260225-0001-1003) — ANC — 1 completed, 2 MISSED ───────────────────
('51000011-0000-0000-0000-000000000001',
 '01000003-0000-0000-0000-000000000001','anc-enrollment',0,'COMPLETED',
 NOW()-INTERVAL '155 days',NOW()-INTERVAL '148 days',NULL,
 NOW()-INTERVAL '155 days','ebuzima-direct','ON_TIME',
 'e1000008-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '155 days',NOW()-INTERVAL '155 days'),

-- visit-1 MISSED
('51000012-0000-0000-0000-000000000001',
 '01000003-0000-0000-0000-000000000001','anc-visit-1',0,'MISSED',
 NOW()-INTERVAL '99 days',NOW()-INTERVAL '92 days',NOW()-INTERVAL '78 days',
 NULL,NULL,NULL,NULL,'must',
 NOW()-INTERVAL '155 days',NOW()-INTERVAL '78 days'),

-- visit-2 MISSED
('51000013-0000-0000-0000-000000000001',
 '01000003-0000-0000-0000-000000000001','anc-visit-2',0,'MISSED',
 NOW()-INTERVAL '71 days',NOW()-INTERVAL '64 days',NOW()-INTERVAL '50 days',
 NULL,NULL,NULL,NULL,'must',
 NOW()-INTERVAL '155 days',NOW()-INTERVAL '50 days'),

-- visit-3 OVERDUE
('51000014-0000-0000-0000-000000000001',
 '01000003-0000-0000-0000-000000000001','anc-visit-3',0,'OVERDUE',
 NOW()-INTERVAL '15 days',NOW()-INTERVAL '8 days',NOW()+INTERVAL '6 days',
 NULL,NULL,NULL,NULL,'must',
 NOW()-INTERVAL '155 days',NOW()-INTERVAL '8 days'),

-- ── P04 (260225-0002-2001) — EPI — BCG+OPV0+Penta1+Penta2 done, Penta3 DUE ─
('51000015-0000-0000-0000-000000000001',
 '01000004-0000-0000-0000-000000000001','epi-enrollment',0,'COMPLETED',
 NOW()-INTERVAL '160 days',NOW()-INTERVAL '153 days',NULL,
 NOW()-INTERVAL '160 days','ebuzima','ON_TIME',
 'e1000012-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '160 days',NOW()-INTERVAL '160 days'),

('51000016-0000-0000-0000-000000000001',
 '01000004-0000-0000-0000-000000000001','epi-opv0',0,'COMPLETED',
 NOW()-INTERVAL '160 days',NOW()-INTERVAL '146 days',NULL,
 NOW()-INTERVAL '118 days','ebuzima','LATE',
 'e1000013-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '160 days',NOW()-INTERVAL '118 days'),

('51000017-0000-0000-0000-000000000001',
 '01000004-0000-0000-0000-000000000001','epi-penta1',0,'COMPLETED',
 NOW()-INTERVAL '118 days',NOW()-INTERVAL '111 days',NULL,
 NOW()-INTERVAL '76 days','ebuzima','LATE',
 'e1000014-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '118 days',NOW()-INTERVAL '76 days'),

('51000018-0000-0000-0000-000000000001',
 '01000004-0000-0000-0000-000000000001','epi-penta2',0,'COMPLETED',
 NOW()-INTERVAL '76 days',NOW()-INTERVAL '69 days',NULL,
 NOW()-INTERVAL '34 days','ebuzima','LATE',
 'e1000015-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '76 days',NOW()-INTERVAL '34 days'),

('51000019-0000-0000-0000-000000000001',
 '01000004-0000-0000-0000-000000000001','epi-penta3',0,'DUE',
 NOW()-INTERVAL '7 days',NOW()+INTERVAL '0 days',NOW()+INTERVAL '14 days',
 NULL,NULL,NULL,NULL,'must',
 NOW()-INTERVAL '76 days',NOW()-INTERVAL '7 days'),

-- ── P05 (260225-0002-2002) — EPI — BCG done, OPV0 MISSED, Penta1 PENDING ──
('51000020-0000-0000-0000-000000000001',
 '01000005-0000-0000-0000-000000000001','epi-enrollment',0,'COMPLETED',
 NOW()-INTERVAL '150 days',NOW()-INTERVAL '143 days',NULL,
 NOW()-INTERVAL '150 days','ebuzima','ON_TIME',
 'e1000016-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '150 days',NOW()-INTERVAL '150 days'),

('51000021-0000-0000-0000-000000000001',
 '01000005-0000-0000-0000-000000000001','epi-opv0',0,'COMPLETED',
 NOW()-INTERVAL '150 days',NOW()-INTERVAL '136 days',NULL,
 NOW()-INTERVAL '108 days','ebuzima','LATE',
 'e1000017-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '150 days',NOW()-INTERVAL '108 days'),

('51000022-0000-0000-0000-000000000001',
 '01000005-0000-0000-0000-000000000001','epi-penta1',0,'MISSED',
 NOW()-INTERVAL '108 days',NOW()-INTERVAL '101 days',NOW()-INTERVAL '87 days',
 NULL,NULL,NULL,NULL,'must',
 NOW()-INTERVAL '150 days',NOW()-INTERVAL '87 days'),

('51000023-0000-0000-0000-000000000001',
 '01000005-0000-0000-0000-000000000001','epi-penta2',0,'PENDING',
 NOW()-INTERVAL '80 days',NOW()-INTERVAL '73 days',NOW()-INTERVAL '59 days',
 NULL,NULL,NULL,NULL,'must',
 NOW()-INTERVAL '150 days',NOW()-INTERVAL '150 days'),

-- ── P06 (260225-0003-3001) — HTN — 3 completed ON_TIME, 1 PENDING ─────────
('51000024-0000-0000-0000-000000000001',
 '01000006-0000-0000-0000-000000000001','htn-enrollment',0,'COMPLETED',
 NOW()-INTERVAL '140 days',NOW()-INTERVAL '133 days',NULL,
 NOW()-INTERVAL '140 days','ebuzima','ON_TIME',
 'e1000018-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '140 days',NOW()-INTERVAL '140 days'),

('51000025-0000-0000-0000-000000000001',
 '01000006-0000-0000-0000-000000000001','htn-followup-1',0,'COMPLETED',
 NOW()-INTERVAL '110 days',NOW()-INTERVAL '103 days',NULL,
 NOW()-INTERVAL '98 days','ebuzima','LATE',
 'e1000019-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '110 days',NOW()-INTERVAL '98 days'),

('51000026-0000-0000-0000-000000000001',
 '01000006-0000-0000-0000-000000000001','htn-followup-2',0,'COMPLETED',
 NOW()-INTERVAL '80 days',NOW()-INTERVAL '73 days',NULL,
 NOW()-INTERVAL '56 days','ebuzima-direct','LATE',
 'e1000020-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '110 days',NOW()-INTERVAL '56 days'),

-- BP check optional — completed
('51000027-0000-0000-0000-000000000001',
 '01000006-0000-0000-0000-000000000001','htn-bp-check',0,'COMPLETED',
 NULL,NULL,NULL,
 NOW()-INTERVAL '2 days','ebuzima-direct','ON_TIME',
 'e1000021-0000-0000-0000-000000000001','could',
 NOW()-INTERVAL '140 days',NOW()-INTERVAL '2 days'),

-- followup-3 DUE
('51000028-0000-0000-0000-000000000001',
 '01000006-0000-0000-0000-000000000001','htn-followup-3',0,'DUE',
 NOW()-INTERVAL '14 days',NOW()-INTERVAL '7 days',NOW()+INTERVAL '7 days',
 NULL,NULL,NULL,NULL,'must',
 NOW()-INTERVAL '110 days',NOW()-INTERVAL '14 days'),

-- ── P07 (260225-0003-3002) — ANC openhim-only — 2 completed, 1 OVERDUE ────
('51000029-0000-0000-0000-000000000001',
 '01000007-0000-0000-0000-000000000001','anc-enrollment',0,'COMPLETED',
 NOW()-INTERVAL '145 days',NOW()-INTERVAL '138 days',NULL,
 NOW()-INTERVAL '145 days','ebuzima','ON_TIME',
 'e1000022-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '145 days',NOW()-INTERVAL '145 days'),

('51000030-0000-0000-0000-000000000001',
 '01000007-0000-0000-0000-000000000001','anc-visit-1',0,'COMPLETED',
 NOW()-INTERVAL '89 days',NOW()-INTERVAL '82 days',NULL,
 NOW()-INTERVAL '103 days','ebuzima','LATE',
 'e1000023-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '89 days',NOW()-INTERVAL '103 days'),

('51000031-0000-0000-0000-000000000001',
 '01000007-0000-0000-0000-000000000001','anc-visit-2',0,'COMPLETED',
 NOW()-INTERVAL '57 days',NOW()-INTERVAL '50 days',NULL,
 NOW()-INTERVAL '61 days','ebuzima','LATE',
 'e1000024-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '89 days',NOW()-INTERVAL '61 days'),

-- visit-3 OVERDUE (no direct counterpart)
('51000032-0000-0000-0000-000000000001',
 '01000007-0000-0000-0000-000000000001','anc-visit-3',0,'OVERDUE',
 NOW()-INTERVAL '25 days',NOW()-INTERVAL '18 days',NOW()-INTERVAL '4 days',
 NULL,NULL,NULL,NULL,'must',
 NOW()-INTERVAL '89 days',NOW()-INTERVAL '18 days'),

-- ── P08 (260225-0003-3003) — ANC openhim-only — 1 completed, rest MISSED ──
('51000033-0000-0000-0000-000000000001',
 '01000008-0000-0000-0000-000000000001','anc-enrollment',0,'COMPLETED',
 NOW()-INTERVAL '138 days',NOW()-INTERVAL '131 days',NULL,
 NOW()-INTERVAL '138 days','ebuzima','ON_TIME',
 'e1000025-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '138 days',NOW()-INTERVAL '138 days'),

('51000034-0000-0000-0000-000000000001',
 '01000008-0000-0000-0000-000000000001','anc-visit-1',0,'MISSED',
 NOW()-INTERVAL '82 days',NOW()-INTERVAL '75 days',NOW()-INTERVAL '61 days',
 NULL,NULL,NULL,NULL,'must',
 NOW()-INTERVAL '138 days',NOW()-INTERVAL '61 days'),

('51000035-0000-0000-0000-000000000001',
 '01000008-0000-0000-0000-000000000001','anc-visit-2',0,'MISSED',
 NOW()-INTERVAL '54 days',NOW()-INTERVAL '47 days',NOW()-INTERVAL '33 days',
 NULL,NULL,NULL,NULL,'must',
 NOW()-INTERVAL '138 days',NOW()-INTERVAL '33 days'),

('51000036-0000-0000-0000-000000000001',
 '01000008-0000-0000-0000-000000000001','anc-visit-3',0,'OVERDUE',
 NOW()-INTERVAL '14 days',NOW()-INTERVAL '7 days',NOW()+INTERVAL '7 days',
 NULL,NULL,NULL,NULL,'must',
 NOW()-INTERVAL '138 days',NOW()-INTERVAL '7 days'),

-- ── P09 (260225-0004-4001) — EPI openhim-only — BCG done, OPV0 DUE ─────────
('51000037-0000-0000-0000-000000000001',
 '01000009-0000-0000-0000-000000000001','epi-enrollment',0,'COMPLETED',
 NOW()-INTERVAL '130 days',NOW()-INTERVAL '123 days',NULL,
 NOW()-INTERVAL '130 days','ebuzima','ON_TIME',
 'e1000026-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '130 days',NOW()-INTERVAL '130 days'),

('51000038-0000-0000-0000-000000000001',
 '01000009-0000-0000-0000-000000000001','epi-opv0',0,'COMPLETED',
 NOW()-INTERVAL '130 days',NOW()-INTERVAL '116 days',NULL,
 NOW()-INTERVAL '3 days','ebuzima','LATE',
 'e1000027-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '130 days',NOW()-INTERVAL '3 days'),

('51000039-0000-0000-0000-000000000001',
 '01000009-0000-0000-0000-000000000001','epi-penta1',0,'PENDING',
 NOW()+INTERVAL '28 days',NOW()+INTERVAL '35 days',NOW()+INTERVAL '49 days',
 NULL,NULL,NULL,NULL,'must',
 NOW()-INTERVAL '130 days',NOW()-INTERVAL '130 days'),

-- ── P10 (260225-0004-4002) — ANC direct-primary — 2 completed, 1 PENDING ──
('51000040-0000-0000-0000-000000000001',
 '01000010-0000-0000-0000-000000000001','anc-enrollment',0,'COMPLETED',
 NOW()-INTERVAL '120 days',NOW()-INTERVAL '113 days',NULL,
 NOW()-INTERVAL '120 days','ebuzima-direct','ON_TIME',
 'e1000028-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '120 days',NOW()-INTERVAL '120 days'),

('51000041-0000-0000-0000-000000000001',
 '01000010-0000-0000-0000-000000000001','anc-visit-1',0,'COMPLETED',
 NOW()-INTERVAL '64 days',NOW()-INTERVAL '57 days',NULL,
 NOW()-INTERVAL '78 days','ebuzima-direct','LATE',
 'e1000029-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '120 days',NOW()-INTERVAL '78 days'),

('51000042-0000-0000-0000-000000000001',
 '01000010-0000-0000-0000-000000000001','anc-visit-2',0,'PENDING',
 NOW()+INTERVAL '8 days',NOW()+INTERVAL '15 days',NOW()+INTERVAL '29 days',
 NULL,NULL,NULL,NULL,'must',
 NOW()-INTERVAL '120 days',NOW()-INTERVAL '120 days'),

-- ── P11 (260225-0004-4003) — ANC dual-source — 2 completed, 1 PENDING ─────
('51000043-0000-0000-0000-000000000001',
 '01000011-0000-0000-0000-000000000001','anc-enrollment',0,'COMPLETED',
 NOW()-INTERVAL '110 days',NOW()-INTERVAL '103 days',NULL,
 NOW()-INTERVAL '110 days','ebuzima-direct','ON_TIME',
 'e1000030-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '110 days',NOW()-INTERVAL '110 days'),

('51000044-0000-0000-0000-000000000001',
 '01000011-0000-0000-0000-000000000001','anc-visit-1',0,'COMPLETED',
 NOW()-INTERVAL '54 days',NOW()-INTERVAL '47 days',NULL,
 NOW()-INTERVAL '68 days','ebuzima-direct','LATE',
 'e1000031-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '110 days',NOW()-INTERVAL '68 days'),

('51000045-0000-0000-0000-000000000001',
 '01000011-0000-0000-0000-000000000001','anc-visit-2',0,'PENDING',
 NOW()+INTERVAL '18 days',NOW()+INTERVAL '25 days',NOW()+INTERVAL '39 days',
 NULL,NULL,NULL,NULL,'must',
 NOW()-INTERVAL '110 days',NOW()-INTERVAL '110 days'),

-- ── P12 (260225-0004-4004) — HTN source-mismatch — 1 completed, 2 MISSED ──
('51000046-0000-0000-0000-000000000001',
 '01000012-0000-0000-0000-000000000001','htn-enrollment',0,'COMPLETED',
 NOW()-INTERVAL '95 days',NOW()-INTERVAL '88 days',NULL,
 NOW()-INTERVAL '95 days','ebuzima-direct','ON_TIME',
 'e1000032-0000-0000-0000-000000000001','must',
 NOW()-INTERVAL '95 days',NOW()-INTERVAL '95 days'),

('51000047-0000-0000-0000-000000000001',
 '01000012-0000-0000-0000-000000000001','htn-followup-1',0,'MISSED',
 NOW()-INTERVAL '65 days',NOW()-INTERVAL '58 days',NOW()-INTERVAL '44 days',
 NULL,NULL,NULL,NULL,'must',
 NOW()-INTERVAL '95 days',NOW()-INTERVAL '44 days'),

('51000048-0000-0000-0000-000000000001',
 '01000012-0000-0000-0000-000000000001','htn-followup-2',0,'MISSED',
 NOW()-INTERVAL '35 days',NOW()-INTERVAL '28 days',NOW()-INTERVAL '14 days',
 NULL,NULL,NULL,NULL,'must',
 NOW()-INTERVAL '95 days',NOW()-INTERVAL '14 days'),

('51000049-0000-0000-0000-000000000001',
 '01000012-0000-0000-0000-000000000001','htn-followup-3',0,'OVERDUE',
 NOW()-INTERVAL '5 days',NOW()+INTERVAL '2 days',NOW()+INTERVAL '16 days',
 NULL,NULL,NULL,NULL,'must',
 NOW()-INTERVAL '95 days',NOW()-INTERVAL '5 days')
ON CONFLICT DO NOTHING;


-- ─────────────────────────────────────────────────────────────────────────────
\echo '--- [2/5] Inserting deviation records ---'
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO deviation (
    id, protocol_instance_id, step_instance_id, deviation_type,
    detected_at, intelligence_event_id, metadata
) VALUES

-- P01 anc-visit-3 OVERDUE
('de000001-0000-0000-0000-000000000001',
 '01000001-0000-0000-0000-000000000001',
 '51000005-0000-0000-0000-000000000001',
 'OVERDUE', NOW()-INTERVAL '28 days', NULL,
 '{"daysOverdue":7}'::jsonb),

-- P03 anc-visit-1 MISSED
('de000002-0000-0000-0000-000000000001',
 '01000003-0000-0000-0000-000000000001',
 '51000012-0000-0000-0000-000000000001',
 'MISSED', NOW()-INTERVAL '78 days', NULL,
 '{"daysPastMissedDate":0}'::jsonb),

-- P03 anc-visit-2 MISSED
('de000003-0000-0000-0000-000000000001',
 '01000003-0000-0000-0000-000000000001',
 '51000013-0000-0000-0000-000000000001',
 'MISSED', NOW()-INTERVAL '50 days', NULL,
 '{"daysPastMissedDate":0}'::jsonb),

-- P03 anc-visit-3 OVERDUE
('de000004-0000-0000-0000-000000000001',
 '01000003-0000-0000-0000-000000000001',
 '51000014-0000-0000-0000-000000000001',
 'OVERDUE', NOW()-INTERVAL '8 days', NULL,
 '{"daysOverdue":7}'::jsonb),

-- P05 epi-penta1 MISSED
('de000005-0000-0000-0000-000000000001',
 '01000005-0000-0000-0000-000000000001',
 '51000022-0000-0000-0000-000000000001',
 'MISSED', NOW()-INTERVAL '87 days', NULL,
 '{"daysPastMissedDate":0}'::jsonb),

-- P07 anc-visit-3 OVERDUE (openhim-only patient)
('de000006-0000-0000-0000-000000000001',
 '01000007-0000-0000-0000-000000000001',
 '51000032-0000-0000-0000-000000000001',
 'OVERDUE', NOW()-INTERVAL '18 days', NULL,
 '{"daysOverdue":7}'::jsonb),

-- P08 anc-visit-1 MISSED (openhim-only patient — no direct coverage)
('de000007-0000-0000-0000-000000000001',
 '01000008-0000-0000-0000-000000000001',
 '51000034-0000-0000-0000-000000000001',
 'MISSED', NOW()-INTERVAL '61 days', NULL,
 '{"daysPastMissedDate":0}'::jsonb),

-- P08 anc-visit-2 MISSED
('de000008-0000-0000-0000-000000000001',
 '01000008-0000-0000-0000-000000000001',
 '51000035-0000-0000-0000-000000000001',
 'MISSED', NOW()-INTERVAL '33 days', NULL,
 '{"daysPastMissedDate":0}'::jsonb),

-- P08 anc-visit-3 OVERDUE
('de000009-0000-0000-0000-000000000001',
 '01000008-0000-0000-0000-000000000001',
 '51000036-0000-0000-0000-000000000001',
 'OVERDUE', NOW()-INTERVAL '7 days', NULL,
 '{"daysOverdue":7}'::jsonb),

-- P12 htn-followup-1 MISSED (source mismatch — openhim rejected)
('de000010-0000-0000-0000-000000000001',
 '01000012-0000-0000-0000-000000000001',
 '51000047-0000-0000-0000-000000000001',
 'MISSED', NOW()-INTERVAL '44 days', NULL,
 '{"daysPastMissedDate":0}'::jsonb),

-- P12 htn-followup-2 MISSED
('de000011-0000-0000-0000-000000000001',
 '01000012-0000-0000-0000-000000000001',
 '51000048-0000-0000-0000-000000000001',
 'MISSED', NOW()-INTERVAL '14 days', NULL,
 '{"daysPastMissedDate":0}'::jsonb),

-- P12 htn-followup-3 OVERDUE
('de000012-0000-0000-0000-000000000001',
 '01000012-0000-0000-0000-000000000001',
 '51000049-0000-0000-0000-000000000001',
 'OVERDUE', NOW()-INTERVAL '5 days', NULL,
 '{"daysOverdue":3}'::jsonb),

-- P06 htn-followup-3 DUE → OVERDUE transition
('de000013-0000-0000-0000-000000000001',
 '01000006-0000-0000-0000-000000000001',
 '51000028-0000-0000-0000-000000000001',
 'OVERDUE', NOW()-INTERVAL '7 days', NULL,
 '{"daysOverdue":7}'::jsonb)
ON CONFLICT DO NOTHING;


-- ─────────────────────────────────────────────────────────────────────────────
\echo '--- [2/6] Inserting event_log records ---'
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO event_log (
    id, cloudevents_id, source, source_event_id, subject, type,
    event_time, received_at, correlation_id, data,
    protocol_instance_id, protocol_definition_id, action_id, facility_id,
    processing_status, matched_step_instance_id
) VALUES

-- P01 enrollment
('e1000001-0000-0000-0000-000000000001','evt-eb-d-0001','ebuzima-direct','src-d-1001',
 '260225-0001-1001','org.openphc.cce.encounter',
 NOW()-INTERVAL '175 days',NOW()-INTERVAL '175 days','corr-d-000001',
 '{"resourceType":"Encounter","id":"enc-p01-v1","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1001"}}'::jsonb,
 '01000001-0000-0000-0000-000000000001','0d000001-0000-0000-0000-000000000001',
 'anc-enrollment','FAC-0001','MATCHED',
 '51000001-0000-0000-0000-000000000001'),

-- P01 ANC visit-1
('e1000002-0000-0000-0000-000000000001','evt-eb-d-0002','ebuzima-direct','src-d-1002',
 '260225-0001-1001','org.openphc.cce.encounter',
 NOW()-INTERVAL '133 days',NOW()-INTERVAL '133 days','corr-d-000002',
 '{"resourceType":"Encounter","id":"enc-p01-v2","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1001"}}'::jsonb,
 '01000001-0000-0000-0000-000000000001','0d000001-0000-0000-0000-000000000001',
 'anc-visit-1','FAC-0001','MATCHED',
 '51000002-0000-0000-0000-000000000001'),

-- P01 ANC visit-2
('e1000003-0000-0000-0000-000000000001','evt-eb-d-0003','ebuzima-direct','src-d-1003',
 '260225-0001-1001','org.openphc.cce.encounter',
 NOW()-INTERVAL '91 days',NOW()-INTERVAL '91 days','corr-d-000003',
 '{"resourceType":"Encounter","id":"enc-p01-v3","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1001"}}'::jsonb,
 '01000001-0000-0000-0000-000000000001','0d000001-0000-0000-0000-000000000001',
 'anc-visit-2','FAC-0001','MATCHED',
 '51000003-0000-0000-0000-000000000001'),

-- P01 BP check
('e1000004-0000-0000-0000-000000000001','evt-eb-d-0004','ebuzima-direct','src-d-1004',
 '260225-0001-1001','org.openphc.cce.observation',
 NOW()-INTERVAL '91 days',NOW()-INTERVAL '91 days','corr-d-000004',
 '{"resourceType":"Observation","id":"obs-p01-bp3","status":"final",
   "code":{"coding":[{"system":"http://loinc.org","code":"55284-4"}]},
   "subject":{"reference":"Patient/260225-0001-1001"},
   "valueQuantity":{"value":138,"unit":"mmHg"}}'::jsonb,
 '01000001-0000-0000-0000-000000000001','0d000001-0000-0000-0000-000000000001',
 'anc-bp-check','FAC-0001','MATCHED',
 '51000004-0000-0000-0000-000000000001'),

-- P02 enrollment
('e1000005-0000-0000-0000-000000000001','evt-eb-d-0005','ebuzima-direct','src-d-2001',
 '260225-0001-1002','org.openphc.cce.encounter',
 NOW()-INTERVAL '168 days',NOW()-INTERVAL '168 days','corr-d-000005',
 '{"resourceType":"Encounter","id":"enc-p02-v1","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1002"}}'::jsonb,
 '01000002-0000-0000-0000-000000000001','0d000001-0000-0000-0000-000000000001',
 'anc-enrollment','FAC-0001','MATCHED',
 '51000007-0000-0000-0000-000000000001'),

-- P02 ANC visit-1
('e1000006-0000-0000-0000-000000000001','evt-eb-d-0006','ebuzima-direct','src-d-2002',
 '260225-0001-1002','org.openphc.cce.encounter',
 NOW()-INTERVAL '126 days',NOW()-INTERVAL '126 days','corr-d-000006',
 '{"resourceType":"Encounter","id":"enc-p02-v2","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1002"}}'::jsonb,
 '01000002-0000-0000-0000-000000000001','0d000001-0000-0000-0000-000000000001',
 'anc-visit-1','FAC-0001','MATCHED',
 '51000008-0000-0000-0000-000000000001'),

-- P02 ANC visit-2 (late)
('e1000007-0000-0000-0000-000000000001','evt-eb-d-0007','ebuzima-direct','src-d-2003',
 '260225-0001-1002','org.openphc.cce.encounter',
 NOW()-INTERVAL '62 days',NOW()-INTERVAL '62 days','corr-d-000007',
 '{"resourceType":"Encounter","id":"enc-p02-v3","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1002"}}'::jsonb,
 '01000002-0000-0000-0000-000000000001','0d000001-0000-0000-0000-000000000001',
 'anc-visit-2','FAC-0001','MATCHED',
 '51000009-0000-0000-0000-000000000001'),

-- P03 enrollment
('e1000008-0000-0000-0000-000000000001','evt-eb-d-0008','ebuzima-direct','src-d-3001',
 '260225-0001-1003','org.openphc.cce.encounter',
 NOW()-INTERVAL '155 days',NOW()-INTERVAL '155 days','corr-d-000008',
 '{"resourceType":"Encounter","id":"enc-p03-v1","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1003"}}'::jsonb,
 '01000003-0000-0000-0000-000000000001','0d000001-0000-0000-0000-000000000001',
 'anc-enrollment','FAC-0001','MATCHED',
 '51000011-0000-0000-0000-000000000001'),

-- openhim P01 visit from FAC-0002 → ZERO_MATCH (same patient, different facility, duplicate content)
('e1000009-0000-0000-0000-000000000001','evt-eb-oh-0001','ebuzima','src-oh-1001',
 '260225-0001-1001','org.openphc.cce.encounter',
 NOW()-INTERVAL '175 days',NOW()-INTERVAL '175 days','corr-oh-000001',
 '{"resourceType":"Encounter","id":"enc-p01-v1-oh","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1001"}}'::jsonb,
 '01000001-0000-0000-0000-000000000001','0d000001-0000-0000-0000-000000000001',
 'anc-enrollment','FAC-0002','DUPLICATE',
 NULL),

-- openhim P01 visit-4 (only in openhim, ZERO_MATCH — no step pending)
('e1000010-0000-0000-0000-000000000001','evt-eb-oh-0002','ebuzima','src-oh-1002',
 '260225-0001-1001','org.openphc.cce.encounter',
 NOW()-INTERVAL '49 days',NOW()-INTERVAL '49 days','corr-oh-000002',
 '{"resourceType":"Encounter","id":"enc-p01-v4-oh","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1001"}}'::jsonb,
 NULL,NULL,NULL,'FAC-0002','ZERO_MATCH',NULL),

-- P02 openhim MATCHED (enrollment duplicate)
('e1000011-0000-0000-0000-000000000001','evt-eb-oh-0003','ebuzima','src-oh-2001',
 '260225-0001-1002','org.openphc.cce.encounter',
 NOW()-INTERVAL '168 days',NOW()-INTERVAL '168 days','corr-oh-000003',
 '{"resourceType":"Encounter","id":"enc-p02-v1-oh","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1002"}}'::jsonb,
 '01000002-0000-0000-0000-000000000001','0d000001-0000-0000-0000-000000000001',
 'anc-enrollment','FAC-0002','DUPLICATE',NULL),

-- P04 EPI enrollment
('e1000012-0000-0000-0000-000000000001','evt-eb-oh-0004','ebuzima','src-oh-4001',
 '260225-0002-2001','org.openphc.cce.immunization',
 NOW()-INTERVAL '160 days',NOW()-INTERVAL '160 days','corr-oh-000004',
 '{"resourceType":"Immunization","id":"imm-p04-bcg","status":"completed",
   "vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"19","display":"BCG"}]},
   "patient":{"reference":"Patient/260225-0002-2001"}}'::jsonb,
 '01000004-0000-0000-0000-000000000001','0d000002-0000-0000-0000-000000000001',
 'epi-enrollment','FAC-0002','MATCHED',
 '51000015-0000-0000-0000-000000000001'),

-- P04 OPV0
('e1000013-0000-0000-0000-000000000001','evt-eb-oh-0005','ebuzima','src-oh-4002',
 '260225-0002-2001','org.openphc.cce.immunization',
 NOW()-INTERVAL '118 days',NOW()-INTERVAL '118 days','corr-oh-000005',
 '{"resourceType":"Immunization","id":"imm-p04-opv0","status":"completed",
   "vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"02","display":"OPV"}]},
   "patient":{"reference":"Patient/260225-0002-2001"}}'::jsonb,
 '01000004-0000-0000-0000-000000000001','0d000002-0000-0000-0000-000000000001',
 'epi-opv0','FAC-0002','MATCHED',
 '51000016-0000-0000-0000-000000000001'),

-- P04 Penta1
('e1000014-0000-0000-0000-000000000001','evt-eb-oh-0006','ebuzima','src-oh-4003',
 '260225-0002-2001','org.openphc.cce.immunization',
 NOW()-INTERVAL '76 days',NOW()-INTERVAL '76 days','corr-oh-000006',
 '{"resourceType":"Immunization","id":"imm-p04-penta1","status":"completed",
   "vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"132","display":"Pentavalent"}]},
   "patient":{"reference":"Patient/260225-0002-2001"}}'::jsonb,
 '01000004-0000-0000-0000-000000000001','0d000002-0000-0000-0000-000000000001',
 'epi-penta1','FAC-0002','MATCHED',
 '51000017-0000-0000-0000-000000000001'),

-- P04 Penta2
('e1000015-0000-0000-0000-000000000001','evt-eb-oh-0061','ebuzima','src-oh-4004',
 '260225-0002-2001','org.openphc.cce.immunization',
 NOW()-INTERVAL '34 days',NOW()-INTERVAL '34 days','corr-oh-034001',
 '{"resourceType":"Immunization","id":"imm-p04-penta2","status":"completed",
   "vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"132","display":"Pentavalent"}]},
   "patient":{"reference":"Patient/260225-0002-2001"}}'::jsonb,
 '01000004-0000-0000-0000-000000000001','0d000002-0000-0000-0000-000000000001',
 'epi-penta2','FAC-0002','MATCHED',
 '51000018-0000-0000-0000-000000000001'),

-- P05 BCG
('e1000016-0000-0000-0000-000000000001','evt-eb-oh-0007','ebuzima','src-oh-5001',
 '260225-0002-2002','org.openphc.cce.immunization',
 NOW()-INTERVAL '150 days',NOW()-INTERVAL '150 days','corr-oh-000007',
 '{"resourceType":"Immunization","id":"imm-p05-bcg","status":"completed",
   "vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"19","display":"BCG"}]},
   "patient":{"reference":"Patient/260225-0002-2002"}}'::jsonb,
 '01000005-0000-0000-0000-000000000001','0d000002-0000-0000-0000-000000000001',
 'epi-enrollment','FAC-0002','MATCHED',
 '51000020-0000-0000-0000-000000000001'),

-- P05 OPV0
('e1000017-0000-0000-0000-000000000001','evt-eb-oh-0062','ebuzima','src-oh-5002',
 '260225-0002-2002','org.openphc.cce.immunization',
 NOW()-INTERVAL '108 days',NOW()-INTERVAL '108 days','corr-oh-108001',
 '{"resourceType":"Immunization","id":"imm-p05-opv0","status":"completed",
   "vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"02","display":"OPV"}]},
   "patient":{"reference":"Patient/260225-0002-2002"}}'::jsonb,
 '01000005-0000-0000-0000-000000000001','0d000002-0000-0000-0000-000000000001',
 'epi-opv0','FAC-0002','MATCHED',
 '51000021-0000-0000-0000-000000000001'),

-- P06 HTN enrollment
('e1000018-0000-0000-0000-000000000001','evt-eb-oh-0008','ebuzima','src-oh-6001',
 '260225-0003-3001','org.openphc.cce.encounter',
 NOW()-INTERVAL '140 days',NOW()-INTERVAL '140 days','corr-oh-000008',
 '{"resourceType":"Encounter","id":"enc-p06-htn1","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"htn-followup"}]}],
   "subject":{"reference":"Patient/260225-0003-3001"}}'::jsonb,
 '01000006-0000-0000-0000-000000000001','0d000003-0000-0000-0000-000000000001',
 'htn-enrollment','FAC-0003','MATCHED',
 '51000024-0000-0000-0000-000000000001'),

-- P06 HTN followup-1
('e1000019-0000-0000-0000-000000000001','evt-eb-oh-0010','ebuzima','src-oh-6003',
 '260225-0003-3001','org.openphc.cce.encounter',
 NOW()-INTERVAL '98 days',NOW()-INTERVAL '98 days','corr-oh-000010',
 '{"resourceType":"Encounter","id":"enc-p06-htn2","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"htn-followup"}]}],
   "subject":{"reference":"Patient/260225-0003-3001"}}'::jsonb,
 '01000006-0000-0000-0000-000000000001','0d000003-0000-0000-0000-000000000001',
 'htn-followup-1','FAC-0003','MATCHED',
 '51000025-0000-0000-0000-000000000001'),

-- P06 HTN followup-2 (via direct)
('e1000020-0000-0000-0000-000000000001','evt-eb-d-0050','ebuzima-direct','src-d-6004',
 '260225-0003-3001','org.openphc.cce.encounter',
 NOW()-INTERVAL '56 days',NOW()-INTERVAL '56 days','corr-d-056001',
 '{"resourceType":"Encounter","id":"enc-p06-htn3","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"htn-followup"}]}],
   "subject":{"reference":"Patient/260225-0003-3001"}}'::jsonb,
 '01000006-0000-0000-0000-000000000001','0d000003-0000-0000-0000-000000000001',
 'htn-followup-2','FAC-0003','MATCHED',
 '51000026-0000-0000-0000-000000000001'),

-- P06 BP check (recent, via direct)
('e1000021-0000-0000-0000-000000000001','evt-eb-d-1002','ebuzima-direct','src-d-6006',
 '260225-0003-3001','org.openphc.cce.observation',
 NOW()-INTERVAL '2 days',NOW()-INTERVAL '2 days','corr-d-1002',
 '{"resourceType":"Observation","id":"obs-p06-bp4","status":"final",
   "code":{"coding":[{"system":"http://loinc.org","code":"55284-4"}]},
   "subject":{"reference":"Patient/260225-0003-3001"},
   "valueQuantity":{"value":128,"unit":"mmHg"}}'::jsonb,
 '01000006-0000-0000-0000-000000000001','0d000003-0000-0000-0000-000000000001',
 'htn-bp-check','FAC-0003','MATCHED',
 '51000027-0000-0000-0000-000000000001'),

-- P07 enrollment (openhim only)
('e1000022-0000-0000-0000-000000000001','evt-eb-oh-0011','ebuzima','src-oh-7001',
 '260225-0003-3002','org.openphc.cce.encounter',
 NOW()-INTERVAL '145 days',NOW()-INTERVAL '145 days','corr-oh-000011',
 '{"resourceType":"Encounter","id":"enc-p07-anc1","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0003-3002"}}'::jsonb,
 '01000007-0000-0000-0000-000000000001','0d000001-0000-0000-0000-000000000001',
 'anc-enrollment','FAC-0003','MATCHED',
 '51000029-0000-0000-0000-000000000001'),

-- P07 ANC visit-1
('e1000023-0000-0000-0000-000000000001','evt-eb-oh-0012','ebuzima','src-oh-7002',
 '260225-0003-3002','org.openphc.cce.encounter',
 NOW()-INTERVAL '103 days',NOW()-INTERVAL '103 days','corr-oh-000012',
 '{"resourceType":"Encounter","id":"enc-p07-anc2","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0003-3002"}}'::jsonb,
 '01000007-0000-0000-0000-000000000001','0d000001-0000-0000-0000-000000000001',
 'anc-visit-1','FAC-0003','MATCHED',
 '51000030-0000-0000-0000-000000000001'),

-- P07 ANC visit-2
('e1000024-0000-0000-0000-000000000001','evt-eb-oh-0060','ebuzima','src-oh-7003',
 '260225-0003-3002','org.openphc.cce.encounter',
 NOW()-INTERVAL '61 days',NOW()-INTERVAL '61 days','corr-oh-061001',
 '{"resourceType":"Encounter","id":"enc-p07-anc3","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0003-3002"}}'::jsonb,
 '01000007-0000-0000-0000-000000000001','0d000001-0000-0000-0000-000000000001',
 'anc-visit-2','FAC-0003','MATCHED',
 '51000031-0000-0000-0000-000000000001'),

-- P08 enrollment (openhim only)
('e1000025-0000-0000-0000-000000000001','evt-eb-oh-0013','ebuzima','src-oh-8001',
 '260225-0003-3003','org.openphc.cce.encounter',
 NOW()-INTERVAL '138 days',NOW()-INTERVAL '138 days','corr-oh-000013',
 '{"resourceType":"Encounter","id":"enc-p08-anc1","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0003-3003"}}'::jsonb,
 '01000008-0000-0000-0000-000000000001','0d000001-0000-0000-0000-000000000001',
 'anc-enrollment','FAC-0003','MATCHED',
 '51000033-0000-0000-0000-000000000001'),

-- P09 EPI enrollment (openhim only)
('e1000026-0000-0000-0000-000000000001','evt-eb-oh-0014','ebuzima','src-oh-9001',
 '260225-0004-4001','org.openphc.cce.immunization',
 NOW()-INTERVAL '130 days',NOW()-INTERVAL '130 days','corr-oh-000014',
 '{"resourceType":"Immunization","id":"imm-p09-bcg","status":"completed",
   "vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"19","display":"BCG"}]},
   "patient":{"reference":"Patient/260225-0004-4001"}}'::jsonb,
 '01000009-0000-0000-0000-000000000001','0d000002-0000-0000-0000-000000000001',
 'epi-enrollment','FAC-0004','MATCHED',
 '51000037-0000-0000-0000-000000000001'),

-- P09 OPV0 (recent, via openhim)
('e1000027-0000-0000-0000-000000000001','evt-eb-oh-1001','ebuzima','src-oh-9002',
 '260225-0004-4001','org.openphc.cce.immunization',
 NOW()-INTERVAL '3 days',NOW()-INTERVAL '3 days','corr-oh-1001',
 '{"resourceType":"Immunization","id":"imm-p09-opv0","status":"completed",
   "vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"02","display":"OPV"}]},
   "patient":{"reference":"Patient/260225-0004-4001"}}'::jsonb,
 '01000009-0000-0000-0000-000000000001','0d000002-0000-0000-0000-000000000001',
 'epi-opv0','FAC-0004','MATCHED',
 '51000038-0000-0000-0000-000000000001'),

-- P10 enrollment (direct only; openhim rejected — MS-2)
('e1000028-0000-0000-0000-000000000001','evt-eb-d-0020','ebuzima-direct','src-d-10001',
 '260225-0004-4002','org.openphc.cce.encounter',
 NOW()-INTERVAL '120 days',NOW()-INTERVAL '120 days','corr-d-020001',
 '{"resourceType":"Encounter","id":"enc-p10-anc1","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0004-4002"}}'::jsonb,
 '01000010-0000-0000-0000-000000000001','0d000001-0000-0000-0000-000000000001',
 'anc-enrollment','FAC-0004','MATCHED',
 '51000040-0000-0000-0000-000000000001'),

-- P10 visit-1 (direct)
('e1000029-0000-0000-0000-000000000001','evt-eb-d-0021','ebuzima-direct','src-d-10002',
 '260225-0004-4002','org.openphc.cce.encounter',
 NOW()-INTERVAL '78 days',NOW()-INTERVAL '78 days','corr-d-020002',
 '{"resourceType":"Encounter","id":"enc-p10-anc2","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0004-4002"}}'::jsonb,
 '01000010-0000-0000-0000-000000000001','0d000001-0000-0000-0000-000000000001',
 'anc-visit-1','FAC-0004','MATCHED',
 '51000041-0000-0000-0000-000000000001'),

-- P11 enrollment (dual source — direct first)
('e1000030-0000-0000-0000-000000000001','evt-shared-0001','ebuzima-direct','src-d-11001',
 '260225-0004-4003','org.openphc.cce.encounter',
 NOW()-INTERVAL '110 days',NOW()-INTERVAL '110 days','corr-d-030001',
 '{"resourceType":"Encounter","id":"enc-p11-anc1","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0004-4003"}}'::jsonb,
 '01000011-0000-0000-0000-000000000001','0d000001-0000-0000-0000-000000000001',
 'anc-enrollment','FAC-0004','MATCHED',
 '51000043-0000-0000-0000-000000000001'),

-- P11 visit-1 (direct only — openhim gap)
('e1000031-0000-0000-0000-000000000001','evt-eb-d-0030','ebuzima-direct','src-d-11002',
 '260225-0004-4003','org.openphc.cce.encounter',
 NOW()-INTERVAL '68 days',NOW()-INTERVAL '68 days','corr-d-030003',
 '{"resourceType":"Encounter","id":"enc-p11-anc2","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0004-4003"}}'::jsonb,
 '01000011-0000-0000-0000-000000000001','0d000001-0000-0000-0000-000000000001',
 'anc-visit-1','FAC-0004','MATCHED',
 '51000044-0000-0000-0000-000000000001'),

-- P12 HTN enrollment (direct; openhim MISSING_SUBJECT — MS-4)
('e1000032-0000-0000-0000-000000000001','evt-eb-d-0040','ebuzima-direct','src-d-12001',
 '260225-0004-4004','org.openphc.cce.observation',
 NOW()-INTERVAL '95 days',NOW()-INTERVAL '95 days','corr-d-040001',
 '{"resourceType":"Observation","id":"obs-p12-bp1","status":"final",
   "code":{"coding":[{"system":"http://loinc.org","code":"55284-4"}]},
   "subject":{"reference":"Patient/260225-0004-4004"},
   "valueQuantity":{"value":145,"unit":"mmHg"}}'::jsonb,
 '01000012-0000-0000-0000-000000000001','0d000003-0000-0000-0000-000000000001',
 'htn-enrollment','FAC-0004','MATCHED',
 '51000046-0000-0000-0000-000000000001'),

-- P02 recent ANC (last 7 days)
('e1000033-0000-0000-0000-000000000001','evt-eb-d-1001','ebuzima-direct','src-d-2004',
 '260225-0001-1002','org.openphc.cce.encounter',
 NOW()-INTERVAL '5 days',NOW()-INTERVAL '5 days','corr-d-1001',
 '{"resourceType":"Encounter","id":"enc-p02-v4","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1002"}}'::jsonb,
 '01000002-0000-0000-0000-000000000001','0d000001-0000-0000-0000-000000000001',
 'anc-visit-3','FAC-0001','MATCHED',
 '51000010-0000-0000-0000-000000000001'),

-- Orphan ZERO_MATCH event (openhim BP with no matching protocol step)
('e1000034-0000-0000-0000-000000000001','evt-eb-oh-0009','ebuzima','src-oh-6002',
 '260225-0003-3001','org.openphc.cce.observation',
 NOW()-INTERVAL '140 days',NOW()-INTERVAL '140 days','corr-oh-000009',
 '{"resourceType":"Observation","id":"obs-p06-bp1","status":"final",
   "code":{"coding":[{"system":"http://loinc.org","code":"55284-4"}]},
   "subject":{"reference":"Patient/260225-0003-3001"},
   "valueQuantity":{"value":162,"unit":"mmHg"}}'::jsonb,
 NULL,NULL,NULL,'FAC-0003','ZERO_MATCH',NULL)
ON CONFLICT DO NOTHING;


-- ─────────────────────────────────────────────────────────────────────────────
\echo '--- [2/7] Inserting audit_log records ---'
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO audit_log (
    id, event_category, event_type, actor, resource_type,
    resource_id, details, ip_address, timestamp
) VALUES

-- Protocol loads
('a1000001-0000-0000-0000-000000000001',
 'PROTOCOL_MANAGEMENT','PROTOCOL_LOADED','admin@openphc.org',
 'ProtocolDefinition','0d000001-0000-0000-0000-000000000001',
 '{"url":"http://openphc.org/fhir/PlanDefinition/anc-high-risk","version":"1.0",
   "actionCount":6,"triggerIndexEntries":6}'::jsonb,
 '10.0.1.5', NOW()-INTERVAL '200 days'),

('a1000002-0000-0000-0000-000000000001',
 'PROTOCOL_MANAGEMENT','PROTOCOL_LOADED','admin@openphc.org',
 'ProtocolDefinition','0d000002-0000-0000-0000-000000000001',
 '{"url":"http://openphc.org/fhir/PlanDefinition/epi-child-0-5","version":"1.0",
   "actionCount":6,"triggerIndexEntries":5}'::jsonb,
 '10.0.1.5', NOW()-INTERVAL '200 days'),

('a1000003-0000-0000-0000-000000000001',
 'PROTOCOL_MANAGEMENT','PROTOCOL_LOADED','admin@openphc.org',
 'ProtocolDefinition','0d000003-0000-0000-0000-000000000001',
 '{"url":"http://openphc.org/fhir/PlanDefinition/htn-management","version":"1.0",
   "actionCount":5,"triggerIndexEntries":5}'::jsonb,
 '10.0.1.5', NOW()-INTERVAL '200 days'),

-- Enrollment audit entries
('a1000004-0000-0000-0000-000000000001',
 'COMPLIANCE','PROTOCOL_ENROLLED','SYSTEM',
 'ProtocolInstance','01000001-0000-0000-0000-000000000001',
 ('{"patientId":"260225-0001-1001","protocolUrl":"http://openphc.org/fhir/PlanDefinition/anc-high-risk",
   "enrolledAt":"'||(NOW()-INTERVAL '175 days')::text||'"}'  )::jsonb,
 NULL, NOW()-INTERVAL '175 days'),

('a1000005-0000-0000-0000-000000000001',
 'COMPLIANCE','PROTOCOL_ENROLLED','SYSTEM',
 'ProtocolInstance','01000004-0000-0000-0000-000000000001',
 ('{"patientId":"260225-0002-2001","protocolUrl":"http://openphc.org/fhir/PlanDefinition/epi-child-0-5",
   "enrolledAt":"'||(NOW()-INTERVAL '160 days')::text||'"}'  )::jsonb,
 NULL, NOW()-INTERVAL '160 days'),

('a1000006-0000-0000-0000-000000000001',
 'COMPLIANCE','PROTOCOL_ENROLLED','SYSTEM',
 'ProtocolInstance','01000006-0000-0000-0000-000000000001',
 ('{"patientId":"260225-0003-3001","protocolUrl":"http://openphc.org/fhir/PlanDefinition/htn-management",
   "enrolledAt":"'||(NOW()-INTERVAL '140 days')::text||'"}'  )::jsonb,
 NULL, NOW()-INTERVAL '140 days'),

-- Step completion audit entries
('a1000007-0000-0000-0000-000000000001',
 'COMPLIANCE','STEP_COMPLETED','SYSTEM',
 'StepInstance','51000001-0000-0000-0000-000000000001',
 '{"protocolInstanceId":"pi000001-0000-0000-0000-000000000001","actionId":"anc-enrollment",
   "completionStatus":"ON_TIME","completedBySource":"ebuzima-direct"}'::jsonb,
 NULL, NOW()-INTERVAL '175 days'),

('a1000008-0000-0000-0000-000000000001',
 'COMPLIANCE','STEP_COMPLETED','SYSTEM',
 'StepInstance','51000002-0000-0000-0000-000000000001',
 '{"protocolInstanceId":"pi000001-0000-0000-0000-000000000001","actionId":"anc-visit-1",
   "completionStatus":"LATE","completedBySource":"ebuzima-direct"}'::jsonb,
 NULL, NOW()-INTERVAL '133 days'),

('a1000009-0000-0000-0000-000000000001',
 'COMPLIANCE','STEP_COMPLETED','SYSTEM',
 'StepInstance','51000015-0000-0000-0000-000000000001',
 '{"protocolInstanceId":"pi000004-0000-0000-0000-000000000001","actionId":"epi-enrollment",
   "completionStatus":"ON_TIME","completedBySource":"ebuzima"}'::jsonb,
 NULL, NOW()-INTERVAL '160 days'),

('a1000010-0000-0000-0000-000000000001',
 'COMPLIANCE','STEP_COMPLETED','SYSTEM',
 'StepInstance','51000024-0000-0000-0000-000000000001',
 '{"protocolInstanceId":"pi000006-0000-0000-0000-000000000001","actionId":"htn-enrollment",
   "completionStatus":"ON_TIME","completedBySource":"ebuzima"}'::jsonb,
 NULL, NOW()-INTERVAL '140 days'),

-- Deviation detection audit entries
('a1000011-0000-0000-0000-000000000001',
 'COMPLIANCE','DEVIATION_DETECTED','SYSTEM',
 'Deviation','de000001-0000-0000-0000-000000000001',
 '{"protocolInstanceId":"pi000001-0000-0000-0000-000000000001","stepInstanceId":"si000005-0000-0000-0000-000000000001",
   "deviationType":"OVERDUE","actionId":"anc-visit-3","patientId":"260225-0001-1001",
   "daysOverdue":7}'::jsonb,
 NULL, NOW()-INTERVAL '28 days'),

('a1000012-0000-0000-0000-000000000001',
 'COMPLIANCE','DEVIATION_DETECTED','SYSTEM',
 'Deviation','de000002-0000-0000-0000-000000000001',
 '{"protocolInstanceId":"pi000003-0000-0000-0000-000000000001","stepInstanceId":"si000012-0000-0000-0000-000000000001",
   "deviationType":"MISSED","actionId":"anc-visit-1","patientId":"260225-0001-1003",
   "daysPastMissedDate":0}'::jsonb,
 NULL, NOW()-INTERVAL '78 days'),

('a1000013-0000-0000-0000-000000000001',
 'COMPLIANCE','DEVIATION_DETECTED','SYSTEM',
 'Deviation','de000005-0000-0000-0000-000000000001',
 '{"protocolInstanceId":"pi000005-0000-0000-0000-000000000001","stepInstanceId":"si000022-0000-0000-0000-000000000001",
   "deviationType":"MISSED","actionId":"epi-penta1","patientId":"260225-0002-2002",
   "daysPastMissedDate":0}'::jsonb,
 NULL, NOW()-INTERVAL '87 days'),

('a1000014-0000-0000-0000-000000000001',
 'COMPLIANCE','DEVIATION_DETECTED','SYSTEM',
 'Deviation','de000010-0000-0000-0000-000000000001',
 '{"protocolInstanceId":"pi000012-0000-0000-0000-000000000001","stepInstanceId":"si000047-0000-0000-0000-000000000001",
   "deviationType":"MISSED","actionId":"htn-followup-1","patientId":"260225-0004-4004",
   "note":"openhim source rejected INVALID_FHIR; direct source gap"}'::jsonb,
 NULL, NOW()-INTERVAL '44 days'),

-- Security / API events
('a1000015-0000-0000-0000-000000000001',
 'SECURITY','USER_LOGIN','insights-ui@openphc.org',
 NULL,NULL,
 '{"method":"JWT","userAgent":"Mozilla/5.0"}'::jsonb,
 '196.207.11.42', NOW()-INTERVAL '7 days'),

('a1000016-0000-0000-0000-000000000001',
 'SECURITY','USER_LOGIN','insights-ui@openphc.org',
 NULL,NULL,
 '{"method":"JWT","userAgent":"Mozilla/5.0"}'::jsonb,
 '196.207.11.42', NOW()-INTERVAL '1 day'),

-- Protocol status check
('a1000017-0000-0000-0000-000000000001',
 'PROTOCOL_MANAGEMENT','PROTOCOL_STATUS_QUERIED','insights-api',
 'ProtocolDefinition','0d000001-0000-0000-0000-000000000001',
 '{"action":"list-active-protocols","resultCount":3}'::jsonb,
 NULL, NOW()-INTERVAL '1 day'),

-- Step state transitions (scheduler)
('a1000018-0000-0000-0000-000000000001',
 'COMPLIANCE','STEP_STATE_TRANSITIONED','SYSTEM',
 'StepInstance','51000005-0000-0000-0000-000000000001',
 '{"from":"DUE","to":"OVERDUE","actionId":"anc-visit-3",
   "patientId":"260225-0001-1001","trigger":"scheduler"}'::jsonb,
 NULL, NOW()-INTERVAL '28 days'),

('a1000019-0000-0000-0000-000000000001',
 'COMPLIANCE','STEP_STATE_TRANSITIONED','SYSTEM',
 'StepInstance','51000012-0000-0000-0000-000000000001',
 '{"from":"OVERDUE","to":"MISSED","actionId":"anc-visit-1",
   "patientId":"260225-0001-1003","trigger":"scheduler"}'::jsonb,
 NULL, NOW()-INTERVAL '78 days'),

('a1000020-0000-0000-0000-000000000001',
 'COMPLIANCE','STEP_STATE_TRANSITIONED','SYSTEM',
 'StepInstance','51000022-0000-0000-0000-000000000001',
 '{"from":"OVERDUE","to":"MISSED","actionId":"epi-penta1",
   "patientId":"260225-0002-2002","trigger":"scheduler"}'::jsonb,
 NULL, NOW()-INTERVAL '87 days')
ON CONFLICT DO NOTHING;


-- =============================================================================
-- SECTION 3 : ENRICHMENTS — Practitioner data & additional volume
-- =============================================================================
-- Adds practitioner references to event_log FHIR data for "Events > By Practitioner" tab.
-- Adds more inbound_event records for smoother trend curves and richer source comparison.
-- Practitioners:
--   prac-001  Dr. Mwila Banda       FAC-0001 (ANC direct)
--   prac-002  Dr. Chola Mwansa      FAC-0002 (EPI openhim)
--   prac-003  Nurse Tembo Kasonde   FAC-0003 (HTN/ANC openhim)
--   prac-004  Dr. Ndiaye Mutale     FAC-0004 (mixed)
-- =============================================================================

\echo '--- [3/1] Enriching event_log with practitioner references ---'

-- FAC-0001 Encounters → Dr. Mwila Banda
UPDATE event_log SET data = data || '{"participant":[{"individual":{"reference":"Practitioner/prac-001","display":"Dr. Mwila Banda"}}]}'::jsonb
WHERE id IN (
  'e1000001-0000-0000-0000-000000000001',
  'e1000002-0000-0000-0000-000000000001',
  'e1000003-0000-0000-0000-000000000001',
  'e1000005-0000-0000-0000-000000000001',
  'e1000006-0000-0000-0000-000000000001',
  'e1000007-0000-0000-0000-000000000001',
  'e1000008-0000-0000-0000-000000000001',
  'e1000033-0000-0000-0000-000000000001'
) AND data->>'resourceType' = 'Encounter';

-- FAC-0001 Observations → Dr. Mwila Banda
UPDATE event_log SET data = data || '{"performer":[{"reference":"Practitioner/prac-001","display":"Dr. Mwila Banda"}]}'::jsonb
WHERE id IN (
  'e1000004-0000-0000-0000-000000000001'
) AND data->>'resourceType' = 'Observation';

-- FAC-0002 openhim Encounters → Dr. Chola Mwansa
UPDATE event_log SET data = data || '{"participant":[{"individual":{"reference":"Practitioner/prac-002","display":"Dr. Chola Mwansa"}}]}'::jsonb
WHERE id IN (
  'e1000009-0000-0000-0000-000000000001',
  'e1000010-0000-0000-0000-000000000001',
  'e1000011-0000-0000-0000-000000000001'
) AND data->>'resourceType' = 'Encounter';

-- FAC-0002 Immunizations → Dr. Chola Mwansa
UPDATE event_log SET data = data || '{"performer":[{"actor":{"reference":"Practitioner/prac-002","display":"Dr. Chola Mwansa"}}]}'::jsonb
WHERE id IN (
  'e1000012-0000-0000-0000-000000000001',
  'e1000013-0000-0000-0000-000000000001',
  'e1000014-0000-0000-0000-000000000001',
  'e1000015-0000-0000-0000-000000000001',
  'e1000016-0000-0000-0000-000000000001',
  'e1000017-0000-0000-0000-000000000001'
) AND data->>'resourceType' = 'Immunization';

-- FAC-0003 Encounters → Nurse Tembo Kasonde
UPDATE event_log SET data = data || '{"participant":[{"individual":{"reference":"Practitioner/prac-003","display":"Nurse Tembo Kasonde"}}]}'::jsonb
WHERE id IN (
  'e1000018-0000-0000-0000-000000000001',
  'e1000019-0000-0000-0000-000000000001',
  'e1000020-0000-0000-0000-000000000001',
  'e1000022-0000-0000-0000-000000000001',
  'e1000023-0000-0000-0000-000000000001',
  'e1000024-0000-0000-0000-000000000001',
  'e1000025-0000-0000-0000-000000000001'
) AND data->>'resourceType' = 'Encounter';

-- FAC-0003 Observations → Nurse Tembo Kasonde
UPDATE event_log SET data = data || '{"performer":[{"reference":"Practitioner/prac-003","display":"Nurse Tembo Kasonde"}]}'::jsonb
WHERE id IN (
  'e1000021-0000-0000-0000-000000000001',
  'e1000034-0000-0000-0000-000000000001'
) AND data->>'resourceType' = 'Observation';

-- FAC-0004 Encounters → Dr. Ndiaye Mutale
UPDATE event_log SET data = data || '{"participant":[{"individual":{"reference":"Practitioner/prac-004","display":"Dr. Ndiaye Mutale"}}]}'::jsonb
WHERE id IN (
  'e1000028-0000-0000-0000-000000000001',
  'e1000029-0000-0000-0000-000000000001',
  'e1000030-0000-0000-0000-000000000001',
  'e1000031-0000-0000-0000-000000000001'
) AND data->>'resourceType' = 'Encounter';

-- FAC-0004 Immunizations → Dr. Ndiaye Mutale
UPDATE event_log SET data = data || '{"performer":[{"actor":{"reference":"Practitioner/prac-004","display":"Dr. Ndiaye Mutale"}}]}'::jsonb
WHERE id IN (
  'e1000026-0000-0000-0000-000000000001',
  'e1000027-0000-0000-0000-000000000001'
) AND data->>'resourceType' = 'Immunization';

-- FAC-0004 Observation → Dr. Ndiaye Mutale
UPDATE event_log SET data = data || '{"performer":[{"reference":"Practitioner/prac-004","display":"Dr. Ndiaye Mutale"}]}'::jsonb
WHERE id = 'e1000032-0000-0000-0000-000000000001'
  AND data->>'resourceType' = 'Observation';


-- ─────────────────────────────────────────────────────────────────────────────
\echo '--- [3/2] Inserting additional inbound_event records for volume ---'
-- ─────────────────────────────────────────────────────────────────────────────
-- Adds 16 more inbound_event records for:
--   • Smoother trend curves across more time periods
--   • More overlap + unique pairs for source comparison demo
--   • Additional rejection reason variety (DESERIALIZATION, PAYLOAD_TOO_LARGE)

INSERT INTO inbound_event (
    id, cloudevents_id, source, type, spec_version, subject,
    event_time, data_content_type, facility_id, correlation_id,
    source_event_id, raw_payload, status, rejection_reason,
    error_details, received_at
) VALUES

-- More ebuzima-direct Encounters across different weeks (fill trend gaps)
('1e000043-0000-0000-0000-000000000001','evt-eb-d-2001','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0001-1001',
 NOW()-INTERVAL '150 days','application/fhir+json','FAC-0001',
 'corr-d-v001','src-d-v001',
 '{"resourceType":"Encounter","id":"enc-vol-01","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1001"},
   "participant":[{"individual":{"reference":"Practitioner/prac-001","display":"Dr. Mwila Banda"}}]}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '150 days'),

('1e000044-0000-0000-0000-000000000001','evt-eb-d-2002','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0001-1002',
 NOW()-INTERVAL '140 days','application/fhir+json','FAC-0001',
 'corr-d-v002','src-d-v002',
 '{"resourceType":"Encounter","id":"enc-vol-02","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1002"},
   "participant":[{"individual":{"reference":"Practitioner/prac-001","display":"Dr. Mwila Banda"}}]}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '140 days'),

-- ebuzima events (present in openhim, absent in direct → source gap)
('1e000045-0000-0000-0000-000000000001','evt-eb-oh-2001','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0003-3002',
 NOW()-INTERVAL '80 days','application/fhir+json','FAC-0003',
 'corr-oh-v001','src-oh-v001',
 '{"resourceType":"Encounter","id":"enc-vol-oh-01","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0003-3002"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '80 days'),

('1e000046-0000-0000-0000-000000000001','evt-eb-oh-2002','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0003-3003',
 NOW()-INTERVAL '100 days','application/fhir+json','FAC-0003',
 'corr-oh-v002','src-oh-v002',
 '{"resourceType":"Encounter","id":"enc-vol-oh-02","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0003-3003"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '100 days'),

-- Overlapping event pair (P06 HTN, same time from both sources → overlap in comparison)
('1e000047-0000-0000-0000-000000000001','evt-eb-d-2003','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0003-3001',
 NOW()-INTERVAL '98 days','application/fhir+json','FAC-0003',
 'corr-d-v003','src-d-v003',
 '{"resourceType":"Encounter","id":"enc-p06-d-htn2","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"htn-followup"}]}],
   "subject":{"reference":"Patient/260225-0003-3001"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '98 days'),

-- More direct-only events (unique to direct in source comparison)
('1e000048-0000-0000-0000-000000000001','evt-eb-d-2004','ebuzima-direct',
 'org.openphc.cce.observation','1.0','260225-0001-1001',
 NOW()-INTERVAL '112 days','application/fhir+json','FAC-0001',
 'corr-d-v004','src-d-v004',
 '{"resourceType":"Observation","id":"obs-p01-bp-extra","status":"final",
   "code":{"coding":[{"system":"http://loinc.org","code":"55284-4"}]},
   "subject":{"reference":"Patient/260225-0001-1001"},
   "valueQuantity":{"value":142,"unit":"mmHg"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '112 days'),

('1e000049-0000-0000-0000-000000000001','evt-eb-d-2005','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0004-4003',
 NOW()-INTERVAL '42 days','application/fhir+json','FAC-0004',
 'corr-d-v005','src-d-v005',
 '{"resourceType":"Encounter","id":"enc-p11-anc3","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0004-4003"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '42 days'),

-- More openhim-only immunization (P09 continues EPI schedule)
('1e000050-0000-0000-0000-000000000001','evt-eb-oh-2003','ebuzima',
 'org.openphc.cce.immunization','1.0','260225-0004-4001',
 NOW()-INTERVAL '88 days','application/fhir+json','FAC-0004',
 'corr-oh-v003','src-oh-v003',
 '{"resourceType":"Immunization","id":"imm-p09-penta1","status":"completed",
   "vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"132","display":"Pentavalent"}]},
   "patient":{"reference":"Patient/260225-0004-4001"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '88 days'),

-- DESERIALIZATION rejection (openhim) — new rejection reason for ingestion pipeline variety
('1e000051-0000-0000-0000-000000000001','evt-eb-oh-2004','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0002-2001',
 NOW()-INTERVAL '45 days','application/fhir+json','FAC-0002',
 'corr-oh-v004','src-oh-v004',
 '{"raw":"invalid json content","truncated":true}'::jsonb,
 'REJECTED','DESERIALIZATION_ERROR',
 'Failed to deserialize FHIR resource: unexpected token at position 0',
 NOW()-INTERVAL '45 days'),

-- PAYLOAD_TOO_LARGE rejection (direct) — another new rejection reason
('1e000052-0000-0000-0000-000000000001','evt-eb-d-2006','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0001-1003',
 NOW()-INTERVAL '38 days','application/fhir+json','FAC-0001',
 'corr-d-v006','src-d-v006',
 '{"resourceType":"Encounter","note":"payload truncated at 1MB"}'::jsonb,
 'REJECTED','PAYLOAD_TOO_LARGE',
 'Payload size 1048577 bytes exceeds maximum allowed 1048576 bytes',
 NOW()-INTERVAL '38 days'),

-- Recent events — last 14 days (fills "this week / this month" dashboard tiles)
('1e000053-0000-0000-0000-000000000001','evt-eb-d-2007','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0001-1001',
 NOW()-INTERVAL '12 days','application/fhir+json','FAC-0001',
 'corr-d-v007','src-d-v007',
 '{"resourceType":"Encounter","id":"enc-p01-recent1","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1001"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '12 days'),

('1e000054-0000-0000-0000-000000000001','evt-eb-oh-2005','ebuzima',
 'org.openphc.cce.encounter','1.0','260225-0003-3001',
 NOW()-INTERVAL '10 days','application/fhir+json','FAC-0003',
 'corr-oh-v005','src-oh-v005',
 '{"resourceType":"Encounter","id":"enc-p06-htn-recent","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"htn-followup"}]}],
   "subject":{"reference":"Patient/260225-0003-3001"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '10 days'),

('1e000055-0000-0000-0000-000000000001','evt-eb-d-2008','ebuzima-direct',
 'org.openphc.cce.observation','1.0','260225-0003-3001',
 NOW()-INTERVAL '10 days','application/fhir+json','FAC-0003',
 'corr-d-v008','src-d-v008',
 '{"resourceType":"Observation","id":"obs-p06-bp-recent","status":"final",
   "code":{"coding":[{"system":"http://loinc.org","code":"55284-4"}]},
   "subject":{"reference":"Patient/260225-0003-3001"},
   "valueQuantity":{"value":132,"unit":"mmHg"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '10 days'),

('1e000056-0000-0000-0000-000000000001','evt-eb-oh-2006','ebuzima',
 'org.openphc.cce.immunization','1.0','260225-0002-2001',
 NOW()-INTERVAL '7 days','application/fhir+json','FAC-0002',
 'corr-oh-v006','src-oh-v006',
 '{"resourceType":"Immunization","id":"imm-p04-penta3","status":"completed",
   "vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"132","display":"Pentavalent"}]},
   "patient":{"reference":"Patient/260225-0002-2001"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '7 days'),

('1e000057-0000-0000-0000-000000000001','evt-eb-d-2009','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0004-4002',
 NOW()-INTERVAL '8 days','application/fhir+json','FAC-0004',
 'corr-d-v009','src-d-v009',
 '{"resourceType":"Encounter","id":"enc-p10-anc3","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0004-4002"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '8 days'),

-- Same-time overlap pair (P06 HTN from both sources at 10 days → overlap in comparison)
('1e000058-0000-0000-0000-000000000001','evt-eb-d-2010','ebuzima-direct',
 'org.openphc.cce.encounter','1.0','260225-0003-3001',
 NOW()-INTERVAL '10 days','application/fhir+json','FAC-0003',
 'corr-d-v010','src-d-v010',
 '{"resourceType":"Encounter","id":"enc-p06-d-htn-recent","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"htn-followup"}]}],
   "subject":{"reference":"Patient/260225-0003-3001"}}'::jsonb,
 'ACCEPTED',NULL,NULL, NOW()-INTERVAL '10 days')
ON CONFLICT DO NOTHING;


-- ─────────────────────────────────────────────────────────────────────────────
\echo '--- [3/3] Inserting additional event_log records for volume ---'
-- ─────────────────────────────────────────────────────────────────────────────
-- Adds event_log records with practitioner data for new inbound events

INSERT INTO event_log (
    id, cloudevents_id, source, source_event_id, subject, type,
    event_time, received_at, correlation_id, data,
    protocol_instance_id, protocol_definition_id, action_id, facility_id,
    processing_status, matched_step_instance_id
) VALUES

-- P06 HTN overlap visit (direct counterpart to openhim at 98 days)
('e1000035-0000-0000-0000-000000000001','evt-eb-d-2003','ebuzima-direct','src-d-v003',
 '260225-0003-3001','org.openphc.cce.encounter',
 NOW()-INTERVAL '98 days',NOW()-INTERVAL '98 days','corr-d-v003',
 '{"resourceType":"Encounter","id":"enc-p06-d-htn2","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"htn-followup"}]}],
   "subject":{"reference":"Patient/260225-0003-3001"},
   "participant":[{"individual":{"reference":"Practitioner/prac-003","display":"Nurse Tembo Kasonde"}}]}'::jsonb,
 '01000006-0000-0000-0000-000000000001','0d000003-0000-0000-0000-000000000001',
 'htn-followup-1','FAC-0003','DUPLICATE',NULL),

-- P01 extra ANC visit (direct, ZERO_MATCH — no more pending steps)
('e1000036-0000-0000-0000-000000000001','evt-eb-d-2001','ebuzima-direct','src-d-v001',
 '260225-0001-1001','org.openphc.cce.encounter',
 NOW()-INTERVAL '150 days',NOW()-INTERVAL '150 days','corr-d-v001',
 '{"resourceType":"Encounter","id":"enc-vol-01","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0001-1001"},
   "participant":[{"individual":{"reference":"Practitioner/prac-001","display":"Dr. Mwila Banda"}}]}'::jsonb,
 NULL,NULL,NULL,'FAC-0001','ZERO_MATCH',NULL),

-- P06 recent HTN visit (direct at 10 days, overlap pair)
('e1000037-0000-0000-0000-000000000001','evt-eb-d-2010','ebuzima-direct','src-d-v010',
 '260225-0003-3001','org.openphc.cce.encounter',
 NOW()-INTERVAL '10 days',NOW()-INTERVAL '10 days','corr-d-v010',
 '{"resourceType":"Encounter","id":"enc-p06-d-htn-recent","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"htn-followup"}]}],
   "subject":{"reference":"Patient/260225-0003-3001"},
   "participant":[{"individual":{"reference":"Practitioner/prac-003","display":"Nurse Tembo Kasonde"}}]}'::jsonb,
 '01000006-0000-0000-0000-000000000001','0d000003-0000-0000-0000-000000000001',
 'htn-followup-3','FAC-0003','MATCHED',
 '51000028-0000-0000-0000-000000000001'),

-- P06 recent BP (direct observation, matched)
('e1000038-0000-0000-0000-000000000001','evt-eb-d-2008','ebuzima-direct','src-d-v008',
 '260225-0003-3001','org.openphc.cce.observation',
 NOW()-INTERVAL '10 days',NOW()-INTERVAL '10 days','corr-d-v008',
 '{"resourceType":"Observation","id":"obs-p06-bp-recent","status":"final",
   "code":{"coding":[{"system":"http://loinc.org","code":"55284-4"}]},
   "subject":{"reference":"Patient/260225-0003-3001"},
   "performer":[{"reference":"Practitioner/prac-003","display":"Nurse Tembo Kasonde"}],
   "valueQuantity":{"value":132,"unit":"mmHg"}}'::jsonb,
 '01000006-0000-0000-0000-000000000001','0d000003-0000-0000-0000-000000000001',
 'htn-bp-check','FAC-0003','MATCHED',NULL),

-- P09 EPI penta1 (openhim)
('e1000039-0000-0000-0000-000000000001','evt-eb-oh-2003','ebuzima','src-oh-v003',
 '260225-0004-4001','org.openphc.cce.immunization',
 NOW()-INTERVAL '88 days',NOW()-INTERVAL '88 days','corr-oh-v003',
 '{"resourceType":"Immunization","id":"imm-p09-penta1","status":"completed",
   "vaccineCode":{"coding":[{"system":"http://hl7.org/fhir/sid/cvx","code":"132","display":"Pentavalent"}]},
   "patient":{"reference":"Patient/260225-0004-4001"},
   "performer":[{"actor":{"reference":"Practitioner/prac-004","display":"Dr. Ndiaye Mutale"}}]}'::jsonb,
 '01000009-0000-0000-0000-000000000001','0d000002-0000-0000-0000-000000000001',
 'epi-penta1','FAC-0004','MATCHED',
 '51000039-0000-0000-0000-000000000001'),

-- P10 ANC visit-2 (direct at 8 days)
('e1000040-0000-0000-0000-000000000001','evt-eb-d-2009','ebuzima-direct','src-d-v009',
 '260225-0004-4002','org.openphc.cce.encounter',
 NOW()-INTERVAL '8 days',NOW()-INTERVAL '8 days','corr-d-v009',
 '{"resourceType":"Encounter","id":"enc-p10-anc3","status":"finished",
   "type":[{"coding":[{"system":"http://openphc.org/encounter-types","code":"anc-visit"}]}],
   "subject":{"reference":"Patient/260225-0004-4002"},
   "participant":[{"individual":{"reference":"Practitioner/prac-004","display":"Dr. Ndiaye Mutale"}}]}'::jsonb,
 '01000010-0000-0000-0000-000000000001','0d000001-0000-0000-0000-000000000001',
 'anc-visit-2','FAC-0004','MATCHED',
 '51000042-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;


-- =============================================================================
-- END OF DEMO DATA
-- =============================================================================
-- Summary inserted:
--   COLLECTOR  inbound_event       : 58 records (42 original + 16 volume/trend)
--              Sources             : ebuzima-direct (28), ebuzima (30)
--              Statuses            : ACCEPTED(46), REJECTED(7), DUPLICATE(2)
--              Rejection reasons   : INVALID_FHIR, MISSING_SUBJECT, INVALID_ENVELOPE,
--                                   UNSUPPORTED_CONTENT_TYPE, DESERIALIZATION, PAYLOAD_TOO_LARGE
--
--   COMPLIANCE protocol_definition : 3  (ANC, EPI, HTN)
--              trigger_index       : 16 rows
--              protocol_instance   : 12 patients across 4 facilities
--              step_instance       : 49 steps (various states)
--              deviation           : 13 records (5 OVERDUE, 8 MISSED)
--              event_log           : 40 records (MATCHED/ZERO_MATCH/DUPLICATE)
--              audit_log           : 20 records
--
--   ENRICHMENTS (Section 3):
--              Practitioner refs   : 4 practitioners across all event_log records
--              Additional inbound  : 16 records for trend fill + source comparison overlap
--              Additional event_log: 6 records with practitioner data
--
-- Events-By-Source Mismatch Showcase:
--   MS-1 (gap)       : P07,P08,P09 — openhim only, no direct coverage
--   MS-2 (rejected)  : P10 — direct ACCEPTED, openhim INVALID_FHIR
--   MS-3 (duplicate) : P11 — same event from both sources; openhim retry → DUPLICATE
--   MS-4 (missing)   : P12 — direct ACCEPTED, openhim MISSING_SUBJECT rejection
--   MS-5 (invalid)   : P06/P05 — openhim INVALID_FHIR for Immunization batch
--
-- Source Comparison Overlap Pairs (same subject+type within time window):
--   P01 encounter @175d, P02 encounter @168d, P10 encounter @120d,
--   P11 encounter @110d, P12 observation @95d, P06 encounter @98d (new),
--   P06 encounter @10d (new)
--
-- UI Coverage →  All 12 screens:
--   Dashboard, Compliance, Protocol Analytics, Patient List, Patient Detail,
--   Deviations, Event Volume (resource/facility/practitioner/source/quality),
--   Source Comparison, Facility Analytics, Ingestion Pipeline, Exports
-- =============================================================================
