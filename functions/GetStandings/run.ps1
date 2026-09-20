using namespace System.Net
param($Request, $TriggerMetadata)

try {
    # Fetch directly from Jolpica
    $apiUrl = "http://api.jolpi.ca/ergast/f1/current/driverStandings.json"
    $response = Invoke-RestMethod -Uri $apiUrl -Method Get
    $rawStandings = $response.MRData.StandingsTable.StandingsLists[0].DriverStandings

    # Map to the exact format your frontend expects
    $standings = @()
    foreach ($driver in $rawStandings) {
        $standings += @{
            Position   = [int]$driver.position
            DriverName = "$($driver.Driver.givenName) $($driver.Driver.familyName)"
            Points     = [float]$driver.points
            Wins       = [int]$driver.wins
        }
    }

    $jsonBody = if ($standings.Count -gt 0) { $standings | ConvertTo-Json -Depth 10 } else { "[]" }

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{ 
            StatusCode = [HttpStatusCode]::OK
            Body       = $jsonBody
            Headers    = @{ 
                "Content-Type"  = "application/json"
                "Cache-Control" = "public, max-age=14400" 
            } 
        })
}
catch {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{ 
            StatusCode = [HttpStatusCode]::InternalServerError
            Body       = "[]"
            Headers    = @{ "Content-Type" = "application/json"; "Cache-Control" = "no-cache" } 
        })
}