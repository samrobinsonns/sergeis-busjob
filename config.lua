Config = {}

-- Bus depot location
Config.Depot = {
    x = 456.0,
    y = -1025.0,
    z = 28.0,
    coords = vector3(456.0, -1025.0, 28.0),
    heading = 90.0,
    target = {
        enabled = true,
        pedModel = 'a_m_m_business_01', -- Depot manager ped model (business man)
        -- Alternative ped models you can use:
        -- 'a_m_m_business_01' - Business man
        -- 'a_f_m_business_02' - Business woman  
        -- 'a_m_m_tourist_01' - Tourist man
        -- 'a_f_m_tourist_01' - Tourist woman
        -- 's_m_m_trucker_01' - Truck driver
        -- 's_m_y_busboy_01' - Bus driver
        offset = {x = 0.0, y = 0.0, z = -1.0} -- Offset from depot center (ped spawns slightly below ground level)
    }
}

-- Bus spawn locations (multiple points for availability checking)
Config.BusSpawnPoints = {
    vector4(460.0, -1025.0, 28.0, 90.0),   -- Primary spawn point
    vector4(465.0, -1025.0, 28.0, 90.0),   -- Secondary spawn point
    vector4(470.0, -1025.0, 28.0, 90.0),   -- Tertiary spawn point
    vector4(475.0, -1025.0, 28.0, 90.0),   -- Fourth spawn point
    vector4(480.0, -1025.0, 28.0, 90.0),   -- Fifth spawn point
    vector4(460.0, -1030.0, 28.0, 90.0),   -- Alternative row
    vector4(465.0, -1030.0, 28.0, 90.0),   -- Alternative row
    vector4(470.0, -1030.0, 28.0, 90.0),   -- Alternative row
}

-- Spawn validation settings
Config.SpawnValidation = {
    checkRadius = 3.0,           -- Radius to check for obstacles
    maxSpawnAttempts = 8,        -- Maximum attempts to find spawn point
    vehicleCheckDistance = 2.5,  -- Distance to check for other vehicles
    pedCheckDistance = 1.5,      -- Distance to check for peds
    groundCheckDistance = 5.0,   -- Distance to check ground clearance
    spawnPointSpacing = 5.0      -- Minimum spacing between spawn points
}

-- Bus model
Config.BusModel = 'bus'

-- Available routes
Config.Routes = {
    {
        name = "Downtown Express",
        stops = {
            {coords = vector3(200.0, -800.0, 30.0), name = "Downtown Central"},
            {coords = vector3(300.0, -900.0, 30.0), name = "Shopping District"},
            {coords = vector3(400.0, -1000.0, 30.0), name = "Residential Area"},
            {coords = vector3(500.0, -1100.0, 30.0), name = "Business Park"}
        },
        basePayment = 150,
        baseXP = 50,
        distanceMultiplier = 0.1 -- XP per km traveled
    },
    {
        name = "Airport Shuttle",
        stops = {
            {coords = vector3(800.0, -1200.0, 30.0), name = "Airport Terminal 1"},
            {coords = vector3(900.0, -1300.0, 30.0), name = "Airport Terminal 2"},
            {coords = vector3(1000.0, -1400.0, 30.0), name = "Airport Parking"}
        },
        basePayment = 200,
        baseXP = 75,
        distanceMultiplier = 0.15
    },
    {
        name = "Beach Route",
        stops = {
            {coords = vector3(-1200.0, -1500.0, 4.0), name = "Beach Boardwalk"},
            {coords = vector3(-1300.0, -1600.0, 4.0), name = "Beach Resort"},
            {coords = vector3(-1400.0, -1700.0, 4.0), name = "Beach Pier"}
        },
        basePayment = 120,
        baseXP = 40,
        distanceMultiplier = 0.08
    }
}

-- Passenger settings
Config.PassengerSettings = {
    maxPassengers = 20,
    passengerModels = {
        'a_m_m_business_01',
        'a_f_m_business_02',
        'a_m_m_tourist_01',
        'a_f_m_tourist_01',
        'a_m_m_skater_01',
        'a_f_m_skater_01'
    },
    passengerCountRange = {3, 8}, -- Random number of passengers per stop
    passengerSpawnOffset = {10, 10}, -- X and Y offset for passenger spawning
    passengerBonus = 5, -- $5 per passenger
    autoLoadDistance = 5.0, -- Distance to automatically load passengers when stopped
    passengerXPBonus = 2, -- XP per passenger loaded
    
    -- Realistic passenger loading settings
    realisticLoading = true, -- Enable realistic walking to bus (set to false for instant warp)
    doorOffset = 2.0, -- Distance from bus center to door
    walkSpeed = 1.0, -- How fast passengers walk to bus
    doorReachDistance = 1.5, -- How close passenger needs to be to door
    maxWalkTime = 5.0, -- Maximum seconds to walk to bus (5 seconds)
    maxEnterTime = 3.0, -- Maximum seconds to enter bus (3 seconds)
    fallbackToWarp = true -- If realistic loading fails, warp passenger in
}

