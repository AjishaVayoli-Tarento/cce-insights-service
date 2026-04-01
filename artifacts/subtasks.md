# CCE Insights Service — JIRA Subtasks (Sequential Execution)

**Epic:** CCE Insights Service — Compliance Analytics & Dashboards  
**Component:** `cce-insights-service`  
**Sprint Target:** Release 1.0.0  
**Total Subtasks:** 16  
**Total Story Points:** 68  
**Total Endpoints:** 38  

> Each subtask is a single PR-able unit. Execute in listed order — each depends on the prior one being merged. Subtasks S4–S9 can be parallelized after S3 is merged.

---

## Subtask S0: Technical Documentation & Design Artifacts

**Type:** Task  
**Priority:** Highest  
**Story Points:** 5  
**Labels:** `documentation`, `design`

**Description:**  
Create comprehensive technical documentation covering architecture, API reference, data dictionary, developer setup guide, and flow diagrams. Documents the full 1.0.0 API surface — 26 endpoints across 9 controllers.

**Acceptance Criteria:**
- [ ] `docs/architecture-overview.md` — System context diagram (including EventVolumeService), tech stack, package structure (~10 packages, ~45 files), data access patterns, query patterns for all 26 endpoints, phased architecture (Phase 1 vs Phase 2), error handling, scaling
- [ ] `docs/api-reference.md` — All 26 REST endpoints with request/response schemas:
  - §1 Compliance Summaries (3 endpoints)
  - §2 Patient Compliance (3 endpoints)
  - §3 Deviations & Intelligence (3 endpoints)
  - §4 Event Volume & Activity Metrics (6 endpoints)
  - §5 Exports (1 endpoint)
  - §6 Error Responses
  - §7 Actuator Endpoints
  - §8 Protocol Analytics (4 endpoints)
  - §9 Facility Analytics (1 endpoint)
  - §10 Deviation Analytics (2 endpoints)
  - §11 Event Processing (1 endpoint)
  - §12 Patient Risk Analytics (2 endpoints)
- [ ] `docs/data-dictionary.md` — 5 read-only tables, enums, 14 aggregation formulas (§3.1–3.14), 6 filter parameter groups (§4.1–4.6), FHIR resource types, practitioner JSONB extraction paths
- [ ] `docs/developer-setup.md` — Prerequisites, quick start (with curl examples for all endpoint groups), shared database (no Flyway), Docker Compose, config reference, environment variables, project structure, testing, Docker build
- [ ] `docs/flow-diagrams.md` — 18 Mermaid diagrams: request flow, compliance summary, patient timeline, deviation trends, facility overview, export flow, event volume (4 diagrams), protocol analytics (4 diagrams), facility ranking, deviation analytics (2 diagrams), processing quality, patient risk (2 diagrams)
- [ ] `.github/copilot-instructions-insights-service.md` — AI agent instructions covering architecture, ~45 files, 26 endpoints across 7 subsections, 14 key aggregation queries, database access patterns, build & run, testing

**Files:**
- `docs/architecture-overview.md`
- `docs/api-reference.md`
- `docs/data-dictionary.md`
- `docs/developer-setup.md`
- `docs/flow-diagrams.md`
- `.github/copilot-instructions-insights-service.md`

---

## Subtask S1: Project Scaffolding & Gradle Build Configuration

**Type:** Task  
**Priority:** Highest  
**Story Points:** 2  
**Labels:** `setup`, `infrastructure`

**Description:**  
Initialize the Spring Boot project with Gradle. The Insights Service is a REST API service with read-only database access. No Kafka, no Flyway, no security (Gateway handles OAuth). Actuator is included for health/metrics.

**Acceptance Criteria:**
- [ ] `build.gradle` with dependencies: Spring Boot 3.4.x, Spring Boot Starter Web, Spring Data JPA, Actuator, PostgreSQL driver, Micrometer Prometheus, Lombok, JUnit 5, Testcontainers (PostgreSQL), MockMvc
- [ ] `settings.gradle` with project name `cce-insights-service`
- [ ] Gradle Wrapper 8.x (`gradlew`, `gradlew.bat`, `gradle/wrapper/`)
- [ ] `.gitignore` for Java/Gradle/IDE
- [ ] `InsightsServiceApplication.java` with `@SpringBootApplication`
- [ ] Base package: `org.openphc.cce.insights` — create sub-packages: `config/`, `domain/entity/`, `domain/enums/`, `domain/repository/`, `service/`, `web/controller/`, `web/dto/`
- [ ] `./gradlew build -x test` succeeds
- [ ] Application starts on port 8084

**Files:**
- `build.gradle`
- `settings.gradle`
- `gradlew`, `gradlew.bat`, `gradle/wrapper/`
- `.gitignore`
- `src/main/java/org/openphc/cce/insights/InsightsServiceApplication.java`

---

## Subtask S2: Application Configuration & Profiles

