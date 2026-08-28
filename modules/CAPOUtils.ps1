
function Resolve-TenantID {
    param(
        [string]$Domain,
        [string]$Proxy
    )

    $url = "https://login.microsoftonline.com/$Domain/.well-known/openid-configuration"
    $webArgs = @{
        Uri             = $url
        UseBasicParsing = $true
        ErrorAction     = 'Stop'
    }
    if ($Proxy) { $webArgs.Proxy = $Proxy }

    try {
        $response = Invoke-WebRequest @webArgs
        $json = $response.Content | ConvertFrom-Json
        $tid = $json.authorization_endpoint.Split('/')[3]
        Write-Host "[+] Resolved tenant ID: $tid" -ForegroundColor Green
        return $tid
    }
    catch {
        Write-Host "[!] Failed to resolve tenant ID for $Domain" -ForegroundColor Red
        return $null
    }
}


function Resolve-DictionaryEntry {
    param(
        [string]$Entry,
        [System.Collections.Specialized.OrderedDictionary]$Dictionary
    )

    if ($Dictionary.Contains($Entry)) {
        return @{ Name = $Entry; Value = $Dictionary[$Entry] }
    }

    foreach ($key in $Dictionary.Keys) {
        if ($Dictionary[$key] -eq $Entry) {
            return @{ Name = $key; Value = $Entry }
        }
    }

    return @{ Name = $Entry; Value = $Entry }
}


function Write-ProbeResult {
    param([PSCustomObject]$Result, [int]$Index, [int]$Total)

    $counter = "[$Index/$Total]".PadRight(10)
    $res     = $Result.Resource.PadRight(22)
    $cli     = $Result.Client.PadRight(28)
    $ua      = $Result.UserAgent.PadRight(16)

    switch ($Result.Status) {
        'GAP' {
            Write-Host "$counter " -NoNewline
            Write-Host "[+] " -ForegroundColor Green -NoNewline
            Write-Host "$res $cli $ua " -NoNewline
            Write-Host "GAP - No MFA!" -ForegroundColor Green
        }
        'MFA Not Setup' {
            Write-Host "$counter " -NoNewline
            Write-Host "[+] " -ForegroundColor Green -NoNewline
            Write-Host "$res $cli $ua " -NoNewline
            Write-Host "MFA not configured!" -ForegroundColor Green
        }
        'MFA Required' {
            Write-Host "$counter " -NoNewline
            Write-Host "[-] " -ForegroundColor Yellow -NoNewline
            Write-Host "$res $cli $ua " -NoNewline
            Write-Host "MFA Required" -ForegroundColor DarkYellow
        }
        'CA Blocked' {
            Write-Host "$counter " -NoNewline
            Write-Host "[-] " -ForegroundColor Yellow -NoNewline
            Write-Host "$res $cli $ua " -NoNewline
            Write-Host "CA Blocked" -ForegroundColor DarkYellow
        }
        'LOCKED' {
            Write-Host "$counter " -NoNewline
            Write-Host "[!] " -ForegroundColor Red -NoNewline
            Write-Host "$res $cli $ua " -NoNewline
            Write-Host "LOCKED - STOP" -ForegroundColor Red
        }
        'Wrong Password' {
            Write-Host "$counter " -NoNewline
            Write-Host "[!] " -ForegroundColor Red -NoNewline
            Write-Host "$res $cli $ua " -NoNewline
            Write-Host "Wrong Password" -ForegroundColor Red
        }
        default {
            Write-Host "$counter " -NoNewline
            Write-Host "[-] " -ForegroundColor DarkGray -NoNewline
            Write-Host "$res $cli $ua " -NoNewline
            Write-Host "$($Result.Status)" -ForegroundColor DarkGray
        }
    }
}


