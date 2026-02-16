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
