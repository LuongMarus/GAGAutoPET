--[[
    PROJECT: HUB SCRIPT AUTO FARM PET
    VERSION: Marus Ver 1.2 (Module Structure)
    AUTHOR: Marus
    UI LIB: Fluent
    GAME: Grow A Garden
    
    STRUCTURE:
    - main.lua (Entry point)
    - modules/config.lua (Configuration)
    - modules/webhook.lua (Discord webhooks)
    - modules/core.lua (Farm logic)
    - modules/ui.lua (User interface)
]]

-- Load Fluent UI Library
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

-- Load Modules từ GitHub
local baseURL = "https://raw.githubusercontent.com/LuongMarus/GAGAutoPET/main/modules/"

-- Setup dependencies trước (placeholder)
getgenv().__AutoFarmDeps = {}

-- Load Config và Webhook trước (không phụ thuộc gì)
local Config = loadstring(game:HttpGet(baseURL .. "config.lua"))()
local Webhook = loadstring(game:HttpGet(baseURL .. "webhook.lua"))()

-- Cập nhật dependencies
getgenv().__AutoFarmDeps.Config = Config
getgenv().__AutoFarmDeps.Webhook = Webhook

-- Giờ mới load Core (cần Config + Webhook)
local Core = loadstring(game:HttpGet(baseURL .. "core.lua"))()

-- Update deps với Core
getgenv().__AutoFarmDeps.Core = Core

-- Load UI cuối cùng (cần Config + Webhook + Core)
local UI = loadstring(game:HttpGet(baseURL .. "ui.lua"))()

-- Khởi tạo config
Config.Initialize()

-- Framework Test Notification
pcall(function()
    Fluent:Notify({
        Title = "Framework Test",
        Content = "Initializing framework test...",
        Duration = 3
    })
end)

-- Khởi tạo UI
local Window, Tabs = UI.Initialize(Fluent)

-- Vòng lặp farm chính
task.spawn(function()
    while task.wait(1.5) do
        local settings = Config.GetSettings()
        if settings.IsRunning then
            pcall(function()
                -- Scan và cập nhật storage liên tục
                Core.ScanAndUpdateStorage(function(title, content, duration)
                    UI.Notify(title, content, duration)
                end)
                
                -- Farm logic
                local occupied, targetCount = Core.ManageGarden(function(title, content, duration)
                    UI.Notify(title, content, duration)
                end)
                
                Core.PlantPets(occupied, targetCount)
                
                -- Cập nhật Misc tab
                UI.UpdateMiscPetList()
            end)
        end
    end
end)

print("[MARUS HUB] Loaded successfully with modular structure!")
