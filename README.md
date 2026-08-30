```
   ___    _    ___  ___
  / __|  /_\  | _ \/ _ \
 | (__  / _ \ |  _/ (_) |
  \___|/_/ \_\|_|  \___/

  Conditional Access Probing Operations
```

> Automated MFA and Conditional Access gap discovery via ROPC for Microsoft Entra ID

[Quick Start](#quick-start) | [Parameters](#parameters) | [Examples](#usage-examples) | [Dictionaries](#dictionaries) | [How It Works](#how-it-works)

---

## What is CAPO?

CAPO is a PowerShell module that discovers Conditional Access policy gaps in Microsoft Entra ID tenants by probing the Resource Owner Password Credentials (ROPC) flow. It systematically tests combinations of resources, client applications, and user agents to find where MFA enforcement has gaps, excluded cloud apps, unrecognized device platforms, or client app conditions that don't cover ROPC.

CAPO is designed for **authorized penetration testing and red team operations**. It implements low-and-slow pacing with jitter, automatic lockout detection, and safety thresholds to minimize detection risk.

### Key Features

- **Combinatorial probing** — Tests every combination of resource x client x user agent to map the full CA attack surface
- **23 AADSTS error codes parsed** — Distinguishes MFA enforcement, CA blocks, credential issues, consent errors, and client/resource incompatibilities
- **Built-in pacing** — Configurable delay with percentage-based jitter for low-and-slow operation
- **Safety lockout** — Automatically aborts on account lockout signals (configurable threshold)
- **Token masking** — Tokens masked by default in console and CSV output; reveal with `-ShowTokens`
- **JWT decode** — Inline decoded token claims with `-Decode`
- **Tab completion** — Resources, client IDs, and user agents autocomplete on Tab
- **SATO integration** — Generates ready-to-run `Invoke-Sato` commands for every discovered gap
- **CSV export** — Full results with timestamps for reporting
- **Device platform bypass** — Includes ChromeOS and other unrecognized-platform user agents for device condition testing
- **Proxy support** — Route all traffic through a proxy for inspection or Burp

## Installation

```powershell
# Clone or download, then import
Import-Module .\CAPO\CAPO.psd1

# Verify
Show-CAPOResources
Show-CAPOClients
Show-CAPOUserAgents
```

**Requirements:** Windows PowerShell 5.1+ (no additional dependencies)

## Quick Start

```powershell
# Default scan: 12 resources x 15 clients x 1 UA = 180 probes
Invoke-CAPO -Domain contoso.com -Username user@contoso.com -Password 'P@ssw0rd' `
  -Delay 10 -Jitter 50 -OutputPath results.csv

# Targeted scan: specific resource + client
Invoke-CAPO -Domain contoso.com -Username user@contoso.com -Password 'P@ssw0rd' `
  -Resources 'Microsoft Graph' -ClientIDs 'Microsoft Office' -Delay 3 -Jitter 30

# Full scope: all 19 resources x 31 clients = 589 probes
Invoke-CAPO -Domain contoso.com -Username user@contoso.com -Password 'P@ssw0rd' `
  -FullScope -Delay 5 -Jitter 40

# Device platform bypass hunting: sweep all 13 user agents
Invoke-CAPO -Domain contoso.com -Username user@contoso.com -Password 'P@ssw0rd' `
  -Resources 'Microsoft Graph' -ClientIDs 'Microsoft Office' `
  -SweepUserAgents -Delay 3 -Jitter 30
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-TenantID` | string | — | Tenant GUID (provide this or `-Domain`) |
| `-Domain` | string | — | Tenant domain (auto-resolves to tenant ID) |
| `-Username` | string | **required** | UPN of the target account |
| `-Password` | string | **required** | Password for the target account |
| `-Resources` | string[] | 12 defaults | Resource names or URLs to probe |
| `-ClientIDs` | string[] | 15 defaults | Client app names or GUIDs to probe |
| `-FullScope` | switch | off | Expand unspecified dimensions to full dictionary (explicit `-Resources`/`-ClientIDs` take priority) |
| `-SweepUserAgents` | switch | off | Test all 13 user agents per combo |
| `-PredefinedUserAgent` | string | — | Use a single named UA from the dictionary |
| `-UserAgent` | string | — | Use a custom raw UA string |
| `-Delay` | int | 10 | Base seconds between probes |
| `-Jitter` | int | 50 | Jitter percentage (0-100) |
| `-Safe` | int | 1 | Abort after N lockout signals |
| `-OutputPath` | string | — | CSV export path |
| `-Decode` | switch | off | Decode and display JWT claims on GAP |
| `-ShowTokens` | switch | off | Include raw tokens in output (masked by default) |
| `-Proxy` | string | — | HTTP proxy URL |

### Scan Sizes

| Configuration | Probes | Est. Time (10s delay) |
|---|---|---|
| Default (12 res x 15 cli x 1 UA) | 180 | ~30 min |
| Full scope (19 res x 31 cli x 1 UA) | 589 | ~98 min |
| Full + UA sweep (19 x 31 x 13) | 7,657 | ~21 hrs |
| Targeted (1 x 1 x 1) | 1 | ~10 sec |

## Usage Examples

### Find CA-excluded cloud apps

When a CA policy enforces MFA on "All cloud apps" but excludes specific apps, CAPO surfaces the exclusions as GAP results:

```powershell
Invoke-CAPO -Domain contoso.com -Username user@contoso.com -Password 'P@ssw0rd' `
  -Delay 5 -Jitter 30 -OutputPath exclusion-scan.csv
```

A GAP on Azure Management while other resources show MFA means Azure Resource Manager is excluded from the CA policy.

### Hunt device platform bypasses

CA policies that enforce MFA on "All platforms" (Windows, macOS, Android, iOS, Linux) miss unrecognized platforms. ChromeOS is the most OPSEC-friendly bypass:

```powershell
# Single UA test
Invoke-CAPO -Domain contoso.com -Username user@contoso.com -Password 'P@ssw0rd' `
  -Resources 'Microsoft Graph' -ClientIDs 'Microsoft Office' `
  -PredefinedUserAgent ChromeOS -Delay 3

# Full UA sweep to map all platform classifications
Invoke-CAPO -Domain contoso.com -Username user@contoso.com -Password 'P@ssw0rd' `
  -Resources 'Microsoft Graph' -ClientIDs 'Microsoft Office' `
  -SweepUserAgents -Delay 3 -Jitter 30
```

| User Agent | Entra Classification | Bypasses "All Platforms" |
|---|---|---|
| ChromeOS | Unknown | Yes (OPSEC-friendly) |
| PlayStation5 | Unknown | Yes (anomalous in logs) |
| NintendoSwitch | Unknown | Yes (anomalous in logs) |
| KaiOS | Unknown | Yes (anomalous in logs) |
| WindowsPhone | Covered | No |

### Detect client app condition gaps

CA policies scoped to "Browser" only don't cover ROPC (classified as "Mobile apps and desktop clients"). Every ROPC probe bypasses browser-only policies:

```powershell
Invoke-CAPO -Domain contoso.com -Username user@contoso.com -Password 'P@ssw0rd' `
  -Resources 'Microsoft Graph','Azure Management' -ClientIDs 'Microsoft Office' -Delay 3
```

If the user has a browser-only CA policy, all probes return GAP.

### Decode tokens and export with full token data

```powershell
# Decode JWT claims inline (tokens still masked in output)
Invoke-CAPO -Domain contoso.com -Username user@contoso.com -Password 'P@ssw0rd' `
  -Resources 'Microsoft Graph' -ClientIDs 'Microsoft Office' -Decode

# Export with raw tokens for downstream tooling (SATO, etc.)
Invoke-CAPO -Domain contoso.com -Username user@contoso.com -Password 'P@ssw0rd' `
  -Resources 'Microsoft Graph' -ClientIDs 'Microsoft Office' `
  -ShowTokens -OutputPath gaps-with-tokens.csv
```

### Multi-client sweep to resolve SP Disabled (500014)

Some client/resource combos return 500014 (the client can't mint tokens for that resource). A multi-client sweep finds the native client that works:

```powershell
Invoke-CAPO -Domain contoso.com -Username user@contoso.com -Password 'P@ssw0rd' `
  -Resources 'Teams' -FullScope -Delay 3 -Jitter 30
```

### Use via proxy

```powershell
Invoke-CAPO -Domain contoso.com -Username user@contoso.com -Password 'P@ssw0rd' `
  -Proxy 'http://127.0.0.1:8080'
```

## Dictionaries

### Resources (19)

| Name | Audience URL | Default |
|---|---|---|
| Microsoft Graph | `https://graph.microsoft.com` | Yes |
| Azure Management | `https://management.azure.com` | Yes |
| Core Management | `https://management.core.windows.net` | Yes |
| Outlook | `https://outlook.office365.com` | Yes |
| Office Apps | `https://officeapps.live.com` | Yes |
| Office Management | `https://manage.office.com` | Yes |
| Azure Key Vault | `https://vault.azure.net` | Yes |
| Teams | `https://api.spaces.skype.com` | Yes |
| Database | `https://database.windows.net` | Yes |
| OneNote | `https://onenote.com` | Yes |
| Intune MAM | `https://msmamservice.api.application` | Yes |
| Yammer | `https://api.yammer.com` | Yes |
| Azure Data Catalog | `https://datacatalog.azure.com` | — |
| Cloud Webapp Proxy | `https://proxy.cloudwebappproxy.net/registerapp` | — |
| Outlook SDF | `https://outlook-sdf.office.com` | — |
| Sara Diagnostics | `https://api.diagnostics.office.com` | — |
| Skype For Business | `https://api.skypeforbusiness.com` | — |
| Webshell Suite | `https://webshell.suite.office.com` | — |
| Azure Graph | `https://graph.windows.net` | — |

> **Note:** Azure Management and Core Management both resolve to the same CA cloud app (Microsoft Azure Management, SP `797f4846-ba00-4fd7-ba43-dac1f8f63013`). A single CA exclusion produces GAP on both.

You can pass raw audience URLs or GUIDs directly:

```powershell
-Resources 'https://vault.azure.net','https://custom.api.contoso.com'
```


## How It Works

### ROPC Flow

CAPO sends Resource Owner Password Credentials (ROPC) grant requests to the Azure AD v1 token endpoint:



### Token Masking

By default, tokens are masked in all output to prevent accidental exposure in screenshots or reports:

```
access_token  : [MASKED - use -ShowTokens to reveal]
refresh_token : [MASKED - use -ShowTokens to reveal]
token_type    : Bearer
expires_in    : 3599
resource      : https://graph.microsoft.com
```

Metadata (token_type, expires_in, resource) is always visible. Use `-ShowTokens` to include raw tokens in console output and CSV export.

### SATO Integration

For every GAP discovered, CAPO generates a ready-to-run [SATO](https://github.com/obikuro/SATO) command:

```
Invoke-Sato -GrantType password -TenantID <tid> -Username user@contoso.com -Password '<pw>'
  -ClientID d3590ed6-52b3-4102-aeff-aad2292ab01c -PredefinedScope MsGraph -PredefinedUserAgent Windows10Chrome
```

The pipeline: **CAPO finds gaps** -> **SATO mints tokens** -> **FOCI pivot** for lateral token movement.

### Safety Features

| Feature | Default | Description |
|---|---|---|
| Credential pre-check | Always on | Validates credentials before sweep; aborts on bad password, no user, disabled, or locked |
| Lockout threshold | `-Safe 1` | Aborts after N lockout signals (AADSTS50053) |
| Configurable delay | `-Delay 10` | Base seconds between probes |
| Jitter | `-Jitter 50` | Randomizes delay by +/- percentage to avoid pattern detection |
| Token masking | On by default | Prevents accidental token exposure |



## Interpreting Results

### Result Categories

| Category | Meaning | Action |
|---|---|---|
| **GAP** | Token issued without MFA | Exploitable — use SATO to mint tokens |
| **MFA Not Setup** | MFA required but user hasn't registered | Creds valid; if self-service registration is open, attacker can register their own MFA |
| **MFA Required** | MFA enforced and user has a method | CA is working as intended |
| **CA Blocked** | Conditional Access denied access | Policy is blocking this combination |
| **SP Disabled / Bad Resource** | Client/resource incompatibility | Not a CA finding — try different client |
| **LOCKED** | Account locked or IP burned | Stop immediately |


## Author

**Edrian Miranda** ([@ObiKuro](https://github.com/obikuro))
