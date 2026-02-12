"""
Models for Education Dropout Forecaster
These models represent the database schema for analytics queries.
Note: We use managed=False since the database is managed by raw SQL migrations.
"""

from django.db import models


class State(models.Model):
    """US State reference table."""
    state_id = models.AutoField(primary_key=True)
    state_code = models.CharField(max_length=2, unique=True)
    state_name = models.CharField(max_length=100)
    region = models.CharField(max_length=50, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = 'states'

    def __str__(self):
        return f"{self.state_code} - {self.state_name}"


class District(models.Model):
    """School district."""
    district_id = models.AutoField(primary_key=True)
    district_code = models.CharField(max_length=20, unique=True)
    district_name = models.CharField(max_length=200)
    state = models.ForeignKey(State, on_delete=models.CASCADE, db_column='state_id')
    superintendent = models.CharField(max_length=200, null=True)
    address = models.TextField(null=True)
    phone = models.CharField(max_length=20, null=True)
    email = models.CharField(max_length=255, null=True)
    total_schools = models.IntegerField(default=0)
    total_students = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        managed = False
        db_table = 'districts'

    def __str__(self):
        return self.district_name


class SchoolType(models.Model):
    """School type reference."""
    type_id = models.AutoField(primary_key=True)
    type_code = models.CharField(max_length=20, unique=True)
    type_name = models.CharField(max_length=100)
    description = models.TextField(null=True)

    class Meta:
        managed = False
        db_table = 'school_types'

    def __str__(self):
        return self.type_name


class School(models.Model):
    """School entity."""
    school_id = models.AutoField(primary_key=True)
    school_code = models.CharField(max_length=20, unique=True)
    school_name = models.CharField(max_length=200)
    district = models.ForeignKey(District, on_delete=models.CASCADE, db_column='district_id')
    school_type = models.ForeignKey(SchoolType, on_delete=models.SET_NULL, null=True, db_column='type_id')
    address = models.TextField(null=True)
    city = models.CharField(max_length=100, null=True)
    zip_code = models.CharField(max_length=10, null=True)
    phone = models.CharField(max_length=20, null=True)
    principal = models.CharField(max_length=200, null=True)
    enrollment = models.IntegerField(default=0)
    grade_levels = models.CharField(max_length=20, null=True)
    is_title_i = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    established_year = models.IntegerField(null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        managed = False
        db_table = 'schools'

    def __str__(self):
        return self.school_name


class DropoutReason(models.Model):
    """Dropout reason codes."""
    reason_id = models.AutoField(primary_key=True)
    reason_code = models.CharField(max_length=10, unique=True)
    reason_name = models.CharField(max_length=100)
    description = models.TextField(null=True)
    risk_weight = models.DecimalField(max_digits=3, decimal_places=2, default=0.5)
    is_preventable = models.BooleanField(default=True)
    intervention_type = models.CharField(max_length=50, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = 'dropout_reasons'

    def __str__(self):
        return f"{self.reason_code} - {self.reason_name}"


class Student(models.Model):
    """Student entity - core table for dropout analysis."""
    
    STATUS_CHOICES = [
        ('ACTIVE', 'Currently Enrolled'),
        ('DROPPED', 'Dropped Out'),
        ('GRADUATED', 'Graduated'),
        ('TRANSFERRED', 'Transferred'),
        ('EXPELLED', 'Expelled'),
        ('SUSPENDED', 'Suspended'),
        ('LOA', 'Leave of Absence'),
        ('DECEASED', 'Deceased'),
    ]
    
    student_id = models.AutoField(primary_key=True)
    student_code = models.CharField(max_length=20, unique=True)
    school = models.ForeignKey(School, on_delete=models.CASCADE, db_column='school_id')
    first_name = models.CharField(max_length=100)
    last_name = models.CharField(max_length=100)
    date_of_birth = models.DateField(null=True)
    gender = models.CharField(max_length=10, null=True)
    ethnicity = models.CharField(max_length=50, null=True)
    
    # Academic info
    grade_level = models.IntegerField(null=True)
    academic_year = models.IntegerField()
    enrolled_date = models.DateField()
    
    # Status tracking
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='ACTIVE')
    dropout_date = models.DateField(null=True)
    dropout_reason = models.ForeignKey(DropoutReason, on_delete=models.SET_NULL, null=True, db_column='dropout_reason_id')
    
    # Risk factors
    gpa = models.DecimalField(max_digits=3, decimal_places=2, null=True)
    attendance_rate = models.DecimalField(max_digits=5, decimal_places=2, null=True)
    disciplinary_incidents = models.IntegerField(default=0)
    retained_grade = models.BooleanField(default=False)
    
    # Socioeconomic factors
    free_reduced_lunch = models.BooleanField(default=False)
    english_learner = models.BooleanField(default=False)
    special_education = models.BooleanField(default=False)
    homeless = models.BooleanField(default=False)
    foster_care = models.BooleanField(default=False)
    single_parent_household = models.BooleanField(default=False)
    
    # Contact
    guardian_name = models.CharField(max_length=200, null=True)
    guardian_phone = models.CharField(max_length=20, null=True)
    guardian_email = models.CharField(max_length=255, null=True)
    address = models.TextField(null=True)
    
    # Risk score (calculated)
    risk_score = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    risk_decile = models.IntegerField(null=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        managed = False
        db_table = 'students'

    def __str__(self):
        return f"{self.first_name} {self.last_name} ({self.student_code})"

    @property
    def full_name(self):
        return f"{self.first_name} {self.last_name}"

    @property
    def is_high_risk(self):
        return self.risk_decile is not None and self.risk_decile <= 3


class AnnualSchoolStats(models.Model):
    """Annual aggregated statistics per school."""
    stat_id = models.AutoField(primary_key=True)
    school = models.ForeignKey(School, on_delete=models.CASCADE, db_column='school_id')
    academic_year = models.IntegerField()
    total_enrolled = models.IntegerField(default=0)
    total_dropouts = models.IntegerField(default=0)
    dropout_rate = models.DecimalField(max_digits=5, decimal_places=2, null=True)
    avg_attendance_rate = models.DecimalField(max_digits=5, decimal_places=2, null=True)
    avg_gpa = models.DecimalField(max_digits=3, decimal_places=2, null=True)
    graduation_rate = models.DecimalField(max_digits=5, decimal_places=2, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = 'annual_school_stats'
        unique_together = ('school', 'academic_year')

    def __str__(self):
        return f"{self.school.school_name} - {self.academic_year}"


class DropoutEvent(models.Model):
    """Detailed dropout event tracking."""
    event_id = models.AutoField(primary_key=True)
    student = models.ForeignKey(Student, on_delete=models.CASCADE, db_column='student_id')
    school = models.ForeignKey(School, on_delete=models.CASCADE, db_column='school_id')
    district = models.ForeignKey(District, on_delete=models.CASCADE, db_column='district_id')
    academic_year = models.IntegerField()
    dropout_date = models.DateField()
    reason = models.ForeignKey(DropoutReason, on_delete=models.SET_NULL, null=True, db_column='reason_id')
    grade_level = models.IntegerField(null=True)
    gpa_at_dropout = models.DecimalField(max_digits=3, decimal_places=2, null=True)
    attendance_at_dropout = models.DecimalField(max_digits=5, decimal_places=2, null=True)
    risk_score_at_dropout = models.DecimalField(max_digits=5, decimal_places=2, null=True)
    interventions_received = models.IntegerField(default=0)
    notes = models.TextField(null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = 'dropout_events'

    def __str__(self):
        return f"Dropout: {self.student} on {self.dropout_date}"
