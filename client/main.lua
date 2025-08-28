

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
local depotPed = nil

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
    
    local depotCoords = Config.Depot.coords
    
    -- Create the depot manager ped
    local pedModel = GetHashKey(Config.Depot.target.pedModel)
    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do
        Citizen.Wait(0)
    end
    
    -- Spawn the ped
    depotPed = CreatePed(4, pedModel, depotCoords.x, depotCoords.y, depotCoords.z - 1.0, Config.Depot.heading, false, true)
    SetEntityHeading(depotPed, Config.Depot.heading)
    FreezeEntityPosition(depotPed, true)
    SetEntityInvincible(depotPed, true)
    SetEntityCanBeDamaged(depotPed, false)
    SetPedCanRagdoll(depotPed, false)
    SetPedCanBeTargetted(depotPed, true)
    SetBlockingOfNonTemporaryEvents(depotPed, true)
    
    -- Add target to the ped
    if Config.TargetSystem.type == 'qb-target' then
        exports['qb-target']:AddTargetEntity(depotPed, {
            options = {
                {
                    type = "client",
                    event = "bus:openDashboard",
                    icon = Config.TargetSystem.icon,
                    label = Config.TargetSystem.label,
                    canInteract = function()
                        return not isRouteActive
                    end
                },
            },
            distance = Config.TargetSystem.distance
        })
        
        if Config.Debug.enabled then
            print('[BUS DEBUG] qb-target entity added successfully')
        end
    elseif Config.TargetSystem.type == 'ox_target' then
        exports.ox_target:addLocalEntity(depotPed, {
            {
                name = 'bus_depot',
                icon = Config.TargetSystem.icon,
                label = Config.TargetSystem.label,
                canInteract = function()
                    return not isRouteActive
                end,
                onSelect = function()
                    TriggerEvent('bus:openDashboard')
                end
            }
        })
        
        if Config.Debug.enabled then
            print('[BUS DEBUG] ox_target entity added successfully')
        end
    end
    
    -- Release the model
    SetModelAsNoLongerNeeded(pedModel)
    
    if Config.Debug.enabled then
        print('[BUS DEBUG] Depot manager ped created and targeted')
        print(string.format('[BUS DEBUG] Ped ID: %d, Model: %s', depotPed, Config.Depot.target.pedModel))
        print(string.format('[BUS DEBUG] Target Label: %s', Config.TargetSystem.label))
        print(string.format('[BUS DEBUG] Target Type: %s', Config.TargetSystem.type))
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
    
    -- Spawn bus first (validation)
    if not SpawnBus() then
        QBCore.Functions.Notify('Failed to start route: No available parking space.', 'error')
        return
    end
    
    -- Check if player can start route (anti-exploit)
    TriggerServerEvent('bus:checkRouteStart')
    
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
    
    -- Find available spawn point
    local spawnPoint = FindAvailableSpawnPoint()
    if not spawnPoint then
        QBCore.Functions.Notify('No available parking spaces at the depot. Please wait for a space to open up.', 'error')
        return false
    end
    
    -- Request model
    local model = GetHashKey(Config.BusModel)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Citizen.Wait(0)
    end
    
    -- Spawn bus at validated location
    busVehicle = CreateVehicle(model, spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.w, true, false)
    
    if not DoesEntityExist(busVehicle) then
        QBCore.Functions.Notify('Failed to spawn bus. Please try again.', 'error')
        SetModelAsNoLongerNeeded(model)
        return false
    end
    
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
        print(string.format('[BUS DEBUG] Bus spawned successfully at: %.2f, %.2f, %.2f', spawnPoint.x, spawnPoint.y, spawnPoint.z))
    end
    
    return true
end

-- Find available spawn point
function FindAvailableSpawnPoint()
    for i, spawnPoint in ipairs(Config.BusSpawnPoints) do
        if IsSpawnPointAvailable(spawnPoint) then
            if Config.Debug.enabled then
                print(string.format('[BUS DEBUG] Found available spawn point %d at: %.2f, %.2f, %.2f', i, spawnPoint.x, spawnPoint.y, spawnPoint.z))
            end
            return spawnPoint
        end
    end
    
    if Config.Debug.enabled then
        print('[BUS DEBUG] No available spawn points found')
    end
    
    return nil
end

