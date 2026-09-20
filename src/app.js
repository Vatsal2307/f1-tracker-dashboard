const JOLPICA_BASE = 'https://api.jolpi.ca/ergast/f1';

async function loadStandings() {
    try {
        const response = await fetch(`${JOLPICA_BASE}/current/driverStandings.json`);
        const data = await response.json();
        const rawStandings = data.MRData.StandingsTable.StandingsLists[0].DriverStandings;

        const tbody = document.querySelector('#standings-table tbody');
        rawStandings.forEach(driver => {
            const row = `<tr>
                <td>${driver.position}</td>
                <td><strong>${driver.Driver.givenName} ${driver.Driver.familyName}</strong></td>
                <td>${driver.points}</td>
                <td>${driver.wins}</td>
            </tr>`;
            tbody.innerHTML += row;
        });
    } catch (error) {
        console.error('Error fetching standings:', error);
    }
}

async function loadConstructorStandings() {
    try {
        const response = await fetch(`${JOLPICA_BASE}/current/constructorStandings.json`);
        const data = await response.json();
        const rawStandings = data.MRData.StandingsTable.StandingsLists[0].ConstructorStandings;

        const tbody = document.querySelector('#constructor-table tbody');
        rawStandings.forEach(team => {
            const row = `<tr>
                <td>${team.position}</td>
                <td><strong>${team.Constructor.name}</strong></td>
                <td>${team.points}</td>
                <td>${team.wins}</td>
            </tr>`;
            tbody.innerHTML += row;
        });
    } catch (error) {
        console.error('Error fetching constructor standings:', error);
    }
}

async function loadSchedule() {
    try {
        const response = await fetch(`${JOLPICA_BASE}/current.json`);
        const data = await response.json();
        const rawRaces = data.MRData.RaceTable.Races;

        const tbody = document.querySelector('#schedule-table tbody');
        let nextRaceFound = false;
        const now = new Date();

        rawRaces.forEach(race => {
            const raceDate = new Date(race.date);
            const status = raceDate < now ? 'Completed' : 'Scheduled';
            const formattedDate = race.date; // already YYYY-MM-DD from Jolpica

            // Pin the next upcoming race to the banner
            if (!nextRaceFound && status === 'Scheduled') {
                document.getElementById('next-race-banner').innerHTML =
                    `<strong>NEXT RACE:</strong> ${race.raceName} on ${formattedDate}`;
                nextRaceFound = true;
            }

            const actionCell = status === 'Completed'
                ? `<button class="view-results-btn" onclick="showRaceResults(${race.round}, '${race.raceName}')">View Results</button>`
                : `<span class="badge scheduled">Scheduled</span>`;

            tbody.innerHTML += `<tr>
                <td>${race.round}</td>
                <td><strong>${race.raceName}</strong><br><small>${race.Circuit.circuitName}</small></td>
                <td>${formattedDate}</td>
                <td>${actionCell}</td>
            </tr>`;
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
        const res = await fetch(`${JOLPICA_BASE}/current/${round}/results.json`);
        const data = await res.json();
        const races = data.MRData.RaceTable.Races;

        tbody.innerHTML = '';
        if (!races || races.length === 0) {
            tbody.innerHTML = '<tr><td colspan="4">No results recorded yet.</td></tr>';
            return;
        }

        const top10 = races[0].Results.slice(0, 10);
        top10.forEach(item => {
            tbody.innerHTML += `
                <tr>
                    <td>${item.position}</td>
                    <td><strong>${item.Driver.givenName} ${item.Driver.familyName}</strong></td>
                    <td>${item.Constructor.name}</td>
                    <td>${item.points}</td>
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