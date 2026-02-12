# System Architecture

## Overview

The Healthcare Outbreak Detector follows a layered architecture designed for scalability, maintainability, and real-time disease surveillance.

## Data Flow

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           DATA INGESTION LAYER                                │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│   Health Facilities          Mobile Apps            Laboratories              │
│         │                        │                       │                    │
│         ▼                        ▼                       ▼                    │
│   ┌──────────┐            ┌──────────┐            ┌──────────┐               │
│   │ register │            │  report  │            │  record  │               │
│   │ _patient │            │  _case   │            │  _test   │               │
│   └────┬─────┘            └────┬─────┘            └────┬─────┘               │
│        │                       │                       │                      │
├────────┼───────────────────────┼───────────────────────┼──────────────────────┤
│        ▼                       ▼                       ▼                      │
│                        PERSISTENCE LAYER                                      │
│   ┌─────────────────────────────────────────────────────────────────────┐    │
│   │                                                                      │    │
│   │   patients ──▶ cases ──▶ specimens ──▶ lab_tests                    │    │
│   │                  │                                                   │    │
│   │                  ├──▶ case_contacts                                  │    │
│   │                  │                                                   │    │
│   │                  └──▶ daily_case_counts ──▶ weekly_epi_data         │    │
│   │                                                                      │    │
│   └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                          │
├────────────────────────────────────┼──────────────────────────────────────────┤
│                                    ▼                                          │
│                         ANALYTICS ENGINE                                      │
│   ┌─────────────────────────────────────────────────────────────────────┐    │
│   │                                                                      │    │
│   │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐ │    │
│   │   │  Z-Score    │  │  Threshold  │  │  Geographic │  │    R₀     │ │    │
│   │   │  Anomaly    │  │  Detection  │  │  Clustering │  │ Estimation│ │    │
│   │   └─────────────┘  └─────────────┘  └─────────────┘  └───────────┘ │    │
│   │                                                                      │    │
│   └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                          │
├────────────────────────────────────┼──────────────────────────────────────────┤
│                                    ▼                                          │
│                          ALERT SYSTEM                                         │
│   ┌─────────────────────────────────────────────────────────────────────┐    │
│   │                                                                      │    │
│   │   Generation ──▶ Classification ──▶ Escalation ──▶ Notification     │    │
│   │                                                                      │    │
│   │   Levels: WATCH ──▶ ALERT ──▶ OUTBREAK ──▶ EMERGENCY                │    │
│   │                                                                      │    │
│   └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                          │
├────────────────────────────────────┼──────────────────────────────────────────┤
│                                    ▼                                          │
│                           API LAYER                                           │
│   ┌─────────────────────────────────────────────────────────────────────┐    │
│   │                                                                      │    │
│   │   api_get_dashboard()  │  api_list_cases()  │  api_get_map_data()   │    │
│   │   api_get_alerts()     │  api_get_outbreak()│  api_get_disease()    │    │
│   │                                                                      │    │
│   └─────────────────────────────────────────────────────────────────────┘    │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Components

### 1. Data Ingestion Layer

Stored procedures that validate and persist surveillance data:

| Procedure | Purpose |
|-----------|---------|
| `register_patient()` | Create patient record with demographics |
| `report_case()` | Register disease case with symptoms |
| `register_specimen()` | Track lab specimens |
| `record_test_result()` | Record lab results, auto-confirm cases |
| `register_contact()` | Add contact with quarantine period |

### 2. Persistence Layer

Core tables organized by domain:

**Geographic Hierarchy**
```
regions → districts → sub_counties → health_facilities
```

**Disease Registry**
```
disease_categories → diseases → disease_symptoms
```

**Case Management**
```
patients → cases → specimens → lab_tests
              ↓
         case_contacts
```

**Time Series**
```
daily_case_counts → weekly_epi_data
```

### 3. Analytics Engine

Detection algorithms implemented as PostgreSQL functions:

| Algorithm | Function | Description |
|-----------|----------|-------------|
| Z-Score | `detect_zscore_anomalies()` | Statistical deviation from baseline |
| Threshold | `detect_basic_outbreak()` | Exceeds disease-specific threshold |
| Clustering | `detect_geographic_clusters()` | Spatial concentration analysis |
| Reproduction | `estimate_reproduction_number()` | R₀ calculation from serial intervals |
| CUSUM | `cusum_detection()` | Cumulative sum control chart |

### 4. Alert System

Multi-tier alert classification and workflow:

```
                    ┌─────────────┐
                    │   TRIGGER   │
                    │  threshold  │
                    │  anomaly    │
                    │  immediate  │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  CLASSIFY   │
                    │             │
                    │ • WATCH     │◄── Low confidence
                    │ • ALERT     │◄── Confirmed anomaly
                    │ • OUTBREAK  │◄── Sustained transmission
                    │ • EMERGENCY │◄── Critical threat
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │ District │ │ Regional │ │ National │
        │   Team   │ │ Surveil. │ │   MOH    │
        └──────────┘ └──────────┘ └──────────┘
```

### 5. API Layer

JSONB-returning functions optimized for REST API consumption:

```sql
-- Returns paginated JSON with metadata
SELECT surveillance.api_list_cases(
    p_disease_code := 'MAL',
    p_district_code := 'KMP',
    p_page := 1,
    p_page_size := 20
);
```

## Scalability Considerations

### Partitioning Strategy

- `cases` table: Range partitioned by `report_date` (annual)
- `daily_case_counts`: Range partitioned by `count_date` (annual)
- `audit_log`: Range partitioned by `changed_at` (monthly)

### Index Strategy

| Pattern | Index Type | Use Case |
|---------|-----------|----------|
| Equality lookups | B-tree | Primary keys, foreign keys |
| Full-text search | GIN | Patient names, symptoms |
| Time-series | BRIN | Date columns on large tables |
| Covering | Composite | Dashboard queries |
| Partial | Conditional | Active-only queries |

### Materialized Views

Pre-computed aggregations for dashboard performance:

- `mv_national_dashboard`: National statistics (refresh: hourly)
- `mv_disease_summary`: Disease-level metrics (refresh: hourly)
- `mv_district_matrix`: District surveillance matrix (refresh: daily)

## Security Model

```
┌─────────────────────────────────────────────────────┐
│                   ROLE HIERARCHY                     │
├─────────────────────────────────────────────────────┤
│                                                      │
│   surveillance_admin                                 │
│        │                                             │
│        ├── surveillance_analyst (read + analytics)  │
│        │                                             │
│        ├── surveillance_operator (CRUD operations)  │
│        │                                             │
│        └── surveillance_readonly (read only)        │
│                                                      │
└─────────────────────────────────────────────────────┘
```

### Row-Level Security (RLS)

District-based data isolation:
```sql
CREATE POLICY district_isolation ON cases
    USING (district_id = current_setting('app.current_district')::INTEGER);
```

### Audit Trail

All changes logged to `audit_log` table via triggers:
- Table name, operation type
- Old/new values as JSONB
- User, timestamp, client IP
