using namespace System.Net

param($Request, $TriggerMetadata)

$round = $Request.Query.round
if (-not $round) {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = "Missing 'round' parameter."
        })
    return
}

$sqlServer = $env:SQL_SERVER_NAME 
$sqlDatabase = "sqldb-f1-tracker"

# 1. Fast, dependency-free Managed Identity Token
$imdsUrl = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2019-08-01&resource=https%3A%2F%2Fdatabase.windows.net%2F"
$tokenResponse = Invoke-RestMethod -Uri $imdsUrl -Headers @{Metadata = "true" } -Method Get

# 2. Connect to SQL
$connString = "Server=tcp:$sqlServer,1433;Initial Catalog=$sqlDatabase;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
$conn = New-Object System.Data.SqlClient.SqlConnection($connString)
$conn.AccessToken = $tokenResponse.access_token
$conn.Open()

# 3. Query the Top 10 Results for the requested round
$cmd = $conn.CreateCommand()
$cmd.CommandText = @"
SELECT Position, DriverName, ConstructorName, Points 
FROM RaceResults 
WHERE Round = @Round 
ORDER BY Position ASC
"@
$cmd.Parameters.AddWithValue("@Round", [int]$round) | Out-Null
$reader = $cmd.ExecuteReader()

$results = @()
while ($reader.Read()) {
    $results += @{
        Position        = $reader["Position"]
        DriverName      = $reader["DriverName"]
        ConstructorName = $reader["ConstructorName"]
        Points          = $reader["Points"]
    }
}
$conn.Close()

# 4. Return formatted JSON response
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = ($results | ConvertTo-Json -Depth 5)
        Headers    = @{ 
            "Content-Type" = "application/json" 
        }
    })