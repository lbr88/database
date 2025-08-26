param(
    [string]$YamlFilePath
)

# Function to run tests for a single file
function Test-Pattern {
    param([string]$FilePath)
    
    $fileName = (Get-Item $FilePath).BaseName
    
    try {
        # Read YAML content
        $yamlContent = Get-Content -Path $FilePath -Raw
        
        # Extract pattern
        $patternMatch = [regex]::Match($yamlContent, 'pattern:\s*(.+)')
        $pattern = $patternMatch.Groups[1].Value.Trim()
        
        # Create regex object with case-insensitive and multiline options
        $regexOptions = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Multiline
        $regex = New-Object System.Text.RegularExpressions.Regex($pattern, $regexOptions)
        
        # Extract tests
        $testsSection = [regex]::Match($yamlContent, '(?s)tests:(.*?)(?:\n\w|\z)').Groups[1].Value
        
        if ([string]::IsNullOrWhiteSpace($testsSection)) {
            return @{
                File = $fileName
                Passed = 0
                Failed = 0
                Total = 0
            }
        }
        
        # Parse each test
        $tests = [regex]::Matches($testsSection, '(?s)- expected:\s*(true|false).*?input:\s*(.+?)(?=\n\s*\w|\n-|\z)')
        
        $passed = 0
        $failed = 0
        $failureDetails = @()
        
        foreach ($test in $tests) {
            $expected = $test.Groups[1].Value -eq 'true'
            $input = $test.Groups[2].Value.Trim()
            
            # Run the test
            $matches = $regex.IsMatch($input)
            
            if ($matches -eq $expected) {
                $passed++
            }
            else {
                $failed++
                $failureDetails += "    Input: '$input' - Expected: $expected, Got: $matches"
            }
        }
        
        return @{
            File = $fileName
            Passed = $passed
            Failed = $failed
            Total = $tests.Count
            Failures = $failureDetails
        }
    }
    catch {
        return @{
            File = $fileName
            Error = $_.Exception.Message
        }
    }
}

# Main execution
if ($YamlFilePath) {
    # Test single file
    $result = Test-Pattern -FilePath $YamlFilePath
    
    if ($result.Error) {
        Write-Host "ERROR: $($result.File): $($result.Error)" -ForegroundColor Red
        exit 1
    }
    
    if ($result.Failed -gt 0) {
        Write-Host "$($result.File): $($result.Failed)/$($result.Total) tests failed" -ForegroundColor Red
        foreach ($failure in $result.Failures) {
            Write-Host $failure
        }
        exit 1
    }
    else {
        Write-Host "$($result.File): All $($result.Total) tests passed"
        exit 0
    }
}
else {
    # Test all files
    $patternFiles = @()
    $patternFiles += Get-ChildItem -Path "regex_patterns" -Filter "*.yml" -File
    $patternFiles += Get-ChildItem -Path "regex_patterns" -Filter "*.yaml" -File
    
    if ($patternFiles.Count -eq 0) {
        Write-Host "No pattern files found"
        exit 1
    }
    
    $results = @()
    $totalFiles = $patternFiles.Count
    $filesWithFailures = @()
    
    foreach ($file in $patternFiles) {
        $result = Test-Pattern -FilePath $file.FullName
        $results += $result
        
        if ($result.Error) {
            $filesWithFailures += $result
        }
        elseif ($result.Failed -gt 0) {
            $filesWithFailures += $result
        }
    }
    
    # Report failures
    if ($filesWithFailures.Count -gt 0) {
        Write-Host "ERRORS:"
        
        # Find global max input length across all failures
        $globalMaxInputLength = 0
        foreach ($failure in $filesWithFailures) {
            if (-not $failure.Error) {
                foreach ($detail in $failure.Failures) {
                    if ($detail -match "Input: '(.+?)' -") {
                        $inputLength = $matches[1].Length
                        if ($inputLength -gt $globalMaxInputLength) {
                            $globalMaxInputLength = $inputLength
                        }
                    }
                }
            }
        }
        
        # Limit padding to 150 characters
        if ($globalMaxInputLength -gt 150) {
            $globalMaxInputLength = 150
        }
        
        foreach ($failure in $filesWithFailures) {
            Write-Host "  $($failure.File):"
            
            if ($failure.Error) {
                # Extract cleaner error message
                $errorMsg = $failure.Error
                if ($errorMsg -match "at offset (\d+)\. (.+?)\.?`"") {
                    $errorMsg = "offset $($matches[1]): $($matches[2])"
                }
                Write-Host "    $errorMsg"
            }
            else {
                foreach ($detail in $failure.Failures) {
                    if ($detail -match "Input: '(.+?)' - Expected: (\w+), Got: (\w+)") {
                        $input = $matches[1]
                        $expected = $matches[2]
                        $got = $matches[3]
                        
                        # Truncate only if longer than 150
                        if ($input.Length -gt 150) {
                            $input = $input.Substring(0, 147) + "..."
                        }
                        
                        $paddedInput = $input.PadRight($globalMaxInputLength)
                        Write-Host "    $paddedInput | Expected: $expected | Got: $got"
                    }
                }
            }
        }
        
        exit 1
    }
    else {
        Write-Host "All tests passed"
        exit 0
    }
}