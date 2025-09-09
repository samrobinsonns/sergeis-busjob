// Global variables
let menu = true;
let jobList = {}; // Legacy variable for backward compatibility
let currentJobIndex = null;
let progressStatus = null;
let playerLevel = 0;

// Global variables for new UI
let playerStats = {
    level: 1,
    xp: 0,
    cash: 0,
    distance: 0,
    jobs: 0,
    title: 'Rookie Driver'
};

let routes = []; // Will be populated from config
let leaderboardData = {
    weekly: [],
    monthly: [],
    global: []
};

// DOM elements
const dashboardContainer = document.getElementById('dashboardContainer');
const ipadFrame = document.querySelector('.ipad-frame');

window.addEventListener("message", function (event) {
  if (event.data.action === "open") {
    showDashboard();
    jobList = event.data.list || [];
    progressStatus = event.data.xp || 0;
    // Routes are now loaded dynamically via loadRoutesData()
  } else if (event.data.action === "updateLevel") {
    // Update player stats with XP data from server
    playerStats.level = event.data.level || 1;
    playerStats.xp = event.data.xp || 0;

    // If full stats are provided, use them
    if (event.data.stats) {
      playerStats = event.data.stats;
    }

    // Update UI with new XP data
    updateTopBarStats(playerStats);
    updateDashboardCards();
    updateExperienceProgress();
    // Routes are now loaded dynamically via loadRoutesData()
  } else if (event.data.action === "updateStats") {
    if (event.data.stats) {
      playerStats = event.data.stats;
      updateTopBarStats(playerStats);
      updateDashboardCards();
      updateExperienceProgress();
    }
  } else if (event.data.action === "updateRoutes") {
    if (event.data.routes) {
      routes = event.data.routes;
      if (document.getElementById('routesTab').classList.contains('active')) {
        loadRoutesData();
      }
    }
  } else if (event.data.action === "updateLeaderboard") {
    if (event.data.leaderboard) {
      leaderboardData = event.data.leaderboard;
      if (document.getElementById('leaderboardTab').classList.contains('active')) {
        loadLeaderboardData();
      }
    }
  }
});

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    setupEventListeners();

    // Load initial data
    loadDashboardData();
    loadRoutesData();

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
    document.querySelectorAll('.tab-pane').forEach(tab => {
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
    updateTopBarStats(playerStats);
    updateDashboardCards();
    updateExperienceProgress();
}

// Update top bar stats
function updateTopBarStats(stats) {
    if (!stats) return;

    // Safely update elements that exist
    const playerLevel = document.getElementById('playerLevel');
    if (playerLevel) playerLevel.textContent = `Level ${stats.level || 1}`;

    const playerJobs = document.getElementById('playerJobs');
    if (playerJobs) playerJobs.textContent = `${stats.jobs || 0} jobs`;
}

// Update dashboard cards
function updateDashboardCards() {
    // Safely update dashboard elements
    const dashboardLevel = document.getElementById('dashboardLevel');
    if (dashboardLevel) dashboardLevel.textContent = playerStats.level || 1;

    const dashboardJobs = document.getElementById('dashboardJobs');
    if (dashboardJobs) dashboardJobs.textContent = playerStats.jobs || 0;
}

// Update experience progress
function updateExperienceProgress() {
    const currentLevel = playerStats.level || 1;
    const currentXP = playerStats.xp || 0;
    const xpForNextLevel = playerStats.xpForNextLevel || 0;
    const nextLevelXP = playerStats.nextLevelXP || (currentXP + xpForNextLevel);

    // Simple progress calculation: current XP / XP needed for next level
    const progress = nextLevelXP > 0 ? (currentXP / nextLevelXP) * 100 : 100;

    // Safely update experience elements
    const expCurrent = document.getElementById('expCurrent');
    if (expCurrent) expCurrent.textContent = currentXP;

    const expNext = document.getElementById('expNext');
    if (expNext) expNext.textContent = nextLevelXP;

    const expBarFill = document.getElementById('xpProgressFill');
    if (expBarFill) expBarFill.style.width = `${Math.min(Math.max(progress, 0), 100)}%`;

    const expProgressText = document.getElementById('expProgressText');
    if (expProgressText) expProgressText.textContent = `${currentXP} / ${nextLevelXP} XP`;

    const expLevel = document.getElementById('expLevel');
    if (expLevel) expLevel.textContent = currentLevel;

    const expNextLevel = document.getElementById('expNextLevel');
    if (expNextLevel) expNextLevel.textContent = currentLevel + 1;

    // Update level progress bar
    const levelFill = document.getElementById('levelFill');
    if (levelFill) {
        levelFill.style.width = `${Math.min(Math.max(progress, 0), 100)}%`;
    }

    // Update top bar XP progress
    const xpProgressFill = document.getElementById('xpProgressFill');
    if (xpProgressFill) {
        xpProgressFill.style.width = `${Math.min(Math.max(progress, 0), 100)}%`;
    }
}

// Get XP requirement for a level (updated dynamically from server)
function getLevelXPRequirement(level) {
    // Use the nextLevelXP from player stats if available
    if (playerStats.nextLevelXP && level === playerStats.level + 1) {
        return playerStats.nextLevelXP;
    }

    // Fallback to estimated calculation
    const baseXP = 100;
    const multiplier = 1.5;
    let requiredXP = 0;

    for (let i = 1; i < level; i++) {
        requiredXP = Math.floor(requiredXP * multiplier) + baseXP;
    }

    return requiredXP;
}

// Load routes data
function loadRoutesData() {
    const routesGrid = document.getElementById('routesGrid');
    if (!routesGrid) return;

    // If routes not loaded yet, request from server
    if (routes.length === 0) {
        if (window.invokeNative) {
            // Request routes from server
            fetch(`https://${GetParentResourceName()}/requestRoutes`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=UTF-8',
                },
                body: JSON.stringify({})
            }).catch(error => {
                console.error('Error requesting routes:', error);
                // Show loading message
                routesGrid.innerHTML = '<div class="no-data">Loading routes...</div>';
            });
        } else {
            // For testing - show loading
            routesGrid.innerHTML = '<div class="no-data">Loading routes...</div>';
        }
        return;
    }

    routesGrid.innerHTML = '';

    if (routes.length === 0) {
        routesGrid.innerHTML = '<div class="no-data">No routes available</div>';
        return;
    }

    // Group routes by level
    const routesByLevel = {};
    routes.forEach((route, index) => {
        const level = route.level || 1;
        if (!routesByLevel[level]) {
            routesByLevel[level] = [];
        }
        routesByLevel[level].push({route, index});
    });

    // Sort levels
    const sortedLevels = Object.keys(routesByLevel).sort((a, b) => parseInt(a) - parseInt(b));

    sortedLevels.forEach(level => {
        const levelRoutes = routesByLevel[level];
        const levelSection = createLevelSection(level, levelRoutes);
        routesGrid.appendChild(levelSection);
    });
}

