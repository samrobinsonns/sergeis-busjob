-- Savana Bus Job - Recreated Client Script
-- Original encrypted script recreated for functionality

local working = false
local currentJob = nil
local currentRoute = nil
local currentStop = 1
local busBlip = nil
local destinationBlip = nil
local passengerPed = nil
local busVehicle = nil
local inBus = false
local currentZone = nil
local menuOpened = false

-- Function to open the bus job menu
function OpenBusMenu()
    if menuOpened then return end
    menuOpened = true

    if shared.debug then
        print("[DEBUG] Sergei Bus: Opening bus menu for zone " .. tostring(currentZone))
    end

    -- Open HTML interface
    SetNuiFocus(true, true)
    -- Get player level from server
    TriggerServerEvent('sergeis-bus:server:getPlayerLevel')

    -- Send initial menu data
    SendNUIMessage({
        action = "open",
        list = GetAvailableJobs(),
        xp = 0 -- Will be updated when server responds
    })
end

-- Function to get available jobs for the current zone
function GetAvailableJobs()
    local jobs = {}

    for k, v in pairs(shared.BusJob) do
        if currentZone == k then
            for jobIndex, job in ipairs(v.Jobs) do
                table.insert(jobs, {
                    index = jobIndex - 1, -- JavaScript 0-indexed
                    name = job.name,
                    level = job.level,
                    giveXp = job.xp,
                    price = job.totalPrice,
                    imgSrc = job.imgSrc,
                    stopcount = #job.stops
                })
            end
            break
        end
    end

    return jobs
end

-- Legacy menu function (kept for compatibility)
function OpenLegacyBusMenu()
    if menuOpened then return end
    menuOpened = true

    local menuOptions = {}

    for k, v in pairs(shared.BusJob) do
        if currentZone == k then
            for jobIndex, job in ipairs(v.Jobs) do
                table.insert(menuOptions, {
                    title = job.name,
                    description = string.format("%s - $%d - %d XP", shared.Locales["price"] .. job.totalPrice, job.xp),
                    image = job.imgSrc,
                    metadata = {
                        {label = "Level Required", value = job.level},
                        {label = "XP Reward", value = job.xp},
                        {label = "Money Reward", value = job.totalPrice}
                    },
                    onSelect = function()
                        StartBusJob(k, jobIndex)
                        menuOpened = false
                    end
                })
            end
            break
        end
    end

    lib.registerContext({
        id = 'bus_job_menu',
        title = 'Bus Job Center',
        options = menuOptions
    })

    lib.showContext('bus_job_menu')
end

-- Function to start a bus job
function StartBusJob(zoneIndex, jobIndex)
    if working then return end

    local zone = shared.BusJob[zoneIndex]
    local job = zone.Jobs[jobIndex]

    -- Check player level with server
    if shared.debug then
        print("[DEBUG] Sergei Bus: Checking if player can do job zone:" .. zoneIndex .. " job:" .. jobIndex)
    end

    lib.callback('sergeis-bus:server:canDoJob', false, function(canDoJob)
        if not canDoJob then
            Framework:Notify("You don't have the required level for this job!", "error")
            if shared.debug then
                print("[DEBUG] Sergei Bus: Player level check failed for job " .. jobIndex)
            end
            return
        end

        if shared.debug then
            print("[DEBUG] Sergei Bus: Starting job " .. job.name .. " (Level " .. job.level .. ")")
        end

        working = true
        currentJob = {zoneIndex = zoneIndex, jobIndex = jobIndex}
        currentRoute = job
        currentStop = 1

        -- Spawn bus vehicle
        if not SpawnBusVehicle(job.vehicles, job.start[1], job.start[2]) then
            working = false
            currentJob = nil
            currentRoute = nil
            currentStop = 1
            return
        end

        -- Create route blips
        CreateRouteBlips(job.stops)

        -- Set first destination
        SetDestination(job.stops[1])

        Framework:Notify(shared.Locales["get_to_bus"], "success")
    end, zoneIndex, jobIndex)

-- Function to spawn bus vehicle
function SpawnBusVehicle(model, coords, heading)
    local modelHash = GetHashKey(model)

    -- Request model with timeout
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end

    if not HasModelLoaded(modelHash) then
        Framework:Notify("Failed to load bus model: " .. model, "error")
        return false
    end

    -- Check if spawn point is clear
    if not Framework:SpawnClear(coords, 5.0) then
        Framework:Notify("Spawn point is blocked!", "error")
        return false
    end

    busVehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, true, false)

    if not DoesEntityExist(busVehicle) then
        Framework:Notify("Failed to spawn bus vehicle!", "error")
        return false
    end

    SetEntityAsMissionEntity(busVehicle, true, true)

    -- Set fuel if available
    if GetResourceState('savana-fuel') == 'started' then
        exports['savana-fuel']:SetFuel(busVehicle, 100.0)
    elseif GetResourceState('LegacyFuel') == 'started' then
        exports.LegacyFuel:SetFuel(busVehicle, 100.0)
    elseif GetResourceState('cdn-fuel') == 'started' then
        exports['cdn-fuel']:SetFuel(busVehicle, 100.0)
    end

    -- Give keys
    TriggerEvent("vehiclekeys:client:SetOwner", GetVehicleNumberPlateText(busVehicle))

    Framework:Notify("Bus spawned! Get in and start your route.", "success")
