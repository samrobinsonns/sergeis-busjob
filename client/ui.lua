-- UI Helper Functions

-- Show route information
function ShowRouteUI(routeName, currentStop, totalStops, nextStop)
    SendNUIMessage({
        type = 'showRoute',
        routeName = routeName,
        currentStop = currentStop,
        totalStops = totalStops,
        nextStop = nextStop
    })
end

-- Show stop information
function ShowStopUI(stopName, currentStop, totalStops)
    SendNUIMessage({
        type = 'showStop',
        stopName = stopName,
        currentStop = currentStop,
        totalStops = totalStops
    })
end

-- Update progress
function UpdateProgressUI(currentStop, totalStops, nextStop)
    SendNUIMessage({
        type = 'updateProgress',
        currentStop = currentStop,
        totalStops = totalStops,
        nextStop = nextStop
    })
end

-- Show payment information
function ShowPaymentUI(basePayment, passengerBonus, totalPayment, totalPassengers)
    SendNUIMessage({
        type = 'showPayment',
        basePayment = basePayment,
        passengerBonus = passengerBonus,
        totalPayment = totalPayment,
        totalPassengers = totalPassengers
    })
end

-- Show message
function ShowMessageUI(message)
    SendNUIMessage({
        type = 'showMessage',
        message = message
    })
end

-- Hide UI
function HideUI()
    SendNUIMessage({
        type = 'hideUI'
    })
end

-- Show help text
function ShowHelpText()
    SendNUIMessage({
        type = 'showHelp',
        helpText = {
            'Press E to load passengers at stops',
            'Complete the route to return to depot',
            'Use /startbus [route] to start a route',
            'Use /endbus to end current route'
        }
    })
end
