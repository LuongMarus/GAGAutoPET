--[[
    MODULE: PET STORAGE
    DESCRIPTION: Quản lý trạng thái pet runtime
]]

local PetStorage = {}

local Storage = {}  -- Internal storage

function PetStorage.GetAll()
    return Storage
end

function PetStorage.Get(uuid)
    return Storage[uuid]
end

function PetStorage.Set(uuid, data)
    Storage[uuid] = data
end

function PetStorage.Update(uuid, key, value)
    if Storage[uuid] then
        Storage[uuid][key] = value
        return true
    end
    return false
end

function PetStorage.Remove(uuid)
    Storage[uuid] = nil
end

function PetStorage.Clear()
    Storage = {}
end

function PetStorage.CountByStatus(status)
    local count = 0
    for _, pet in pairs(Storage) do
        if pet.Status == status then
            count = count + 1
        end
    end
    return count
end

return PetStorage