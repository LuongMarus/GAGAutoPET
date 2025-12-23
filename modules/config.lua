--[[
    MODULE: CONFIG
    DESCRIPTION: Quản lý cấu hình toàn cục
]]

local Config = {}

-- Khởi tạo cấu hình mặc định
function Config.Initialize()
    getgenv().FarmSettings = getgenv().FarmSettings or {
        IsRunning = false,
        SelectedSpecies = "",
        TargetAge = 50,
        MaxSlots = 6,
        FarmLimit = 6,
        WebhookURL = "",
        ExcludeMutation = true,
        TargetUUIDs = {},
        PetStorage = {}
    }
end

-- Lấy settings hiện tại
function Config.GetSettings()
    return getgenv().FarmSettings
end

-- Cập nhật setting
function Config.UpdateSetting(key, value)
    if getgenv().FarmSettings[key] ~= nil then
        getgenv().FarmSettings[key] = value
        return true
    end
    return false
end

return Config
