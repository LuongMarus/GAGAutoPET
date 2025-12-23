-- MODULE: CORE

local Core = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local PetsService = ReplicatedStorage
    :WaitForChild("GameEvents")
    :WaitForChild("PetsService")

local Config = getgenv().__AutoFarmDeps.Config
local Webhook = getgenv().__AutoFarmDeps.Webhook

local function Settings()
    return Config.GetSettings()
end

local function IsAlive()
    return not Settings().IsDestroyed
end

function Core.IsMutation(name)
    local list = {"Mega","Rainbow","Ascended","Nightmare","Golden","Radiant","Shiny"}
    for _, k in ipairs(list) do
        if string.find(name, k) then
            return true, k
        end
    end
    return false, "Normal"
end

function Core.ScanAndUpdateStorage()
    if not IsAlive() then return end

    local s = Settings()
    s.PetStorage = {}
    s.TargetUUIDs = {}
    s.ActiveSlots = 0

    -- Scan Garden
    local list = LocalPlayer.PlayerGui
        :WaitForChild("ActivePetUI")
        .Frame.Main.PetDisplay.ScrollingFrame

    for _, frame in ipairs(list:GetChildren()) do
        if frame:IsA("Frame") and frame:FindFirstChild("Main") then
            local age = tonumber(string.match(frame.Main.PET_AGE_SHADOW.Text or "", "(%d+)"))
            local mut, mutType = Core.IsMutation(frame.Name)

            s.PetStorage[frame.Name] = {
                UUID = frame.Name,
                Name = frame.Name,
                BaseName = string.lower(frame.Name),
                Location = "Garden",
                Age = age,
                Mutation = mutType,
                Status = "Waiting"
            }
        end
    end

    -- Scan Backpack
    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") and tool:FindFirstChild("UUID") then
            local uuid = tool.UUID.Value
            if not s.PetStorage[uuid] then
                local mut, mutType = Core.IsMutation(tool.Name)

                s.PetStorage[uuid] = {
                    UUID = uuid,
                    Name = tool.Name,
                    BaseName = string.lower(tool.Name),
                    Location = "Backpack",
                    Age = nil,
                    Mutation = mutType,
                    Status = "Waiting"
                }
            end
        end
    end

    -- Apply rules
    for uuid, pet in pairs(s.PetStorage) do
        pet.Status = "Waiting"

        if s.SelectedSpecies ~= "" and not string.find(pet.BaseName, s.SelectedSpecies) then
            pet.Status = "Excluded"
            continue
        end

        if s.ExcludeMutation and pet.Mutation ~= "Normal" then
            pet.Status = "Excluded"
            continue
        end

        if pet.Age and pet.Age >= s.TargetAge then
            pet.Status = "Excluded"
            continue
        end

        if #s.TargetUUIDs < s.FarmLimit then
            table.insert(s.TargetUUIDs, uuid)
            pet.Status = "Active"
        end
    end
end

function Core.ManageGarden()
    if not IsAlive() then return end

    local s = Settings()
    for uuid, pet in pairs(s.PetStorage) do
        if pet.Location == "Garden" then
            local shouldHarvest = false
            if pet.Age and pet.Age >= s.TargetAge then
                shouldHarvest = true
                Webhook.SendPetMaxLevel(pet.Name, pet.Age, s.WebhookURL)
            elseif pet.Mutation ~= "Normal" then
                shouldHarvest = true
                Webhook.SendMutationAchieved(pet.Name, pet.Mutation, s.WebhookURL)
            end
            
            if shouldHarvest then
                PetsService:FireServer("UnequipPet", uuid)
                pet.Status = "Excluded"
            end
        end
    end
end

function Core.PlantPets()
    if not IsAlive() then return end

    local s = Settings()
    local planted = 0

    for _, uuid in ipairs(s.TargetUUIDs) do
        if planted >= s.MaxSlots then break end

        local pet = s.PetStorage[uuid]
        if pet and pet.Location == "Backpack" then
            local tool = LocalPlayer.Backpack:FindFirstChild(pet.Name)
            if tool then
                tool.Parent = LocalPlayer.Character
                task.wait(0.1)
                tool:Activate()
                pet.Location = "Garden"
                planted += 1
            end
        end
    end

    s.ActiveSlots = planted
end

--------------------------------------------------
-- SCAN AND UPDATE STORAGE
--------------------------------------------------
function Core.ScanAndUpdateStorage(Notify)
    local s = Settings()
    if s.SelectedSpecies == "" then return end
    
    local searchName = string.lower(s.SelectedSpecies)
    local excludeMutation = s.ExcludeMutation
    local targetUUIDs = s.TargetUUIDs
    local petStorage = s.PetStorage
    
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
                -- Kiểm tra mutation trước khi thêm
                if excludeMutation and Core.IsMutation(baseName) then
                    if Notify then Notify("Skip Mutation", baseName, 3) end
                else
                    -- Thêm pet mới vào danh sách
                    table.insert(targetUUIDs, tool.Name)
                    petStorage[tool.Name] = {
                        baseName = baseName,
                        uuid = tool.Name,
                        location = source.location,
                        lastSeen = os.time()
                    }
                    if Notify then Notify("New Pet", baseName, 3) end
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
                    local isMut, mutType = Core.IsMutation(baseName)
                    if isMut then
                        -- Xóa UUID khỏi danh sách farm
                        for i, uuid in ipairs(targetUUIDs) do
                            if uuid == tool.Name then
                                table.remove(targetUUIDs, i)
                                break
                            end
                        end
                        
                        -- Gửi webhook
                        if Deps().Webhook then
                            Deps().Webhook.SendMutationAchieved(baseName, mutType, s.WebhookURL)
                        end
                        
                        -- Xóa khỏi storage
                        petStorage[tool.Name] = nil
                        
                        if Notify then Notify("Mutation", baseName .. " (" .. mutType .. ")", 5) end
                    end
                end
            end
        end
    end
end

return Core
