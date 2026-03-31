# CCE Insights Service — JIRA Subtasks (Sequential Execution)

**Epic:** CCE Insights Service — Compliance Analytics & Dashboards  
**Component:** `cce-insights-service`  
**Sprint Target:** Release 1.0.0  
**Total Subtasks:** 9  

> Each subtask is a single PR-able unit. Execute in listed order — each depends on the prior one being merged.

---

## Subtask S0: Technical Documentation & Design Artifacts

**Type:** Task  
**Priority:** Highest  
**Story Points:** 3  
**Labels:** `documentation`, `design`

**Description:**  
Create comprehensive technical documentation covering architecture, API reference, data dictionary, developer setup guide, and flow diagrams. This establishes the technical baseline for review before implementation begins.

**Acceptance Criteria:**
- [ ] `docs/architecture-overview.md` — System context diagram, tech stack, package structure (~10 packages, ~30 files), data access patterns, phased architecture (Phase 1 vs Phase 2), error handling, scaling
- [ ] `docs/api-reference.md` — All 10 REST endpoints: compliance summaries (3), patient compliance (3), deviations & intelligence (3), exports (1); request/response schemas, error format
- [ ] `docs/data-dictionary.md` — 5 read-only tables, enums, aggregation formulas, query filter parameters, pagination spec, metrics
- [ ] `docs/developer-setup.md` — Prerequisites, quick start, shared database (no Flyway), Docker Compose (PostgreSQL only), config reference, environment variables, project structure, testing, Docker build
- [ ] `docs/flow-diagrams.md` — Request flow, compliance summary aggregation, patient timeline query, deviation trend analysis, facility overview, export flow
- [ ] `copilot-instructions-insights-service.md` — AI agent instructions covering architecture, key conventions, database access patterns, API structure, build & run, testing

**Files:**
- `docs/architecture-overview.md`
- `docs/api-reference.md`
- `docs/data-dictionary.md`
- `docs/developer-setup.md`
- `docs/flow-diagrams.md`
- `copilot-instructions-insights-service.md`

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
Map the Compliance Service's database tables as read-only JPA entities. All entities use `@Immutable` — no insert/update/delete operations. Repositories extend `ReadOnlyRepository` (no `save`/`delete` methods).

**Acceptance Criteria:**
- [ ] `ProtocolDefinition` entity — maps `protocol_definition` table, `@Immutable`, JSONB fields (`definition`) mapped as `String`
- [ ] `ProtocolInstance` entity — maps `protocol_instance` table, `@Immutable`, `ProtocolInstanceStatus` enum, relationship to `ProtocolDefinition`
- [ ] `StepInstance` entity — maps `step_instance` table, `@Immutable`, `StepState` and `CompletionStatus` enums, relationship to `ProtocolInstance`
- [ ] `Deviation` entity — maps `deviation` table, `@Immutable`, `DeviationType` enum, relationship to `ProtocolInstance` and `StepInstance`
- [ ] `EventLog` entity — maps `event_log` table, `@Immutable`, JSONB `cloudevent_json` mapped as `String`
- [ ] `ReadOnlyRepository<T, ID>` base interface — extends `Repository<T, ID>` with `findById`, `findAll` (paginated), no mutating methods
- [ ] Individual repositories: `ProtocolDefinitionRepository`, `ProtocolInstanceRepository`, `StepInstanceRepository`, `DeviationRepository`, `EventLogRepository`
- [ ] Custom query methods annotated with `@Query` for aggregation queries
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

## Subtask S4: Compliance Summary Service & Endpoints

**Type:** Story  
**Priority:** High  
**Story Points:** 5  
**Labels:** `feature`, `api`

**Description:**  
Implement the compliance summary endpoints — protocol adherence rates, facility roll-ups, and compliance categorization. This is the primary dashboard data source.