function Get-SATOCommand {
    param([PSCustomObject]$Gap, [string]$Username)

    $scopeMap = @{
        'https://graph.microsoft.com'         = 'MsGraph'
        'https://management.azure.com'        = 'MaARM'
        'https://management.core.windows.net' = 'CoreARM'
        'https://outlook.office365.com'       = 'Outlook'
        'https://officeapps.live.com'         = 'OneDrive'
        'https://manage.office.com'           = 'Office'
        'https://vault.azure.net'             = 'KeyVault'
        'https://api.spaces.skype.com'        = 'MSTeams'
    }

    $satoUAs = @(
        'Windows10Chrome','Windows10Edge','Windows10Firefox',
        'MacOSSafari','MacOSChrome','LinuxFirefox',
        'AndroidChrome','iOSSafari','ChromeOS','WindowsPhone',
        'PlayStation5','NintendoSwitch','KaiOS'
    )

    $scopeParam = if ($scopeMap.ContainsKey($Gap.ResourceURL)) {
        "-PredefinedScope $($scopeMap[$Gap.ResourceURL])"
    } else {
        "-Scope `"$($Gap.ResourceURL)/.default offline_access openid`""
    }

    $uaParam = if ($Gap.UserAgent -in $satoUAs) {
        "-PredefinedUserAgent $($Gap.UserAgent)"
    } else {
        ""
    }

    $cmd = "Invoke-Sato -GrantType password -TenantID <tid> -Username $Username -Password '<pw>' ``"
    $cmd += "`n  -ClientID $($Gap.ClientID) $scopeParam"
    if ($uaParam) { $cmd += " $uaParam" }

    return $cmd
}


function Show-ProbeSummary {
    param(
        [PSCustomObject[]]$Results,
        [string]$Username,
        [switch]$ShowTokens
    )

    $gaps       = @($Results | Where-Object { $_.Status -eq 'GAP' })
    $mfaNotSet  = @($Results | Where-Object { $_.Status -eq 'MFA Not Setup' })
    $mfaBlock   = @($Results | Where-Object { $_.Status -in @('MFA Required','CA Blocked','External MFA','App CA Blocked','Device Required') })
    $credValid  = @($Results | Where-Object { $_.Status -eq 'Expired' })
    $errors     = @($Results | Where-Object { $_.Status -in @('LOCKED','Wrong Password','No User','Disabled','Suspicious','User Blocked') })
    $skipped    = @($Results | Where-Object { $_.Status -in @('Not Authorized','Secret Required','App Disabled','SP Disabled','Resource Off','Bad Client','Bad Resource','No Consent','App CA Blocked') })

    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host "  CAPO PROBE SUMMARY" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Total probes:       $($Results.Count)" -ForegroundColor White
    Write-Host "  Gaps found:         $($gaps.Count)" -ForegroundColor $(if ($gaps.Count -gt 0) { 'Green' } else { 'White' })
    Write-Host "  MFA not configured: $($mfaNotSet.Count)" -ForegroundColor $(if ($mfaNotSet.Count -gt 0) { 'Green' } else { 'White' })
    Write-Host "  MFA/CA enforced:    $($mfaBlock.Count)" -ForegroundColor Yellow
    Write-Host "  Password expired:   $($credValid.Count)" -ForegroundColor $(if ($credValid.Count -gt 0) { 'Yellow' } else { 'White' })
    Write-Host "  Errors/stops:       $($errors.Count)" -ForegroundColor $(if ($errors.Count -gt 0) { 'Red' } else { 'White' })
    Write-Host "  Invalid combos:     $($skipped.Count)" -ForegroundColor DarkGray
    if ($gaps.Count -gt 0 -and -not $ShowTokens) {
        Write-Host "  Token data:         MASKED (use -ShowTokens to include raw tokens)" -ForegroundColor DarkYellow
    }

    if ($gaps.Count -gt 0) {
        Write-Host ""
        Write-Host "  GAPS FOUND - use these with SATO:" -ForegroundColor Green
        Write-Host ("  " + ("-" * 76)) -ForegroundColor Green
        foreach ($gap in $gaps) {
            Write-Host ""
            Write-Host "  Resource:  $($gap.Resource) ($($gap.ResourceURL))" -ForegroundColor White
            Write-Host "  Client:    $($gap.Client) ($($gap.ClientID))" -ForegroundColor White
            Write-Host "  UA:        $($gap.UserAgent)" -ForegroundColor White
            Write-Host "  SATO:" -ForegroundColor DarkGreen
            $cmd = Get-SATOCommand -Gap $gap -Username $Username
            foreach ($line in $cmd.Split("`n")) {
                Write-Host "    $line" -ForegroundColor DarkGreen
            }
        }
    }

    if ($mfaNotSet.Count -gt 0) {
        Write-Host ""
        Write-Host "  MFA NOT CONFIGURED - user can register MFA, then these become gaps:" -ForegroundColor Green
        foreach ($r in $mfaNotSet) {
            Write-Host "    $($r.Resource) x $($r.Client) x $($r.UserAgent)" -ForegroundColor White
        }
    }

    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Cyan
}


function Export-ProbeReport {
    param(
        [PSCustomObject[]]$Results,
        [string]$OutputPath,
        [switch]$ShowTokens
    )

    if ($ShowTokens) {
        $export = foreach ($r in $Results) {
            $row = $r | Select-Object Timestamp, Resource, ResourceURL, Client, ClientID, UserAgent, Status, Code, Detail
            if ($r.TokenData -and $r.TokenData.access_token) {
                $row | Add-Member -NotePropertyName 'AccessToken'  -NotePropertyValue $r.TokenData.access_token  -PassThru |
                       Add-Member -NotePropertyName 'RefreshToken' -NotePropertyValue $r.TokenData.refresh_token -PassThru
            } else { $row }
        }
    } else {
        $export = $Results | Select-Object Timestamp, Resource, ResourceURL, Client, ClientID, UserAgent, Status, Code, Detail
    }

    $export | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Host "[*] Results exported to $OutputPath" -ForegroundColor Cyan
}
