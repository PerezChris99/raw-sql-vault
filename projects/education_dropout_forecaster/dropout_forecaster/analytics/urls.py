"""
URL routing for analytics app
Education Dropout Forecaster API endpoints
"""

from django.urls import path
from . import views

app_name = 'analytics'

urlpatterns = [
    # Health check
    path('health/', views.HealthCheckView.as_view(), name='health'),
    
    # School rankings (core query)
    path('schools/rankings/', views.SchoolRankingsView.as_view(), name='school_rankings'),
    
    # Year-over-year comparison (LAG/LEAD)
    path('analytics/yoy/', views.YearOverYearView.as_view(), name='yoy_comparison'),
    
    # Cumulative dropouts (SUM OVER)
    path('analytics/cumulative/<int:school_id>/', views.CumulativeDropoutsView.as_view(), name='cumulative_dropouts'),
    
    # Moving averages (AVG OVER)
    path('analytics/moving-averages/', views.MovingAveragesView.as_view(), name='moving_averages'),
    
    # Dropout reasons (RANK/DENSE_RANK)
    path('analytics/reasons/', views.DropoutReasonsView.as_view(), name='dropout_reasons'),
    
    # Student risk percentiles (NTILE/PERCENT_RANK)
    path('students/risk-percentiles/', views.RiskPercentilesView.as_view(), name='risk_percentiles'),
    
    # At-risk students
    path('students/at-risk/', views.AtRiskStudentsView.as_view(), name='at_risk_students'),
    
    # District summary
    path('districts/summary/', views.DistrictSummaryView.as_view(), name='district_summary'),
    
    # Early warning alerts
    path('alerts/early-warning/', views.EarlyWarningView.as_view(), name='early_warning'),
]
