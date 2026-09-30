# Exports the stored definition of an existing flow or Copilot Studio workflow
# so you can see how it's built (triggers, agent node, Teams step, etc.).
# Read-only: this script does not change anything.

$ErrorActionPreference = "Stop"

# 1. Settings
$orgUrl     = "https://org8ae7d3ca.crm.dynamics.com"
$nameSearch = "Email Summary"   # part of the workflow's name

# 2. Sign in and get a token for Dataverse
Connect-AzAccount | Out-Null
$tokenResult = Get-AzAccessToken -ResourceUrl $orgUrl
$token = if ($tokenResult.Token -is [securestring]) {
    [System.Net.NetworkCredential]::new('', $tokenResult.Token).Password
} else {
    $tokenResult.Token
}
$headers = @{
    "Authorization"    = "Bearer $token"
    "Accept"           = "application/json"
    "OData-MaxVersion" = "4.0"
    "OData-Version"    = "4.0"
}

# 3. Find matching workflows
$filter = [uri]::EscapeDataString("contains(name,'$nameSearch')")
$select = "workflowid,name,category,type,modernflowtype,statecode,clientdata"
$uri    = "$orgUrl/api/data/v9.2/workflows?`$filter=$filter&`$select=$select"
$results = (Invoke-RestMethod -Method Get -Uri $uri -Headers $headers).value

if (-not $results) { Write-Host "No workflows found with '$nameSearch' in the name."; return }

# 4. Show the key fields and save each definition as readable JSON
foreach ($wf in $results) {
    Write-Host ""
    Write-Host "Name:           $($wf.name)"
    Write-Host "ID:             $($wf.workflowid)"
    Write-Host "Category:       $($wf.category)"
    Write-Host "Modern type:    $($wf.modernflowtype)"
    Write-Host "State (1 = on): $($wf.statecode)"

    if ($wf.clientdata) {
        $safeName = ($wf.name -replace '[^\w\-]', '_')
        $outFile  = Join-Path $PSScriptRoot "$safeName.definition.json"
        $wf.clientdata | ConvertFrom-Json | ConvertTo-Json -Depth 50 | Set-Content -Path $outFile -Encoding UTF8
        Write-Host "Definition:     saved to $outFile"
    } else {
        Write-Host "Definition:     (clientdata is empty for this record)"
    }
}