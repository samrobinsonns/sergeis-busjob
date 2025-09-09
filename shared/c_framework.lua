Framework = {}
currentZone = nil
working = false
menuOpened = false
passengerCreationAttempted = false
headingToDepot = false

-- Global variables for mission state
busBlip = nil
destinationBlip = nil
passengerPed = nil
busVehicle = nil

function Framework:GetIdentifier()
    if shared.Framework == "qb" then
        return FrameworkObject.Functions.GetPlayerData().citizenid
    elseif shared.Framework == "esx" then
        return FrameworkObject.GetPlayerData().identifier
    else
        -- Write your own code.
        return nil
    end
end

function Framework:Notify(msg, tip)
    if shared.Framework == "qb" then
        return FrameworkObject.Functions.Notify(msg, tip, 2500)
    elseif shared.Framework == "esx" then        
        return FrameworkObject.ShowNotification(msg,tip, 2500)
    else
        -- Write your own code.
        return nil
    end
end

function Framework:RemoveKey(vehicle, trailer)
    print(vehicle..' and ' ..trailer..' key deleted')
end

function Framework:SpawnClear(data,count)
    if shared.Framework == "qb" then
        return FrameworkObject.Functions.SpawnClear(data,count)
    elseif shared.Framework == "esx" then
        return FrameworkObject.Game.IsSpawnPointClear(data,count)
    else
        -- Write your own code.
        return nil
    end
end