**Type:** Task  
**Priority:** Highest  
**Story Points:** 1  
**Labels:** `config`

**Description:**  
Configure `application.yml` for the read-only service. All JPA/Hibernate settings enforce read-only mode — no DDL auto-generation, `validate` mode only. Set up profiles for local, test, and production.

**Acceptance Criteria:**
- [ ] `application.yml` — server port 8084, datasource config (externalized), JPA `validate` mode, `default_read_only: true`, HikariCP `read-only: true`, actuator exposure
- [ ] `application-local.yml` — local PostgreSQL defaults
- [ ] `application-test.yml` — Testcontainers overrides
- [ ] Actuator health endpoint returns 200 with `db` health indicator
- [ ] Application logs show `ddl-auto: validate` on startup

**Files:**
- `src/main/resources/application.yml`
- `src/main/resources/application-local.yml`
- `src/main/resources/application-test.yml`

---

## Subtask S3: Domain Entities & Repositories (Read-Only)

**Type:** Story  
**Priority:** High  
**Story Points:** 5  
**Labels:** `domain`, `jpa`

**Description:**  
Map the Compliance Service's database tables as read-only JPA entities. All entities use `@Immutable` — no insert/update/delete operations. Repositories extend `ReadOnlyRepository` (no `save`/`delete` methods). Includes `@Query` methods for all aggregation patterns used by the 26 endpoints.

**Acceptance Criteria:**
- [ ] `ProtocolDefinition` entity — maps `protocol_definition` table, `@Immutable`, JSONB fields (`definition`) mapped as `String`
- [ ] `ProtocolInstance` entity — maps `protocol_instance` table, `@Immutable`, `ProtocolInstanceStatus` enum, relationship to `ProtocolDefinition`
- [ ] `StepInstance` entity — maps `step_instance` table, `@Immutable`, `StepState` and `CompletionStatus` enums, relationship to `ProtocolInstance`
- [ ] `Deviation` entity — maps `deviation` table, `@Immutable`, `DeviationType` enum, relationship to `ProtocolInstance` and `StepInstance`
- [ ] `EventLog` entity — maps `event_log` table, `@Immutable`, JSONB `data` column mapped as `String`, `processing_status`, `facility_id`, `source` columns
- [ ] `ReadOnlyRepository<T, ID>` base interface — extends `Repository<T, ID>` with `findById`, `findAll` (paginated), no mutating methods
- [ ] Individual repositories: `ProtocolDefinitionRepository`, `ProtocolInstanceRepository`, `StepInstanceRepository`, `DeviationRepository`, `EventLogRepository`
- [ ] Custom `@Query` methods for: compliance aggregation, step analytics (with `PERCENTILE_CONT`), completion funnel, outcome distribution, enrollment trends, facility ranking, deviation by-action, resolution rate, event volume (by resourceType/facility/practitioner/source), processing quality, at-risk hotspots, repeat deviations
- [ ] Enums: `ProtocolInstanceStatus`, `StepState`, `CompletionStatus`, `DeviationType`, `ComplianceCategory` (derived)
- [ ] All entities tested with `@DataJpaTest` + Testcontainers

**Files:**
- `src/main/java/org/openphc/cce/insights/domain/entity/ProtocolDefinition.java`
- `src/main/java/org/openphc/cce/insights/domain/entity/ProtocolInstance.java`
- `src/main/java/org/openphc/cce/insights/domain/entity/StepInstance.java`
- `src/main/java/org/openphc/cce/insights/domain/entity/Deviation.java`
- `src/main/java/org/openphc/cce/insights/domain/entity/EventLog.java`
- `src/main/java/org/openphc/cce/insights/domain/enums/*.java`
- `src/main/java/org/openphc/cce/insights/domain/repository/ReadOnlyRepository.java`
- `src/main/java/org/openphc/cce/insights/domain/repository/*Repository.java`

---

## Subtask S4: Compliance Summary Service & Endpoints (3 endpoints)

**Type:** Story  
**Priority:** High  
**Story Points:** 5  
**Labels:** `feature`, `api`

**Description:**  
Implement the compliance summary endpoints — protocol adherence rates, facility roll-ups, and patient listing by compliance status. This is the primary dashboard data source.

**Acceptance Criteria:**
- [ ] `ComplianceSummaryService` — aggregation logic: compliance_rate = completed_steps / total_steps, category classification (on_track / at_risk / non_compliant based on step states)
- [ ] `GET /v1/insights/protocols/{protocolDefinitionId}/compliance-summary` — protocol-level compliance metrics with step metrics and deviation breakdown
- [ ] `GET /v1/insights/facilities/{facilityId}/compliance-summary` — facility-level compliance across all protocols with per-protocol breakdown
- [ ] `GET /v1/insights/protocols/{protocolDefinitionId}/patients` — list patients by compliance status (on_track/at_risk/non_compliant) with cursor pagination
- [ ] DTOs: `ComplianceSummaryDto`, `FacilitySummaryDto`, `PatientComplianceDto`
- [ ] Response format: `{ "data": { ... } }` envelope; paginated lists use `{ "data": [...], "pagination": {...} }`
- [ ] Unit tests for adherence calculation edge cases (0 steps, all completed, all missed)
- [ ] MockMvc tests for each endpoint: 200 OK, pagination, filters, 404

