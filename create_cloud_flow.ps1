# Creates a simple Power Automate cloud flow using the Dataverse Web API.
# The flow runs once a day and performs a single Compose action (no connections needed).
#
# Requirements:
#   Install-Module Az.Accounts -Scope CurrentUser
#   Your account needs permission to create flows in the target environment.

# 1. Your environment's Dataverse URL (Power Platform admin center > Environments > Environment URL)
$orgUrl = "https://org8ae7d3ca.crm.dynamics.com"

# 2. Sign in and get a token for Dataverse
Connect-AzAccount | Out-Null
$tokenResult = Get-AzAccessToken -ResourceUrl $orgUrl
# Newer Az.Accounts versions return the token as a SecureString
$token = if ($tokenResult.Token -is [securestring]) {
    [System.Net.NetworkCredential]::new('', $tokenResult.Token).Password
} else {
    $tokenResult.Token
}

$headers = @{
    "Authorization"    = "Bearer $token"
    "Content-Type"     = "application/json"
    "OData-MaxVersion" = "4.0"
    "OData-Version"    = "4.0"
    "Prefer"           = "return=representation"
}

$headers["MSCRM.SolutionUniqueName"] = "copilotLearningApiv2_1790111718035"

# 3. The flow definition (same JSON you'd see if you exported a flow)
$clientData = @{
    properties = @{
        connectionReferences = @{}
        definition = @{
            '$schema'      = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"
            contentVersion = "1.0.0.0"
            parameters     = @{
                '$connections'    = @{ defaultValue = @{}; type = "Object" }
                '$authentication' = @{ defaultValue = @{}; type = "SecureObject" }
            }
            triggers = @{
                Recurrence = @{
                    type       = "Recurrence"
                    recurrence = @{ frequency = "Day"; interval = 1 }
                }
            }
            actions = @{
                Compose = @{
                    type     = "Compose"
                    inputs   = "Hello from a flow created with code!"
                    runAfter = @{}
                }
            }
        }
    }
    schemaVersion = "1.0.0.0"
} | ConvertTo-Json -Depth 20 -Compress

# 4. Create the flow record. category 5 = modern (cloud) flow; clientdata must be a JSON *string*
$body = @{
    name          = "Hello World - Created with Code"
    description   = "Sample cloud flow created through the Dataverse Web API"
    category      = 5
    type          = 1
    primaryentity = "none"
    clientdata    = $clientData
} | ConvertTo-Json -Depth 5

$flow = Invoke-RestMethod -Method Post -Uri "$orgUrl/api/data/v9.2/workflows" -Headers $headers -Body $body
Write-Host "Created flow: $($flow.workflowid)"

# 5. Turn the flow on (flows are created in the Off/Draft state)
$activate = @{ statecode = 1; statuscode = 2 } | ConvertTo-Json
Invoke-RestMethod -Method Patch -Uri "$orgUrl/api/data/v9.2/workflows($($flow.workflowid))" -Headers $headers -Body $activate
Write-Host "Flow is on. Find it under My flows or Solutions > Default Solution."