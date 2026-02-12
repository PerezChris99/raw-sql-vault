# Healthcare Outbreak Detector

A production-grade PostgreSQL disease surveillance system for real-time outbreak detection, case management, and epidemic response coordination.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    HEALTHCARE OUTBREAK DETECTOR                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────┐  │
│  │   INGEST    │───▶│   DETECT    │───▶│        RESPOND          │  │
│  │             │    │             │    │                         │  │
│  │ • Patients  │    │ • Z-Score   │    │ • Alert Generation      │  │
│  │ • Cases     │    │ • Threshold │    │ • Escalation Workflows  │  │
│  │ • Lab Tests │    │ • Clustering│    │ • Contact Tracing       │  │
│  │ • Contacts  │    │ • R₀ Est.   │    │ • Outbreak Declaration  │  │
│  └─────────────┘    └─────────────┘    └─────────────────────────┘  │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                      API LAYER (JSONB)                        │   │
│  │  • api_get_dashboard()  • api_list_cases()  • api_get_map()  │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
healthcare_outbreak_detector/
├── README.md                          # This file
├── docs/
│   ├── ARCHITECTURE.md                # System design & data flow
│   ├── API_REFERENCE.md               # JSONB API documentation
│   ├── DEPLOYMENT.md                  # Installation & deployment
│   └── ERD.md                         # Entity relationship diagram
├── database/
│   ├── migrations/                    # Versioned migrations
│   │   ├── V001__extensions.sql
│   │   ├── V002__schema_enums.sql
│   │   ├── V003__schema_tables.sql
│   │   ├── V004__schema_triggers.sql
│   │   └── V005__indexes.sql
│   ├── schema/
│   │   ├── enums/                     # Custom PostgreSQL types
│   │   ├── tables/                    # Table definitions
│   │   └── triggers/                  # Trigger functions
│   ├── functions/
│   │   ├── analytics/                 # Outbreak detection algorithms
│   │   ├── api/                       # JSONB API endpoints
│   │   └── procedures/                # Data entry procedures
│   ├── views/
│   │   ├── standard/                  # Regular views
│   │   └── materialized/              # Dashboard materialized views
│   └── seeds/                         # Reference data
├── alerts/
│   ├── generation/                    # Alert creation logic
│   ├── escalation/                    # Escalation workflows
│   └── notifications/                 # Notification system
├── maintenance/
│   ├── partitioning/                  # Table partitioning
│   ├── archival/                      # Data archival
│   └── monitoring/                    # Health checks & stats
├── scripts/
│   ├── deploy.ps1                     # Full deployment
│   ├── rollback.ps1                   # Rollback support
│   └── migrate.ps1                    # Run migrations
└── tests/
    ├── unit/                          # Unit tests
    └── integration/                   # End-to-end tests
```

## Quick Start

```powershell
# 1. Deploy the database
.\scripts\deploy.ps1 -Database "surveillance_db" -CreateDb

# 2. Run migrations
.\scripts\migrate.ps1 -Database "surveillance_db"

# 3. Verify deployment
psql -d surveillance_db -c "SELECT surveillance.health_check();"
```

## Key Features

| Feature | Description |
|---------|-------------|
| **Real-time Detection** | Z-score anomaly detection, threshold monitoring, geographic clustering |
| **Case Management** | Patient registration, case tracking, lab integration |
| **Contact Tracing** | Exposure tracking, quarantine management, follow-up scheduling |
| **Alert System** | Multi-level alerts, auto-escalation, notification workflows |
| **API Ready** | JSONB functions for REST API integration |
| **Production Grade** | Partitioning, archival, monitoring, health checks |

## Technology

- **Database**: PostgreSQL 14+
- **Extensions**: uuid-ossp, pgcrypto, pg_trgm, btree_gist
- **Schema**: `surveillance`

## License

MIT
