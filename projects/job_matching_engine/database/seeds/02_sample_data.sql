-- ============================================================================
-- Seed Data: Sample Companies, Jobs, and Seekers
-- Purpose: Test data for matching demonstrations
-- ============================================================================

USE job_matching;

-- ============================================================================
-- LOCATIONS
-- ============================================================================

INSERT INTO locations (city, state_province, country, country_code, timezone, is_remote_friendly) VALUES
    ('San Francisco', 'California', 'United States', 'US', 'America/Los_Angeles', TRUE),
    ('New York', 'New York', 'United States', 'US', 'America/New_York', TRUE),
    ('Seattle', 'Washington', 'United States', 'US', 'America/Los_Angeles', TRUE),
    ('Austin', 'Texas', 'United States', 'US', 'America/Chicago', TRUE),
    ('London', 'England', 'United Kingdom', 'GB', 'Europe/London', TRUE),
    ('Berlin', NULL, 'Germany', 'DE', 'Europe/Berlin', TRUE),
    ('Toronto', 'Ontario', 'Canada', 'CA', 'America/Toronto', TRUE),
    ('Singapore', NULL, 'Singapore', 'SG', 'Asia/Singapore', TRUE),
    ('Remote', NULL, 'Worldwide', 'WW', 'UTC', TRUE)
ON DUPLICATE KEY UPDATE is_remote_friendly = VALUES(is_remote_friendly);

-- ============================================================================
-- COMPANIES
-- ============================================================================

INSERT INTO companies (company_name, industry_id, description, company_size, employee_count_range, website, is_verified) VALUES
    ('TechCorp Innovation', 
     (SELECT industry_id FROM industries WHERE industry_code = 'TECH'),
     'Leading software development company specializing in cloud solutions',
     'large', '1000-5000', 'https://techcorp.example.com', TRUE),
    
    ('DataFlow Analytics',
     (SELECT industry_id FROM industries WHERE industry_code = 'AIML'),
     'AI and machine learning solutions for enterprise',
     'medium', '100-500', 'https://dataflow.example.com', TRUE),
    
    ('CloudFirst Systems',
     (SELECT industry_id FROM industries WHERE industry_code = 'SAAS'),
     'Cloud-native SaaS platform provider',
     'medium', '200-1000', 'https://cloudfirst.example.com', TRUE),
    
    ('FinanceHub Tech',
     (SELECT industry_id FROM industries WHERE industry_code = 'FINTECH'),
     'Digital banking and payment solutions',
     'large', '500-2000', 'https://financehub.example.com', TRUE),
    
    ('StartupX',
     (SELECT industry_id FROM industries WHERE industry_code = 'TECH'),
     'Fast-growing startup building next-gen applications',
     'startup', '10-50', 'https://startupx.example.com', TRUE)
ON DUPLICATE KEY UPDATE description = VALUES(description);

-- ============================================================================
-- SAMPLE JOBS
-- ============================================================================

INSERT INTO jobs (company_id, title, description, required_skills, preferred_skills, 
                  experience_min_years, experience_max_years, salary_min, salary_max,
                  job_type, work_arrangement, is_active) VALUES
    
    -- TechCorp Jobs
    ((SELECT company_id FROM companies WHERE company_name = 'TechCorp Innovation'),
     'Senior Full-Stack Developer',
     'We are looking for an experienced full-stack developer to join our product team. You will work on building scalable web applications using modern technologies.',
     'Python Django React JavaScript PostgreSQL Docker AWS Git REST',
     'TypeScript GraphQL Kubernetes Redis',
     5, 10, 150000, 200000, 'full_time', 'hybrid', TRUE),
    
    ((SELECT company_id FROM companies WHERE company_name = 'TechCorp Innovation'),
     'DevOps Engineer',
     'Join our infrastructure team to build and maintain cloud-native CI/CD pipelines.',
     'AWS Docker Kubernetes Terraform Linux CI/CD Python Bash Git',
     'Azure GCP Ansible Prometheus',
     3, 8, 130000, 180000, 'full_time', 'remote', TRUE),
    
    ((SELECT company_id FROM companies WHERE company_name = 'TechCorp Innovation'),
     'Junior Backend Developer',
     'Entry-level position for passionate developers interested in building APIs.',
     'Python SQL REST Git',
     'Django Flask PostgreSQL Docker',
     0, 2, 70000, 95000, 'full_time', 'onsite', TRUE),
    
    -- DataFlow Analytics Jobs
    ((SELECT company_id FROM companies WHERE company_name = 'DataFlow Analytics'),
     'Machine Learning Engineer',
     'Build and deploy ML models at scale for our analytics platform.',
     'Python TensorFlow PyTorch Machine-Learning Pandas SQL AWS',
     'Spark Kubernetes MLflow NLP',
     3, 7, 140000, 190000, 'full_time', 'hybrid', TRUE),
    
    ((SELECT company_id FROM companies WHERE company_name = 'DataFlow Analytics'),
     'Data Scientist',
     'Analyze large datasets and build predictive models for client solutions.',
     'Python Pandas Machine-Learning SQL Tableau',
     'R Spark TensorFlow Statistics',
     2, 5, 120000, 160000, 'full_time', 'remote', TRUE),
    
    -- CloudFirst Jobs
    ((SELECT company_id FROM companies WHERE company_name = 'CloudFirst Systems'),
     'React Frontend Developer',
     'Create beautiful and responsive user interfaces for our SaaS platform.',
     'React JavaScript TypeScript CSS HTML Git',
     'Next.js Tailwind GraphQL Testing',
     2, 6, 110000, 150000, 'full_time', 'remote', TRUE),
    
    ((SELECT company_id FROM companies WHERE company_name = 'CloudFirst Systems'),
     'Node.js Backend Developer',
     'Build scalable microservices for our cloud platform.',
     'Node.js JavaScript TypeScript PostgreSQL MongoDB REST Docker',
     'GraphQL Redis Kubernetes AWS',
     3, 7, 125000, 165000, 'full_time', 'hybrid', TRUE),
    
    -- FinanceHub Jobs
    ((SELECT company_id FROM companies WHERE company_name = 'FinanceHub Tech'),
     'Senior Java Developer',
     'Develop high-performance financial transaction systems.',
     'Java Spring-Boot PostgreSQL Kafka Docker REST Git',
     'Kubernetes AWS Microservices',
     5, 12, 160000, 220000, 'full_time', 'onsite', TRUE),
    
    -- StartupX Jobs
    ((SELECT company_id FROM companies WHERE company_name = 'StartupX'),
     'Full-Stack Engineer',
     'Wear many hats and build our product from the ground up.',
     'JavaScript React Node.js PostgreSQL Git AWS',
     'TypeScript Docker Python',
     2, 5, 100000, 140000, 'full_time', 'remote', TRUE),
    
    ((SELECT company_id FROM companies WHERE company_name = 'StartupX'),
     'Frontend Intern',
     'Learn and grow as a frontend developer while contributing to real projects.',
     'JavaScript HTML CSS Git',
     'React Vue.js TypeScript',
     0, 1, 40000, 55000, 'internship', 'hybrid', TRUE);

