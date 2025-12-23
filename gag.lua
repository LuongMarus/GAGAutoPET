--[[
    PROJECT: HUB SCRIPT AUTO FARM PET
    VERSION: Marus Ver 1.1 (Dropdown Update)
    AUTHOR: Marus
    UI LIB: Fluent
    GAME: Grow A Garden
]]

-- Load Fluent UI Library
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Marus Hub | Marus Ver 1.0",
    SubTitle = "Grow A Garden",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- Tạo nút Toggle cho Mobile
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

-- Bo tròn góc
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = ToggleButton

-- Thêm viền
local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(100, 100, 100)
UIStroke.Thickness = 2
UIStroke.Parent = ToggleButton

-- Cho phép kéo nút
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

-- Toggle UI khi click
ToggleButton.MouseButton1Click:Connect(function()
    Window:Minimize()
end)

ScreenGui.Parent = game:GetService("CoreGui")

-- Tabs
local Tabs = {
    Info = Window:AddTab({ Title = "Info", Icon = "info" }),
    Farm = Window:AddTab({ Title = "Auto Farm", Icon = "sprout" }),
    Misc = Window:AddTab({ Title = "Misc", Icon = "list" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- /// [1] KHỞI TẠO DỊCH VỤ ///
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local PetsService = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetsService")

-- Biến cấu hình toàn cục
getgenv().FarmSettings = {
    IsRunning = false,
    SelectedSpecies = "",
    TargetAge = 50,
    MaxSlots = 6,
    FarmLimit = 6,
    WebhookURL = "",
    ExcludeMutation = true,  -- MẶC ĐẬNH BẬT: Loại trừ pet có mutation đặc biệt
    TargetUUIDs = {},  -- Danh sách UUID của pet đang farm
    PetStorage = {}  -- Lưu TẤT CẢ pet đã scan (persistent storage)
}
-- Biến UI cho Misc tab
local MiscUI = {
    PetListLabel = nil
}
-- /// [2] HÀM CHỨC NĂNG HỆ THỐNG ///

-- Gửi Webhook Discord khi pet đạt age target
local function SendWebhookNotification(petName, petAge)
    local url = getgenv().FarmSettings.WebhookURL
    if url == "" or not string.find(url, "http") then return end

    local data = {
        ["content"] = "",
        ["embeds"] = {{
            ["title"] = "PET MAX LEVEL REACHED!",
            ["description"] = "Đã thu hoạch thành công thú cưng.",
            ["type"] = "rich",
            ["color"] = 65280, -- Màu xanh lá
            ["fields"] = {
                {["name"] = "Pet Name", ["value"] = petName, ["inline"] = true},
                {["name"] = "Age/Level", ["value"] = tostring(petAge), ["inline"] = true},
                {["name"] = "Player", ["value"] = LocalPlayer.Name, ["inline"] = true}
            },
            ["footer"] = { ["text"] = "Script made by Marus Ver 1.1" },
            ["timestamp"] = DateTime.now():ToIsoDate()
        }}
    }
    
    pcall(function()
        request({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
end

-- Gửi Webhook Discord khi pet đạt mutation target
local function SendMutationAchievedNotification(petName, mutationType)
    local url = getgenv().FarmSettings.WebhookURL
    if url == "" or not string.find(url, "http") then return end

    local data = {
        ["content"] = "",
        ["embeds"] = {{
            ["title"] = "MUTATION TARGET ACHIEVED!",
            ["description"] = "Pet đã đạt mutation mục tiêu và được loại khỏi farm.",
            ["type"] = "rich",
            ["color"] = 16776960, -- Màu vàng
            ["fields"] = {
                {["name"] = "Pet Name", ["value"] = petName, ["inline"] = true},
                {["name"] = "Mutation Type", ["value"] = mutationType, ["inline"] = true},
                {["name"] = "Player", ["value"] = LocalPlayer.Name, ["inline"] = true}
            },
            ["footer"] = { ["text"] = "Script made by Marus Ver 1.1" },
            ["timestamp"] = DateTime.now():ToIsoDate()
        }}
    }
    
    pcall(function()
        request({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
end

-- Hàm kiểm tra xem pet có phải mutation không
local function IsMutation(petName)
    local mutationPrefixes = {
        "Mega", "Rainbow", "Ascended", "Nightmare", "Golden",
        "Dark", "Shadow", "Crystal", "Mystic", "Lunar", 
        "Solar", "Shiny", "Legendary", "Mythic", "Divine", "Celestial"
    }
    for _, prefix in ipairs(mutationPrefixes) do
        if string.find(petName, prefix) then
            return true, prefix
        end
    end
    return false, "Normal"
end

-- Hàm kiểm tra xem pet có mutation bị loại trừ không (Mega, Rainbow, Ascended, Nightmare)
local function IsExcludedMutation(petName)
    local excludedPrefixes = {"Mega", "Rainbow", "Ascended", "Nightmare"}
    for _, prefix in ipairs(excludedPrefixes) do
        if string.find(petName, prefix) then
            return true, prefix
        end
    end
    return false, nil
end

-- Hàm cập nhật hiển thị danh sách pet trong Misc tab
local function UpdateMiscPetList()
    if not MiscUI.PetListLabel then return end
    
    local targetUUIDs = getgenv().FarmSettings.TargetUUIDs
    local targetAge = getgenv().FarmSettings.TargetAge
    
    if #targetUUIDs == 0 then
        MiscUI.PetListLabel:SetTitle("Danh Sách Pet Target")
        MiscUI.PetListLabel:SetDesc("Chưa có pet nào trong danh sách.\nVui lòng nhập tên pet và quét!")
        return
    end
    
    local petInfoList = {}
    local Backpack = LocalPlayer:FindFirstChild("Backpack")
    local Character = LocalPlayer.Character
    
    -- Duyệt qua TẤT CẢ UUID đã lưu
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
        
        -- Tìm trong Backpack
        if Backpack then
            for _, tool in pairs(Backpack:GetChildren()) do
                if tool:IsA("Tool") and tool.Name == uuid then
                    found = true
                    petInfo.location = "Backpack"
                    
                    -- Parse tên pet
                    local baseName = string.match(tool.Name, "^(.+) %[") or tool.Name
                    petInfo.name = baseName
                    
                    -- Parse Age
                    local ageMatch = string.match(tool.Name, "Age (%d+)")
                    petInfo.age = ageMatch and tonumber(ageMatch) or 0
                    
                    -- Parse Weight (KG)
                    local weightMatch = string.match(tool.Name, "(%d+%.%d+) KG")
                    petInfo.weight = weightMatch or "N/A"
                    
                    -- Check mutation
                    local isMut, mutType = IsMutation(baseName)
                    petInfo.mutation = mutType
                    
                    -- Check status
                    petInfo.status = petInfo.age >= targetAge and "[OK] ĐẠT" or "[X] CHƯA ĐẠT"
                    break
                end
            end
        end
        
        -- Tìm trong Character nếu chưa tìm thấy
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
                    
                    local isMut, mutType = IsMutation(baseName)
                    petInfo.mutation = mutType
                    
                    petInfo.status = petInfo.age >= targetAge and "[OK] ĐẠT" or "[X] CHƯA ĐẠT"
                    break
                end
            end
        end
        
        -- Nếu không tìm thấy, parse từ UUID string
        if not found then
            local baseName = string.match(uuid, "^(.+) %[") or uuid
            petInfo.name = baseName
            
            local ageMatch = string.match(uuid, "Age (%d+)")
            petInfo.age = ageMatch and tonumber(ageMatch) or 0
            
            local weightMatch = string.match(uuid, "(%d+%.%d+) KG")
            petInfo.weight = weightMatch or "N/A"
            
            local isMut, mutType = IsMutation(baseName)
            petInfo.mutation = mutType
            
            petInfo.status = petInfo.age >= targetAge and "[OK] ĐẠT" or "[~] ĐÃ PLANT"
            petInfo.location = "In Garden/UI"
        end
        
        table.insert(petInfoList, petInfo)
    end
    
    -- Tạo nội dung hiển thị
    local content = ""
    for i, info in ipairs(petInfoList) do
        content = content .. string.format(
            "[%d] %s\n   UUID: %s...\n   Age: %d | Weight: %s KG\n   Mutation: %s | Location: %s\n   %s\n\n",
            i, 
            info.name, 
            string.sub(info.uuid, 1, 30), -- Hiển thị 30 ký tự đầu của UUID
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

-- [GIAI ĐOẠN 1] QUÉT VÀ LẮU UUID CỦA PET CẦN FARM
local function ScanAndBuildTargetList()
    local targetName = getgenv().FarmSettings.SelectedSpecies
    if targetName == "" or targetName == nil then 
        print("[SCAN] Chưa chọn loài pet!")
        return 
    end
    
    local uuidList = {}
    local searchName = string.lower(targetName)
    local excludeMutation = getgenv().FarmSettings.ExcludeMutation
    
    -- Quét Backpack
    local Backpack = LocalPlayer:FindFirstChild("Backpack")
    if Backpack then
        for _, tool in pairs(Backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local baseName = string.match(tool.Name, "^(.+) %[Age") or tool.Name
                local baseNameLower = string.lower(baseName)
                
                -- Kiểm tra tên có chứa tên gốc
                if string.find(baseNameLower, searchName, 1, true) then
                    -- Kiểm tra mutation
                    if excludeMutation and IsMutation(baseName) then
                        print("[SCAN] Bỏ qua mutation:", tool.Name)
                    else
                        -- Lưu UUID và thông tin vào PetStorage
                        table.insert(uuidList, tool.Name)
                        getgenv().FarmSettings.PetStorage[tool.Name] = {
                            baseName = baseName,
                            uuid = tool.Name,
                            lastSeen = os.time()
                        }
                        print("[SCAN] Thêm vào danh sách:", tool.Name)
                    end
                end
            end
        end
    end
    
    -- Quét Character
    local Character = LocalPlayer.Character
    if Character then
        for _, tool in pairs(Character:GetChildren()) do
            if tool:IsA("Tool") then
                local baseName = string.match(tool.Name, "^(.+) %[Age") or tool.Name
                local baseNameLower = string.lower(baseName)
                
                if string.find(baseNameLower, searchName, 1, true) then
                    if excludeMutation and IsMutation(baseName) then
                        print("[SCAN] Bỏ qua mutation:", tool.Name)
                    else
                        table.insert(uuidList, tool.Name)
                        getgenv().FarmSettings.PetStorage[tool.Name] = {
                            baseName = baseName,
                            uuid = tool.Name,
                            lastSeen = os.time()
                        }
                        print("[SCAN] Thêm vào danh sách:", tool.Name)
                    end
                end
            end
        end
    end
    
    -- Quét Character
    local Character = LocalPlayer.Character
    if Character then
        for _, tool in pairs(Character:GetChildren()) do
            if tool:IsA("Tool") then
                local baseName = string.match(tool.Name, "^(.+) %[Age") or tool.Name
                local baseNameLower = string.lower(baseName)
                
                if string.find(baseNameLower, searchName, 1, true) then
                    if excludeMutation and IsMutation(baseName) then
                        print("[SCAN] Bỏ qua mutation:", tool.Name)
                    else
                        table.insert(uuidList, tool.Name)
                        getgenv().FarmSettings.PetStorage[tool.Name] = {
                            baseName = baseName,
                            uuid = tool.Name,
                            lastSeen = os.time()
                        }
                        print("[SCAN] Thêm vào danh sách:", tool.Name)
                    end
                end
            end
        end
    end
    
    -- Quét Pet đang Plant trong vườn (ActivePetUI)
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if PlayerGui then
        local ActiveUI = PlayerGui:FindFirstChild("ActivePetUI")
        if ActiveUI then
            local List = ActiveUI:FindFirstChild("Frame") and ActiveUI.Frame:FindFirstChild("Main") and ActiveUI.Frame.Main:FindFirstChild("PetDisplay") and ActiveUI.Frame.Main.PetDisplay:FindFirstChild("ScrollingFrame")
            if List then
                for _, frame in pairs(List:GetChildren()) do
                    if frame:IsA("Frame") and string.find(frame.Name, "{") then
                        local uuid = frame.Name
                        local petName = ""
                        
                        -- Đọc tên pet từ UI
                        for _, lbl in pairs(frame:GetDescendants()) do
                            if lbl:IsA("TextLabel") and lbl.Visible then
                                if not string.find(lbl.Text, "Age") and lbl.Text ~= "" and petName == "" then
                                    petName = lbl.Text
                                    break
                                end
                            end
                        end
                        
                        -- Parse baseName từ tên pet hoặc UUID
                        local baseName = petName ~= "" and petName or (string.match(uuid, "^(.+) %[") or uuid)
                        local baseNameLower = string.lower(baseName)
                        
                        if string.find(baseNameLower, searchName, 1, true) then
                            -- Kiểm tra xem UUID đã có trong list chưa (tránh trùng)
                            local alreadyAdded = false
                            for _, existingUuid in ipairs(uuidList) do
                                if existingUuid == uuid then
                                    alreadyAdded = true
                                    break
                                end
                            end
                            
                            if not alreadyAdded then
                                if excludeMutation and IsMutation(baseName) then
                                    print("[SCAN] Bỏ qua mutation trong vườn:", uuid)
                                else
                                    table.insert(uuidList, uuid)
                                    getgenv().FarmSettings.PetStorage[uuid] = {
                                        baseName = baseName,
                                        uuid = uuid,
                                        lastSeen = os.time()
                                    }
                                    print("[SCAN] Thêm pet từ vườn:", uuid)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    getgenv().FarmSettings.TargetUUIDs = uuidList
    print("[SCAN] Hoàn tất! Tìm thấy", #uuidList, "pet cần farm")
    print("[STORAGE] Đã lưu", #uuidList, "pet vào PetStorage")
    
    -- Cập nhật Misc tab
    UpdateMiscPetList()
    
    Fluent:Notify({
        Title = "Scan Complete",
        Content = "Tìm thấy " .. #uuidList .. " pet \"" .. targetName .. "\" để farm",
        Duration = 5
    })
end

-- [MỚI] HÀM SCAN VÀ CẬP NHẬT STORAGE LIÊN TỤC (TỰ ĐỘNG THÊM PET MỚI)
local function ScanAndUpdateStorage()
    local targetName = getgenv().FarmSettings.SelectedSpecies
    if targetName == "" or targetName == nil then return end
    
    local searchName = string.lower(targetName)
    local excludeMutation = getgenv().FarmSettings.ExcludeMutation
    local targetUUIDs = getgenv().FarmSettings.TargetUUIDs
    local petStorage = getgenv().FarmSettings.PetStorage
    
    -- Scan Backpack và Character
    local sources = {}
    local Backpack = LocalPlayer:FindFirstChild("Backpack")
    local Character = LocalPlayer.Character
    
    if Backpack then
        for _, tool in pairs(Backpack:GetChildren()) do
            if tool:IsA("Tool") then
                table.insert(sources, {tool = tool, location = "Backpack"})
            end
        end
    end
    
    if Character then
        for _, tool in pairs(Character:GetChildren()) do
            if tool:IsA("Tool") then
                table.insert(sources, {tool = tool, location = "Character"})
            end
        end
    end
    
    -- Cập nhật storage và TỰ ĐỘNG THÊM PET MỚI
    for _, source in ipairs(sources) do
        local tool = source.tool
        local baseName = string.match(tool.Name, "^(.+) %[Age") or tool.Name
        local baseNameLower = string.lower(baseName)
        
        -- Chỉ xử lý pet có tên khớp
        if string.find(baseNameLower, searchName, 1, true) then
            -- Kiểm tra xem UUID có trong TargetUUIDs không
            local isTarget = false
            for _, uuid in ipairs(targetUUIDs) do
                if tool.Name == uuid then
                    isTarget = true
                    break
                end
            end
            
            -- [MỚI] Nếu chưa có trong list, TỰ ĐỘNG THÊM VÀO
            if not isTarget then
                -- Kiểm tra mutation trước khi thêm
                if excludeMutation and IsMutation(baseName) then
                    print("[AUTO-SCAN] Bỏ qua mutation:", tool.Name)
                else
                    -- Thêm pet mới vào danh sách
                    table.insert(targetUUIDs, tool.Name)
                    petStorage[tool.Name] = {
                        baseName = baseName,
                        uuid = tool.Name,
                        location = source.location,
                        lastSeen = os.time()
                    }
                    print("[AUTO-SCAN] Phát hiện pet mới:", tool.Name)
                    
                    Fluent:Notify({
                        Title = "New Pet Detected",
                        Content = "Đã thêm " .. baseName .. " vào danh sách farm!",
                        Duration = 3
                    })
                end
            else
                -- Pet đã có trong list, chỉ cập nhật thông tin
                if not petStorage[tool.Name] then
                    petStorage[tool.Name] = {}
                end
                
                petStorage[tool.Name].baseName = baseName
                petStorage[tool.Name].uuid = tool.Name
                petStorage[tool.Name].location = source.location
                petStorage[tool.Name].lastSeen = os.time()
                
                -- Kiểm tra mutation bị loại trừ (Mega, Rainbow, Ascended, Nightmare)
                if excludeMutation then
                    local isExcluded, mutType = IsExcludedMutation(baseName)
                    if isExcluded then
                        print("[MUTATION DETECTED] Pet đã đạt mutation:", baseName, "Type:", mutType)
                        
                        -- Xóa UUID khỏi danh sách farm
                        for i, uuid in ipairs(targetUUIDs) do
                            if uuid == tool.Name then
                                table.remove(targetUUIDs, i)
                                print("[STORAGE] Đã xóa UUID khỏi farm list:", tool.Name)
                                break
                            end
                        end
                        
                        -- Gửi webhook thông báo
                        SendMutationAchievedNotification(baseName, mutType)
                        
                        -- Xóa khỏi storage
                        petStorage[tool.Name] = nil
                        
                        Fluent:Notify({
                            Title = "Mutation Achieved",
                            Content = baseName .. " (" .. mutType .. ") đã loại khỏi farm!",
                            Duration = 5
                        })
                    end
                end
            end
        end
    end
end

-- [MỚI] Hàm lấy danh sách loài từ Balo để đưa vào Dropdown
local function GetSpeciesList()
    local list = {}
    local found = {} -- Dùng để lọc trùng
    local Backpack = LocalPlayer:FindFirstChild("Backpack")
    
    if Backpack then
        for _, tool in pairs(Backpack:GetChildren()) do
            if tool:IsA("Tool") and string.find(tool.Name, "Age") then
                -- Tách tên: "Golden Phoenix [Age 1]" -> "Golden Phoenix"
                -- Pattern "^(.+) %[Age" nghĩa là lấy tất cả ký tự trước chữ " [Age"
                local name = string.match(tool.Name, "^(.+) %[Age")
                
                if name and not found[name] then
                    found[name] = true
                    table.insert(list, name)
                end
            end
        end
    end
    
    table.sort(list) -- Sắp xếp tên theo thứ tự ABC
    return list
end

-- Hàm đếm số lượng pet theo tên (hỗ trợ tìm nhiều)
local function CountPetsByName(petName)
    if petName == "" or petName == nil then return 0 end
    local count = 0
    local searchName = string.lower(petName)
    local excludeMutation = getgenv().FarmSettings.ExcludeMutation
    
    local Backpack = LocalPlayer:FindFirstChild("Backpack")
    if Backpack then
        for _, tool in pairs(Backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local baseName = string.match(tool.Name, "^(.+) %[Age") or tool.Name
                local baseNameLower = string.lower(baseName)
                
                -- Tìm pet có chứa tên gốc
                if string.find(baseNameLower, searchName, 1, true) then
                    -- Nếu bật loại trừ mutation, kiểm tra
                    if excludeMutation and IsMutation(baseName) then
                        -- Bỏ qua pet mutation
                    else
                        count = count + 1
                    end
                end
            end
        end
    end
    
    local Character = LocalPlayer.Character
    if Character then
        for _, tool in pairs(Character:GetChildren()) do
            if tool:IsA("Tool") then
                local baseName = string.match(tool.Name, "^(.+) %[Age") or tool.Name
                local baseNameLower = string.lower(baseName)
                
                if string.find(baseNameLower, searchName, 1, true) then
                    if excludeMutation and IsMutation(baseName) then
                        -- Bỏ qua
                    else
                        count = count + 1
                    end
                end
            end
        end
    end
    return count
end

-- /// [3] LOGIC AUTO FARM ///

-- [GIAI ĐOẠN 2] HÀM QUẢN LÝ VƯỜN (FARM THEO UUID)
local function ManageGarden()
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not PlayerGui then return 0, 0 end
    local ActiveUI = PlayerGui:FindFirstChild("ActivePetUI")
    if not ActiveUI then return 0, 0 end
    local List = ActiveUI:FindFirstChild("Frame") and ActiveUI.Frame:FindFirstChild("Main") and ActiveUI.Frame.Main:FindFirstChild("PetDisplay") and ActiveUI.Frame.Main.PetDisplay:FindFirstChild("ScrollingFrame")
    if not List then return 0, 0 end

    local totalOccupied = 0    
    local currentTargetCount = 0
    local targetUUIDs = getgenv().FarmSettings.TargetUUIDs
    
    -- Nếu danh sách UUID trống, chỉ đếm tổng
    if #targetUUIDs == 0 then
        for _, frame in pairs(List:GetChildren()) do
             if frame:IsA("Frame") and string.find(frame.Name, "{") then
                 totalOccupied = totalOccupied + 1
             end
        end
        return totalOccupied, 0
    end

    for _, frame in pairs(List:GetChildren()) do
        if frame:IsA("Frame") and string.find(frame.Name, "{") then
            totalOccupied = totalOccupied + 1
            
            local uuid = frame.Name
            local age = 0
            local petName = ""
            local isTarget = false
            
            -- Đọc thông tin pet
            for _, lbl in pairs(frame:GetDescendants()) do
                if lbl:IsA("TextLabel") and lbl.Visible then
                    local a = string.match(lbl.Text, "Age:%s*(%d+)")
                    if a then age = tonumber(a) end
                    
                    if not string.find(lbl.Text, "Age") and lbl.Text ~= "" and petName == "" then
                        petName = lbl.Text
                    end
                end
            end
            
            -- [THAY ĐỔI] KIỂM TRA UUID THAY VÌ TÊN
            -- Tìm xem UUID này có trong danh sách target không
            for _, targetID in ipairs(targetUUIDs) do
                -- So sánh UUID (frame.Name là UUID thật)
                if uuid == targetID then
                    isTarget = true
                    break
                end
            end

            if isTarget then
                currentTargetCount = currentTargetCount + 1
                
                if age >= getgenv().FarmSettings.TargetAge then
                    print("[FARM] Thu hoạch:", petName, "Age:", age, "UUID:", uuid)
                    
                    Fluent:Notify({
                        Title = "Harvesting",
                        Content = "Unequipping " .. petName .. " (Age " .. age .. ")",
                        Duration = 3
                    })
                    
                    PetsService:FireServer("UnequipPet", uuid)
                    SendWebhookNotification(petName, age)
                    
                    -- Xóa UUID khỏi danh sách (pet đã hoàn thành)
                    for i, id in ipairs(targetUUIDs) do
                        if id == uuid then
                            table.remove(targetUUIDs, i)
                            print("[FARM] Đã xóa UUID khỏi danh sách")
                            break
                        end
                    end
                    
                    totalOccupied = totalOccupied - 1
                    currentTargetCount = currentTargetCount - 1
                    task.wait(0.2)
                end
            end
        end
    end
    return totalOccupied, currentTargetCount
end

-- Hàm Trồng Pet (FARM THEO UUID)
local function PlantPets(totalOccupied, currentTargetCount)
    if totalOccupied >= getgenv().FarmSettings.MaxSlots then return end
    if currentTargetCount >= getgenv().FarmSettings.FarmLimit then return end

    local Backpack = LocalPlayer:FindFirstChild("Backpack")
    local Char = LocalPlayer.Character
    if not Backpack or not Char then return end
    local Humanoid = Char:FindFirstChild("Humanoid")
    local targetUUIDs = getgenv().FarmSettings.TargetUUIDs
    
    if #targetUUIDs == 0 then return end

    for _, tool in pairs(Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            -- Kiểm tra xem tool.Name có trong danh sách UUID không
            local isTarget = false
            for _, targetID in ipairs(targetUUIDs) do
                if tool.Name == targetID then
                    isTarget = true
                    break
                end
            end
            
            if isTarget then
                local ageMatch = string.match(tool.Name, "Age (%d+)")
                local age = ageMatch and tonumber(ageMatch) or 0
                
                if age < getgenv().FarmSettings.TargetAge then
                    print("[FARM] Trồng:", tool.Name, "Age:", age)
                    Humanoid:EquipTool(tool)
                    task.wait(0.3)
                    tool:Activate()
                    task.wait(1)
                    
                    totalOccupied = totalOccupied + 1
                    currentTargetCount = currentTargetCount + 1
                    
                    if totalOccupied >= getgenv().FarmSettings.MaxSlots then break end
                    if currentTargetCount >= getgenv().FarmSettings.FarmLimit then break end
                end
            end
        end
    end
end

-- Vòng lặp chính
task.spawn(function()
    while true do
        if getgenv().FarmSettings.IsRunning then
            pcall(function()
                local occupied, targetCount = ManageGarden()
                task.wait(0.5)
                PlantPets(occupied, targetCount)
            end)
        end
        task.wait(1.5)
    end
end)


-- /// [4] XÂY DỰNG GIAO DIỆN (UI TABS) ///

-- TAB 1: INFO
Tabs.Info:AddParagraph({
    Title = "Thông tin Script",
    Content = "Script Auto Farm Pet made By Marus Ver 1.1\nCập nhật: Dropdown chọn Pet thông minh."
})
Tabs.Info:AddButton({
    Title = "Copy Discord Link",
    Description = "Copy link Discord vào clipboard",
    Callback = function()
        setclipboard("https://discord.gg/YourLinkHere")
        Fluent:Notify({Title = "Success", Content = "Đã copy link Discord!", Duration = 5})
    end
})

-- TAB 2: AUTO FARM
Tabs.Farm:AddParagraph({
    Title = "Cấu Hình Farm",
    Content = "Nhập tên gốc pet (ví dụ: Phoenix) để farm tất cả loài có tên đó."
})

-- INPUT NHẬP TÊN PET
Tabs.Farm:AddInput("PetNameInput", {
    Title = "Tên Gốc Pet (Base Name)",
    Description = "Nhập tên gốc (ví dụ: Phoenix, Dragon, Bee)",
    Default = "",
    Placeholder = "Phoenix",
    Numeric = false,
    Finished = true,
    Callback = function(Value)
        getgenv().FarmSettings.SelectedSpecies = Value
        
        if Value ~= "" then
            -- Tự động scan và lưu tất cả pet vào PetStorage
            ScanAndBuildTargetList()
            
            Fluent:Notify({
                Title = "Auto Storage",
                Content = "Pet sẽ được tự động lưu và scan liên tục!",
                Duration = 5
            })
        end
    end
})

-- TOGGLE LOẠI TRỪ MUTATION
Tabs.Farm:AddToggle("ExcludeMutationToggle", {
    Title = "Loại Trừ Mutation",
    Description = "Bật để bỏ qua pet Mega, Rainbow, Ascended, Nightmare...",
    Default = true,
    Callback = function(Value)
        getgenv().FarmSettings.ExcludeMutation = Value
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
        -- Re-scan sau khi thay đổi cài đặt
        if getgenv().FarmSettings.SelectedSpecies ~= "" then
            ScanAndBuildTargetList()
        end
    end
})

-- NÚT QUÉT LẠI (RE-SCAN)
Tabs.Farm:AddButton({
    Title = "Quét Lại Danh Sách (Re-scan)",
    Description = "Bấm để cập nhật danh sách pet sau khi mua/nở trứng",
    Callback = function()
        if getgenv().FarmSettings.SelectedSpecies == "" then
            Fluent:Notify({
                Title = "Error",
                Content = "Vui lòng nhập tên pet trước!",
                Duration = 3
            })
        else
            ScanAndBuildTargetList()
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
        getgenv().FarmSettings.TargetAge = age
    end
})

Tabs.Farm:AddInput("MaxSlotsInput", {
    Title = "Tổng Slot Vườn",
    Default = "6",
    Numeric = true,
    Finished = true,
    Callback = function(Value)
        local slots = tonumber(Value) or 6
        getgenv().FarmSettings.MaxSlots = slots
    end
})

Tabs.Farm:AddInput("FarmLimitInput", {
    Title = "Giới Hạn Farm",
    Default = "6",
    Numeric = true,
    Finished = true,
    Callback = function(Value)
        local limit = tonumber(Value) or 6
        getgenv().FarmSettings.FarmLimit = limit
    end
})

local FarmToggle = Tabs.Farm:AddToggle("AutoFarmToggle", {
    Title = "Bật Auto Farm",
    Default = false,
    Callback = function(Value)
        getgenv().FarmSettings.IsRunning = Value
        if Value and (getgenv().FarmSettings.SelectedSpecies == "" or getgenv().FarmSettings.SelectedSpecies == nil) then
            Fluent:Notify({
                Title = "Warning",
                Content = "Vui lòng chọn loài Pet trước!",
                Duration = 5
            })
            FarmToggle:SetValue(false)
        end
    end
})

-- TAB 3: MISC
Tabs.Misc:AddParagraph({
    Title = "Thông Tin Pet Target",
    Content = "Hiển thị chi tiết về các pet đã được scan và lưu vào danh sách farm."
})

-- Label hiển thị danh sách pet
MiscUI.PetListLabel = Tabs.Misc:AddParagraph({
    Title = "Danh Sách Pet Target",
    Content = "Chưa có pet nào trong danh sách.\nVui lòng nhập tên pet và quét!"
})

-- Nút làm mới thông tin
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

-- TAB 4: SETTINGS
Tabs.Settings:AddInput("WebhookURL", {
    Title = "Webhook URL",
    Default = "",
    Callback = function(Value) getgenv().FarmSettings.WebhookURL = Value end
})

Tabs.Settings:AddButton({
    Title = "Test Webhook",
    Callback = function()
        SendWebhookNotification("TEST PET", 999)
        Fluent:Notify({Title = "Webhook", Content = "Đã gửi tin nhắn test!", Duration = 3})
    end
})

-- VÒNG LẶP FARM CHÍNH
task.spawn(function()
    while task.wait(1.5) do
        if getgenv().FarmSettings.IsRunning then
            -- Scan và cập nhật storage liên tục
            ScanAndUpdateStorage()
            
            -- Farm logic
            local occupied, targetCount = ManageGarden()
            PlantPets(occupied, targetCount)
            
            -- Cập nhật Misc tab
            UpdateMiscPetList()
        end
    end
end)

Fluent:Notify({
    Title = "Marus Auto Farm Ver 1.1",
    Content = "Script Loaded Successfully!",
    Duration = 5
})