/**
 * MatchingService
 * Core business logic for job-candidate matching using MySQL full-text search
 */

const db = require('../config/database');

class MatchingService {
    
    /**
     * Match candidates to a specific job using full-text search
     * @param {number} jobId - Job ID to match against
     * @param {Object} options - Matching options
     * @returns {Promise<Array>} Matched candidates with scores
     */
    async matchJobToCandidates(jobId, options = {}) {
        const { 
            limit = 50, 
            minExperience = null, 
            maxExperience = null 
        } = options;
        
        const results = await db.callProcedure(
            'sp_match_job_to_candidates',
            [jobId, limit, minExperience, maxExperience]
        );
        
        return results[0] || [];
    }
    
    /**
     * Match jobs to a specific candidate using full-text search
     * @param {number} seekerId - Seeker ID to match for
     * @param {Object} options - Matching options
     * @returns {Promise<Array>} Matched jobs with scores
     */
    async matchCandidateToJobs(seekerId, options = {}) {
        const {
            limit = 20,
            workArrangement = null,
            minSalary = null
        } = options;
        
        const results = await db.callProcedure(
            'sp_match_candidate_to_jobs',
            [seekerId, limit, workArrangement, minSalary]
        );
        
        return results[0] || [];
    }
    
    /**
     * Advanced skill-based search using Boolean mode
     * Supports operators: + (must have), - (must not), "" (phrase), * (wildcard)
     * 
     * @example
     * // Find candidates with Python AND Django, but NOT PHP
     * searchBySkills('+python +django -php', 'seekers')
     * 
     * @param {string} skillsQuery - Boolean mode search query
     * @param {string} searchType - 'seekers' or 'jobs'
     * @param {number} limit - Maximum results
     * @returns {Promise<Array>} Search results with relevance scores
     */
    async searchBySkills(skillsQuery, searchType = 'seekers', limit = 50) {
        const results = await db.callProcedure(
            'sp_advanced_skill_search',
            [skillsQuery, searchType, limit]
        );
        
        return results[0] || [];
    }
    
    /**
     * Perform bulk matching between all active jobs and available candidates
     * @param {number} minScore - Minimum match score threshold
     * @param {number} limit - Maximum results
     * @returns {Promise<Array>} All matches above threshold
     */
    async bulkMatch(minScore = 1.0, limit = 1000) {
        const results = await db.callProcedure(
            'sp_bulk_matching',
            [minScore, limit]
        );
        
        return results[0] || [];
    }
    
    /**
     * Raw full-text matching query (direct SQL)
     * The core matching query as per the project requirements
     * 
     * @param {string} requiredSkills - Space-separated required skills
     * @param {number} limit - Maximum results
     * @returns {Promise<Array>} Matched candidates
     */
    async rawSkillMatch(requiredSkills, limit = 50) {
        const sql = `
            SELECT 
                j.job_id,
                j.title,
                c.company_name,
                s.seeker_id,
                CONCAT(s.first_name, ' ', s.last_name) AS candidate_name,
                s.skills_text,
                MATCH(s.skills_text) AGAINST(? IN BOOLEAN MODE) AS relevance_score,
                s.experience_years
            FROM jobs j
            CROSS JOIN seekers s
            JOIN companies c ON j.company_id = c.company_id
            WHERE j.is_active = TRUE
              AND s.is_available = TRUE
              AND MATCH(s.skills_text) AGAINST(? IN BOOLEAN MODE)
            ORDER BY relevance_score DESC
            LIMIT ?
        `;
        
        return db.query(sql, [requiredSkills, requiredSkills, limit]);
    }
    
    /**
     * Find candidates similar to a given candidate
     * @param {number} seekerId - Reference seeker ID
     * @param {number} limit - Maximum results
     * @returns {Promise<Array>} Similar candidates
     */
    async findSimilarCandidates(seekerId, limit = 10) {
        const results = await db.callProcedure(
            'sp_find_similar_candidates',
            [seekerId, limit]
        );
        
        return results[0] || [];
    }
    
    /**
     * Find jobs similar to a given job
     * @param {number} jobId - Reference job ID
     * @param {number} limit - Maximum results
     * @returns {Promise<Array>} Similar jobs
     */
    async findSimilarJobs(jobId, limit = 10) {
        const results = await db.callProcedure(
            'sp_find_similar_jobs',
            [jobId, limit]
        );
        
        return results[0] || [];
    }
    
    /**
     * Analyze skill gap between a candidate and a job
     * @param {number} seekerId - Seeker ID
     * @param {number} jobId - Job ID
     * @returns {Promise<Array>} Missing skills
     */
    async analyzeSkillGap(seekerId, jobId) {
        const results = await db.callProcedure(
            'sp_skill_gap_analysis',
            [seekerId, jobId]
        );
        
        return results[0] || [];
    }
    
    /**
     * Get job recommendations for a candidate
     * @param {number} seekerId - Seeker ID
     * @param {number} limit - Maximum recommendations
     * @returns {Promise<Array>} Recommended jobs
     */
    async getRecommendations(seekerId, limit = 10) {
        const results = await db.callProcedure(
            'sp_api_get_recommended_jobs',
            [seekerId, limit]
        );
        
        return results[0] || [];
    }
}

module.exports = new MatchingService();
