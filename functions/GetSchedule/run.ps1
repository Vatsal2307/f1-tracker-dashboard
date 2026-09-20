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
    $cmd.CommandText = "
    IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='ConstructorStandings' and xtype='U')
    CREATE TABLE ConstructorStandings (
        Season NVARCHAR(10),
        Position INT,
        ConstructorName NVARCHAR(100),
        Points FLOAT,
        Wins INT
    )"
    $cmd.ExecuteNonQuery()
    $conn.Close()

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{ 
            StatusCode = [HttpStatusCode]::OK
            Body       = "MIGRATION SUCCESS: ConstructorStandings table created!"
            Headers    = @{ "Content-Type" = "text/plain" } 
        })
}
catch {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{ 
            StatusCode = [HttpStatusCode]::InternalServerError
            Body       = "ERROR: $_"
            Headers    = @{ "Content-Type" = "text/plain" } 
        })
}