end

-- Function to create route blips
function CreateRouteBlips(stops)
    if busBlip then RemoveBlip(busBlip) end

    busBlip = AddBlipForEntity(busVehicle)
    SetBlipSprite(busBlip, 513)
    SetBlipColour(busBlip, 5)
    SetBlipScale(busBlip, 0.8)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Your Bus")
    EndTextCommandSetBlipName(busBlip)
end

-- Function to set destination
function SetDestination(coords)
    if destinationBlip then RemoveBlip(destinationBlip) end

    destinationBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(destinationBlip, 1)
    SetBlipColour(destinationBlip, 1)
    SetBlipScale(destinationBlip, 0.8)
    SetBlipRoute(destinationBlip, true)
    SetBlipRouteColour(destinationBlip, 1)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Next Stop")
    EndTextCommandSetBlipName(destinationBlip)
end

-- Function to handle passenger boarding
function HandlePassengerBoarding()
    if not working or not currentRoute then return end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    if busVehicle and IsPedInVehicle(playerPed, busVehicle, false) then
        inBus = true

        if currentStop <= #currentRoute.stops then
            local stopCoords = currentRoute.stops[currentStop]
            local distance = GetDistanceBetweenCoords(playerCoords, stopCoords.x, stopCoords.y, stopCoords.z, true)

            if distance < 10.0 then
                -- At stop, create passenger
                if not passengerPed then
                    CreatePassenger(stopCoords)
                end

                -- Check if player is stopped and near passenger
                if GetEntitySpeed(busVehicle) < 2.0 then
                    DrawMarker(1, stopCoords.x, stopCoords.y, stopCoords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.0, 3.0, 1.0, 0, 255, 0, 100, false, true, 2, true, nil, nil, false)
                    Draw3DText(stopCoords.x, stopCoords.y, stopCoords.z + 0.5, shared.Locales["passenger_boarding"])

                    if IsControlJustReleased(0, 38) then -- E key
                        PassengerBoarded()
                    end
                end
            end
        else
            -- All stops completed, head to end point
            local endCoords = currentRoute.ends
            local distance = GetDistanceBetweenCoords(playerCoords, endCoords.x, endCoords.y, endCoords.z, true)

            if distance < 10.0 and GetEntitySpeed(busVehicle) < 2.0 then
                DrawMarker(1, endCoords.x, endCoords.y, endCoords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.0, 3.0, 1.0, 0, 255, 0, 100, false, true, 2, true, nil, nil, false)
                Draw3DText(endCoords.x, endCoords.y, endCoords.z + 0.5, shared.Locales["end_work"])

                if IsControlJustReleased(0, 38) then -- E key
                    CompleteJob()
                end
            end
        end
    else
        inBus = false
    end
end

