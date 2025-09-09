Config = {}

-- Bus depot location
Config.Depot = {
    x = 469.9733,
    y = -583.4772,
    z = 28.4996,
    coords = vector3(469.9733, -583.4772, 28.4996),
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

-- Default bus model (fallback if route doesn't specify one)
Config.BusModel = 'bus'

-- Available routes
Config.Routes = {
    {
        name = "Downtown Express",
        level = 1, -- Basic route for beginners
        vehicleModel = 'bus2', -- Standard bus for basic routes
        stops = {
            {coords = vector3(462.7124, -643.9278, 28.3319), name = "Downtown Central"},
            {coords = vector3(274.4731, -592.2328, 43.1166), name = "Pillbox Hill Hospital"},
            {coords = vector3(-516.8644, -264.1432, 35.3808), name = "City Hall"},
            {coords = vector3(-651.6819, -938.4558, 22.1935), name = "Weazel News"},
            {coords = vector3(-172.2864, -1416.1000, 31.1496), name = "Union Depository"}
        },
        basePayment = 200,
        baseXP = 75,
        distanceMultiplier = 0.12 -- XP per km traveled
    },
    {
        name = "Airport Shuttle",
        level = 5, -- Advanced route requiring experience
        vehicleModel = 'airbus', -- Airbus for airport routes
        stops = {
            {coords = vector3(-1037.0, -2737.0, 20.0), name = "Airport Terminal 1"},
            {coords = vector3(-1034.0, -2733.0, 20.0), name = "Airport Terminal 2"},
            {coords = vector3(-1029.0, -2491.0, 20.0), name = "Airport Parking"}
        },
        basePayment = 250,
        baseXP = 100,
        distanceMultiplier = 0.18
    },
    {
        name = "Beach Route",
        level = 3, -- Intermediate route
        vehicleModel = 'LFS', -- Coach bus for longer beach routes
        stops = {
            {coords = vector3(-1681.0, -1111.0, 13.0), name = "Beach Boardwalk"},
            {coords = vector3(-1583.0, -1035.0, 13.0), name = "Beach Resort"},
            {coords = vector3(-1506.0, -937.0, 13.0), name = "Beach Pier"}
        },
        basePayment = 180,
        baseXP = 60,
        distanceMultiplier = 0.10
    },
    {
        name = "Vinewood Circuit",
        level = 4, -- Advanced route
        vehicleModel = 'mid60lf', -- Coach bus for celebrity routes
        stops = {
            {coords = vector3(689.0, 601.0, 128.0), name = "Vinewood Hills"},
            {coords = vector3(115.0, 568.0, 183.0), name = "Richards Majestic"},
            {coords = vector3(-497.0, 527.0, 120.0), name = "Vinewood Sign"},
            {coords = vector3(-1334.0, 453.0, 100.0), name = "Galileo Observatory"}
        },
        basePayment = 300,
        baseXP = 120,
        distanceMultiplier = 0.15
    },
    {
        name = "Mirror Park Loop",
        level = 2, -- Beginner intermediate route
        vehicleModel = 'co1', -- Standard bus
        stops = {
            {coords = vector3(1054.0, -806.0, 30.0), name = "Mirror Park"},
            {coords = vector3(1244.0, -1041.0, 36.0), name = "East Vinewood"},
            {coords = vector3(1073.0, -1138.0, 28.0), name = "Murrieta Heights"},
            {coords = vector3(916.0, -1032.0, 34.0), name = "Hawick"}
        },
        basePayment = 160,
        baseXP = 55,
        distanceMultiplier = 0.11
    },
    {
        name = "Textile City Express",
        level = 3, -- Intermediate industrial route
        vehicleModel = 'bus', -- Standard bus for industrial areas
        stops = {
            {coords = vector3(718.0, -962.0, 30.0), name = "Textile City"},
            {coords = vector3(406.0, -1311.0, 46.0), name = "Cypress Flats"},
            {coords = vector3(336.0, -1580.0, 29.0), name = "La Mesa"},
            {coords = vector3(479.0, -1751.0, 28.0), name = "Mission Row"}
        },
        basePayment = 140,
        baseXP = 50,
        distanceMultiplier = 0.09
    },
    {
        name = "Paleto Bay Rural",
        level = 6, -- Expert route requiring high level
        vehicleModel = 'coach', -- Coach bus for long rural routes
        stops = {
            {coords = vector3(-168.0, 6429.0, 31.0), name = "Paleto Bay"},
            {coords = vector3(1689.0, 6429.0, 32.0), name = "Grapeseed"},
            {coords = vector3(2549.0, 4668.0, 34.0), name = "Mount Chiliad Base"},
            {coords = vector3(1673.0, 4815.0, 42.0), name = "Altruist Camp"}
        },
        basePayment = 400,
        baseXP = 150,
        distanceMultiplier = 0.25
    },
    {
        name = "Del Perro Luxury",
        level = 7, -- High-level luxury route
        vehicleModel = 'tourbus', -- Tour bus for luxury routes
        stops = {
            {coords = vector3(-1661.0, -541.0, 35.0), name = "Del Perro Pier"},
            {coords = vector3(-1894.0, -572.0, 20.0), name = "Vespucci Beach"},
            {coords = vector3(-2085.0, -1016.0, 15.0), name = "Pacific Bluffs"},
            {coords = vector3(-1850.0, -1230.0, 15.0), name = "Richman"}
        },
        basePayment = 500,
        baseXP = 180,
        distanceMultiplier = 0.20
    },
    {
        name = "Sandy Shores Desert",
        level = 8, -- Expert desert route
        vehicleModel = 'coach', -- Coach bus for desert conditions
        stops = {
            {coords = vector3(1961.0, 3740.0, 32.0), name = "Sandy Shores"},
            {coords = vector3(2510.0, 4109.0, 38.0), name = "Grand Senora Desert"},
            {coords = vector3(2939.0, 4624.0, 48.0), name = "Mount Gordo"},
            {coords = vector3(2365.0, 4961.0, 42.0), name = "Raton Canyon"}
        },
        basePayment = 600,
        baseXP = 200,
        distanceMultiplier = 0.30
    },
    {
        name = "Morningwood Residential",
        level = 2, -- Easy residential route
        vehicleModel = 'bus', -- Standard bus for residential areas
        stops = {
            {coords = vector3(-1436.0, -653.0, 28.0), name = "Morningwood"},
            {coords = vector3(-1285.0, -841.0, 25.0), name = "Rockford Hills"},
            {coords = vector3(-887.0, -1073.0, 20.0), name = "West Vinewood"},
            {coords = vector3(-1174.0, -1571.0, 15.0), name = "Burton"}
        },
        basePayment = 130,
        baseXP = 45,
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
