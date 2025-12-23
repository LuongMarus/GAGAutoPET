local Config = {}

function Config.Initialize()
    getgenv().FarmSettings = getgenv().FarmSettings or {
        IsRunning = false,
        IsDestroyed = false,
        SelectedSpecies = "",
        TargetAge = 50,
        MaxSlots = 6,
        FarmLimit = 6,
        WebhookURL = "",
        ExcludeMutation = true,
        TargetUUIDs = {},
        PetStorage = {},
        ActiveSlots = 0
    }
end

function Config.GetSettings()
    return getgenv().FarmSettings
end

function Config.UpdateSetting(key, value)
    local s = Config.GetSettings()
    if s[key] ~= nil then
        s[key] = value
        return true
    end
    return false
end

return Config