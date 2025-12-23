--[[
    MODULE: CORE
    DESCRIPTION: Logic farm chính
]]

local Core = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PetsService = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetsService")

-- Lazy load dependencies
local function GetConfig()
    return getgenv().__AutoFarmDeps.Config
end

local function GetWebhook()
    return getgenv().__AutoFarmDeps.Webhook
end

-- Kiểm tra mutation
function Core.IsMutation(petName)
    local mutationPrefixes = {
        "Mega", "Rainbow", "Ascended", "Nightmare",
    }
    for _, prefix in ipairs(mutationPrefixes) do
        if string.find(petName, prefix) then
            return true, prefix
        end
    end
    return false, "Normal"
end

-- Kiểm tra mutation bị loại trừ
function Core.IsExcludedMutation(petName)
    local excludedPrefixes = {"Mega", "Rainbow", "Ascended", "Nightmare"}
    for _, prefix in ipairs(excludedPrefixes) do
        if string.find(petName, prefix) then
            return true, prefix
        end
    end
    return false, nil
end

-- Scan và build danh sách pet
function Core.ScanAndBuildTargetList()
    local settings = GetConfig().GetSettings()
    local targetName = settings.SelectedSpecies
    
    if targetName == "" or targetName == nil then 
        print("[SCAN] Chưa chọn loài pet!")
        return 
    end
    
    local uuidList = {}
    local searchName = string.lower(targetName)
    local excludeMutation = settings.ExcludeMutation
    
    -- Quét Backpack
    local Backpack = LocalPlayer:FindFirstChild("Backpack")
    if Backpack then
        for _, tool in pairs(Backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local baseName = string.match(tool.Name, "^(.+) %[Age") or tool.Name
                local baseNameLower = string.lower(baseName)
                
                if string.find(baseNameLower, searchName, 1, true) then
                    if excludeMutation and Core.IsMutation(baseName) then
                        print("[SCAN] Bỏ qua mutation:", tool.Name)
                    else
                        table.insert(uuidList, tool.Name)
                        settings.PetStorage[tool.Name] = {
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
                    if excludeMutation and Core.IsMutation(baseName) then
                        print("[SCAN] Bỏ qua mutation:", tool.Name)
                    else
                        table.insert(uuidList, tool.Name)
                        settings.PetStorage[tool.Name] = {
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
    
    -- Quét Pet đang Plant trong vườn
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if PlayerGui then
        local ActiveUI = PlayerGui:FindFirstChild("ActivePetUI")
        if ActiveUI then
            local List = ActiveUI:FindFirstChild("Frame") and ActiveUI.Frame:FindFirstChild("Main") 
                and ActiveUI.Frame.Main:FindFirstChild("PetDisplay") 
                and ActiveUI.Frame.Main.PetDisplay:FindFirstChild("ScrollingFrame")
            if List then
                for _, frame in pairs(List:GetChildren()) do
                    if frame:IsA("Frame") and string.find(frame.Name, "{") then
                        local uuid = frame.Name
                        local petName = ""
                        
                        for _, lbl in pairs(frame:GetDescendants()) do
                            if lbl:IsA("TextLabel") and lbl.Visible then
                                if not string.find(lbl.Text, "Age") and lbl.Text ~= "" and petName == "" then
                                    petName = lbl.Text
                                    break
                                end
                            end
                        end
                        
                        local baseName = petName ~= "" and petName or (string.match(uuid, "^(.+) %[") or uuid)
                        local baseNameLower = string.lower(baseName)
                        
                        if string.find(baseNameLower, searchName, 1, true) then
                            local alreadyAdded = false
                            for _, existingUuid in ipairs(uuidList) do
                                if existingUuid == uuid then
                                    alreadyAdded = true
                                    break
                                end
                            end
                            
                            if not alreadyAdded then
                                if excludeMutation and Core.IsMutation(baseName) then
                                    print("[SCAN] Bỏ qua mutation trong vườn:", uuid)
                                else
                                    table.insert(uuidList, uuid)
                                    settings.PetStorage[uuid] = {
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
    
    settings.TargetUUIDs = uuidList
    print("[SCAN] Hoàn tất! Tìm thấy", #uuidList, "pet cần farm")
    print("[STORAGE] Đã lưu", #uuidList, "pet vào PetStorage")
    
    return #uuidList
end

-- Scan và cập nhật storage liên tục (tự động thêm pet mới)
function Core.ScanAndUpdateStorage(NotifyCallback)
    local settings = GetConfig().GetSettings()
    local targetName = settings.SelectedSpecies
    
    if targetName == "" or targetName == nil then return end
    
    local searchName = string.lower(targetName)
    local excludeMutation = settings.ExcludeMutation
    local targetUUIDs = settings.TargetUUIDs
    local petStorage = settings.PetStorage
    
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
    
    for _, source in ipairs(sources) do
        local tool = source.tool
        local baseName = string.match(tool.Name, "^(.+) %[Age") or tool.Name
        local baseNameLower = string.lower(baseName)
        
        if string.find(baseNameLower, searchName, 1, true) then
            local isTarget = false
            for _, uuid in ipairs(targetUUIDs) do
                if tool.Name == uuid then
                    isTarget = true
                    break
                end
            end
            
            if not isTarget then
                if excludeMutation and Core.IsMutation(baseName) then
                    print("[AUTO-SCAN] Bỏ qua mutation:", tool.Name)
                else
                    table.insert(targetUUIDs, tool.Name)
                    petStorage[tool.Name] = {
                        baseName = baseName,
                        uuid = tool.Name,
                        location = source.location,
                        lastSeen = os.time()
                    }
                    print("[AUTO-SCAN] Phát hiện pet mới:", tool.Name)
                    
                    if NotifyCallback then
                        NotifyCallback("New Pet Detected", "Đã thêm " .. baseName .. " vào danh sách farm!", 3)
                    end
                end
            else
                if not petStorage[tool.Name] then
                    petStorage[tool.Name] = {}
                end
                
                petStorage[tool.Name].baseName = baseName
                petStorage[tool.Name].uuid = tool.Name
                petStorage[tool.Name].location = source.location
                petStorage[tool.Name].lastSeen = os.time()
                
                if excludeMutation then
                    local isExcluded, mutType = Core.IsExcludedMutation(baseName)
                    if isExcluded then
                        print("[MUTATION DETECTED] Pet đã đạt mutation:", baseName, "Type:", mutType)
                        
                        for i, uuid in ipairs(targetUUIDs) do
                            if uuid == tool.Name then
                                table.remove(targetUUIDs, i)
                                print("[STORAGE] Đã xóa UUID khỏi farm list:", tool.Name)
                                break
                            end
                        end
                        
                        GetWebhook().SendMutationAchieved(baseName, mutType, settings.WebhookURL)
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

-- Quản lý vườn (harvest pets)
function Core.ManageGarden(NotifyCallback)
    local settings = GetConfig().GetSettings()
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not PlayerGui then return 0, 0 end
    
    local ActiveUI = PlayerGui:FindFirstChild("ActivePetUI")
    if not ActiveUI then return 0, 0 end
    
    local List = ActiveUI:FindFirstChild("Frame") and ActiveUI.Frame:FindFirstChild("Main") 
        and ActiveUI.Frame.Main:FindFirstChild("PetDisplay") 
        and ActiveUI.Frame.Main.PetDisplay:FindFirstChild("ScrollingFrame")
    if not List then return 0, 0 end

    local totalOccupied = 0    
    local currentTargetCount = 0
    local targetUUIDs = settings.TargetUUIDs
    
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
            
            for _, lbl in pairs(frame:GetDescendants()) do
                if lbl:IsA("TextLabel") and lbl.Visible then
                    local a = string.match(lbl.Text, "Age:%s*(%d+)")
                    if a then age = tonumber(a) end
                    
                    if not string.find(lbl.Text, "Age") and lbl.Text ~= "" and petName == "" then
                        petName = lbl.Text
                    end
                end
            end
            
            for _, targetID in ipairs(targetUUIDs) do
                if uuid == targetID then
                    isTarget = true
                    break
                end
            end

            if isTarget then
                currentTargetCount = currentTargetCount + 1
                
                if age >= settings.TargetAge then
                    print("[FARM] Thu hoạch:", petName, "Age:", age, "UUID:", uuid)
                    
                    if NotifyCallback then
                        NotifyCallback("Harvesting", "Unequipping " .. petName .. " (Age " .. age .. ")", 3)
                    end
                    
                    PetsService:FireServer("UnequipPet", uuid)
                    GetWebhook().SendPetMaxLevel(petName, age, settings.WebhookURL)
                    
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

-- Trồng pets
function Core.PlantPets(totalOccupied, currentTargetCount)
    local settings = GetConfig().GetSettings()
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
                    print("[FARM] Trồng:", tool.Name, "Age:", age)
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

return Core
