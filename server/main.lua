local QBCore = exports['qb-core']:GetCoreObject()

-- Local variables
local playerRouteAttempts = {}
local playerRouteCooldowns = {}

-- Initialize when resource starts
Citizen.CreateThread(function()
    -- Wait for QBCore to be ready
    while not QBCore do
        QBCore = exports['qb-core']:GetCoreObject()
        Citizen.Wait(100)
    end
    
    -- Clean up old route attempts every hour
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(3600000) -- 1 hour
            CleanupOldRouteAttempts()
        end
    end)
    
    if Config.Debug.enabled then
        print('[BUS SERVER] Server initialized successfully')
    end
end)

-- Event handlers
RegisterNetEvent('bus:getPlayerStats')
AddEventHandler('bus:getPlayerStats', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    local playerName = Player.PlayerData.name
    
    -- Get player stats from database using oxmysql
    exports.oxmysql:execute('SELECT * FROM bus_jobs WHERE citizenid = ?', {citizenid}, function(result)
        local stats = {
            level = 1,
            xp = 0,
            cash = Player.PlayerData.money.cash or 0,
            distance = 0.0,
            jobs = 0,
            title = 'Rookie Driver'
        }
        
        if result and result[1] then
            local data = result[1]
            stats.level = data.current_level
            stats.xp = data.total_xp
            stats.distance = data.total_distance
            stats.jobs = data.jobs_completed
            stats.title = GetPlayerTitle(data.current_level)
        end
        
        -- Send stats to client
        TriggerClientEvent('bus:updatePlayerStats', src, stats)
        
        -- Send routes data
        TriggerClientEvent('bus:updateRoutes', src, Config.Routes)
        
        -- Send leaderboard data
        LoadLeaderboardData(src)
    end)
end)

RegisterNetEvent('bus:checkRouteStart')
AddEventHandler('bus:checkRouteStart', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Check if player can start route
    if not canPlayerStartRoute(citizenid) then
        TriggerClientEvent('QBCore:Notify', src, 'You have reached the maximum routes per hour. Please wait.', 'error')
        return
    end
    
    -- Increment route attempts
    incrementPlayerRouteAttempts(citizenid)
    
    -- Allow route to start
    TriggerClientEvent('bus:routeStartAllowed', src)
end)

