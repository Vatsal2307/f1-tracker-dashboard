using namespace System.Net
param($Request, $TriggerMetadata)

try {
    $apiUrl = "http://api.jolpi.ca/ergast/f1/current.json"
    $response = Invoke-RestMethod -Uri $apiUrl -Method Get
    $rawRaces = $response.MRData.RaceTable.Races

    $schedule = @()
    foreach ($race in $rawRaces) {
        $raceDate = $race.date -as [datetime]
        $schedule += @{
            Round       = [int]$race.round
            RaceName    = $race.raceName
            CircuitName = $race.Circuit.circuitName
            RaceDate    = $raceDate.ToString("yyyy-MM-dd")
            Status      = if ($raceDate -lt (Get-Date)) { "Completed" } else { "Scheduled" }
        }
    }

    $jsonBody = if ($schedule.Count -gt 0) { $schedule | ConvertTo-Json -Depth 10 } else { "[]" }

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