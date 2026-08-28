@{
    RootModule        = 'CAPO.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'a1c3f7e2-8b4d-4e6a-9f01-3d5c7e8b2a4f'
    Author            = 'Edrian Miranda'
    Copyright         = 'BSD 3-Clause'
    Description       = 'CAPO (Conditional Access Probing Operations) - automated MFA/CA gap discovery via ROPC with built-in low-and-slow pacing.'
    FunctionsToExport = @('Invoke-CAPO', 'Show-CAPOResources', 'Show-CAPOClients', 'Show-CAPOUserAgents, Resolve-TenantID')
    PrivateData       = @{
        PSData = @{
            Tags       = @('security', 'pentesting', 'red team', 'azure', 'entra', 'conditional access', 'MFA')
            ProjectUri = 'https://github.com/obikuro/CAPO'
        }
    }
}
