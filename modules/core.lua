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

function Core.IsMutation(petName)
    local mutationPrefixes = {"Mega", "Rainbow", "Ascended", "Nightmare"}
    for _, prefix in ipairs(mutationPrefixes) do
        if string.find(petName, prefix) then
            return true, prefix
        end
    end
    return false, "Normal"
end

function Core.ScanAndBuildTargetList(NotifyCallback)
    local settings = GetConfig().GetSettings()
    local targetName = settings.SelectedSpecies
    
    if targetName == "" or targetName == nil then 
        if NotifyCallback then NotifyCallback("Error", "No pet selected!", 3) end
        return 
    end
    
    local uuidList = {}
    local searchName = string.lower(targetName)
    local excludeMutation = settings.ExcludeMutation 
    
    local function AddToList(tool, location)
        local baseName = string.match(tool.Name, "^(.+) %[Age") or tool.Name
        local baseNameLower = string.lower(baseName)
        
        if string.find(baseNameLower, searchName, 1, true) then
            local isMutated, _ = Core.IsMutation(baseName)
            
            if location == "Backpack" and excludeMutation and isMutated then
                return
            end

            table.insert(uuidList, tool.Name)
            settings.PetStorage[tool.Name] = {
                baseName = baseName,
                uuid = tool.Name,
                lastSeen = os.time()
            }
        end
    end

    if LocalPlayer:FindFirstChild("Backpack") then
        for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
            if tool:IsA("Tool") then AddToList(tool, "Backpack") end
        end
    end
    
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
                        local mainFrame = frame.Main
                        
                        for _, lbl in pairs(mainFrame:GetDescendants()) do
                            if lbl:IsA("TextLabel") and lbl.Visible and lbl.Text ~= "" and petName == "" then
                                if not string.find(lbl.Text, "Age") and not string.find(lbl.Text, ":") then
                                    petName = lbl.Text
                                    break
                                end
                            end
                        end
                        
                        if string.find(string.lower(petName), searchName, 1, true) then
                            table.insert(uuidList, uuid)
                            settings.PetStorage[uuid] = { baseName = petName, uuid = uuid, lastSeen = os.time() }
                        end
                    end
                end
            end
        end
    end
    
    settings.TargetUUIDs = uuidList
    return #uuidList
end

function Core.ScanAndUpdateStorage(NotifyCallback)
    local settings = GetConfig().GetSettings()
    local targetName = settings.SelectedSpecies
    if targetName == "" or targetName == nil then return end
    
    local searchName = string.lower(targetName)
    local excludeMutation = settings.ExcludeMutation
    local targetUUIDs = settings.TargetUUIDs
    
    if LocalPlayer:FindFirstChild("Backpack") then
        for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local baseName = string.match(tool.Name, "^(.+) %[Age") or tool.Name
                local baseNameLower = string.lower(baseName)
                
                if string.find(baseNameLower, searchName, 1, true) then
                    if not (excludeMutation and Core.IsMutation(baseName)) then
                        local isTarget = false
                        for _, uuid in ipairs(targetUUIDs) do
                            if tool.Name == uuid then isTarget = true; break end
                        end
                        
                        if not isTarget then
                            table.insert(targetUUIDs, tool.Name)
                            settings.PetStorage[tool.Name] = {
                                baseName = baseName, uuid = tool.Name, location = "Backpack", lastSeen = os.time()
                            }
                        end
                    end
                end
            end
        end
    end