-- ============================================================================
-- SAMPLE SEEKERS
-- ============================================================================

INSERT INTO seekers (first_name, last_name, email, headline, summary, skills_text,
                     experience_years, current_job_title, desired_job_type,
                     desired_work_arrangement, desired_salary_min, is_available) VALUES
    
    ('Sarah', 'Chen',
     'sarah.chen@email.com',
     'Senior Full-Stack Developer | Python & React Expert',
     'Passionate developer with 7 years of experience building scalable web applications. Expert in Python, Django, and React.',
     'Python Django React JavaScript TypeScript PostgreSQL Docker AWS Kubernetes Git REST GraphQL',
     7, 'Senior Software Engineer', 'full_time', 'hybrid', 140000, TRUE),
    
    ('James', 'Wilson',
     'james.wilson@email.com',
     'DevOps Engineer | Cloud Infrastructure Specialist',
     '5 years experience in cloud infrastructure and automation. AWS certified.',
     'AWS Docker Kubernetes Terraform Linux Python Bash CI/CD Jenkins Git Azure',
     5, 'DevOps Engineer', 'full_time', 'remote', 130000, TRUE),
    
    ('Emily', 'Rodriguez',
     'emily.rodriguez@email.com',
     'Machine Learning Engineer | AI/ML Enthusiast',
     'ML engineer with expertise in deep learning and NLP. Building AI solutions for 4 years.',
     'Python TensorFlow PyTorch Machine-Learning Pandas NumPy SQL AWS Docker Spark NLP',
     4, 'ML Engineer', 'full_time', 'hybrid', 140000, TRUE),
    
    ('Michael', 'Johnson',
     'michael.johnson@email.com',
     'Frontend Developer | React Specialist',
     'Creating beautiful user experiences for 3 years. Passionate about modern frontend technologies.',
     'React JavaScript TypeScript CSS Tailwind HTML Next.js Git Testing',
     3, 'Frontend Developer', 'full_time', 'remote', 100000, TRUE),
    
    ('Lisa', 'Anderson',
     'lisa.anderson@email.com',
     'Data Scientist | Analytics Expert',
     'Data scientist with strong background in statistics and machine learning.',
     'Python Pandas Machine-Learning SQL Tableau R Statistics Spark Visualization',
     3, 'Data Analyst', 'full_time', 'remote', 110000, TRUE),
    
    ('David', 'Kim',
     'david.kim@email.com',
     'Backend Developer | Node.js & Java',
     'Backend specialist with experience in both Node.js and Java ecosystems.',
     'Node.js JavaScript Java Spring-Boot PostgreSQL MongoDB Redis Docker REST Git',
     4, 'Backend Developer', 'full_time', 'hybrid', 120000, TRUE),
    
    ('Amanda', 'Taylor',
     'amanda.taylor@email.com',
     'Junior Developer | Recent CS Graduate',
     'Enthusiastic recent graduate eager to start career in software development.',
     'Python JavaScript SQL Git HTML CSS React',
     0, NULL, 'full_time', 'onsite', 65000, TRUE),
    
    ('Robert', 'Brown',
     'robert.brown@email.com',
     'Senior Java Developer | FinTech Specialist',
     '10 years building high-performance financial systems.',
     'Java Spring-Boot PostgreSQL Kafka Docker Kubernetes AWS Microservices REST Git',
     10, 'Principal Engineer', 'full_time', 'hybrid', 180000, TRUE),
    
    ('Jennifer', 'Garcia',
     'jennifer.garcia@email.com',
     'Full-Stack Developer | Startup Experience',
     'Versatile developer who thrives in fast-paced startup environments.',
     'JavaScript React Node.js Python PostgreSQL MongoDB Docker AWS Git TypeScript',
     3, 'Software Developer', 'full_time', 'remote', 95000, TRUE),
    
    ('Chris', 'Lee',
     'chris.lee@email.com',
     'CS Student | Looking for Internship',
     'Computer Science student seeking internship opportunity to gain real-world experience.',
     'JavaScript HTML CSS Python Git React SQL',
     0, NULL, 'internship', 'hybrid', 40000, TRUE);
