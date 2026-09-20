const API_BASE_URL = 'https://func-f1-tracker-2053.azurewebsites.net/api';

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

async function loadConstructorStandings() {
    try {
        const response = await fetch(`${API_BASE_URL}/GetConstructorStandings`);
        const data = await response.json();

        const tbody = document.querySelector('#constructor-table tbody');
        data.forEach(team => {
            const row = `<tr>
                <td>${team.Position}</td>
                <td><strong>${team.ConstructorName}</strong></td>
                <td>${team.Points}</td>
                <td>${team.Wins}</td>
            </tr>`;
            tbody.innerHTML += row;
        });
    } catch (error) {
        console.error('Error fetching constructor standings:', error);
    }
}

async function loadSchedule() {
    try {
        const response = await fetch(`${API_BASE_URL}/GetSchedule`);
        const data = await response.json();

        const tbody = document.querySelector('#schedule-table tbody');
        let nextRaceFound = false;

        data.forEach(race => {
            // Pin the next upcoming race to the banner
            if (!nextRaceFound && race.Status === "Scheduled") {
                document.getElementById('next-race-banner').innerHTML =
                    `<strong>NEXT RACE:</strong> ${race.RaceName} on ${race.RaceDate}`;
                nextRaceFound = true;
            }

            // Determine if we show a button or a badge
            const isCompleted = race.Status === "Completed";
            const actionCell = isCompleted
                ? `<button class="view-results-btn" onclick="showRaceResults(${race.Round}, '${race.RaceName}')">View Results</button>`
                : `<span class="badge scheduled">Scheduled</span>`;

            // Build and insert the row
            const row = `<tr>
                <td>${race.Round}</td>
                <td><strong>${race.RaceName}</strong><br><small>${race.CircuitName}</small></td>
                <td>${race.RaceDate}</td>
                <td>${actionCell}</td>
            </tr>`;
            tbody.innerHTML += row;
        });
    } catch (error) {
        console.error('Error fetching schedule:', error);
    }
}

async function showRaceResults(round, raceName) {
    const dialog = document.getElementById('results-dialog');
    const modalTitle = document.getElementById('modal-title');
    const tbody = document.querySelector('#modal-results-table tbody');

    modalTitle.textContent = `${raceName} - Top 10 Finishers`;
    tbody.innerHTML = '<tr><td colspan="4">Loading...</td></tr>';
    dialog.showModal();

    try {
        const res = await fetch(`${API_BASE_URL}/GetRaceResults?round=${round}`);
        const data = await res.json();

        tbody.innerHTML = '';
        if (!data || data.length === 0) {
            tbody.innerHTML = '<tr><td colspan="4">No results recorded yet.</td></tr>';
            return;
        }

        data.forEach(item => {
            tbody.innerHTML += `
                <tr>
                    <td>${item.Position}</td>
                    <td><strong>${item.DriverName}</strong></td>
                    <td>${item.ConstructorName}</td>
                    <td>${item.Points}</td>
                </tr>`;
        });
    } catch (err) {
        tbody.innerHTML = '<tr><td colspan="4">Failed to load results.</td></tr>';
    }
}

// Initialize dashboard once all content is loaded
document.addEventListener('DOMContentLoaded', () => {
    loadStandings();
    loadConstructorStandings();
    loadSchedule();
});