**Files:**
- `src/main/java/org/openphc/cce/insights/service/ComplianceSummaryService.java`
- `src/main/java/org/openphc/cce/insights/web/controller/ComplianceSummaryController.java`
- `src/main/java/org/openphc/cce/insights/web/dto/ComplianceSummaryDto.java`
- `src/main/java/org/openphc/cce/insights/web/dto/FacilitySummaryDto.java`
- `src/main/java/org/openphc/cce/insights/web/dto/PatientComplianceDto.java`

---

## Subtask S5: Patient Compliance Service & Endpoints (5 endpoints)

**Type:** Story  
**Priority:** High  
**Story Points:** 5  
**Labels:** `feature`, `api`

**Description:**  
Implement patient-level compliance endpoints — timeline view, protocol tracking list, detailed step-by-step tracking, patient event history, and patient deviation history.

**Acceptance Criteria:**
- [ ] `PatientTimelineService` — timeline assembly combining events and step status changes, per-protocol step progression
- [ ] `GET /v1/insights/patients/{patientId}/compliance-timeline` — chronological timeline across all enrolled protocols with event history and step status
- [ ] `GET /v1/insights/patients/{patientId}/protocol-tracking` — list all protocol instances for a patient with compliance rates
- [ ] `GET /v1/insights/patients/{patientId}/protocol-tracking/{protocolInstanceId}` — detailed step-by-step tracking with deviations for a single protocol
- [ ] `GET /v1/insights/patients/{patientId}/events` — patient event history from event_log with resource type, source, and date filtering
- [ ] `GET /v1/insights/patients/{patientId}/deviations` — patient deviation history across all protocol instances with type and date filtering
- [ ] DTOs: `PatientTimelineDto`, `PatientComplianceDto`
- [ ] Unit tests for timeline ordering, empty results, multi-protocol scenarios
- [ ] MockMvc tests for each endpoint: 200 OK, 404 patient not found

**Files:**
- `src/main/java/org/openphc/cce/insights/service/PatientTimelineService.java`
- `src/main/java/org/openphc/cce/insights/web/controller/PatientController.java`
- `src/main/java/org/openphc/cce/insights/web/dto/PatientTimelineDto.java`

---

## Subtask S6: Deviation & Intelligence Endpoints (3 endpoints)

**Type:** Story  
**Priority:** High  
**Story Points:** 5  
**Labels:** `feature`, `api`

**Description:**  
Implement the core deviation endpoints — paginated list, time-bucketed trends, and intelligence summary. This subtask covers the base deviation features; advanced deviation analytics (by-action, resolution-rate) are in S9.

**Acceptance Criteria:**
- [ ] `DeviationAnalyticsService` — deviation queries, trend aggregation with `DATE_TRUNC`
- [ ] `GET /v1/insights/deviations` — paginated list with filters: `deviationType`, `facilityId`, `protocolDefinitionId`, `startDate`, `endDate`, `sort`, cursor pagination
- [ ] `GET /v1/insights/deviations/trends` — time-bucketed counts by `interval` (daily/weekly/monthly) and deviation type
- [ ] `GET /v1/insights/intelligence/summary` — aggregated deviation counts by type and severity, recent activity summary (24h/7d/30d)
- [ ] DTOs: `DeviationDto`, `DeviationTrendDto`, `IntelligenceSummaryDto`
- [ ] Unit tests for trend bucketing, empty date ranges, type filtering
- [ ] MockMvc tests for each endpoint: 200 OK, pagination, filter combinations

**Files:**
- `src/main/java/org/openphc/cce/insights/service/DeviationAnalyticsService.java`
- `src/main/java/org/openphc/cce/insights/web/controller/DeviationController.java`
- `src/main/java/org/openphc/cce/insights/web/dto/DeviationDto.java`
- `src/main/java/org/openphc/cce/insights/web/dto/DeviationTrendDto.java`
- `src/main/java/org/openphc/cce/insights/web/dto/IntelligenceSummaryDto.java`

---

## Subtask S7: Event Volume & Activity Metrics (8 endpoints)

**Type:** Story  
**Priority:** High  
**Story Points:** 5  
**Labels:** `feature`, `api`, `event-volume`

**Description:**  
Implement event volume analytics — aggregate counts of clinical events grouped by FHIR `resourceType`, facility, practitioner (JSONB extraction), and source system. Includes composite summary and time-series trends.

