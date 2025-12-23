--[[
    MODULE: WEBHOOK
    DESCRIPTION: Xử lý Discord webhook notifications
]]

local Webhook = {}

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Gửi webhook khi pet đạt age target
function Webhook.SendPetMaxLevel(petName, petAge, webhookURL)
    if webhookURL == "" or not string.find(webhookURL, "http") then return end

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
            Url = webhookURL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
end

-- Gửi webhook khi pet đạt mutation target
function Webhook.SendMutationAchieved(petName, mutationType, webhookURL)
    if webhookURL == "" or not string.find(webhookURL, "http") then return end

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
            Url = webhookURL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
end

return Webhook
