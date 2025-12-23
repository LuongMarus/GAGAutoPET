local Core = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PetsService = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetsService")

local function GetDeps() return getgenv().__AutoFarmDeps end

function Core.IsMutation(name)
    local list = {"Mega", "Rainbow", "Ascended", "Nightmare", "Shiny", "Golden"}
    for _, k in ipairs(list) do
        if string.find(name, k) then return true, k end
    end
    return false, "Normal"
end

function Core.ScanAndUpdateStorage(Notify)
    local s = GetDeps().Config.GetSettings()
    if s.SelectedSpecies == "" then return 0, 0 end

    local searchName = string.lower(s.SelectedSpecies)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local char = LocalPlayer.Character
    
    -- 1. Reset trạng thái tạm thời nhưng giữ PetStorage
    local currentTargetUUIDs = {}
    local occupiedSlots = 0
    local targetInGarden = 0

    -- 2. Quét Garden (ActivePetUI)
    local gui = LocalPlayer.PlayerGui:FindFirstChild("ActivePetUI")
    if gui and gui:FindFirstChild("Frame") then
        local list = gui.Frame.Main.PetDisplay.ScrollingFrame
        for _, frame in ipairs(list:GetChildren()) do
            if frame:IsA("Frame") and string.find(frame.Name, "{") then
                occupiedSlots = occupiedSlots + 1
                local uuid = frame.Name
                local petName = ""
                local age = 0
                
                for _, lbl in pairs(frame:GetDescendants()) do
                    if lbl:IsA("TextLabel") and lbl.Visible and lbl.Text then
                        local a = string.match(lbl.Text, "Age:%s*(%d+)")
                        if a then age = tonumber(a) 
                        elseif lbl.Text ~= "" and not string.find(lbl.Text, "Age") then
                            petName = lbl.Text
                        end
                    end
                end

                if petName ~= "" and string.find(string.lower(petName), searchName) then
                    targetInGarden = targetInGarden + 1
                    s.PetStorage[uuid] = {Name = petName, Age = age, Location = "Garden"}
                end
            end
        end
    end

    -- 3. Quét Backpack & Character
    local tools = {}
    if backpack then for _, t in pairs(backpack:GetChildren()) do table.insert(tools, t) end end
    if char then for _, t in pairs(char:GetChildren()) do if t:IsA("Tool") then table.insert(tools, t) end end end

    for _, tool in ipairs(tools) do
        local baseName = string.match(tool.Name, "^(.+) %[Age") or tool.Name
        if string.find(string.lower(baseName), searchName) then
            local isMut, mutType = Core.IsMutation(baseName)
            if not (s.ExcludeMutation and isMut) then
                local uuid = tool.Name
                s.PetStorage[uuid] = {Name = tool.Name, Age = 0, Location = "Backpack"}
                table.insert(currentTargetUUIDs, uuid)
            end
        end
    end

    s.TargetUUIDs = currentTargetUUIDs
    return occupiedSlots, targetInGarden
end

function Core.ManageGarden(Notify)
    local s = GetDeps().Config.GetSettings()
    local gui = LocalPlayer.PlayerGui:FindFirstChild("ActivePetUI")
    if not gui then return 0, 0 end

    local list = gui.Frame.Main.PetDisplay.ScrollingFrame
    local children = list:GetChildren()
    local occupied = 0
    local targetCount = 0
    for _, frame in ipairs(children) do
        if frame:IsA("Frame") and string.find(frame.Name, "{") then
            occupied += 1
            local uuid = frame.Name
            if table.find(s.TargetUUIDs, uuid) then
                targetCount += 1
            end
        end
    end

    for _, frame in ipairs(children) do
        if frame:IsA("Frame") and string.find(frame.Name, "{") then
            local uuid = frame.Name
            local age = 0
            local petName = ""
            
            for _, lbl in pairs(frame:GetDescendants()) do
                if lbl:IsA("TextLabel") and lbl.Visible and lbl.Text then
                    local a = string.match(lbl.Text, "Age:%s*(%d+)")
                    if a then age = tonumber(a) end
                    
                    if not string.find(lbl.Text, "Age") and lbl.Text ~= "" and petName == "" then
                        petName = lbl.Text
                        break
                    end
                end
            end

            -- Thu hoạch nếu đạt Age hoặc Mutation
            local isMut, mutType = Core.IsMutation(petName)
            if age >= s.TargetAge or (s.ExcludeMutation and isMut) then
                PetsService:FireServer("UnequipPet", uuid)
                if Notify then Notify("Harvest", petName, 2) end
                if age >= s.TargetAge then
                    GetDeps().Webhook.SendPetMaxLevel(petName, age, s.WebhookURL)
                    if s.PetStorage[uuid] then
                        s.PetStorage[uuid].Status = "Excluded"
                        s.PetStorage[uuid].Location = "Backpack"
                    end
                elseif isMut then
                    GetDeps().Webhook.SendMutationAchieved(petName, mutType, s.WebhookURL)
                    s.PetStorage[uuid] = nil
                end
                occupied -= 1
                if table.find(s.TargetUUIDs, uuid) then
                    targetCount -= 1
                end
                task.wait(0.3)
            end
        end
    end
    return occupied, targetCount
end

function Core.PlantPets(occupied, targetInGarden)
    local s = GetDeps().Config.GetSettings()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("Humanoid") then return end

    local canPlant = math.min(s.MaxSlots - occupied, s.FarmLimit - targetInGarden)
    if canPlant <= 0 then return end

    local count = 0
    for _, uuid in ipairs(s.TargetUUIDs) do
        if count >= canPlant then break end
        local tool = LocalPlayer.Backpack:FindFirstChild(uuid)
        if tool then
            char.Humanoid:EquipTool(tool)
            task.wait(0.2)
            tool:Activate()
            if s.PetStorage[uuid] then s.PetStorage[uuid].Location = "Garden" end
            count = count + 1
            task.wait(0.5)
        end
    end
end

return Core