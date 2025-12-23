--[[
    MODULE: CORE
    DESCRIPTION: Logic farm chính (Đã sửa logic: Đạt = Max Level HOẶC Mutation)
    UPDATE: Đã thêm hàm GetDashboardInfo để hiển thị thông tin Real-time
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

-- Kiểm tra mutation (Trả về true nếu tên có chứa từ khóa)
function Core.IsMutation(petName)
    local mutationPrefixes = {
        "Mega", "Rainbow", "Ascended", "Nightmare", "Golden", "Radiant", "Shiny" -- Thêm các loại khác nếu cần
    }
    for _, prefix in ipairs(mutationPrefixes) do
        if string.find(petName, prefix) then
            return true, prefix
        end
    end
    return false, "Normal"
end

-- Scan và build danh sách pet
function Core.ScanAndBuildTargetList(NotifyCallback)
    local settings = GetConfig().GetSettings()
    local targetName = settings.SelectedSpecies
    
    if targetName == "" or targetName == nil then 
        print("[SCAN] Chưa chọn loài pet!")
        if NotifyCallback then
            NotifyCallback("Error", "Chưa chọn loài pet!", 3)
        end
        return 
    end
    
    local uuidList = {}
    local searchName = string.lower(targetName)
    -- Lưu ý: Ở bước Scan, ta KHÔNG loại trừ mutation nếu muốn farm nó để unequip.
    local excludeMutation = settings.ExcludeMutation 
    
    -- Helper function để thêm vào list
    local function AddToList(tool, location)
        local baseName = string.match(tool.Name, "^(.+) %[Age") or tool.Name
        local baseNameLower = string.lower(baseName)
        
        -- Chỉ lấy đúng loài (ví dụ "Goose")
        if string.find(baseNameLower, searchName, 1, true) then
            
            local isMutated, _ = Core.IsMutation(baseName)
            
            -- Nếu đang ở trong Balo và là Mutation -> Không thêm vào danh sách farm (để không equip ra)
            if location == "Backpack" and excludeMutation and isMutated then
                print("[SCAN] Bỏ qua pet đã Mutation trong Balo:", tool.Name)
                return
            end

            -- Nếu đang ở Active (Vườn) hoặc chưa Mutation -> Thêm vào list để xử lý
            table.insert(uuidList, tool.Name)
            settings.PetStorage[tool.Name] = {
                baseName = baseName,
                uuid = tool.Name,
                lastSeen = os.time()
            }
            print("[SCAN] Thêm vào danh sách ("..location.."):", tool.Name)
        end
    end

    -- 1. Quét Backpack
    local Backpack = LocalPlayer:FindFirstChild("Backpack")
    if Backpack then
        for _, tool in pairs(Backpack:GetChildren()) do
            if tool:IsA("Tool") then
                AddToList(tool, "Backpack")
            end
        end
    end
    
    -- 2. Quét Character (Pet đang cầm tay nhưng chưa plant)
    local Character = LocalPlayer.Character
    if Character then
        for _, tool in pairs(Character:GetChildren()) do
            if tool:IsA("Tool") then
                AddToList(tool, "Character")
            end
        end
    end
    
    -- 3. Quét Pet đang Plant trong vườn (ActivePetUI)
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if PlayerGui then
        local ActiveUI = PlayerGui:FindFirstChild("ActivePetUI")
        if ActiveUI then
            local List = ActiveUI:FindFirstChild("Frame") and ActiveUI.Frame:FindFirstChild("Main") 
                and ActiveUI.Frame.Main:FindFirstChild("PetDisplay") 
                and ActiveUI.Frame.Main.PetDisplay:FindFirstChild("ScrollingFrame")
            if List then
                for _, frame in pairs(List:GetChildren()) do
                    if frame:IsA("Frame") and frame:FindFirstChild("Main") then
                        local uuid = frame.Name
                        local petName = ""
                        
                        -- Lấy tên hiển thị
                        local mainFrame = frame:FindFirstChild("Main")
                        for _, lbl in pairs(mainFrame:GetDescendants()) do
                            if lbl:IsA("TextLabel") and lbl.Visible and lbl.Text ~= "" and petName == "" then
                                if not string.find(lbl.Text, "Age") and not string.find(lbl.Text, ":") then
                                    petName = lbl.Text
                                    break
                                end
                            end
                        end
                        
                        -- Kiểm tra xem tên pet có chứa từ khóa tìm kiếm không
                        if string.find(string.lower(petName), searchName, 1, true) then
                            table.insert(uuidList, uuid)
                            settings.PetStorage[uuid] = {
                                baseName = petName,
                                uuid = uuid,
                                lastSeen = os.time()
                            }
                            print("[SCAN] Phát hiện pet trong vườn:", petName)
                        end
                    end
                end
            end
        end
    end
    
    settings.TargetUUIDs = uuidList
    if NotifyCallback then
        NotifyCallback("Scan Complete", "Tìm thấy " .. #uuidList .. " pet cần xử lý!", 5)
    end
    
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
            if tool:IsA("Tool") then table.insert(sources, {tool = tool, location = "Backpack"}) end
        end
    end
    if Character then
        for _, tool in pairs(Character:GetChildren()) do
            if tool:IsA("Tool") then table.insert(sources, {tool = tool, location = "Character"}) end
        end
    end
    
    for _, source in ipairs(sources) do
        local tool = source.tool
        local baseName = string.match(tool.Name, "^(.+) %[Age") or tool.Name
        local baseNameLower = string.lower(baseName)
        
        if string.find(baseNameLower, searchName, 1, true) then
            if excludeMutation and Core.IsMutation(baseName) then
                 -- Log nhẹ, không làm gì cả
            else
                local isTarget = false
                for _, uuid in ipairs(targetUUIDs) do
                    if tool.Name == uuid then isTarget = true; break end
                end
                
                if not isTarget then
                    table.insert(targetUUIDs, tool.Name)
                    petStorage[tool.Name] = {
                        baseName = baseName,
                        uuid = tool.Name,
                        location = source.location,
                        lastSeen = os.time()
                    }
                    if NotifyCallback then
                        NotifyCallback("New Pet", "Thêm " .. baseName, 2)
                    end
                end
            end
        end
    end
end

-- Quản lý vườn (harvest pets) - PHẦN QUAN TRỌNG NHẤT
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
    
    -- Đếm tổng slot đang dùng
    for _, frame in pairs(List:GetChildren()) do
         if frame:IsA("Frame") and frame:FindFirstChild("Main") then
             totalOccupied = totalOccupied + 1
         end
    end

    if #targetUUIDs == 0 then return totalOccupied, 0 end

    for _, frame in pairs(List:GetChildren()) do
        if frame:IsA("Frame") then
            local mainFrame = frame:FindFirstChild("Main")
            if not mainFrame then continue end
            
            local uuid = frame.Name
            local age = 0
            local petName = ""
            local isTarget = false
            
            -- Lấy Age
            local ageLabel = mainFrame:FindFirstChild("PET_AGE_SHADOW")
            if ageLabel and ageLabel:IsA("TextLabel") then
                local a = string.match(ageLabel.Text, "(%d+)")
                if a then age = tonumber(a) end
            end
            
            -- Lấy Tên Pet (để check Mutation)
            for _, lbl in pairs(mainFrame:GetDescendants()) do
                if lbl:IsA("TextLabel") and lbl.Visible and lbl.Text ~= "" and petName == "" then
                    if not string.find(lbl.Text, "Age") and not string.find(lbl.Text, ":") then
                        petName = lbl.Text
                    end
                end
            end
            
            -- Check xem có phải pet mình đang quản lý không
            for _, targetID in ipairs(targetUUIDs) do
                if uuid == targetID then
                    isTarget = true
                    break
                end
            end

            if isTarget then
                currentTargetCount = currentTargetCount + 1
                
                -- LOGIC KIỂM TRA ĐIỀU KIỆN "ĐẠT"
                -- Điều kiện 1: Đủ tuổi (Age >= Target)
                local isMaxAge = age >= settings.TargetAge
                -- Điều kiện 2: Là Mutation (Golden, Mega...)
                local isMutated, mutType = Core.IsMutation(petName)
                
                if isMaxAge or isMutated then
                    local reason = isMutated and ("Mutation: " .. mutType) or ("Max Age: " .. age)
                    print("[FARM] Thu hoạch:", petName, "| Lý do:", reason)
                    
                    if NotifyCallback then
                        NotifyCallback("Harvesting", petName .. " (" .. reason .. ")", 3)
                    end
                    
                    PetsService:FireServer("UnequipPet", uuid)
                    
                    -- Gửi Webhook nếu cần
                    if isMutated then
                        GetWebhook().SendMutationAchieved(petName, mutType, settings.WebhookURL)
                    else
                        GetWebhook().SendPetMaxLevel(petName, age, settings.WebhookURL)
                    end
                    
                    -- Xóa khỏi danh sách target
                    for i, id in ipairs(targetUUIDs) do
                        if id == uuid then
                            table.remove(targetUUIDs, i)
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
    local maxSlots = settings.MaxSlots
    local farmLimit = settings.FarmLimit
    local targetUUIDs = settings.TargetUUIDs
    
    if totalOccupied >= maxSlots then return end
    if currentTargetCount >= farmLimit then return end

    local Backpack = LocalPlayer:FindFirstChild("Backpack")
    local Char = LocalPlayer.Character
    if not Backpack or not Char then return end
    
    local Humanoid = Char:FindFirstChild("Humanoid")
    if #targetUUIDs == 0 then return end

    local planted = 0

    for _, tool in pairs(Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local isTarget = false
            for _, targetID in ipairs(targetUUIDs) do
                if tool.Name == targetID then isTarget = true; break end
            end
            
            if isTarget then
                if currentTargetCount + planted >= farmLimit then break end
                if totalOccupied + planted >= maxSlots then break end
                
                -- Equip và Plant
                print("[FARM] Trồng:", tool.Name)
                Humanoid:EquipTool(tool)
                task.wait(0.5)
                tool:Activate()
                task.wait(1.5) -- Đợi server phản hồi và UI cập nhật
                
                -- KIỂM TRA NGAY SAU KHI TRỒNG
                local plantedUUID = tool.Name
                local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
                if PlayerGui then
                    local ActiveUI = PlayerGui:FindFirstChild("ActivePetUI")
                    if ActiveUI then
                        local List = ActiveUI:FindFirstChild("Frame") and ActiveUI.Frame:FindFirstChild("Main") 
                            and ActiveUI.Frame.Main.PetDisplay.ScrollingFrame
                        if List then
                            local frame = List:FindFirstChild(plantedUUID)
                            if frame then
                                local plantedAge = 0
                                local plantedName = ""
                                
                                -- Lấy Age
                                local ageLabel = frame:FindFirstChild("PET_AGE_SHADOW", true)
                                if ageLabel then 
                                    local a = string.match(ageLabel.Text, "(%d+)")
                                    if a then plantedAge = tonumber(a) end
                                end
                                
                                -- Lấy Tên
                                local mainFrame = frame:FindFirstChild("Main")
                                for _, lbl in pairs(mainFrame:GetDescendants()) do
                                    if lbl:IsA("TextLabel") and lbl.Visible and lbl.Text ~= "" and plantedName == "" then
                                        if not string.find(lbl.Text, "Age") and lbl.Text ~= "Shadow" then
                                            plantedName = lbl.Text
                                        end
                                    end
                                end
                                
                                -- LOGIC CHECK "ĐẠT"
                                local isMaxAge = plantedAge >= settings.TargetAge
                                local isMutated, mutType = Core.IsMutation(plantedName)

                                if isMaxAge or isMutated then
                                    local reason = isMutated and ("Mutation: " .. mutType) or ("Age " .. plantedAge)
                                    print("[FARM] Pet vừa trồng đã ĐẠT:", plantedName, "-> Unequip ngay. Lý do:", reason)
                                    
                                    PetsService:FireServer("UnequipPet", plantedUUID)
                                    
                                    -- Xóa khỏi list
                                    for i, id in ipairs(targetUUIDs) do
                                        if id == plantedUUID then
                                            table.remove(targetUUIDs, i)
                                            break
                                        end
                                    end
                                    task.wait(0.5)
                                else
                                    planted = planted + 1
                                end
                            else
                                -- Nếu không tìm thấy frame (có thể lag hoặc chưa load kịp), tạm tính là đã trồng
                                planted = planted + 1
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ===============================================
-- HÀM MỚI: Lấy thông tin Dashboard (Real-time)
-- ===============================================
function Core.GetDashboardInfo()
    local settings = GetConfig().GetSettings()
    local targetUUIDs = settings.TargetUUIDs or {}
    
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not PlayerGui then return "Đang tải GUI..." end
    
    local ActiveUI = PlayerGui:FindFirstChild("ActivePetUI")
    if not ActiveUI then return "Chưa mở vườn" end
    
    local List = ActiveUI:FindFirstChild("Frame") and ActiveUI.Frame:FindFirstChild("Main") 
        and ActiveUI.Frame.Main:FindFirstChild("PetDisplay") 
        and ActiveUI.Frame.Main.PetDisplay:FindFirstChild("ScrollingFrame")
        
    if not List then return "Không đọc được dữ liệu vườn" end

    local infoText = ""
    local petCount = 0
    local farmCount = 0
    
    -- Duyệt qua các pet trong vườn để lấy thông tin
    for _, frame in pairs(List:GetChildren()) do
        if frame:IsA("Frame") and frame:FindFirstChild("Main") then
            petCount = petCount + 1
            local uuid = frame.Name
            local mainFrame = frame:FindFirstChild("Main")
            
            -- Lấy tên
            local petName = "Unknown"
            for _, lbl in pairs(mainFrame:GetDescendants()) do
                if lbl:IsA("TextLabel") and lbl.Visible and lbl.Text ~= "" then
                    if not string.find(lbl.Text, "Age") and not string.find(lbl.Text, ":") and lbl.Text ~= "Shadow" then
                        petName = lbl.Text
                        break
                    end
                end
            end
            
            -- Lấy Age
            local age = 0
            local ageLabel = mainFrame:FindFirstChild("PET_AGE_SHADOW")
            if ageLabel then 
                local a = string.match(ageLabel.Text, "(%d+)")
                if a then age = tonumber(a) end
            end
            
            -- Kiểm tra xem có đang farm con này không
            local isFarming = false
            for _, id in ipairs(targetUUIDs) do
                if id == uuid then isFarming = true; break end
            end
            
            -- Xác định trạng thái
            local status = ""
            if isFarming then
                farmCount = farmCount + 1
                status = "[FARM]"
            else
                status = "[GIỮ]"
            end
            
            -- Format dòng thông tin
            infoText = infoText .. string.format("%s Lv.%-3d %s\n", status, age, petName)
        end
    end
    
    local header = string.format("--- 📊 TRẠNG THÁI VƯỜN ---\nSlot: %d/%d | Đang Farm: %d\nMục tiêu: Age %d (hoặc Mutation)\n--------------------------\n", 
        petCount, settings.MaxSlots, farmCount, settings.TargetAge)
        
    return header .. infoText
end

return Core