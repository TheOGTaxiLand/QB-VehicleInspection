local QBCore = exports['qb-core']:GetCoreObject()
local nuiOpen = false
local inspectVehicle = nil

-- helper: find vehicle in front
local function GetVehicleInFront(distance)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local target = pos + forward * distance
    local ray = StartShapeTestCapsule(pos.x, pos.y, pos.z, target.x, target.y, target.z, 2.0, 10, ped, 7)
    local _, hit, endCoords, surfaceNormal, entity = GetShapeTestResult(ray)
    if hit == 1 and DoesEntityExist(entity) and IsEntityAVehicle(entity) then
        return entity
    end
    return nil
end

-- Build checks table from vehicle entity
local function gatherChecks(veh)
    local checks = {}
    checks.engine = GetVehicleEngineHealth(veh) or 0
    checks.body = GetVehicleBodyHealth(veh) or 0
    checks.burstTyres = 0
    for i = 0, 7 do
        local ok, isBurst = pcall(IsVehicleTyreBurst, veh, i, true)
        if ok and isBurst then checks.burstTyres = checks.burstTyres + 1 end
    end
    checks.missingWindows = 0
    for i = 0, 7 do
        if not IsVehicleWindowIntact(veh, i) then checks.missingWindows = checks.missingWindows + 1 end
    end
    checks.plate = GetVehicleNumberPlateText(veh) or "UNKNOWN"
    return checks
end

-- Open inspection NUI with checks
local function openInspectionUI(checks)
    SendNUIMessage({
        action = "openUI",
        plate = checks.plate,
        engine = math.floor(checks.engine),
        body = math.floor(checks.body),
        burstTyres = checks.burstTyres,
        missingWindows = checks.missingWindows,
        lights = "Not Checked" -- placeholder if you later add more checks
    })
    SetNuiFocus(true, true)
    nuiOpen = true
end

-- NUI callback endpoints via POST are handled by fetch in NUI; we define handlers here for server messages:
RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    nuiOpen = false
    cb({ ok = true })
end)

-- Listen for history UI open (server sends rows)
RegisterNetEvent("qb-vehicleinspect:client:showInspectionUI", function(plate, data)
    SendNUIMessage({
        action = "openHistory",
        plate = plate,
        history = data
    })
    SetNuiFocus(true, true)
    nuiOpen = true
end)

-- Listen for message from NUI to finish inspection (NUI posts to resource endpoint which triggers server events via this code)
-- We need to register a NUI callback endpoint names (these are called by the HTML fetch endpoints)
-- FiveM will map HTML fetch to a resource endpoint we define via RegisterNUICallback

RegisterNUICallback('inspectionResult', function(data, cb)
    -- data: { passed = true/false, checks = checksTable }
    SetNuiFocus(false, false)
    nuiOpen = false

    local passed = data.passed
    local checks = data.checks or {}

    if passed then
        -- ask server to award if valid
        TriggerServerEvent('qb-vehicleinspect:server:awardIfValid', checks.plate or "UNKNOWN", checks)
    else
        -- simply log failed attempt server-side for auditing
        TriggerServerEvent('qb-vehicleinspect:server:awardIfValid', checks.plate or "UNKNOWN", checks) -- server will mark as failed if validation fails; we can also add dedicated event
    end

    cb({ ok = true })
end)

-- Register /inspect command and keybind
RegisterCommand('inspect', function()
    if nuiOpen then return end
    local veh = GetVehicleInFront(5.0)
    if not veh then
        QBCore.Functions.Notify("No vehicle in front.", "error")
        return
    end
    local checks = gatherChecks(veh)
    openInspectionUI(checks)
end)

RegisterKeyMapping('inspect', 'Inspect vehicle in front', 'keyboard', 'E')
