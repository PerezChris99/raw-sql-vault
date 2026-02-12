# Job Matching Query Engine

> High-performance job-to-candidate matching system using MySQL full-text search with Node.js integration.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      JOB MATCHING QUERY ENGINE                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                 │
│  │   INGEST    │───▶│    INDEX    │───▶│    MATCH    │                 │
│  │             │    │             │    │             │                 │
│  │ • Profiles  │    │ • Full-text │    │ • Boolean   │                 │
│  │ • Jobs      │    │ • NGRAM     │    │   Mode      │                 │
│  │ • Skills    │    │ • Weighted  │    │ • Relevance │                 │
│  │ • Companies │    │             │    │ • Ranking   │                 │
│  └─────────────┘    └─────────────┘    └─────────────┘                 │
│         │                                     │                         │
│         │                                     ▼                         │
│         │                            ┌─────────────┐                   │
│         │                            │     API     │                   │
│         │                            │             │                   │
│         │                            │ • Search    │                   │
│         │                            │ • Recommend │                   │
│         │                            │ • Analytics │                   │
│         │                            └─────────────┘                   │
│         │                                     │                         │
│         ▼                                     ▼                         │
│  ┌───────────────────────────────────────────────────────────────┐     │
│  │                       MySQL 8.0+ Database                      │     │
│  │      Full-Text Search | InnoDB | NGRAM Parser | JSON Support   │     │
│  └───────────────────────────────────────────────────────────────┘     │
│                                     │                                   │
│                                     ▼                                   │
│  ┌───────────────────────────────────────────────────────────────┐     │
│  │                    Node.js Application Layer                   │     │
│  │              mysql2/promise | Connection Pooling               │     │
│  └───────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
job_matching_engine/
├── README.md
├── docs/
│   ├── ARCHITECTURE.md          # System design documentation
│   ├── API_REFERENCE.md         # API endpoints and usage
│   └── DEPLOYMENT.md            # Installation and deployment guide
├── database/
│   ├── migrations/
│   │   ├── V001__schema_setup.sql      # Database and table creation
│   │   ├── V002__fulltext_indexes.sql  # Full-text search indexes
│   │   ├── V003__triggers.sql          # Auto-generation triggers
│   │   └── V004__indexes.sql           # Performance indexes
│   ├── functions/
│   │   ├── matching/                   # Core matching logic
│   │   │   ├── skill_matcher.sql       # Skill-based matching
│   │   │   └── job_ranker.sql          # Relevance ranking
│   │   ├── api/                        # Stored procedures for API
│   │   │   └── sp_search.sql           # Search procedures
│   │   └── procedures/                 # Business procedures
│   │       └── sp_registration.sql     # Registration logic
│   ├── views/
│   │   └── reporting_views.sql         # Analytics views
│   └── seeds/
│       ├── 01_industries.sql           # Industry categories
│       ├── 02_skills.sql               # Skills taxonomy
│       ├── 03_companies.sql            # Sample companies
│       └── 04_sample_data.sql          # Sample jobs/seekers
├── src/
│   ├── config/
│   │   └── database.js                 # MySQL connection config
│   ├── models/
│   │   ├── Job.js                      # Job model
│   │   └── Seeker.js                   # Seeker model
│   ├── services/
│   │   └── MatchingService.js          # Matching business logic
│   └── index.js                        # Application entry
├── scripts/
│   └── deploy.ps1                      # Deployment automation
├── package.json
└── tests/
    └── integration/
        └── test_matching.sql           # SQL integration tests
```

## Quick Start

```powershell
# 1. Create database
mysql -u root -p -e "CREATE DATABASE job_matching CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# 2. Run migrations
.\scripts\deploy.ps1 -Action deploy

# 3. Install Node.js dependencies
npm install

# 4. Test matching
node src/index.js
```

## Key Features

- **Full-Text Boolean Search**: Advanced skill matching with Boolean operators
- **Relevance Ranking**: MATCH...AGAINST scoring for result ordering
- **Bi-directional Matching**: Jobs-to-seekers and seekers-to-jobs
- **Skills Taxonomy**: Hierarchical skill categorization with synonyms
- **Real-time Recommendations**: Instant job/candidate suggestions
- **Experience Weighting**: Factor years of experience into matching
- **Location-based Filtering**: Geographic job search support

## Technology Stack

| Component | Technology |
|-----------|------------|
| Database | MySQL 8.0+ with InnoDB |
| Search | FULLTEXT indexes with NGRAM parser |
| Backend | Node.js with mysql2/promise |
| Matching | Boolean Mode + Natural Language Mode |

## Core Matching Query

```sql
-- Match seekers to job requirements using full-text search
SELECT 
    j.job_id,
    j.title,
    j.company_name,
    s.seeker_id,
    CONCAT(s.first_name, ' ', s.last_name) AS candidate_name,
    MATCH(s.skills_text) AGAINST(j.required_skills IN BOOLEAN MODE) AS relevance_score,
    s.experience_years
FROM jobs j
CROSS JOIN seekers s
WHERE MATCH(s.skills_text) AGAINST(j.required_skills IN BOOLEAN MODE)
  AND s.is_available = TRUE
  AND j.is_active = TRUE
ORDER BY relevance_score DESC
LIMIT 50;
```

## License

MIT License - Educational and production use permitted.