**Acceptance Criteria:**
- [ ] `EventVolumeService` — queries `event_log` table, excludes duplicates (`processing_status != 'DUPLICATE'`), JSONB path extraction for practitioner references (COALESCE across 5 paths)
- [ ] `GET /v1/insights/events/summary` — composite summary: total events, processing status breakdown, top resource types, facilities, sources
- [ ] `GET /v1/insights/events/trends` — time-series event volume with `interval` (daily/weekly/monthly) and resource type breakdown
- [ ] `GET /v1/insights/events/by-resource-type` — event counts grouped by `data->>'resourceType'` with percentages
- [ ] `GET /v1/insights/events/by-facility` — event counts per facility with resource type sub-groups, cursor pagination
- [ ] `GET /v1/insights/events/by-practitioner` — event counts per practitioner via JSONB COALESCE extraction, cursor pagination. Practitioner `display` field is best-effort.
- [ ] `GET /v1/insights/events/by-source` — event counts per source system with status breakdown (uses inbound_event)
- [ ] `GET /v1/insights/events/compare-sources` — compare two source systems: overlap, unique events, sample pairs (uses inbound_event)
- [ ] DTOs: `EventVolumeSummaryDto`, `EventVolumeTrendDto`, `ResourceTypeCountDto`, `FacilityEventCountDto`, `PractitionerEventCountDto`, `SourceSystemCountDto`
- [ ] Unit tests for JSONB path extraction logic, percentage calculation, null practitioner handling
- [ ] MockMvc tests for all 6 endpoints: 200 OK, filters, pagination

**Files:**
- `src/main/java/org/openphc/cce/insights/service/EventVolumeService.java`
- `src/main/java/org/openphc/cce/insights/web/controller/EventVolumeController.java`
- `src/main/java/org/openphc/cce/insights/web/dto/EventVolumeSummaryDto.java`
- `src/main/java/org/openphc/cce/insights/web/dto/EventVolumeTrendDto.java`
- `src/main/java/org/openphc/cce/insights/web/dto/ResourceTypeCountDto.java`
- `src/main/java/org/openphc/cce/insights/web/dto/FacilityEventCountDto.java`
- `src/main/java/org/openphc/cce/insights/web/dto/PractitionerEventCountDto.java`
- `src/main/java/org/openphc/cce/insights/web/dto/SourceSystemCountDto.java`

---

## Subtask S8: Protocol Analytics Service & Endpoints (4 endpoints)

**Type:** Story  
**Priority:** High  
**Story Points:** 5  
**Labels:** `feature`, `api`, `protocol-analytics`

**Description:**  
Implement protocol-level analytics — per-step performance (timeliness, median time-to-complete), completion funnels showing patient drop-off, outcome distribution by terminal status, and enrollment trends over time.

**Acceptance Criteria:**
- [ ] `ProtocolAnalyticsService` — step-level aggregation with `PERCENTILE_CONT(0.5)`, funnel calculation (reached vs completed per action), outcome distribution, enrollment trend bucketing
- [ ] `GET /v1/insights/protocols/{protocolDefinitionId}/step-analytics` — per-action completion rate, timeliness distribution (EARLY/ON_TIME/LATE), avg + median days to complete
- [ ] `GET /v1/insights/protocols/{protocolDefinitionId}/completion-funnel` — drop-off rates at each sequential step; `stepOrder` derived from PlanDefinition action ordering
- [ ] `GET /v1/insights/protocols/{protocolDefinitionId}/outcome-distribution` — percentage of protocol instances in each terminal status (ACTIVE/COMPLETED/WITHDRAWN/EXPIRED)
- [ ] `GET /v1/insights/protocols/{protocolDefinitionId}/enrollment-trends` — new enrollments over time by `interval` (daily/weekly/monthly) with optional facility filter
- [ ] DTOs: `StepAnalyticsDto`, `CompletionFunnelDto`, `OutcomeDistributionDto`, `EnrollmentTrendDto`
- [ ] Unit tests for: percentile calculation, funnel ordering, zero-enrollment edge cases, single-step protocol
- [ ] MockMvc tests for all 4 endpoints: 200 OK, filters, 404 protocol not found

**Files:**
- `src/main/java/org/openphc/cce/insights/service/ProtocolAnalyticsService.java`
- `src/main/java/org/openphc/cce/insights/web/controller/ProtocolAnalyticsController.java`
- `src/main/java/org/openphc/cce/insights/web/dto/StepAnalyticsDto.java`
- `src/main/java/org/openphc/cce/insights/web/dto/CompletionFunnelDto.java`
- `src/main/java/org/openphc/cce/insights/web/dto/OutcomeDistributionDto.java`
- `src/main/java/org/openphc/cce/insights/web/dto/EnrollmentTrendDto.java`

---

## Subtask S9: Deviation Analytics (Advanced) & Facility Ranking (3 endpoints)

