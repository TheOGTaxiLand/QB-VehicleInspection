local QBCore = exports['qb-core']:GetCoreObject()
local oxmysql = exports.oxmysql

-- Utility: format future expiration timestamp string
local function futureDate(days)
    return os.date('%Y-%m-%d %H:%M:%S', os.time() + (days * 86400))
end

-- Convert MySQL datetime string "YYYY-MM-DD HH:MM:SS" to os.time table
local function datetimeToTable(date)
    if not date then return nil end
    local y, m, d, h, i, s = date:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    return {
        year = tonumber(y),
        month = tonumber(m),
        day = tonumber(d),
        hour = tonumber(h),
        min = tonumber(i),
        sec = tonumber(s)
    }
end

-- Insert log
local function logInspection(player, plate, passed, checks)
    local expires_at = passed and futureDate(Config.ExpirationDays) or nil
    oxmysql:insert(
        'INSERT INTO vehicle_inspections (citizenid, name, plate, passed, checks, expires_at) VALUES (?, ?, ?, ?, ?, ?)',
        {
            player.PlayerData.citizenid,
            player.PlayerData.charinfo.firstname .. " " .. player.PlayerData.charinfo.lastname,
            plate,
            passed and 1 or 0,
            json.encode(checks),
            expires_at
        }
    )
end

-- Get latest inspection row for plate
local function getLatestInspection(plate, cb)
    oxmysql:single(
        'SELECT * FROM vehicle_inspections WHERE plate = ? ORDER BY created_at DESC LIMIT 1',
        { plate },
        function(row)
            if not row then cb(nil) return end
            row.expired = true
            if row.expires_at then
                local t = datetimeToTable(row.expires_at)
                if t and os.time(t) > os.time() then
                    row.expired = false
                end
            end
            cb(row)
        end
    )
end

-- Check reward cooldown (recent successful give)
local function checkRecentPass(plate, minutes, cb)
    oxmysql:scalar(
        'SELECT created_at FROM vehicle_inspections WHERE plate = ? AND passed = 1 ORDER BY created_at DESC LIMIT 1',
        { plate },
        function(last)
            if not last then cb(false) return end
            local t = datetimeToTable(last)
            if not t then cb(false) return end
            local diff = os.time() - os.time(t)
            cb(diff < (minutes * 60))
        end
    )
end

-- Server-side validation of checks table
local function validateChecks(checks)
    if not checks then return false end
    if not tonumber(checks.engine) or tonumber(checks.engine) < Config.EngineHealthThreshold then return false end
    if not tonumber(checks.body) or tonumber(checks.body) < Config.BodyHealthThreshold then return false end
    if tonumber(checks.burstTyres) == nil or tonumber(checks.burstTyres) > Config.MaxBurstTyres then return false end
    if tonumber(checks.missingWindows) == nil or tonumber(checks.missingWindows) > Config.MaxMissingWindows then return false end
    return true
end

-- Give reward endpoint called by client when inspection passes UI
RegisterNetEvent('qb-vehicleinspect:server:awardIfValid', function(plate, checks)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- validate
    local valid = validateChecks(checks)
    if not valid then
        logInspection(Player, plate, false, checks)
        TriggerClientEvent('QBCore:Notify', src, "Inspection failed server validation.", "error")
        return
    end

    -- reward cooldown by plate
    checkRecentPass(plate, Config.RewardCooldownMinutes, function(inCooldown)
        if inCooldown then
            logInspection(Player, plate, true, checks)
            TriggerClientEvent('QBCore:Notify', src, ("Vehicle %s was inspected recently. Try later."):format(plate), "error")
            return
        end

        -- Add item + notify
        Player.Functions.AddItem(Config.RewardItem, Config.RewardAmount)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.RewardItem], "add")
        TriggerClientEvent('QBCore:Notify', src, "Inspection passed. You received a certificate.", "success")

        logInspection(Player, plate, true, checks)
    end)
end)

-- Export usable by other resources: check if a vehicle plate has a valid (non-expired) inspection
exports('IsVehicleInspectionValid', function(plate, cb)
    getLatestInspection(plate, function(row)
        if not row or row.passed ~= 1 or row.expired then
            cb(false)
        else
            cb(true)
        end
    end)
end)

-- Command: /viewinspections PLATE (for allowed jobs)
QBCore.Commands.Add(Config.ViewCommand, "View vehicle inspection history", {{name="plate", help="Plate number"}}, false, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if not Config.AllowedJobs[ Player.PlayerData.job.name ] then
        TriggerClientEvent('QBCore:Notify', src, "You are not authorized to use this.", "error")
        return
    end

    local plate = args[1]
    if not plate or plate == '' then
        TriggerClientEvent('QBCore:Notify', src, "Usage: /viewinspections PLATE", "error")
        return
    end

    oxmysql:fetch('SELECT * FROM vehicle_inspections WHERE plate = ? ORDER BY created_at DESC LIMIT 50', { plate }, function(rows)
        TriggerClientEvent("qb-vehicleinspect:client:showInspectionUI", src, plate, rows)
    end)
end)
