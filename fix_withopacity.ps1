$ErrorActionPreference = "Stop"

# Files to process
$files = @(
    "lib\shared\widgets\sync_status_indicator.dart",
    "lib\shared\layouts\main_layout.dart",
    "lib\features\teachers\teacher_students_screen.dart",
    "lib\features\students\student_profile_screen.dart",
    "lib\features\students\student_admission_screen.dart",
    "lib\features\students\student_import_dialog.dart",
    "lib\features\students\students_screen.dart",
    "lib\features\staff\staff_screen.dart",
    "lib\features\staff\staff_admission_screen.dart",
    "lib\features\finance\fees_screen.dart",
    "lib\features\finance\finance_analytics_screen.dart",
    "lib\features\finance\expense_tracker_screen.dart",
    "lib\features\parents\parent_dashboard_screen.dart",
    "lib\features\dashboard\widgets\stat_card.dart",
    "lib\features\dashboard\widgets\revenue_chart.dart",
    "lib\features\dashboard\dashboard_screen.dart",
    "lib\features\dashboard\activity_logs_screen.dart",
    "lib\features\exams\question_bank_screen.dart",
    "lib\features\auth\login_screen.dart",
    "lib\features\auth\institutional_registration_screen.dart",
    "lib\features\attendance\attendance_screen.dart",
    "lib\features\assessments\assessment_screen.dart",
    "lib\features\academic\classes_screen.dart",
    "lib\features\academic\subjects_screen.dart"
)

$replacementCount = 0

foreach ($file in $files) {
    $fullPath = Join-Path $PSScriptRoot $file
    if (Test-Path $fullPath) {
        $content = Get-Content $fullPath -Raw -Encoding UTF8
        $originalContent = $content
        
        # Replace .withOpacity( with .withValues(alpha: 
        $content = $content -replace '\.withOpacity\(', '.withValues(alpha: '
        
        if ($content -ne $originalContent) {
            Set-Content $fullPath -Value $content -Encoding UTF8 -NoNewline
            $fileReplacements = ([regex]::Matches($originalContent, '\.withOpacity\(')).Count
            $replacementCount += $fileReplacements
            Write-Host "[OK] Updated $file ($fileReplacements replacements)"
        }
    } else {
        Write-Host "[WARN] File not found: $file" -ForegroundColor Yellow
    }
}

Write-Host "`n[OK] Total replacements: $replacementCount" -ForegroundColor Green
