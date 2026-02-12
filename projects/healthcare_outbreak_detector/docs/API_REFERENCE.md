# API Reference

All API functions return JSONB for easy REST API integration. Connect via any PostgreSQL client or use with frameworks like FastAPI, Express, or Django.

## Authentication Context

Set user context before API calls:
```sql
SET app.current_user = 'john.doe@health.gov';
SET app.current_district = '101';  -- For RLS
```

---

## Case APIs

### `api_get_case(p_case_id UUID)`

Get complete case details including patient, disease, location, and lab results.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `p_case_id` | UUID | Yes | Case unique identifier |

**Response:**
```json
{
  "case_id": "550e8400-e29b-41d4-a716-446655440000",
  "case_number": "CS-2024-000123",
  "status": "confirmed",
  "severity": "moderate",
  "hospitalized": true,
  "onset_date": "2024-01-15",
  "report_date": "2024-01-17",
  "symptoms": ["fever", "headache", "vomiting"],
  "verified": true,
  "patient": {
    "patient_id": "...",
    "patient_code": "PT-2024-000456",
    "name": "John Mukasa",
    "age": 34,
    "gender": "male"
  },
  "disease": {
    "disease_id": 5,
    "code": "MAL",
    "name": "Malaria",
    "icd10": "B50"
  },
  "location": {
    "district": "Kampala",
    "district_code": "KMP",
    "region": "Central"
  },
  "lab_results": [
    {
      "test_id": "...",
      "test_name": "Malaria RDT",
      "result": "positive",
      "result_date": "2024-01-17"
    }
  ],
  "contacts_count": 3,
  "created_at": "2024-01-17T10:30:00Z",
  "updated_at": "2024-01-18T14:22:00Z"
}
```

---

### `api_list_cases(...)`

List cases with filtering and pagination.

**Parameters:**
| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `p_disease_code` | VARCHAR | No | NULL | Filter by disease |
| `p_district_code` | VARCHAR | No | NULL | Filter by district |
| `p_status` | VARCHAR | No | NULL | Filter by case status |
| `p_from_date` | DATE | No | NULL | Start date filter |
| `p_to_date` | DATE | No | NULL | End date filter |
| `p_page` | INTEGER | No | 1 | Page number |
| `p_page_size` | INTEGER | No | 20 | Items per page |

**Response:**
```json
{
  "data": [
    {
      "case_id": "...",
      "case_number": "CS-2024-000123",
      "status": "confirmed",
      "severity": "moderate",
      "report_date": "2024-01-17",
      "disease_code": "MAL",
      "disease_name": "Malaria",
      "district": "Kampala",
      "patient_name": "John M.",
      "age": 34,
      "gender": "male"
    }
  ],
  "pagination": {
    "page": 1,
    "page_size": 20,
    "total_items": 156,
    "total_pages": 8
  }
}
```

---

## Dashboard APIs

### `api_get_dashboard()`

Get national surveillance dashboard data.

**Response:**
```json
{
  "summary": {
    "cases_today": 45,
    "cases_7d": 312,
    "cases_30d": 1247,
    "deaths_30d": 23,
    "active_outbreaks": 3,
    "active_alerts": 7,
    "districts_reporting": 42
  },
  "top_diseases": [
    {"disease_code": "MAL", "disease_name": "Malaria", "cases": 523, "deaths": 12},
    {"disease_code": "TYP", "disease_name": "Typhoid", "cases": 189, "deaths": 3}
  ],
  "alerts": [
    {
      "alert_code": "ALERT-CHO-KMP-20240117",
      "title": "Cholera threshold alert in Kampala",
      "level": "outbreak",
      "disease": "Cholera",
      "district": "Kampala",
      "detection_date": "2024-01-15"
    }
  ],
  "trend_7d": [
    {"date": "2024-01-11", "cases": 42},
    {"date": "2024-01-12", "cases": 38}
  ],
  "timestamp": "2024-01-17T10:30:00Z"
}
```

---

### `api_get_district_dashboard(p_district_code VARCHAR)`

Get district-level surveillance dashboard.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `p_district_code` | VARCHAR | Yes | District code |

**Response:**
```json
{
  "district": {
    "district_id": 101,
    "code": "KMP",
    "name": "Kampala",
    "region": "Central",
    "population": 1680000
  },
  "summary": {
    "cases_7d": 89,
    "cases_30d": 312,
    "deaths_30d": 5,
    "incidence_rate": 18.57
  },
  "diseases": [
    {"disease_code": "MAL", "disease_name": "Malaria", "cases_30d": 145}
  ],
  "facilities": [
    {"facility_code": "KMP-001", "facility_name": "Mulago Hospital", "facility_type": "national_referral", "cases_reported": 67}
  ],
  "timestamp": "2024-01-17T10:30:00Z"
}
```

---

## Outbreak APIs

### `api_get_active_outbreaks()`

List all active outbreaks with details.

**Response:**
```json
{
  "outbreaks": [
    {
      "outbreak_id": "...",
      "outbreak_code": "OBK-CHO-KMP-20240110",
      "disease": "Cholera",
      "disease_code": "CHO",
      "district": "Kampala",
      "region": "Central",
      "declaration_date": "2024-01-10",
      "duration_days": 7,
      "total_cases": 45,
      "confirmed_cases": 38,
      "deaths": 2,
      "cfr": 5.3,
      "alert_level": "outbreak",
      "response_status": "active"
    }
  ],
  "count": 3,
  "timestamp": "2024-01-17T10:30:00Z"
}
```

---

### `api_get_outbreak(p_outbreak_id UUID)`

Get detailed outbreak information with epidemic curve.

