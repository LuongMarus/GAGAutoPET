local Core = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PetsService = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetsService")

local function GetConfig()
    return getgenv().__AutoFarmDeps.Config
end

local function GetWebhook()
    return getgenv().__AutoFarmDeps.Webhook
end

-- [TÍNH NĂNG 1]: Nhận diện Mutation bao gồm Radiant
function Core.IsMutation(petName)
    local list = {"Mega", "Rainbow", "Ascended", "Nightmare", "Golden", "Radiant", "Shiny"}
    for _, prefix in ipairs(list) do
        if string.find(petName, prefix) then return true, prefix end
    end
    return false, "Normal"
end

function Core.IsDone(petName, age, targetAge)
    local isMutated, mutType = Core.IsMutation(petName)
    if isMutated then
        return true, "Mutation: " .. mutType
    end
    if age >= targetAge then
        return true, "Max Age: " .. age
    end
    return false, nil
end

function Core.ScanAndBuildTargetList(NotifyCallback)
    local settings = GetConfig().GetSettings()
    local targetName = settings.SelectedSpecies
    
    if targetName == "" or targetName == nil then 
        if NotifyCallback then NotifyCallback("Error", "No pet selected!", 3) end
        return 0
    end
    
    local searchName = string.lower(targetName)
    local targetAge = settings.TargetAge
    settings.TargetUUIDs = {}
    settings.PetStorage = {}
    
    if LocalPlayer:FindFirstChild("Backpack") then
        for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local baseName = string.match(tool.Name, "^(.+) %[Age") or tool.Name
                if string.find(string.lower(baseName), searchName, 1, true) then
                    local isMutated = Core.IsMutation(baseName)
                    local isDone, _ = Core.IsDone(baseName, 0, targetAge)
                    
                    if not (isMutated and settings.ExcludeMutation) and not isDone then
                        table.insert(settings.TargetUUIDs, tool.Name)
                    end
                    
                    settings.PetStorage[tool.Name] = {
                        baseName = baseName,
                        uuid = tool.Name,
                        location = "Backpack"
                    }
                end
            end
        end
    end
    
    return #settings.TargetUUIDs
end

function Core.ScanAndUpdateStorage(NotifyCallback)
    local settings = GetConfig().GetSettings()
    local targetName = settings.SelectedSpecies
    if targetName == "" or targetName == nil then return end
    
    local searchName = string.lower(targetName)
    local targetAge = settings.TargetAge
    
    if LocalPlayer:FindFirstChild("Backpack") then
        for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local baseName = string.match(tool.Name, "^(.+) %[Age") or tool.Name
                if string.find(string.lower(baseName), searchName, 1, true) then
                    if not settings.PetStorage[tool.Name] then
                        local isMutated = Core.IsMutation(baseName)
                        local isDone, _ = Core.IsDone(baseName, 0, targetAge)
                        
                        if not (isMutated and settings.ExcludeMutation) and not isDone then
                            local alreadyInList = false
                            for _, uuid in ipairs(settings.TargetUUIDs) do
                                if uuid == tool.Name then alreadyInList = true; break end
                            end
                            if not alreadyInList then
                                table.insert(settings.TargetUUIDs, tool.Name)
                            end
                        end
                        
                        settings.PetStorage[tool.Name] = {
                            baseName = baseName,
                            uuid = tool.Name,
                            location = "Backpack"
                        }
                    end
                end
            end
        end
    end
end

