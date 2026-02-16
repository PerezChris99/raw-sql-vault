# 🛡️ Production Infrastructure

Shared production-ready configurations for all Raw SQL Vault projects.

## Contents

| Directory | Purpose |
|-----------|---------|
| `security/` | RBAC, RLS, audit logging, attack prevention |
| `performance/` | Connection pooling, indexing strategies, caching |
| `connectors/` | Backend integration templates (Node.js, Python, Go) |
| `monitoring/` | Health checks, metrics, alerting |
| `deployment/` | Docker, Kubernetes, CI/CD configs |

## Quick Start

### 1. Apply Security Layer
```sql
-- Run on each project database
\i security/00_audit_infrastructure.sql
\i security/01_rbac_roles.sql
\i security/02_row_level_security.sql
\i security/03_input_sanitization.sql
\i security/04_rate_limiting.sql
\i security/05_encryption_at_rest.sql
```

### 2. Configure Connection Pooling
```bash
# PgBouncer recommended for production
cp performance/pgbouncer.ini /etc/pgbouncer/
```

### 3. Connect Your Backend
```javascript
// Node.js example
const connector = require('./_infrastructure/connectors/nodejs/pg-connector');
const db = connector.createPool('refugee_aid');
```

## Security Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     APPLICATION LAYER                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │   Node.js   │  │   Python    │  │     Go      │              │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘              │
└─────────┼────────────────┼────────────────┼─────────────────────┘
          │                │                │
          ▼                ▼                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CONNECTION POOL (PgBouncer)                   │
│  • Connection limiting (max 100/pool)                           │
│  • Statement timeout (30s default)                              │
│  • Idle connection cleanup                                       │
└─────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SECURITY GATEWAY                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │Rate Limiting│  │SQL Injection│  │ Audit Log   │              │
│  │  (leaky     │  │ Detection   │  │ (all DDL/   │              │
│  │   bucket)   │  │ & Blocking  │  │  DML ops)   │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
└─────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ROW-LEVEL SECURITY                            │
│  • Tenant isolation (multi-tenant apps)                         │
│  • Role-based data access                                        │
│  • Column-level encryption for PII                              │
└─────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    PostgreSQL DATABASE                           │
│  • TLS 1.3 connections                                          │
│  • Encrypted at rest (pgcrypto)                                 │
│  • Automated backups                                             │
└─────────────────────────────────────────────────────────────────┘
```

## Production Checklist

- [ ] Apply all security migrations
- [ ] Configure connection pooling
- [ ] Enable TLS for database connections
- [ ] Set up audit log rotation
- [ ] Configure rate limiting thresholds
- [ ] Enable automated backups
- [ ] Set up monitoring dashboards
- [ ] Configure alerting rules
- [ ] Test disaster recovery procedures
- [ ] Document incident response plan