RegisterNetEvent('bus:completeRoute')
AddEventHandler('bus:completeRoute', function(routeData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    local playerName = Player.PlayerData.name
    
    -- Validate route data
    if not validateRouteData(routeData) then
        if Config.Debug.enabled then
            print(string.format('[BUS SERVER] Invalid route data from player %s', playerName))
        end
        return
    end
    
    -- Calculate total payment with level bonus
    local levelBonus = GetPlayerLevelBonus(citizenid)
    local finalPayment = math.floor(routeData.totalPayment * levelBonus)
    
    -- Add money to player
    Player.Functions.AddMoney(Config.PaymentSettings.defaultMethod, finalPayment, Config.PaymentSettings.paymentReason)
    
    -- Update database
    UpdatePlayerStats(citizenid, playerName, routeData, finalPayment)
    
    -- Notify player
    TriggerClientEvent('QBCore:Notify', src, string.format(Config.Messages.paymentReceived, 
        finalPayment, routeData.routePayment, routeData.passengerBonus), 'success')
    
    -- Check for level up
    CheckLevelUp(src, citizenid, routeData.xpEarned)
    
    if Config.Debug.enabled then
        print(string.format('[BUS SERVER] Route completed by %s: $%d, %d XP', 
            playerName, finalPayment, routeData.xpEarned))
    end
end)

-- Commands
QBCore.Commands.Add(Config.Commands.giveMoney, 'Give money to player (Admin Only)', {{name = 'id', help = 'Player ID'}, {name = 'amount', help = 'Amount'}}, true, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    if not Player.PlayerData.admin then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have permission to use this command.', 'error')
        return
    end
    
    local targetId = tonumber(args[1])
    local amount = tonumber(args[2])
    
    if not targetId or not amount then
        TriggerClientEvent('QBCore:Notify', src, 'Usage: /' .. Config.Commands.giveMoney .. ' [id] [amount]', 'error')
        return
    end
    
    local TargetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not TargetPlayer then
        TriggerClientEvent('QBCore:Notify', src, 'Player not found.', 'error')
        return
    end
    
    -- Add money to target player
    TargetPlayer.Functions.AddMoney(Config.PaymentSettings.defaultMethod, amount, Config.PaymentSettings.adminGiftReason)
    
    -- Update database stats
    exports.oxmysql:execute('UPDATE bus_jobs SET total_earnings = total_earnings + ? WHERE citizenid = ?', 
        {amount, TargetPlayer.PlayerData.citizenid})
    
    -- Notify both players
    TriggerClientEvent('QBCore:Notify', src, string.format('Gave $%d to %s', amount, TargetPlayer.PlayerData.name), 'success')
    TriggerClientEvent('QBCore:Notify', targetId, string.format('You received $%d from an admin', amount), 'success')
    
    if Config.Debug.enabled then
        print(string.format('[BUS SERVER] Admin %s gave $%d to %s', 
            Player.PlayerData.name, amount, TargetPlayer.PlayerData.name))
    end
end)

QBCore.Commands.Add(Config.Commands.help, 'Show bus job help', {}, false, function(source, args)
    local src = source
    
    for _, helpText in ipairs(Config.Messages.helpText) do
        TriggerClientEvent('QBCore:Notify', src, helpText, 'info')
        Citizen.Wait(1000)
    end
end)

QBCore.Commands.Add(Config.Commands.stats, 'Show your bus job statistics', {}, false, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    exports.oxmysql:execute('SELECT * FROM bus_jobs WHERE citizenid = ?', {citizenid}, function(result)
        if result and result[1] then
            local data = result[1]
            local stats = string.format('Level: %d | XP: %d | Jobs: %d | Distance: %.1f km | Earnings: $%d', 
                data.current_level, data.total_xp, data.jobs_completed, data.total_distance, data.total_earnings)
            TriggerClientEvent('QBCore:Notify', src, stats, 'primary')
        else
            TriggerClientEvent('QBCore:Notify', src, 'No statistics found. Complete your first route!', 'info')
        end
    end)
end)

-- Database functions
function UpdatePlayerStats(citizenid, playerName, routeData, finalPayment)
    -- Use stored procedure to update stats
    exports.oxmysql:execute('CALL UpdateBusJobStats(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        citizenid,
        playerName,
        routeData.routePayment,
        routeData.passengerBonus,
        finalPayment,
        routeData.passengersLoaded,
        routeData.distanceTraveled,
        routeData.xpEarned,
        routeData.completionTime,
        routeData.routeName
    }, function(result)
        if Config.Debug.enabled then
            print(string.format('[BUS SERVER] Updated stats for %s', playerName))
        end
    end)
end

function LoadLeaderboardData(src)
    -- Load weekly leaderboard
    exports.oxmysql:execute('SELECT * FROM bus_leaderboard WHERE period = ? AND period_start = DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY) ORDER BY rank LIMIT 10', 
        {'weekly'}, function(weeklyResult)
        
        -- Load monthly leaderboard
        exports.oxmysql:execute('SELECT * FROM bus_leaderboard WHERE period = ? AND period_start = DATE_FORMAT(CURDATE(), "%Y-%m-01") ORDER BY rank LIMIT 10', 
            {'monthly'}, function(monthlyResult)
            
            -- Load global leaderboard
            exports.oxmysql:execute('SELECT * FROM bus_leaderboard_current ORDER BY global_rank LIMIT 10', {}, function(globalResult)
                
                local leaderboard = {
                    weekly = weeklyResult or {},
                    monthly = monthlyResult or {},
                    global = globalResult or {}
                }
                
                TriggerClientEvent('bus:updateLeaderboard', src, leaderboard)
            end)
        end)
    end)
end

-- Utility functions
function GetPlayerTitle(level)
    if Config.Leveling.levels[level] then
        return Config.Leveling.levels[level].title
    end
    return 'Unknown Driver'
end

function GetPlayerLevelBonus(citizenid)
    exports.oxmysql:execute('SELECT current_level FROM bus_jobs WHERE citizenid = ?', {citizenid}, function(result)
        if result and result[1] then
            local level = result[1].current_level
            if Config.Leveling.levels[level] then
                return Config.Leveling.levels[level].bonus
            end
        end
        return 1.0 -- Default bonus
    end)
    return 1.0 -- Fallback
end

