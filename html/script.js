// Global variables
let playerStats = {
    level: 1,
    xp: 0,
    cash: 0,
    distance: 0,
    jobs: 0,
    title: 'Rookie Driver'
};

let routes = [];
let leaderboardData = {
    weekly: [],
    monthly: [],
    global: []
};

// DOM elements
const dashboardContainer = document.getElementById('dashboardContainer');
const ipadFrame = document.querySelector('.ipad-frame');

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    setupEventListeners();
    
    // For testing purposes, show dashboard by default
    if (window.location.href.includes('test-dashboard.html')) {
        showDashboard();
    }
});

// Setup event listeners
function setupEventListeners() {
    // Close dashboard button
    const closeBtn = document.getElementById('closeDashboard');
    if (closeBtn) {
        closeBtn.addEventListener('click', hideDashboard);
    }

    // Navigation items
    const navItems = document.querySelectorAll('.nav-item');
    navItems.forEach(item => {
        item.addEventListener('click', function() {
            const tab = this.getAttribute('data-tab');
            switchTab(tab);
        });
    });

    // Leaderboard tabs
    const leaderboardTabs = document.querySelectorAll('.leaderboard-tab');
    leaderboardTabs.forEach(tab => {
        tab.addEventListener('click', function() {
            const period = this.getAttribute('data-period');
            switchLeaderboardPeriod(period);
        });
    });
}

// Switch between tabs
function switchTab(tabName) {
    // Hide all content tabs
    document.querySelectorAll('.content-tab').forEach(tab => {
        tab.classList.remove('active');
    });

    // Show selected tab
    const selectedTab = document.getElementById(tabName + 'Tab');
    if (selectedTab) {
        selectedTab.classList.add('active');
    }

    // Update navigation active state
    document.querySelectorAll('.nav-item').forEach(item => {
        item.classList.remove('active');
        if (item.getAttribute('data-tab') === tabName) {
            item.classList.add('active');
        }
    });

    // Load tab-specific content
    switch (tabName) {
        case 'routes':
            loadRoutesData();
            break;
        case 'leaderboard':
            loadLeaderboardData();
            break;
    }
}

// Show dashboard
function showDashboard() {
    dashboardContainer.classList.remove('hidden');
    showIPadFrame();
    loadDashboardData();
}

// Hide dashboard
function hideDashboard() {
    dashboardContainer.classList.add('hidden');
    hideIPadFrame();
    
    // Send NUI callback to close dashboard
    if (window.invokeNative) {
        fetch(`https://${GetParentResourceName()}/closeDashboard`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({})
        });
    }
}

// Show iPad frame
function showIPadFrame() {
    if (ipadFrame) {
        ipadFrame.style.display = 'block';
    }
}

// Hide iPad frame
function hideIPadFrame() {
    if (ipadFrame) {
        ipadFrame.style.display = 'none';
    }
}

// Load dashboard data
function loadDashboardData() {
    updateTopBarStats();
    updateDashboardCards();
    updateExperienceProgress();
}

// Update top bar stats
function updateTopBarStats() {
    document.getElementById('playerLevel').textContent = `Level ${playerStats.level}`;
    document.getElementById('playerXP').textContent = `${playerStats.xp} XP`;
    document.getElementById('playerCash').textContent = `$${(playerStats.cash / 1000).toFixed(1)}K`;
    document.getElementById('playerDistance').textContent = `${playerStats.distance.toFixed(1)} km`;
    document.getElementById('playerJobs').textContent = `${playerStats.jobs} jobs`;
}

// Update dashboard cards
function updateDashboardCards() {
    document.getElementById('dashboardDistance').textContent = `${playerStats.distance.toFixed(1)} km`;
    document.getElementById('dashboardEarnings').textContent = `$${(playerStats.cash / 1000).toFixed(1)}K`;
    document.getElementById('dashboardJobs').textContent = playerStats.jobs;
    document.getElementById('dashboardLevel').textContent = playerStats.level;
}