-- Function to create passenger
function CreatePassenger(coords)
    local pedModel = shared.PedModels[math.random(1, #shared.PedModels)]
    local modelHash = GetHashKey(pedModel)

    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end

    if not HasModelLoaded(modelHash) then
        Framework:Notify("Failed to load passenger model!", "error")
        return
    end

    passengerPed = CreatePed(4, modelHash, coords.x, coords.y, coords.z - 1.0, coords.w, false, false)

    if not DoesEntityExist(passengerPed) then
        Framework:Notify("Failed to create passenger!", "error")
        return
    end

    SetEntityAsMissionEntity(passengerPed, true, true)
    FreezeEntityPosition(passengerPed, true)
    SetBlockingOfNonTemporaryEvents(passengerPed, true)
end

-- Function when passenger boards
function PassengerBoarded()
    if shared.debug then
        print("[DEBUG] Sergei Bus: Passenger boarded at stop " .. currentStop)
    end

    if passengerPed then
        DeleteEntity(passengerPed)
        passengerPed = nil
    end

    currentStop = currentStop + 1

    if currentStop <= #currentRoute.stops then
        SetDestination(currentRoute.stops[currentStop])
        Framework:Notify(string.format(shared.Locales["remaining_stations"], #currentRoute.stops - currentStop + 1), "success")
        if shared.debug then
            print("[DEBUG] Sergei Bus: Next stop: " .. currentStop .. "/" .. #currentRoute.stops)
        end
    else
        -- Head to end point
        SetDestination(currentRoute.ends)
        Framework:Notify(shared.Locales["back_to_the_station"], "success")
        if shared.debug then
            print("[DEBUG] Sergei Bus: All stops completed, heading to depot")
        end
    end
end

-- Function to complete job
function CompleteJob()
    if not working then return end

    if shared.debug then
        print("[DEBUG] Sergei Bus: Completing job - Zone: " .. currentJob.zoneIndex .. " Job: " .. currentJob.jobIndex)
    end

    -- Award money and XP
    TriggerServerEvent('sergeis-bus:server:completeJob', currentJob.zoneIndex, currentJob.jobIndex)

    -- Clean up
    EndMission()
end

-- Function to end mission
function EndMission()
    if not working then return end

    working = false
    currentJob = nil
    currentRoute = nil
    currentStop = 1

    -- Remove blips
    if busBlip then RemoveBlip(busBlip) end
    if destinationBlip then RemoveBlip(destinationBlip) end

    -- Delete bus
    if busVehicle then
        DeleteEntity(busVehicle)
        busVehicle = nil
    end

    -- Delete passenger
    if passengerPed then
        DeleteEntity(passengerPed)
        passengerPed = nil
    end

    Framework:Notify("Job cancelled.", "error")
end

-- Thread for main loop
Citizen.CreateThread(function()
    while true do
        Wait(0)

        if working then
            HandlePassengerBoarding()
        end

        -- Draw info text
        if working and inBus then
            if shared.infoText then
                if currentStop <= #currentRoute.stops then
                    text(string.format(shared.Locales["remaining_stations"], #currentRoute.stops - currentStop + 1), 100)
                else
                    text(shared.Locales["back_to_the_station"], 100)
                end
            end
        end
    end
end)

-- Thread for zone handling (for non-target systems)
Citizen.CreateThread(function()
    while true do
        Wait(1000)

        if not shared.UseTarget and not working then
            for k, v in pairs(shared.BusJob) do
                local playerPed = PlayerPedId()
                local playerCoords = GetEntityCoords(playerPed)
                local coords = vector3(v.pedCoords.x, v.pedCoords.y, v.pedCoords.z)
                local distance = #(playerCoords - coords)

                if distance < 18.0 then
                    currentZone = k
                    HandleDealerZone(v.pedCoords)
                    break
                end
            end
        end
    end
end)

-- Function to handle dealer zone (for non-target systems)
function HandleDealerZone(coords)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local distance = #(playerCoords - coords)

    if distance < 18.0 then
        DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 1.5, 0.5, 255, 255, 0, 100, false, true, 2, true, nil, nil, false)

        if distance < 1.5 then
            if not working then
                Draw3DText(coords.x, coords.y, coords.z + 0.4, shared.Locales["open_job"])
                if IsControlJustReleased(0, 38) then
                    OpenBusMenu()
                end
            else
                Draw3DText(coords.x, coords.y, coords.z + 0.4, shared.Locales["cancel_job"])
                if IsControlJustReleased(0, 38) then
                    EndMission()
                end
            end
        end
    end
end

-- Function to draw 3D text
function Draw3DText(x, y, z, Text)
    if Text then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(true)
        AddTextComponentString(Text)
        SetDrawOrigin(x, y, z, 0)
        DrawText(0.0, 0.0)
        local Factor = (string.len(Text)) / 370
        DrawRect(0.0, 0.0 + 0.0125, 0.017 + Factor, 0.03, 0, 0, 0, 75)
        ClearDrawOrigin()
    end
end

-- Function to display text
function text(text, duration)
    if not shared.infoText then return end
    ClearPrints()
    BeginTextCommandPrint('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandPrint(duration, 1)
end

-- NUI Callbacks for HTML interface
RegisterNUICallback('nuiOff', function(data, cb)
    SetNuiFocus(false, false)
    menuOpened = false
    cb('ok')
end)

RegisterNUICallback('startJob', function(data, cb)
    if data and data.job and data.index then
        StartBusJob(currentZone, data.index + 1) -- JavaScript arrays are 0-indexed
    end
    cb('ok')
end)

-- Event handlers
RegisterNetEvent('sergeis-bus:client:sendNotifys', function(msg, tip)
    Framework:Notify(msg, tip)
end)

RegisterNetEvent('sergeis-bus:client:updatePlayerLevel', function(level, xp)
    if menuOpened then
        -- Update the NUI with actual player level
        SendNUIMessage({
            action = "updateLevel",
            level = level,
            xp = xp
        })
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    EndMission()
end)
