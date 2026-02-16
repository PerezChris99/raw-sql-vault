# Milk Supply Chain Auditor

A traceability system for Uganda's dairy sector using **Recursive CTEs** to trace milk batches from farm to consumer.

## SQL Feature

**Recursive CTEs** (`WITH RECURSIVE`) for traversing batch lineage:

```sql
WITH RECURSIVE chain AS (
    SELECT * FROM batches WHERE batch_id = 'X'
    UNION 
    SELECT b.* FROM batches b 
    JOIN chain c ON b.prev_batch = c.batch_id
) 
SELECT * FROM chain;
```

## Use Case

Uganda's dairy industry needs full traceability for:
- **Food safety** - Trace contamination sources
- **Quality control** - Track temperature/handling issues
- **Export compliance** - EU/regional certification requirements
- **Farmer payments** - Accurate attribution of milk sources

## Features

- Recursive batch tracing from consumer back to farm
- Forward tracing for recall scenarios
- Temperature breach detection throughout chain
- Multi-level processing tracking (collection → cooling → processing → packaging)
- Farmer attribution and quality scoring

## Schema Overview

- `farmers` - Dairy farmers/suppliers
- `collection_centers` - Milk collection points
- `processing_plants` - Dairy processing facilities
- `batches` - Milk batches with parent-child relationships
- `batch_tests` - Quality/safety test results
- `deliveries` - Final product deliveries

## Sample Queries

### Trace Batch Origin (Reverse)
```sql
WITH RECURSIVE origin_trace AS (
    SELECT batch_id, parent_batch_id, stage, farmer_id, 0 AS depth
    FROM batches WHERE batch_id = 'PKG-2024-001'
    UNION ALL
    SELECT b.batch_id, b.parent_batch_id, b.stage, b.farmer_id, ot.depth + 1
    FROM batches b
    JOIN origin_trace ot ON b.batch_id = ot.parent_batch_id
)
SELECT * FROM origin_trace ORDER BY depth;
```

### Forward Trace (Recall)
```sql
WITH RECURSIVE recall_trace AS (
    SELECT batch_id, parent_batch_id, stage
    FROM batches WHERE batch_id = 'FARM-001-2024-01'
    UNION ALL
    SELECT b.batch_id, b.parent_batch_id, b.stage
    FROM batches b
    JOIN recall_trace rt ON b.parent_batch_id = rt.batch_id
)
SELECT * FROM recall_trace;
```

---

## 🔌 Backend Integration

### Environment Variables
```bash
DB_HOST=localhost
DB_PORT=6432
DB_NAME=milk_supply
DB_USER=app_service
DB_PASSWORD=your_secure_password
```

### Node.js Example
```javascript
const { createConnector } = require('../../_infrastructure/connectors/nodejs/pg-connector');
const db = createConnector('milk_supply');

// Trace batch to origin
const traceOrigin = await db.query(
    'SELECT * FROM fn_trace_to_origin($1)',
    [batchId]
);

// Forward trace for recalls
const affectedBatches = await db.query(
    'SELECT * FROM fn_trace_forward($1)',
    [contaminatedBatchId]
);

// Check contamination in chain
const contamination = await db.query(
    'SELECT * FROM fn_check_contamination_chain($1)',
    [batchId]
);
```

### Python Example
```python
from _infrastructure.connectors.python.pg_connector import PostgresConnector
db = PostgresConnector.create('milk_supply')

# Full chain trace
chain = db.query('SELECT * FROM fn_trace_to_origin(%s)', [batch_id])

# Recall scenario
affected = db.query('SELECT * FROM fn_trace_forward(%s)', [contaminated_batch])
```

### Security Setup
```sql
\i ../../_infrastructure/security/00_audit_infrastructure.sql
SELECT audit.enable_auditing('public', 'batches');
SELECT audit.enable_auditing('public', 'batch_tests');
```