// Update experience progress
function updateExperienceProgress() {
    const currentLevel = playerStats.level;
    const currentXP = playerStats.xp;
    const nextLevelXP = getLevelXPRequirement(currentLevel + 1);
    const currentLevelXP = getLevelXPRequirement(currentLevel);
    
    const progress = nextLevelXP > currentLevelXP ? 
        ((currentXP - currentLevelXP) / (nextLevelXP - currentLevelXP)) * 100 : 100;
    
    document.getElementById('expTotal').textContent = currentXP;
    document.getElementById('expBarFill').style.width = `${progress}%`;
    document.getElementById('expProgressText').textContent = `${currentXP} / ${nextLevelXP} XP`;
    document.getElementById('expLevel').textContent = `Level ${currentLevel}`;
    document.getElementById('expToNext').textContent = nextLevelXP - currentXP;
    document.getElementById('expNextLevel').textContent = currentLevel + 1;
}

// Get XP requirement for a level
function getLevelXPRequirement(level) {
    // This would come from config in FiveM
    const levelXP = {
        1: 0, 2: 100, 3: 300, 4: 600, 5: 1000,
        6: 1500, 7: 2100, 8: 2800, 9: 3600, 10: 4500
    };
    return levelXP[level] || 0;
}

// Load routes data
function loadRoutesData() {
    const routesGrid = document.getElementById('routesGrid');
    if (!routesGrid) return;
    
    routesGrid.innerHTML = '';
    
    routes.forEach((route, index) => {
        const routeCard = createRouteCard(route, index);
        routesGrid.appendChild(routeCard);
    });
}

// Create route card
function createRouteCard(route, index) {
    const card = document.createElement('div');
    card.className = 'route-card';
    
    const stopsList = route.stops.map(stop => stop.name).join(' → ');
    
    card.innerHTML = `
        <div class="route-header">
            <div class="route-name">${route.name}</div>
            <div class="route-payment">$${route.basePayment}</div>
        </div>
        <div class="route-details">
            ${route.stops.length} stops • ${stopsList}
        </div>
        <div class="route-stops">
            <span>Stops: ${route.stops.length}</span>
            <span>Base Pay: $${route.basePayment}</span>
        </div>
        <button class="route-button" onclick="startRoute(${index})">
            Start Route
        </button>
    `;
    
    return card;
}

// Start route
function startRoute(routeIndex) {
    const route = routes[routeIndex];
    if (!route) return;
    
    // Send NUI callback to start route
    if (window.invokeNative) {
        fetch(`https://${GetParentResourceName()}/startRoute`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({
                routeIndex: routeIndex
            })
        });
    } else {
        // For testing
        alert(`Starting route: ${route.name}\nThis would normally spawn a bus and begin the route in FiveM.`);
    }
}

// Load leaderboard data
function loadLeaderboardData() {
    const leaderboardBody = document.getElementById('leaderboardBody');
    if (!leaderboardBody) return;
    
    // Get current period
    const activePeriod = document.querySelector('.leaderboard-tab.active');
    const period = activePeriod ? activePeriod.getAttribute('data-period') : 'weekly';
    
    const data = leaderboardData[period] || [];
    populateLeaderboard(data);
}

// Switch leaderboard period
function switchLeaderboardPeriod(period) {
    // Update active tab
    document.querySelectorAll('.leaderboard-tab').forEach(tab => {
        tab.classList.remove('active');
        if (tab.getAttribute('data-period') === period) {
            tab.classList.add('active');
        }
    });
    
    // Load data for selected period
    const data = leaderboardData[period] || [];
    populateLeaderboard(data);
}

// Populate leaderboard
function populateLeaderboard(data) {
    const leaderboardBody = document.getElementById('leaderboardBody');
    if (!leaderboardBody) return;
    
    leaderboardBody.innerHTML = '';
    
    if (data.length === 0) {
        leaderboardBody.innerHTML = '<div class="no-data">No data available</div>';
        return;
    }
    
    data.forEach((entry, index) => {
        const row = document.createElement('div');
        row.className = 'leaderboard-entry';
        
        row.innerHTML = `
            <div class="rank">#${entry.rank}</div>
            <div class="player-name">${entry.playerName}</div>
            <div class="level">${entry.level}</div>
            <div class="xp">${entry.xp.toLocaleString()}</div>
            <div class="jobs">${entry.jobs}</div>
            <div class="earnings">$${entry.earnings.toLocaleString()}</div>
        `;
        
        leaderboardBody.appendChild(row);
    });
}

