# Education Dropout Forecaster - Architecture

## System Overview

The Education Dropout Forecaster analyzes student dropout patterns using PostgreSQL window functions, providing district-level rankings, trend analysis, and early warning indicators for at-risk students.

## Data Model

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            ENTITY RELATIONSHIP DIAGRAM                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐         ┌──────────────┐         ┌──────────────┐        │
│  │   states     │────────▶│  districts   │────────▶│   schools    │        │
│  │──────────────│   1:N   │──────────────│   1:N   │──────────────│        │
│  │ state_id     │         │ district_id  │         │ school_id    │        │
│  │ name         │         │ name         │         │ name         │        │
│  │ code         │         │ state_id     │         │ district_id  │        │
│  └──────────────┘         │ superintendent│        │ enrollment   │        │
│                           └──────────────┘         │ type         │        │
│                                                    └──────────────┘        │
│                                                           │                 │
│                                                           │ 1:N             │
│                                                           ▼                 │
│  ┌──────────────┐         ┌──────────────┐         ┌──────────────┐        │
│  │dropout_reasons│◀───────│  students    │────────▶│    grades    │        │
│  │──────────────│   N:1   │──────────────│   1:N   │──────────────│        │
│  │ reason_id    │         │ student_id   │         │ grade_id     │        │
│  │ code         │         │ school_id    │         │ student_id   │        │
│  │ description  │         │ status       │         │ subject      │        │
│  │ risk_weight  │         │ dropout_reason│        │ grade_value  │        │
│  └──────────────┘         │ enrolled_date│         │ semester     │        │
│                           │ dropout_date │         └──────────────┘        │
│                           └──────────────┘                                  │
│                                  │                                          │
│                                  │ 1:N                                      │
│                                  ▼                                          │
│                           ┌──────────────┐         ┌──────────────┐        │
│                           │  attendance  │         │risk_factors  │        │
│                           │──────────────│         │──────────────│        │
│                           │ attendance_id│         │ factor_id    │        │
│                           │ student_id   │         │ student_id   │        │
│                           │ date         │         │ factor_type  │        │
│                           │ status       │         │ score        │        │
│                           └──────────────┘         └──────────────┘        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Window Functions Strategy

### Ranking Functions

#### ROW_NUMBER() - Unique Sequential Ranking
```sql
-- Each school gets unique rank within district
ROW_NUMBER() OVER (
    PARTITION BY district_id 
    ORDER BY dropout_count DESC
) AS unique_rank
```
- Always produces 1, 2, 3, 4...
- No duplicates even with ties
- Best for: Sequential ordering, pagination

#### RANK() - Ranking with Gaps
```sql
-- Schools with same dropout count share rank, gaps follow
RANK() OVER (
    PARTITION BY district_id 
    ORDER BY dropout_rate DESC
) AS rank_with_gaps
```
- Ties get same rank (1, 1, 3, 4...)
- Best for: Competition-style ranking

#### DENSE_RANK() - Ranking without Gaps
```sql
-- Schools with same rate share rank, no gaps
DENSE_RANK() OVER (
    ORDER BY dropout_rate DESC
) AS dense_rank
```
- Ties get same rank (1, 1, 2, 3...)
- Best for: Continuous rank numbers

### Analytic Functions

#### LAG/LEAD - Time Series Comparison
```sql
-- Compare current year to previous
SELECT 
    school_id,
    academic_year,
    dropout_count,
    LAG(dropout_count, 1) OVER (
        PARTITION BY school_id 
        ORDER BY academic_year
    ) AS prev_year,
    LEAD(dropout_count, 1) OVER (
        PARTITION BY school_id 
        ORDER BY academic_year
    ) AS next_year
FROM annual_stats;
```

#### Running Totals
```sql
-- Cumulative dropouts through the year
SUM(daily_dropouts) OVER (
    PARTITION BY school_id 
    ORDER BY event_date 
    ROWS UNBOUNDED PRECEDING
) AS cumulative_dropouts
```

#### Moving Averages
```sql
-- 30-day moving average of dropout rate
AVG(dropout_rate) OVER (
    PARTITION BY district_id 
    ORDER BY report_date 
    ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
) AS moving_avg_30d
```

### Distribution Functions

#### NTILE - Quartile/Decile Analysis
```sql
-- Divide schools into risk quartiles
NTILE(4) OVER (ORDER BY risk_score DESC) AS risk_quartile
-- 1 = highest risk (top 25%)
-- 4 = lowest risk (bottom 25%)
```

#### PERCENT_RANK - Percentile Position
```sql
-- Where does this school rank percentile-wise?
PERCENT_RANK() OVER (ORDER BY dropout_rate) AS percentile
-- Returns 0.0 to 1.0
```

## Risk Scoring Algorithm

```sql
-- Composite risk score calculation
WITH risk_components AS (
    SELECT 
        student_id,
        -- Attendance risk (weight: 0.25)
        CASE WHEN attendance_rate < 0.80 THEN 0.25
             WHEN attendance_rate < 0.90 THEN 0.15
             ELSE 0 END AS attendance_risk,
        -- GPA risk (weight: 0.25)
        CASE WHEN gpa < 1.5 THEN 0.25
             WHEN gpa < 2.0 THEN 0.20
             WHEN gpa < 2.5 THEN 0.10
             ELSE 0 END AS gpa_risk,
        -- Disciplinary risk (weight: 0.20)
        LEAST(disciplinary_incidents * 0.05, 0.20) AS discipline_risk,
        -- Prior retention (weight: 0.15)
        CASE WHEN retained_grade THEN 0.15 ELSE 0 END AS retention_risk,
        -- Socioeconomic (weight: 0.15)
        CASE WHEN free_lunch THEN 0.10 ELSE 0 END +
        CASE WHEN single_parent THEN 0.05 ELSE 0 END AS socio_risk
    FROM student_factors
)
SELECT 
    student_id,
    ROUND((attendance_risk + gpa_risk + discipline_risk + 
           retention_risk + socio_risk) * 100, 1) AS risk_score,
    NTILE(10) OVER (ORDER BY 
        attendance_risk + gpa_risk + discipline_risk + 
        retention_risk + socio_risk DESC
    ) AS risk_decile
FROM risk_components;
```

