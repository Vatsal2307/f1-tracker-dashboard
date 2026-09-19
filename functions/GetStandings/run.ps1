using namespace System.Net

param($Request, $TriggerMetadata)

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

# 3. Query the Standings
$cmd = $conn.CreateCommand()
$cmd.CommandText = "SELECT Position, DriverName, Points, Wins FROM DriverStandings ORDER BY Position ASC"
$reader = $cmd.ExecuteReader()

$standings = @()
while ($reader.Read()) {
    $standings += @{
        Position   = $reader["Position"]
        DriverName = $reader["DriverName"]
        Points     = $reader["Points"]
        Wins       = $reader["Wins"]
    }
}
$conn.Close()

# 4. Return formatted JSON response
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = ($standings | ConvertTo-Json -Depth 10)
        Headers    = @{
            "Content-Type" = "application/json"
        }
    })