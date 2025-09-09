-- Savana Bus Job - Recreated Client Script
-- Original encrypted script recreated for functionality

local currentJob = nil
local currentRoute = nil
local currentStop = 1
local inBus = false
local headingToDepot = false

-- OpenBusMenu and GetAvailableJobs functions moved to shared/c_framework.lua

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
    if shared.debug then
        print("[DEBUG] Sergei Bus: StartBusJob called with zoneIndex=" .. tostring(zoneIndex) .. ", jobIndex=" .. tostring(jobIndex))
    end

    if working then
        if shared.debug then
            print("[DEBUG] Sergei Bus: Already working, returning")
        end
        return
    end

    local zone = shared.BusJob[zoneIndex]
    local job = zone.Jobs[jobIndex]

    if shared.debug then
        print("[DEBUG] Sergei Bus: Zone data: " .. tostring(zone))
        print("[DEBUG] Sergei Bus: Job data: " .. tostring(job))
        if job then
            print("[DEBUG] Sergei Bus: Job vehicles: " .. tostring(job.vehicles))
            print("[DEBUG] Sergei Bus: Job start coords: " .. tostring(job.start[1]))
            print("[DEBUG] Sergei Bus: Job start heading: " .. tostring(job.start[2]))
        end
    end

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
        headingToDepot = false

        -- Spawn bus vehicle
        if shared.debug then
            print("[DEBUG] Sergei Bus: About to spawn vehicle...")
        end
        if not SpawnBusVehicle(job.vehicles, job.start[1], job.start[2]) then
            working = false
            currentJob = nil
            currentRoute = nil
            currentStop = 1
            if shared.debug then
                print("[DEBUG] Sergei Bus: Vehicle spawning failed, exiting job start")
            end
            return
        end
        if shared.debug then
            print("[DEBUG] Sergei Bus: Vehicle spawned successfully, continuing with waypoints...")
        end

        -- Create route blips
        if shared.debug then
            print("[DEBUG] Sergei Bus: About to create route blips...")
            print("[DEBUG] Sergei Bus: job.stops = " .. tostring(job.stops))
            if job.stops then
                print("[DEBUG] Sergei Bus: Number of stops: " .. #job.stops)
                if #job.stops > 0 then
                    print("[DEBUG] Sergei Bus: First stop coords: " .. tostring(job.stops[1]))
                else
                    print("[DEBUG] Sergei Bus: No stops found in job data!")
                end
            end
        end
        CreateRouteBlips(job.stops)

        -- Set first destination
        if shared.debug then
            print("[DEBUG] Sergei Bus: About to set first destination...")
        end
        if job.stops and job.stops[1] then
            SetDestination(job.stops[1])
        else
            if shared.debug then
                print("[ERROR] Sergei Bus: No stops found in job data")
            end
        end

        Framework:Notify(shared.Locales["get_to_bus"], "success")
    end, zoneIndex, jobIndex)
end

-- Function to spawn bus vehicle
function SpawnBusVehicle(model, coords, heading)
    if shared.debug then
        print("[DEBUG] Sergei Bus: SpawnBusVehicle called with model=" .. tostring(model) .. ", coords=" .. tostring(coords) .. ", heading=" .. tostring(heading))
    end

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
        if shared.debug then
            print("[DEBUG] Sergei Bus: Model failed to load: " .. model .. " (hash: " .. modelHash .. ")")
        end
        return false
    end

    if shared.debug then
        print("[DEBUG] Sergei Bus: Model loaded successfully: " .. model)
    end

    -- Check if spawn point is clear
    if not Framework:SpawnClear(coords, 5.0) then
        Framework:Notify("Spawn point is blocked!", "error")
        if shared.debug then
            print("[DEBUG] Sergei Bus: Spawn point blocked at coords: " .. tostring(coords))
        end
        return false
    end

    if shared.debug then
        print("[DEBUG] Sergei Bus: Spawn point clear, creating vehicle...")
    end

    busVehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, true, false)

    if not DoesEntityExist(busVehicle) then
        Framework:Notify("Failed to spawn bus vehicle!", "error")
        if shared.debug then
            print("[DEBUG] Sergei Bus: Failed to create vehicle entity")
        end
        return false
    end

    if shared.debug then
        print("[DEBUG] Sergei Bus: Vehicle spawned successfully with entity ID: " .. tostring(busVehicle))
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

    return true
end

