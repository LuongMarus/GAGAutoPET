--[[ 
    FULL AUTO FARM CORE
    Remote: ReplicatedStorage.GameEvents.PetsService
    UI Path: PlayerGui.ActivePetUI.Frame.Main.PetDisplay.ScrollingFrame
]]

local Core = {}

--------------------------------------------------
-- SERVICES
--------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PetsService = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetsService")

--------------------------------------------------
-- DEPENDENCY
--------------------------------------------------
local function GetConfig()
    return getgenv().__AutoFarmDeps and getgenv().__AutoFarmDeps.Config
end

local function GetWebhook()
    return getgenv().__AutoFarmDeps and getgenv().__AutoFarmDeps.Webhook
end

--------------------------------------------------
-- MUTATION DETECTION
--------------------------------------------------
function Core.IsMutation(petName)
    if not petName or petName == "" then
        return false, "Normal"
    end

    local list = {
        "Mega",
        "Rainbow",
        "Ascended",
        "Nightmare",
        "Golden",
        "Radiant",
        "Shiny"
    }

    for _, prefix in ipairs(list) do
        if string.find(petName, prefix) then
            return true, prefix
        end
    end

    return false, "Normal"
end

--------------------------------------------------
-- SAFE UI GETTER
--------------------------------------------------
local function GetGardenList()
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not PlayerGui then return nil end

    local ActiveUI = PlayerGui:FindFirstChild("ActivePetUI")
    if not ActiveUI then return nil end

    return ActiveUI:FindFirstChild("Frame")
        and ActiveUI.Frame:FindFirstChild("Main")
        and ActiveUI.Frame.Main:FindFirstChild("PetDisplay")
        and ActiveUI.Frame.Main.PetDisplay:FindFirstChild("ScrollingFrame")
end

--------------------------------------------------
-- READ PET DATA FROM UI FRAME
--------------------------------------------------
local function ReadPetInfo(frame)
    local petName = ""
    local age = 0

    if not frame:FindFirstChild("Main") then
        return petName, age
    end

    local main = frame.Main

    -- AGE
    local ageLabel = main:FindFirstChild("PET_AGE_SHADOW", true)
    if ageLabel and ageLabel:IsA("TextLabel") then
        age = tonumber(string.match(ageLabel.Text, "(%d+)")) or 0
    end

    -- NAME (scan visible labels)
    for _, lbl in ipairs(main:GetDescendants()) do
        if lbl:IsA("TextLabel") and lbl.Visible and lbl.Text ~= "" then
            if not string.find(lbl.Text, "Age")
                and not string.find(lbl.Text, ":")
                and lbl.Text ~= "Shadow" then
                petName = lbl.Text
                break
            end
        end
    end

    return petName, age
end

--------------------------------------------------
-- DASHBOARD
--------------------------------------------------
function Core.GetDashboardInfo()
    local list = GetGardenList()
    if not list then
        return "Mở vườn để xem trạng thái"
    end

    local info = "--- TRẠNG THÁI VƯỜN ---\n"

    for _, frame in ipairs(list:GetChildren()) do
        if frame:IsA("Frame") then
            local petName, age = ReadPetInfo(frame)
            if petName ~= "" then
                info ..= string.format("%s | Age: %d\n", petName, age)
            end
        end
    end

    return info ~= "" and info or "Vườn trống"
end