**Response:**
```json
{
  "outbreak": {
    "outbreak_id": "...",
    "outbreak_code": "OBK-CHO-KMP-20240110",
    "disease_name": "Cholera",
    "district": "Kampala",
    "region": "Central",
    "declaration_date": "2024-01-10",
    "first_case_date": "2024-01-05",
    "duration_days": 12,
    "total_cases": 45,
    "confirmed_cases": 38,
    "deaths": 2,
    "cfr": 5.3,
    "situation_summary": "Outbreak centered in Nakawa division...",
    "containment_measures": ["Water chlorination", "Health education"]
  },
  "epidemic_curve": [
    {"date": "2024-01-05", "cases": 3, "cumulative": 3},
    {"date": "2024-01-06", "cases": 5, "cumulative": 8},
    {"date": "2024-01-07", "cases": 8, "cumulative": 16}
  ],
  "by_age_group": {
    "under_5": 12,
    "5_to_14": 8,
    "15_to_49": 20,
    "50_plus": 5
  }
}
```

---

## Alert APIs

### `api_get_alerts(p_level VARCHAR, p_district_code VARCHAR)`

Get active alerts with optional filtering.

**Parameters:**
| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `p_level` | VARCHAR | No | NULL | Filter: `emergency`, `outbreak`, `alert`, `watch` |
| `p_district_code` | VARCHAR | No | NULL | Filter by district |

**Response:**
```json
{
  "alerts": [
    {
      "alert_id": "...",
      "alert_code": "ALERT-CHO-KMP-20240117",
      "level": "outbreak",
      "type": "threshold_breach",
      "title": "Cholera threshold alert in Kampala",
      "description": "Detected 15 cases in last 7 days (threshold: 10, z-score: 3.2)",
      "disease": "Cholera",
      "district": "Kampala",
      "detection_date": "2024-01-15",
      "current_value": 15,
      "threshold_value": 10,
      "days_active": 2
    }
  ],
  "by_level": {
    "emergency": 0,
    "outbreak": 2,
    "alert": 3,
    "watch": 2
  },
  "count": 7,
  "timestamp": "2024-01-17T10:30:00Z"
}
```

---

## Geographic APIs

### `api_get_map_data(p_disease_code VARCHAR, p_days INTEGER)`

Get geographic data for mapping visualizations.

**Parameters:**
| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `p_disease_code` | VARCHAR | No | NULL | Filter by disease |
| `p_days` | INTEGER | No | 30 | Time window |

**Response:**
```json
{
  "districts": [
    {
      "district_code": "KMP",
      "district_name": "Kampala",
      "lat": 0.3476,
      "lng": 32.5825,
      "cases": 145,
      "deaths": 3,
      "has_outbreak": true,
      "risk_level": "high"
    },
    {
      "district_code": "WKS",
      "district_name": "Wakiso",
      "lat": 0.4054,
      "lng": 32.4594,
      "cases": 67,
      "deaths": 1,
      "has_outbreak": false,
      "risk_level": "medium"
    }
  ],
  "timestamp": "2024-01-17T10:30:00Z"
}
```

---

## Disease APIs

### `api_get_disease_summary(p_disease_code VARCHAR)`

Get disease statistics and distribution.

**Without disease_code** - Returns all diseases summary:
```json
{
  "diseases": [
    {
      "disease_code": "MAL",
      "disease_name": "Malaria",
      "cases_7d": 89,
      "cases_30d": 312,
      "trend": "decreasing"
    }
  ]
}
```

**With disease_code** - Returns detailed disease info:
```json
{
  "disease": {
    "disease_id": 5,
    "code": "MAL",
    "name": "Malaria",
    "icd10": "B50",
    "category": "Vector-borne",
    "transmission_mode": "vector",
    "outbreak_threshold": 50,
    "notifiable": false
  },
  "statistics": {
    "cases_7d": 89,
    "cases_30d": 312,
    "deaths_30d": 12,
    "confirmed_30d": 287,
    "districts_affected": 28
  },
  "by_district": [
    {"district": "Kampala", "cases": 67},
    {"district": "Wakiso", "cases": 45}
  ]
}
```

---

## Usage with REST APIs

### FastAPI Example

```python
from fastapi import FastAPI
import asyncpg

app = FastAPI()

@app.get("/api/v1/dashboard")
async def get_dashboard():
    conn = await asyncpg.connect(DATABASE_URL)
    result = await conn.fetchval(
        "SELECT surveillance.api_get_dashboard()"
    )
    await conn.close()
    return result

@app.get("/api/v1/cases")
async def list_cases(
    disease: str = None,
    district: str = None,
    page: int = 1,
    page_size: int = 20
):
    conn = await asyncpg.connect(DATABASE_URL)
    result = await conn.fetchval(
        """
        SELECT surveillance.api_list_cases(
            p_disease_code := $1,
            p_district_code := $2,
            p_page := $3,
            p_page_size := $4
        )
        """,
        disease, district, page, page_size
    )
    await conn.close()
    return result
```

### Express.js Example

```javascript
const { Pool } = require('pg');
const pool = new Pool({ connectionString: DATABASE_URL });

app.get('/api/v1/alerts', async (req, res) => {
  const { level, district } = req.query;
  const result = await pool.query(
    `SELECT surveillance.api_get_alerts($1, $2)`,
    [level || null, district || null]
  );
  res.json(result.rows[0].api_get_alerts);
});
```

---

## Error Handling

API functions return error objects when appropriate:
```json
{
  "error": "Case not found"
}
```

```json
{
  "error": "District not found"
}
```

Always check for the `error` key in responses before processing data.
