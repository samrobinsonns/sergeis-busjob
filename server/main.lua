-- Savana Bus Job - Recreated Server Script
-- Handles job completion, rewards, and XP system

local playerXP = {} -- Cache for player XP levels

-- Cache for player jobs completed
local playerJobsCompleted = {}

-- Function to get player XP and jobs completed with better error handling
function GetPlayerXP(source)
    local player = Framework:GetPlayer(source)
    if not player then
        print("[ERROR] Sergei Bus: Player not found for source " .. tostring(source))
        return 0
    end

    local identifier = Framework:GetPlayerIdentifier(player)
    if not identifier then
        print("[ERROR] Sergei Bus: No identifier found for player " .. tostring(source))
        return 0
    end

    print("[DEBUG] Sergei Bus: Getting XP for player " .. tostring(source) .. " with identifier: " .. identifier)

    -- Check cache first
    if playerXP[identifier] then
        print("[DEBUG] Sergei Bus: XP from cache for " .. identifier .. ": " .. playerXP[identifier])
        return playerXP[identifier]
    end

    -- Query database with error handling
    local success, result = pcall(function()
        return MySQL.query.await('SELECT bus_xp, jobs_completed FROM sergei_bus_xp WHERE identifier = ?', {identifier})
    end)

    if success and result and result[1] then
        local xp = result[1].bus_xp or 0
        local jobs = result[1].jobs_completed or 0
        playerXP[identifier] = xp
        playerJobsCompleted[identifier] = jobs
        print("[DEBUG] Sergei Bus: XP from database for " .. identifier .. ": " .. xp .. ", Jobs: " .. jobs)
        return xp
    elseif success then
        -- Player not found in database, create entry
        print("[DEBUG] Sergei Bus: Creating new XP entry for " .. identifier)
        local insertSuccess, insertResult = pcall(function()
            MySQL.update('INSERT INTO sergei_bus_xp (identifier, bus_xp, jobs_completed) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE bus_xp = VALUES(bus_xp), jobs_completed = VALUES(jobs_completed)', {identifier, 0, 0})
        end)

        if not insertSuccess then
            print("[ERROR] Sergei Bus: Failed to create XP entry: " .. tostring(insertResult))
        else
            print("[DEBUG] Sergei Bus: Successfully created XP entry for " .. identifier)
        end

        playerXP[identifier] = 0
        playerJobsCompleted[identifier] = 0
        return 0
    else
        print("[ERROR] Sergei Bus: Database query failed for " .. identifier .. ": " .. tostring(result))
        return 0
    end
end

-- Function to get player jobs completed
function GetPlayerJobsCompleted(source)
    local player = Framework:GetPlayer(source)
    if not player then
        return 0
    end

    local identifier = Framework:GetPlayerIdentifier(player)
    if not identifier then
        return 0
    end

    -- Check cache first
    if playerJobsCompleted[identifier] then
        return playerJobsCompleted[identifier]
    end

    -- GetPlayerXP also loads jobs_completed, so if it's not in cache, we need to call it
    GetPlayerXP(source)
    return playerJobsCompleted[identifier] or 0
end

-- Function to set player XP with error handling
function SetPlayerXP(source, xp)
    local player = Framework:GetPlayer(source)
    local identifier = Framework:GetPlayerIdentifier(player)

    if not identifier then
        if shared.debug then
            print("[DEBUG] Sergei Bus: Cannot set XP - no identifier for player " .. tostring(source))
        end
        return
    end

    -- Update cache
    playerXP[identifier] = xp

    -- Save to database with error handling (preserve jobs_completed)
    local success, error = pcall(function()
        local jobs = playerJobsCompleted[identifier] or 0
        MySQL.update('INSERT INTO sergei_bus_xp (identifier, bus_xp, jobs_completed) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE bus_xp = VALUES(bus_xp), jobs_completed = VALUES(jobs_completed)', {identifier, xp, jobs})
    end)

    if success then
        if shared.debug then
            print("[DEBUG] Sergei Bus: Saved XP for " .. identifier .. ": " .. xp)
        end
    else
        if shared.debug then
            print("[DEBUG] Sergei Bus: Failed to save XP for " .. identifier .. ": " .. tostring(error))
        end
    end