-- Check if spawn point is available
function IsSpawnPointAvailable(spawnPoint)
    local coords = vector3(spawnPoint.x, spawnPoint.y, spawnPoint.z)
    
    -- Check for vehicles in the area
    local vehicles = GetGamePool('CVehicle')
    for _, vehicle in pairs(vehicles) do
        if DoesEntityExist(vehicle) and vehicle ~= busVehicle then
            local vehicleCoords = GetEntityCoords(vehicle)
            local distance = #(coords - vehicleCoords)
            if distance < Config.SpawnValidation.vehicleCheckDistance then
                return false
            end
        end
    end
    
    -- Check for peds in the area
    local peds = GetGamePool('CPed')
    for _, ped in pairs(peds) do
        if DoesEntityExist(ped) and ped ~= PlayerPedId() then
            local pedCoords = GetEntityCoords(ped)
            local distance = #(coords - pedCoords)
            if distance < Config.SpawnValidation.pedCheckDistance then
                return false
            end
        end
    end
    
    -- Check ground clearance
    local groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, false)
    if groundZ and math.abs(coords.z - groundZ) > Config.SpawnValidation.groundCheckDistance then
        return false
    end
    
    -- Check if area is clear using raycast
    local startPos = vector3(coords.x, coords.y, coords.z + 2.0)
    local endPos = vector3(coords.x, coords.y, coords.z - 2.0)
    local ray = StartShapeTestRay(startPos.x, startPos.y, startPos.z, endPos.x, endPos.y, endPos.z, 1, 0, 0)
    local _, hit, _, _, _ = GetShapeTestResult(ray)
    
    if hit == 1 then
        return false
    end
    
    return true
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
        local blip = AddBlipForCoord(stop.coords.x, stop.coords.y, stop.coords.z)
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
    local depotCoords = Config.Depot.coords
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
    local stopCoords = currentStopData.coords
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
        local spawnPos = vector3(stopData.coords.x + offsetX, stopData.coords.y + offsetY, stopData.coords.z)
        
        local ped = CreatePed(4, hash, spawnPos.x, spawnPos.y, spawnPos.z, 0.0, false, true)
        
        -- Set ped properties
        SetPedCanRagdoll(ped, Config.PedSettings.canRagdoll)
        SetPedCanBeTargetted(ped, Config.PedSettings.canBeTargetted)
        SetPedCanBeDraggedOut(ped, Config.PedSettings.canBeDraggedOut)
        SetPedCanRagdollFromPlayerImpact(ped, Config.PedSettings.canRagdollFromPlayerImpact)
        SetPedCanRagdollFromPlayerWeaponImpact(ped, Config.PedSettings.canRagdollFromPlayerWeaponImpact)
        SetPedCanRagdollFromPlayerVehicleImpact(ped, Config.PedSettings.canRagdollFromPlayerVehicleImpact)
        SetBlockingOfNonTemporaryEvents(ped, Config.PedSettings.blockNonTemporaryEvents)
        
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
    local totalPassengers = #passengerPeds[stopIndex]
    local passengersLoaded = 0
    
    -- Check if realistic loading is enabled
    if not Config.PassengerSettings.realisticLoading then
        -- Fallback to old warp method
        for _, ped in ipairs(passengerPeds[stopIndex]) do
            if DoesEntityExist(ped) then
                local seatIndex = GetNextFreeSeat(busVehicle)
                if seatIndex ~= -1 then
                    TaskWarpPedIntoVehicle(ped, busVehicle, seatIndex)
                    loadedPassengers = loadedPassengers + 1
                    currentPassengerCount = currentPassengerCount + 1
                end
            end
        end
        CompletePassengerLoading(stopIndex)
        return
    end
    
    -- Load each passenger with realistic walking animation
    for i, ped in ipairs(passengerPeds[stopIndex]) do
        if DoesEntityExist(ped) then
            -- Calculate door position (front right door of bus)
            local busCoords = GetEntityCoords(busVehicle)
            local busHeading = GetEntityHeading(busVehicle)
            local doorOffset = vector3(
                math.cos(math.rad(busHeading + 90)) * Config.PassengerSettings.doorOffset,  -- Right side
                math.sin(math.rad(busHeading + 90)) * Config.PassengerSettings.doorOffset,  -- Right side
                0.0
            )
            local doorPosition = busCoords + doorOffset
            
            -- Make passenger walk to bus door
            TaskGoToCoordAnyMeans(ped, doorPosition.x, doorPosition.y, doorPosition.z, Config.PassengerSettings.walkSpeed, 0, false, 786603, 0xbf800000)
            
            -- Wait a bit for passenger to reach door, then enter
            Citizen.CreateThread(function()
                local maxAttempts = Config.PassengerSettings.maxWalkTime * 10 -- Convert to 100ms intervals
                local attempts = 0
                while attempts < maxAttempts and DoesEntityExist(ped) do
                    Citizen.Wait(100)
                    attempts = attempts + 1
                    
                    local pedCoords = GetEntityCoords(ped)
                    local distanceToDoor = #(pedCoords - doorPosition)
                    
                    if distanceToDoor < Config.PassengerSettings.doorReachDistance then -- Close enough to door
                        -- Find available seat
                        local seatIndex = GetNextFreeSeat(busVehicle)
                        if seatIndex ~= -1 then
                            -- Make passenger enter bus naturally
                            TaskEnterVehicle(ped, busVehicle, -1, seatIndex, 1.0, 1, 0)
                            
                            -- Wait for passenger to enter, then count them
                            Citizen.CreateThread(function()
                                local maxEnterAttempts = Config.PassengerSettings.maxEnterTime * 10 -- Convert to 100ms intervals
                                local enterAttempts = 0
                                while enterAttempts < maxEnterAttempts and DoesEntityExist(ped) do
                                    Citizen.Wait(100)
                                    enterAttempts = enterAttempts + 1
                                    
                                    if IsPedInVehicle(ped, busVehicle, false) then
                                        loadedPassengers = loadedPassengers + 1
                                        currentPassengerCount = currentPassengerCount + 1
                                        passengersLoaded = passengersLoaded + 1
                                        break
                                    end
                                end
                                
                                -- If passenger didn't enter after timeout, force them in (if fallback enabled)
                                if not IsPedInVehicle(ped, busVehicle, false) and DoesEntityExist(ped) and Config.PassengerSettings.fallbackToWarp then
                                    TaskWarpPedIntoVehicle(ped, busVehicle, seatIndex)
                                    loadedPassengers = loadedPassengers + 1
                                    currentPassengerCount = currentPassengerCount + 1
                                    passengersLoaded = passengersLoaded + 1
                                end
                                
                                -- Check if all passengers are loaded
                                if passengersLoaded >= totalPassengers then
                                    CompletePassengerLoading(stopIndex)
                                end
                            end)
                        end
                        break
                    end
                end
                
                -- If passenger didn't reach door after timeout, force them in (if fallback enabled)
                if attempts >= maxAttempts and DoesEntityExist(ped) and Config.PassengerSettings.fallbackToWarp then
                    local seatIndex = GetNextFreeSeat(busVehicle)
                    if seatIndex ~= -1 then
                        TaskWarpPedIntoVehicle(ped, busVehicle, seatIndex)
                        loadedPassengers = loadedPassengers + 1
                        currentPassengerCount = currentPassengerCount + 1
                        passengersLoaded = passengersLoaded + 1
                        
                        if passengersLoaded >= totalPassengers then
                            CompletePassengerLoading(stopIndex)
                        end
                    end
                end
            end)
        end
    end
