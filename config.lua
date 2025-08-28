Config = {}

-- Bus depot location
Config.Depot = {
    x = 456.0,
    y = -1025.0,
    z = 28.0,
    heading = 90.0,
    target = {
        enabled = true,
        model = 'prop_busstop_02', -- Target prop model
        offset = {x = 0.0, y = 0.0, z = 0.0}, -- Offset from depot center
        size = {x = 1.0, y = 1.0, z = 1.0}, -- Target size
        rotation = 0.0 -- Target rotation
    }
}

-- Bus spawn location (near depot)
Config.BusSpawn = {
    x = 460.0,
    y = -1025.0,
    z = 28.0,
    heading = 90.0
}

-- Bus model
Config.BusModel = 'bus'

-- Available routes
Config.Routes = {
    {
        name = "Downtown Express",
        stops = {
            {x = 200.0, y = -800.0, z = 30.0, name = "Downtown Central"},
            {x = 300.0, y = -900.0, z = 30.0, name = "Shopping District"},
            {x = 400.0, y = -1000.0, z = 30.0, name = "Residential Area"},
            {x = 500.0, y = -1100.0, z = 30.0, name = "Business Park"}
        },
        basePayment = 150,
        baseXP = 50,
        distanceMultiplier = 0.1 -- XP per km traveled
    },
    {
        name = "Airport Shuttle",
        stops = {
            {x = 800.0, y = -1200.0, z = 30.0, name = "Airport Terminal 1"},
            {x = 900.0, y = -1300.0, z = 30.0, name = "Airport Terminal 2"},
            {x = 1000.0, y = -1400.0, z = 30.0, name = "Airport Parking"}
        },
        basePayment = 200,
        baseXP = 75,
        distanceMultiplier = 0.15
    },
    {
        name = "Beach Route",
        stops = {
            {x = -1200.0, y = -1500.0, z = 4.0, name = "Beach Boardwalk"},
            {x = -1300.0, y = -1600.0, z = 4.0, name = "Beach Resort"},
            {x = -1400.0, y = -1700.0, z = 4.0, name = "Beach Pier"}
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
    passengerXPBonus = 2 -- XP per passenger loaded
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