end

-- Function to increment jobs completed
function IncrementPlayerJobsCompleted(source)
    local player = Framework:GetPlayer(source)
    if not player then
        print("[ERROR] Sergei Bus: Player not found for source " .. tostring(source))
        return
    end

    local identifier = Framework:GetPlayerIdentifier(player)
    if not identifier then
        print("[ERROR] Sergei Bus: No identifier found for player " .. tostring(source))
        return
    end

    -- Get current jobs completed count
    local currentJobs = GetPlayerJobsCompleted(source)
    local newJobsCount = currentJobs + 1

    -- Update cache
    playerJobsCompleted[identifier] = newJobsCount

    -- Save to database
    local success, error = pcall(function()
        MySQL.update('INSERT INTO sergei_bus_xp (identifier, jobs_completed) VALUES (?, ?) ON DUPLICATE KEY UPDATE jobs_completed = VALUES(jobs_completed)', {identifier, newJobsCount})
    end)

    if success then
        print("[DEBUG] Sergei Bus: Incremented jobs completed for " .. identifier .. ": " .. currentJobs .. " -> " .. newJobsCount)
    else
        print("[ERROR] Sergei Bus: Failed to save jobs completed for " .. identifier .. ": " .. tostring(error))
    end

    return newJobsCount
end

-- Function to add XP to player
function AddPlayerXP(source, xp)
    local currentXP = GetPlayerXP(source)
    local newXP = currentXP + xp

    SetPlayerXP(source, newXP)

    return newXP
end

-- Function to get player level from XP (config-driven)
function GetPlayerLevel(xp)
    if not Config or not Config.Leveling or not Config.Leveling.levels then
        print("[DEBUG] Sergei Bus: Config not loaded, using fallback calculation for XP: " .. xp)
        -- Fallback to simple calculation if config not loaded
        if xp < 100 then return 1
        elseif xp < 300 then return 2
        elseif xp < 600 then return 3
        elseif xp < 1000 then return 4  -- 600-999 XP = Level 4
        elseif xp < 1500 then return 5  -- 1000-1499 XP = Level 5
        elseif xp < 2100 then return 6  -- 1500-2099 XP = Level 6
        elseif xp < 2800 then return 7  -- 2100-2799 XP = Level 7
        elseif xp < 3600 then return 8  -- 2800-3599 XP = Level 8
        elseif xp < 4500 then return 9  -- 3600-4499 XP = Level 9
        else return 10 end  -- 4500+ XP = Level 10
    end

    -- Use config-driven level calculation
    local levels = Config.Leveling.levels
    local maxLevel = Config.Leveling.maxLevel or 10

    print("[DEBUG] Sergei Bus: Using config calculation for XP: " .. xp .. ", maxLevel: " .. maxLevel)

    for level = maxLevel, 1, -1 do
        if levels[level] and xp >= levels[level].xp then
            print("[DEBUG] Sergei Bus: Player level " .. level .. " (XP: " .. xp .. " >= " .. levels[level].xp .. ")")
            return level
        end
    end

    return 1 -- Default to level 1
end