end

function CompletePassengerLoading(stopIndex)
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
        print(string.format('[BUS DEBUG] All passengers loaded, moved to stop %d', currentStop))
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
    
    -- Store route data before clearing
    local routeData = {
        routeName = currentRoute.name,
        routePayment = currentRoute.basePayment,
        passengerBonus = currentPassengerCount * Config.PassengerSettings.passengerBonus,
        totalPayment = totalPayment,
        passengersLoaded = currentPassengerCount,
        distanceTraveled = routeDistance,
        xpEarned = totalXP,
        completionTime = completionTime
    }
    
    -- Send completion data to server
    TriggerServerEvent('bus:completeRoute', routeData)
    
    -- End route (this clears the data)
    EndRoute()
    
    -- Note: Server will handle the payment notification
end

function CalculateRouteDistance()
    local totalDistance = 0.0
    local lastCoords = Config.BusSpawnPoints[1] -- Use first spawn point as starting location
    
    for _, stop in ipairs(currentRoute.stops) do
        local stopCoords = stop.coords
        totalDistance = totalDistance + #(stopCoords - lastCoords)
        lastCoords = stopCoords
    end
    
    -- Add distance back to depot
    local depotCoords = Config.Depot.coords
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
        -- Remove depot ped
        if depotPed and DoesEntityExist(depotPed) then
            DeleteEntity(depotPed)
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
        if depotPed then
            print(string.format('[BUS DEBUG] Depot Ped Exists: %s', tostring(DoesEntityExist(depotPed))))
            print(string.format('[BUS DEBUG] Depot Ped Coords: %.2f, %.2f, %.2f', 
                GetEntityCoords(depotPed)))
        end
    end, false)
    
    RegisterCommand('testtarget', function()
        if depotPed and DoesEntityExist(depotPed) then
            print('[BUS DEBUG] Testing target system...')
            print(string.format('[BUS DEBUG] Ped ID: %d', depotPed))
            print(string.format('[BUS DEBUG] Target Type: %s', Config.TargetSystem.type))
            print(string.format('[BUS DEBUG] Target Label: %s', Config.TargetSystem.label))
            print('[BUS DEBUG] Try targeting the ped now...')
        else
            print('[BUS DEBUG] Depot ped does not exist!')
        end
    end, false)
end
