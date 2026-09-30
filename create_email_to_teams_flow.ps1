# Creates a cloud flow in a solution:
#   Trigger: When a new email arrives in your Inbox (Office 365 Outlook)
#   Action:  Post the email subject to you in Teams (chat with Flow bot)
#
# Before running: create two connection references in the solution
# (Office 365 Outlook and Microsoft Teams) and paste their logical names below.

$ErrorActionPreference = "Stop"

# 1. Settings
$orgUrl       = "https://org8ae7d3ca.crm.dynamics.com"
$solutionName = "copilotLearningApiv2_1790111718035"
$flowName     = "Email Subject to Teams - Created with Code"
$recipient    = "mlukacsko@avkare.com"   # who gets the Teams message

# Connection reference LOGICAL names (the "Name" column in the solution)
$outlookConnRef = "cr170_OutlookEmailtoTeams"
$teamsConnRef   = "cr170_TeamsEmailtoTeams"

# 2. Sign in and get a token for Dataverse
Connect-AzAccount | Out-Null
$tokenResult = Get-AzAccessToken -ResourceUrl $orgUrl
$token = if ($tokenResult.Token -is [securestring]) {
    [System.Net.NetworkCredential]::new('', $tokenResult.Token).Password
} else {
    $tokenResult.Token
}

$headers = @{
    "Authorization"            = "Bearer $token"
    "Content-Type"             = "application/json"
    "OData-MaxVersion"         = "4.0"
    "OData-Version"            = "4.0"
    "Prefer"                   = "return=representation"
    "MSCRM.SolutionUniqueName" = $solutionName
}

# 3. The flow definition
#    Single quotes keep PowerShell from treating $ and @{ } as its own syntax.
$auth = '@parameters(''$authentication'')'

$clientData = @{
    properties = @{
        connectionReferences = @{
            shared_office365 = @{
                runtimeSource = "embedded"
                connection    = @{ connectionReferenceLogicalName = $outlookConnRef }
                api           = @{ name = "shared_office365" }
            }
            shared_teams = @{
                runtimeSource = "embedded"
                connection    = @{ connectionReferenceLogicalName = $teamsConnRef }
                api           = @{ name = "shared_teams" }
            }
        }
        definition = @{
            '$schema'      = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"
            contentVersion = "1.0.0.0"
            parameters     = @{
                '$connections'    = @{ defaultValue = @{}; type = "Object" }
                '$authentication' = @{ defaultValue = @{}; type = "SecureObject" }
            }
            triggers = @{
                'When_a_new_email_arrives_(V3)' = @{
                    type    = "OpenApiConnectionNotification"
                    splitOn = '@triggerOutputs()?[''body/value'']'
                    inputs  = @{
                        host = @{
                            apiId          = "/providers/Microsoft.PowerApps/apis/shared_office365"
                            connectionName = "shared_office365"
                            operationId    = "OnNewEmailV3"
                        }
                        parameters = @{
                            folderPath              = "Inbox"
                            importance              = "Any"
                            fetchOnlyWithAttachment = $false
                            includeAttachments      = $false
                        }
                        authentication = $auth
                    }
                }
            }
            actions = @{
                Post_message_in_a_chat = @{
                    type     = "OpenApiConnection"
                    runAfter = @{}
                    inputs   = @{
                        host = @{
                            apiId          = "/providers/Microsoft.PowerApps/apis/shared_teams"
                            connectionName = "shared_teams"
                            operationId    = "PostMessageToConversation"
                        }
                        parameters = @{
                            poster              = "Flow bot"
                            location            = "Chat with Flow bot"
                            'body/recipient'    = $recipient
                            'body/messageBody'  = '<p>New email: @{triggerOutputs()?[''body/subject'']}</p>'
                        }
                        authentication = $auth
                    }
                }
            }
        }
    }
    schemaVersion = "1.0.0.0"
} | ConvertTo-Json -Depth 30 -Compress

# 4. Create the flow record (category 5 = cloud flow)
$body = @{
    name          = $flowName
    description   = "Sends a Teams message with the subject of each new email"
    category      = 5
    type          = 1
    primaryentity = "none"
    clientdata    = $clientData
} | ConvertTo-Json -Depth 5

$flow = Invoke-RestMethod -Method Post -Uri "$orgUrl/api/data/v9.2/workflows" -Headers $headers -Body $body
Write-Host "Created flow: $($flow.workflowid)"

# 5. Make sure it's in the solution (ComponentType 29 = workflow/flow)
$addBody = @{
    ComponentId           = $flow.workflowid
    ComponentType         = 29
    SolutionUniqueName    = $solutionName
    AddRequiredComponents = $false
} | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$orgUrl/api/data/v9.2/AddSolutionComponent" -Headers $headers -Body $addBody | Out-Null
Write-Host "Added flow to solution: $solutionName"

# 6. Turn the flow on
$activate = @{ statecode = 1; statuscode = 2 } | ConvertTo-Json
Invoke-RestMethod -Method Patch -Uri "$orgUrl/api/data/v9.2/workflows($($flow.workflowid))" -Headers $headers -Body $activate | Out-Null
Write-Host "Flow is on. Send yourself a test email and watch for a Teams message from Flow bot."