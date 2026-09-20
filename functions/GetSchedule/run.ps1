using namespace System.Net
param($Request, $TriggerMetadata)

$output = "Starting Database Diagnostics...`n"

try {
    $imdsUrl = "$($env:IDENTITY_ENDPOINT)?api-version=2019-08-01&resource=https%3A%2F%2Fdatabase.windows.net%2F"
    $tokenResponse = Invoke-RestMethod -Uri$imdsUrl -Headers @{ "X-IDENTITY-HEADER" = $env:IDENTITY_HEADER } -Method Get$connString = "Server=tcp:$($env:SQL_SERVER_NAME),1433;Initial Catalog=sqldb-f1-tracker;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
    $conn = New-Object System.Data.SqlClient.SqlConnection($connString)$conn.AccessToken = $tokenResponse.access_token$conn.Open()

    $tables = @("DriverStandings", "ConstructorStandings", "Races", "RaceResults")
    
    foreach ($table in$tables) {
        try {
            $cmd = $conn.CreateCommand()$cmd.CommandText = "SELECT COUNT(*) FROM $table"
            $count = $cmd.ExecuteScalar()$output += "[OK] Table '$table' exists and has$count rows.`n"
        }
        catch {
            $output += "[FAIL] Table '$table' error: $($_.Exception.Message)`n"
        }
    }
    $conn.Close()

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{ 
            StatusCode = [HttpStatusCode]::OK
            Body       = $output
            Headers    = @{ "Content-Type" = "text/plain" } 
        })
}
catch {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{ 
            StatusCode = [HttpStatusCode]::InternalServerError
            Body       = "CRITICAL CONNECTION ERROR: $_"
            Headers    = @{ "Content-Type" = "text/plain" } 
        })
}