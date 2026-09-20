using namespace System.Net
param($Request, $TriggerMetadata)

try {
    $sqlServer = $env:SQL_SERVER_NAME 
    if (-not $sqlServer) { throw "SQL_SERVER_NAME environment variable is missing in Azure Settings." }

    $sqlDatabase = "sqldb-f1-tracker"
    $imdsUrl = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2019-08-01&resource=https%3A%2F%2Fdatabase.windows.net%2F"
    $tokenResponse = Invoke-RestMethod -Uri $imdsUrl -Headers @{Metadata = "true" } -Method Get
    
    $connString = "Server=tcp:$sqlServer,1433;Initial Catalog=$sqlDatabase;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
    $conn = New-Object System.Data.SqlClient.SqlConnection($connString)
    $conn.AccessToken = $tokenResponse.access_token
    $conn.Open()

    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT Round, RaceName, CircuitName, RaceDate FROM Races ORDER BY Round ASC"
    $reader = $cmd.ExecuteReader()

    $schedule = @()
    while ($reader.Read()) {
        $raceDate = $reader["RaceDate"] -as [datetime]
        $schedule += @{
            Round       = $reader["Round"]
            RaceName    = $reader["RaceName"]
            CircuitName = $reader["CircuitName"]
            RaceDate    = $raceDate.ToString("yyyy-MM-dd")
            Status      = if ($raceDate -lt (Get-Date)) { "Completed" } else { "Scheduled" }
        }
    }
    $conn.Close()

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = ($schedule | ConvertTo-Json -Depth 10)
            Headers    = @{ "Content-Type" = "application/json" }
        })
}
catch {
    # Catch the exact error and print it to the browser
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::InternalServerError
            Body       = "Backend Error: $_"
            Headers    = @{ "Content-Type" = "text/plain" }
        })
}