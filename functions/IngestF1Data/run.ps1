param($Timer)

Write-Host "Starting F1 Data Ingestion..."

try {
    if (-not $env:SQL_SERVER_NAME) { throw "SQL_SERVER_NAME environment variable is missing." }
    if (-not $env:IDENTITY_ENDPOINT) { throw "IDENTITY_ENDPOINT is missing." }

    $sqlServer = $env:SQL_SERVER_NAME 
    $sqlDatabase = "sqldb-f1-tracker"

    $imdsUrl = "$($env:IDENTITY_ENDPOINT)?api-version=2019-08-01&resource=https%3A%2F%2Fdatabase.windows.net%2F"
    $tokenResponse = Invoke-RestMethod -Uri $imdsUrl -Headers @{ "X-IDENTITY-HEADER" = $env:IDENTITY_HEADER } -Method Get
    $accessToken = $tokenResponse.access_token

    Write-Host "Fetching F1 API Data..."
    $driverResponse = Invoke-RestMethod -Uri "http://api.jolpi.ca/ergast/f1/current/driverStandings.json"
    $season = $driverResponse.MRData.StandingsTable.season
    $standings = $driverResponse.MRData.StandingsTable.StandingsLists[0].DriverStandings
    
    $constructorResponse = Invoke-RestMethod -Uri "http://api.jolpi.ca/ergast/f1/current/constructorStandings.json"
    $constructorStandings = $constructorResponse.MRData.StandingsTable.StandingsLists[0].ConstructorStandings
    
    $scheduleResponse = Invoke-RestMethod -Uri "http://api.jolpi.ca/ergast/f1/current.json"
    $races = $scheduleResponse.MRData.RaceTable.Races

    $connString = "Server=tcp:$sqlServer,1433;Initial Catalog=$sqlDatabase;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
    $conn = New-Object System.Data.SqlClient.SqlConnection($connString)
    $conn.AccessToken = $accessToken
    $conn.Open()

    Write-Host "Verifying Database Schema (Self-Healing)..."
    $setupCmd = $conn.CreateCommand()
    $setupCmd.CommandText = @"
    IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='DriverStandings' and xtype='U')
    CREATE TABLE DriverStandings (Season NVARCHAR(10), Position INT, DriverName NVARCHAR(100), Points FLOAT, Wins INT);

    IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='ConstructorStandings' and xtype='U')
    CREATE TABLE ConstructorStandings (Season NVARCHAR(10), Position INT, ConstructorName NVARCHAR(100), Points FLOAT, Wins INT);

    IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Races' and xtype='U')
    CREATE TABLE Races (Season NVARCHAR(10), Round INT, RaceName NVARCHAR(100), CircuitName NVARCHAR(100), RaceDate NVARCHAR(50));

    IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='RaceResults' and xtype='U')
    CREATE TABLE RaceResults (Season NVARCHAR(10), Round INT, Position INT, DriverName NVARCHAR(100), ConstructorName NVARCHAR(100), Points FLOAT);
