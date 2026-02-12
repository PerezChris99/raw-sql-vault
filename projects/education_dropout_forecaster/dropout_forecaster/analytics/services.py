"""
Services for Education Dropout Forecaster
Contains raw SQL queries using Django's raw() and connection.cursor()
Demonstrates window function usage with PostgreSQL
"""

import logging
from typing import List, Dict, Any, Optional
from django.db import connection
from django.db.models import QuerySet

from .models import Student, School, District

logger = logging.getLogger(__name__)


class DropoutAnalytics:
    """
    Service class for dropout analysis using raw SQL with window functions.
    All methods use Django's raw() or cursor for direct SQL execution.
    """

    # =========================================================================
    # CORE QUERY: School Rankings (Per Specification)
    # =========================================================================

    def get_school_rankings(
        self,
        district_id: Optional[int] = None,
        academic_year: Optional[int] = None,
        limit: int = 100
    ) -> List[Dict[str, Any]]:
        """
        Get schools ranked by dropout count within each district.
        Uses ROW_NUMBER() and RANK() window functions.
        
        This is the core query per project specification:
        SELECT school, COUNT(*) as dropouts, 
               ROW_NUMBER() OVER (PARTITION BY district ORDER BY COUNT(*) DESC) as rank
        FROM students WHERE status='dropped' GROUP BY school;
        """
        params = []
        where_clauses = ["st.status = 'DROPPED'"]
        
        if district_id:
            where_clauses.append("d.district_id = %s")
            params.append(district_id)
        if academic_year:
            where_clauses.append("st.academic_year = %s")
            params.append(academic_year)
        
        params.append(limit)
        where_clause = " AND ".join(where_clauses)
        
        sql = f"""
            SELECT 
                s.school_id,
                s.school_code,
                s.school_name,
                d.district_id,
                d.district_name,
                COUNT(*) AS dropout_count,
                s.enrollment,
                ROUND(COUNT(*) * 100.0 / NULLIF(s.enrollment, 0), 2) AS dropout_rate,
                ROW_NUMBER() OVER (
                    PARTITION BY d.district_id 
                    ORDER BY COUNT(*) DESC
                ) AS district_rank,
                RANK() OVER (
                    ORDER BY COUNT(*) DESC
                ) AS overall_rank,
                DENSE_RANK() OVER (
                    ORDER BY ROUND(COUNT(*) * 100.0 / NULLIF(s.enrollment, 0), 2) DESC
                ) AS rate_rank
            FROM students st
            JOIN schools s ON st.school_id = s.school_id
            JOIN districts d ON s.district_id = d.district_id
            WHERE {where_clause}
            GROUP BY s.school_id, s.school_code, s.school_name, 
                     d.district_id, d.district_name, s.enrollment
            ORDER BY d.district_name, district_rank
            LIMIT %s
        """
        
        logger.debug(f"Executing school rankings query with params: {params}")
        return self._execute_query(sql, params)

    # =========================================================================
    # YEAR-OVER-YEAR COMPARISON with LAG/LEAD
    # =========================================================================

    def get_yoy_comparison(
        self,
        school_id: Optional[int] = None,
        district_id: Optional[int] = None
    ) -> List[Dict[str, Any]]:
        """
        Get year-over-year dropout comparison using LAG/LEAD window functions.
        Shows previous year, current year, and next year dropouts with changes.
        """
        params = []
        where_clauses = ["st.status = 'DROPPED'"]
        
        if school_id:
            where_clauses.append("s.school_id = %s")
            params.append(school_id)
        if district_id:
            where_clauses.append("s.district_id = %s")
            params.append(district_id)
        
        where_clause = " AND ".join(where_clauses)
        
        sql = f"""
            WITH yearly_stats AS (
                SELECT 
                    s.school_id,
                    s.school_name,
                    st.academic_year,
                    COUNT(*) AS dropout_count
                FROM students st
                JOIN schools s ON st.school_id = s.school_id
                WHERE {where_clause}
                GROUP BY s.school_id, s.school_name, st.academic_year
            )
            SELECT 
                school_id,
                school_name,
                academic_year,
                dropout_count,
                LAG(dropout_count, 1) OVER (
                    PARTITION BY school_id 
                    ORDER BY academic_year
                ) AS prev_year_dropouts,
                LEAD(dropout_count, 1) OVER (
                    PARTITION BY school_id 
                    ORDER BY academic_year
                ) AS next_year_dropouts,
                dropout_count - LAG(dropout_count, 1) OVER (
                    PARTITION BY school_id 
                    ORDER BY academic_year
                ) AS change_from_prev,
                ROUND(
                    (dropout_count - LAG(dropout_count, 1) OVER (
                        PARTITION BY school_id ORDER BY academic_year
                    )) * 100.0 / NULLIF(LAG(dropout_count, 1) OVER (
                        PARTITION BY school_id ORDER BY academic_year
                    ), 0), 2
                ) AS pct_change,
                CASE 
                    WHEN dropout_count > LAG(dropout_count, 1) OVER (
                        PARTITION BY school_id ORDER BY academic_year
                    ) THEN 'INCREASING'
                    WHEN dropout_count < LAG(dropout_count, 1) OVER (
                        PARTITION BY school_id ORDER BY academic_year
                    ) THEN 'DECREASING'
                    ELSE 'STABLE'
                END AS trend
            FROM yearly_stats
            ORDER BY school_id, academic_year
        """
        
        return self._execute_query(sql, params)

    # =========================================================================
    # RUNNING TOTALS with SUM OVER
    # =========================================================================

    def get_cumulative_dropouts(
        self,
        school_id: int,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Get cumulative/running dropout totals using SUM() OVER().
        Shows daily dropouts, cumulative total, YTD total, and rolling 7-day.
        """
        params = [school_id]
        where_clauses = ["de.school_id = %s"]
        
        if start_date:
            where_clauses.append("de.dropout_date >= %s")
            params.append(start_date)
        if end_date:
            where_clauses.append("de.dropout_date <= %s")
            params.append(end_date)
        
        where_clause = " AND ".join(where_clauses)
        
        sql = f"""
            WITH daily_dropouts AS (
                SELECT 
                    de.dropout_date,
                    COUNT(*) AS daily_count
                FROM dropout_events de
                WHERE {where_clause}
                GROUP BY de.dropout_date
            )
            SELECT 
                dropout_date,
                daily_count,
                SUM(daily_count) OVER (
                    ORDER BY dropout_date 
                    ROWS UNBOUNDED PRECEDING
                ) AS cumulative_total,
                SUM(daily_count) OVER (
                    PARTITION BY EXTRACT(YEAR FROM dropout_date)
                    ORDER BY dropout_date 
                    ROWS UNBOUNDED PRECEDING
                ) AS ytd_total,
                SUM(daily_count) OVER (
                    ORDER BY dropout_date 
                    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
                ) AS rolling_7day
            FROM daily_dropouts
            ORDER BY dropout_date
        """
        
        return self._execute_query(sql, params)

    # =========================================================================
    # PERCENTILE ANALYSIS with NTILE
    # =========================================================================

    def get_risk_percentiles(
        self,
        school_id: Optional[int] = None,
        district_id: Optional[int] = None,
        risk_threshold: float = 0
    ) -> List[Dict[str, Any]]:
        """
        Get student risk percentiles using NTILE() and PERCENT_RANK().
        Divides students into quartiles, deciles, and percentiles.
        """
        params = [risk_threshold]
        where_clauses = ["st.status = 'ACTIVE'", "st.risk_score >= %s"]
        
        if school_id:
            where_clauses.append("st.school_id = %s")
            params.append(school_id)
        if district_id:
            where_clauses.append("s.district_id = %s")
            params.append(district_id)
        
        where_clause = " AND ".join(where_clauses)
        
        sql = f"""
            SELECT 
                st.student_id,
                st.first_name || ' ' || st.last_name AS student_name,
                s.school_name,
                st.grade_level,
                st.risk_score,
                NTILE(4) OVER (ORDER BY st.risk_score DESC) AS risk_quartile,
                NTILE(10) OVER (ORDER BY st.risk_score DESC) AS risk_decile,
                NTILE(100) OVER (ORDER BY st.risk_score DESC) AS risk_percentile,
                ROUND(PERCENT_RANK() OVER (ORDER BY st.risk_score) * 100, 2) AS percentile_rank
            FROM students st
            JOIN schools s ON st.school_id = s.school_id
            WHERE {where_clause}
            ORDER BY st.risk_score DESC
        """
        
        return self._execute_query(sql, params)

    # =========================================================================
    # MOVING AVERAGES with AVG OVER
    # =========================================================================

    def get_moving_averages(
        self,
        district_id: Optional[int] = None,
        months: int = 12
    ) -> List[Dict[str, Any]]:
        """
        Get dropout moving averages (3-month, 6-month, 12-month).
        Uses AVG() OVER() with ROWS BETWEEN.
        """
        params = []
        where_clauses = [f"de.dropout_date >= CURRENT_DATE - INTERVAL '{months} months'"]
        
        if district_id:
            where_clauses.append("d.district_id = %s")
            params.append(district_id)
        
        where_clause = " AND ".join(where_clauses)
        
        sql = f"""
            WITH monthly_stats AS (
                SELECT 
                    d.district_id,
                    d.district_name,
                    DATE_TRUNC('month', de.dropout_date)::DATE AS report_month,
                    COUNT(*) AS monthly_dropouts
                FROM dropout_events de
                JOIN districts d ON de.district_id = d.district_id
                WHERE {where_clause}
                GROUP BY d.district_id, d.district_name, DATE_TRUNC('month', de.dropout_date)
            )
            SELECT 
                district_id,
                district_name,
                report_month,
                monthly_dropouts,
                ROUND(AVG(monthly_dropouts) OVER (
                    PARTITION BY district_id 
                    ORDER BY report_month 
                    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
                ), 2) AS moving_avg_3m,
                ROUND(AVG(monthly_dropouts) OVER (
                    PARTITION BY district_id 
                    ORDER BY report_month 
                    ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
                ), 2) AS moving_avg_6m,
                ROUND(AVG(monthly_dropouts) OVER (
                    PARTITION BY district_id 
                    ORDER BY report_month 
                    ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
                ), 2) AS moving_avg_12m
            FROM monthly_stats
            ORDER BY district_id, report_month
        """
        
        return self._execute_query(sql, params)

    # =========================================================================
    # AT-RISK STUDENTS
    # =========================================================================

    def get_at_risk_students(
        self,
        school_id: Optional[int] = None,
        risk_decile_threshold: int = 3,
        limit: int = 100
    ) -> List[Dict[str, Any]]:
        """
        Get at-risk students with school and district rankings.
        Uses ROW_NUMBER() for ranking within groups.
        """
        params = [risk_decile_threshold]
        where_clauses = ["st.status = 'ACTIVE'", "st.risk_decile <= %s"]
        
        if school_id:
            where_clauses.append("st.school_id = %s")
            params.append(school_id)
        
        params.append(limit)
        where_clause = " AND ".join(where_clauses)
        
        sql = f"""
            SELECT 
                st.student_id,
                st.student_code,
                st.first_name || ' ' || st.last_name AS full_name,
                s.school_name,
                st.grade_level,
                st.gpa,
                st.attendance_rate,
                st.disciplinary_incidents,
                st.risk_score,
                st.risk_decile,
                ROW_NUMBER() OVER (
                    PARTITION BY st.school_id 
                    ORDER BY st.risk_score DESC
                ) AS school_risk_rank,
                ROW_NUMBER() OVER (
                    PARTITION BY s.district_id 
                    ORDER BY st.risk_score DESC
                ) AS district_risk_rank,
                CASE 
                    WHEN st.risk_score >= 80 THEN 'Critical'
                    WHEN st.risk_score >= 60 THEN 'High'
                    WHEN st.risk_score >= 40 THEN 'Moderate'
                    ELSE 'Low'
                END AS risk_level
            FROM students st
            JOIN schools s ON st.school_id = s.school_id
            WHERE {where_clause}
            ORDER BY st.risk_score DESC
            LIMIT %s
        """
        
        return self._execute_query(sql, params)

    # =========================================================================
    # DROPOUT REASON ANALYSIS
    # =========================================================================

    def get_reason_rankings(
        self,
        academic_year: Optional[int] = None
    ) -> List[Dict[str, Any]]:
        """
        Get dropout reasons ranked by frequency using RANK() and DENSE_RANK().
        Also calculates cumulative percentage for Pareto analysis.
        """
        params = []
        where_clauses = ["st.status = 'DROPPED'"]
        
        if academic_year:
            where_clauses.append("st.academic_year = %s")
            params.append(academic_year)
        
        where_clause = " AND ".join(where_clauses)
        
        sql = f"""
            SELECT 
                dr.reason_code,
                dr.reason_name,
                dr.is_preventable,
                COUNT(*) AS total_dropouts,
                RANK() OVER (ORDER BY COUNT(*) DESC) AS rank_position,
                DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) AS dense_rank_position,
                ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total,
                ROUND(
                    SUM(COUNT(*)) OVER (
                        ORDER BY COUNT(*) DESC 
                        ROWS UNBOUNDED PRECEDING
                    ) * 100.0 / SUM(COUNT(*)) OVER ()
                , 2) AS cumulative_pct
            FROM students st
            JOIN dropout_reasons dr ON st.dropout_reason_id = dr.reason_id
            WHERE {where_clause}
            GROUP BY dr.reason_id, dr.reason_code, dr.reason_name, dr.is_preventable
            ORDER BY rank_position
        """
        
        return self._execute_query(sql, params)

    # =========================================================================
    # DISTRICT SUMMARY
    # =========================================================================

    def get_district_summary(self) -> List[Dict[str, Any]]:
        """
        Get district-level summary with state rankings.
        Uses ROW_NUMBER() PARTITION BY state and NTILE() for risk quintiles.
        """
        sql = """
            SELECT 
                d.district_id,
                d.district_name,
                st.state_name,
                d.total_schools,
                d.total_students,
                COUNT(DISTINCT CASE WHEN stu.status = 'DROPPED' THEN stu.student_id END) AS total_dropouts,
                ROUND(
                    COUNT(DISTINCT CASE WHEN stu.status = 'DROPPED' THEN stu.student_id END) * 100.0 
                    / NULLIF(d.total_students, 0)
                , 2) AS dropout_rate,
                ROW_NUMBER() OVER (
                    PARTITION BY st.state_id 
                    ORDER BY COUNT(DISTINCT CASE WHEN stu.status = 'DROPPED' THEN stu.student_id END) DESC
                ) AS state_rank,
                NTILE(5) OVER (
                    ORDER BY COUNT(DISTINCT CASE WHEN stu.status = 'DROPPED' THEN stu.student_id END) * 100.0 
                             / NULLIF(d.total_students, 0) DESC
                ) AS risk_quintile
            FROM districts d
            JOIN states st ON d.state_id = st.state_id
            LEFT JOIN schools s ON d.district_id = s.district_id
            LEFT JOIN students stu ON s.school_id = stu.school_id
            GROUP BY d.district_id, d.district_name, st.state_id, st.state_name, 
                     d.total_schools, d.total_students
            ORDER BY st.state_name, state_rank
        """
        
        return self._execute_query(sql, [])

    # =========================================================================
    # STORED PROCEDURE CALLS
    # =========================================================================

    def call_school_rankings_function(
        self,
        academic_year: Optional[int] = None,
        district_id: Optional[int] = None,
        limit: int = 100
    ) -> List[Dict[str, Any]]:
        """Call the fn_school_dropout_rankings stored function."""
        sql = "SELECT * FROM fn_school_dropout_rankings(%s, %s, %s)"
        return self._execute_query(sql, [academic_year, district_id, limit])

    def call_risk_percentiles_function(
        self,
        school_id: Optional[int] = None,
        district_id: Optional[int] = None,
        risk_threshold: float = 0
    ) -> List[Dict[str, Any]]:
        """Call the fn_risk_percentiles stored function."""
        sql = "SELECT * FROM fn_risk_percentiles(%s, %s, %s)"
        return self._execute_query(sql, [school_id, district_id, risk_threshold])

    def call_early_warning_alerts(
        self,
        school_id: Optional[int] = None,
        days_lookback: int = 30
    ) -> List[Dict[str, Any]]:
        """Call the fn_early_warning_alerts stored function."""
        sql = "SELECT * FROM fn_early_warning_alerts(%s, %s)"
        return self._execute_query(sql, [school_id, days_lookback])

    # =========================================================================
    # RAW ORM QUERIES
    # =========================================================================

    def get_students_with_ranking_raw(
        self,
        school_id: int
    ) -> QuerySet:
        """
        Use Django's raw() method on the Student model.
        Returns Student model instances with additional window function fields.
        """
        sql = """
            SELECT 
                st.*,
                NTILE(10) OVER (ORDER BY st.risk_score DESC) AS computed_decile,
                ROW_NUMBER() OVER (ORDER BY st.risk_score DESC) AS risk_rank
            FROM students st
            WHERE st.school_id = %s AND st.status = 'ACTIVE'
            ORDER BY st.risk_score DESC
        """
        return Student.objects.raw(sql, [school_id])

    # =========================================================================
    # HELPER METHODS
    # =========================================================================

    def _execute_query(
        self,
        sql: str,
        params: List[Any]
    ) -> List[Dict[str, Any]]:
        """Execute raw SQL and return results as list of dicts."""
        with connection.cursor() as cursor:
            cursor.execute(sql, params)
            columns = [col[0] for col in cursor.description]
            return [dict(zip(columns, row)) for row in cursor.fetchall()]


# ============================================================================
# Convenience functions for quick access
# ============================================================================

def get_school_rankings(**kwargs) -> List[Dict[str, Any]]:
    """Quick access to school rankings."""
    return DropoutAnalytics().get_school_rankings(**kwargs)


def get_at_risk_students(**kwargs) -> List[Dict[str, Any]]:
    """Quick access to at-risk students."""
    return DropoutAnalytics().get_at_risk_students(**kwargs)


def get_yoy_comparison(**kwargs) -> List[Dict[str, Any]]:
    """Quick access to year-over-year comparison."""
    return DropoutAnalytics().get_yoy_comparison(**kwargs)
