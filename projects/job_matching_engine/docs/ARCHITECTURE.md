# Job Matching Engine - Architecture

## System Overview

The Job Matching Query Engine is a high-performance recruitment matching system that leverages MySQL's full-text search capabilities to efficiently match job seekers with job openings based on skills, experience, and preferences.

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                           │
│                  REST API / GraphQL / WebSocket                     │
├─────────────────────────────────────────────────────────────────────┤
│                        APPLICATION LAYER                            │
│                                                                     │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐               │
│   │  Matching   │  │   Search    │  │  Analytics  │               │
│   │   Service   │  │   Service   │  │   Service   │               │
│   └─────────────┘  └─────────────┘  └─────────────┘               │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                          DATA LAYER                                 │
│                                                                     │
│   ┌─────────────────────────────────────────────────────────────┐  │
│   │                    MySQL 8.0+ InnoDB                         │  │
│   │                                                              │  │
│   │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │  │
│   │  │ seekers  │  │   jobs   │  │  skills  │  │companies │   │  │
│   │  │          │  │          │  │          │  │          │   │  │
│   │  │ FULLTEXT │  │ FULLTEXT │  │  B-TREE  │  │  B-TREE  │   │  │
│   │  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │  │
│   └─────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## Data Model

### Entity Relationship Diagram

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│    INDUSTRIES   │       │    COMPANIES    │       │   LOCATIONS     │
├─────────────────┤       ├─────────────────┤       ├─────────────────┤
│ industry_id PK  │◄──────│ industry_id FK  │       │ location_id PK  │
│ industry_name   │       │ company_id PK   │       │ city            │
│ description     │       │ company_name    │       │ country         │
└─────────────────┘       │ description     │       │ remote_friendly │
                          └────────┬────────┘       └────────┬────────┘
                                   │                         │
                                   ▼                         │
                          ┌─────────────────┐               │
                          │      JOBS       │               │
                          ├─────────────────┤               │
                          │ job_id PK       │◄──────────────┘
                          │ company_id FK   │
                          │ title           │
                          │ description     │
                          │ required_skills │ ◄── FULLTEXT
                          │ preferred_skills│ ◄── FULLTEXT
                          │ experience_min  │
                          │ salary_range    │
                          │ job_type        │
                          │ is_active       │
                          └────────┬────────┘
                                   │
                                   │ MATCH
                                   ▼
                          ┌─────────────────┐
                          │     SEEKERS     │
                          ├─────────────────┤
                          │ seeker_id PK    │
                          │ first_name      │
                          │ last_name       │
                          │ email           │
                          │ skills_text     │ ◄── FULLTEXT
                          │ experience_years│
                          │ desired_salary  │
                          │ is_available    │
                          └────────┬────────┘
                                   │
                                   ▼
                          ┌─────────────────┐
                          │  APPLICATIONS   │
                          ├─────────────────┤
                          │ application_id  │
                          │ job_id FK       │
                          │ seeker_id FK    │
                          │ match_score     │
                          │ status          │
                          │ applied_at      │
                          └─────────────────┘
```

## Full-Text Search Strategy

### Index Types

1. **Natural Language Mode**
   - Default mode for general searches
   - Returns relevance scores automatically
   - Good for user-facing searches

2. **Boolean Mode**
   - Supports operators: `+`, `-`, `*`, `""`
   - Required for skill matching
   - Allows mandatory/excluded terms

3. **Query Expansion**
   - Finds related terms automatically
   - Useful for skill synonym matching

### Matching Algorithm

```sql
-- Primary matching formula
MATCH(skills_text) AGAINST('python +django react' IN BOOLEAN MODE)

-- Scoring breakdown:
-- 1. Base relevance from MATCH...AGAINST
-- 2. Experience weight factor
-- 3. Location preference boost
-- 4. Salary range fit
-- 5. Recency bonus

Final_Score = (FT_Score * 0.5) + 
              (Experience_Match * 0.2) + 
              (Location_Match * 0.15) + 
              (Salary_Match * 0.1) + 
              (Recency * 0.05)
```

## Query Patterns

### 1. Jobs to Candidates (Recruiter View)

```sql
SELECT 
    s.seeker_id,
    s.full_name,
    s.skills_text,
    MATCH(s.skills_text) AGAINST(? IN BOOLEAN MODE) AS score
FROM seekers s
WHERE MATCH(s.skills_text) AGAINST(? IN BOOLEAN MODE)
  AND s.experience_years >= ?
  AND s.is_available = TRUE
ORDER BY score DESC
LIMIT 50;
```

### 2. Candidates to Jobs (Seeker View)

```sql
SELECT 
    j.job_id,
    j.title,
    j.company_name,
    MATCH(j.required_skills, j.preferred_skills) 
        AGAINST(? IN NATURAL LANGUAGE MODE) AS relevance
FROM jobs j
WHERE MATCH(j.required_skills, j.preferred_skills) 
        AGAINST(? IN NATURAL LANGUAGE MODE)
  AND j.is_active = TRUE
ORDER BY relevance DESC
LIMIT 20;
```

## Performance Considerations

### Indexing Strategy

| Table | Index Type | Columns | Purpose |
|-------|-----------|---------|---------|
| seekers | FULLTEXT | skills_text | Skill matching |
| seekers | B-TREE | experience_years | Range filtering |
| seekers | B-TREE | is_available | Status filtering |
| jobs | FULLTEXT | required_skills, preferred_skills | Skill matching |
| jobs | B-TREE | is_active, created_at | Active job filtering |
| jobs | B-TREE | company_id | Company lookups |

### Query Optimization

1. **Minimum Word Length**: Set `ft_min_word_len=2` for skill abbreviations
2. **Stopwords**: Custom stopword list excluding technical terms
3. **Connection Pooling**: Reuse connections for batch matching
4. **Result Caching**: Cache frequent search results

## Scalability

### Horizontal Scaling

```
                    ┌─────────────┐
                    │ Load Balancer│
                    └──────┬──────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
    ┌─────┴─────┐    ┌─────┴─────┐    ┌─────┴─────┐
    │  Node.js  │    │  Node.js  │    │  Node.js  │
    │  Server 1 │    │  Server 2 │    │  Server 3 │
    └─────┬─────┘    └─────┬─────┘    └─────┬─────┘
          │                │                │
          └────────────────┼────────────────┘
                           │
                    ┌──────┴──────┐
                    │MySQL Primary│
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
        ┌─────┴─────┐┌─────┴─────┐┌─────┴─────┐
        │  Replica  ││  Replica  ││  Replica  │
        │     1     ││     2     ││     3     │
        └───────────┘└───────────┘└───────────┘
```

### Read/Write Splitting

- **Writes**: Primary server only
- **Reads**: Distributed across replicas
- **Matching Queries**: Read replicas (heaviest load)

## Security Model

1. **Data Encryption**: TLS for transit, AES for PII at rest
2. **Access Control**: Role-based permissions (recruiter, seeker, admin)
3. **Rate Limiting**: Prevent search abuse
4. **SQL Injection Prevention**: Parameterized queries only