-- Event handler for job completion
RegisterNetEvent('sergeis-bus:server:completeJob', function(zoneIndex, jobIndex)
    local src = source
    local player = Framework:GetPlayer(src)

    if not player then
        if shared.debug then
            print("[DEBUG] Sergei Bus: Player not found for job completion")
        end
        return
    end

    -- Load config if not available
    if not Config then
        if shared.debug then
            print("[DEBUG] Sergei Bus: Config not loaded in server for job completion, loading from file...")
        end
        local configChunk, loadError = load(LoadResourceFile(GetCurrentResourceName(), 'config.lua'))
        if configChunk then
            local success, result = pcall(configChunk)
            if not success then
                print("[ERROR] Sergei Bus: Failed to execute config in server: " .. tostring(result))
                return
            end
        else
            print("[ERROR] Sergei Bus: Failed to load config file in server: " .. tostring(loadError))
            return
        end
    end

    -- Get job from config (adjust for 1-based indexing)
    local routeIndex = jobIndex + 1 -- Convert from 0-based to 1-based
    local route = Config.Routes and Config.Routes[routeIndex]

    if not route then
        if shared.debug then
            print("[DEBUG] Sergei Bus: Invalid route index " .. routeIndex .. " (jobIndex: " .. jobIndex .. ")")
        end
        Framework:Notify(src, "Error: Route not found!", "error")
        return
    end

    if shared.debug then
        print("[DEBUG] Sergei Bus: Processing job completion for " .. GetPlayerName(src) .. " - " .. route.name)
    end

    -- Check if player meets level requirement
    local playerXP = GetPlayerXP(src)
    local playerLevel = GetPlayerLevel(playerXP)
    local requiredLevel = route.level or 1

    if playerLevel < requiredLevel then
        Framework:Notify(src, string.format("You need to be level %d to do this job!", requiredLevel), "error")
        if shared.debug then
            print("[DEBUG] Sergei Bus: Player level check failed - Required: " .. requiredLevel .. " Current: " .. playerLevel)
        end
        return
    end

    -- Award money
    local payment = route.basePayment or 0
    Framework:AddMoney(src, "cash", payment)

    -- Award XP
    local xpReward = route.baseXP or 0
    local newXP = AddPlayerXP(src, xpReward)
    local newLevel = GetPlayerLevel(newXP)

    -- Increment jobs completed counter
    local newJobsCount = IncrementPlayerJobsCompleted(src)

    -- Check for level up
    if newLevel > playerLevel then
        Framework:Notify(src, string.format("🎉 Level Up! You are now level %d!", newLevel), "success")
        if shared.debug then
            print("[DEBUG] Sergei Bus: Player leveled up from " .. playerLevel .. " to " .. newLevel)
        end
    end

    -- Send completion message
    Framework:Notify(src, string.format("Route completed! You earned $%d and %d XP", payment, xpReward), "success")
    Framework:Notify(src, string.format("Jobs Completed: %d", newJobsCount), "info")

    if shared.debug then
        print("[DEBUG] Sergei Bus: Player " .. GetPlayerName(src) .. " completed " .. route.name .. ": +$" .. payment .. ", +" .. xpReward .. " XP, Total Jobs: " .. newJobsCount)
    end

    -- Update client stats
    TriggerClientEvent('sergeis-bus:client:updatePlayerLevel', src, newLevel, newXP, {
        level = newLevel,
        xp = newXP,
        jobs = newJobsCount
    })
end)

