--[[
    MODULE: UI
    DESCRIPTION: Giao diện người dùng (Fluent UI)
]]

local UI = {}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Dependencies
local Config = getgenv().__AutoFarmDeps.Config
local Core = getgenv().__AutoFarmDeps.Core
local Webhook = getgenv().__AutoFarmDeps.Webhook

-- UI References
local Window
local Tabs = {}
local MiscUI = {
    PetListLabel = nil
}
local FarmToggle

-- Tạo nút toggle cho mobile
local function CreateMobileToggle()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "MarusToggleButton"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Name = "ToggleButton"
    ToggleButton.Parent = ScreenGui
    ToggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    ToggleButton.BorderSizePixel = 0
    ToggleButton.Position = UDim2.new(0, 10, 0.5, -25)
    ToggleButton.Size = UDim2.new(0, 50, 0, 50)
    ToggleButton.Font = Enum.Font.GothamBold
    ToggleButton.Text = "M"
    ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleButton.TextSize = 20
    ToggleButton.AutoButtonColor = false

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 10)
    UICorner.Parent = ToggleButton

    local UIStroke = Instance.new("UIStroke")
    UIStroke.Color = Color3.fromRGB(100, 100, 100)
    UIStroke.Thickness = 2
    UIStroke.Parent = ToggleButton

    local dragging = false
    local dragInput, dragStart, startPos

    ToggleButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = ToggleButton.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    ToggleButton.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            ToggleButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    ToggleButton.MouseButton1Click:Connect(function()
        Window:Minimize()
    end)

    ScreenGui.Parent = game:GetService("CoreGui")
end

