using namespace System.Net

param($Request, $TriggerMetadata)

$sqlServer = $env:SQL_SERVER_NAME 
$sqlDatabase = "sqldb-f1-tracker"

$imdsUrl = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2019-08-01&resource=https%3A%2F%2Fdatabase.windows.net%2F"
$tokenResponse = Invoke-RestMethod -Uri $imdsUrl -Headers @{Metadata = "true" } -Method Get

$connString = "Server=tcp:$sqlServer,1433;Initial Catalog=$sqlDatabase;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
$conn = New-Object System.Data.SqlClient.SqlConnection($connString)
$conn.AccessToken = $tokenResponse.access_token
$conn.Open()

$cmd = $conn.CreateCommand()
$cmd.CommandText = "SELECT Position, ConstructorName, Points, Wins FROM ConstructorStandings ORDER BY Position ASC"
$reader = $cmd.ExecuteReader()

$standings = @()
while ($reader.Read()) {
    $standings += @{
        Position        = $reader["Position"]
        ConstructorName = $reader["ConstructorName"]
        Points          = $reader["Points"]
        Wins            = $reader["Wins"]
    }
}
$conn.Close()

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = ($standings | ConvertTo-Json -Depth 10)
        Headers    = @{ "Content-Type" = "application/json" }
    })