**Type:** Story  
**Priority:** High  
**Story Points:** 5  
**Labels:** `feature`, `api`, `deviation-analytics`

**Description:**  
Implement advanced deviation analytics — most-deviated protocol steps (by action), resolution rate (OVERDUE→COMPLETED vs OVERDUE→MISSED), and facility ranking leaderboard (by compliance rate, deviation count, or event volume).

**Acceptance Criteria:**
- [ ] Extension to `DeviationAnalyticsService` — by-action grouping with affected patient counts, resolution rate tracking (resolved = step reached COMPLETED after OVERDUE deviation; escalated = step reached MISSED)
- [ ] `FacilityRankingService` — cross-table aggregation (protocol_instance + step_instance + event_log + deviation) per facility, rank assignment by configurable metric
- [ ] `GET /v1/insights/deviations/by-action` — most deviated-from protocol steps grouped by `actionId`, with overdue/missed breakdown and `affectedPatients` count
- [ ] `GET /v1/insights/deviations/resolution-rate` — OVERDUE deviation outcomes: resolved count + percentage, escalated count + percentage, `avgDaysToResolve`, per-protocol breakdown
- [ ] `GET /v1/insights/facilities/ranking` — facility leaderboard with `rankBy` param (`complianceRate`/`deviationCount`/`eventVolume`), `order` (asc/desc), cursor pagination
- [ ] DTOs: `DeviationByActionDto`, `DeviationResolutionDto`, `FacilityRankingDto`
- [ ] Unit tests for: resolution classification logic, ranking sort stability, edge cases (facility with no deviations, action with only overdue)
- [ ] MockMvc tests for all 3 endpoints: 200 OK, rankBy options, filter combinations

**Files:**
- `src/main/java/org/openphc/cce/insights/service/FacilityRankingService.java`
- `src/main/java/org/openphc/cce/insights/web/controller/FacilityRankingController.java`
- `src/main/java/org/openphc/cce/insights/web/dto/DeviationByActionDto.java`
- `src/main/java/org/openphc/cce/insights/web/dto/DeviationResolutionDto.java`
- `src/main/java/org/openphc/cce/insights/web/dto/FacilityRankingDto.java`

---

## Subtask S10: Processing Quality & Patient Risk Analytics (3 endpoints)

**Type:** Story  
**Priority:** High  
**Story Points:** 5  
**Labels:** `feature`, `api`, `patient-risk`

**Description:**  
Implement event processing quality monitoring (integration health) and patient risk analytics — at-risk hotspots by facility and repeat deviation patients requiring targeted outreach.

**Acceptance Criteria:**
- [ ] `ProcessingQualityService` — MATCHED/ZERO_MATCH/DUPLICATE ratios per source system from `event_log.processing_status`
- [ ] `PatientRiskService` — patient compliance categorization across all active protocol instances per facility (on_track/at_risk/non_compliant via correlated subqueries on step_instance.state); repeat deviation identification with threshold filter
- [ ] `GET /v1/insights/events/processing-quality` — per-source breakdown of MATCHED/ZERO_MATCH/DUPLICATE with percentages and overall totals
- [ ] `GET /v1/insights/patients/at-risk-hotspots` — per-facility concentration of at_risk + non_compliant patients, ordered by non_compliant count DESC, cursor pagination
- [ ] `GET /v1/insights/patients/repeat-deviations` — patients with `totalDeviations >= minDeviations` (default 3), with overdue/missed counts, affected protocols/steps, recent deviation details, cursor pagination
- [ ] DTOs: `ProcessingQualityDto`, `AtRiskHotspotDto`, `RepeatDeviationPatientDto`
- [ ] Unit tests for: compliance categorization across multi-protocol patients, minDeviations threshold, percentage edge cases (division by zero)
- [ ] MockMvc tests for all 3 endpoints: 200 OK, filters, pagination

**Files:**
- `src/main/java/org/openphc/cce/insights/service/ProcessingQualityService.java`
- `src/main/java/org/openphc/cce/insights/service/PatientRiskService.java`
- `src/main/java/org/openphc/cce/insights/web/controller/ProcessingQualityController.java`
- `src/main/java/org/openphc/cce/insights/web/controller/PatientRiskController.java`
- `src/main/java/org/openphc/cce/insights/web/dto/ProcessingQualityDto.java`
- `src/main/java/org/openphc/cce/insights/web/dto/AtRiskHotspotDto.java`
- `src/main/java/org/openphc/cce/insights/web/dto/RepeatDeviationPatientDto.java`

---

## Subtask S11: Export Service & Endpoint (1 endpoint)

**Type:** Story  
**Priority:** Medium  
**Story Points:** 3  
**Labels:** `feature`, `api`

**Description:**  
Implement the data export endpoint. Supports CSV format using streaming to avoid memory issues with large datasets.