**Acceptance Criteria:**
- [ ] `ComplianceSummaryService` — aggregation logic: adherence_rate = completed_steps / total_steps, category classification (on_track ≥80%, at_risk ≥50%, non_compliant <50%)
- [ ] `GET /v1/compliance-summary` — optional filters: `facility_id`, `protocol_canonical`, `from`, `to`
- [ ] `GET /v1/compliance-summary/{protocolCanonical}` — single protocol breakdown with step-level detail
- [ ] `GET /v1/compliance-summary/by-facility` — facility-level aggregation with pagination
- [ ] DTOs: `ComplianceSummaryResponse`, `ProtocolComplianceDetail`, `FacilityComplianceDTO`
- [ ] Response format: `{ "data": { ... } }` envelope
- [ ] Unit tests for adherence calculation edge cases (0 steps, all completed, all missed)
- [ ] MockMvc tests for each endpoint: 200 OK, pagination, filters, 404

**Files:**
- `src/main/java/org/openphc/cce/insights/service/ComplianceSummaryService.java`
- `src/main/java/org/openphc/cce/insights/web/controller/ComplianceSummaryController.java`
- `src/main/java/org/openphc/cce/insights/web/dto/ComplianceSummaryResponse.java`
- `src/main/java/org/openphc/cce/insights/web/dto/ProtocolComplianceDetail.java`
- `src/main/java/org/openphc/cce/insights/web/dto/FacilityComplianceDTO.java`

---

## Subtask S5: Patient Compliance Service & Endpoints

**Type:** Story  
**Priority:** High  
**Story Points:** 5  
**Labels:** `feature`, `api`

**Description:**  
Implement patient-level compliance endpoints — timeline view, protocol tracking detail, and per-patient compliance overview.

**Acceptance Criteria:**
- [ ] `PatientComplianceService` — timeline assembly, per-protocol step progression
- [ ] `GET /v1/patients/{patientId}/compliance` — patient overview across all protocols
- [ ] `GET /v1/patients/{patientId}/timeline` — chronological step events with status
- [ ] `GET /v1/patients/{patientId}/protocols/{protocolInstanceId}` — detailed step-by-step tracking for a single protocol
- [ ] DTOs: `PatientComplianceOverview`, `PatientTimelineResponse`, `TimelineEvent`, `ProtocolTrackingDetail`
- [ ] Unit tests for timeline ordering, empty results, multi-protocol scenarios
- [ ] MockMvc tests for each endpoint: 200 OK, 404 patient not found

**Files:**
- `src/main/java/org/openphc/cce/insights/service/PatientComplianceService.java`
- `src/main/java/org/openphc/cce/insights/web/controller/PatientComplianceController.java`
- `src/main/java/org/openphc/cce/insights/web/dto/PatientComplianceOverview.java`
- `src/main/java/org/openphc/cce/insights/web/dto/PatientTimelineResponse.java`
- `src/main/java/org/openphc/cce/insights/web/dto/ProtocolTrackingDetail.java`

---

## Subtask S6: Deviation Analytics Service & Endpoints

**Type:** Story  
**Priority:** High  
**Story Points:** 5  
**Labels:** `feature`, `api`

**Description:**  
Implement deviation and intelligence endpoints — recent deviations list, trend analysis over time, and intelligence summary.

**Acceptance Criteria:**
- [ ] `DeviationAnalyticsService` — deviation queries, trend aggregation with `DATE_TRUNC`
- [ ] `GET /v1/deviations` — paginated list, filters: `type`, `facility_id`, `protocol_canonical`, `from`, `to`
- [ ] `GET /v1/deviations/trends` — time-bucketed counts by `period` (day/week/month) and deviation type
- [ ] `GET /v1/intelligence/summary` — aggregated counts of triggers fired, grouped by type
- [ ] DTOs: `DeviationListResponse`, `DeviationTrendsResponse`, `TrendDataPoint`, `IntelligenceSummaryResponse`
- [ ] Unit tests for trend bucketing, empty date ranges, type filtering
- [ ] MockMvc tests for each endpoint: 200 OK, pagination, filter combinations

**Files:**
- `src/main/java/org/openphc/cce/insights/service/DeviationAnalyticsService.java`
- `src/main/java/org/openphc/cce/insights/web/controller/DeviationController.java`
- `src/main/java/org/openphc/cce/insights/web/controller/IntelligenceController.java`
- `src/main/java/org/openphc/cce/insights/web/dto/DeviationListResponse.java`
- `src/main/java/org/openphc/cce/insights/web/dto/DeviationTrendsResponse.java`
- `src/main/java/org/openphc/cce/insights/web/dto/IntelligenceSummaryResponse.java`

