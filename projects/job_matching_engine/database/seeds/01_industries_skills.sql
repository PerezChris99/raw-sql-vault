-- ============================================================================
-- Seed Data: Industries and Skill Categories
-- Purpose: Reference data for job categorization
-- ============================================================================

USE job_matching;

-- ============================================================================
-- INDUSTRIES
-- ============================================================================

INSERT INTO industries (industry_code, industry_name, description) VALUES
    ('TECH', 'Technology', 'Software, hardware, and IT services'),
    ('FIN', 'Finance', 'Banking, insurance, and financial services'),
    ('HEALTH', 'Healthcare', 'Medical, pharmaceutical, and health services'),
    ('EDU', 'Education', 'Schools, universities, and e-learning'),
    ('RETAIL', 'Retail', 'Consumer goods and e-commerce'),
    ('MFG', 'Manufacturing', 'Production and industrial'),
    ('MEDIA', 'Media & Entertainment', 'Publishing, broadcasting, and gaming'),
    ('CONSULT', 'Consulting', 'Business and management consulting'),
    ('TELE', 'Telecommunications', 'Networks and communications'),
    ('ENERGY', 'Energy', 'Oil, gas, and renewable energy')
ON DUPLICATE KEY UPDATE industry_name = VALUES(industry_name);

-- Sub-industries for Tech
INSERT INTO industries (industry_code, industry_name, description, parent_industry_id) VALUES
    ('SAAS', 'SaaS', 'Software as a Service', (SELECT industry_id FROM industries WHERE industry_code = 'TECH' LIMIT 1)),
    ('FINTECH', 'FinTech', 'Financial Technology', (SELECT industry_id FROM industries WHERE industry_code = 'TECH' LIMIT 1)),
    ('AIML', 'AI/ML', 'Artificial Intelligence and Machine Learning', (SELECT industry_id FROM industries WHERE industry_code = 'TECH' LIMIT 1)),
    ('CYBER', 'Cybersecurity', 'Information Security', (SELECT industry_id FROM industries WHERE industry_code = 'TECH' LIMIT 1)),
    ('ECOMM', 'E-Commerce', 'Online Retail Technology', (SELECT industry_id FROM industries WHERE industry_code = 'TECH' LIMIT 1))
ON DUPLICATE KEY UPDATE industry_name = VALUES(industry_name);

-- ============================================================================
-- SKILL CATEGORIES
-- ============================================================================

INSERT INTO skill_categories (category_code, category_name, description) VALUES
    ('PROG', 'Programming Languages', 'Core programming and scripting languages'),
    ('FRONTEND', 'Frontend Development', 'Client-side web technologies'),
    ('BACKEND', 'Backend Development', 'Server-side technologies and frameworks'),
    ('DATABASE', 'Databases', 'Data storage and query systems'),
    ('DEVOPS', 'DevOps & Cloud', 'Infrastructure and deployment'),
    ('DATA', 'Data Science', 'Analytics, ML, and data engineering'),
    ('MOBILE', 'Mobile Development', 'iOS, Android, and cross-platform'),
    ('DESIGN', 'Design', 'UI/UX and graphic design'),
    ('MGMT', 'Management', 'Project and team management'),
    ('SOFT', 'Soft Skills', 'Communication and interpersonal skills')
ON DUPLICATE KEY UPDATE category_name = VALUES(category_name);

-- ============================================================================
-- SKILLS
-- ============================================================================