"@
    $setupCmd.ExecuteNonQuery() | Out-Null

    Write-Host "Beginning SQL Transaction..."
    $transaction = $conn.BeginTransaction()
    
    try {
        # --- Drivers ---
        $clearCmd = $conn.CreateCommand(); $clearCmd.Transaction = $transaction
        $clearCmd.CommandText = "DELETE FROM DriverStandings WHERE Season = @Season"
        $clearCmd.Parameters.AddWithValue("@Season", $season) | Out-Null
        $clearCmd.ExecuteNonQuery() | Out-Null

        foreach ($driver in $standings) {
            $insertCmd = $conn.CreateCommand(); $insertCmd.Transaction = $transaction
            $insertCmd.CommandText = "INSERT INTO DriverStandings (Season, Position, DriverName, Points, Wins) VALUES (@Season, @Position, @DriverName, @Points, @Wins)"
            $insertCmd.Parameters.AddWithValue("@Season", $season) | Out-Null
            $insertCmd.Parameters.AddWithValue("@Position", $driver.position) | Out-Null
            $insertCmd.Parameters.AddWithValue("@DriverName", $driver.Driver.familyName) | Out-Null
            $insertCmd.Parameters.AddWithValue("@Points", $driver.points) | Out-Null
            $insertCmd.Parameters.AddWithValue("@Wins", $driver.wins) | Out-Null
            $insertCmd.ExecuteNonQuery() | Out-Null
        }
        
        # --- Constructors ---
        $clearWccCmd = $conn.CreateCommand(); $clearWccCmd.Transaction = $transaction
        $clearWccCmd.CommandText = "DELETE FROM ConstructorStandings WHERE Season = @Season"
        $clearWccCmd.Parameters.AddWithValue("@Season", $season) | Out-Null
        $clearWccCmd.ExecuteNonQuery() | Out-Null

        foreach ($constructor in $constructorStandings) {
            $insertWccCmd = $conn.CreateCommand(); $insertWccCmd.Transaction = $transaction
            $insertWccCmd.CommandText = "INSERT INTO ConstructorStandings (Season, Position, ConstructorName, Points, Wins) VALUES (@Season, @Position, @ConstructorName, @Points, @Wins)"
            $insertWccCmd.Parameters.AddWithValue("@Season", $season) | Out-Null
            $insertWccCmd.Parameters.AddWithValue("@Position", $constructor.position) | Out-Null
            $insertWccCmd.Parameters.AddWithValue("@ConstructorName", $constructor.Constructor.name) | Out-Null
            $insertWccCmd.Parameters.AddWithValue("@Points", $constructor.points) | Out-Null
            $insertWccCmd.Parameters.AddWithValue("@Wins", $constructor.wins) | Out-Null
            $insertWccCmd.ExecuteNonQuery() | Out-Null
        }

        # --- Schedule ---
        $clearScheduleCmd = $conn.CreateCommand(); $clearScheduleCmd.Transaction = $transaction
        $clearScheduleCmd.CommandText = "DELETE FROM Races WHERE Season = @Season"
        $clearScheduleCmd.Parameters.AddWithValue("@Season", $season) | Out-Null
        $clearScheduleCmd.ExecuteNonQuery() | Out-Null

        foreach ($race in $races) {
            $insertRaceCmd = $conn.CreateCommand(); $insertRaceCmd.Transaction = $transaction
            $insertRaceCmd.CommandText = "INSERT INTO Races (Season, Round, RaceName, CircuitName, RaceDate) VALUES (@Season, @Round, @RaceName, @CircuitName, @RaceDate)"
            $insertRaceCmd.Parameters.AddWithValue("@Season", $season) | Out-Null
            $insertRaceCmd.Parameters.AddWithValue("@Round", $race.round) | Out-Null
            $insertRaceCmd.Parameters.AddWithValue("@RaceName", $race.raceName) | Out-Null
            $insertRaceCmd.Parameters.AddWithValue("@CircuitName", $race.Circuit.circuitName) | Out-Null
            $insertRaceCmd.Parameters.AddWithValue("@RaceDate", $race.date) | Out-Null
            $insertRaceCmd.ExecuteNonQuery() | Out-Null
        }

        # --- Race Results ---
        $completedRaces = $races | Where-Object { ([datetime]$_.date) -lt (Get-Date) }

        $clearResultsCmd = $conn.CreateCommand(); $clearResultsCmd.Transaction = $transaction
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
                    $insResCmd = $conn.CreateCommand(); $insResCmd.Transaction = $transaction
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
            catch { Write-Warning "Results fetch failed for round $round" }
        }
        
        $transaction.Commit()
        Write-Host "SUCCESS: Data Ingested!"
    }
    catch {
        $transaction.Rollback()
        throw "SQL Transaction failed: $_"
    }
    finally {
        $conn.Close()
    }
}
catch {
    Write-Error "Ingestion script crashed: $_"
}