function CheckLevelUp(src, citizenid, xpEarned)
    exports.oxmysql:execute('SELECT total_xp, current_level FROM bus_jobs WHERE citizenid = ?', {citizenid}, function(result)
        if result and result[1] then
            local currentXP = result[1].total_xp
            local currentLevel = result[1].current_level
            
            -- Check for level up
            for level, levelData in pairs(Config.Leveling.levels) do
                if level > currentLevel and currentXP >= levelData.xp then
                    -- Level up!
                    exports.oxmysql:execute('UPDATE bus_jobs SET current_level = ? WHERE citizenid = ?', {level, citizenid})
                    
                    -- Notify player
                    TriggerClientEvent('QBCore:Notify', src, string.format(Config.Messages.levelUp, level, levelData.title), 'success')
                    
                    if Config.Debug.enabled then
                        print(string.format('[BUS SERVER] Player %s leveled up to %d: %s', citizenid, level, levelData.title))
                    end
                    break
                end
            end
        end
    end)
end

-- Anti-exploit functions
function canPlayerStartRoute(citizenid)
    local currentTime = os.time()
    local attempts = playerRouteAttempts[citizenid] or 0
    local lastAttempt = playerRouteCooldowns[citizenid] or 0
    
    -- Check cooldown
    if currentTime - lastAttempt < (Config.AntiExploit.routeCooldown / 1000) then
        return false
    end
    
    -- Check hourly limit
    if attempts >= Config.AntiExploit.maxRoutesPerHour then
        return false
    end
    
    return true
end

function incrementPlayerRouteAttempts(citizenid)
    local currentTime = os.time()
    
    if not playerRouteAttempts[citizenid] then
        playerRouteAttempts[citizenid] = 0
    end
    
    playerRouteAttempts[citizenid] = playerRouteAttempts[citizenid] + 1
    playerRouteCooldowns[citizenid] = currentTime
    
    -- Reset attempts after 1 hour
    Citizen.CreateThread(function()
        Citizen.Wait(Config.AntiExploit.routeCooldown)
        if playerRouteAttempts[citizenid] then
            playerRouteAttempts[citizenid] = playerRouteAttempts[citizenid] - 1
            if playerRouteAttempts[citizenid] <= 0 then
                playerRouteAttempts[citizenid] = nil
            end
        end
    end)
end

function CleanupOldRouteAttempts()
    local currentTime = os.time()
    
    for citizenid, lastAttempt in pairs(playerRouteCooldowns) do
        if currentTime - lastAttempt > 3600 then -- 1 hour
            playerRouteAttempts[citizenid] = nil
            playerRouteCooldowns[citizenid] = nil
        end
    end
    
    if Config.Debug.enabled then
        print('[BUS SERVER] Cleaned up old route attempts')
    end
end

-- Data validation
function validateRouteData(routeData)
    if not routeData then return false end
    
    -- Check required fields
    if not routeData.routeName or not routeData.totalPayment or not routeData.xpEarned then
        return false
    end
    
    -- Validate payment amount
    if routeData.totalPayment < 0 or routeData.totalPayment > 10000 then
        return false
    end
    
    -- Validate XP amount
    if routeData.xpEarned < 0 or routeData.xpEarned > 1000 then
        return false
    end
    
    -- Validate passenger count
    if routeData.passengersLoaded and (routeData.passengersLoaded < 0 or routeData.passengersLoaded > Config.AntiExploit.maxPassengersPerRoute) then
        return false
    end
    
    return true
end

-- Export functions for external use
exports('GetPlayerBusStats', function(citizenid)
    local result = exports.oxmysql:executeSync('SELECT * FROM bus_jobs WHERE citizenid = ?', {citizenid})
    if result and result[1] then
        return result[1]
    end
    return nil
end)

exports('GetBusLeaderboard', function(period, limit)
    limit = limit or 10
    local query = ''
    local params = {}
    
    if period == 'weekly' then
        query = 'SELECT * FROM bus_leaderboard WHERE period = ? AND period_start = DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY) ORDER BY rank LIMIT ?'
        params = {'weekly', limit}
    elseif period == 'monthly' then
        query = 'SELECT * FROM bus_leaderboard WHERE period = ? AND period_start = DATE_FORMAT(CURDATE(), "%Y-%m-01") ORDER BY rank LIMIT ?'
        params = {'monthly', limit}
    else
        query = 'SELECT * FROM bus_leaderboard_current ORDER BY global_rank LIMIT ?'
        params = {limit}
    end
    
    local result = exports.oxmysql:executeSync(query, params)
    return result or {}
end)

-- Resource cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- Clean up any remaining data
        playerRouteAttempts = {}
        playerRouteCooldowns = {}
        
        if Config.Debug.enabled then
            print('[BUS SERVER] Resource stopped, cleaned up data')
        end
    end
end)
