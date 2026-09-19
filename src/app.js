// Replace XXXX with your actual function app suffix
const API_BASE_URL = 'https://func-f1-tracker-XXXX.azurewebsites.net/api';

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