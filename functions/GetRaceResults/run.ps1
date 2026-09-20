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

try {
    # Fetch results for the specific round dynamically
    $apiUrl = "http://api.jolpi.ca/ergast/f1/current/$round/results.json"
    $response = Invoke-RestMethod -Uri $apiUrl -Method Get
    
    $races = $response.MRData.RaceTable.Races
    $results = @()
    
    # Only process if the API returns completed race data
    if ($races.Count -gt 0) {
        $top10 = $races[0].Results | Select-Object -First 10
        
        foreach ($item in $top10) {
            $results += @{
                Position        = [int]$item.position
                DriverName      = "$($item.Driver.givenName) $($item.Driver.familyName)"
                ConstructorName = $item.Constructor.name
                Points          = [float]$item.points
            }
        }
    }

    # Safely convert to JSON
    $jsonBody = if ($results.Count -gt 0) { $results | ConvertTo-Json -Depth 5 } else { "[]" }

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
            Headers    = @{ 
                "Content-Type"  = "application/json"
                "Cache-Control" = "no-cache" 
            }
        })
}