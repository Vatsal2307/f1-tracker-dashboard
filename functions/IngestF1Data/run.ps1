param($Timer)

# The SQL Server name must be passed as an Environment Variable
$sqlServer = $env:SQL_SERVER_NAME 
$sqlDatabase = "sqldb-f1-tracker"

Write-Host "Starting F1 Data Ingestion..."

# 1. Get Managed Identity Token via Azure IMDS (Zero dependencies)
$imdsUrl = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2019-08-01&resource=https%3A%2F%2Fdatabase.windows.net%2F"
$tokenResponse = Invoke-RestMethod -Uri $imdsUrl -Headers @{Metadata = "true" } -Method Get
$accessToken = $tokenResponse.access_token

# 2. Fetch Data from Jolpica F1 API
Write-Host "Fetching Driver Standings from Jolpica API..."
$driverResponse = Invoke-RestMethod -Uri "http://api.jolpi.ca/ergast/f1/current/driverStandings.json"
$season = $driverResponse.MRData.StandingsTable.season
$standings = $driverResponse.MRData.StandingsTable.StandingsLists[0].DriverStandings
Write-Host "Fetching Constructor Standings from Jolpica API..."
$constructorResponse = Invoke-RestMethod -Uri "http://api.jolpi.ca/ergast/f1/current/constructorStandings.json"
$constructorStandings = $constructorResponse.MRData.StandingsTable.StandingsLists[0].ConstructorStandings
Write-Host "Fetching Schedule from Jolpica API..."
$scheduleResponse = Invoke-RestMethod -Uri "http://api.jolpi.ca/ergast/f1/current.json"
$races = $scheduleResponse.MRData.RaceTable.Races

# 3. Connect to SQL Database natively
$connString = "Server=tcp:$sqlServer,1433;Initial Catalog=$sqlDatabase;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
$conn = New-Object System.Data.SqlClient.SqlConnection($connString)
$conn.AccessToken = $accessToken
$conn.Open()

