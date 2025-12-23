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

-- Load Modules
local modulesFolder = script:FindFirstChild("modules") or script.Parent:FindFirstChild("modules")

if not modulesFolder then
    error("[ERROR] Modules folder not found!")
    return
end

local Config = require(modulesFolder.config)
local Core = require(modulesFolder.core)
local UI = require(modulesFolder.ui)

-- Khởi tạo config
Config.Initialize()

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