-- Function to create route blips
function CreateRouteBlips(stops)
    if shared.debug then
        print("[DEBUG] Sergei Bus: CreateRouteBlips called with " .. #stops .. " stops")
        print("[DEBUG] Sergei Bus: busVehicle entity: " .. tostring(busVehicle))
    end

    if busBlip then
        RemoveBlip(busBlip)
        if shared.debug then
            print("[DEBUG] Sergei Bus: Removed existing bus blip")
        end
    end

    busBlip = AddBlipForEntity(busVehicle)
    if busBlip then
    SetBlipSprite(busBlip, 513)
    SetBlipColour(busBlip, 5)
    SetBlipScale(busBlip, 0.8)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Your Bus")
    EndTextCommandSetBlipName(busBlip)

        if shared.debug then
            print("[DEBUG] Sergei Bus: Created bus blip with ID: " .. tostring(busBlip))
        end
    else
        if shared.debug then
            print("[DEBUG] Sergei Bus: Failed to create bus blip!")
        end
    end
end

-- Function to set destination
function SetDestination(stopData)
    if shared.debug then
        print("[DEBUG] Sergei Bus: SetDestination called with stopData: " .. tostring(stopData))
    end

    -- Handle both old format (direct vector) and new format (table with coords field)
    local coords
    if stopData and stopData.coords then
        coords = stopData.coords
        if shared.debug then
            print("[DEBUG] Sergei Bus: Using coords field: x=" .. coords.x .. ", y=" .. coords.y .. ", z=" .. coords.z)
        end
    elseif stopData and stopData.x then
        coords = stopData
        if shared.debug then
            print("[DEBUG] Sergei Bus: Using direct coords: x=" .. coords.x .. ", y=" .. coords.y .. ", z=" .. coords.z)
        end
    else
        if shared.debug then
            print("[ERROR] Sergei Bus: Invalid stop data format in SetDestination")
        end
        return
    end

    -- Clear any existing destination blip and GPS route
    if destinationBlip then
        RemoveBlip(destinationBlip)
        destinationBlip = nil
        if shared.debug then
            print("[DEBUG] Sergei Bus: Removed existing destination blip")
        end
    end

    -- Clear any existing GPS routes to prevent conflicts
    ClearGpsPlayerWaypoint()
    ClearGpsMultiRoute()

    destinationBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    if destinationBlip then
        -- Set blip properties for maximum visibility
        SetBlipSprite(destinationBlip, 1)  -- Standard waypoint icon
        SetBlipColour(destinationBlip, 1)  -- Red color
        SetBlipScale(destinationBlip, 0.8)
        SetBlipAsShortRange(destinationBlip, false)  -- Always visible
        SetBlipAlpha(destinationBlip, 255)  -- Fully visible

        -- Enable GPS route
        SetBlipRoute(destinationBlip, true)
        SetBlipRouteColour(destinationBlip, 1)  -- Red route

        -- Set blip name
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Next Stop")
        EndTextCommandSetBlipName(destinationBlip)

        if shared.debug then
            print("[DEBUG] Sergei Bus: Created destination blip with ID: " .. tostring(destinationBlip))
            print("[DEBUG] Sergei Bus: Route should now be visible on GPS")
            print("[DEBUG] Sergei Bus: Blip coordinates: x=" .. coords.x .. ", y=" .. coords.y .. ", z=" .. coords.z)
            print("[DEBUG] Sergei Bus: Blip sprite: " .. GetBlipSprite(destinationBlip))
            print("[DEBUG] Sergei Bus: Blip colour: " .. GetBlipColour(destinationBlip))
            print("[DEBUG] Sergei Bus: Blip alpha: " .. GetBlipAlpha(destinationBlip))
            print("[DEBUG] Sergei Bus: Blip as short range: " .. tostring(IsBlipShortRange(destinationBlip)))

            -- Check GPS route status after a short delay
            Citizen.CreateThread(function()
                Wait(1000) -- Wait 1 second for route calculation
                print("[DEBUG] Sergei Bus: GPS route status check:")
                print("[DEBUG] Sergei Bus: DoesBlipHaveGpsRoute: " .. tostring(DoesBlipHaveGpsRoute(destinationBlip)))
                print("[DEBUG] Sergei Bus: IsBlipOnMinimap: " .. tostring(IsBlipOnMinimap(destinationBlip)))
                -- Note: GetBlipRouteColour is not a valid FiveM native
            end)
        end
    else
        if shared.debug then
            print("[DEBUG] Sergei Bus: Failed to create destination blip!")
            print("[DEBUG] Sergei Bus: Coordinates used: x=" .. coords.x .. ", y=" .. coords.y .. ", z=" .. coords.z)
        end
    end
end

-- Function to handle passenger boarding
function HandlePassengerBoarding()
    if not working or not currentRoute then return end

            if shared.debug and math.random(1, 500) == 1 then -- Only log occasionally to avoid spam
            print("[DEBUG] Sergei Bus: HandlePassengerBoarding called - working: " .. tostring(working) .. ", route: " .. tostring(currentRoute))
        end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    if busVehicle and IsPedInVehicle(playerPed, busVehicle, false) then
        inBus = true

        if shared.debug and math.random(1, 200) == 1 then -- Log less frequently
            print("[DEBUG] Sergei Bus: Player is in bus, checking stops")
        end

        if currentStop <= #currentRoute.stops then
            local stopData = currentRoute.stops[currentStop]
            local stopCoords

            -- Handle both old format (direct vector) and new format (table with coords field)
            if stopData.coords then
                stopCoords = stopData.coords
            else
                stopCoords = stopData
            end

            -- Ensure coordinates are numbers
            local pX, pY, pZ = tonumber(playerCoords.x), tonumber(playerCoords.y), tonumber(playerCoords.z)
            local sX, sY, sZ = tonumber(stopCoords.x), tonumber(stopCoords.y), tonumber(stopCoords.z)

            local distance = GetDistanceBetweenCoords(pX, pY, pZ, sX, sY, sZ, true)

            if shared.debug and (distance < 15.0 or (math.random(1, 1000) == 1 and currentStop > 1)) then -- Only log when close or occasionally (but not for first stop)
                print("[DEBUG] Sergei Bus: Current stop: " .. currentStop .. "/" .. #currentRoute.stops)
                print("[DEBUG] Sergei Bus: Stop coords: x=" .. sX .. ", y=" .. sY .. ", z=" .. sZ)
                print("[DEBUG] Sergei Bus: Player coords: x=" .. pX .. ", y=" .. pY .. ", z=" .. pZ)
                print("[DEBUG] Sergei Bus: Distance to stop: " .. distance)
            end

            if distance < 10.0 then
                if shared.debug and math.random(1, 100) == 1 then -- Only log occasionally when at stop
                    print("[DEBUG] Sergei Bus: Within 10 units of stop - passenger logic should trigger")
                end

                -- At stop, create passenger (only if we don't have one already)
                if not passengerPed and not passengerCreationAttempted then
                    if shared.debug then
                        print("[DEBUG] Sergei Bus: At stop, attempting to create passenger...")
                        print("[DEBUG] Sergei Bus: passengerPed is nil: " .. tostring(passengerPed == nil))
                        print("[DEBUG] Sergei Bus: passengerCreationAttempted: " .. tostring(passengerCreationAttempted))
                    end
                    passengerCreationAttempted = true
                    if shared.debug then
                        print("[DEBUG] Sergei Bus: Calling CreatePassenger with coords: x=" .. sX .. ", y=" .. sY .. ", z=" .. sZ)
                    end
                    CreatePassenger({x = sX, y = sY, z = sZ})
                elseif passengerPed and passengerCreationAttempted then
                    -- Reset flag if passenger was successfully created
                    if shared.debug then
                        print("[DEBUG] Sergei Bus: Passenger already exists, resetting creation flag")
                    end
                    passengerCreationAttempted = false
                elseif passengerPed then
                    if shared.debug and math.random(1, 200) == 1 then
                        print("[DEBUG] Sergei Bus: Passenger ped exists: " .. tostring(passengerPed))
                    end
                end

                -- Check if player is stopped and near passenger
                local vehicleSpeed = GetEntitySpeed(busVehicle)
                if shared.debug and math.random(1, 200) == 1 then -- Only log speed occasionally
                    print("[DEBUG] Sergei Bus: Vehicle speed: " .. vehicleSpeed)
                end

                if vehicleSpeed < 2.0 then
                    if shared.debug and math.random(1, 100) == 1 then -- Only log occasionally
                        print("[DEBUG] Sergei Bus: Vehicle stopped, showing marker and text")
                    end

                    DrawMarker(1, sX, sY, sZ - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.0, 3.0, 1.0, 0, 255, 0, 100, false, true, 2, true, nil, nil, false)
                    Draw3DText(sX, sY, sZ + 0.5, "Press ~y~E~w~ to load passengers")

                    if IsControlJustReleased(0, 38) and passengerPed then -- E key and passenger exists
                        if shared.debug then
                            print("[DEBUG] Sergei Bus: E key pressed for passenger boarding")
                            print("[DEBUG] Sergei Bus: passengerPed exists: " .. tostring(passengerPed ~= nil))
                        end
                        StartPassengerBoarding()
                    end
                else
                    if shared.debug then
                        print("[DEBUG] Sergei Bus: Vehicle moving too fast (" .. vehicleSpeed .. " > 2.0), not showing marker")
                    end
                end
            else
                if shared.debug and distance < 50.0 then
                    print("[DEBUG] Sergei Bus: Getting close to stop - distance: " .. distance)
                end
            end
        else
            -- All stops completed, head to depot
            -- Load depot coordinates from config
            if not Config then
                if shared.debug then
                    print("[DEBUG] Sergei Bus: Config not loaded in client, loading from file...")
                end
                local configChunk, loadError = load(LoadResourceFile(GetCurrentResourceName(), 'config.lua'))
                if configChunk then
                    local success, result = pcall(configChunk)
                    if not success then
                        print("[ERROR] Sergei Bus: Failed to execute config in client: " .. tostring(result))
                        return
                    end
                else
                    print("[ERROR] Sergei Bus: Failed to load config file in client: " .. tostring(loadError))
                    return
                end
            end

            local depotCoords = Config.Depot.coords
            local distance = GetDistanceBetweenCoords(playerCoords.x, playerCoords.y, playerCoords.z, depotCoords.x, depotCoords.y, depotCoords.z, true)

            if shared.debug and distance < 100.0 then
                print("[DEBUG] Sergei Bus: Distance to depot: " .. distance)
            end

            if distance < 10.0 and GetEntitySpeed(busVehicle) < 2.0 then
                DrawMarker(1, depotCoords.x, depotCoords.y, depotCoords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.0, 3.0, 1.0, 0, 255, 0, 100, false, true, 2, true, nil, nil, false)

                if headingToDepot and passengerPed then
                    Draw3DText(depotCoords.x, depotCoords.y, depotCoords.z + 0.5, "Press ~y~E~w~ to drop off passenger and complete job")
                else
                    Draw3DText(depotCoords.x, depotCoords.y, depotCoords.z + 0.5, "Press ~y~E~w~ to complete job")
                end

                if IsControlJustReleased(0, 38) then -- E key
                    if headingToDepot and passengerPed then
                        -- Drop off passenger at depot first
                        HandlePassengerDropOff()
                        Wait(3000) -- Wait for passenger to exit and walk away
                    end
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
    if shared.debug then
        print("[DEBUG] Sergei Bus: CreatePassenger called with coords: " .. tostring(coords))
        if coords then
            print("[DEBUG] Sergei Bus: CreatePassenger coords: x=" .. (coords.x or "nil") .. ", y=" .. (coords.y or "nil") .. ", z=" .. (coords.z or "nil"))
        end
    end

    local pedModel = shared.PedModels[math.random(1, #shared.PedModels)]

    if shared.debug then
        print("[DEBUG] Sergei Bus: Selected passenger model: " .. tostring(pedModel))
    end

    -- pedModel is already hashed due to backticks in shared.lua
    local modelHash = pedModel

    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end

    if not HasModelLoaded(modelHash) then
        Framework:Notify("Failed to load passenger model!", "error")
        if shared.debug then
            print("[DEBUG] Sergei Bus: Failed to load passenger model: " .. tostring(pedModel))
        end
        return
    end

    if shared.debug then
        print("[DEBUG] Sergei Bus: Passenger model loaded successfully")
    end

    passengerPed = CreatePed(4, modelHash, coords.x, coords.y, coords.z - 1.0, coords.w or 0.0, false, false)

    if not DoesEntityExist(passengerPed) then
        Framework:Notify("Failed to create passenger!", "error")
        if shared.debug then
            print("[DEBUG] Sergei Bus: Failed to create passenger entity")
        end
        return
    end

    if shared.debug then
        print("[DEBUG] Sergei Bus: Passenger created successfully with entity ID: " .. tostring(passengerPed))
    end

    SetEntityAsMissionEntity(passengerPed, true, true)
    -- Don't freeze the passenger initially - let them walk to the bus
    -- FreezeEntityPosition(passengerPed, true) -- Commented out for walking animation
    SetBlockingOfNonTemporaryEvents(passengerPed, true)

    -- Make passenger stand still and face the bus
    if busVehicle then
        TaskLookAtEntity(passengerPed, busVehicle, -1, 0, 2)
        -- Clear any movement tasks and make them stand still
        ClearPedTasks(passengerPed)
        TaskStandStill(passengerPed, -1)
        SetBlockingOfNonTemporaryEvents(passengerPed, true)
    end

    if shared.debug then
        print("[DEBUG] Sergei Bus: Passenger setup complete, waiting for boarding")
    end
end

-- Function to start passenger boarding animation
function StartPassengerBoarding()
    if shared.debug then
        print("[DEBUG] Sergei Bus: StartPassengerBoarding called")
        print("[DEBUG] Sergei Bus: passengerPed: " .. tostring(passengerPed))
        print("[DEBUG] Sergei Bus: busVehicle: " .. tostring(busVehicle))
    end

    if not passengerPed or not busVehicle then
        if shared.debug then
            print("[DEBUG] Sergei Bus: Cannot start boarding - passenger or bus missing")
        end
        return
    end

    if shared.debug then
        print("[DEBUG] Sergei Bus: Starting realistic passenger boarding sequence")
    end

    -- Prevent multiple boarding attempts (simpler check)
    if passengerPed and IsPedInVehicle(passengerPed, busVehicle, false) then
        if shared.debug then
            print("[DEBUG] Sergei Bus: Passenger already in vehicle, skipping boarding")
        end
        return
    end

    -- Clear any existing tasks
    ClearPedTasks(passengerPed)
    ClearPedTasksImmediately(passengerPed)

    -- Notify player that boarding is starting
    Framework:Notify("Passenger is boarding the bus...", "info")

    -- Calculate passenger door position immediately
    local busCoords = GetEntityCoords(busVehicle)
    local busHeading = GetEntityHeading(busVehicle)
    local passengerDoorOffset = 2.5 -- Distance from center to passenger door

    -- Determine which door to use for entry (this needs to be done first)
    local doorIndex = 1 -- Default to passenger door
    if DoesVehicleHaveDoor(busVehicle, 1) then
        doorIndex = 1 -- Front passenger door
    elseif DoesVehicleHaveDoor(busVehicle, 2) then
        doorIndex = 2 -- Rear passenger door
    else
        doorIndex = 0 -- Driver door fallback
    end

    -- Determine which side the passenger door is on based on the door index
    local doorSideMultiplier = 1 -- Default to right side (+90 degrees)

    -- For door index 1 (front passenger door), we want the right side of the bus
    -- For door index 2 (rear passenger door), we also want the right side
    -- For door index 0 (driver door), we want the left side
    if doorIndex == 0 then
        doorSideMultiplier = -1 -- Left side for driver door
    end

    -- Calculate position next to the correct door side
    local passengerDoorX = busCoords.x + math.sin(math.rad(busHeading + (90 * doorSideMultiplier))) * passengerDoorOffset
    local passengerDoorY = busCoords.y + math.cos(math.rad(busHeading + (90 * doorSideMultiplier))) * passengerDoorOffset
    local passengerDoorCoords = vector3(passengerDoorX, passengerDoorY, busCoords.z)

    -- Start boarding sequence immediately
    Citizen.CreateThread(function()
        -- doorIndex is already determined above, open doors immediately when boarding starts

        -- Open door immediately
        local doorOpenSuccess = pcall(function()
            SetVehicleDoorOpen(busVehicle, doorIndex, false, false)
            if shared.debug then
                print("[DEBUG] Sergei Bus: Opened door " .. doorIndex .. " immediately for boarding")
            end
        end)
        -- Make passenger walk to passenger door position immediately
        TaskGoToCoordAnyMeans(passengerPed, passengerDoorX, passengerDoorY, busCoords.z, 1.0, 0, false, 786603, 0.5)

        if shared.debug then
            print("[DEBUG] Sergei Bus: Passenger walking to passenger door position: " .. tostring(passengerDoorCoords))
        end

        -- Wait for passenger to reach passenger door position or timeout
        local timeout = 0
        while timeout < 5000 do -- 5 second timeout
            local pedCoords = GetEntityCoords(passengerPed)
            local distanceToDoor = GetDistanceBetweenCoords(
                pedCoords.x, pedCoords.y, pedCoords.z,
                passengerDoorX, passengerDoorY, busCoords.z,
                true
            )
            if distanceToDoor < 1.5 then -- Closer distance check for door position
                if shared.debug then
                    print("[DEBUG] Sergei Bus: Passenger reached door position")
                end
                break
            end
            Wait(100)
            timeout = timeout + 100
        end

        if not DoesEntityExist(passengerPed) or not DoesEntityExist(busVehicle) then
            if shared.debug then
                print("[DEBUG] Sergei Bus: Passenger or bus no longer exists, aborting boarding")
            end
            return
        end

        Wait(500) -- Brief wait for door to open and passenger to position

        -- Have passenger enter the bus through the correct door (try different seat if first is occupied)
        local seatIndex = 1 -- Start with passenger seat
        local enteredVehicle = false

        if IsVehicleSeatFree(busVehicle, seatIndex) then
            -- TaskEnterVehicle with specific door
            TaskEnterVehicle(passengerPed, busVehicle, -1, seatIndex, 2.0, doorIndex, 0)
            enteredVehicle = true
            if shared.debug then
                print("[DEBUG] Sergei Bus: Passenger entering through door " .. doorIndex .. " to seat " .. seatIndex)
            end
        else
            -- Try other seats if passenger seat is occupied
            for i = 2, 8 do
                if IsVehicleSeatFree(busVehicle, i) then
                    seatIndex = i
                    TaskEnterVehicle(passengerPed, busVehicle, -1, seatIndex, 2.0, doorIndex, 0)
                    enteredVehicle = true
                    if shared.debug then
                        print("[DEBUG] Sergei Bus: Passenger entering through door " .. doorIndex .. " to seat " .. seatIndex)
                    end
                    break
                end
            end
        end

        -- Fallback: Force passenger into vehicle if TaskEnterVehicle fails
        if not enteredVehicle then
            if shared.debug then
                print("[DEBUG] Sergei Bus: TaskEnterVehicle failed, using fallback method")
            end
            for i = 1, 8 do
                if IsVehicleSeatFree(busVehicle, i) then
                    SetPedIntoVehicle(passengerPed, busVehicle, i)
                    seatIndex = i
                    enteredVehicle = true
                    if shared.debug then
                        print("[DEBUG] Sergei Bus: Passenger force-placed in seat " .. i .. " using fallback")
                    end
                    break
                end
            end
        end

        -- Wait for passenger to enter (or if already entered via fallback)
        local enterTimeout = 0
        while enterTimeout < 5000 do -- 5 second timeout for entering
            if IsPedInVehicle(passengerPed, busVehicle, false) then
                if shared.debug then
                    print("[DEBUG] Sergei Bus: Passenger confirmed in vehicle after " .. enterTimeout .. "ms")
                    local seatIndex = -1
                    for i = -1, 8 do
                        if GetPedInVehicleSeat(busVehicle, i) == passengerPed then
                            seatIndex = i
                            break
                        end
                    end
                    print("[DEBUG] Sergei Bus: Passenger is in seat: " .. seatIndex)
                end
                break
            end
            Wait(100)
            enterTimeout = enterTimeout + 100
        end

        if shared.debug and enterTimeout >= 5000 then
            print("[DEBUG] Sergei Bus: Passenger boarding timeout - passenger may not have entered vehicle")
            print("[DEBUG] Sergei Bus: Passenger coords: " .. tostring(GetEntityCoords(passengerPed)))
        end

        -- If passenger still not in vehicle after timeout, use force method as last resort
        if not IsPedInVehicle(passengerPed, busVehicle, false) then
            if shared.debug then
                print("[DEBUG] Sergei Bus: Timeout reached, forcing passenger into vehicle")
            end
            for i = 1, 8 do
                if IsVehicleSeatFree(busVehicle, i) then
                    SetPedIntoVehicle(passengerPed, busVehicle, i)
                    seatIndex = i
                    -- Ensure passenger is properly seated with retention
                    SetPedConfigFlag(passengerPed, 32, true) -- CPED_CONFIG_FLAG_DisableShufflingToDriverSeat
                    SetPedConfigFlag(passengerPed, 429, true) -- CPED_CONFIG_FLAG_StayInCarOnExit
                    SetPedConfigFlag(passengerPed, 430, true) -- CPED_CONFIG_FLAG_DontLeaveCarOnOwnerEntry
                    -- Removed flag 168 (DisablePedEnteringVehicles) as it prevents proper boarding

                    -- Set the passenger as a mission entity and prevent despawning
                    SetEntityAsMissionEntity(passengerPed, true, true)
                    SetEntityInvincible(passengerPed, true)
                    SetPedCanRagdoll(passengerPed, false)

                    if shared.debug then
                        print("[DEBUG] Sergei Bus: Passenger force-placed in seat " .. i .. " with full retention settings")
                    end
                    break
                end
            end
        end

        Wait(500) -- Brief pause after entering

        -- Close the door that was opened (with error handling)
        local doorCloseSuccess = pcall(function()
            SetVehicleDoorShut(busVehicle, doorIndex, false)
            if shared.debug then
                print("[DEBUG] Sergei Bus: Closed door index " .. doorIndex)
            end
        end)

        if shared.debug then
            print("[DEBUG] Sergei Bus: Passenger entered bus in seat " .. seatIndex .. " through door " .. doorIndex .. ", door closed (success: " .. tostring(doorCloseSuccess) .. ")")
        end

        -- Ensure passenger is properly seated and retained
        if IsPedInVehicle(passengerPed, busVehicle, false) then
            -- Force the passenger to sit properly in the seat
            SetPedConfigFlag(passengerPed, 32, true) -- CPED_CONFIG_FLAG_DisableShufflingToDriverSeat
            SetPedConfigFlag(passengerPed, 429, true) -- CPED_CONFIG_FLAG_StayInCarOnExit
            SetPedConfigFlag(passengerPed, 430, true) -- CPED_CONFIG_FLAG_DontLeaveCarOnOwnerEntry
            -- Removed flag 168 (DisablePedEnteringVehicles) as it prevents proper boarding

            -- Set the passenger as a mission entity and prevent despawning
            SetEntityAsMissionEntity(passengerPed, true, true)
            SetEntityInvincible(passengerPed, true) -- Prevent passenger from dying
            SetPedCanRagdoll(passengerPed, false) -- Prevent ragdoll physics

            -- Create a task to keep passenger in vehicle
            TaskVehicleDriveWander(passengerPed, busVehicle, 0.0, 786603) -- Dummy task to keep in vehicle

            if shared.debug then
                print("[DEBUG] Sergei Bus: Passenger properly seated in seat " .. seatIndex .. " with retention settings")
            end
        end

        -- Notify player
        Framework:Notify("Passenger boarded successfully!", "success")

        if shared.debug then
            print("[DEBUG] Sergei Bus: Passenger successfully boarded, starting retention monitor")
        end

        -- Start passenger retention monitoring thread
        StartPassengerRetentionMonitor()

        -- Wait a bit then complete boarding
        if shared.debug then
            print("[DEBUG] Sergei Bus: Waiting 1.5 seconds before completing boarding...")
        end
        Wait(1500)
        if shared.debug then
            print("[DEBUG] Sergei Bus: Calling CompletePassengerBoarding now...")
        end
        CompletePassengerBoarding()
    end)
end

-- Function to start passenger retention monitoring
function StartPassengerRetentionMonitor()
    if not passengerPed or not busVehicle then return end

    if shared.debug then
        print("[DEBUG] Sergei Bus: Starting passenger retention monitor")
    end

    Citizen.CreateThread(function()
        while working and passengerPed and DoesEntityExist(passengerPed) and DoesEntityExist(busVehicle) do
            -- Check if passenger is still in vehicle
            if not IsPedInVehicle(passengerPed, busVehicle, false) then
                if shared.debug then
                    print("[DEBUG] Sergei Bus: Passenger not in vehicle, attempting to re-seat")
                    print("[DEBUG] Sergei Bus: Passenger ped exists: " .. tostring(DoesEntityExist(passengerPed)))
                    print("[DEBUG] Sergei Bus: Bus vehicle exists: " .. tostring(DoesEntityExist(busVehicle)))
                    local pedCoords = GetEntityCoords(passengerPed)
                    print("[DEBUG] Sergei Bus: Passenger coords: x=" .. pedCoords.x .. ", y=" .. pedCoords.y .. ", z=" .. pedCoords.z)
                end

                -- Try to put passenger back in vehicle
                for i = 1, 8 do
                    if IsVehicleSeatFree(busVehicle, i) then
                        SetPedIntoVehicle(passengerPed, busVehicle, i)
                        SetPedConfigFlag(passengerPed, 32, true)  -- Disable shuffling to driver seat
                        SetPedConfigFlag(passengerPed, 429, true) -- Stay in car on exit
                        SetPedConfigFlag(passengerPed, 430, true) -- Don't leave car on owner entry
                        -- Removed flag 168 (DisablePedEnteringVehicles) as it prevents proper boarding

                        if shared.debug then
                            print("[DEBUG] Sergei Bus: Passenger re-seated in seat " .. i)
                        end
                        break
                    end
                end
            else
                -- Passenger is in vehicle, reinforce retention settings
                SetPedConfigFlag(passengerPed, 32, true)  -- Disable shuffling to driver seat
                SetPedConfigFlag(passengerPed, 429, true) -- Stay in car on exit
                SetPedConfigFlag(passengerPed, 430, true) -- Don't leave car on owner entry
                -- Removed flag 168 (DisablePedEnteringVehicles) as it prevents proper boarding
            end

            -- Check passenger health and prevent despawning
            if GetEntityHealth(passengerPed) < 100 then
                SetEntityHealth(passengerPed, 200)
            end

            Wait(2000) -- Check every 2 seconds
        end

        if shared.debug then
            print("[DEBUG] Sergei Bus: Passenger retention monitor stopped")
        end
    end)
end

-- Function to complete passenger boarding
function CompletePassengerBoarding()
    if shared.debug then
        print("[DEBUG] Sergei Bus: Completing passenger boarding")
        print("[DEBUG] Sergei Bus: Current stop before increment: " .. currentStop)
        print("[DEBUG] Sergei Bus: Total stops in route: " .. #currentRoute.stops)
    end

    -- Drop off passenger at intermediate stops to make room for new passengers
    -- Only keep passengers until depot if it's the last stop
    if passengerPed and currentStop < #currentRoute.stops then
        if shared.debug then
            print("[DEBUG] Sergei Bus: Dropping off passenger at intermediate stop " .. currentStop)
        end

        -- Synchronous drop-off at intermediate stops
        TaskLeaveVehicle(passengerPed, busVehicle, 0)

        -- Wait for passenger to exit
        local dropOffTimeout = 0
        while IsPedInVehicle(passengerPed, busVehicle, false) and dropOffTimeout < 3000 do
            Wait(100)
            dropOffTimeout = dropOffTimeout + 100
        end

        -- Make passenger walk away
        local stopCoords
        local stopData = currentRoute.stops[currentStop]
        if stopData and stopData.coords then
            stopCoords = stopData.coords
        elseif stopData then
            stopCoords = stopData
        end

        if stopCoords then
            local walkAwayX = (stopCoords.x or 456.0) + math.random(-3, 3)
            local walkAwayY = (stopCoords.y or -1025.0) + math.random(-3, 3)
            TaskGoToCoordAnyMeans(passengerPed, walkAwayX, walkAwayY, (stopCoords.z or 28.0), 1.0, 0, false, 786603, 0.5)

            -- Delete passenger after walking away
            Citizen.CreateThread(function()
                Wait(4000)
                if DoesEntityExist(passengerPed) then
                    DeleteEntity(passengerPed)
                end
            end)
        end

        -- Reset passenger variables for next passenger
        passengerPed = nil
        passengerCreationAttempted = false

        if shared.debug then
            print("[DEBUG] Sergei Bus: Intermediate passenger dropped off successfully")
        end
    elseif passengerPed and currentStop >= #currentRoute.stops then
        if shared.debug then
            print("[DEBUG] Sergei Bus: Keeping final passenger on board until depot")
        end
        -- Don't drop off the final passenger - they stay until depot
    end

    -- Reset passenger creation flag for next stop
    passengerCreationAttempted = false

    -- Increment to next stop
    currentStop = currentStop + 1

    if shared.debug then
        print("[DEBUG] Sergei Bus: Current stop after increment: " .. currentStop)
    end

    if currentStop <= #currentRoute.stops then
        if shared.debug then
            print("[DEBUG] Sergei Bus: Setting destination for stop " .. currentStop)
            print("[DEBUG] Sergei Bus: Stop data: " .. tostring(currentRoute.stops[currentStop]))
        end
        SetDestination(currentRoute.stops[currentStop])
        if shared.debug then
            print("[DEBUG] Sergei Bus: Next stop: " .. currentStop .. "/" .. #currentRoute.stops)
        end
    else
        -- Head to depot - passenger will be dropped off at depot
        -- Load depot coordinates from config
        if not Config then
            if shared.debug then
                print("[DEBUG] Sergei Bus: Config not loaded in client for SetDestination, loading from file...")
            end
            local configChunk, loadError = load(LoadResourceFile(GetCurrentResourceName(), 'config.lua'))
            if configChunk then
                local success, result = pcall(configChunk)
                if not success then
                    print("[ERROR] Sergei Bus: Failed to execute config in client: " .. tostring(result))
                    return
                end
            else
                print("[ERROR] Sergei Bus: Failed to load config file in client: " .. tostring(loadError))
                return
            end
        end

        SetDestination(Config.Depot.coords)
        Framework:Notify("All stops completed! Return to depot to complete the job.", "success")
        if shared.debug then
            print("[DEBUG] Sergei Bus: All stops completed, heading to depot")
        end

        -- Mark that we're heading to depot for final passenger drop-off
        headingToDepot = true
    end
end

-- Function to handle passenger drop-off at stops
function HandlePassengerDropOff()
    if not passengerPed or not busVehicle then return end

    if shared.debug then
        print("[DEBUG] Sergei Bus: Handling passenger drop-off")
    end

    -- Determine drop-off location (stop or depot)
    local stopCoords

    if currentStop <= #currentRoute.stops then
        -- Regular stop drop-off
        local stopData = currentRoute.stops[currentStop]

        -- Handle both old format (direct vector) and new format (table with coords field)
        if stopData and stopData.coords then
            stopCoords = stopData.coords
        elseif stopData then
            stopCoords = stopData
        end
    else
        -- Depot drop-off - use depot coordinates
        -- Load config if not available
        if not Config then
            if shared.debug then
                print("[DEBUG] Sergei Bus: Config not loaded in HandlePassengerDropOff, loading from file...")
            end
            local configChunk, loadError = load(LoadResourceFile(GetCurrentResourceName(), 'config.lua'))
            if configChunk then
                local success, result = pcall(configChunk)
                if not success then
                    print("[ERROR] Sergei Bus: Failed to execute config in HandlePassengerDropOff: " .. tostring(result))
                end
            else
                print("[ERROR] Sergei Bus: Failed to load config file in HandlePassengerDropOff: " .. tostring(loadError))
            end
        end

        if Config and Config.Depot then
            stopCoords = Config.Depot.coords
        else
            -- Fallback if config not available
            stopCoords = {x = 456.0, y = -1025.0, z = 28.0}
        end
    end

    if stopCoords then
        TaskLeaveVehicle(passengerPed, busVehicle, 0)

        -- Wait for passenger to exit
        Citizen.CreateThread(function()
            Wait(3000) -- Give time for passenger to exit

            if DoesEntityExist(passengerPed) then
                -- Make passenger walk away from the bus
                local walkAwayX = (stopCoords.x or 456.0) + math.random(-5, 5)
                local walkAwayY = (stopCoords.y or -1025.0) + math.random(-5, 5)
                TaskGoToCoordAnyMeans(passengerPed, walkAwayX, walkAwayY, (stopCoords.z or 28.0), 1.0, 0, false, 786603, 0.5)

                -- Delete passenger after they walk away
                Wait(5000)
                if DoesEntityExist(passengerPed) then
                    DeleteEntity(passengerPed)
                    passengerPed = nil
                    if shared.debug then
                        print("[DEBUG] Sergei Bus: Passenger dropped off and deleted")
                    end
                end
            end
        end)
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

    -- Clean up with completion flag
    EndMission(true)
end

-- EndMission function moved to shared/c_framework.lua

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
                if currentStop > #currentRoute.stops then
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

RegisterNUICallback('closeDashboard', function(data, cb)
    if shared.debug then
        print("[DEBUG] Sergei Bus: closeDashboard NUI callback received!")
    end

    -- Release NUI focus
    SetNuiFocus(false, false)
    menuOpened = false

    if shared.debug then
        print("[DEBUG] Sergei Bus: Dashboard closed, NUI focus released")
    end

    cb('ok')
end)

RegisterNUICallback('startJob', function(data, cb)
    if shared.debug then
        print("[DEBUG] Sergei Bus: startJob NUI callback received!")
        print("[DEBUG] Sergei Bus: data.job = " .. tostring(data.job))
        print("[DEBUG] Sergei Bus: data.index = " .. tostring(data.index))
        print("[DEBUG] Sergei Bus: currentZone = " .. tostring(currentZone))
    end

    if data and data.job and data.index then
        if shared.debug then
            print("[DEBUG] Sergei Bus: All data present, closing NUI and starting job...")
            print("[DEBUG] Sergei Bus: Job name: " .. (data.job.name or "Unknown"))
            print("[DEBUG] Sergei Bus: Job stops count: " .. (data.job.stops and #data.job.stops or "nil"))
            print("[DEBUG] Sergei Bus: Job level: " .. (data.job.level or "nil"))
            print("[DEBUG] Sergei Bus: Job vehicleModel: " .. (data.job.vehicleModel or "nil"))

            -- Debug coordinates from UI
            if data.job.stops and #data.job.stops > 0 then
                for i, stop in ipairs(data.job.stops) do
                    if stop.coords then
                        print("[DEBUG] Sergei Bus: UI job stop " .. i .. " coords: x=" .. tostring(stop.coords.x) .. ", y=" .. tostring(stop.coords.y) .. ", z=" .. tostring(stop.coords.z))
                    elseif stop.x then
                        print("[DEBUG] Sergei Bus: UI job stop " .. i .. " direct: x=" .. tostring(stop.x) .. ", y=" .. tostring(stop.y) .. ", z=" .. tostring(stop.z))
                    else
                        print("[DEBUG] Sergei Bus: UI job stop " .. i .. " has no coordinates!")
                    end
                end
            end
        end

        -- Close the NUI menu first
        SetNuiFocus(false, false)
        menuOpened = false
        SendNUIMessage({
            action = "close"
        })

        -- Use config-based job data instead of shared data
        StartConfigBusJob(data.job, data.index)
    else
        if shared.debug then
            print("[DEBUG] Sergei Bus: Missing required data in startJob callback!")
        end
    end
    cb('ok')
end)

-- Function to start a job using config route data instead of shared data
function StartConfigBusJob(jobData, jobIndex)
    if shared.debug then
        print("[DEBUG] Sergei Bus: StartConfigBusJob called with job: " .. (jobData.name or "Unknown") .. ", index: " .. tostring(jobIndex))
    end

    if working then
        if shared.debug then
            print("[DEBUG] Sergei Bus: Already working, returning")
        end
        return
    end

    -- Check player level with server
    if shared.debug then
        print("[DEBUG] Sergei Bus: Checking if player can do job - Required level: " .. (jobData.level or 1))
        print("[DEBUG] Sergei Bus: Using currentZone: " .. tostring(currentZone) .. ", jobIndex: " .. tostring(jobIndex))
    end

    -- Use currentZone if available, otherwise default to 1 (config-based system)
    local zoneToCheck = currentZone or 1
    local jobIndexToCheck = jobIndex or 1

    lib.callback('sergeis-bus:server:canDoJob', false, function(canDoJob)
        if not canDoJob then
            Framework:Notify("You don't have the required level for this job!", "error")
            if shared.debug then
                print("[DEBUG] Sergei Bus: Player level check failed for job")
            end
            return
        end

        if shared.debug then
            print("[DEBUG] Sergei Bus: Starting config-based job " .. jobData.name .. " (Level " .. (jobData.level or 1) .. ")")
        end

        working = true
        currentJob = {zoneIndex = zoneToCheck, jobIndex = jobIndexToCheck}
        currentRoute = jobData
        currentStop = 1
        headingToDepot = false

        -- Spawn bus vehicle using config data
        if shared.debug then
            print("[DEBUG] Sergei Bus: About to spawn vehicle...")
        end

        local vehicleModel = jobData.vehicleModel or jobData.vehicles or Config.BusModel or 'bus'
        local startCoords = jobData.start and jobData.start[1] or vector3(462.65, -605.81, 28.50)
        local startHeading = jobData.start and jobData.start[2] or 215.05

        if not SpawnBusVehicle(vehicleModel, startCoords, startHeading) then
            working = false
            currentJob = nil
            currentRoute = nil
            currentStop = 1
            if shared.debug then
                print("[DEBUG] Sergei Bus: Vehicle spawning failed, exiting job start")
            end
            return
        end

        if shared.debug then
            print("[DEBUG] Sergei Bus: Vehicle spawned successfully, continuing with waypoints...")
        end

        -- Create route blips using config stops
        if shared.debug then
            print("[DEBUG] Sergei Bus: About to create route blips...")
            print("[DEBUG] Sergei Bus: Config job stops: " .. #jobData.stops)
        end

        CreateRouteBlips(jobData.stops)

        -- Set first destination using config stops
        if shared.debug then
            print("[DEBUG] Sergei Bus: About to set first destination...")
        end

        if jobData.stops and jobData.stops[1] then
            -- Convert config coords to vector4 if needed
            local firstStop = jobData.stops[1]

            if shared.debug then
                print("[DEBUG] Sergei Bus: First stop data: " .. tostring(firstStop))
                if firstStop.coords then
                    print("[DEBUG] Sergei Bus: First stop coords: x=" .. firstStop.coords.x .. ", y=" .. firstStop.coords.y .. ", z=" .. firstStop.coords.z)
                elseif firstStop.x then
                    print("[DEBUG] Sergei Bus: First stop direct: x=" .. firstStop.x .. ", y=" .. firstStop.y .. ", z=" .. firstStop.z)
                end
            end

            local coords
            if firstStop.coords then
                coords = vector4(firstStop.coords.x, firstStop.coords.y, firstStop.coords.z, firstStop.coords.w or 0.0)
            elseif firstStop.x then
                coords = vector4(firstStop.x, firstStop.y, firstStop.z, firstStop.w or 0.0)
            end

            if coords then
                if shared.debug then
                    print("[DEBUG] Sergei Bus: Setting destination to processed coords: x=" .. coords.x .. ", y=" .. coords.y .. ", z=" .. coords.z)
                end
                SetDestination(coords)
            else
                if shared.debug then
                    print("[ERROR] Sergei Bus: Invalid coordinates for first stop")
                end
            end
        else
            if shared.debug then
                print("[ERROR] Sergei Bus: No stops found in config job data")
            end
        end

        Framework:Notify(shared.Locales["get_to_bus"], "success")
    end, zoneToCheck, jobIndexToCheck)
end

-- NUI callback to request routes from config
RegisterNUICallback('requestRoutes', function(data, cb)
    if shared.debug then
        print("[DEBUG] Sergei Bus: requestRoutes NUI callback received!")
    end

    -- Request routes from server using a callback
    lib.callback('sergeis-bus:server:getRoutes', false, function(routes)
        if shared.debug then
            print("[DEBUG] Sergei Bus: Received routes from server: " .. tostring(routes))
            if routes and #routes > 0 then
                for i, route in ipairs(routes) do
                    print("[DEBUG] Sergei Bus: Client received route " .. i .. ": " .. route.name)
                    if route.stops and #route.stops > 0 then
                        for j, stop in ipairs(route.stops) do
                            if stop.coords then
                                print("[DEBUG] Sergei Bus: Client route " .. i .. " stop " .. j .. " coords: x=" .. tostring(stop.coords.x) .. ", y=" .. tostring(stop.coords.y) .. ", z=" .. tostring(stop.coords.z))
                            elseif stop.x then
                                print("[DEBUG] Sergei Bus: Client route " .. i .. " stop " .. j .. " direct: x=" .. tostring(stop.x) .. ", y=" .. tostring(stop.y) .. ", z=" .. tostring(stop.z))
                            else
                                print("[DEBUG] Sergei Bus: Client route " .. i .. " stop " .. j .. " has no coordinates!")
                            end
                        end
                    end
                end
            end
        end

        -- Send routes data to NUI
        SendNUIMessage({
            action = "updateRoutes",
            routes = routes or {}
        })
    end)

    cb('ok')
end)

-- Event handlers
RegisterNetEvent('sergeis-bus:client:sendNotifys', function(msg, tip)
    Framework:Notify(msg, tip)
end)

RegisterNetEvent('sergeis-bus:client:updatePlayerLevel', function(level, xp, stats)
    if menuOpened then
        -- Update the NUI with actual player level and complete stats
        local messageData = {
            action = "updateLevel",
            level = level,
            xp = xp
        }

        -- Include full stats if available
        if stats then
            messageData.stats = stats
        end

        SendNUIMessage(messageData)

        if shared.debug then
            print("[DEBUG] Sergei Bus: Sent player level update - Level: " .. level .. ", XP: " .. xp)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    EndMission()
end)