# 4. Idempotent Update using SQL Transaction
$transaction = $conn.BeginTransaction()
try {
    # Clear existing standings for this season to prevent duplicates
    $clearCmd = $conn.CreateCommand()
    $clearCmd.Transaction = $transaction
    $clearCmd.CommandText = "DELETE FROM DriverStandings WHERE Season = @Season"
    $clearCmd.Parameters.AddWithValue("@Season", $season) | Out-Null
    $clearCmd.ExecuteNonQuery() | Out-Null

    # Insert fresh standings
    foreach ($driver in $standings) {
        $insertCmd = $conn.CreateCommand()
        $insertCmd.Transaction = $transaction
        $insertCmd.CommandText = "INSERT INTO DriverStandings (Season, Position, DriverName, Points, Wins) VALUES (@Season, @Position, @DriverName, @Points, @Wins)"
        $insertCmd.Parameters.AddWithValue("@Season", $season) | Out-Null
        $insertCmd.Parameters.AddWithValue("@Position", $driver.position) | Out-Null
        $insertCmd.Parameters.AddWithValue("@DriverName", $driver.Driver.familyName) | Out-Null
        $insertCmd.Parameters.AddWithValue("@Points", $driver.points) | Out-Null
        $insertCmd.Parameters.AddWithValue("@Wins", $driver.wins) | Out-Null
        $insertCmd.ExecuteNonQuery() | Out-Null
    }
    # Clear and Upsert Constructor Standings
    $clearWccCmd = $conn.CreateCommand()
    $clearWccCmd.Transaction = $transaction
    $clearWccCmd.CommandText = "DELETE FROM ConstructorStandings WHERE Season = @Season"
    $clearWccCmd.Parameters.AddWithValue("@Season", $season) | Out-Null
    $clearWccCmd.ExecuteNonQuery() | Out-Null

    foreach ($constructor in $constructorStandings) {
        $insertWccCmd = $conn.CreateCommand()
        $insertWccCmd.Transaction = $transaction
        $insertWccCmd.CommandText = "INSERT INTO ConstructorStandings (Season, Position, ConstructorName, Points, Wins) VALUES (@Season, @Position, @ConstructorName, @Points, @Wins)"
        $insertWccCmd.Parameters.AddWithValue("@Season", $season) | Out-Null
        $insertWccCmd.Parameters.AddWithValue("@Position", $constructor.position) | Out-Null
        $insertWccCmd.Parameters.AddWithValue("@ConstructorName", $constructor.Constructor.name) | Out-Null
        $insertWccCmd.Parameters.AddWithValue("@Points", $constructor.points) | Out-Null
        $insertWccCmd.Parameters.AddWithValue("@Wins", $constructor.wins) | Out-Null
        $insertWccCmd.ExecuteNonQuery() | Out-Null
    }

    # Clear and Upsert Schedule
    $clearScheduleCmd = $conn.CreateCommand()
    $clearScheduleCmd.Transaction = $transaction
    $clearScheduleCmd.CommandText = "DELETE FROM Races WHERE Season = @Season"
    $clearScheduleCmd.Parameters.AddWithValue("@Season", $season) | Out-Null
    $clearScheduleCmd.ExecuteNonQuery() | Out-Null

    foreach ($race in $races) {
        $insertRaceCmd = $conn.CreateCommand()
        $insertRaceCmd.Transaction = $transaction
        $insertRaceCmd.CommandText = "INSERT INTO Races (Season, Round, RaceName, CircuitName, RaceDate) VALUES (@Season, @Round, @RaceName, @CircuitName, @RaceDate)"
        $insertRaceCmd.Parameters.AddWithValue("@Season", $season) | Out-Null
        $insertRaceCmd.Parameters.AddWithValue("@Round", $race.round) | Out-Null
        $insertRaceCmd.Parameters.AddWithValue("@RaceName", $race.raceName) | Out-Null
        $insertRaceCmd.Parameters.AddWithValue("@CircuitName", $race.Circuit.circuitName) | Out-Null
        $insertRaceCmd.Parameters.AddWithValue("@RaceDate", $race.date) | Out-Null
        $insertRaceCmd.ExecuteNonQuery() | Out-Null
    }

    # Clear and Upsert Race Results (Top 10)
    Write-Host "Fetching race results for completed rounds..."
    $completedRaces = $races | Where-Object { ([datetime]$_.date) -lt (Get-Date) }

    $clearResultsCmd = $conn.CreateCommand()
    $clearResultsCmd.Transaction = $transaction
    $clearResultsCmd.CommandText = "DELETE FROM RaceResults WHERE Season = @Season"
    $clearResultsCmd.Parameters.AddWithValue("@Season", $season) | Out-Null
    $clearResultsCmd.ExecuteNonQuery() | Out-Null

    foreach ($compRace in $completedRaces) {
        $round = $compRace.round
        $resUrl = "http://api.jolpi.ca/ergast/f1/$season/$round/results.json"
        
        try {
            $roundData = Invoke-RestMethod -Uri $resUrl -Method Get
            $resultsList = $roundData.MRData.RaceTable.Races[0].Results | Select-Object -First 10

            foreach ($item in $resultsList) {
                $insResCmd = $conn.CreateCommand()
                $insResCmd.Transaction = $transaction
                $insResCmd.CommandText = "INSERT INTO RaceResults (Season, Round, Position, DriverName, ConstructorName, Points) VALUES (@Season, @Round, @Position, @DriverName, @ConstructorName, @Points)"
                
                $insResCmd.Parameters.AddWithValue("@Season", $season) | Out-Null
                $insResCmd.Parameters.AddWithValue("@Round", [int]$round) | Out-Null
                $insResCmd.Parameters.AddWithValue("@Position", [int]$item.position) | Out-Null
                $insResCmd.Parameters.AddWithValue("@DriverName", "$($item.Driver.givenName) $($item.Driver.familyName)") | Out-Null
                $insResCmd.Parameters.AddWithValue("@ConstructorName", $item.Constructor.name) | Out-Null
                $insResCmd.Parameters.AddWithValue("@Points", [float]$item.points) | Out-Null
                $insResCmd.ExecuteNonQuery() | Out-Null
            }
        }
        catch {
            Write-Warning "Could not retrieve results for Round $round: $_"
        }
    }
    
    $transaction.Commit()
    Write-Host "Successfully updated Driver Standings, Schedule, and Race Results for Season $season."
}
catch {
    $transaction.Rollback()
    Write-Error "Database update failed: $_"
}
finally {
    $conn.Close()
}