// Create route card
function createRouteCard(route, index) {
    const card = document.createElement('div');
    card.className = 'route-card';

    // Get bus icon based on route name
    const busIcon = `<i class="${getBusIconForRoute(route.name)}"></i>`;

    // Get level requirement from route data
    const requiredLevel = route.level || 1;
    const playerLevel = playerStats.level || 1;
    const canDoJob = playerLevel >= requiredLevel;
    const levelText = canDoJob ? `Level ${requiredLevel}+` : `Requires Level ${requiredLevel}`;

    card.innerHTML = `
        <div class="route-header">
            <div class="route-bus-icon">
                ${busIcon}
            </div>
            <div class="route-info">
                <div class="route-name">${route.name || 'Unknown Route'}</div>
                <div class="route-stats">
                    <span class="stat-item">
                        <i class="fas fa-map-marker-alt"></i>
                        ${route.stops ? route.stops.length : 0} stops
                    </span>
                    <span class="stat-item">
                        <i class="fas fa-dollar-sign"></i>
                        $${route.basePayment || 0}
                    </span>
                    <span class="stat-item">
                        <i class="fas fa-star"></i>
                        ${route.baseXP || 0} XP
                    </span>
                    <span class="stat-item ${canDoJob ? 'success' : 'warning'}">
                        <i class="fas fa-level-up-alt"></i>
                        ${levelText}
                    </span>
                </div>
            </div>
        </div>
        <div class="route-details">
            <div class="route-description">
                <strong>Route:</strong> ${route.stops ? route.stops.length : 0} passenger stops
            </div>
            <div class="route-rewards">
                <div class="reward-item">
                    <i class="fas fa-coins"></i>
                    <span>Earn $${route.basePayment || 0}</span>
                </div>
                <div class="reward-item">
                    <i class="fas fa-chart-line"></i>
                    <span>Gain ${route.baseXP || 0} XP + distance bonuses</span>
                </div>
                <div class="reward-item">
                    <i class="fas fa-bus"></i>
                    <span>Vehicle: ${route.vehicleModel ? route.vehicleModel.charAt(0).toUpperCase() + route.vehicleModel.slice(1) : 'Standard Bus'}</span>
                </div>
            </div>
        </div>
        <div class="route-actions">
            <button class="btn ${canDoJob ? 'btn-primary' : 'btn-danger'} route-button" onclick="startRoute(${index})" ${!canDoJob ? 'disabled' : ''}>
                <i class="fas fa-play"></i>
                ${canDoJob ? 'Start Route' : `Level ${requiredLevel} Required`}
            </button>
        </div>
    `;

    return card;
}

