
function Wait-ProbeDelay {
    param(
        [int]$Delay,
        [int]$Jitter
    )

    if ($Delay -le 0) { return }

    $jitterRange = [int]($Delay * ($Jitter / 100.0))
    $min = [Math]::Max(1, $Delay - $jitterRange)
    $max = $Delay + $jitterRange
    $actual = Get-Random -Minimum $min -Maximum ($max + 1)

    Write-Host "    waiting ${actual}s..." -ForegroundColor DarkGray -NoNewline
    Start-Sleep -Seconds $actual
    Write-Host "" -ForegroundColor DarkGray
}