-- Event handler for getting player level (for client-side checks)
RegisterNetEvent('sergeis-bus:server:getPlayerLevel', function()
    local src = source
    local playerXP = GetPlayerXP(src)
    local playerLevel = GetPlayerLevel(playerXP)

    -- Get complete stats including XP to next level (call function directly)
    local xpForNextLevel = 0
    local nextLevelXP = 0

    print("[DEBUG] Sergei Bus: Calculating XP for player " .. GetPlayerName(src) .. " - Level: " .. playerLevel .. ", XP: " .. playerXP)

    -- Calculate XP needed for next level using config
    if Config and Config.Leveling and Config.Leveling.levels then
        local levels = Config.Leveling.levels
        local maxLevel = Config.Leveling.maxLevel or 10

        print("[DEBUG] Sergei Bus: Using config for XP calculation - maxLevel: " .. maxLevel)

        if playerLevel < maxLevel and levels[playerLevel + 1] then
            nextLevelXP = levels[playerLevel + 1].xp
            xpForNextLevel = nextLevelXP - playerXP
            print("[DEBUG] Sergei Bus: Next level XP: " .. nextLevelXP .. ", XP to next: " .. xpForNextLevel)
        else
            print("[DEBUG] Sergei Bus: Player at max level or next level not found")
        end
    else
        print("[DEBUG] Sergei Bus: Config not available, using fallback calculation")
        -- Fallback calculation
        if playerLevel < 10 then
            local fallbackXP = {100, 300, 600, 1000, 1500, 2100, 2800, 3600, 4500, 5500}
            nextLevelXP = fallbackXP[playerLevel] or 5500
            xpForNextLevel = nextLevelXP - playerXP
            print("[DEBUG] Sergei Bus: Fallback - Next level XP: " .. nextLevelXP .. ", XP to next: " .. xpForNextLevel)
        end
    end

    -- Get jobs completed count
    local jobsCompleted = GetPlayerJobsCompleted(src)

    local stats = {
        level = playerLevel,
        xp = playerXP,
        xpForNextLevel = math.max(0, xpForNextLevel),
        nextLevelXP = nextLevelXP,
        jobs = jobsCompleted
    }

    print("[DEBUG] Sergei Bus: Final stats - Level: " .. playerLevel .. ", XP: " .. playerXP .. ", XP to next: " .. stats.xpForNextLevel .. ", Next level XP: " .. nextLevelXP .. ", Jobs: " .. jobsCompleted)

    TriggerClientEvent('sergeis-bus:client:updatePlayerLevel', src, playerLevel, playerXP, stats)
end)

-- Function to check if player can do job
function CanPlayerDoJob(source, requiredLevel)
    local playerXP = GetPlayerXP(source)
    local playerLevel = GetPlayerLevel(playerXP)

    return playerLevel >= requiredLevel
end

-- Callback for client to check job requirements
lib.callback.register('sergeis-bus:server:canDoJob', function(source, zoneIndex, jobIndex)
    -- First try to get job from shared data (legacy support)
    local zone = shared.BusJob[zoneIndex]
    if zone and zone.Jobs and zone.Jobs[jobIndex] then
        local job = zone.Jobs[jobIndex]
        if job and job.level then
            return CanPlayerDoJob(source, job.level)
        end
    end

    -- If not found in shared data, try to get from config routes
    if Config and Config.Routes and Config.Routes[jobIndex] then
        local route = Config.Routes[jobIndex]
        if route and route.level then
            return CanPlayerDoJob(source, route.level)
        else
            -- If no level specified in config, assume level 1 (available to all)
            return CanPlayerDoJob(source, 1)
        end
    end

    -- Fallback: assume job is available (level 1)
    if shared.debug then
        print("[DEBUG] Sergei Bus: Job not found in shared data or config, allowing job")
    end
    return CanPlayerDoJob(source, 1)
end)

-- Function to get job info
lib.callback.register('sergeis-bus:server:getJobInfo', function(source, zoneIndex, jobIndex)
    local zone = shared.BusJob[zoneIndex]
    if not zone then return nil end

    local job = zone.Jobs[jobIndex]
    if not job then return nil end

    local playerXP = GetPlayerXP(source)
    local playerLevel = GetPlayerLevel(playerXP)

    return {
        name = job.name,
        level = job.level,
        xp = job.xp,
        totalPrice = job.totalPrice,
        playerLevel = playerLevel,
        canDoJob = playerLevel >= job.level,
        stops = #job.stops
    }
end)