-- Cập nhật Misc pet list
local function UpdateMiscPetList()
    if not MiscUI.PetListLabel then return end
    
    local settings = Config.GetSettings()
    local targetUUIDs = settings.TargetUUIDs
    local targetAge = settings.TargetAge
    
    if #targetUUIDs == 0 then
        MiscUI.PetListLabel:SetTitle("Danh Sách Pet Target")
        MiscUI.PetListLabel:SetDesc("Chưa có pet nào trong danh sách.\nVui lòng nhập tên pet và quét!")
        return
    end
    
    local petInfoList = {}
    local Backpack = LocalPlayer:FindFirstChild("Backpack")
    local Character = LocalPlayer.Character
    
    for i, uuid in ipairs(targetUUIDs) do
        local petInfo = {
            uuid = uuid,
            name = "Unknown",
            age = 0,
            weight = "N/A",
            mutation = "Unknown",
            status = "[?] KHÔNG TÌM THẤY",
            location = "Unknown"
        }
        
        local found = false
        
        if Backpack then
            for _, tool in pairs(Backpack:GetChildren()) do
                if tool:IsA("Tool") and tool.Name == uuid then
                    found = true
                    petInfo.location = "Backpack"
                    
                    local baseName = string.match(tool.Name, "^(.+) %[") or tool.Name
                    petInfo.name = baseName
                    
                    local ageMatch = string.match(tool.Name, "Age (%d+)")
                    petInfo.age = ageMatch and tonumber(ageMatch) or 0
                    
                    local weightMatch = string.match(tool.Name, "(%d+%.%d+) KG")
                    petInfo.weight = weightMatch or "N/A"
                    
                    local isMut, mutType = Core.IsMutation(baseName)
                    petInfo.mutation = mutType
                    
                    petInfo.status = petInfo.age >= targetAge and "[OK] ĐẠT" or "[X] CHƯA ĐẠT"
                    break
                end
            end
        end
        
        if not found and Character then
            for _, tool in pairs(Character:GetChildren()) do
                if tool:IsA("Tool") and tool.Name == uuid then
                    found = true
                    petInfo.location = "Equipped"
                    
                    local baseName = string.match(tool.Name, "^(.+) %[") or tool.Name
                    petInfo.name = baseName
                    
                    local ageMatch = string.match(tool.Name, "Age (%d+)")
                    petInfo.age = ageMatch and tonumber(ageMatch) or 0
                    
                    local weightMatch = string.match(tool.Name, "(%d+%.%d+) KG")
                    petInfo.weight = weightMatch or "N/A"
                    
                    local isMut, mutType = Core.IsMutation(baseName)
                    petInfo.mutation = mutType
                    
                    petInfo.status = petInfo.age >= targetAge and "[OK] ĐẠT" or "[X] CHƯA ĐẠT"
                    break
                end
            end
        end
        
        if not found then
            local baseName = string.match(uuid, "^(.+) %[") or uuid
            petInfo.name = baseName
            
            local ageMatch = string.match(uuid, "Age (%d+)")
            petInfo.age = ageMatch and tonumber(ageMatch) or 0
            
            local weightMatch = string.match(uuid, "(%d+%.%d+) KG")
            petInfo.weight = weightMatch or "N/A"
            
            local isMut, mutType = Core.IsMutation(baseName)
            petInfo.mutation = mutType
            
            petInfo.status = petInfo.age >= targetAge and "[OK] ĐẠT" or "[~] ĐÃ PLANT"
            petInfo.location = "In Garden/UI"
        end
        
        table.insert(petInfoList, petInfo)
    end
    
    local content = ""
    for i, info in ipairs(petInfoList) do
        content = content .. string.format(
            "[%d] %s\n   UUID: %s...\n   Age: %d | Weight: %s KG\n   Mutation: %s | Location: %s\n   %s\n\n",
            i, 
            info.name, 
            string.sub(info.uuid, 1, 30),
            info.age, 
            info.weight,
            info.mutation, 
            info.location, 
            info.status
        )
    end
    
    MiscUI.PetListLabel:SetTitle("Danh Sách Pet Target (" .. #petInfoList .. " pets)")
    MiscUI.PetListLabel:SetDesc(content)
end

-- Khởi tạo UI
function UI.Initialize(Fluent)
    Window = Fluent:CreateWindow({
        Title = "Marus Hub | Marus Ver 1.1",
        SubTitle = "Grow A Garden",
        TabWidth = 160,
        Size = UDim2.fromOffset(580, 460),
        Acrylic = true,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.LeftControl
    })

    CreateMobileToggle()

    Tabs = {
        Info = Window:AddTab({ Title = "Info", Icon = "info" }),
        Farm = Window:AddTab({ Title = "Auto Farm", Icon = "sprout" }),
        Misc = Window:AddTab({ Title = "Misc", Icon = "list" }),
        Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
    }

    UI.BuildInfoTab(Fluent)
    UI.BuildFarmTab(Fluent)
    UI.BuildMiscTab(Fluent)
    UI.BuildSettingsTab(Fluent)

    Fluent:Notify({
        Title = "Marus Auto Farm Ver 1.1",
        Content = "Script Loaded Successfully!",
        Duration = 5
    })
    
    return Window, Tabs
end

-- Build Info tab
function UI.BuildInfoTab(Fluent)
    Tabs.Info:AddParagraph({
        Title = "Thông tin Script",
        Content = "Script Auto Farm Pet made By Marus Ver 1.1\nCấu trúc module hóa chuẩn Lua."
    })
    
    Tabs.Info:AddButton({
        Title = "Copy Discord Link",
        Description = "Copy link Discord vào clipboard",
        Callback = function()
            setclipboard("https://discord.gg/YourLinkHere")
            Fluent:Notify({Title = "Success", Content = "Đã copy link Discord!", Duration = 5})
        end
    })
end

-- Build Farm tab
function UI.BuildFarmTab(Fluent)
    Tabs.Farm:AddParagraph({
        Title = "Cấu Hình Farm",
        Content = "Nhập tên gốc pet (ví dụ: Phoenix) để farm tất cả loài có tên đó."
    })

    Tabs.Farm:AddInput("PetNameInput", {
        Title = "Tên Gốc Pet (Base Name)",
        Description = "Nhập tên gốc (ví dụ: Phoenix, Dragon, Bee)",
        Default = "",
        Placeholder = "Phoenix",
        Numeric = false,
        Finished = true,
        Callback = function(Value)
            Config.UpdateSetting("SelectedSpecies", Value)
            
            if Value ~= "" then
                Core.ScanAndBuildTargetList()
                Fluent:Notify({
                    Title = "Auto Storage",
                    Content = "Pet sẽ được tự động lưu và scan liên tục!",
                    Duration = 5
                })
            end
        end
    })

    Tabs.Farm:AddToggle("ExcludeMutationToggle", {
        Title = "Loại Trừ Mutation",
        Description = "Bật để bỏ qua pet Mega, Rainbow, Ascended, Nightmare...",
        Default = true,
        Callback = function(Value)
            Config.UpdateSetting("ExcludeMutation", Value)
            if Value then
                Fluent:Notify({
                    Title = "Exclude Mutation",
                    Content = "Chỉ farm pet gốc, không farm mutation!",
                    Duration = 3
                })
            else
                Fluent:Notify({
                    Title = "Include All",
                    Content = "Farm tất cả pet kể cả mutation!",
                    Duration = 3
                })
            end
            
            local settings = Config.GetSettings()
            if settings.SelectedSpecies ~= "" then
                Core.ScanAndBuildTargetList()
            end
        end
    })

    Tabs.Farm:AddButton({
        Title = "Quét Lại Danh Sách (Re-scan)",
        Description = "Bấm để cập nhật danh sách pet sau khi mua/nở trứng",
        Callback = function()
            local settings = Config.GetSettings()
            if settings.SelectedSpecies == "" then
                Fluent:Notify({
                    Title = "Error",
                    Content = "Vui lòng nhập tên pet trước!",
                    Duration = 3
                })
            else
                Core.ScanAndBuildTargetList()
            end
        end
    })

    Tabs.Farm:AddInput("TargetAgeInput", {
        Title = "Tuổi Thu Hoạch",
        Description = "10-100",
        Default = "50",
        Numeric = true,
        Finished = true,
        Callback = function(Value)
            local age = tonumber(Value) or 50
            if age > 100 then age = 100 end
            Config.UpdateSetting("TargetAge", age)
        end
    })

    Tabs.Farm:AddInput("MaxSlotsInput", {
        Title = "Tổng Slot Vườn",
        Default = "6",
        Numeric = true,
        Finished = true,
        Callback = function(Value)
            local slots = tonumber(Value) or 6
            Config.UpdateSetting("MaxSlots", slots)
        end
    })

    Tabs.Farm:AddInput("FarmLimitInput", {
        Title = "Giới Hạn Farm",
        Default = "6",
        Numeric = true,
        Finished = true,
        Callback = function(Value)
            local limit = tonumber(Value) or 6
            Config.UpdateSetting("FarmLimit", limit)
        end
    })

    FarmToggle = Tabs.Farm:AddToggle("AutoFarmToggle", {
        Title = "Bật Auto Farm",
        Default = false,
        Callback = function(Value)
            Config.UpdateSetting("IsRunning", Value)
            local settings = Config.GetSettings()
            if Value and (settings.SelectedSpecies == "" or settings.SelectedSpecies == nil) then
                Fluent:Notify({
                    Title = "Warning",
                    Content = "Vui lòng chọn loài Pet trước!",
                    Duration = 5
                })
                FarmToggle:SetValue(false)
            end
        end
    })
end

-- Build Misc tab
function UI.BuildMiscTab(Fluent)
    Tabs.Misc:AddParagraph({
        Title = "Thông Tin Pet Target",
        Content = "Hiển thị chi tiết về các pet đã được scan và lưu vào danh sách farm."
    })

    MiscUI.PetListLabel = Tabs.Misc:AddParagraph({
        Title = "Danh Sách Pet Target",
        Content = "Chưa có pet nào trong danh sách.\nVui lòng nhập tên pet và quét!"
    })

    Tabs.Misc:AddButton({
        Title = "Làm Mới Thông Tin",
        Description = "Cập nhật lại trạng thái của các pet",
        Callback = function()
            UpdateMiscPetList()
            Fluent:Notify({
                Title = "Updated",
                Content = "Đã cập nhật thông tin pet!",
                Duration = 2
            })
        end
    })
end

-- Build Settings tab
function UI.BuildSettingsTab(Fluent)
    Tabs.Settings:AddInput("WebhookURL", {
        Title = "Webhook URL",
        Default = "",
        Callback = function(Value) 
            Config.UpdateSetting("WebhookURL", Value)
        end
    })

    Tabs.Settings:AddButton({
        Title = "Test Webhook",
        Callback = function()
            local settings = Config.GetSettings()
            Webhook.SendPetMaxLevel("TEST PET", 999, settings.WebhookURL)
            Fluent:Notify({Title = "Webhook", Content = "Đã gửi tin nhắn test!", Duration = 3})
        end
    })
end

-- Hàm notify helper
function UI.Notify(title, content, duration)
    if Window then
        Window:Notify({
            Title = title,
            Content = content,
            Duration = duration
        })
    end
end

-- Export update function
UI.UpdateMiscPetList = UpdateMiscPetList

return UI
