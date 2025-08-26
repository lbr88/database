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

# Validate patterns sequentially
$failedPatterns = @()

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
            File = $file.BaseName
            Error = $_.Exception.Message
        }
    }
}

# Log errors
if ($failedPatterns.Count -gt 0) {
    Write-Host "ERRORS:"
    
    # Find max name length for padding
    $maxNameLength = ($failedPatterns | ForEach-Object { $_.File.Length } | Measure-Object -Maximum).Maximum
    
    foreach ($failure in $failedPatterns) {
        # Extract just the core error
        $errorMsg = $failure.Error
        if ($errorMsg -match "at offset (\d+)\. (.+?)\.?`"") {
            $errorMsg = "offset $($matches[1]): $($matches[2])"
        }
        
        $paddedName = $failure.File.PadRight($maxNameLength)
        Write-Host "  $paddedName | $errorMsg"
    }
    exit 1
}