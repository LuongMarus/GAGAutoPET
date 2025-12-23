--[[
    MODULE: UI
    DESCRIPTION: Giao diện Fluent UI cho Auto Farm
    AUTHOR: Marus
]]

local UI = {}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Deps
local Deps = getgenv().__AutoFarmDeps
local Config = Deps.Config
local Webhook = Deps.Webhook
local Core = Deps.Core

-- Shortcut
local function Settings()
    return Config.GetSettings()
end

-- =====================
-- Notify helper
-- =====================
function UI.Notify(title, content, duration)
    pcall(function()
        UI.Fluent:Notify({
            Title = title or "Info",
            Content = content or "",
            Duration = duration or 3
        })
    end)
end

-- =====================
-- Initialize UI
-- =====================
function UI.Initialize(Fluent)
    UI.Fluent = Fluent

    local Window = Fluent:CreateWindow({
        Title = "Marus Hub | Marus Ver 1.1 | Grow A Garden",
        SubTitle = "Auto Farm Pet",
        TabWidth = 160,
        Size = UDim2.fromOffset(520, 420),
        Acrylic = true,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.RightControl
    })

    local Tabs = {
        AutoFarm = Window:AddTab({ Title = "Auto Farm", Icon = "leaf" }),
        Misc     = Window:AddTab({ Title = "Misc", Icon = "list" }),
        Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
    }

    -- =========================================================
    -- AUTO FARM TAB
    -- =========================================================
    do
        local Tab = Tabs.AutoFarm
        local s = Settings()

        Tab:AddToggle("AutoFarmToggle", {
            Title = "Bật Auto Farm",
            Default = s.IsRunning,
            Callback = function(value)
                Config.UpdateSetting("IsRunning", value)
                UI.Notify("Auto Farm", value and "Đã bật" or "Đã tắt", 2)
            end
        })

        Tab:AddInput("BasePetName", {
            Title = "Tên Gốc Pet (Base Name)",
            Default = s.SelectedSpecies,
            Placeholder = "Ví dụ: Phoenix, Dragon, Bee",
            Callback = function(value)
                Config.UpdateSetting("SelectedSpecies", string.lower(value))
                if value ~= "" then
                    Core.ScanAndBuildTargetList()
                    UI.Notify("Scanned", "Danh sách pet đã cập nhật", 3)
                end
            end
        })

        Tab:AddToggle("ExcludeMutation", {
            Title = "Loại Trừ Mutation",
            Default = s.ExcludeMutation,
            Callback = function(value)
                Config.UpdateSetting("ExcludeMutation", value)
            end
        })

        Tab:AddButton({
            Title = "Quét Lại Danh Sách (Re-scan)",
            Description = "Cập nhật danh sách pet sau khi mua/nở/mutation",
            Callback = function()
                Core.ScanAndBuildTargetList()
                UI.Notify("Re-scanned", "Danh sách pet đã cập nhật", 2)
            end
        })

        Tab:AddSlider("TargetAge", {
            Title = "Tuổi Thu Hoạch",
            Min = 1,
            Max = 100,
            Default = s.TargetAge,
            Rounding = 0,
            Callback = function(value)
                Config.UpdateSetting("TargetAge", value)
            end
        })

        Tab:AddSlider("MaxSlots", {
            Title = "Tổng Slot Vườn",
            Min = 1,
            Max = 10,
            Default = s.MaxSlots,
            Rounding = 0,
            Callback = function(value)
                Config.UpdateSetting("MaxSlots", value)
            end
        })

        Tab:AddSlider("FarmLimit", {
            Title = "Farm Limit",
            Min = 1,
            Max = 10,
            Default = s.FarmLimit,
            Rounding = 0,
            Callback = function(value)
                Config.UpdateSetting("FarmLimit", value)
            end
        })
    end

    -- =========================================================
    -- MISC TAB (Dashboard)
    -- =========================================================
    do
        local Tab = Tabs.Misc
        local PetListLabel

        PetListLabel = Tab:AddParagraph({
            Title = "Pet Dashboard",
            Content = "Chưa có dữ liệu"
        })

        function UI.UpdateMiscPetList()
            local s = Settings()
            local storage = s.PetStorage or {}

            local lines = {}
            local active = 0
            local excluded = 0
            local waiting = 0

            for uuid, pet in pairs(storage) do
                local ageText = pet.Age == nil and "?" or tostring(pet.Age)
                local status = pet.Status or "Waiting"

                if status == "Active" then active += 1
                elseif status == "Excluded" then excluded += 1
                else waiting += 1 end

                table.insert(lines, string.format(
                    "- %s | Age: %s | %s | %s",
                    pet.Name or uuid,
                    ageText,
                    status,
                    pet.Mutation or "Normal"
                ))
            end

            local summary = string.format(
                "Slots: %d / %d\nFarmLimit: %d\nActive: %d | Waiting: %d | Excluded: %d\n\n",
                s.ActiveSlots or 0,
                s.MaxSlots,
                s.FarmLimit,
                active,
                waiting,
                excluded
            )

            PetListLabel:Set({
                Title = "Pet Dashboard",
                Content = summary .. table.concat(lines, "\n")
            })
        end
    end

    -- =========================================================
    -- SETTINGS TAB
    -- =========================================================
    do
        local Tab = Tabs.Settings
        local s = Settings()

        Tab:AddInput("WebhookURL", {
            Title = "Discord Webhook URL",
            Default = s.WebhookURL,
            Placeholder = "https://discord.com/api/webhooks/...",
            Callback = function(value)
                Config.UpdateSetting("WebhookURL", value)
            end
        })

        Tab:AddButton({
            Title = "Test Webhook",
            Callback = function()
                Webhook.SendPetMaxLevel("Test Pet", 999, Settings().WebhookURL)
                UI.Notify("Webhook", "Đã gửi webhook test", 2)
            end
        })
    end

    return Window, Tabs
end

return UI
--------------------------------------------------