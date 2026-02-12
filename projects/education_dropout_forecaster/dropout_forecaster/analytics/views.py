"""
Views for Education Dropout Forecaster
API endpoints for dropout analytics using raw SQL queries
"""

import json
from django.http import JsonResponse
from django.views import View
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator

from .services import DropoutAnalytics


class BaseAPIView(View):
    """Base view with common functionality."""
    
    def get_int_param(self, request, name, default=None):
        """Get integer parameter from request."""
        value = request.GET.get(name)
        if value is None:
            return default
        try:
            return int(value)
        except ValueError:
            return default
    
    def get_float_param(self, request, name, default=None):
        """Get float parameter from request."""
        value = request.GET.get(name)
        if value is None:
            return default
        try:
            return float(value)
        except ValueError:
            return default


@method_decorator(csrf_exempt, name='dispatch')
class SchoolRankingsView(BaseAPIView):
    """
    API endpoint for school dropout rankings.
    
    GET /api/schools/rankings/
    Query params:
        - district_id: Filter by district
        - academic_year: Filter by year
        - limit: Max results (default 100)
    """
    
    def get(self, request):
        analytics = DropoutAnalytics()
        
        results = analytics.get_school_rankings(
            district_id=self.get_int_param(request, 'district_id'),
            academic_year=self.get_int_param(request, 'academic_year'),
            limit=self.get_int_param(request, 'limit', 100)
        )
        
        return JsonResponse({
            'success': True,
            'count': len(results),
            'data': results
        })


@method_decorator(csrf_exempt, name='dispatch')
class YearOverYearView(BaseAPIView):
    """
    API endpoint for year-over-year dropout comparison.
    Uses LAG/LEAD window functions.
    
    GET /api/analytics/yoy/
    Query params:
        - school_id: Filter by school
        - district_id: Filter by district
    """
    
    def get(self, request):
        analytics = DropoutAnalytics()
        
        results = analytics.get_yoy_comparison(
            school_id=self.get_int_param(request, 'school_id'),
            district_id=self.get_int_param(request, 'district_id')
        )
        
        return JsonResponse({
            'success': True,
            'count': len(results),
            'data': results
        })


@method_decorator(csrf_exempt, name='dispatch')
class CumulativeDropoutsView(BaseAPIView):
    """
    API endpoint for cumulative dropout tracking.
    Uses SUM() OVER() for running totals.
    
    GET /api/analytics/cumulative/<school_id>/
    Query params:
        - start_date: Filter start date (YYYY-MM-DD)
        - end_date: Filter end date (YYYY-MM-DD)
    """
    
    def get(self, request, school_id):
        analytics = DropoutAnalytics()
        
        results = analytics.get_cumulative_dropouts(
            school_id=school_id,
            start_date=request.GET.get('start_date'),
            end_date=request.GET.get('end_date')
        )
        
        return JsonResponse({
            'success': True,
            'school_id': school_id,
            'count': len(results),
            'data': results
        })


@method_decorator(csrf_exempt, name='dispatch')
class RiskPercentilesView(BaseAPIView):
    """
    API endpoint for student risk percentiles.
    Uses NTILE() and PERCENT_RANK() window functions.
    
    GET /api/students/risk-percentiles/
    Query params:
        - school_id: Filter by school
        - district_id: Filter by district
        - risk_threshold: Minimum risk score (default 0)
    """
    
    def get(self, request):
        analytics = DropoutAnalytics()
        
        results = analytics.get_risk_percentiles(
            school_id=self.get_int_param(request, 'school_id'),
            district_id=self.get_int_param(request, 'district_id'),
            risk_threshold=self.get_float_param(request, 'risk_threshold', 0)
        )
        
        return JsonResponse({
            'success': True,
            'count': len(results),
            'data': results
        })


@method_decorator(csrf_exempt, name='dispatch')
class AtRiskStudentsView(BaseAPIView):
    """
    API endpoint for at-risk students.
    Shows students in top risk deciles with school/district rankings.
    
    GET /api/students/at-risk/
    Query params:
        - school_id: Filter by school
        - risk_decile_threshold: Max decile (default 3)
        - limit: Max results (default 100)
    """
    
    def get(self, request):
        analytics = DropoutAnalytics()
        
        results = analytics.get_at_risk_students(
            school_id=self.get_int_param(request, 'school_id'),
            risk_decile_threshold=self.get_int_param(request, 'risk_decile_threshold', 3),
            limit=self.get_int_param(request, 'limit', 100)
        )
        
        return JsonResponse({
            'success': True,
            'count': len(results),
            'data': results
        })


@method_decorator(csrf_exempt, name='dispatch')
class MovingAveragesView(BaseAPIView):
    """
    API endpoint for dropout moving averages.
    Uses AVG() OVER() with ROWS BETWEEN.
    
    GET /api/analytics/moving-averages/
    Query params:
        - district_id: Filter by district
        - months: Lookback period (default 12)
    """
    
    def get(self, request):
        analytics = DropoutAnalytics()
        
        results = analytics.get_moving_averages(
            district_id=self.get_int_param(request, 'district_id'),
            months=self.get_int_param(request, 'months', 12)
        )
        
        return JsonResponse({
            'success': True,
            'count': len(results),
            'data': results
        })


@method_decorator(csrf_exempt, name='dispatch')
class DropoutReasonsView(BaseAPIView):
    """
    API endpoint for dropout reason analysis.
    Uses RANK(), DENSE_RANK(), and cumulative calculations.
    
    GET /api/analytics/reasons/
    Query params:
        - academic_year: Filter by year
    """
    
    def get(self, request):
        analytics = DropoutAnalytics()
        
        results = analytics.get_reason_rankings(
            academic_year=self.get_int_param(request, 'academic_year')
        )
        
        return JsonResponse({
            'success': True,
            'count': len(results),
            'data': results
        })


@method_decorator(csrf_exempt, name='dispatch')
class DistrictSummaryView(BaseAPIView):
    """
    API endpoint for district-level summary.
    Shows districts with state rankings and risk quintiles.
    
    GET /api/districts/summary/
    """
    
    def get(self, request):
        analytics = DropoutAnalytics()
        results = analytics.get_district_summary()
        
        return JsonResponse({
            'success': True,
            'count': len(results),
            'data': results
        })


@method_decorator(csrf_exempt, name='dispatch')
class EarlyWarningView(BaseAPIView):
    """
    API endpoint for early warning alerts.
    Calls the fn_early_warning_alerts stored function.
    
    GET /api/alerts/early-warning/
    Query params:
        - school_id: Filter by school
        - days_lookback: Days to look back (default 30)
    """
    
    def get(self, request):
        analytics = DropoutAnalytics()
        
        results = analytics.call_early_warning_alerts(
            school_id=self.get_int_param(request, 'school_id'),
            days_lookback=self.get_int_param(request, 'days_lookback', 30)
        )
        
        return JsonResponse({
            'success': True,
            'count': len(results),
            'data': results
        })


@method_decorator(csrf_exempt, name='dispatch')
class HealthCheckView(View):
    """Health check endpoint."""
    
    def get(self, request):
        from django.db import connection
        
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
            db_status = "healthy"
        except Exception as e:
            db_status = f"error: {str(e)}"
        
        return JsonResponse({
            'status': 'ok' if db_status == 'healthy' else 'degraded',
            'database': db_status,
            'service': 'education_dropout_forecaster'
        })