---

## Subtask S7: Export Service & Endpoint

**Type:** Story  
**Priority:** Medium  
**Story Points:** 3  
**Labels:** `feature`, `api`

**Description:**  
Implement the data export endpoint. Supports CSV format using streaming to avoid memory issues with large datasets.

**Acceptance Criteria:**
- [ ] `ExportService` — cursor-based streaming from database, CSV row transformation
- [ ] `GET /v1/export` — query params: `format=csv`, `type` (deviations|compliance|steps), filters (same as respective list endpoints)
- [ ] CSV export uses `StreamingResponseBody` — no full dataset buffering
- [ ] Response headers: `Content-Type: text/csv`, `Content-Disposition: attachment; filename="..."`
- [ ] Unit tests for CSV formatting (header row, escaping, date formatting)
- [ ] Integration test: export 100+ rows, verify streaming behavior

**Files:**
- `src/main/java/org/openphc/cce/insights/service/ExportService.java`
- `src/main/java/org/openphc/cce/insights/web/controller/ExportController.java`

---

## Subtask S8: Observability — Health, Metrics & Error Handling

**Type:** Task  
**Priority:** Medium  
**Story Points:** 2  
**Labels:** `observability`, `ops`

**Description:**  
Configure global error handling, custom health indicators, and Micrometer metrics. Ensure consistent error responses and operational visibility.

**Acceptance Criteria:**
- [ ] `GlobalExceptionHandler` with `@ControllerAdvice` — `{ "error": { "code": "...", "message": "..." } }` format
- [ ] Handle: `IllegalArgumentException` → 400, resource not found → 404, unexpected → 500
- [ ] Custom health indicator: database connectivity check (read-only query)
- [ ] Micrometer metrics: `insights.request.count` (by endpoint, status), `insights.query.duration` (by query type), `insights.export.rows` (counter)
- [ ] Prometheus endpoint at `/actuator/prometheus`
- [ ] Structured JSON logging (logback-spring.xml)

**Files:**
- `src/main/java/org/openphc/cce/insights/web/GlobalExceptionHandler.java`
- `src/main/java/org/openphc/cce/insights/config/MetricsConfig.java`
- `src/main/java/org/openphc/cce/insights/health/DatabaseHealthIndicator.java`
- `src/main/resources/logback-spring.xml`

---

## Subtask S9 (Stretch): Integration Tests & Test Data Seeding

**Type:** Task  
**Priority:** Medium  
**Story Points:** 3  
**Labels:** `testing`, `quality`

**Description:**  
Full integration test suite using Testcontainers PostgreSQL. Seed compliance schema and data from SQL scripts, then verify all endpoints end-to-end.

**Acceptance Criteria:**
- [ ] `AbstractIntegrationTest` base class — `@Testcontainers`, `@DynamicPropertySource`, PostgreSQL container with schema init
- [ ] SQL seed scripts: `init-schema.sql` (Compliance Service DDL), `seed-data.sql` (sample protocols, instances, steps, deviations)
- [ ] Integration tests for each controller: compliance summaries, patient compliance, deviations, export
- [ ] Verify pagination, filtering, edge cases (no data, 1 record, boundary dates)
- [ ] CI-ready: no external dependencies required

**Files:**
- `src/integrationTest/java/org/openphc/cce/insights/AbstractIntegrationTest.java`
- `src/integrationTest/resources/init-schema.sql`
- `src/integrationTest/resources/seed-data.sql`
- `src/integrationTest/java/org/openphc/cce/insights/web/controller/*ControllerIT.java`

---

## Dependency Graph

```
S0 (Docs)
 └── S1 (Scaffolding)
      └── S2 (Config)
           └── S3 (Entities & Repos)
                ├── S4 (Compliance Summary)
                ├── S5 (Patient Compliance)
                └── S6 (Deviation Analytics)
                     └── S7 (Export)
                          └── S8 (Observability)
                               └── S9 (Integration Tests)
```

**Critical path:** S0 → S1 → S2 → S3 → S4/S5/S6 (parallelizable) → S7 → S8 → S9