**Acceptance Criteria:**
- [ ] `ExportService` — cursor-based streaming from database, CSV row transformation
- [ ] `GET /v1/insights/exports/compliance-report` — query params: `format` (json/csv), `protocolDefinitionId`, `facilityId`, `startDate`, `endDate`
- [ ] CSV export uses `StreamingResponseBody` — no full dataset buffering
- [ ] Response headers: `Content-Type: text/csv`, `Content-Disposition: attachment; filename="..."`
- [ ] Unit tests for CSV formatting (header row, escaping, date formatting)
- [ ] Integration test: export 100+ rows, verify streaming behavior

**Files:**
- `src/main/java/org/openphc/cce/insights/service/ExportService.java`
- `src/main/java/org/openphc/cce/insights/web/controller/ExportController.java`

---

## Subtask S12: Observability — Health, Metrics & Error Handling

**Type:** Task  
**Priority:** Medium  
**Story Points:** 2  
**Labels:** `observability`, `ops`

**Description:**  
Configure global error handling, custom health indicators, and Micrometer metrics. Ensure consistent error responses and operational visibility across all 26 endpoints.

**Acceptance Criteria:**
- [ ] `GlobalExceptionHandler` with `@ControllerAdvice` — `{ "error": { "code": "...", "message": "..." } }` format
- [ ] Handle: `IllegalArgumentException` → 400, resource not found → 404, database unreachable → 503, unexpected → 500
- [ ] Custom health indicator: database connectivity check (read-only query)
- [ ] Micrometer metrics: `cce.insights.request.count` (by endpoint, status), `cce.insights.query.duration` (by query_type), `cce.insights.request.duration` (timer), `cce.insights.export.rows` (counter)
- [ ] Prometheus endpoint at `/actuator/prometheus`
- [ ] Structured JSON logging (logback-spring.xml)

**Files:**
- `src/main/java/org/openphc/cce/insights/web/GlobalExceptionHandler.java`
- `src/main/java/org/openphc/cce/insights/config/MetricsConfig.java`
- `src/main/java/org/openphc/cce/insights/health/DatabaseHealthIndicator.java`
- `src/main/resources/logback-spring.xml`

---

## Subtask S13: Integration Tests & Test Data Seeding

**Type:** Task  
**Priority:** Medium  
**Story Points:** 5  
**Labels:** `testing`, `quality`

**Description:**  
Full integration test suite using Testcontainers PostgreSQL. Seed compliance schema and data from SQL scripts, then verify all 26 endpoints end-to-end. Seed data must include realistic FHIR JSONB payloads with practitioner references for event volume testing.

**Acceptance Criteria:**
- [ ] `AbstractIntegrationTest` base class — `@Testcontainers`, `@DynamicPropertySource`, PostgreSQL container with schema init
- [ ] SQL seed scripts: `init-schema.sql` (Compliance Service DDL), `seed-data.sql` (sample protocols, instances, steps, deviations, event_log entries with FHIR JSONB data including practitioner references)
- [ ] Integration tests for all 9 controllers:
  - `ComplianceSummaryControllerIT` — compliance summaries (3 endpoints)
  - `PatientControllerIT` — patient compliance (3 endpoints)
  - `DeviationControllerIT` — deviations & intelligence (3 endpoints), by-action, resolution-rate
  - `EventVolumeControllerIT` — event volume (6 endpoints), JSONB practitioner extraction
  - `ProtocolAnalyticsControllerIT` — step analytics, completion funnel, outcome distribution, enrollment trends
  - `FacilityRankingControllerIT` — ranking with all 3 rankBy options
  - `ProcessingQualityControllerIT` — per-source processing quality
  - `PatientRiskControllerIT` — at-risk hotspots, repeat deviations
  - `ExportControllerIT` — CSV streaming export
- [ ] Verify pagination, filtering, edge cases (no data, 1 record, boundary dates)
- [ ] CI-ready: no external dependencies required

**Files:**
- `src/integrationTest/java/org/openphc/cce/insights/AbstractIntegrationTest.java`
- `src/integrationTest/resources/init-schema.sql`
- `src/integrationTest/resources/seed-data.sql`
- `src/integrationTest/java/org/openphc/cce/insights/web/controller/*ControllerIT.java`

---

## Subtask S14: Ingestion Analytics (inbound_event Integration) — 4 endpoints

**Type:** Story  
**Priority:** High  
**Story Points:** 5  
**Labels:** `feature`, `api`, `ingestion-analytics`

**Description:**  
Implement ingestion pipeline analytics by querying the `inbound_event` table (owned by the Collector Service). Provides acceptance/rejection funnels, rejection reason analysis, source data quality scores, and pipeline loss tracking (accepted events vs compliance-matched). Also migrates source-level event counts and source comparison to `inbound_event` for complete event visibility.

