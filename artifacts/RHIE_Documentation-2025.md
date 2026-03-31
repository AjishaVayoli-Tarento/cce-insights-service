# RHIE Technical Documentation
# Rwanda Health Information Exchange (RHIE)
**Version:** 2.0.0 | **FHIR Version:** 4.0.0 | **Ministry of Health, Rwanda**

---

## Table of Contents
1. [System Overview](#system-overview)
2. [Architecture](#architecture)
3. [Authentication & Security](#authentication--security)
4. [Global Validations](#global-validations)
5. [Patient Journey](#patient-journey)
6. [FHIR Resources](#fhir-resources)
7. [API Endpoints](#api-endpoints)
8. [Validation Rules](#validation-rules)
9. [Code Systems & Terminologies](#code-systems--terminologies)
10. [Integration Patterns](#integration-patterns)
11. [Error Handling](#error-handling)
12. [Best Practices](#best-practices)

---

## System Overview

### What is RHIE?
The Rwanda Health Information Exchange (RHIE) is a national health information system that enables the secure exchange of patient health information across healthcare facilities in Rwanda. It is built on FHIR (Fast Healthcare Interoperability Resources) standards.

### Key Components
1. **SHR (Shared Health Record)** - Central repository for patient health records
2. **Client Registry (CR)** - Patient demographic and identifier management
3. **UPID Generator** - Unique Patient Identifier generation service

### Supported Features
- Patient Registration & Demographics
- Visit & Consultation Management
- Vital Signs Recording
- Electronic Prescriptions (e-Prescription)
- Lab Orders & Results
- Imaging Orders & Studies
- Diagnosis & Conditions
- Procedures & Immunizations
- Electronic Transfers (e-Transfers)
- Medication Dispensing & Administration
- International Patient Summary (IPS)
- Patient Consent Management

---

## Architecture

### Data Flow
1. **Registration Flow:** EMR → UPID Generator → Client Registry → SHR
2. **Clinical Data Flow:** EMR → SHR (with references to CR)
3. **Query Flow:** EMR → SHR → Response with linked resources

---

## Authentication & Security

### HTTP Basic Authentication
All API requests require HTTP Basic Authentication.

**Example Credentials:**
- Username: `MRS_TEST`
- Password: `Ubuzima1.`

### Security Headers
```
Authorization: Basic <base64(username:password)>
Content-Type: application/fhir+json
Accept: application/fhir+json
```

**Pre-encoded header:**
```
Authorization: Basic TVJTX1RFU1Q6VWJ1emltYTEu
```

### Request Example
```bash
curl -X GET \
  'http://197.243.24.138:5000/cr/Patient/251119-0001-4106' \
  -H 'Authorization: Basic TVJTX1RFU1Q6VWJ1emltYTEu' \
  -H 'Accept: application/fhir+json'
```

---

## Global Validations

All FHIR resources must comply with the following global validations:

### Mandatory Requirements
1. **Unique Identifiers:** All resources must have a unique UUID identifier
2. **Reference Resolution:** All references (subject, encounter, practitioner, location) must resolve correctly
3. **ISO 8601 Dates:** All dates/times must be in ISO 8601 format
4. **Logical Consistency:** Dates must be logically consistent (no future dates for historical events)
5. **Valid Terminologies:** Coding must be from valid terminology systems
6. **Deceased Validation:** If patient has deceased status, no medical encounters should be saved after deceased date

### Reference Format
All FHIR references must follow the pattern: `ResourceType/ResourceId`

**Examples:**
```
Patient/251119-0001-4106
Encounter/9a8e5398-64ee-4111-84a0-9e1e6e0a0121
Practitioner/HLC-PRAC-2025-00005
Location/1163f2b9-08b0-4333-8e60-6a6fadc91f4f
```

---

## Patient Journey

### 1. Patient Registration
- **UPID Format:** `YYMMDD-FOSAID-RAND4` (e.g., `251119-0001-4106`)
- NID validation against DOB is performed by CR service
- Patient must exist before any clinical data

**Flow:** Check CR → Query Demographics → Generate UPID → POST Patient to CR → Create Visit Encounter

### 2. Vital Signs Recording
Vital Signs may include:
- Blood Pressure (Systolic/Diastolic)
- Heart Rate
- Respiratory Rate
- Temperature
- Oxygen Saturation
- Weight/Height/BMI

### 3. Consultation Encounter
**Consultation Structure:**
- Consultation Encounter (Must always reference Visit Encounter)
- Chief Complaints (Observation referencing Consultation Encounter)
- Clinical Findings (Observation referencing Consultation Encounter)
- Assessment Notes (Observation referencing Consultation Encounter)

### 4. Investigations
**Investigation Types:**
- Laboratory Tests (ServiceRequest → Observation)
- Imaging Studies (ServiceRequest → ImagingStudy)
- Diagnostic Reports (DiagnosticReport)

### 5. Diagnosis
- Create Condition Resource linked to Encounter with ICD-11 coding

### 6. Treatment
**Treatment Flow:**
- **MedicationRequest:** Prescription order (e-Prescription)
- **MedicationDispense:** Pharmacy dispensing
- **MedicationAdministration:** Actual administration to patient

> **Key Concept - groupIdentifier:** Multiple medications prescribed together share the same `groupIdentifier` (prescription code).

### 7. Procedures & Immunizations
- **Procedure:** Record surgical or medical procedures performed
- **Immunization:** Record vaccines administered

### 8. Transfers
- Create Transfer Encounter with Origin and Destination Location

---

## FHIR Resources

### Resource Hierarchy
```
Patient (Root)
├── Consent
├── Encounter (Visit)
│   ├── Encounter (Consultation)
│   │   ├── Observation (Chief Complaints)
│   │   └── Observation (Clinical Findings)
│   ├── Encounter (Transfer)
│   ├── Observation (Vital Signs)
│   ├── Condition (Diagnosis)
│   ├── AllergyIntolerance
│   ├── Immunization
│   ├── ServiceRequest (Lab Order)
│   │   └── Observation (Lab Results)
│   ├── ServiceRequest (Imaging Order)
│   │   └── ImagingStudy
│   ├── Procedure
│   └── MedicationRequest (Prescription)
│       ├── MedicationDispense
│       └── MedicationAdministration
└── Bundle (IPS - International Patient Summary)
```

### Core Resources Overview
| Resource | Purpose | Key Identifiers |
|---|---|---|
| Patient | Patient demographics | UPID, NID, Passport |
| Consent | Patient consent records | Patient reference |
| Encounter | Healthcare visit/interaction | Visit ID, Type |
| Observation | Clinical observations | Category, Code |
| Condition | Diagnoses | ICD-11 Code |
| AllergyIntolerance | Allergies | NPC Code |
| Immunization | Vaccinations | NPC Code |
| ServiceRequest | Orders for services | Category, Code |
| ImagingStudy | Imaging results | DICOM modality |
| Procedure | Procedures performed | ICHI Code |
| MedicationRequest | Prescriptions | SNOMED CT Code |
| MedicationDispense | Medication dispensing | SNOMED CT Code |
| MedicationAdministration | Medication given | SNOMED CT Code |

---

## API Endpoints

### Patient Management

#### Search Patient
```
GET /Patient?identifier={upid}
GET /Patient?given={firstName}&family={lastName}
GET /Patient?birthdate={YYYY-MM-DD}
```

#### Create Patient
```http
POST /Patient
Content-Type: application/fhir+json
```
```json
{
  "resourceType": "Patient",
  "id": "251119-0001-4106",
  "identifier": [
    { "system": "NID", "value": "1192880005226000" },
    { "system": "UPI", "value": "251119-0001-4106" }
  ],
  "active": true,
  "name": [{ "family": "MUGISHA", "given": ["BENON"] }],
  "gender": "male",
  "birthDate": "1928-01-01",
  "telecom": [{ "system": "phone", "value": "+250796000075", "use": "mobile" }],
  "address": [{
    "type": "physical",
    "country": "Rwanda",
    "state": "1#Umujyi wa Kigali (Kigali City)",
    "district": "1#Nyarugenge",
    "line": "1#Gihanga",
    "city": "1#Umujyi wa Kigali (Kigali City)"
  }],
  "maritalStatus": {
    "coding": [{
      "system": "http://terminology.hl7.org/CodeSystem/v3-MaritalStatus",
      "code": "S",
      "display": "SINGLE"
    }]
  },
  "deceasedBoolean": false
}
```

#### Read Patient
```
GET /Patient/{id}
```

---

### Consent Management

#### Create Consent
```http
POST /Consent
```
```json
{
  "resourceType": "Consent",
  "status": "active",
  "scope": {
    "coding": [{
      "system": "http://terminology.hl7.org/CodeSystem/consentscope",
      "code": "patient-privacy",
      "display": "Privacy Consent"
    }]
  },
  "category": [{
    "coding": [{
      "system": "http://terminology.hl7.org/CodeSystem/v3-ActCode",
      "code": "INFA",
      "display": "information access"
    }]
  }],
  "patient": { "reference": "Patient/251119-0001-4106" },
  "dateTime": "2025-11-18T10:18:07+00:00"
}
```

---

### Encounter Management

#### 1. Create Visit Encounter
```http
POST /Encounter
```
```json
{
  "resourceType": "Encounter",
  "id": "9a8e5398-64ee-4111-84a0-9e1e6e0a0121",
  "meta": {
    "tag": [{
      "system": "http://fhir.openmrs.org/ext/encounter-tag",
      "code": "encounter",
      "display": "Encounter"
    }]
  },
  "status": "finished",
  "class": {
    "system": "http://terminology.hl7.org/CodeSystem/v3-ActCode",
    "code": "AMB",
    "display": "Ambulatory"
  },
  "type": [{ "coding": [{ "display": "VISIT_ENCOUNTER" }] }],
  "serviceType": {
    "coding": [{
      "system": "http://terminology.hl7.org/CodeSystem/service-type",
      "display": "Outpatients"
    }]
  },
  "subject": {
    "reference": "Patient/251119-0001-4106",
    "type": "Patient",
    "display": "BENON MUGISHA"
  },
  "participant": [{
    "individual": {
      "reference": "Practitioner/HLC-PRAC-2025-00005",
      "display": "MUTIMUKEYE Clarisse"
    }
  }],
  "period": { "start": "2025-11-19T13:35:35+02:00" },
  "location": [{
    "location": {
      "reference": "Location/1163f2b9-08b0-4333-8e60-6a6fadc91f4f",
      "display": "Kibagabaga Level Two Teaching Hospital"
    }
  }]
}
```

#### 2. Create Consultation Encounter
```http
POST /Encounter
```
```json
{
  "resourceType": "Encounter",
  "id": "0c9036b7-5b25-4465-8c77-a4bb1cbeda95",
  "status": "finished",
  "class": {
    "system": "http://terminology.hl7.org/CodeSystem/v3-ActCode",
    "code": "AMB"
  },
  "type": [{ "coding": [{ "display": "CONSULTATION_ENCOUNTER" }] }],
  "subject": { "reference": "Patient/251119-0001-4106" },
  "participant": [{ "individual": { "reference": "Practitioner/HLC-PRAC-2025-00005" } }],
  "period": { "start": "2025-11-19T13:35:35+02:00" },
  "location": [{ "location": { "reference": "Location/1163f2b9-08b0-4333-8e60-6a6fadc91f4f" } }],
  "partOf": { "reference": "Encounter/9a8e5398-64ee-4111-84a0-9e1e6e0a0121" }
}
```

#### 3. Create Transfer Encounter
```http
POST /Encounter
```
```json
{
  "resourceType": "Encounter",
  "id": "6370fc4a-4f77-4a53-93e4-6cced7325474",
  "status": "finished",
  "class": { "system": "http://terminology.hl7.org/CodeSystem/v3-ActCode", "code": "AMB" },
  "type": [{ "coding": [{ "display": "TRANSFER_ENCOUNTER" }] }],
  "subject": { "reference": "Patient/251119-0001-4106" },
  "participant": [{ "individual": { "reference": "Practitioner/HLC-PRAC-2025-00005" } }],
  "period": { "start": "2025-11-19T13:35:35+02:00" },
  "hospitalization": {
    "origin": {
      "reference": "Location/1163f2b9-08b0-4333-8e60-6a6fadc91f4f",
      "identifier": { "value": "0001" },
      "display": "Kicukiro Health Center"
    },
    "destination": {
      "reference": "Location/1163f2b9-08b0-4333-8e60-6a6fadc91f4f",
      "identifier": { "value": "0002" },
      "display": "Kibagabaga Hospital"
    }
  },
  "location": [{ "location": { "reference": "Location/1163f2b9-08b0-4333-8e60-6a6fadc91f4f" } }],
  "partOf": { "reference": "Encounter/9a8e5398-64ee-4111-84a0-9e1e6e0a0121" }
}
```

#### 4. Search Encounters
```
GET /Encounter?fromDate={yyyy-mm-dd}&toDate={yyyy-mm-dd}&page=1&size=20
GET /Encounter?searchSet=UPI&value={upid}
```

---

### Observation Management

#### 1. Create Vital Signs Observation
```http
POST /Observation
```
```json
{
  "resourceType": "Observation",
  "id": "9a89ba8a-ca93-4449-9d89-71aeb6b4352a",
  "status": "final",
  "category": [{
    "coding": [{
      "system": "http://terminology.hl7.org/CodeSystem/observation-category",
      "code": "vital-signs",
      "display": "Vital Signs"
    }]
  }],
  "code": {
    "coding": [{ "system": "http://loinc.org", "code": "8480-6", "display": "Systolic blood pressure" }]
  },
  "subject": { "reference": "Patient/251119-0001-4106" },
  "encounter": { "reference": "Encounter/9a8e5398-64ee-4111-84a0-9e1e6e0a0121" },
  "performer": [{ "reference": "Practitioner/f830114a-bc0b-410e-b8c7-79e61c0df653", "display": "Salman Muhammed" }],
  "valueQuantity": { "value": 160, "unit": "mmHg", "system": "http://unitsofmeasure.org" },
  "effectiveDateTime": "2025-11-18T06:18:07+00:00"
}
```

#### 2. Create Consultation Observation (Chief Complaints)
```http
POST /Observation
```
```json
{
  "resourceType": "Observation",
  "id": "404c4536-3773-4f62-83c4-a1b23ab9dfb2",
  "status": "final",
  "category": [{
    "coding": [{
      "system": "http://terminology.hl7.org/CodeSystem/observation-category",
      "code": "survey",
      "display": "Survey"
    }]
  }],
  "code": {
    "coding": [{ "system": "http://loinc.org", "code": "33747-0", "display": "Chief Complaints" }]
  },
  "subject": { "reference": "Patient/251119-0001-4106" },
  "encounter": { "reference": "Encounter/9a8e5398-64ee-4111-84a0-9e1e6e0a0121" },
  "performer": [{ "reference": "Practitioner/f830114a-bc0b-410e-b8c7-79e61c0df653" }],
  "valueString": "Headache since 2 days",
  "effectiveDateTime": "2025-11-18T06:18:07+00:00"
}
```

#### 3. Create Lab Results Observation
```http
POST /Observation
```
```json
{
  "resourceType": "Observation",
  "id": "304c4536-3773-4f62-83c4-a1b23ab9dfb1",
  "status": "final",
  "category": [{
    "coding": [{
      "system": "http://terminology.hl7.org/CodeSystem/observation-category",
      "code": "laboratory",
      "display": "Laboratory"
    }]
  }],
  "code": {
    "coding": [{ "system": "http://loinc.org", "code": "33747-0", "display": "Full Blood Count" }]
  },
  "subject": { "reference": "Patient/251119-0001-4106" },
  "encounter": { "reference": "Encounter/9a8e5398-64ee-4111-84a0-9e1e6e0a0121" },
  "performer": [{ "reference": "Practitioner/f830114a-bc0b-410e-b8c7-79e61c0df653" }],
  "valueQuantity": { "value": 160, "unit": "mmHg", "system": "http://unitsofmeasure.org" },
  "effectiveDateTime": "2025-11-18T06:18:07+00:00"
}
```

---

### AllergyIntolerance Management

#### Create AllergyIntolerance
```http
POST /AllergyIntolerance
```
```json
{
  "resourceType": "AllergyIntolerance",
  "id": "9c3cd6b6-1e07-4dd8-94ad-2edb41d0f1bc",
  "clinicalStatus": {
    "coding": [{ "system": "http://terminology.hl7.org/CodeSystem/allergyintoleranceclinical", "code": "active" }]
  },
  "verificationStatus": {
    "coding": [{ "system": "http://terminology.hl7.org/CodeSystem/allergyintoleranceverification", "code": "confirmed" }]
  },
  "patient": { "reference": "Patient/251119-0001-4106" },
  "encounter": { "reference": "Encounter/9a8e5398-64ee-4111-84a0-9e1e6e0a0121" },
  "code": {
    "coding": [{ "system": "http://npc.rw/npc", "code": "227493005", "display": "Penicillin" }]
  },
  "onsetDateTime": "2025-11-18T10:18:07+00:00",
  "recordedDate": "2025-11-18",
  "extension": [{
    "url": "http://example.org/fhir/StructureDefinition/location",
    "valueReference": { "reference": "Location/12345" }
  }]
}
```

---

### Immunization Management

#### Create Immunization
```http
POST /Immunization
```
```json
{
  "resourceType": "Immunization",
  "id": "3d178818-a99c-442d-9694-c88525e0ee26",
  "status": "completed",
  "vaccineCode": {
    "coding": [{ "system": "http://npc.rw", "code": "333598008", "display": "Influenza vaccine" }]
  },
  "patient": { "reference": "Patient/251119-0001-4106" },
  "encounter": { "reference": "Encounter/9a8e5398-64ee-4111-84a0-9e1e6e0a0121" },
  "occurrenceDateTime": "2024-11-18T10:18:10+00:00",
  "location": { "reference": "Location/e7fafc08-6a99-4dae-bf13-a9a7d8b0df8d", "display": "Kibagabaga Hospital" },
  "performer": [{
    "function": {
      "coding": [{
        "system": "http://terminology.hl7.org/CodeSystem/v2-0443",
        "code": "AP",
        "display": "Administering Provider"
      }]
    },
    "actor": { "reference": "Practitioner/cd65ae81-e6d5-4e3c-a8e9-dd9b3d5b28af", "display": "Dr Aziz Muhammed" }
  }]
}
```

---

### ServiceRequest Management (Lab Orders)

#### Create Lab Order
```http
POST /ServiceRequest
```
```json
{
  "resourceType": "ServiceRequest",
  "id": "a430a35a-978b-4a0c-a564-efc6d639bcd3",
  "status": "active",
  "intent": "order",
  "category": {
    "coding": { "system": "http://snomed.info/sct", "code": "108252007", "display": "Laboratory procedure" }
  },
  "code": {
    "coding": [{ "system": "http://snomed.info/sct", "code": "15220000", "display": "Full Blood Count" }]
  },
  "subject": { "reference": "Patient/251119-0001-4106" },
  "encounter": { "reference": "Encounter/9a8e5398-64ee-4111-84a0-9e1e6e0a0121" },
  "occurrenceDateTime": "2025-11-18T09:18:09+00:00",
  "requester": { "reference": "Practitioner/cd65ae81-e6d5-4e3c-a8e9-dd9b3d5b28af", "display": "Dr Aziz Muhammed" },
  "performer": { "reference": "Practitioner/cd65ae81-e6d5-4e3c-a8e9-dd9b3d5b28af" },
  "locationReference": { "reference": "Location/12345" }
}
```

---

### ImagingStudy Management

#### Create ImagingStudy
```http
POST /ImagingStudy
```
```json
{
  "resourceType": "ImagingStudy",
  "id": "f6991e61-26cd-4f97-b652-25738e7c8b89",
  "status": "available",
  "modality": { "system": "https://dicom.nema.org/", "code": "XA", "display": "X-Ray Angiography" },
  "subject": { "reference": "Patient/251119-0001-4106" },
  "encounter": { "reference": "Encounter/9a8e5398-64ee-4111-84a0-9e1e6e0a0121" },
  "started": "2025-11-19T14:30:00+02:00",
  "procedureCode": [{
    "coding": [{ "system": "http://www.ichi.org/", "code": "71250", "display": "X-ray of right shoulder" }]
  }],
  "reasonCode": [{
    "coding": [{ "system": "http://hl7.org/fhir/sid/icd-10", "code": "R05.1", "display": "Acute Pain" }]
  }],
  "description": "X-ray of right shoulder",
  "conclusion": "No evidence of fracture. Mild degenerative changes noted.",
  "series": [{
    "uid": "1.2.3.4.5.6.7.8.1",
    "number": 1,
    "description": "X-ray of right shoulder",
    "bodySite": {
      "code": {
        "coding": [{ "system": "http://snomed.info/sct", "code": "39607008", "display": "Right Shoulder" }]
      }
    },
    "instance": [{
      "uid": "1.2.3.4.5.6.7.8.1.1",
      "sopClass": { "system": "urn:ietf:rfc:3986", "code": "1.2.840.10008.5.1.4.1.1.2" },
      "number": 1,
      "title": "XRAY Image Instance"
    }]
  }]
}
```

---

### Condition Management (Diagnosis)

#### Create Condition
```http
POST /Condition
```
```json
{
  "resourceType": "Condition",
  "id": "a3fbd599-5ae9-4043-a9ba-27795822a393",
  "clinicalStatus": {
    "coding": [{ "system": "http://terminology.hl7.org/CodeSystem/condition-clinical", "code": "active" }]
  },
  "verificationStatus": {
    "coding": [{ "system": "http://terminology.hl7.org/CodeSystem/condition-ver-status", "code": "confirmed" }]
  },
  "code": {
    "coding": [{ "system": "https://icd.who.int", "code": "1F42", "display": "Malaria due to Plasmodium malariae" }]
  },
  "subject": { "reference": "Patient/251119-0001-4106" },
  "encounter": { "reference": "Encounter/9a8e5398-64ee-4111-84a0-9e1e6e0a0121" },
  "onsetDateTime": "2025-11-18T10:18:07+00:00",
  "asserter": { "reference": "Practitioner/f830114a-bc0b-410e-b8c7-79e61c0df653", "display": "Dr. Aziz Muhammed" }
}
```

---

### Procedure Management

#### Create Procedure
```http
POST /Procedure
```
```json
{
  "resourceType": "Procedure",
  "id": "288b63e3-3ad1-4ee2-b431-4fd394655fa6",
  "status": "completed",
  "code": {
    "coding": [{ "system": "ICHI", "code": "18629005", "display": "Administration of vaccine" }]
  },
  "subject": { "reference": "Patient/251119-0001-4106" },
  "encounter": { "reference": "Encounter/9a8e5398-64ee-4111-84a0-9e1e6e0a0121" },
  "performedDateTime": "2025-11-19T19:17:57+00:00",
  "performer": [{
    "function": {
      "coding": [{
        "system": "http://terminology.hl7.org/CodeSystem/v3-ParticipationType",
        "code": "PRF",
        "display": "Performer"
      }]
    },
    "actor": { "reference": "Practitioner/818565f8-b6f2-41ad-9218-b7075738985b", "display": "Dr. Aziz Muhammed" }
  }],
  "location": { "reference": "Location/745c17bb-a41b-494c-9955-48491f7de5bb", "display": "Kibagabaga Hospital" }
}
```

---

### Medication Management

#### 1. Create MedicationRequest (e-Prescription)
```http
POST /MedicationRequest
```
```json
{
  "resourceType": "MedicationRequest",
  "id": "6d7c9160-c48f-4dc4-ab9f-d518c7d0e695",
  "status": "active",
  "intent": "order",
  "medicationCodeableConcept": {
    "coding": [{ "system": "http://snomed.info/sct", "code": "372756006", "display": "Amoxicillin" }]
  },
  "subject": { "reference": "Patient/251119-0001-4106" },
  "encounter": { "reference": "Encounter/9a8e5398-64ee-4111-84a0-9e1e6e0a0121" },
  "authoredOn": "2025-11-18T09:30:00+02:00",
  "requester": { "reference": "Practitioner/dr-mutesi-jane", "display": "Dr. Jane Mutesi" },
  "groupIdentifier": {
    "system": "http://moh.gov.rw/prescription-code",
    "value": "PR-2025-11-20-001"
  },
  "insurance": [{ "reference": "Coverage/cov-mituelle-230321", "display": "Mituelle de Santé" }],
  "dosageInstruction": [{
    "text": "Take 2 tablets by mouth three times daily for 7 days",
    "timing": { "repeat": { "frequency": 3, "period": 1, "periodUnit": "d" } },
    "route": {
      "coding": [{ "system": "http://snomed.info/sct", "code": "26643006", "display": "Oral route" }]
    },
    "doseAndRate": [{
      "doseQuantity": {
        "value": 50,
        "unit": "mg",
        "system": "http://terminology.hl7.org/CodeSystem/v3-orderableDrugForm",
        "code": "Mg"
      }
    }]
  }],
  "extension": [{
    "url": "http://hl7.org/fhir/StructureDefinition/location",
    "valueReference": {
      "reference": "Location/87654321-abcd-efgh-ijkl1234567890ab",
      "display": "KIBAGABAGA District Hospital"
    }
  }]
}
```

> **Note on groupIdentifier:** When multiple medications are prescribed together, they all share the same `groupIdentifier` value (prescription code).

#### 2. Create MedicationDispense
```http
POST /MedicationDispense
```
```json
{
  "resourceType": "MedicationDispense",
  "id": "d64229f8-af5b-4818-9e0d-8072d2b0c05a",
  "status": "completed",
  "medicationCodeableConcept": {
    "coding": [{ "system": "http://snomed.info/sct", "code": "387517004", "display": "Paracetamol" }]
  },
  "subject": { "reference": "Patient/251119-0001-4106" },
  "encounter": { "reference": "Encounter/9a8e5398-64ee-4111-84a0-9e1e6e0a0121" },
  "authorizingPrescription": [{ "reference": "MedicationRequest/6d7c9160-c48f-4dc4-ab9f-d518c7d0e695" }],
  "performer": [{ "actor": { "reference": "Practitioner/ba98f017-80b0-4af3-8819-b3bdef862aca", "display": "Dr. Johnson Bill" } }],
  "destination": { "reference": "Location/87654321-abcd-efgh-ijkl1234567890ab", "display": "KIBAGABAGA Hospital" },
  "whenHandedOver": "2025-11-18T02:00:00+00:00",
  "quantity": { "value": 500, "unit": "mg", "system": "http://unitsofmeasure.org" },
  "dosageInstruction": [{
    "timing": { "repeat": { "frequency": 2, "period": 1, "periodUnit": "d" } },
    "route": {
      "coding": [{ "system": "http://snomed.info/sct", "code": "26643006", "display": "Oral route" }]
    },
    "doseAndRate": [{ "doseQuantity": { "value": 500, "unit": "mg", "system": "http://unitsofmeasure.org" } }]
  }]
}
```

#### 3. Create MedicationAdministration
```http
POST /MedicationAdministration
```
```json
{
  "resourceType": "MedicationAdministration",
  "id": "9d99df65-d61d-4c7a-b3e5-9b9d18ba88d5",
  "status": "completed",
  "medicationCodeableConcept": {
    "coding": [{ "system": "http://snomed.info/sct", "code": "372756006", "display": "Amoxicillin" }]
  },
  "subject": { "reference": "Patient/251119-0001-4106" },
  "context": { "reference": "Encounter/9a8e5398-64ee-4111-84a0-9e1e6e0a0121" },
  "supportingInformation": [{ "reference": "MedicationRequest/6d7c9160-c48f-4dc4-ab9f-d518c7d0e695" }],
  "effectiveDateTime": "2025-11-18T10:15:00+02:00",
  "performer": [{
    "function": {
      "coding": [{
        "system": "http://terminology.hl7.org/CodeSystem/medication-admin-performer-function",
        "code": "performer",
        "display": "Performer"
      }]
    },
    "actor": { "reference": "Practitioner/nurse-12345", "display": "Nurse Uwase Marie" }
  }],
  "request": { "reference": "MedicationRequest/6d7c9160-c48f-4dc4-ab9f-d518c7d0e695" },
  "dosage": {
    "text": "Injection IV",
    "route": {
      "coding": [{ "system": "http://snomed.info/sct", "code": "26643006", "display": "Intravenous route" }]
    },
    "method": {
      "coding": [{ "system": "http://snomed.info/sct", "code": "738995006", "display": "Injection" }]
    },
    "dose": { "value": 100, "unit": "mg", "system": "http://unitsofmeasure.org", "code": "mg" }
  },
  "extension": [{
    "url": "http://hl7.org/fhir/StructureDefinition/medicationadministration-location",
    "valueReference": {
      "reference": "Location/87654321-abcd-efgh-ijkl1234567890ab",
      "display": "KIBAGABAGA District Hospital"
    }
  }]
}
```

---

### International Patient Summary (IPS)

#### Get IPS
```
GET /Bundle/$ips?patient={patientId}
```
Returns a complete Bundle containing all patient clinical information in IPS format.

---

## Validation Rules

### Patient Validations
| Rule | Description | Error Message |
|---|---|---|
| UPID Format | Must match: `YYMMDD-FOSAID-RAND4` | "Invalid UPID format" |
| NID vs DOB | If NID provided, must validate against DOB | "NID does not match birth date" |
| Future DOB | Birth date cannot be in the future | "Birth date cannot be future dated" |
| Resource ID = UPID | Resource identifier must equal UPID identifier | "Resource ID must match UPID" |
| Required Fields | identifier, name, gender, birthDate required | "Missing required field: {field}" |
| Deceased Check | No encounters after deceased date | "Cannot create encounter for deceased patient" |

### Encounter Validations
| Rule | Description | Error Message |
|---|---|---|
| Subject Required | Patient reference mandatory | "Subject is required" |
| Practitioner Required | Participant with practitioner reference mandatory | "Practitioner reference is required" |
| Location Required | Location reference mandatory | "Location is required" |
| Type Required | Encounter type mandatory | "Encounter type is required" |
| partOf (Consultation) | Consultation must reference parent Visit | "partOf reference to Visit required" |
| Transfer Origin/Dest | Transfer must have origin and destination | "Transfer requires origin and destination" |

### Observation Validations
| Rule | Description | Error Message |
|---|---|---|
| Encounter Required | Encounter reference mandatory | "Encounter reference is required" |
| Value Not N/A | Value cannot be "N/A" | "Value cannot be N/A" |
| Subject Required | Patient reference mandatory | "Subject is required" |
| Performer Required | Practitioner reference mandatory | "Performer is required" |
| Category Required | Category based on type (vital-signs, laboratory, survey) | "Category is required" |
| Code System | LOINC for lab results and vital signs | "Invalid code system" |

### AllergyIntolerance Validations
| Rule | Description | Error Message |
|---|---|---|
| Clinical Status | Required (active, inactive, resolved) | "Clinical status is required" |
| Verification Status | Required (unconfirmed, confirmed, refuted) | "Verification status is required" |
| Patient Required | Patient reference required | "Patient reference is required" |
| Code Required | Allergy code mandatory | "Allergy code is required" |
| RecordedDate | Mandatory | "RecordedDate is required" |
| OnsetDateTime | Mandatory | "OnsetDateTime is required" |
| Location | Required via extension | "Location reference is required" |

### Immunization Validations
| Rule | Description | Error Message |
|---|---|---|
| Status | Required (completed, not-done) | "Status is required" |
| Vaccine Code | NPC code required | "Vaccine code is required" |
| Patient Required | Patient reference required | "Patient reference is required" |
| Occurrence Date | Not in future, required | "Occurrence date cannot be future" |
| Performer Required | Practitioner required | "Performer is required" |
| Location Required | Location required | "Location is required" |
| Encounter | Encounter NOT mandatory | N/A |

### ServiceRequest Validations (Lab/Imaging)
| Rule | Description | Error Message |
|---|---|---|
| Status | Required (active, completed, etc.) | "Status is required" |
| Intent | Required (order) | "Intent is required" |
| Category | Lab: 108252007, Imaging: 363679005 | "Invalid category code" |
| Code | SNOMED CT code required | "Code is required" |
| Subject Required | Patient reference required | "Subject is required" |
| Occurrence Date | Not future, mandatory | "Occurrence date cannot be future" |
| Requester | Practitioner required | "Requester is required" |
| Performer | Practitioner required | "Performer is required" |
| Location | Required | "Location is required" |

### Condition Validations
| Rule | Description | Error Message |
|---|---|---|
| Clinical Status | Required (active, resolved, recurrence, remission) | "Clinical status is required" |
| Verification Status | Required (unconfirmed, provisional, differential, confirmed) | "Verification status is required" |
| Code | ICD-11 code required | "Condition code is required" |
| Subject Required | Patient reference mandatory | "Subject is required" |
| Asserter Required | Practitioner mandatory | "Asserter is required" |

### Procedure Validations
| Rule | Description | Error Message |
|---|---|---|
| Status | Required (completed default) | "Status is required" |
| Code | ICHI code required | "Procedure code is required" |
| Subject Required | Patient reference required | "Subject is required" |
| Performed Date | Not future, required | "Performed date cannot be future" |
| Performer | Practitioner required | "Performer is required" |
| Location | Required | "Location is required" |

### Medication Validations
| Rule | Description | Error Message |
|---|---|---|
| Status | Required (active, stopped, completed) | "Status is required" |
| Code | SNOMED CT code required | "Medication code is required" |
| Subject Required | Patient reference required | "Subject is required" |
| Performer/Actor | Practitioner required | "Performer is required" |
| Location | Required via extension | "Location is required" |
| Dosage | Route, method, dose mandatory | "Dosage information is required" |
| Date/Time | Mandatory, not future for admin | "Date/time is required" |

### Consent Validations
| Rule | Description | Error Message |
|---|---|---|
| Status | Required (draft, proposed, active, rejected, inactive) | "Status is required" |
| Scope | Required (patient-privacy, treatment, research) | "Scope is required" |
| Category | Mandatory | "Category is required" |
| Patient Required | Patient reference mandatory | "Patient reference is required" |
| DateTime | Mandatory | "DateTime is required" |

---

## Code Systems & Terminologies

### Primary Code Systems
| System | Purpose | URL | Example |
|---|---|---|---|
| LOINC | Lab tests, Vital signs | http://loinc.org | 8480-6 (Systolic BP) |
| SNOMED CT | Clinical terms, Medications | http://snomed.info/sct | 372756006 (Amoxicillin) |
| ICD-11 | Diagnoses | https://icd.who.int | 1F42 (Malaria) |
| ICHI | Procedures | http://www.ichi.org/ | 18629005 (Vaccine admin) |
| NPC | Rwanda National Pharmacy Code | http://npc.rw | 227493005 (Penicillin) |
| DICOM | Imaging modalities | https://dicom.nema.org/ | XA (X-Ray Angiography) |

### Encounter Class Codes
| Code | Display | Description |
|---|---|---|
| AMB | Ambulatory | Outpatient visit |
| EMER | Emergency | Emergency visit |
| IMP | Inpatient | Hospital admission |
| HH | Home Health | Home care visit |

### Encounter Type Codes
| Code | Description |
|---|---|
| VISIT_ENCOUNTER | Initial visit/registration |
| CONSULTATION_ENCOUNTER | Clinical consultation |
| TRANSFER_ENCOUNTER | Patient transfer |

### Observation Category Codes
| Code | Usage |
|---|---|
| vital-signs | Vital signs measurements |
| laboratory | Lab test results |
| survey | Questionnaires, chief complaints |
| exam | Physical examination findings |
| social-history | Social history observations |

### Medication Status Codes
| Resource | Status Values |
|---|---|
| MedicationRequest | active, on-hold, cancelled, completed, entered-in-error, stopped, draft, unknown |
| MedicationDispense | preparation, in-progress, cancelled, on-hold, completed, entered-in-error, stopped, declined, unknown |
| MedicationAdministration | in-progress, not-done, on-hold, completed, entered-in-error, stopped, unknown |

---

## Integration Patterns

### Pattern 1: Complete Patient Registration Flow
```javascript
// Step 1: Check if patient exists in Client Registry
GET http://197.243.24.138:5001/cr/Patient?identifier=251119-0001-4106

// Step 2: If not found, get demographics from NIDA
POST http://197.243.24.138:5001/api/v1/citizens/getCitizen
{
  "fosaid": "0001",
  "documentType": "NID",
  "documentNumber": "1192880005226000"
}

// Step 3: Create patient in Client Registry
POST http://197.243.24.138:5001/cr/Patient
{ "resourceType": "Patient", "id": "251119-0001-4106", ... }

// Step 4: Create Visit Encounter in SHR
POST http://10.10.69.42:9096/shr/Encounter
{ "resourceType": "Encounter", "type": [{"coding": [{"display": "VISIT_ENCOUNTER"}]}], ... }
```

### Pattern 2: E-Prescription with Multiple Medications
```javascript
const prescriptionCode = "PR-2025-11-20-001";

// All three share the same groupIdentifier
// Medication 1
POST /MedicationRequest { "groupIdentifier": { "value": prescriptionCode }, "medicationCodeableConcept": { "coding": [{"code": "372756006", "display": "Amoxicillin"}] } }

// Medication 2
POST /MedicationRequest { "groupIdentifier": { "value": prescriptionCode }, "medicationCodeableConcept": { "coding": [{"code": "387517004", "display": "Paracetamol"}] } }

// Medication 3
POST /MedicationRequest { "groupIdentifier": { "value": prescriptionCode }, "medicationCodeableConcept": { "coding": [{"code": "318341008", "display": "Ibuprofen"}] } }
```

### Pattern 3: Lab Order → Results Flow
```javascript
// Step 1: Doctor orders lab test
POST /ServiceRequest {
  "status": "active", "intent": "order",
  "category": {"coding": {"code": "108252007"}},
  "code": {"coding": [{"code": "15220000", "display": "Full Blood Count"}]},
  "subject": {"reference": "Patient/251119-0001-4106"},
  "encounter": {"reference": "Encounter/visit-id"}
}

// Step 2: Lab technician enters results
POST /Observation {
  "status": "final",
  "category": [{"coding": [{"code": "laboratory"}]}],
  "code": {"coding": [{"system": "http://loinc.org", "code": "33747-0"}]},
  "subject": {"reference": "Patient/251119-0001-4106"},
  "encounter": {"reference": "Encounter/visit-id"},
  "valueQuantity": {"value": 160, "unit": "mmHg"}
}
```

### Pattern 4: Complete Clinical Visit
```javascript
// 1. Create Visit Encounter
POST /Encounter (VISIT_ENCOUNTER)

// 2. Record Vital Signs
POST /Observation (vital-signs category) // Blood Pressure, Temperature, Heart Rate

// 3. Create Consultation Encounter (child of Visit)
POST /Encounter (CONSULTATION_ENCOUNTER with partOf)

// 4. Record Chief Complaints
POST /Observation (survey category)

// 5. Order Investigations
POST /ServiceRequest (Lab order)
POST /ServiceRequest (Imaging order)

// 6. Enter Diagnosis
POST /Condition

// 7. Prescribe Medications
POST /MedicationRequest (with groupIdentifier)

// 8. Record Procedures
POST /Procedure

// 9. Update Visit Encounter
PUT /Encounter/{visit-id}
{
  "status": "finished",
  "period": {
    "start": "2025-11-19T13:35:35+02:00",
    "end": "2025-11-19T15:45:00+02:00"
  }
}
```

---

## Error Handling

### HTTP Status Codes
| Code | Meaning | Common Causes |
|---|---|---|
| 200 | OK | Successful GET request |
| 201 | Created | Successful POST (resource created) |
| 204 | No Content | Successful DELETE |
| 400 | Bad Request | Invalid JSON, validation failure |
| 401 | Unauthorized | Missing/invalid authentication |
| 404 | Not Found | Resource doesn't exist |
| 409 | Conflict | Duplicate resource |
| 422 | Unprocessable Entity | Business logic validation failure |
| 500 | Internal Server Error | Server-side error |

### Error Response Format
```json
{
  "resourceType": "OperationOutcome",
  "issue": [{
    "severity": "error",
    "code": "invalid",
    "diagnostics": "Patient reference is required",
    "expression": ["subject"]
  }]
}
```

### Common Errors & Solutions

| Error | Cause | Solution |
|---|---|---|
| "Invalid UPID format" | UPID doesn't match `YYMMDD-FOSAID-RAND4` | Use UPID from Client Registry/UPID Generator |
| "Reference could not be resolved" | Referenced resource doesn't exist | Ensure Patient/Encounter/Practitioner/Location exists first |
| "Birth date cannot be future dated" | birthDate is after current date | Use correct historical date |
| "Encounter reference is required" | Observation missing encounter reference | Add encounter reference to all observations |
| "Cannot create encounter for deceased patient" | Attempting to create encounter after patient's death | Check patient deceased status before creating encounters |
| "Value cannot be N/A" | Observation value set to "N/A" | Provide actual value or don't create the observation |

---

## Best Practices

### 1. Resource Ordering
Always create resources in this order:
1. Patient (if not exists)
2. Consent
3. Visit Encounter
4. Vital Signs Observations
5. Consultation Encounter (with `partOf` to Visit)
6. Consultation Observations
7. Service Requests (Lab/Imaging orders)
8. Conditions (Diagnoses)
9. Procedures
10. MedicationRequests (grouped by prescription)
11. Lab Results Observations
12. ImagingStudies
13. MedicationDispense
14. MedicationAdministration
15. Transfer Encounter (if needed)

### 2. UUID Generation
```javascript
// JavaScript
const uuid = crypto.randomUUID();

// Python
import uuid
resource_id = str(uuid.uuid4())

// Java
import java.util.UUID;
String uuid = UUID.randomUUID().toString();
```

### 3. Date/Time Formatting
Always use ISO 8601 format:
```
YYYY-MM-DD               # date only
YYYY-MM-DDTHH:mm:ss+00:00  # date-time with timezone

# Examples:
2025-11-18
2025-11-18T10:18:07+02:00
```

### 4. Reference Management
```json
{
  "reference": "ResourceType/resource-id",
  "type": "ResourceType",
  "display": "Human readable name"
}
```

### 5. Search Optimization
```
# Good - specific search
GET /Patient?identifier=251119-0001-4106

# Bad - broad search
GET /Patient?_content=MUGISHA

# Good - with pagination
GET /Encounter?patient=251119-0001-4106&_count=20&page=1

# Good - date range
GET /Observation?date=ge2025-01-01&date=le2025-12-31
```

### Debug Checklist
- [ ] Authentication credentials correct?
- [ ] `Content-Type` header set to `application/fhir+json`?
- [ ] All required fields present?
- [ ] References point to existing resources?
- [ ] Date/time in ISO 8601 format?
- [ ] UPID format valid?
- [ ] No future dates for historical events?
- [ ] Code systems correct (LOINC, SNOMED, ICD-11)?

---

## Appendix

### A. Quick Reference Card
| Task | Endpoint | Method |
|---|---|---|
| Search Patient | `/Patient?identifier={upid}` | GET |
| Create Patient | `/Patient` | POST |
| Create Visit | `/Encounter` | POST |
| Record Vitals | `/Observation` | POST |
| Create Consultation | `/Encounter` (with partOf) | POST |
| Order Lab | `/ServiceRequest` | POST |
| Enter Lab Results | `/Observation` | POST |
| Add Diagnosis | `/Condition` | POST |
| Prescribe Medication | `/MedicationRequest` | POST |
| Record Procedure | `/Procedure` | POST |
| Create Transfer | `/Encounter` (transfer type) | POST |
| Get IPS | `/Bundle/$ips?patient={id}` | GET |

### B. Important URLs
```
SHR Base:                  {BASE_URL}:{PORT}/shr/
Client Registry:           {BASE_URL}:{PORT}/cr/
UPID Generator:            {BASE_URL}:{PORT}/api/v1/citizens/
SHR FHIR Capability:       {BASE_URL}:{PORT}/shr/metadata
```

### C. External References
- FHIR R4 Specification: https://hl7.org/fhir/R4/
- HAPI FHIR Documentation: https://hapifhir.io/
- LOINC: https://loinc.org/
- SNOMED CT: https://www.snomed.org/
- ICD-11: https://icd.who.int/

### D. Glossary
| Term | Definition |
|---|---|
| CR | Client Registry - Patient demographic registry |
| EMR | Electronic Medical Record system |
| FHIR | Fast Healthcare Interoperability Resources |
| FOSAID | Facility ID |
| ICD | International Classification of Diseases |
| ICHI | International Classification of Health Interventions |
| IPS | International Patient Summary |
| LOINC | Logical Observation Identifiers Names and Codes |
| NID | National ID |
| NIDA | National Identification Agency |
| NPC | National Pharmacy Code |
| RHIE | Rwanda Health Information Exchange |
| SHR | Shared Health Record |
| SNOMED CT | Systematized Nomenclature of Medicine Clinical Terms |
| UPID | Unique Patient Identifier |
| UUID | Universally Unique Identifier |

---

## Version History
| Version | Date | Changes |
|---|---|---|
| 1.0.0 | November 2023 | Initial release |
| 2.0.0 | November 2025 | Second release with enhancements |

---

## Contact & Support
- **Email:** digitalization@moh.gov.rw
- **Documentation:** coming soon
- **Issue Tracker:** coming soon
