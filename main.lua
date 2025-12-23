--====================================================
-- MARUS HUB - MAIN LOADER (FINAL / HARDENED)
-- GAME: Grow A Garden
--====================================================

-- ===== PRE-FLIGHT CHECK =====
assert(game and game.GetService, "[BOOT] Invalid execution environment")

-- ===== LOAD FLUENT UI =====
local Fluent
do
    local ok, lib = pcall(function()
        return loadstring(game:HttpGet(
            "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"
        ))()
    end)
    assert(ok and lib, "[BOOT] Failed to load Fluent UI")
    Fluent = lib
end

-- ===== GLOBAL DEPENDENCY ROOT =====
getgenv().__AutoFarmDeps = {}

-- ===== BASE URL (SINGLE SOURCE OF TRUTH) =====
local baseURL = "https://raw.githubusercontent.com/LuongMarus/GAGAutoPET/main/modules/"
assert(type(baseURL) == "string", "[BOOT] baseURL invalid")

-- ===== CACHE BUSTER (ANTI ROBLOX CACHE) =====
local CACHE = "?v=" .. tostring(os.time()) .. tostring(math.random(1000,9999))

-- ===== SAFE MODULE LOADER =====
local function LoadModule(name)
    local url = baseURL .. name .. CACHE
    local source

    local okHttp, errHttp = pcall(function()
        source = game:HttpGet(url)
    end)
    assert(okHttp and source, "[BOOT] HttpGet failed: " .. name)

    local fn, errParse = loadstring(source)
    assert(fn, "[BOOT] Syntax error in " .. name .. ": " .. tostring(errParse))

    local okExec, module = pcall(fn)
    assert(okExec and module, "[BOOT] Runtime error in " .. name)

    return module
end

-- ===== LOAD CORE MODULES (ORDER MATTERS) =====
local Config  = LoadModule("config.lua")
local Webhook = LoadModule("webhook.lua")

-- Inject deps early
getgenv().__AutoFarmDeps.Config  = Config
getgenv().__AutoFarmDeps.Webhook = Webhook

-- Init config BEFORE Core
assert(Config.Initialize, "[BOOT] Config.Initialize missing")
Config.Initialize()

-- Load Core + UI
local Core = LoadModule("core.lua")
local UI   = LoadModule("ui.lua")

getgenv().__AutoFarmDeps.Core = Core

-- ===== INIT UI =====
local okUI, Window = pcall(function()
    return UI.Initialize(Fluent)
end)
assert(okUI, "[BOOT] UI initialization failed")

-- ===== MAIN LOOP (SAFE / KILLABLE) =====
task.spawn(function()
    while task.wait(1.5) do
        local settings = Config.GetSettings()

        -- HARD KILL
        if settings.IsDestroyed then
            warn("[MARUS HUB] Script destroyed. Main loop stopped.")
            break
        end

        if settings.IsRunning then
            pcall(function()
                -- Order is IMPORTANT
                Core.ManageGarden(UI.Notify)
                local occupied, targetCount =
                    Core.ScanAndUpdateStorage(UI.Notify)
                Core.PlantPets(occupied, targetCount)
            end)
        end
    end
end)

print("[MARUS HUB] Loader initialized successfully")