## Django Integration Pattern

### Raw Query Service Layer

```python
# analytics/services.py
from django.db import connection

class DropoutAnalytics:
    """Service class for dropout analysis using raw SQL."""
    
    def get_school_rankings(self, district_id=None, academic_year=None):
        """
        Get schools ranked by dropout rate within each district.
        Uses ROW_NUMBER() window function.
        """
        params = []
        where_clause = "WHERE st.status = 'dropped'"
        
        if district_id:
            where_clause += " AND d.district_id = %s"
            params.append(district_id)
        if academic_year:
            where_clause += " AND st.academic_year = %s"
            params.append(academic_year)
        
        sql = f"""
            SELECT 
                s.school_id,
                s.school_name,
                d.district_name,
                COUNT(*) AS dropout_count,
                ROUND(COUNT(*) * 100.0 / NULLIF(s.enrollment, 0), 2) AS dropout_rate,
                ROW_NUMBER() OVER (
                    PARTITION BY d.district_id 
                    ORDER BY COUNT(*) DESC
                ) AS district_rank,
                RANK() OVER (
                    ORDER BY COUNT(*) DESC
                ) AS overall_rank
            FROM students st
            JOIN schools s ON st.school_id = s.school_id
            JOIN districts d ON s.district_id = d.district_id
            {where_clause}
            GROUP BY s.school_id, s.school_name, d.district_id, 
                     d.district_name, s.enrollment
            ORDER BY d.district_name, district_rank
        """
        
        with connection.cursor() as cursor:
            cursor.execute(sql, params)
            columns = [col[0] for col in cursor.description]
            return [dict(zip(columns, row)) for row in cursor.fetchall()]
```

### Model-Based Raw Queries

```python
# Using Django's raw() method on models
from analytics.models import Student

# Execute raw SQL with model instance mapping
students = Student.objects.raw("""
    SELECT 
        s.*,
        NTILE(10) OVER (ORDER BY risk_score DESC) AS risk_decile
    FROM students s
    JOIN student_risk_scores sr ON s.student_id = sr.student_id
    WHERE s.school_id = %s
""", [school_id])

for student in students:
    print(f"{student.name}: Decile {student.risk_decile}")
```

## Query Patterns

### Pattern 1: Partition Rankings
```sql
-- Rank within groups
SELECT *,
    ROW_NUMBER() OVER (PARTITION BY group_col ORDER BY metric DESC) AS rank
FROM table
```

### Pattern 2: Running Calculations
```sql
-- Cumulative/running totals
SELECT *,
    SUM(value) OVER (ORDER BY date ROWS UNBOUNDED PRECEDING) AS running_total
FROM table
```

### Pattern 3: Comparison Windows
```sql
-- Compare to previous/next
SELECT *,
    value - LAG(value) OVER (ORDER BY period) AS change
FROM table
```

### Pattern 4: Distribution Analysis
```sql
-- Percentile buckets
SELECT *,
    NTILE(100) OVER (ORDER BY metric) AS percentile
FROM table
```

## Performance Considerations

### Index Strategy
```sql
-- Support window function ordering
CREATE INDEX idx_students_school_status ON students(school_id, status);
CREATE INDEX idx_students_district_year ON students(district_id, academic_year);
CREATE INDEX idx_attendance_student_date ON attendance(student_id, date DESC);
```

### Materialized Views for Heavy Analytics
```sql
-- Pre-compute expensive window calculations
CREATE MATERIALIZED VIEW mv_school_rankings AS
SELECT 
    school_id,
    academic_year,
    dropout_count,
    ROW_NUMBER() OVER (PARTITION BY district_id ORDER BY dropout_count DESC) AS rank
FROM annual_dropout_stats;

-- Refresh periodically
REFRESH MATERIALIZED VIEW mv_school_rankings;
```

### Query Optimization Tips

1. **Filter Before Windowing**: Use CTEs to filter data before applying window functions
2. **Limit Partitions**: Smaller partitions = faster window calculations
3. **Index ORDER BY Columns**: Window functions sort data internally
4. **Use Frame Clauses**: Specify `ROWS BETWEEN` to limit window size

## Data Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Student    │     │   Dropout    │     │   Window     │     │   Rankings   │
│   Records    │────▶│   Events     │────▶│   Functions  │────▶│   & Analysis │
│              │     │              │     │              │     │              │
│ - enrollment │     │ - reason     │     │ - ROW_NUMBER │     │ - by school  │
│ - attendance │     │ - date       │     │ - RANK       │     │ - by district│
│ - grades     │     │ - school     │     │ - LAG/LEAD   │     │ - trends     │
│ - risk flags │     │ - year       │     │ - SUM OVER   │     │ - forecasts  │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
```

## Scalability

| Data Volume | Strategy |
|-------------|----------|
| < 100K students | Direct queries with indexes |
| 100K - 1M students | Materialized views, partitioning |
| > 1M students | Table partitioning by year, parallel queries |

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/schools/rankings/` | GET | School rankings by district |
| `/api/schools/{id}/trends/` | GET | Year-over-year trends |
| `/api/students/at-risk/` | GET | At-risk student list |
| `/api/districts/{id}/analysis/` | GET | District-wide analysis |
| `/api/reports/annual/` | GET | Annual dropout report |