end

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
            
            local ageLabel = mainFrame:FindFirstChild("PET_AGE_SHADOW")
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
            
            for _, targetID in ipairs(targetUUIDs) do
                if uuid == targetID then isTarget = true; break end
            end

            if isTarget then
                currentTargetCount = currentTargetCount + 1
                
                local isMaxAge = age >= settings.TargetAge
                local isMutated, mutType = Core.IsMutation(petName)
                
                if isMaxAge or isMutated then
                    local reason = isMutated and ("Mutation: " .. mutType) or ("Max Age: " .. age)
                    print("[FARM] Harvest:", petName, "| Reason:", reason)
                    
                    if NotifyCallback then NotifyCallback("Harvesting", petName .. " (" .. reason .. ")", 3) end
                    
                    PetsService:FireServer("UnequipPet", uuid)
                    
                    if isMutated then
                        GetWebhook().SendMutationAchieved(petName, mutType, settings.WebhookURL)
                    else
                        GetWebhook().SendPetMaxLevel(petName, age, settings.WebhookURL)
                    end
                    
                    for i, id in ipairs(targetUUIDs) do
                        if id == uuid then table.remove(targetUUIDs, i); break end
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

function Core.PlantPets(totalOccupied, currentTargetCount)
    local settings = GetConfig().GetSettings()
    local maxSlots = settings.MaxSlots
    local farmLimit = settings.FarmLimit
    local targetUUIDs = settings.TargetUUIDs
    
    if totalOccupied >= maxSlots or currentTargetCount >= farmLimit then return end
    if not LocalPlayer:FindFirstChild("Backpack") or not LocalPlayer.Character then return end
    
    local Humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
    if #targetUUIDs == 0 then return end

    local planted = 0

    for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local isTarget = false
            for _, targetID in ipairs(targetUUIDs) do
                if tool.Name == targetID then isTarget = true; break end
            end
            
            if isTarget then
                if currentTargetCount + planted >= farmLimit or totalOccupied + planted >= maxSlots then break end
                
                print("[FARM] Plant:", tool.Name)
                Humanoid:EquipTool(tool)
                task.wait(0.5)
                tool:Activate()
                task.wait(1.5)
                
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
                                
                                local ageLabel = frame:FindFirstChild("PET_AGE_SHADOW", true)
                                if ageLabel then 
                                    local a = string.match(ageLabel.Text, "(%d+)")
                                    if a then plantedAge = tonumber(a) end
                                end
                                
                                local mainFrame = frame:FindFirstChild("Main")
                                for _, lbl in pairs(mainFrame:GetDescendants()) do
                                    if lbl:IsA("TextLabel") and lbl.Visible and lbl.Text ~= "" and plantedName == "" then
                                        if not string.find(lbl.Text, "Age") and lbl.Text ~= "Shadow" then
                                            plantedName = lbl.Text
                                        end
                                    end
                                end
                                
                                local isMaxAge = plantedAge >= settings.TargetAge
                                local isMutated, mutType = Core.IsMutation(plantedName)

                                if isMaxAge or isMutated then
                                    print("[FARM] Just planted pet is DONE, unequip:", plantedName)
                                    PetsService:FireServer("UnequipPet", plantedUUID)
                                    for i, id in ipairs(targetUUIDs) do
                                        if id == plantedUUID then table.remove(targetUUIDs, i); break end
                                    end
                                    task.wait(0.5)
                                else
                                    planted = planted + 1
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
    local targetUUIDs = settings.TargetUUIDs or {}
    
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not PlayerGui then return "Loading GUI..." end
    
    local ActiveUI = PlayerGui:FindFirstChild("ActivePetUI")
    if not ActiveUI then return "Garden not open" end
    
    local List = ActiveUI:FindFirstChild("Frame") and ActiveUI.Frame:FindFirstChild("Main") 
        and ActiveUI.Frame.Main:FindFirstChild("PetDisplay") 
        and ActiveUI.Frame.Main.PetDisplay:FindFirstChild("ScrollingFrame")
        
    if not List then return "Pet list not found" end
    
    local info = ""
    for _, frame in pairs(List:GetChildren()) do
        if frame:IsA("Frame") and frame:FindFirstChild("Main") then
            local mainFrame = frame.Main
            local petName = ""
            local age = 0
            
            local ageLabel = mainFrame:FindFirstChild("PET_AGE_SHADOW")
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
            
            if petName ~= "" then
                info = info .. petName .. " (Age " .. age .. ")\n"
            end
        end
    end
    
    return info ~= "" and info or "Garden empty"
end

return Core
