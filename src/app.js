// Replace XXXX with your actual function app suffix
const API_BASE_URL = 'https://func-f1-tracker-XXXX.azurewebsites.net/api';
async function loadSchedule() {
    try {
        const response = await fetch(`${API_BASE_URL}/GetSchedule`);
        const data = await response.json();

        const tbody = document.querySelector('#schedule-table tbody');
        let nextRaceFound = false;

        data.forEach(race => {
            const row = `<tr>
                <td>${race.Round}</td>
                <td><strong>${race.RaceName}</strong><br><small>${race.CircuitName}</small></td>
                <td>${race.RaceDate}</td>
                <td>${race.Status}</td>
            </tr>`;
            tbody.innerHTML += row;

            // Pin the next upcoming race to the banner
            if (!nextRaceFound && race.Status === "Scheduled") {
                document.getElementById('next-race-banner').innerHTML =
                    `<strong>NEXT RACE:</strong> ${race.RaceName} on ${race.RaceDate}`;
                nextRaceFound = true;
            }
        });
    } catch (error) {
        console.error('Error fetching schedule:', error);
    }
}

document.addEventListener('DOMContentLoaded', () => {
    loadStandings();
    loadSchedule(); // Add this line!
});
async function loadStandings() {
    try {
        const response = await fetch(`${API_BASE_URL}/GetStandings`);
        const data = await response.json();

        const tbody = document.querySelector('#standings-table tbody');
        data.forEach(driver => {
            const row = `<tr>
                <td>${driver.Position}</td>
                <td><strong>${driver.DriverName}</strong></td>
                <td>${driver.Points}</td>
                <td>${driver.Wins}</td>
            </tr>`;
            tbody.innerHTML += row;
        });
    } catch (error) {
        console.error('Error fetching standings:', error);
    }
}

// Initialize dashboard
document.addEventListener('DOMContentLoaded', () => {
    loadStandings();
    // loadSchedule() would be called here once the GetSchedule API is ready
});