
function Send-ROPCProbe {
    param(
        [string]$TenantID,
        [string]$Username,
        [string]$Password,
        [string]$ResourceName,
        [string]$ResourceURL,
        [string]$ClientName,
        [string]$ClientGUID,
        [string]$UAName,
        [string]$UAString,
        [string]$Proxy
    )

    $url = "https://login.microsoftonline.com/$TenantID/oauth2/token"

    $body = @{
        resource    = $ResourceURL
        client_id   = $ClientGUID
        client_info = '1'
        grant_type  = 'password'
        username    = $Username
        password    = $Password
        scope       = 'openid'
    }

    $headers = @{
        'User-Agent'   = $UAString
        'Accept'       = 'application/json'
    }

    $webArgs = @{
        Uri             = $url
        Method          = 'POST'
        Body            = $body
        Headers         = $headers
        ContentType     = 'application/x-www-form-urlencoded'
        UseBasicParsing = $true
        ErrorAction     = 'Stop'
    }
    if ($Proxy) { $webArgs.Proxy = $Proxy }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    try {
        $response = Invoke-WebRequest @webArgs
        $token = $response.Content | ConvertFrom-Json

        return [PSCustomObject]@{
            Timestamp   = $timestamp
            Resource    = $ResourceName
            ResourceURL = $ResourceURL
            Client      = $ClientName
            ClientID    = $ClientGUID
            UserAgent   = $UAName
            Status      = 'GAP'
            Code        = $null
            Detail      = 'Token issued without MFA'
            TokenData   = $token
        }
    }
    catch {
        $errorBody = $null
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            try { $errorBody = $_.ErrorDetails.Message | ConvertFrom-Json } catch {}
        }
        if (-not $errorBody -and $_.Exception.Response) {
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = [System.IO.StreamReader]::new($stream)
                $raw = $reader.ReadToEnd()
                $reader.Close()
                $errorBody = $raw | ConvertFrom-Json
            } catch {}
        }

        $code   = $null
        $status = 'Error'
        $detail = ''

        if ($errorBody -and $errorBody.error_description) {
            $desc = $errorBody.error_description
            if ($desc -match 'AADSTS(\d+)') { $code = $Matches[1] }

            switch ($code) {
                '50076'  { $status = 'MFA Required';    $detail = 'Password valid - MFA enforced' }
                '50079'  { $status = 'MFA Not Setup';   $detail = 'Password valid - MFA enrollment required but not configured' }
                '50158'  { $status = 'External MFA';    $detail = 'Password valid - third-party MFA' }
                '53003'  { $status = 'CA Blocked';      $detail = 'Password valid - blocked by conditional access' }
                '50105'  { $status = 'App CA Blocked';  $detail = 'Application blocked by conditional access' }
                '53000'  { $status = 'Device Required'; $detail = 'Requires compliant/managed device' }
                '50053'  { $status = 'LOCKED';          $detail = 'Account locked or IP burned' }
                '50126'  { $status = 'Wrong Password';  $detail = 'Invalid credentials' }
                '50034'  { $status = 'No User';         $detail = 'User not found' }
                '50057'  { $status = 'Disabled';        $detail = 'Account disabled' }
                '50055'  { $status = 'Expired';         $detail = 'Password expired (password valid)' }
                '65001'  { $status = 'No Consent';      $detail = 'User/admin has not consented' }
                '65002'  { $status = 'Not Authorized';  $detail = 'Client not authorized for resource' }
                '7000218' { $status = 'Secret Required'; $detail = 'Client assertion or secret required' }
                '7000112' { $status = 'App Disabled';   $detail = 'Application disabled' }
                '53011'  { $status = 'User Blocked';    $detail = 'User blocked due to risk' }
                '53004'  { $status = 'Suspicious';      $detail = 'Suspicious activity detected' }
                '500014' { $status = 'SP Disabled';     $detail = 'Service principal disabled' }
                '50001'  { $status = 'Resource Off';    $detail = 'Resource disabled or does not exist' }
                '700016' { $status = 'Bad Client';      $detail = 'Invalid client ID' }
                '500011' { $status = 'Bad Resource';    $detail = 'Invalid resource' }
                '900144' { $status = 'No Password';     $detail = 'Empty password' }
                default  {
                    $status = 'Error'
                    $detail = $desc.Substring(0, [Math]::Min(200, $desc.Length))
                }
            }
        }
        else {
            $detail = $_.Exception.Message
        }

        return [PSCustomObject]@{
            Timestamp   = $timestamp
            Resource    = $ResourceName
            ResourceURL = $ResourceURL
            Client      = $ClientName
            ClientID    = $ClientGUID
            UserAgent   = $UAName
            Status      = $status
            Code        = $code
            Detail      = $detail
            TokenData   = $null
        }
    }
}
