using namespace System.Net
param($Request, $TriggerMetadata)

# Initialize a guaranteed JSON-safe output object
$output = @{
    Success = $false
    Message = ""
    Data    = @()
}

try {
    if (-not $env:SQL_SERVER_NAME) { throw "SQL_SERVER_NAME environment variable is missing." }
    if (-not $env:IDENTITY_ENDPOINT) { throw "IDENTITY_ENDPOINT is missing. Managed Identity is not available to this function." }

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
            Round       = $reader["Round"]
            RaceName    = $reader["RaceName"]
            CircuitName = $reader["CircuitName"]
            RaceDate    = $raceDate.ToString("yyyy-MM-dd")
            Status      = if ($raceDate -lt (Get-Date)) { "Completed" } else { "Scheduled" }
        }
    }
    $conn.Close()

    $output.Success = $true
    $output.Message = "Successfully fetched $($schedule.Count) races."
    $output.Data = $schedule

}
catch {
    # Safely extract ONLY the text message to prevent silent object-parsing crashes
    $output.Success = $false
    $output.Message = "Diagnostic Error: $($_.Exception.Message)"
}

# Always return HTTP 200 OK so the browser renders the JSON block
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = ($output | ConvertTo-Json -Depth 10)
        Headers    = @{ "Content-Type" = "application/json" }
    })