**Acceptance Criteria:**
- [ ] `InboundEvent` entity — maps `inbound_event` table, `@Immutable`, 16 columns including `status`, `rejection_reason`, `error_details`, `raw_payload` (JSONB)
- [ ] `InboundEventRepository` — 12 native SQL queries for status counts, rejection analysis, source quality, trends, overlap detection, and pipeline loss
- [ ] `IngestionAnalyticsService` — ingestion funnel, rejection analytics, source data quality, pipeline loss
- [ ] `GET /v1/insights/ingestion/funnel` — acceptance/rejection/duplicate rates with optional interval-based trends
- [ ] `GET /v1/insights/ingestion/rejections` — rejection reason breakdown, per-source rejection rates with top reasons
- [ ] `GET /v1/insights/ingestion/source-quality` — per-source quality scores (acceptance/rejection/duplicate rates)
- [ ] `GET /v1/insights/ingestion/pipeline-loss` — accepted events vs compliance-matched, loss rate per source
- [ ] DTOs: `IngestionFunnelDto`, `RejectionAnalyticsDto`, `SourceDataQualityDto`, `PipelineLossDto`
- [ ] Migration: `EventVolumeService.getBySource()` and `compareSourceSystems()` now use `InboundEventRepository`
- [ ] `init-schema.sql` updated with `inbound_event` DDL
- [ ] `seed-data.sql` updated with sample inbound_event rows
- [ ] `IngestionAnalyticsControllerIT` integration tests

**Files:**
- `src/main/java/org/openphc/cce/insights/domain/entity/InboundEvent.java`
- `src/main/java/org/openphc/cce/insights/domain/repository/InboundEventRepository.java`
- `src/main/java/org/openphc/cce/insights/service/IngestionAnalyticsService.java`
- `src/main/java/org/openphc/cce/insights/web/controller/IngestionAnalyticsController.java`
- `src/main/java/org/openphc/cce/insights/web/dto/IngestionFunnelDto.java`
- `src/main/java/org/openphc/cce/insights/web/dto/RejectionAnalyticsDto.java`
- `src/main/java/org/openphc/cce/insights/web/dto/SourceDataQualityDto.java`
- `src/main/java/org/openphc/cce/insights/web/dto/PipelineLossDto.java`

---

## Subtask S15: Deployment & Containerization

**Type:** Task  
**Priority:** Medium  
**Story Points:** 5  
**Labels:** `infrastructure`, `deployment`, `documentation`

**Description:**  
Add Docker containerization (multi-stage Dockerfile, docker-compose.yml), deployment guide (Docker, Kubernetes, bare-metal), release notes, and supporting files (.dockerignore, .env.example). Perform code optimization and synchronize all documentation to the final 33-endpoint codebase state.

**Acceptance Criteria:**
- [ ] `Dockerfile` — multi-stage build (eclipse-temurin:21-jdk-alpine → jre-alpine), non-root user, health check, JVM tuning
- [ ] `docker-compose.yml` — PostgreSQL 16 + insights-service with health checks and environment configuration
- [ ] `.dockerignore` — exclude build artifacts, IDE files, docs
- [ ] `.env.example` — document all environment variables with defaults
- [ ] `docs/deployment-guide.md` — Docker Compose, standalone Docker, Kubernetes (ConfigMap + Secret + Deployment + Service), bare-metal, systemd, monitoring, scaling
- [ ] `RELEASE_NOTES.md` — v1.0.0 release with full endpoint inventory, architecture summary, bug fixes, known limitations
- [ ] `README.md` — rewritten with project overview, quick start, endpoint summary, configuration, project structure
- [ ] Code optimization: extract `DateUtil` utility, fix `FacilityRankingService` deviation count bug, add missing `logstash-logback-encoder` dependency
- [ ] All `.md` files updated to reflect 38 endpoints, 6 entities, 10 services + DateUtil, 11 controllers, InboundEvent/IngestionAnalytics/Lookups/Caching additions

**Files:**
- `Dockerfile`
- `docker-compose.yml`
- `.dockerignore`
- `.env.example`
- `RELEASE_NOTES.md`
- `README.md`
- `docs/deployment-guide.md`
- `docs/architecture-overview.md` (updated)
- `docs/developer-setup.md` (updated)
- `docs/flow-diagrams.md` (updated)
- `artifacts/subtasks.md` (updated)
- `build.gradle` (logstash-logback-encoder added)
- `src/main/java/org/openphc/cce/insights/service/DateUtil.java` (new)
- `src/main/java/org/openphc/cce/insights/service/FacilityRankingService.java` (bug fix)

---

## Endpoint-to-Subtask Mapping