-- Programming Languages
INSERT INTO skills (skill_code, skill_name, category_id, synonyms, is_technical, demand_level) VALUES
    ('PYTHON', 'Python', (SELECT category_id FROM skill_categories WHERE category_code = 'PROG'), 'py,python3', TRUE, 'critical'),
    ('JAVASCRIPT', 'JavaScript', (SELECT category_id FROM skill_categories WHERE category_code = 'PROG'), 'js,ecmascript,es6', TRUE, 'critical'),
    ('TYPESCRIPT', 'TypeScript', (SELECT category_id FROM skill_categories WHERE category_code = 'PROG'), 'ts', TRUE, 'high'),
    ('JAVA', 'Java', (SELECT category_id FROM skill_categories WHERE category_code = 'PROG'), 'j2ee,jdk', TRUE, 'high'),
    ('CSHARP', 'C#', (SELECT category_id FROM skill_categories WHERE category_code = 'PROG'), 'csharp,dotnet', TRUE, 'high'),
    ('GO', 'Go', (SELECT category_id FROM skill_categories WHERE category_code = 'PROG'), 'golang', TRUE, 'high'),
    ('RUST', 'Rust', (SELECT category_id FROM skill_categories WHERE category_code = 'PROG'), 'rustlang', TRUE, 'medium'),
    ('PHP', 'PHP', (SELECT category_id FROM skill_categories WHERE category_code = 'PROG'), 'php8', TRUE, 'medium'),
    ('RUBY', 'Ruby', (SELECT category_id FROM skill_categories WHERE category_code = 'PROG'), 'rb', TRUE, 'medium'),
    ('SWIFT', 'Swift', (SELECT category_id FROM skill_categories WHERE category_code = 'PROG'), 'swiftlang', TRUE, 'medium'),
    ('KOTLIN', 'Kotlin', (SELECT category_id FROM skill_categories WHERE category_code = 'PROG'), 'kt', TRUE, 'medium'),
    ('CPP', 'C++', (SELECT category_id FROM skill_categories WHERE category_code = 'PROG'), 'cpp,cplusplus', TRUE, 'medium'),
    ('SQL', 'SQL', (SELECT category_id FROM skill_categories WHERE category_code = 'PROG'), 'tsql,plsql', TRUE, 'high')
ON DUPLICATE KEY UPDATE demand_level = VALUES(demand_level);

-- Frontend
INSERT INTO skills (skill_code, skill_name, category_id, synonyms, is_technical, demand_level) VALUES
    ('REACT', 'React', (SELECT category_id FROM skill_categories WHERE category_code = 'FRONTEND'), 'reactjs,react.js', TRUE, 'critical'),
    ('VUE', 'Vue.js', (SELECT category_id FROM skill_categories WHERE category_code = 'FRONTEND'), 'vuejs,vue', TRUE, 'high'),
    ('ANGULAR', 'Angular', (SELECT category_id FROM skill_categories WHERE category_code = 'FRONTEND'), 'angularjs,ng', TRUE, 'high'),
    ('NEXTJS', 'Next.js', (SELECT category_id FROM skill_categories WHERE category_code = 'FRONTEND'), 'next,nextjs', TRUE, 'high'),
    ('HTML', 'HTML', (SELECT category_id FROM skill_categories WHERE category_code = 'FRONTEND'), 'html5', TRUE, 'high'),
    ('CSS', 'CSS', (SELECT category_id FROM skill_categories WHERE category_code = 'FRONTEND'), 'css3,scss,sass', TRUE, 'high'),
    ('TAILWIND', 'Tailwind CSS', (SELECT category_id FROM skill_categories WHERE category_code = 'FRONTEND'), 'tailwindcss', TRUE, 'high'),
    ('SVELTE', 'Svelte', (SELECT category_id FROM skill_categories WHERE category_code = 'FRONTEND'), 'sveltejs', TRUE, 'medium')
ON DUPLICATE KEY UPDATE demand_level = VALUES(demand_level);