function Core.ManageGarden(NotifyCallback)
    local settings = GetConfig().GetSettings()
    local targetName = settings.SelectedSpecies
    if targetName == "" or targetName == nil then return 0, 0 end
    
    local searchName = string.lower(targetName)
    local targetAge = settings.TargetAge
    
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not PlayerGui then return 0, 0 end
    
    local ActiveUI = PlayerGui:FindFirstChild("ActivePetUI")
    if not ActiveUI then return 0, 0 end
    
    local List = ActiveUI:FindFirstChild("Frame") and ActiveUI.Frame:FindFirstChild("Main") 
        and ActiveUI.Frame.Main:FindFirstChild("PetDisplay") 
        and ActiveUI.Frame.Main.PetDisplay:FindFirstChild("ScrollingFrame")
    if not List then return 0, 0 end

    local totalOccupied = 0
    local targetInGarden = 0
    
    for _, frame in pairs(List:GetChildren()) do
        if frame:IsA("Frame") and frame:FindFirstChild("Main") then
            totalOccupied = totalOccupied + 1
            
            local mainFrame = frame.Main
            local uuid = frame.Name
            local petName = ""
            local age = 0
            
            local ageLabel = mainFrame:FindFirstChild("PET_AGE_SHADOW", true)
            if ageLabel and ageLabel:IsA("TextLabel") then
                local a = string.match(ageLabel.Text, "(%d+)")
                if a then age = tonumber(a) end
            end
            
            for _, lbl in pairs(mainFrame:GetDescendants()) do
                if lbl:IsA("TextLabel") and lbl.Visible and lbl.Text ~= "" and petName == "" then
                    if not string.find(lbl.Text, "Age") and not string.find(lbl.Text, ":") then
                        petName = lbl.Text
                    end
                end
            end
            
            print("[DEBUG] Found pet in garden: '" .. petName .. "' age: " .. age)
                targetInGarden = targetInGarden + 1
                
                local isMutated, mutType = Core.IsMutation(petName)
                local isDone = age >= targetAge or isMutated
                local reason = isMutated and ("Mutation: " .. mutType) or ("Max Age: " .. age)
                
                if isDone then
                    print("[FARM] Unequip:", petName, "| Age:", age, "| Reason:", reason)
                    
                    if NotifyCallback then 
                        NotifyCallback("Harvesting", petName .. " (" .. reason .. ")", 3) 
                    end
                    
                    PetsService:FireServer("UnequipPet", uuid)
                    
                    local isMutated, mutType = Core.IsMutation(petName)
                    if isMutated then
                        GetWebhook().SendMutationAchieved(petName, mutType, settings.WebhookURL)
                    else
                        GetWebhook().SendPetMaxLevel(petName, age, settings.WebhookURL)
                    end
                    
                    for i, id in ipairs(settings.TargetUUIDs) do
                        if id == uuid then 
                            table.remove(settings.TargetUUIDs, i)
                            break 
                        end
                    end
                    
                    totalOccupied = totalOccupied - 1
                    targetInGarden = targetInGarden - 1
                    task.wait(0.3)
                end
            end
        end
    end
    
    return totalOccupied, targetInGarden
end

function Core.PlantPets(totalOccupied, targetInGarden)
    local settings = GetConfig().GetSettings()
    local maxSlots = settings.MaxSlots
    local farmLimit = settings.FarmLimit
    local targetAge = settings.TargetAge
    local targetUUIDs = settings.TargetUUIDs
    
    if totalOccupied >= maxSlots then return end
    if targetInGarden >= farmLimit then return end
    if not LocalPlayer:FindFirstChild("Backpack") then return end
    if not LocalPlayer.Character then return end
    
    local Humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    if not Humanoid then return end
    
    local planted = 0
    local availableSlots = math.min(maxSlots - totalOccupied, farmLimit - targetInGarden)
    
    for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
        if planted >= availableSlots then break end
        
        if tool:IsA("Tool") then
            local isInList = false
            for _, uuid in ipairs(targetUUIDs) do
                if tool.Name == uuid then 
                    isInList = true
                    break 
                end
            end
            
            if isInList then
                print("[FARM] Planting:", tool.Name)
                Humanoid:EquipTool(tool)
                task.wait(0.5)
                tool:Activate()
                task.wait(1.5)
                
                local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
                if PlayerGui then
                    local ActiveUI = PlayerGui:FindFirstChild("ActivePetUI")
                    if ActiveUI then
                        local List = ActiveUI:FindFirstChild("Frame") and ActiveUI.Frame:FindFirstChild("Main") 
                            and ActiveUI.Frame.Main.PetDisplay.ScrollingFrame
                        if List then
                            local frame = List:FindFirstChild(tool.Name)
                            if frame then
                                local plantedAge = 0
                                local plantedName = ""
                                
                                local ageLabel = frame:FindFirstChild("PET_AGE_SHADOW", true)
                                if ageLabel and ageLabel:IsA("TextLabel") then 
                                    local a = string.match(ageLabel.Text, "(%d+)")
                                    if a then plantedAge = tonumber(a) end
                                end
                                
                                local mainFrame = frame:FindFirstChild("Main")
                                if mainFrame then
                                    for _, lbl in pairs(mainFrame:GetDescendants()) do
                                        if lbl:IsA("TextLabel") and lbl.Visible and lbl.Text ~= "" and plantedName == "" then
                                            if not string.find(lbl.Text, "Age") and lbl.Text ~= "Shadow" then
                                                plantedName = lbl.Text
                                            end
                                        end
                                    end
                                end
                                
                                local isDone, reason = Core.IsDone(plantedName, plantedAge, targetAge)
                                if isDone then
                                    print("[FARM] Just planted but DONE:", plantedName, "| Reason:", reason)
                                    PetsService:FireServer("UnequipPet", tool.Name)
                                    for i, id in ipairs(targetUUIDs) do
                                        if id == tool.Name then 
                                            table.remove(targetUUIDs, i)
                                            break 
                                        end
                                    end
                                    task.wait(0.5)
                                else
                                    planted = planted + 1
                                    for i, id in ipairs(targetUUIDs) do
                                        if id == tool.Name then 
                                            table.remove(targetUUIDs, i)
                                            break 
                                        end
                                    end
                                end
                            else
                                planted = planted + 1
                            end
                        end
                    end
                end
            end
        end
    end
