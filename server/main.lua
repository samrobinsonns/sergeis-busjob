-- Savana Bus Job - Recreated Server Script
-- Handles job completion, rewards, and XP system

local playerXP = {} -- Cache for player XP levels

-- Function to get player XP (you'll need to implement database storage)
function GetPlayerXP(source)
    local identifier = Framework:GetPlayerIdentifier(Framework:GetPlayer(source))

    if not identifier then return 0 end

    -- Check cache first
    if playerXP[identifier] then
        return playerXP[identifier]
    end

    -- Query database (example - adjust based on your database setup)
    local result = MySQL.query.await('SELECT bus_xp FROM sergei_bus_xp WHERE identifier = ?', {identifier})

    if result and result[1] then
        playerXP[identifier] = result[1].bus_xp or 0
        return playerXP[identifier]
    end

    return 0
end

-- Function to set player XP
function SetPlayerXP(source, xp)
    local identifier = Framework:GetPlayerIdentifier(Framework:GetPlayer(source))

    if not identifier then return end

    playerXP[identifier] = xp

    -- Save to database (example - adjust based on your database setup)
    MySQL.update('INSERT INTO sergei_bus_xp (identifier, bus_xp) VALUES (?, ?) ON DUPLICATE KEY UPDATE bus_xp = ?', {identifier, xp, xp})
end

-- Function to add XP to player
function AddPlayerXP(source, xp)
    local currentXP = GetPlayerXP(source)
    local newXP = currentXP + xp

    SetPlayerXP(source, newXP)

    return newXP
end

-- Function to get player level from XP
function GetPlayerLevel(xp)
    -- Simple level calculation - adjust as needed
    if xp < 100 then return 1
    elseif xp < 300 then return 2
    elseif xp < 600 then return 3
    elseif xp < 1000 then return 4
    elseif xp < 1500 then return 5
    elseif xp < 2200 then return 6
    elseif xp < 3000 then return 7
    elseif xp < 4000 then return 8
    elseif xp < 5200 then return 9
    elseif xp < 6600 then return 10
    elseif xp < 8200 then return 11
    elseif xp < 10000 then return 12
    elseif xp < 12000 then return 13
    elseif xp < 14200 then return 14
    elseif xp < 16600 then return 15
    elseif xp < 19200 then return 16
    elseif xp < 22000 then return 17
    elseif xp < 25000 then return 18
    elseif xp < 28200 then return 19
    elseif xp < 31600 then return 20
    else return 20 end -- Max level
end

-- Event handler for job completion
RegisterNetEvent('sergeis-bus:server:completeJob', function(zoneIndex, jobIndex)
    local src = source
    local player = Framework:GetPlayer(src)

    if not player then return end

    local zone = shared.BusJob[zoneIndex]
    if not zone then return end

    local job = zone.Jobs[jobIndex]
    if not job then return end

    -- Check if player meets level requirement
    local playerXP = GetPlayerXP(src)
    local playerLevel = GetPlayerLevel(playerXP)

    if playerLevel < job.level then
        Framework:Notify(src, string.format("You need to be level %d to do this job!", job.level), "error")
        return
    end

    -- Award money
    Framework:AddMoney(src, "cash", job.totalPrice)

    -- Award XP
    local newXP = AddPlayerXP(src, job.xp)
    local newLevel = GetPlayerLevel(newXP)

    -- Check for level up
    if newLevel > playerLevel then
        Framework:Notify(src, string.format("🎉 Level Up! You are now level %d!", newLevel), "success")
    end

    -- Send completion message
    Framework:Notify(src, string.format(shared.Locales["xpAndMoney"], job.totalPrice, job.xp), "success")

    if shared.debug then
        print(string.format("Player %s completed bus job: +$%d, +%d XP", GetPlayerName(src), job.totalPrice, job.xp))
    end
end)

-- Event handler for getting player level (for client-side checks)
RegisterNetEvent('sergeis-bus:server:getPlayerLevel', function()
    local src = source
    local playerXP = GetPlayerXP(src)
    local playerLevel = GetPlayerLevel(playerXP)

    TriggerClientEvent('sergeis-bus:client:updatePlayerLevel', src, playerLevel, playerXP)
end)

-- Function to check if player can do job
function CanPlayerDoJob(source, requiredLevel)
    local playerXP = GetPlayerXP(source)
    local playerLevel = GetPlayerLevel(playerXP)

    return playerLevel >= requiredLevel
end

-- Callback for client to check job requirements
lib.callback.register('sergeis-bus:server:canDoJob', function(source, zoneIndex, jobIndex)
    local zone = shared.BusJob[zoneIndex]
    if not zone then return false end

    local job = zone.Jobs[jobIndex]
    if not job then return false end

    return CanPlayerDoJob(source, job.level)
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

    -- Calculate XP needed for next level
    if playerLevel < 20 then
        local levelXP = {
            100, 300, 600, 1000, 1500, 2200, 3000, 4000, 5200, 6600,
            8200, 10000, 12000, 14200, 16600, 19200, 22000, 25000, 28200, 31600
        }
        xpForNextLevel = levelXP[playerLevel] - playerXP
    end

    return {
        level = playerLevel,
        xp = playerXP,
        xpForNextLevel = xpForNextLevel
    }
end)

-- Command to check player stats
RegisterCommand('busstats', function(source)
    if source == 0 then return end -- Don't run from console

    local stats = lib.callback.await('sergeis-bus:server:getPlayerStats', source)

    Framework:Notify(source, string.format("Bus Driver Level: %d | XP: %d | XP to next: %d",
        stats.level, stats.xp, stats.xpForNextLevel), "info")
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

-- Function to initialize database table if it doesn't exist
Citizen.CreateThread(function()
    Wait(1000) -- Wait for database connection

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `sergei_bus_xp` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `identifier` varchar(50) NOT NULL,
            `bus_xp` int(11) NOT NULL DEFAULT 0,
            `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `identifier` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
    ]])

    if shared.debug then
        print("Bus job database table initialized")
    end
end)

-- Function to save all cached XP on server shutdown
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    if shared.debug then
        print("Saving player XP data...")
    end

    -- Save cached XP data
    for identifier, xp in pairs(playerXP) do
        MySQL.update('INSERT INTO sergei_bus_xp (identifier, bus_xp) VALUES (?, ?) ON DUPLICATE KEY UPDATE bus_xp = ?', {identifier, xp, xp})
    end

    if shared.debug then
        print("Player XP data saved")
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
end