| # | Endpoint | Subtask |
|---|----------|---------|
| 1 | `GET /v1/insights/protocols/{id}/compliance-summary` | S4 |
| 2 | `GET /v1/insights/facilities/{id}/compliance-summary` | S4 |
| 3 | `GET /v1/insights/protocols/{id}/patients` | S4 |
| 4 | `GET /v1/insights/patients/{id}/compliance-timeline` | S5 |
| 5 | `GET /v1/insights/patients/{id}/protocol-tracking` | S5 |
| 6 | `GET /v1/insights/patients/{id}/protocol-tracking/{piId}` | S5 |
| 7 | `GET /v1/insights/patients/{id}/events` | S5 |
| 8 | `GET /v1/insights/patients/{id}/deviations` | S5 |
| 9 | `GET /v1/insights/deviations` | S6 |
| 10 | `GET /v1/insights/deviations/trends` | S6 |
| 11 | `GET /v1/insights/intelligence/summary` | S6 |
| 12 | `GET /v1/insights/events/summary` | S7 |
| 13 | `GET /v1/insights/events/trends` | S7 |
| 14 | `GET /v1/insights/events/by-resource-type` | S7 |
| 15 | `GET /v1/insights/events/by-facility` | S7 |
| 16 | `GET /v1/insights/events/by-practitioner` | S7 |
| 17 | `GET /v1/insights/events/by-source` | S7 |
| 18 | `GET /v1/insights/events/source-comparison` | S7 |
| 19 | `GET /v1/insights/protocols/{id}/step-analytics` | S8 |
| 20 | `GET /v1/insights/protocols/{id}/completion-funnel` | S8 |
| 21 | `GET /v1/insights/protocols/{id}/outcome-distribution` | S8 |
| 22 | `GET /v1/insights/protocols/{id}/enrollment-trends` | S8 |
| 23 | `GET /v1/insights/deviations/by-action` | S9 |
| 24 | `GET /v1/insights/deviations/resolution-rate` | S9 |
| 25 | `GET /v1/insights/facilities/ranking` | S9 |
| 26 | `GET /v1/insights/events/processing-quality` | S10 |
| 27 | `GET /v1/insights/patients/at-risk-hotspots` | S10 |
| 28 | `GET /v1/insights/patients/repeat-deviations` | S10 |
| 29 | `GET /v1/insights/exports/compliance-report` | S11 |
| 30 | `GET /v1/insights/ingestion/funnel` | S14 |
| 31 | `GET /v1/insights/ingestion/rejections` | S14 |
| 32 | `GET /v1/insights/ingestion/source-quality` | S14 |
| 33 | `GET /v1/insights/ingestion/pipeline-loss` | S14 |
| 34 | `GET /v1/insights/lookups/protocols` | S16 |
| 35 | `GET /v1/insights/lookups/facilities` | S16 |
| 36 | `GET /v1/insights/lookups/practitioners` | S16 |
| 37 | `GET /v1/insights/lookups/sources` | S16 |
| 38 | `GET /v1/insights/lookups/patients` | S16 |

---

## Dependency Graph

```
S0 (Docs)
 └── S1 (Scaffolding)
      └── S2 (Config)
           └── S3 (Entities & Repos)
                ├── S4 (Compliance Summary — 3 endpoints)
                ├── S5 (Patient Compliance — 5 endpoints)
                ├── S6 (Deviations & Intelligence — 3 endpoints)
                ├── S7 (Event Volume — 8 endpoints)
                ├── S8 (Protocol Analytics — 4 endpoints)
                ├── S9 (Deviation Analytics + Facility Ranking — 3 endpoints)
                ├── S10 (Processing Quality + Patient Risk — 3 endpoints)
                ├── S14 (Ingestion Analytics — 4 endpoints)
                └── S16 (Lookups + Caching — 5 endpoints)
                     └── S11 (Export — 1 endpoint)
                          └── S12 (Observability)
                               └── S13 (Integration Tests)
                                    └── S15 (Deployment & Containerization)
```

**Critical path:** S0 → S1 → S2 → S3 → S4–S10+S14+S16 (parallelizable — 9 subtasks, 38 endpoints) → S11 → S12 → S13 → S15

**Story Points Summary:**

| Subtask | Points | Endpoints |
|---------|--------|-----------|
| S0 Documentation | 5 | — |
| S1 Scaffolding | 2 | — |
| S2 Config | 1 | — |
| S3 Entities & Repos | 5 | — |
| S4 Compliance Summary | 5 | 3 |
| S5 Patient Compliance | 5 | 5 |
| S6 Deviations & Intelligence | 5 | 3 |
| S7 Event Volume + Source Comparison | 5 | 8 |
| S8 Protocol Analytics | 5 | 4 |
| S9 Deviation Analytics + Facility Ranking | 5 | 3 |
| S10 Processing Quality + Patient Risk | 5 | 3 |
| S11 Export | 3 | 1 |
| S12 Observability | 2 | — |
| S13 Integration Tests | 5 | — |
| S14 Ingestion Analytics (inbound_event) | 5 | 4 |
| S15 Deployment & Containerization | 5 | — |
| S16 Lookups, Caching & Optimization | 3 | 6 |
| **Total** | **66** | **38** |
