using namespace System.Net
param($Request, $TriggerMetadata)
try {
    $imdsUrl = "$($env:IDENTITY_ENDPOINT)?api-version=2019-08-01&resource=https%3A%2F%2Fdatabase.windows.net%2F"
    $tokenResponse = Invoke-RestMethod -Uri $imdsUrl -Headers @{ "X-IDENTITY-HEADER" = $env:IDENTITY_HEADER } -Method Get
    $connString = "Server=tcp:$($env:SQL_SERVER_NAME),1433;Initial Catalog=sqldb-f1-tracker;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
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
            Round = $reader["Round"]; RaceName = $reader["RaceName"]; CircuitName = $reader["CircuitName"]
            RaceDate = $raceDate.ToString("yyyy-MM-dd")
            Status = if ($raceDate -lt (Get-Date)) { "Completed" } else { "Scheduled" }
        }
    }
    $conn.Close()
    $jsonBody = if ($schedule.Count -gt 0) { $schedule | ConvertTo-Json -Depth 10 } else { "[]" }
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{ StatusCode = [HttpStatusCode]::OK; Body = $jsonBody; Headers = @{ "Content-Type" = "application/json" } })
}
catch {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{ StatusCode = [HttpStatusCode]::InternalServerError; Body = "[]"; Headers = @{ "Content-Type" = "application/json" } })
}