// Create level section
function createLevelSection(level, levelRoutes) {
    const section = document.createElement('div');
    section.className = 'level-section';

    const levelNames = {
        1: 'Beginner',
        2: 'Novice',
        3: 'Intermediate',
        4: 'Advanced',
        5: 'Expert',
        6: 'Professional',
        7: 'Elite',
        8: 'Master',
        9: 'Champion',
        10: 'Legend'
    };

    const levelName = levelNames[level] || `Level ${level}`;

    section.innerHTML = `
        <div class="level-header">
            <div class="level-badge">Level ${level}</div>
            <div class="level-name">${levelName}</div>
            <div class="level-count">${levelRoutes.length} route${levelRoutes.length !== 1 ? 's' : ''}</div>
        </div>
        <div class="level-routes">
            ${levelRoutes.map(({route, index}) => createRouteCard(route, index).outerHTML).join('')}
        </div>
    `;

    return section;
}

// Get appropriate bus icon for route type
function getBusIconForRoute(routeName) {
    if (routeName.toLowerCase().includes('airport')) {
        return 'fas fa-plane';
    } else if (routeName.toLowerCase().includes('beach')) {
        return 'fas fa-umbrella-beach';
    } else if (routeName.toLowerCase().includes('express') || routeName.toLowerCase().includes('downtown')) {
        return 'fas fa-city';
    } else {
        return 'fas fa-bus';
    }
}

// Start route
function startRoute(routeIndex) {
    const route = routes[routeIndex];
    if (!route) return;

    // Send the raw config route data directly to the client
    if (window.invokeNative) {
        fetch(`https://${GetParentResourceName()}/startJob`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({
                job: route,  // Send raw config route data
                index: routeIndex  // Job index within zone
            })
        }).then(() => {
            // Close the dashboard after starting the job
            hideDashboard();
        }).catch(error => {
            console.error('Error starting job:', error);
        });
    } else {
        // For testing in browser
        alert(`Starting route: ${route.name}\nThis would normally spawn a bus and begin the route in FiveM.`);
        hideDashboard();
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
        row.className = 'leaderboard-row';

        row.innerHTML = `
            <div class="rank-badge ${getRankBadgeClass(index + 1)}">${getRankDisplay(index + 1)}</div>
            <div class="player-name">${entry.playerName}</div>
            <div class="level">${entry.level}</div>
            <div class="xp">${entry.xp.toLocaleString()}</div>
            <div class="jobs">${entry.jobs}</div>
            <div class="earnings">$${entry.earnings.toLocaleString()}</div>
        `;

        leaderboardBody.appendChild(row);
    });
}

// Get rank badge class
function getRankBadgeClass(rank) {
    if (rank === 1) return 'gold';
    if (rank === 2) return 'silver';
    if (rank === 3) return 'bronze';
    return 'default';
}

// Get rank display
function getRankDisplay(rank) {
    if (rank <= 3) return rank;
    return rank;
}



$('.filterMenu').click(function() {
  if (menu) {
    $('.menu-items').show();
    menu = false;
    $('#down').css('rotate', '360deg')
  } else {
    $('.menu-items').hide();
    menu = true;
    $('#down').css('rotate', '270deg')
  }
});



// Legacy close handler - updated for new UI
$(document).on("click", ".closeIcon", function() {
  hideDashboard(); // Use new hide function
})

// Legacy confirm handler - updated for new UI
$(document).on("click", "#confirm", function () {
  if (currentJobIndex !== null) {
    const selectedJob = jobList[currentJobIndex];
    $(".popUp").hide();
    hideDashboard(); // Use new hide function
    $.post("https://sergeis-busjob/startJob", JSON.stringify({
      job: selectedJob,
      index: currentJobIndex
    }), function () {
    });
  } else {
    console.error("No job selected!");
  }
});

// Legacy handlers removed - new UI uses different event system

// loadModelData function removed - routes are now loaded dynamically from config via server
// Sorting functionality removed as routes are now loaded from server dynamically






// Keyboard shortcuts
window.addEventListener("keyup", (event) => {
  if (event.key == "Escape") {
      // Don't prevent default for escape key to allow proper focus release
      hideDashboard();
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