--------------------------------------------------
-- SCAN AND UPDATE STORAGE
--------------------------------------------------
function Core.ScanAndUpdateStorage(NotifyCallback)
    local deps = GetConfig()
    if not deps then return end

    local settings = deps.GetSettings()
    local targetName = settings.SelectedSpecies
    if targetName == "" or targetName == nil then return end
    
    local searchName = string.lower(targetName)
    local excludeMutation = settings.ExcludeMutation
    local targetUUIDs = settings.TargetUUIDs
    local petStorage = settings.PetStorage
    
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
            
            -- Nếu chưa có trong list, TỰ ĐỘNG THÊM VÀO
            if not isTarget then
                if excludeMutation and Core.IsMutation(baseName) then
                    if NotifyCallback then
                        NotifyCallback("Bỏ qua mutation", baseName, 3)
                    end
                else
                    -- Thêm pet mới vào danh sách
                    table.insert(targetUUIDs, tool.Name)
                    petStorage[tool.Name] = {
                        baseName = baseName,
                        uuid = tool.Name,
                        location = source.location,
                        lastSeen = os.time()
                    }
                    if NotifyCallback then
                        NotifyCallback("New Pet Detected", "Đã thêm " .. baseName .. " vào danh sách farm!", 3)
                    end
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
                
                -- Kiểm tra mutation bị loại trừ
                if excludeMutation then
                    local isExcluded, mutType = Core.IsMutation(baseName)
                    if isExcluded then
                        -- Xóa UUID khỏi danh sách farm
                        for i, uuid in ipairs(targetUUIDs) do
                            if uuid == tool.Name then
                                table.remove(targetUUIDs, i)
                                break
                            end
                        end
                        
                        -- Gửi webhook
                        local webhook = GetWebhook()
                        if webhook then
                            webhook.SendMutationAchieved(baseName, mutType, settings.WebhookURL)
                        end
                        
                        -- Xóa khỏi storage
                        petStorage[tool.Name] = nil
                        
                        if NotifyCallback then
                            NotifyCallback("Mutation Achieved", baseName .. " (" .. mutType .. ") đã loại khỏi farm!", 5)
                        end
                    end
                end
            end
        end
    end
end

--------------------------------------------------
-- MANAGE GARDEN (AUTO HARVEST)
--------------------------------------------------
function Core.ManageGarden(NotifyCallback)
    local deps = GetConfig()
    if not deps then return end

    local settings = deps.GetSettings()
    local list = GetGardenList()
    if not list then return end

    for _, frame in ipairs(list:GetChildren()) do
        if frame:IsA("Frame") then
            local uuid = frame.Name
            local petName, age = ReadPetInfo(frame)
            if petName ~= "" then
                local isMutated, mutType = Core.IsMutation(petName)

                if age >= settings.TargetAge or (isMutated and settings.ExcludeMutation) then
                    PetsService:FireServer("UnequipPet", uuid)

                    if NotifyCallback then
                        NotifyCallback(
                            "Thu hoạch",
                            string.format("%s (%s)", petName, isMutated and mutType or ("Age " .. age)),
                            3
                        )
                    end

                    local webhook = GetWebhook()
                    if webhook then
                        if isMutated then
                            webhook.SendMutationAchieved(petName, mutType, settings.WebhookURL)
                        else
                            webhook.SendPetMaxLevel(petName, age, settings.WebhookURL)
                        end
                    end

                    task.wait(0.25)
                end
            end
        end
    end
end

--------------------------------------------------
-- PLANT PET (FROM BACKPACK)
--------------------------------------------------
function Core.PlantPet(tool)
    if not LocalPlayer.Character then return end
    local Humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    if not Humanoid then return end

    Humanoid:EquipTool(tool)
    task.wait(0.3)
    tool:Activate()
end

--------------------------------------------------
-- PLANT PETS (FROM BACKPACK)
--------------------------------------------------
function Core.PlantPets(totalOccupied, currentTargetCount)
    local deps = GetConfig()
    if not deps then return end

    local settings = deps.GetSettings()
    if totalOccupied >= settings.MaxSlots then return end
    if currentTargetCount >= settings.FarmLimit then return end

    local Backpack = LocalPlayer:FindFirstChild("Backpack")
    local Char = LocalPlayer.Character
    if not Backpack or not Char then return end
    local Humanoid = Char:FindFirstChild("Humanoid")
    local targetUUIDs = settings.TargetUUIDs
    
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
                
                if age < settings.TargetAge then
                    Humanoid:EquipTool(tool)
                    task.wait(0.3)
                    tool:Activate()
                    task.wait(1)
                    
                    totalOccupied = totalOccupied + 1
                    currentTargetCount = currentTargetCount + 1
                    
                    if totalOccupied >= settings.MaxSlots then break end
                    if currentTargetCount >= settings.FarmLimit then break end
                end
            end
        end
    end
end

--------------------------------------------------
-- AUTO FARM LOOP (CALL FROM MAIN SCRIPT)
--------------------------------------------------
function Core.AutoFarmTick(NotifyCallback)
    Core.ManageGarden(NotifyCallback)
end

return Core
