param()

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Level,
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    
    if ($Level -eq "ERROR") {
        Write-Host "ERROR: $Message" -ForegroundColor Red
    }
    elseif ($Level -eq "SUCCESS") {
        Write-Host "$Message" -ForegroundColor Green
    }
    elseif ($Level -eq "INFO") {
        Write-Host "$Message"
    }
}

# Get all pattern files
$patternFiles = @()
$patternFiles += Get-ChildItem -Path "regex_patterns" -Filter "*.yml" -File
$patternFiles += Get-ChildItem -Path "regex_patterns" -Filter "*.yaml" -File

if ($patternFiles.Count -eq 0) {
    Write-Log -Level "ERROR" -Message "No pattern files found in regex_patterns/"
    exit 1
}

Write-Log -Level "INFO" -Message "Found $($patternFiles.Count) pattern files to validate"

# Validate patterns sequentially
$failedPatterns = @()
$completed = 0
$totalFiles = $patternFiles.Count
$lastPercentLogged = 0

foreach ($file in $patternFiles) {
    try {
        # Read YAML content
        $yamlContent = Get-Content -Path $file.FullName -Raw
        
        # Extract pattern field
        $patternMatch = [regex]::Match($yamlContent, 'pattern:\s*(.+)')
        $pattern = $patternMatch.Groups[1].Value.Trim()
        
        # Validate the pattern
        $regex = New-Object System.Text.RegularExpressions.Regex($pattern)
        
        # Success - no need to log
    }
    catch {
        $failedPatterns += @{
            File = $file.FullName
            Error = $_.ToString()
            Pattern = $pattern
        }
    }
    
    $completed++
    
    # Log progress every 10%
    $percentComplete = [math]::Floor(($completed / $totalFiles) * 10) * 10
    if ($percentComplete -gt $lastPercentLogged) {
        Write-Log -Level "INFO" -Message "$percentComplete% complete ($completed/$totalFiles files)"
        $lastPercentLogged = $percentComplete
    }
}

# Log errors
foreach ($failure in $failedPatterns) {
    Write-Log -Level "ERROR" -Message "$($failure.File): $($failure.Error)"
    if ($Verbose) {
        Write-Log -Level "ERROR" -Message "Pattern was: $($failure.Pattern)"
    }
}

# Summary
if ($failedPatterns.Count -gt 0) {
    Write-Log -Level "ERROR" -Message "$($failedPatterns.Count) pattern(s) failed validation"
    exit 1
}
else {
    Write-Log -Level "SUCCESS" -Message "All $($patternFiles.Count) patterns validated successfully"
    exit 0
}