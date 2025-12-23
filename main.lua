local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
getgenv().__AutoFarmDeps = {}

-- Load Modules
local baseURL = "https://raw.githubusercontent.com/LuongMarus/GAGAutoPET/main/modules/"
local Config = loadstring(game:HttpGet(baseURL .. "config.lua"))()
local PetStorage = loadstring(game:HttpGet(base.."petstorage.lua"))()
local Webhook = loadstring(game:HttpGet(base.."webhook.lua"))()
getgenv().__AutoFarmDeps.Config = Config
getgenv().__AutoFarmDeps.PetStorage = PetStorage
getgenv().__AutoFarmDeps.Webhook = Webhook

local Core = loadstring(game:HttpGet(baseURL .. "core.lua"))()
local UI = loadstring(game:HttpGet(baseURL .. "ui.lua"))()
getgenv().__AutoFarmDeps.Core = Core

Config.Initialize()
UI.Initialize(Fluent)

-- Main Loop
task.spawn(function()
    while task.wait(1.5) do
        local s = Config.GetSettings()
        if s.IsRunning then
            pcall(function()
                Core.ManageGarden(UI.Notify)
                local occupied, targetCount = Core.ScanAndUpdateStorage(UI.Notify)
                Core.PlantPets(occupied, targetCount)
            end)
        end
    end
end)