-- Function to get all player stats
lib.callback.register('sergeis-bus:server:getPlayerStats', function(source)
    local playerXP = GetPlayerXP(source)
    local playerLevel = GetPlayerLevel(playerXP)
    local xpForNextLevel = 0
    local nextLevelXP = 0

    -- Calculate XP needed for next level using config
    if Config and Config.Leveling and Config.Leveling.levels then
        local levels = Config.Leveling.levels
        local maxLevel = Config.Leveling.maxLevel or 10

        if playerLevel < maxLevel and levels[playerLevel + 1] then
            nextLevelXP = levels[playerLevel + 1].xp
            xpForNextLevel = nextLevelXP - playerXP
        end
    else
        -- Fallback calculation
        if playerLevel < 5 then
            local fallbackXP = {100, 300, 600, 1000, 1500}
            nextLevelXP = fallbackXP[playerLevel] or 1500
            xpForNextLevel = nextLevelXP - playerXP
        end
    end

    return {
        level = playerLevel,
        xp = playerXP,
        xpForNextLevel = math.max(0, xpForNextLevel),
        nextLevelXP = nextLevelXP
    }
end)

-- Function to get routes from config
lib.callback.register('sergeis-bus:server:getRoutes', function(source)
    if shared.debug then
        print("[DEBUG] Sergei Bus: getRoutes callback called by source: " .. tostring(source))
    end

    -- Ensure Config is loaded
    if not Config then
        if shared.debug then
            print("[DEBUG] Sergei Bus: Config not loaded, loading from file...")
        end

        -- Load config directly from file
        local configChunk, loadError = load(LoadResourceFile(GetCurrentResourceName(), 'config.lua'))
        if configChunk then
            local success, result = pcall(configChunk)
            if success then
                if shared.debug then
                    print("[DEBUG] Sergei Bus: Config loaded successfully from file")
                end
            else
                if shared.debug then
                    print("[ERROR] Sergei Bus: Failed to execute config: " .. tostring(result))
                end
                return {}
            end
        else
            if shared.debug then
                print("[ERROR] Sergei Bus: Failed to load config file: " .. tostring(loadError))
            end
            return {}
        end
    end

    -- Return routes from config
    if Config and Config.Routes then
        if shared.debug then
            print("[DEBUG] Sergei Bus: Returning " .. #Config.Routes .. " routes from config")
            for i, route in ipairs(Config.Routes) do
                local levelText = route.level and (" (Level " .. route.level .. ")") or " (No level req)"
                print("[DEBUG] Sergei Bus: Route " .. i .. ": " .. route.name .. levelText .. " - " .. #route.stops .. " stops")

                -- Debug stop coordinates
                if route.stops and #route.stops > 0 then
                    for j, stop in ipairs(route.stops) do
                        if stop.coords then
                            print("[DEBUG] Sergei Bus: Route " .. i .. " stop " .. j .. " coords: x=" .. stop.coords.x .. ", y=" .. stop.coords.y .. ", z=" .. stop.coords.z)
                        elseif stop.x then
                            print("[DEBUG] Sergei Bus: Route " .. i .. " stop " .. j .. " direct: x=" .. stop.x .. ", y=" .. stop.y .. ", z=" .. stop.z)
                        end
                    end
                end
            end
        end
        return Config.Routes
    else
        if shared.debug then
            print("[ERROR] Sergei Bus: Config.Routes is nil or empty")
        end
        return {}
    end
end)

-- Command to check player stats
RegisterCommand('busstats', function(source)
    if source == 0 then return end -- Don't run from console

    -- Get player stats directly (not using callback system)
    local playerXP = GetPlayerXP(source)
    local playerLevel = GetPlayerLevel(playerXP)
    local jobsCompleted = GetPlayerJobsCompleted(source)
    local xpForNextLevel = 0
    local nextLevelXP = 0

    -- Calculate XP needed for next level using config
    if Config and Config.Leveling and Config.Leveling.levels then
        local levels = Config.Leveling.levels
        local maxLevel = Config.Leveling.maxLevel or 10

        if playerLevel < maxLevel and levels[playerLevel + 1] then
            nextLevelXP = levels[playerLevel + 1].xp
            xpForNextLevel = nextLevelXP - playerXP
        end
    else
        -- Fallback calculation
        if playerLevel < 5 then
            local fallbackXP = {100, 300, 600, 1000, 1500}
            nextLevelXP = fallbackXP[playerLevel] or 1500
            xpForNextLevel = nextLevelXP - playerXP
        end
    end

    Framework:Notify(source, string.format("Bus Driver Level: %d | XP: %d | XP to next: %d | Jobs: %d",
        playerLevel, playerXP, math.max(0, xpForNextLevel), jobsCompleted), "info")
end, false)

-- Admin command to set player XP
RegisterCommand('setbusxp', function(source, args)
    if source == 0 then return end -- Don't run from console

    -- Add your admin permission check here
    -- if not IsPlayerAceAllowed(source, "admin") then return end

    if not args[1] or not args[2] then
        Framework:Notify(source, "Usage: /setbusxp [playerid] [xp]", "error")
        return
    end

    local target = tonumber(args[1])
    local xp = tonumber(args[2])

    if not target or not xp then
        Framework:Notify(source, "Invalid arguments", "error")
        return
    end

    SetPlayerXP(target, xp)
    Framework:Notify(source, string.format("Set player %d bus XP to %d", target, xp), "success")
    Framework:Notify(target, string.format("Your bus XP has been set to %d", xp), "info")
end, false)

-- Always ensure database table exists on resource start
Citizen.CreateThread(function()
    -- Check if Config is loaded
    print("[DEBUG] Sergei Bus: Checking if Config is loaded...")
    if Config then
        print("^2[SUCCESS] Sergei Bus: Config loaded successfully^0")
        if Config.Leveling and Config.Leveling.levels then
            print("[DEBUG] Sergei Bus: Leveling config found with " .. Config.Leveling.maxLevel .. " max levels")
        else
            print("^3[WARNING] Sergei Bus: Leveling config not found in Config^0")
        end
    else
        print("^1[ERROR] Sergei Bus: Config is nil - config.lua not loaded!^0")
    end

    -- Wait for database connection with retry mechanism
    local retries = 0
    local maxRetries = 10

    while retries < maxRetries do
        local success, result = pcall(function()
            return MySQL.query('SELECT 1')
        end)

        if success then
            break
        end

        retries = retries + 1
        Wait(1000)

        print("Sergei Bus Job: Waiting for database connection... Attempt " .. retries .. "/" .. maxRetries)
    end

    if retries >= maxRetries then
        print("^1[ERROR] Sergei Bus Job: Failed to connect to database after " .. maxRetries .. " attempts!^0")
        return
    end

    print("^2[SUCCESS] Sergei Bus Job: Database connection established^0")

    -- Always check and create table if needed
    local checkSuccess, tableExists = pcall(function()
        local result = MySQL.query('SHOW TABLES LIKE "sergei_bus_xp"')
        return result and #result > 0
    end)

    if checkSuccess and tableExists then
        print("^3Sergei Bus Job: Database table 'sergei_bus_xp' already exists^0")

        -- Check if jobs_completed column exists and add it if it doesn't
        local columnCheck, columnResult = pcall(function()
            local result = MySQL.query("SHOW COLUMNS FROM `sergei_bus_xp` LIKE 'jobs_completed'")
            return result and #result > 0
        end)

        if columnCheck and not columnResult then
            print("^3[INFO] Sergei Bus Job: Adding jobs_completed column to existing table...^0")
            local alterSuccess, alterError = pcall(function()
                MySQL.query("ALTER TABLE `sergei_bus_xp` ADD COLUMN `jobs_completed` int(11) NOT NULL DEFAULT 0")
            end)

            if alterSuccess then
                print("^2[SUCCESS] Sergei Bus Job: Added jobs_completed column to existing table!^0")
            else
                print("^1[ERROR] Sergei Bus Job: Failed to add jobs_completed column: " .. tostring(alterError) .. "^0")
            end
        end
    elseif checkSuccess and not tableExists then
        print("^3[INFO] Sergei Bus Job: Database table 'sergei_bus_xp' does not exist, creating...^0")

        -- Create table
        local success, error = pcall(function()
            MySQL.query([[
                CREATE TABLE IF NOT EXISTS `sergei_bus_xp` (
                    `id` int(11) NOT NULL AUTO_INCREMENT,
                    `identifier` varchar(50) NOT NULL,
                    `bus_xp` int(11) NOT NULL DEFAULT 0,
                    `jobs_completed` int(11) NOT NULL DEFAULT 0,
                    `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    PRIMARY KEY (`id`),
                    UNIQUE KEY `identifier` (`identifier`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
            ]])
        end)

        if success then
            print("^2[SUCCESS] Sergei Bus Job: Database table 'sergei_bus_xp' created successfully!^0")
        else
            print("^1[ERROR] Sergei Bus Job: Failed to create database table: " .. tostring(error) .. "^0")
        end
    elseif not checkSuccess then
        print("^1[ERROR] Sergei Bus Job: Failed to check if table exists: " .. tostring(tableExists) .. "^0")
    end
end)

-- Function to save all cached XP and jobs completed on server shutdown
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    if shared.debug then
        print("Saving player XP and jobs data...")
    end

    -- Save cached XP and jobs data
    for identifier, xp in pairs(playerXP) do
        local jobs = playerJobsCompleted[identifier] or 0
        MySQL.update('INSERT INTO sergei_bus_xp (identifier, bus_xp, jobs_completed) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE bus_xp = VALUES(bus_xp), jobs_completed = VALUES(jobs_completed)', {identifier, xp, jobs})
    end

    if shared.debug then
        print("Player XP and jobs data saved")
    end
end)

-- Debug command
if shared.debug then
    RegisterCommand('busdebug', function(source)
        if source == 0 then return end

        local playerXP = GetPlayerXP(source)
        local playerLevel = GetPlayerLevel(playerXP)

        print(string.format("Player %s - Level: %d, XP: %d", GetPlayerName(source), playerLevel, playerXP))
        Framework:Notify(source, string.format("Debug - Level: %d, XP: %d", playerLevel, playerXP), "info")
    end, false)

    -- Command to manually create/check database table
    RegisterCommand('busdbcheck', function(source)
        if source == 0 then
            print("Checking database table...")

            -- Check if table exists
            local checkSuccess, tableExists = pcall(function()
                local result = MySQL.query('SHOW TABLES LIKE "sergei_bus_xp"')
                return result and #result > 0
            end)

            if checkSuccess and tableExists then
                print("^2[SUCCESS] Sergei Bus: Database table 'sergei_bus_xp' exists!^0")
            elseif checkSuccess and not tableExists then
                print("^3[WARNING] Sergei Bus: Database table 'sergei_bus_xp' does not exist, creating...^0")

                -- Create table
                local success, error = pcall(function()
                    MySQL.query([[
                        CREATE TABLE IF NOT EXISTS `sergei_bus_xp` (
                            `id` int(11) NOT NULL AUTO_INCREMENT,
                            `identifier` varchar(50) NOT NULL,
                            `bus_xp` int(11) NOT NULL DEFAULT 0,
                            `jobs_completed` int(11) NOT NULL DEFAULT 0,
                            `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                            PRIMARY KEY (`id`),
                            UNIQUE KEY `identifier` (`identifier`)
                        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
                    ]])
                end)

                if success then
                    print("^2[SUCCESS] Sergei Bus: Database table created successfully!^0")
                else
                    print("^1[ERROR] Sergei Bus: Failed to create database table: " .. tostring(error) .. "^0")
                end
            elseif not checkSuccess then
                print("^1[ERROR] Sergei Bus: Failed to check if table exists: " .. tostring(tableExists) .. "^0")
            end
        else
            Framework:Notify(source, "This command is console only", "error")
        end
    end, false)
end