-- Backend
INSERT INTO skills (skill_code, skill_name, category_id, synonyms, is_technical, demand_level) VALUES
    ('NODEJS', 'Node.js', (SELECT category_id FROM skill_categories WHERE category_code = 'BACKEND'), 'node,nodejs', TRUE, 'critical'),
    ('DJANGO', 'Django', (SELECT category_id FROM skill_categories WHERE category_code = 'BACKEND'), 'djangorest,drf', TRUE, 'high'),
    ('FLASK', 'Flask', (SELECT category_id FROM skill_categories WHERE category_code = 'BACKEND'), 'flaskapi', TRUE, 'medium'),
    ('FASTAPI', 'FastAPI', (SELECT category_id FROM skill_categories WHERE category_code = 'BACKEND'), 'fast-api', TRUE, 'high'),
    ('SPRING', 'Spring Boot', (SELECT category_id FROM skill_categories WHERE category_code = 'BACKEND'), 'springboot,spring', TRUE, 'high'),
    ('EXPRESS', 'Express.js', (SELECT category_id FROM skill_categories WHERE category_code = 'BACKEND'), 'expressjs,express', TRUE, 'high'),
    ('RAILS', 'Ruby on Rails', (SELECT category_id FROM skill_categories WHERE category_code = 'BACKEND'), 'ror,rails', TRUE, 'medium'),
    ('DOTNET', '.NET Core', (SELECT category_id FROM skill_categories WHERE category_code = 'BACKEND'), 'aspnet,dotnetcore', TRUE, 'high'),
    ('GRAPHQL', 'GraphQL', (SELECT category_id FROM skill_categories WHERE category_code = 'BACKEND'), 'gql', TRUE, 'high'),
    ('REST', 'REST APIs', (SELECT category_id FROM skill_categories WHERE category_code = 'BACKEND'), 'restapi,restful', TRUE, 'critical')
ON DUPLICATE KEY UPDATE demand_level = VALUES(demand_level);

-- Databases
INSERT INTO skills (skill_code, skill_name, category_id, synonyms, is_technical, demand_level) VALUES
    ('POSTGRESQL', 'PostgreSQL', (SELECT category_id FROM skill_categories WHERE category_code = 'DATABASE'), 'postgres,psql', TRUE, 'critical'),
    ('MYSQL', 'MySQL', (SELECT category_id FROM skill_categories WHERE category_code = 'DATABASE'), 'mariadb', TRUE, 'high'),
    ('MONGODB', 'MongoDB', (SELECT category_id FROM skill_categories WHERE category_code = 'DATABASE'), 'mongo,nosql', TRUE, 'high'),
    ('REDIS', 'Redis', (SELECT category_id FROM skill_categories WHERE category_code = 'DATABASE'), 'redisdb', TRUE, 'high'),
    ('ELASTICSEARCH', 'Elasticsearch', (SELECT category_id FROM skill_categories WHERE category_code = 'DATABASE'), 'elastic,es', TRUE, 'high'),
    ('DYNAMODB', 'DynamoDB', (SELECT category_id FROM skill_categories WHERE category_code = 'DATABASE'), 'dynamo', TRUE, 'medium'),
    ('CASSANDRA', 'Cassandra', (SELECT category_id FROM skill_categories WHERE category_code = 'DATABASE'), 'apache-cassandra', TRUE, 'medium'),
    ('ORACLE', 'Oracle', (SELECT category_id FROM skill_categories WHERE category_code = 'DATABASE'), 'oracledb', TRUE, 'medium')
ON DUPLICATE KEY UPDATE demand_level = VALUES(demand_level);

