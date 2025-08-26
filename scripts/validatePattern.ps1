param(
    [Parameter(Mandatory=$true)]
    [string]$YamlFilePath
)

$moduleName = "regex"

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Level,
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $levelPadded = $Level.ToUpper().PadRight(7)
    $modulePadded = $moduleName.PadRight(0)
    
    # Write colored level
    Write-Host -NoNewline "["
    if ($Level -eq "ERROR") {
        Write-Host -NoNewline $levelPadded -ForegroundColor Red
    }
    elseif ($Level -eq "SUCCESS") {
        Write-Host -NoNewline $levelPadded -ForegroundColor Green
    }
    elseif ($Level -eq "INFO") {
        Write-Host -NoNewline $levelPadded -ForegroundColor Cyan
    }
    else {
        Write-Host -NoNewline $levelPadded
    }
    Write-Host -NoNewline "] "
    
    # Write grey timestamp
    Write-Host -NoNewline "[$timestamp] " -ForegroundColor DarkGray
    
    # Write module and message in normal color
    Write-Host "[$modulePadded] $Message"
}

try {
    # Check if file exists
    if (-not (Test-Path $YamlFilePath)) {
        Write-Log -Level "ERROR" -Message "YAML file not found: $YamlFilePath"
        exit 1
    }

    # Read YAML content
    $yamlContent = Get-Content -Path $YamlFilePath -Raw

    # Extract pattern field from YAML
    $patternMatch = [regex]::Match($yamlContent, 'pattern:\s*(.+)')
    $pattern = $patternMatch.Groups[1].Value.Trim()
    
    Write-Log -Level "INFO" -Message "Found pattern: $pattern"
    
    # Validate the pattern against .NET regex engine
    try {
        $regex = New-Object System.Text.RegularExpressions.Regex($pattern)
        Write-Log -Level "SUCCESS" -Message "Valid regex pattern"
        exit 0
    }
    catch {
        Write-Log -Level "ERROR" -Message "Pattern validation failed: $_"
        exit 1
    }
}
catch {
    Write-Log -Level "ERROR" -Message "Script execution failed: $_"
    exit 1
}