
$manifest = Import-PowerShellDataFile "$PSScriptRoot\CAPO.psd1"
$version = $manifest.ModuleVersion

$banner = @"

   ___    _    ___  ___
  / __|  /_\  | _ \/ _ \
 | (__  / _ \ |  _/ (_) |
  \___|/_/ \_\|_|  \___/

  Conditional Access Probing Operations
  Version $version
  by Edrian Miranda aka ObiKuro

"@

Write-Host $banner -ForegroundColor DarkCyan
Write-Host ("-" * 60) -ForegroundColor DarkCyan


# --- Dot-source modules ---

$modulesPath = Join-Path -Path $PSScriptRoot -ChildPath 'modules'
$scripts = Get-ChildItem -Path "$modulesPath\*.ps1" -ErrorAction SilentlyContinue
foreach ($script in $scripts) {
    try { . $script.FullName }
    catch { Write-Error "Failed to import $($script.FullName): $_" }
}


# =====================================================================
#  DICTIONARIES
# =====================================================================

# Resources - v1 audience URLs for ROPC probing
$CAPOResources = [ordered]@{
    'Microsoft Graph'    = 'https://graph.microsoft.com'
    'Azure Management'   = 'https://management.azure.com'
    'Core Management'    = 'https://management.core.windows.net'
    'Outlook'            = 'https://outlook.office365.com'
    'Office Apps'        = 'https://officeapps.live.com'
    'Office Management'  = 'https://manage.office.com'
    'Azure Key Vault'    = 'https://vault.azure.net'
    'Teams'              = 'https://api.spaces.skype.com'
    'Database'           = 'https://database.windows.net'
    'OneNote'            = 'https://onenote.com'
    'Azure Data Catalog' = 'https://datacatalog.azure.com'
    'Cloud Webapp Proxy' = 'https://proxy.cloudwebappproxy.net/registerapp'
    'Intune MAM'         = 'https://msmamservice.api.application'
    'Outlook SDF'        = 'https://outlook-sdf.office.com'
    'Sara Diagnostics'   = 'https://api.diagnostics.office.com'
    'Skype For Business' = 'https://api.skypeforbusiness.com'
    'Webshell Suite'     = 'https://webshell.suite.office.com'
    'Yammer'             = 'https://api.yammer.com'
    'Azure Graph'        = 'https://graph.windows.net'
}

$DefaultResources = [ordered]@{
    'Microsoft Graph'   = 'https://graph.microsoft.com'
    'Azure Management'  = 'https://management.azure.com'
    'Core Management'   = 'https://management.core.windows.net'
    'Outlook'           = 'https://outlook.office365.com'
    'Office Apps'       = 'https://officeapps.live.com'
    'Office Management' = 'https://manage.office.com'
    'Azure Key Vault'   = 'https://vault.azure.net'
    'Teams'             = 'https://api.spaces.skype.com'
    'Database'          = 'https://database.windows.net'
    'OneNote'           = 'https://onenote.com'
    'Intune MAM'        = 'https://msmamservice.api.application'
    'Yammer'            = 'https://api.yammer.com'
}

# Client IDs - curated first-party apps (FOCI + high-value non-FOCI)
$CAPOClientIDs = [ordered]@{
    'Microsoft Office'            = 'd3590ed6-52b3-4102-aeff-aad2292ab01c'
    'Outlook Mobile'              = '27922004-5251-4030-b22d-91ecd9a37ea4'
    'Microsoft Teams'             = '1fec8e78-bce4-4aaf-ab1b-5451cc387264'
    'OneDrive'                    = 'b26aadf8-566f-4478-926f-589f601d9c74'
    'SharePoint'                  = 'd326c1ce-6cc6-4de2-bebc-4591e5e13ef0'
    'Microsoft Edge'              = 'e9c51622-460d-4d3d-952d-966a5b1da34c'
    'Azure CLI'                   = '04b07795-8ddb-461a-bbee-02f9e1bf7b46'
    'Azure PowerShell'            = '1950a258-227b-4e31-a9cf-717495945fc2'
    'Visual Studio'               = '872cd9fa-d31f-45e0-9eab-6e460a02d1f1'
    'Intune Company Portal'       = '9ba1a5c7-f17a-4de9-a1f1-6178c8d51223'
    'OneDrive SyncEngine'         = 'ab9b8c07-8f02-4f72-87fa-80105867a763'
    'PowerApps'                   = '4e291c71-d680-4d0e-9640-0a3358e31177'
    'Microsoft Flow'              = '57fcbcfa-7cee-4eb1-8b25-12d2030b4ee0'
    'Microsoft Authenticator'     = '4813382a-8fa7-425e-ab75-3b753aab3abb'
    'Power BI'                    = 'c0d2a505-13b8-4ae0-aa9e-cddd5eab0b12'
    'Microsoft Planner'           = '66375f6b-983f-4c2c-9701-d680650f588f'
    'Microsoft To-Do'             = '22098786-6e16-43cc-a27d-191a01a1e3b5'
    'Microsoft Whiteboard'        = '57336123-6e14-4acc-8dcf-287b6088aa28'
    'SharePoint Android'          = 'f05ff7c9-f75a-4acd-a3b5-f4b6a870245d'
    'Office 365 Exchange Online'  = '00000002-0000-0ff1-ce00-000000000000'
    'Microsoft Defender Platform' = 'cab96880-db5b-4e15-90a7-f3f1d62ffe39'
    'Microsoft Defender Mobile'   = 'dd47d17a-3194-4d86-bfd5-c6ae6f5651e3'
    'Outlook Lite'                = 'e9b154d0-7658-433b-bb25-6b8e0a8a7c59'
    'Microsoft Tunnel'            = 'eb539595-3fe1-474e-9c1d-feb3625d1be5'
    'Microsoft Edge 2'            = 'ecd6b820-32c2-49b6-98a6-444530e5a77a'
    'M365 Compliance Drive'       = 'be1918be-3fe3-4be9-b32b-b542fc27f02e'
    'Microsoft Stream Mobile'     = '844cca35-0656-46ce-b636-13f48b0eecbd'
    'Intune MAM Client'           = '6c7e8096-f593-4d72-807f-a5f86dcc9c77'
    'Office UWP PWA'              = '0ec893e0-5785-4de6-99da-4ed124e5296c'
    'Microsoft Bing Search'       = 'cf36b471-5b44-428c-9ce7-313bf84528de'
    'Device Registration Client'  = 'dd762716-544d-4aeb-a526-687b73838a22'
}

$DefaultClientIDs = [ordered]@{
    'Microsoft Office'            = 'd3590ed6-52b3-4102-aeff-aad2292ab01c'
    'Outlook Mobile'              = '27922004-5251-4030-b22d-91ecd9a37ea4'
    'Microsoft Teams'             = '1fec8e78-bce4-4aaf-ab1b-5451cc387264'
    'OneDrive'                    = 'b26aadf8-566f-4478-926f-589f601d9c74'
    'SharePoint'                  = 'd326c1ce-6cc6-4de2-bebc-4591e5e13ef0'
    'Microsoft Edge'              = 'e9c51622-460d-4d3d-952d-966a5b1da34c'
    'Azure CLI'                   = '04b07795-8ddb-461a-bbee-02f9e1bf7b46'
    'Azure PowerShell'            = '1950a258-227b-4e31-a9cf-717495945fc2'
    'Visual Studio'               = '872cd9fa-d31f-45e0-9eab-6e460a02d1f1'
    'Intune Company Portal'       = '9ba1a5c7-f17a-4de9-a1f1-6178c8d51223'
    'PowerApps'                   = '4e291c71-d680-4d0e-9640-0a3358e31177'
    'Microsoft Authenticator'     = '4813382a-8fa7-425e-ab75-3b753aab3abb'
    'Power BI'                    = 'c0d2a505-13b8-4ae0-aa9e-cddd5eab0b12'
    'Office 365 Exchange Online'  = '00000002-0000-0ff1-ce00-000000000000'
    'Microsoft Defender Platform' = 'cab96880-db5b-4e15-90a7-f3f1d62ffe39'
}

# User Agents 
$CAPOUserAgents = [ordered]@{
    'Windows10Chrome'  = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
    'Windows10Edge'    = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0'
    'Windows10Firefox' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0'
    'MacOSSafari'      = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15'
    'MacOSChrome'      = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
    'LinuxFirefox'     = 'Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0'
    'AndroidChrome'    = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36'
    'iOSSafari'        = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1'
    'ChromeOS'         = 'Mozilla/5.0 (X11; CrOS x86_64 14541.0.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
    'WindowsPhone'     = 'Mozilla/5.0 (Windows Phone 10.0; Android 6.0.1; Microsoft; Lumia 950) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/52.0.2743.116 Mobile Safari/537.36 Edge/15.15254'
    'PlayStation5'     = 'Mozilla/5.0 (PlayStation; PlayStation 5/2.26) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0 Safari/605.1.15'
    'NintendoSwitch'   = 'Mozilla/5.0 (Nintendo Switch; WifiWebAuthApplet) AppleWebKit/609.4 (KHTML, like Gecko) NF/6.0.2.21.3 NintendoBrowser/5.1.0.22474'
    'KaiOS'            = 'Mozilla/5.0 (Mobile; rv:48.0) Gecko/48.0 Firefox/48.0 KAIOS/2.5'
}


# =====================================================================
#  LISTING FUNCTIONS
# =====================================================================

function Show-CAPOResources {
    Write-Host "`nAvailable resources:" -ForegroundColor Cyan
    $maxLen = ($CAPOResources.Keys | Measure-Object -Maximum -Property Length).Maximum
    foreach ($key in $CAPOResources.Keys) {
        $isDefault = $DefaultResources.Contains($key)
        $marker = if ($isDefault) { "*" } else { " " }
        Write-Host "  $marker $($key.PadRight($maxLen))  $($CAPOResources[$key])" -ForegroundColor $(if ($isDefault) { 'White' } else { 'DarkGray' })
    }
    Write-Host "`n  * = included in default scan" -ForegroundColor DarkGray
}

function Show-CAPOClients {
    Write-Host "`nAvailable client IDs:" -ForegroundColor Cyan
    $maxLen = ($CAPOClientIDs.Keys | Measure-Object -Maximum -Property Length).Maximum
    foreach ($key in $CAPOClientIDs.Keys) {
        $isDefault = $DefaultClientIDs.Contains($key)
        $marker = if ($isDefault) { "*" } else { " " }
        Write-Host "  $marker $($key.PadRight($maxLen))  $($CAPOClientIDs[$key])" -ForegroundColor $(if ($isDefault) { 'White' } else { 'DarkGray' })
    }
    Write-Host "`n  * = included in default scan" -ForegroundColor DarkGray
}

function Show-CAPOUserAgents {
    Write-Host "`nAvailable user agents:" -ForegroundColor Cyan
    $maxLen = ($CAPOUserAgents.Keys | Measure-Object -Maximum -Property Length).Maximum
    foreach ($key in $CAPOUserAgents.Keys) {
        Write-Host "  $($key.PadRight($maxLen))  $($CAPOUserAgents[$key])" -ForegroundColor White
    }
}


# =====================================================================
#  MAIN FUNCTION
# =====================================================================

function Invoke-CAPO {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$TenantID,

        [Parameter()]
        [string]$Domain,

        [Parameter(Mandatory)]
        [string]$Username,

        [Parameter(Mandatory)]
        [string]$Password,

        # Scope control
        [string[]]$Resources,
        [string[]]$ClientIDs,
        [switch]$FullScope,
        [switch]$SweepUserAgents,

        # User-Agent (when not sweeping)
        [string]$UserAgent,

        [ValidateSet(
            'Windows10Chrome', 'Windows10Edge', 'Windows10Firefox',
            'MacOSSafari', 'MacOSChrome', 'LinuxFirefox',
            'AndroidChrome', 'iOSSafari', 'ChromeOS', 'WindowsPhone',
            'PlayStation5', 'NintendoSwitch', 'KaiOS'
        )]
        [string]$PredefinedUserAgent,

        # Pacing
        [int]$Delay = 10,

        [ValidateRange(0, 100)]
        [int]$Jitter = 50,

        # Safety
        [int]$Safe = 1,

        # Output
        [string]$OutputPath,
        [switch]$Decode,
        [switch]$ShowTokens,

        # Network
        [string]$Proxy
    )

    # --- Resolve TenantID ---
    if (-not $TenantID -and -not $Domain) {
        Write-Host "[!] Either -TenantID or -Domain is required." -ForegroundColor Red
        return
    }
    if ($Domain -and -not $TenantID) {
        $TenantID = Resolve-TenantID -Domain $Domain -Proxy $Proxy
        if (-not $TenantID) { return }
    }

    # --- Resolve resources (explicit -Resources wins over -FullScope) ---
    $resMap = [ordered]@{}
    if ($Resources) {
        foreach ($r in $Resources) {
            $entry = Resolve-DictionaryEntry -Entry $r -Dictionary $CAPOResources
            $resMap[$entry.Name] = $entry.Value
        }
    }
    elseif ($FullScope) {
        foreach ($k in $CAPOResources.Keys) { $resMap[$k] = $CAPOResources[$k] }
    }
    else {
        foreach ($k in $DefaultResources.Keys) { $resMap[$k] = $DefaultResources[$k] }
    }

    # --- Resolve client IDs (explicit -ClientIDs wins over -FullScope) ---
    $cliMap = [ordered]@{}
    if ($ClientIDs) {
        foreach ($c in $ClientIDs) {
            $entry = Resolve-DictionaryEntry -Entry $c -Dictionary $CAPOClientIDs
            $cliMap[$entry.Name] = $entry.Value
        }
    }
    elseif ($FullScope) {
        foreach ($k in $CAPOClientIDs.Keys) { $cliMap[$k] = $CAPOClientIDs[$k] }
    }
    else {
        foreach ($k in $DefaultClientIDs.Keys) { $cliMap[$k] = $DefaultClientIDs[$k] }
    }

    # --- Resolve user agents ---
    $uaMap = [ordered]@{}
    if ($SweepUserAgents) {
        foreach ($k in $CAPOUserAgents.Keys) { $uaMap[$k] = $CAPOUserAgents[$k] }
    }
    elseif ($PredefinedUserAgent) {
        $uaMap[$PredefinedUserAgent] = $CAPOUserAgents[$PredefinedUserAgent]
    }
    elseif ($UserAgent) {
        $uaMap['Custom'] = $UserAgent
    }
    else {
        $uaMap['Windows10Chrome'] = $CAPOUserAgents['Windows10Chrome']
    }

    # --- Build combination matrix ---
    $combos = [System.Collections.ArrayList]::new()
    foreach ($resKey in $resMap.Keys) {
        foreach ($cliKey in $cliMap.Keys) {
            foreach ($uaKey in $uaMap.Keys) {
                [void]$combos.Add(@{
                        ResourceName = $resKey
                        ResourceURL  = $resMap[$resKey]
                        ClientName   = $cliKey
                        ClientGUID   = $cliMap[$cliKey]
                        UAName       = $uaKey
                        UAString     = $uaMap[$uaKey]
                    })
            }
        }
    }

    $totalCombos = $combos.Count
    Write-Host ""
    Write-Host "[*] Target:     $Username @ $TenantID" -ForegroundColor White
    Write-Host "[*] Resources:  $($resMap.Count)" -ForegroundColor White
    Write-Host "[*] Clients:    $($cliMap.Count)" -ForegroundColor White
    Write-Host "[*] User Agents: $($uaMap.Count)$(if ($SweepUserAgents) {' (sweep)'})" -ForegroundColor White
    Write-Host "[*] Total probes: $totalCombos" -ForegroundColor White
    Write-Host "[*] Pacing:     ${Delay}s base delay, ${Jitter}% jitter" -ForegroundColor White

    $estMin = [Math]::Round(($totalCombos * $Delay) / 60, 1)
    Write-Host "[*] Estimated time: ~${estMin} minutes" -ForegroundColor DarkGray
    Write-Host ""

    # --- Test authentication ---
    Write-Host "[*] Validating credentials..." -ForegroundColor Yellow
    $testResult = Send-ROPCProbe `
        -TenantID $TenantID `
        -Username $Username `
        -Password $Password `
        -ResourceName 'Microsoft Graph' `
        -ResourceURL 'https://graph.microsoft.com' `
        -ClientName 'Microsoft Office' `
        -ClientGUID 'd3590ed6-52b3-4102-aeff-aad2292ab01c' `
        -UAName 'Windows10Chrome' `
        -UAString $CAPOUserAgents['Windows10Chrome'] `
        -Proxy $Proxy

    switch ($testResult.Status) {
        'GAP' { Write-Host "[+] Credentials valid - token issued (gap on test combo)" -ForegroundColor Green }
        'MFA Required' { Write-Host "[+] Credentials valid - MFA enforced on test combo" -ForegroundColor Green }
        'MFA Not Setup' { Write-Host "[+] Credentials valid - MFA not configured" -ForegroundColor Green }
        'CA Blocked' { Write-Host "[+] Credentials valid - CA blocked on test combo" -ForegroundColor Green }
        'External MFA' { Write-Host "[+] Credentials valid - external MFA on test combo" -ForegroundColor Green }
        'App CA Blocked' { Write-Host "[+] Credentials valid - app CA blocked on test combo" -ForegroundColor Green }
        'Device Required' { Write-Host "[+] Credentials valid - device required on test combo" -ForegroundColor Green }
        'Expired' { Write-Host "[+] Credentials valid - password expired" -ForegroundColor Yellow }
        'Wrong Password' {
            Write-Host "[!] Wrong password - aborting." -ForegroundColor Red
            return
        }
        'No User' {
            Write-Host "[!] User not found - aborting." -ForegroundColor Red
            return
        }
        'Disabled' {
            Write-Host "[!] Account disabled - aborting." -ForegroundColor Red
            return
        }
        'LOCKED' {
            Write-Host "[!] Account locked or IP burned - aborting." -ForegroundColor Red
            return
        }
        default {
            Write-Host "[?] Test auth returned: $($testResult.Status) - $($testResult.Detail)" -ForegroundColor Yellow
            Write-Host "    Proceeding with caution..." -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "[*] Starting probe sweep..." -ForegroundColor Cyan
    Write-Host ""

    # --- Run probes ---
    $results = [System.Collections.ArrayList]::new()
    $lockCount = 0
    $index = 0

    foreach ($combo in $combos) {
        $index++

        if ($index -gt 1) {
            Wait-ProbeDelay -Delay $Delay -Jitter $Jitter
        }

        $result = Send-ROPCProbe `
            -TenantID    $TenantID `
            -Username    $Username `
            -Password    $Password `
            -ResourceName $combo.ResourceName `
            -ResourceURL  $combo.ResourceURL `
            -ClientName   $combo.ClientName `
            -ClientGUID   $combo.ClientGUID `
            -UAName       $combo.UAName `
            -UAString     $combo.UAString `
            -Proxy        $Proxy

        [void]$results.Add($result)
        Write-ProbeResult -Result $result -Index $index -Total $totalCombos

        if ($Decode -and $result.Status -eq 'GAP' -and $result.TokenData.access_token) {
            Write-Host "    Decoded token:" -ForegroundColor DarkGreen
            $tokenParts = $result.TokenData.access_token.Split('.')
            if ($tokenParts.Count -ge 2) {
                $padded = $tokenParts[1].Replace('-', '+').Replace('_', '/')
                while ($padded.Length % 4) { $padded += '=' }
                try {
                    $payload = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($padded)) | ConvertFrom-Json
                    $payload | Format-List | Out-String | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGreen }
                }
                catch {}
            }
        }

        # Safety check
        if ($result.Status -eq 'LOCKED') {
            $lockCount++
            if ($lockCount -ge $Safe) {
                Write-Host ""
                Write-Host "[!] Reached lockout threshold ($Safe) - aborting sweep." -ForegroundColor Red
                break
            }
        }
    }

    # --- Mask tokens unless -ShowTokens ---
    if (-not $ShowTokens) {
        foreach ($r in $results) {
            if ($r.TokenData) {
                $r.TokenData = [PSCustomObject]@{
                    access_token  = '[MASKED - use -ShowTokens to reveal]'
                    refresh_token = '[MASKED - use -ShowTokens to reveal]'
                    token_type    = $r.TokenData.token_type
                    expires_in    = $r.TokenData.expires_in
                    resource      = $r.TokenData.resource
                }
            }
        }
    }

    # --- Summary ---
    Show-ProbeSummary -Results $results.ToArray() -Username $Username -ShowTokens:$ShowTokens

    # --- Export ---
    if ($OutputPath) {
        Export-ProbeReport -Results $results.ToArray() -OutputPath $OutputPath -ShowTokens:$ShowTokens
    }

    # --- Return results for pipeline ---
    return $results.ToArray()
}


# =====================================================================
#  TAB COMPLETION
# =====================================================================

Register-ArgumentCompleter -CommandName Invoke-CAPO -ParameterName Resources -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $CAPOResources.Keys | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        $quoted = if ($_ -match '\s') { "'$_'" } else { $_ }
        [System.Management.Automation.CompletionResult]::new($quoted, $_, 'ParameterValue', $CAPOResources[$_])
    }
}.GetNewClosure()

Register-ArgumentCompleter -CommandName Invoke-CAPO -ParameterName ClientIDs -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $CAPOClientIDs.Keys | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        $quoted = if ($_ -match '\s') { "'$_'" } else { $_ }
        [System.Management.Automation.CompletionResult]::new($quoted, $_, 'ParameterValue', $CAPOClientIDs[$_])
    }
}.GetNewClosure()

Register-ArgumentCompleter -CommandName Invoke-CAPO -ParameterName PredefinedUserAgent -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $CAPOUserAgents.Keys | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $CAPOUserAgents[$_])
    }
}.GetNewClosure()

Export-ModuleMember -Function Invoke-CAPO, Show-CAPOResources, Show-CAPOClients, Show-CAPOUserAgents, Resolve-TenantID
