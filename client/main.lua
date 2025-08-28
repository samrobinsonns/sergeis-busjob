

local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()

-- Local variables
local isOnDuty = false
local currentRoute = nil
local currentStop = 1
local currentPassengerCount = 0
local routeStartTime = 0
local busVehicle = nil
local busBlip = nil
local stopBlips = {}
local passengerPeds = {}
local isRouteActive = false
local dashboardOpen = false

-- Initialize when resource starts
Citizen.CreateThread(function()
    -- Wait for QBCore to be ready
    while not QBCore do
        QBCore = exports['qb-core']:GetCoreObject()
        Citizen.Wait(100)
    end
    
    -- Setup depot target
    SetupDepotTarget()
    
    -- Main logic thread
    Citizen.CreateThread(function()
        while true do
            if isOnDuty and currentRoute and isRouteActive then
                CheckRouteProgress()
            end
            Citizen.Wait(Config.Performance.routeCheckDelay)
        end
    end)
    
    -- Passenger loading check thread
    Citizen.CreateThread(function()
        while true do
            if isOnDuty and currentRoute and isRouteActive and busVehicle then
                CheckPassengerLoading()
            end
            Citizen.Wait(Config.Performance.passengerLoadCheckDelay)
        end
    end)
end)

-- Setup depot target zone
function SetupDepotTarget()
    if not Config.Depot.target.enabled then return end
    
    local depotCoords = vector3(Config.Depot.x, Config.Depot.y, Config.Depot.z)
    
    if Config.TargetSystem.type == 'qb-target' then
        exports['qb-target']:AddBoxZone("bus_depot", depotCoords,
            Config.Depot.target.size.x, Config.Depot.target.size.y, {
            name = "bus_depot",
            heading = Config.Depot.target.rotation,
            debugPoly = Config.Debug.enabled,
            minZ = depotCoords.z - 1,
            maxZ = depotCoords.z + 2,
        }, {
            options = {
                {
                    type = "client",
                    event = "bus:openDashboard",
                    icon = Config.TargetSystem.icon,
                    label = Config.TargetSystem.label,
                },
            },
            distance = Config.TargetSystem.distance
        })
    elseif Config.TargetSystem.type == 'ox_target' then
        exports.ox_target:addBoxZone({
            coords = depotCoords,
            size = vector3(Config.Depot.target.size.x, Config.Depot.target.size.y, Config.Depot.target.size.z),
            rotation = Config.Depot.target.rotation,
            debug = Config.Debug.enabled,
            options = {
                {
                    name = 'bus_depot',
                    icon = Config.TargetSystem.icon,
                    label = Config.TargetSystem.label,
                    onSelect = function()
                        TriggerEvent('bus:openDashboard')
                    end
                }
            }
        })
    end
end

-- Event handlers
RegisterNetEvent('bus:openDashboard')
AddEventHandler('bus:openDashboard', function()
    if isRouteActive then
        QBCore.Functions.Notify('You cannot open dashboard while on a route!', 'error')
        return
    end
    
    -- Get player stats from server
    TriggerServerEvent('bus:getPlayerStats')
    
    -- Show dashboard
    dashboardOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showDashboard'
    })
end)

RegisterNetEvent('bus:updatePlayerStats')
AddEventHandler('bus:updatePlayerStats', function(stats)
    SendNUIMessage({
        action = 'updateStats',
        stats = stats
    })
end)

RegisterNetEvent('bus:updateRoutes')
AddEventHandler('bus:updateRoutes', function(routes)
    SendNUIMessage({
        action = 'updateRoutes',
        routes = routes
    })
end)

RegisterNetEvent('bus:updateLeaderboard')
AddEventHandler('bus:updateLeaderboard', function(leaderboard)
    SendNUIMessage({
        action = 'updateLeaderboard',
        leaderboard = leaderboard
    })
end)