-- DevOps & Cloud
INSERT INTO skills (skill_code, skill_name, category_id, synonyms, is_technical, demand_level) VALUES
    ('AWS', 'AWS', (SELECT category_id FROM skill_categories WHERE category_code = 'DEVOPS'), 'amazon-web-services,ec2,s3', TRUE, 'critical'),
    ('AZURE', 'Azure', (SELECT category_id FROM skill_categories WHERE category_code = 'DEVOPS'), 'microsoft-azure', TRUE, 'high'),
    ('GCP', 'Google Cloud', (SELECT category_id FROM skill_categories WHERE category_code = 'DEVOPS'), 'gcp,google-cloud-platform', TRUE, 'high'),
    ('DOCKER', 'Docker', (SELECT category_id FROM skill_categories WHERE category_code = 'DEVOPS'), 'containers,dockerfile', TRUE, 'critical'),
    ('KUBERNETES', 'Kubernetes', (SELECT category_id FROM skill_categories WHERE category_code = 'DEVOPS'), 'k8s,kubectl', TRUE, 'high'),
    ('TERRAFORM', 'Terraform', (SELECT category_id FROM skill_categories WHERE category_code = 'DEVOPS'), 'tf,iac', TRUE, 'high'),
    ('CICD', 'CI/CD', (SELECT category_id FROM skill_categories WHERE category_code = 'DEVOPS'), 'jenkins,github-actions,gitlab-ci', TRUE, 'high'),
    ('LINUX', 'Linux', (SELECT category_id FROM skill_categories WHERE category_code = 'DEVOPS'), 'ubuntu,centos,bash', TRUE, 'high'),
    ('GIT', 'Git', (SELECT category_id FROM skill_categories WHERE category_code = 'DEVOPS'), 'github,gitlab,version-control', TRUE, 'critical')
ON DUPLICATE KEY UPDATE demand_level = VALUES(demand_level);

-- Data Science
INSERT INTO skills (skill_code, skill_name, category_id, synonyms, is_technical, demand_level) VALUES
    ('ML', 'Machine Learning', (SELECT category_id FROM skill_categories WHERE category_code = 'DATA'), 'machinelearning,ml-models', TRUE, 'critical'),
    ('TENSORFLOW', 'TensorFlow', (SELECT category_id FROM skill_categories WHERE category_code = 'DATA'), 'tf,keras', TRUE, 'high'),
    ('PYTORCH', 'PyTorch', (SELECT category_id FROM skill_categories WHERE category_code = 'DATA'), 'torch', TRUE, 'high'),
    ('PANDAS', 'Pandas', (SELECT category_id FROM skill_categories WHERE category_code = 'DATA'), 'dataframes', TRUE, 'high'),
    ('SPARK', 'Apache Spark', (SELECT category_id FROM skill_categories WHERE category_code = 'DATA'), 'pyspark,spark-sql', TRUE, 'high'),
    ('TABLEAU', 'Tableau', (SELECT category_id FROM skill_categories WHERE category_code = 'DATA'), 'data-visualization', TRUE, 'medium'),
    ('POWERBI', 'Power BI', (SELECT category_id FROM skill_categories WHERE category_code = 'DATA'), 'pbi,dax', TRUE, 'medium'),
    ('NLP', 'NLP', (SELECT category_id FROM skill_categories WHERE category_code = 'DATA'), 'natural-language-processing', TRUE, 'high')
ON DUPLICATE KEY UPDATE demand_level = VALUES(demand_level);

-- Soft Skills
INSERT INTO skills (skill_code, skill_name, category_id, synonyms, is_technical, demand_level) VALUES
    ('LEADERSHIP', 'Leadership', (SELECT category_id FROM skill_categories WHERE category_code = 'SOFT'), 'team-lead,management', FALSE, 'high'),
    ('COMMUNICATION', 'Communication', (SELECT category_id FROM skill_categories WHERE category_code = 'SOFT'), 'presentation,writing', FALSE, 'critical'),
    ('AGILE', 'Agile', (SELECT category_id FROM skill_categories WHERE category_code = 'SOFT'), 'scrum,kanban,sprint', FALSE, 'high'),
    ('PROBLEMSOLVING', 'Problem Solving', (SELECT category_id FROM skill_categories WHERE category_code = 'SOFT'), 'analytical,critical-thinking', FALSE, 'high'),
    ('TEAMWORK', 'Teamwork', (SELECT category_id FROM skill_categories WHERE category_code = 'SOFT'), 'collaboration,team-player', FALSE, 'high')
ON DUPLICATE KEY UPDATE demand_level = VALUES(demand_level);