end

function Core.GetDashboardInfo()
    local settings = GetConfig().GetSettings()
    local targetName = settings.SelectedSpecies
    local targetAge = settings.TargetAge
    local targetUUIDs = settings.TargetUUIDs or {}
    
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not PlayerGui then return "Loading GUI..." end
    
    local ActiveUI = PlayerGui:FindFirstChild("ActivePetUI")
    if not ActiveUI then return "Open garden first" end
    
    local List = ActiveUI:FindFirstChild("Frame") and ActiveUI.Frame:FindFirstChild("Main") 
        and ActiveUI.Frame.Main:FindFirstChild("PetDisplay") 
        and ActiveUI.Frame.Main.PetDisplay:FindFirstChild("ScrollingFrame")
    if not List then return "Garden not found" end
    
    local infoText = ""
    local petCount = 0
    local farmingCount = 0
    local doneCount = 0
    
    for _, frame in pairs(List:GetChildren()) do
        if frame:IsA("Frame") and frame:FindFirstChild("Main") then
            petCount = petCount + 1
            local uuid = frame.Name
            local mainFrame = frame.Main
            local petName = ""
            local age = 0
            
            local ageLabel = mainFrame:FindFirstChild("PET_AGE_SHADOW", true)
            if ageLabel and ageLabel:IsA("TextLabel") then
                local a = string.match(ageLabel.Text, "(%d+)")
                if a then age = tonumber(a) end
            end
            
            for _, lbl in pairs(mainFrame:GetDescendants()) do
                if lbl:IsA("TextLabel") and lbl.Visible and lbl.Text ~= "" and petName == "" then
                    if not string.find(lbl.Text, "Age") and not string.find(lbl.Text, ":") and lbl.Text ~= "Shadow" then
                        petName = lbl.Text
                    end
                end
            end
            
            if petName ~= "" then
                local isDone, reason = Core.IsDone(petName, age, targetAge)
                local status = "[GIỮ]"
                
                if not isDone then
                    local isFarming = false
                    for _, id in ipairs(targetUUIDs) do
                        if id == uuid then isFarming = true; break end
                    end
                    if isFarming then
                        status = "[FARM]"
                        farmingCount = farmingCount + 1
                    end
                end
                
                if isDone then
                    doneCount = doneCount + 1
                end
                
                infoText = infoText .. string.format("%s Lv.%-3d %s\n", status, age, petName)
            end
        end
    end
    
    local header = string.format("=== Garden: %d/%d | Farming: %d | Holding: %d ===\nTarget: %s | Age >= %d | Exclude Mutations: %s\n\n", 
        petCount, settings.MaxSlots, farmingCount, doneCount, targetName or "None", targetAge, settings.ExcludeMutation and "Yes" or "No")
        
    return header .. (infoText ~= "" and infoText or "Garden empty")
end

return Core