-- Leveling system configuration
Config.Leveling = {
    enabled = true,
    levels = {
        [1] = {xp = 0, title = "Rookie Driver", bonus = 1.0},
        [2] = {xp = 100, title = "Novice Driver", bonus = 1.05},
        [3] = {xp = 300, title = "Experienced Driver", bonus = 1.1},
        [4] = {xp = 600, title = "Skilled Driver", bonus = 1.15},
        [5] = {xp = 1000, title = "Professional Driver", bonus = 1.2},
        [6] = {xp = 1500, title = "Expert Driver", bonus = 1.25},
        [7] = {xp = 2100, title = "Master Driver", bonus = 1.3},
        [8] = {xp = 2800, title = "Elite Driver", bonus = 1.35},
        [9] = {xp = 3600, title = "Legendary Driver", bonus = 1.4},
        [10] = {xp = 4500, title = "Bus Driving Champion", bonus = 1.5}
    },
    maxLevel = 10,
    xpMultiplier = 1.0 -- Global XP multiplier
}

-- Game settings
Config.GameSettings = {
    routeTimeout = 300000, -- 5 minutes to complete route
    depotReturnDistance = 10.0, -- Distance to return to depot
    forceRouteEndDelay = 30000 -- 30 seconds delay before forcing route end
}

-- Vehicle settings
Config.VehicleSettings = {
    engineOn = false,
    doorsLocked = 1,
    maxSpeed = 0.0, -- 0 = no limit
    fuelLevel = 100.0,
    dirtLevel = 0.0,
    plateText = "BUS"
}

-- Blip settings
Config.BlipSettings = {
    sprite = 1,
    currentStopColor = 2, -- Green
    completedStopColor = 1, -- Red
    upcomingStopColor = 3, -- Blue
    shortRange = true,
    scale = 1.0
}

-- Ped settings
Config.PedSettings = {
    canRagdoll = false,
    canBeTargetted = false,
    canBeDraggedOut = false,
    canRagdollFromPlayerImpact = false,
    canRagdollFromPlayerWeaponImpact = false,
    canRagdollFromPlayerVehicleImpact = false,
    blockNonTemporaryEvents = true
}

-- Payment settings
Config.PaymentSettings = {
    defaultMethod = 'cash', -- 'cash', 'bank', 'crypto'
    allowMultipleMethods = false,
    paymentReason = 'bus-route-completion',
    adminGiftReason = 'bus-admin-gift'
}

-- Target system settings
Config.TargetSystem = {
    type = 'qb-target', -- 'qb-target' or 'ox_target'
    label = 'Open Bus Job Dashboard',
    icon = 'fas fa-bus',
    distance = 2.0
}

-- Dashboard settings
Config.Dashboard = {
    title = "Bus Driving System",
    companyName = "City Transit Authority",
    refreshInterval = 5000, -- How often to refresh dashboard data (ms)
    showWeeklyStats = true,
    showMonthlyStats = true,
    showGlobalRanking = true
}

-- Notification settings
Config.NotificationSettings = {
    useQBCoreNotifications = true,
    notificationTypes = {
        success = 'success',
        error = 'error',
        info = 'primary',
        warning = 'warning'
    }
}

-- Debug settings
Config.Debug = {
    enabled = false,
    showCoordinates = false,
    logLevel = 'info', -- 'debug', 'info', 'warn', 'error'
    showFPS = false
}

-- Commands
Config.Commands = {
    endRoute = 'endbus',
    giveMoney = 'givebusmoney',
    help = 'bushelp',
    stats = 'busstats'
}

-- Messages
Config.Messages = {
    routeStarted = 'Route started: %s',
    routeEnded = 'Route ended.',
    notOnRoute = 'You are not currently on a route.',
    routeComplete = 'Route complete! Return to depot for payment.',
    routeTimeout = 'Route timeout! Return to depot immediately.',
    passengersLoaded = 'Passengers loaded! Moving to: %s',
    paymentReceived = 'Route completed! You earned $%d ($%d base + $%d passenger bonus)',
    consoleOnly = 'This command is console only',
    playerNotFound = 'Player not found',
    busSpawned = 'Your bus has been spawned. Look for the marker!',
    returnBus = 'Return your bus to the depot to complete the route.',
    levelUp = 'Congratulations! You reached level %d: %s',
    xpEarned = 'You earned %d XP for this route!',
    helpText = {
        'Go to the bus depot and use the target to open dashboard',
        'Select a route from the Routes tab',
        'Drive to each stop and wait for passengers to load automatically',
        'Complete the route and return to depot for payment',
        'Use /endbus to end current route early'
    }
}

-- Performance settings
Config.Performance = {
    mainThreadDelay = 1000, -- Main logic thread delay
    passengerSpawnDelay = 100, -- Delay between passenger spawns
    blipUpdateDelay = 1000, -- Blip update delay
    routeCheckDelay = 1000, -- Route completion check delay
    passengerLoadCheckDelay = 500 -- How often to check if bus is stopped at stop
}

-- Anti-exploit settings
Config.AntiExploit = {
    maxRoutesPerHour = 10,
    maxPassengersPerRoute = 50,
    routeCooldown = 60000, -- 1 minute cooldown between routes
    validateCoordinates = true,
    maxDistanceFromDepot = 10000.0 -- Maximum distance player can be from depot
}