RegisterNetEvent('bus:routeStartAllowed')
AddEventHandler('bus:routeStartAllowed', function()
    -- This event is triggered when server allows route to start
    if Config.Debug.enabled then
        print('[BUS DEBUG] Route start allowed by server')
    end
end)

-- NUI Callbacks
RegisterNUICallback('closeDashboard', function(data, cb)
    dashboardOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('startRoute', function(data, cb)
    if data.routeIndex and data.routeIndex >= 0 and data.routeIndex < #Config.Routes then
        -- Close dashboard first
        dashboardOpen = false
        SetNuiFocus(false, false)
        
        -- Start the route
        StartRoute(data.routeIndex)
        cb('ok')
    else
        cb('error')
    end
end)

-- Route management
function StartRoute(routeIndex)
    if isRouteActive then
        QBCore.Functions.Notify('You are already on a route!', 'error')
        return
    end
    
    local route = Config.Routes[routeIndex + 1] -- Lua is 1-indexed
    if not route then
        QBCore.Functions.Notify('Invalid route selected!', 'error')
        return
    end
    
    -- Check if player can start route (anti-exploit)
    TriggerServerEvent('bus:checkRouteStart')
    
    -- Spawn bus
    SpawnBus()
    
    -- Setup route
    currentRoute = route
    currentStop = 1
    currentPassengerCount = 0
    routeStartTime = GetGameTimer()
    isRouteActive = true
    
    -- Create route blips
    CreateRouteBlips()
    
    -- Create bus marker
    CreateBusMarker()
    
    -- Notify player
    QBCore.Functions.Notify(string.format(Config.Messages.routeStarted, route.name), 'success')
    QBCore.Functions.Notify(Config.Messages.busSpawned, 'info')
    
    if Config.Debug.enabled then
        print(string.format('[BUS DEBUG] Route started: %s', route.name))
    end
end

function SpawnBus()
    -- Delete existing bus if any
    if busVehicle and DoesEntityExist(busVehicle) then
        DeleteEntity(busVehicle)
    end
    
    -- Request model
    local model = GetHashKey(Config.BusModel)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Citizen.Wait(0)
    end
    
    -- Spawn bus
    busVehicle = CreateVehicle(model, Config.BusSpawn.x, Config.BusSpawn.y, Config.BusSpawn.z, Config.BusSpawn.heading, true, false)
    
    -- Set vehicle properties
    SetVehicleEngineOn(busVehicle, Config.VehicleSettings.engineOn, true, true)
    SetVehicleDoorsLocked(busVehicle, Config.VehicleSettings.doorsLocked)
    SetVehicleFuelLevel(busVehicle, Config.VehicleSettings.fuelLevel)
    SetVehicleDirtLevel(busVehicle, Config.VehicleSettings.dirtLevel)
    SetVehicleNumberPlateText(busVehicle, Config.VehicleSettings.plateText)
    
    -- Set player as driver
    SetPedIntoVehicle(PlayerPedId(), busVehicle, -1)
    
    -- Release model
    SetModelAsNoLongerNeeded(model)
    
    if Config.Debug.enabled then
        print('[BUS DEBUG] Bus spawned successfully')
    end
end

function CreateRouteBlips()
    -- Clear existing blips
    for _, blip in pairs(stopBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    stopBlips = {}
    
    -- Create blips for each stop
    for i, stop in ipairs(currentRoute.stops) do
        local blip = AddBlipForCoord(stop.x, stop.y, stop.z)
        SetBlipSprite(blip, Config.BlipSettings.sprite)
        SetBlipColour(blip, Config.BlipSettings.upcomingStopColor)
        SetBlipScale(blip, Config.BlipSettings.scale)
        SetBlipAsShortRange(blip, Config.BlipSettings.shortRange)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(string.format("Bus Stop %d: %s", i, stop.name))
        EndTextCommandSetBlipName(blip)
        
        stopBlips[i] = blip
    end
    
    if Config.Debug.enabled then
        print(string.format('[BUS DEBUG] Created %d route blips', #currentRoute.stops))
    end
end

function CreateBusMarker()
    if busVehicle and DoesEntityExist(busVehicle) then
        busBlip = AddBlipForEntity(busVehicle)
        SetBlipSprite(busBlip, Config.BlipSettings.sprite)
        SetBlipColour(busBlip, 2) -- Green for player's bus
        SetBlipScale(busBlip, Config.BlipSettings.scale)
        SetBlipAsShortRange(busBlip, Config.BlipSettings.shortRange)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Your Bus")
        EndTextCommandSetBlipName(busBlip)
        
        if Config.Debug.enabled then
            print('[BUS DEBUG] Created bus marker')
        end
    end
end

function CheckRouteProgress()
    if not currentRoute or not busVehicle or not DoesEntityExist(busVehicle) then
        EndRoute()
        return
    end
    
    -- Check if player is still in bus
    if not IsPedInVehicle(PlayerPedId(), busVehicle, false) then
        QBCore.Functions.Notify('You left your bus! Route cancelled.', 'error')
        EndRoute()
        return
    end
    
    -- Check route timeout
    local currentTime = GetGameTimer()
    if (currentTime - routeStartTime) > Config.GameSettings.routeTimeout then
        QBCore.Functions.Notify(Config.Messages.routeTimeout, 'error')
        EndRoute()
        return
    end
    
    -- Check if at depot (route completion)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local depotCoords = vector3(Config.Depot.x, Config.Depot.y, Config.Depot.z)
    local distanceToDepot = #(playerCoords - depotCoords)
    
    if distanceToDepot < Config.GameSettings.depotReturnDistance and currentStop > #currentRoute.stops then
        CompleteRoute()
    end
end

function CheckPassengerLoading()
    if not currentRoute or not busVehicle or currentStop > #currentRoute.stops then
        return
    end
    
    local currentStopData = currentRoute.stops[currentStop]
    if not currentStopData then return end
    
    local busCoords = GetEntityCoords(busVehicle)
    local stopCoords = vector3(currentStopData.x, currentStopData.y, currentStopData.z)
    local distance = #(busCoords - stopCoords)
    
    -- Check if bus is at the current stop
    if distance < Config.PassengerSettings.autoLoadDistance then
        local vehicleSpeed = GetEntitySpeed(busVehicle)
        if vehicleSpeed < 1.0 then -- Check if bus is stopped
            -- Show loading message
            QBCore.Functions.Notify(string.format('Loading passengers at: %s', currentStopData.name), 'info')
            
            -- Spawn passengers if not already spawned
            if not passengerPeds[currentStop] then
                SpawnPassengersAtStop(currentStopData, currentStop)
            end
            
            -- Auto-load passengers after delay
            Citizen.CreateThread(function()
                Citizen.Wait(2000) -- Wait 2 seconds for passengers to spawn
                if isOnDuty and currentRoute and currentStop <= #currentRoute.stops then
                    LoadPassengers(currentStop)
                end
            end)
        end
    end
end

function SpawnPassengersAtStop(stopData, stopIndex)
    local passengerCount = math.random(Config.PassengerSettings.passengerCountRange[1], Config.PassengerSettings.passengerCountRange[2])
    local spawnedPeds = {}
    
    for i = 1, passengerCount do
        local model = Config.PassengerSettings.passengerModels[math.random(#Config.PassengerSettings.passengerModels)]
        local hash = GetHashKey(model)
        
        RequestModel(hash)
        while not HasModelLoaded(hash) do
            Citizen.Wait(0)
        end
        
        -- Calculate spawn position
        local offsetX = math.random(-Config.PassengerSettings.passengerSpawnOffset[1], Config.PassengerSettings.passengerSpawnOffset[1])
        local offsetY = math.random(-Config.PassengerSettings.passengerSpawnOffset[2], Config.PassengerSettings.passengerSpawnOffset[2])
        local spawnPos = vector3(stopData.x + offsetX, stopData.y + offsetY, stopData.z)
        
        local ped = CreatePed(4, hash, spawnPos.x, spawnPos.y, spawnPos.z, 0.0, false, true)
        
        -- Set ped properties
        SetPedCanRagdoll(ped, Config.PedSettings.canRagdoll)
        SetPedCanBeTargetted(ped, Config.PedSettings.canBeTargetted)
        SetPedCanBeDraggedOut(ped, Config.PedSettings.canBeDraggedOut)
        SetPedCanRagdollFromPlayerImpact(ped, Config.PedSettings.canRagdollFromPlayerImpact)
        SetPedCanRagdollFromPlayerWeaponImpact(ped, Config.PedSettings.canRagdollFromPlayerWeaponImpact)
        SetPedCanRagdollFromPlayerVehicleImpact(ped, Config.PedSettings.canRagdollFromPlayerVehicleImpact)
        SetPedBlockingEvents(ped, Config.PedSettings.blockingEvents)
        
        -- Make ped wait at bus stop
        TaskWanderStandard(ped, 10.0, 10)
        
        spawnedPeds[i] = ped
        SetModelAsNoLongerNeeded(hash)
    end
    
    passengerPeds[stopIndex] = spawnedPeds
    
    if Config.Debug.enabled then
        print(string.format('[BUS DEBUG] Spawned %d passengers at stop %d', passengerCount, stopIndex))
    end
end

function LoadPassengers(stopIndex)
    local stopData = currentRoute.stops[stopIndex]
    if not stopData or not passengerPeds[stopIndex] then return end
    
    local loadedPassengers = 0
    
    -- Load each passenger
    for _, ped in ipairs(passengerPeds[stopIndex]) do
        if DoesEntityExist(ped) then
            -- Teleport passenger into bus
            local seatIndex = GetNextFreeSeat(busVehicle)
            if seatIndex ~= -1 then
                TaskWarpPedIntoVehicle(ped, busVehicle, seatIndex)
                loadedPassengers = loadedPassengers + 1
                currentPassengerCount = currentPassengerCount + 1
            end
        end
    end
    
    -- Clear passenger data for this stop
    passengerPeds[stopIndex] = nil
    
    -- Update blip color for completed stop
    if stopBlips[stopIndex] and DoesBlipExist(stopBlips[stopIndex]) then
        SetBlipColour(stopBlips[stopIndex], Config.BlipSettings.completedStopColor)
    end
    
    -- Move to next stop
    currentStop = currentStop + 1
    
    -- Notify player
    if currentStop <= #currentRoute.stops then
        local nextStop = currentRoute.stops[currentStop]
        QBCore.Functions.Notify(string.format(Config.Messages.passengersLoaded, nextStop.name), 'success')
    else
        QBCore.Functions.Notify(Config.Messages.returnBus, 'info')
    end
    
    if Config.Debug.enabled then
        print(string.format('[BUS DEBUG] Loaded %d passengers, moved to stop %d', loadedPassengers, currentStop))
    end
end

function GetNextFreeSeat(vehicle)
    for i = 0, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        if IsVehicleSeatFree(vehicle, i) then
            return i
        end
    end
    return -1
end

function CompleteRoute()
    if not currentRoute then return end
    
    -- Calculate route statistics
    local routeDistance = CalculateRouteDistance()
    local completionTime = math.floor((GetGameTimer() - routeStartTime) / 1000)
    local totalXP = currentRoute.baseXP + (currentPassengerCount * Config.PassengerSettings.passengerXPBonus)
    local totalPayment = currentRoute.basePayment + (currentPassengerCount * Config.PassengerSettings.passengerBonus)
    
    -- Send completion data to server
    TriggerServerEvent('bus:completeRoute', {
        routeName = currentRoute.name,
        routePayment = currentRoute.basePayment,
        passengerBonus = currentPassengerCount * Config.PassengerSettings.passengerBonus,
        totalPayment = totalPayment,
        passengersLoaded = currentPassengerCount,
        distanceTraveled = routeDistance,
        xpEarned = totalXP,
        completionTime = completionTime
    })
    
    -- End route
    EndRoute()
    
    -- Notify player
    QBCore.Functions.Notify(string.format(Config.Messages.paymentReceived, totalPayment, currentRoute.basePayment, currentPassengerCount * Config.PassengerSettings.passengerBonus), 'success')
end

function CalculateRouteDistance()
    local totalDistance = 0.0
    local lastCoords = vector3(Config.BusSpawn.x, Config.BusSpawn.y, Config.BusSpawn.z)
    
    for _, stop in ipairs(currentRoute.stops) do
        local stopCoords = vector3(stop.x, stop.y, stop.z)
        totalDistance = totalDistance + #(stopCoords - lastCoords)
        lastCoords = stopCoords
    end
    
    -- Add distance back to depot
    local depotCoords = vector3(Config.Depot.x, Config.Depot.y, Config.Depot.z)
    totalDistance = totalDistance + #(depotCoords - lastCoords)
    
    return totalDistance
end

function EndRoute()
    -- Clear route data
    currentRoute = nil
    currentStop = 1
    currentPassengerCount = 0
    routeStartTime = 0
    isRouteActive = false
    
    -- Remove blips
    for _, blip in pairs(stopBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    stopBlips = {}
    
    -- Remove bus marker
    if busBlip and DoesBlipExist(busBlip) then
        RemoveBlip(busBlip)
        busBlip = nil
    end
    
    -- Clear passenger peds
    for _, peds in pairs(passengerPeds) do
        for _, ped in ipairs(peds) do
            if DoesEntityExist(ped) then
                DeleteEntity(ped)
            end
        end
    end
    passengerPeds = {}
    
    if Config.Debug.enabled then
        print('[BUS DEBUG] Route ended')
    end
end

-- Commands
RegisterCommand(Config.Commands.endRoute, function()
    if isRouteActive then
        EndRoute()
        QBCore.Functions.Notify('Route ended manually.', 'info')
    else
        QBCore.Functions.Notify('You are not on a route.', 'error')
    end
end, false)

RegisterCommand(Config.Commands.help, function()
    for _, helpText in ipairs(Config.Messages.helpText) do
        QBCore.Functions.Notify(helpText, 'info')
        Citizen.Wait(1000)
    end
end, false)

-- Resource cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- Remove target zone
        if Config.TargetSystem.type == 'qb-target' then
            exports['qb-target']:RemoveZone("bus_depot")
        elseif Config.TargetSystem.type == 'ox_target' then
            exports.ox_target:removeZone("bus_depot")
        end
        
        -- End current route
        if isRouteActive then
            EndRoute()
        end
        
        -- Clean up blips
        for _, blip in pairs(stopBlips) do
            if DoesBlipExist(blip) then
                RemoveBlip(blip)
            end
        end
        
        if busBlip and DoesBlipExist(busBlip) then
            RemoveBlip(busBlip)
        end
    end
end)

-- Debug functions
if Config.Debug.enabled then
    RegisterCommand('busdebug', function()
        print(string.format('[BUS DEBUG] Route Active: %s', tostring(isRouteActive)))
        print(string.format('[BUS DEBUG] Current Stop: %d', currentStop))
        print(string.format('[BUS DEBUG] Passengers: %d', currentPassengerCount))
        if currentRoute then
            print(string.format('[BUS DEBUG] Route: %s', currentRoute.name))
        end
        if busVehicle then
            print(string.format('[BUS DEBUG] Bus Exists: %s', tostring(DoesEntityExist(busVehicle))))
        end
    end, false)
end
