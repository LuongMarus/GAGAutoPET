local UI = {}
function UI.Initialize(Fluent)
    UI.Fluent = Fluent
    local Window = Fluent:CreateWindow({
        Title = "Marus Hub | v1.2",
        SubTitle = "Grow A Garden",
        TabWidth = 160,
        Size = UDim2.fromOffset(520, 420),
        Theme = "Dark"
    })

    local Tabs = {
        Farm = Window:AddTab({ Title = "Auto Farm", Icon = "leaf" }),
        Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
    }

    local s = getgenv().__AutoFarmDeps.Config.GetSettings()

    Tabs.Farm:AddToggle("MainToggle", {
        Title = "Bật Auto Farm",
        Default = s.IsRunning,
        Callback = function(v) s.IsRunning = v end
    })

    Tabs.Farm:AddInput("Species", {
        Title = "Tên Pet (Ví dụ: Phoenix)",
        Callback = function(v) 
            s.SelectedSpecies = v
            local Core = getgenv().__AutoFarmDeps.Core
            if Core and Core.ScanAndUpdateStorage then
                Core.ScanAndUpdateStorage(UI.Notify)
            end
        end
    })

    Tabs.Farm:AddSlider("Age", { Title = "Tuổi thu hoạch", Min = 1, Max = 100, Default = 50, Callback = function(v) s.TargetAge = v end })

    Tabs.Farm:AddButton("ReScan", {
        Title = "Quét Lại Danh Sách",
        Callback = function()
            local Core = getgenv().__AutoFarmDeps.Core
            if Core and Core.ScanAndUpdateStorage then
                Core.ScanAndUpdateStorage(UI.Notify)
            end
        end
    })
    
    return Window, Tabs
end

function UI.Notify(title, content, duration)
    if UI.Fluent then
        UI.Fluent:Notify({Title = title, Content = content, Duration = duration or 3})
    end
end

return UI