/**
 * Job Matching Engine - Entry Point
 * Demonstrates the full-text search matching capabilities
 */

const db = require('./config/database');
const MatchingService = require('./services/MatchingService');

/**
 * Demo function showcasing the matching engine capabilities
 */
async function runDemo() {
    console.log('='.repeat(60));
    console.log('  JOB MATCHING ENGINE - DEMO');
    console.log('='.repeat(60));
    console.log();
    
    try {
        // Health check
        const isHealthy = await db.healthCheck();
        console.log(`Database connection: ${isHealthy ? '✓ Connected' : '✗ Failed'}`);
        console.log();
        
        if (!isHealthy) {
            console.error('Cannot proceed without database connection.');
            process.exit(1);
        }
        
        // ================================================================
        // Demo 1: Match candidates to a job using Boolean mode
        // ================================================================
        console.log('-'.repeat(60));
        console.log('Demo 1: Boolean Mode Skill Search');
        console.log('Query: +python +django -php (Must have Python AND Django, NOT PHP)');
        console.log('-'.repeat(60));
        
        const pythonCandidates = await MatchingService.searchBySkills(
            '+python +django -php',
            'seekers',
            5
        );
        
        if (pythonCandidates.length > 0) {
            console.table(pythonCandidates.map(c => ({
                Name: c.name,
                Score: parseFloat(c.score).toFixed(2),
                Skills: c.skills_text.substring(0, 50) + '...',
                Experience: c.experience_years + ' yrs'
            })));
        } else {
            console.log('No candidates found matching the query.');
        }
        console.log();
        
        // ================================================================
        // Demo 2: Find jobs matching React developers
        // ================================================================
        console.log('-'.repeat(60));
        console.log('Demo 2: Search Jobs for React Developers');
        console.log('Query: react javascript typescript');
        console.log('-'.repeat(60));
        
        const reactJobs = await MatchingService.searchBySkills(
            'react javascript typescript',
            'jobs',
            5
        );
        
        if (reactJobs.length > 0) {
            console.table(reactJobs.map(j => ({
                Title: j.title,
                Company: j.company_name,
                Score: parseFloat(j.score).toFixed(2),
                Salary: `$${j.salary_min?.toLocaleString() || 'N/A'}-$${j.salary_max?.toLocaleString() || 'N/A'}`
            })));
        } else {
            console.log('No jobs found matching the query.');
        }
        console.log();
        
        // ================================================================
        // Demo 3: Raw SQL Full-Text Match (as per project spec)
        // ================================================================
        console.log('-'.repeat(60));
        console.log('Demo 3: Raw SQL Full-Text Match');
        console.log('Core Query: MATCH...AGAINST IN BOOLEAN MODE');
        console.log('-'.repeat(60));
        
        const rawResults = await MatchingService.rawSkillMatch(
            'python javascript react aws docker',
            10
        );
        
        if (rawResults.length > 0) {
            console.table(rawResults.slice(0, 5).map(r => ({
                Job: r.title,
                Candidate: r.candidate_name,
                Score: parseFloat(r.relevance_score).toFixed(2),
                Experience: r.experience_years + ' yrs'
            })));
        } else {
            console.log('No matches found.');
        }
        console.log();
        
        // ================================================================
        // Demo 4: Bulk Matching (All Jobs x All Candidates)
        // ================================================================
        console.log('-'.repeat(60));
        console.log('Demo 4: Bulk Matching Overview');
        console.log('Matching all active jobs with available candidates');
        console.log('-'.repeat(60));
        
        const bulkMatches = await MatchingService.bulkMatch(0.5, 20);
        
        if (bulkMatches.length > 0) {
            console.log(`Found ${bulkMatches.length} potential matches.`);
            console.log('Top 5 matches:');
            console.table(bulkMatches.slice(0, 5).map(m => ({
                Job: m.job_title,
                Company: m.company_name,
                Candidate: m.candidate_name,
                Score: parseFloat(m.match_score).toFixed(2)
            })));
        } else {
            console.log('No bulk matches found above threshold.');
        }
        console.log();
        
        // ================================================================
        // Summary
        // ================================================================
        console.log('='.repeat(60));
        console.log('Demo Complete!');
        console.log('='.repeat(60));
        console.log();
        console.log('The Job Matching Engine supports:');
        console.log('  • Boolean mode searches (+required, -excluded)');
        console.log('  • Natural language relevance ranking');
        console.log('  • Bi-directional matching (jobs-to-candidates, candidates-to-jobs)');
        console.log('  • Bulk matching with score thresholds');
        console.log('  • Similar candidate/job discovery');
        console.log('  • Skill gap analysis');
        console.log();
        
    } catch (error) {
        console.error('Demo error:', error.message);
    } finally {
        // Close the connection pool
        await db.pool.end();
    }
}

// Run the demo
runDemo();
