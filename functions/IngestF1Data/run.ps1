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
    
    $transaction.Commit()
    Write-Host "Successfully updated Driver Standings for Season $season."
}
catch {
    $transaction.Rollback()
    Write-Error "Database update failed: $_"
}
finally {
    $conn.Close()
}