// NUI Message Handler
window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch (data.action) {
        case 'showDashboard':
            showDashboard();
            break;
            
        case 'hideDashboard':
            hideDashboard();
            break;
            
        case 'updateStats':
            if (data.stats) {
                playerStats = data.stats;
                updateTopBarStats();
                updateDashboardCards();
                updateExperienceProgress();
            }
            break;
            
        case 'updateRoutes':
            if (data.routes) {
                routes = data.routes;
                if (document.getElementById('routesTab').classList.contains('active')) {
                    loadRoutesData();
                }
            }
            break;
            
        case 'updateLeaderboard':
            if (data.leaderboard) {
                leaderboardData = data.leaderboard;
                if (document.getElementById('leaderboardTab').classList.contains('active')) {
                    loadLeaderboardData();
                }
            }
            break;
            
        case 'showLoading':
            // Show loading state if needed
            break;
    }
});

// Mock data for testing (remove in production)
if (window.location.href.includes('test-dashboard.html')) {
    // Mock player stats
    playerStats = {
        level: 6,
        xp: 1800,
        cash: 24500,
        distance: 320.4,
        jobs: 9,
        title: 'Expert Driver'
    };
    
    // Mock routes
    routes = [
        {
            name: "Downtown Express",
            stops: [
                {x: 200.0, y: -800.0, z: 30.0, name: "Downtown Central"},
                {x: 300.0, y: -900.0, z: 30.0, name: "Shopping District"},
                {x: 400.0, y: -1000.0, z: 30.0, name: "Residential Area"},
                {x: 500.0, y: -1100.0, z: 30.0, name: "Business Park"}
            ],
            basePayment: 150,
            baseXP: 50,
            distanceMultiplier: 0.1
        },
        {
            name: "Airport Shuttle",
            stops: [
                {x: 800.0, y: -1200.0, z: 30.0, name: "Airport Terminal 1"},
                {x: 900.0, y: -1300.0, z: 30.0, name: "Airport Terminal 2"},
                {x: 1000.0, y: -1400.0, z: 30.0, name: "Airport Parking"}
            ],
            basePayment: 200,
            baseXP: 75,
            distanceMultiplier: 0.15
        },
        {
            name: "Beach Route",
            stops: [
                {x: -1200.0, y: -1500.0, z: 4.0, name: "Beach Boardwalk"},
                {x: -1300.0, y: -1600.0, z: 4.0, name: "Beach Resort"},
                {x: -1400.0, y: -1700.0, z: 4.0, name: "Beach Pier"}
            ],
            basePayment: 120,
            baseXP: 40,
            distanceMultiplier: 0.08
        }
    ];
    
    // Mock leaderboard data
    leaderboardData = {
        weekly: [
            {rank: 1, playerName: "John Driver", level: 8, xp: 2800, jobs: 15, earnings: 3500},
            {rank: 2, playerName: "Sarah Bus", level: 7, xp: 2500, jobs: 12, earnings: 3000},
            {rank: 3, playerName: "Mike Route", level: 6, xp: 2200, jobs: 10, earnings: 2800}
        ],
        monthly: [
            {rank: 1, playerName: "John Driver", level: 8, xp: 2800, jobs: 45, earnings: 10500},
            {rank: 2, playerName: "Sarah Bus", level: 7, xp: 2500, jobs: 38, earnings: 9200},
            {rank: 3, playerName: "Mike Route", level: 6, xp: 2200, jobs: 32, earnings: 7800}
        ],
        global: [
            {rank: 1, playerName: "John Driver", level: 8, xp: 2800, jobs: 156, earnings: 35600},
            {rank: 2, playerName: "Sarah Bus", level: 7, xp: 2500, jobs: 142, earnings: 32400},
            {rank: 3, playerName: "Mike Route", level: 6, xp: 2200, jobs: 128, earnings: 29800}
        ]
    };
}