-- Function to open the bus job menu
function OpenBusMenu()
    if menuOpened then return end
    menuOpened = true

    if shared.debug then
        print("[DEBUG] Sergei Bus: Opening bus menu for zone " .. tostring(currentZone))
        print("[DEBUG] Sergei Bus: Available jobs: " .. tostring(#GetAvailableJobs()))
    end

    -- Open HTML interface
    SetNuiFocus(true, true)
    -- Get player level from server
    TriggerServerEvent('sergeis-bus:server:getPlayerLevel')

    -- Send initial menu data
    local jobList = GetAvailableJobs()
    SendNUIMessage({
        action = "open",
        list = jobList,
        xp = 0 -- Will be updated when server responds
    })

    if shared.debug then
        print("[DEBUG] Sergei Bus: Sent NUI message with " .. #jobList .. " jobs")
    end
end

-- Function to get available jobs for the current zone
function GetAvailableJobs()
    local jobs = {}

    -- Try to load Config if not available
    if not Config then
        if shared.debug then
            print("[DEBUG] Sergei Bus: Config not loaded in shared, loading from file...")
        end

        local configChunk, loadError = load(LoadResourceFile(GetCurrentResourceName(), 'config.lua'))
        if configChunk then
            local success, result = pcall(configChunk)
            if success then
                if shared.debug then
                    print("[DEBUG] Sergei Bus: Config loaded successfully in shared file")
                end
            else
                if shared.debug then
                    print("[ERROR] Sergei Bus: Failed to execute config in shared: " .. tostring(result))
                end
            end
        else
            if shared.debug then
                print("[ERROR] Sergei Bus: Failed to load config file in shared: " .. tostring(loadError))
            end
        end
    end

    -- Use Config.Routes if available (new system)
    if Config and Config.Routes then
        if shared.debug then
            print("[DEBUG] Sergei Bus: Using Config.Routes with " .. #Config.Routes .. " routes")
        end

        for jobIndex, route in ipairs(Config.Routes) do
            table.insert(jobs, {
                index = jobIndex - 1, -- JavaScript 0-indexed
                name = route.name,
                level = route.level or 1,
                giveXp = route.baseXP or 0,
                price = route.basePayment or 0,
                imgSrc = 'images/bus/bus.png', -- Default bus image
                stopcount = route.stops and #route.stops or 0
            })
        end
    else
        -- Fallback to old shared.BusJob system
        if shared.debug then
            print("[DEBUG] Sergei Bus: Config not available, using shared.BusJob fallback")
        end

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
    end

    if shared.debug then
        print("[DEBUG] Sergei Bus: GetAvailableJobs returning " .. #jobs .. " jobs")
    end

    return jobs
end

-- Function to end mission
function EndMission(completed)
    if not working then return end

    -- Default to false (cancellation) if no parameter provided
    completed = completed or false

    working = false
    passengerCreationAttempted = false
    headingToDepot = false

    -- Remove blips if they exist
    if busBlip then
        RemoveBlip(busBlip)
        busBlip = nil
    end
    if destinationBlip then
        RemoveBlip(destinationBlip)
        destinationBlip = nil
    end

    -- Clear any GPS routes
    ClearGpsPlayerWaypoint()
    ClearGpsMultiRoute()

    -- Delete bus if it exists
    if busVehicle then
        DeleteEntity(busVehicle)
        busVehicle = nil
    end

    -- Delete passenger if it exists
    if passengerPed then
        DeleteEntity(passengerPed)
        passengerPed = nil
    end

    -- Show appropriate message based on completion status
    if completed then
        Framework:Notify("Job completed successfully!", "success")
    else
        Framework:Notify("Job cancelled.", "error")
    end
end

text = function(text, duration)
    if not shared.infoText then
        
    else
        ClearPrints()
        BeginTextCommandPrint('STRING')
        AddTextComponentSubstringPlayerName(text)
        EndTextCommandPrint(duration, 1)
    end
end

loadVehicle = function(vehicle, coords, heading)
    local model
    if type(vehicle) == 'number' then 
        model = vehicle 
    else 
        model = GetHashKey(vehicle) 
    end
    while not HasModelLoaded(model) do 
        Wait(0) 
        RequestModel(model) 
    end

    local car = CreateVehicle(model, coords.x,coords.y,coords.z, heading, true, false)
    SetEntityAsMissionEntity(car, true, true)
    
    TriggerEvent("vehiclekeys:client:SetOwner", GetVehicleNumberPlateText(car))
    fuel(car)
    return car
end

function fuel(car)
    if GetResourceState('savana-fuel') == 'started' then
        return exports['savana-fuel']:SetFuel(car, 100.0)
    end
    if GetResourceState('LegacyFuel') == 'started' then
        return exports.LegacyFuel:SetFuel(car, 100.0)
    end
    if GetResourceState('cdn-fuel') == 'started' then
        return exports['cdn-fuel']:SetFuel(car, 100.0)
    end
    if GetResourceState('ox_fuel') == 'started' then
        return Entity(car) and Entity(car).state and Entity(car).state.fuel or 100
    end
end

for k, v in pairs(shared.BusJob) do
    if shared.UseTarget then
        RequestModel(v.ped)
        while not HasModelLoaded(v.ped) do
            Wait(0)
        end
        local ped = CreatePed(4, GetHashKey(v.ped), v.pedCoords.x, v.pedCoords.y, v.pedCoords.z -1, v.pedCoords.w, false, false)
        SetEntityHeading(ped, v.pedCoords.w)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedDiesWhenInjured(ped, false)
        SetPedCanRagdoll(ped, false)

        if GetResourceState('ox_target') == 'started' then
            local coord = v.pedCoords
            exports.ox_target:addBoxZone({
                coords = vector3(coord.x,coord.y,coord.z),
                size = vec3(1, 1, 2),
                rotation = 0,
                debug = shared.debug,
                distance = 2.5,
                options = {
                    {
                        name = "OpenBusMenu",
                        label = shared.Locales["open_job_target"],
                        icon = "fas fa-briefcase",
                        onSelect = function()
                            currentZone = k
                            OpenBusMenu()
                        end,
                        canInteract = function(entity, distance, data)
                            return not working 
                        end,
                    },
                    {
                        name = 'cancel_mission',
                        label = shared.Locales["cancel_job_target"],
                        icon = "fas fa-truck",
                        onSelect = function(data)
                            EndMission()
                        end,
                        canInteract = function(entity, distance, data)
                            return working 
                        end,
                    },
                },
            })
        else
            exports['qb-target']:AddTargetEntity(ped, {
                options = {
                    {
                        label = shared.Locales["open_job_target"],
                        icon = "fas fa-briefcase",
                        action = function()
                            currentZone = k
                            OpenBusMenu()
                        end,
                        canInteract = function()
                            if not working then 
                                return true
                            end
                        end,
                    },
                    {
                        action = function()
                            EndMission()
                        end,
                        icon = 'fas fa-truck',
                        label = shared.Locales["cancel_job_target"],
                        canInteract = function()
                            if working then 
                                return true
                            end
                        end,
                    },
                },
                distance = 2.0
            })
        end
    else
        local coords = vector3(v.pedCoords.x, v.pedCoords.y, v.pedCoords.z)
        
        Citizen.CreateThread(function()

            while true do
                wait = 1000
                local playerPed = PlayerPedId()
                local playerCoords = GetEntityCoords(playerPed)
                local coords = vector3(v.pedCoords.x, v.pedCoords.y, v.pedCoords.z)
                local distance = #(playerCoords - coords)

                if distance < 18.0 then
                    currentZone = k
                    HandleDealerZone(v.pedCoords)
                    wait = 0
                end
                Citizen.Wait(wait)
            end
        end)
    end
end

function HandleDealerZone(_coords)
    coords = vector3(_coords.x, _coords.y, _coords.z)
    if menuOpened then return end

    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
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

RegisterNetEvent('sergeis-bus:client:sendNotifys',function(msg, tipim)
    Framework:Notify(msg, tipim)
end)


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

function createBlips()
    for _, bus in pairs(shared.BusJob) do
        local blip = AddBlipForCoord(bus.pedCoords.x, bus.pedCoords.y, bus.pedCoords.z)

        SetBlipSprite(blip, bus.blip.sprite) 
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, bus.blip.size)
        SetBlipColour(blip, bus.blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(bus.blip.text)
        EndTextCommandSetBlipName(blip)
    end
end

if shared.Framework == 'esx' or shared.Framework == 'esxold' then
    RegisterNetEvent('esx:playerLoaded', function()
        createBlips()
    end)
else
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        createBlips()
    end)
end
AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
      return
    end
    EndMission()
end)

AddEventHandler('onResourceStart', function(resourceName)
    -- handles script restarts
    if GetCurrentResourceName() == resourceName then
        createBlips()
    end
end)