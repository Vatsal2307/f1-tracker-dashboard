using namespace System.Net
param($Request, $TriggerMetadata)

try {
    $apiUrl = "http://api.jolpi.ca/ergast/f1/current/constructorStandings.json"
    $response = Invoke-RestMethod -Uri $apiUrl -Method Get
    $rawStandings = $response.MRData.StandingsTable.StandingsLists[0].ConstructorStandings

    $standings = @()
    foreach ($constructor in $rawStandings) {
        $standings += @{
            Position        = [int]$constructor.position
            ConstructorName = $constructor.Constructor.name
            Points          = [float]$constructor.points
            Wins            = [int]$constructor.wins
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