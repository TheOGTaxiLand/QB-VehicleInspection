-- Config (shared)
Config = {}

-- Reward / item
Config.RewardItem = 'inspection'
Config.RewardAmount = 1

-- Check thresholds (server/enforced)
Config.EngineHealthThreshold = 400.0
Config.BodyHealthThreshold = 400.0
Config.MaxBurstTyres = 1
Config.MaxMissingWindows = 2

-- Inspection expiration and cooldown
Config.ExpirationDays = 365       -- inspection valid for 365 days
Config.RewardCooldownMinutes = 10 -- prevents double rewarding same vehicle in short time

-- Permissions
Config.ViewCommand = 'viewinspections'
Config.AllowedJobs = { ['mechanic'] = true, ['police'] = true, } -- who can use /viewinspections

-- UI settings
Config.NUIResourceName = GetCurrentResourceName and GetCurrentResourceName() or 'qb-vehicleinspection'
