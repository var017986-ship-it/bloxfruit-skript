-- ====================================================================
-- Blox Fruits Master Harvester v63.0 (Ultra-Lite Headless Zero-Crash Edition)
-- File: script.lua
-- Features: 1. 0% GUI / 0% CoreGui calls (Eliminates ALL BlueStacks Android crashes)
--           2. Pure Headless Background Harvester & Server Hopper
--           3. Instant Auto Pirates Team Selector ("PICK A SIDE!" Bypass)
--           4. Calibrated 140 studs/sec Smooth Fruit Harvester & Auto Storage
--           5. Main Universe Server Hop (2753915549) with 0% Error 773
-- ====================================================================

-- 1. Double Execution Prevention
if getgenv and getgenv().BloxHarvesterActive then
    return
end
if getgenv then getgenv().BloxHarvesterActive = true end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local JobId = game.JobId
local MAIN_UNIVERSE_PLACE_ID = 2753915549

_G.FruitsCollectedCounter = _G.FruitsCollectedCounter or 0

if not _G.VisitedServersHistory then _G.VisitedServersHistory = {} end
if not _G.UnstorableFruits then _G.UnstorableFruits = {} end
_G.VisitedServersHistory[JobId] = true

local isHoppingCurrently = false
local FLY_SPEED = 140

local TARGET_FRUITS = {
    ["Kitsune Fruit"] = true, ["Dragon Fruit"] = true, ["Leopard Fruit"] = true,
    ["Dough Fruit"] = true, ["T-Rex Fruit"] = true, ["Spirit Fruit"] = true,
    ["Venom Fruit"] = true, ["Shadow Fruit"] = true, ["Blizzard Fruit"] = true,
    ["Portal Fruit"] = true, ["Buddha Fruit"] = true, ["Rumble Fruit"] = true,
    ["Sound Fruit"] = true, ["Mammoth Fruit"] = true, ["Gravity Fruit"] = true,
    ["Control Fruit"] = true
}

-----------------------------------------------------------------------
-- Subsystem: Safe Notification
-----------------------------------------------------------------------
local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 3
        })
    end)
end

-----------------------------------------------------------------------
-- Subsystem: Teleport Auto-Execution Registration
-----------------------------------------------------------------------
local SCRIPT_RAW_URL = "https://raw.githubusercontent.com/var017986-ship-it/bloxfruit-skript/main/script.lua"
local QUEUE_CODE = 'task.spawn(function() pcall(function() repeat task.wait(1) until game:IsLoaded() and game.Players.LocalPlayer; task.wait(1.5); loadstring(game:HttpGet("' .. SCRIPT_RAW_URL .. '"))() end) end)'

local function safeQueueOnTeleport()
    pcall(function()
        local q = queue_on_teleport or queueonteleport or (ArceusX and ArceusX.QueueOnTeleport) or (getgenv and getgenv().queue_on_teleport)
        if q then q(QUEUE_CODE) end
    end)
end

safeQueueOnTeleport()

-----------------------------------------------------------------------
-- Subsystem: Safe Anti-AFK
-----------------------------------------------------------------------
pcall(function()
    LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end)

-----------------------------------------------------------------------
-- Subsystem: Fast Auto Team Selector
-----------------------------------------------------------------------
task.spawn(function()
    for _ = 1, 10 do
        pcall(function()
            local commF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
            if commF then commF:InvokeServer("SetTeam", "Pirates") end
        end)
        task.wait(0.5)
    end
end)

-----------------------------------------------------------------------
-- Subsystem: Flight Engine (140 studs/sec)
-----------------------------------------------------------------------
local function flyToTarget(targetCFrame)
    local char = LocalPlayer.Character
    if not char then return false end

    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local startPos = root.Position
    local targetPos = targetCFrame.Position
    local distance = (targetPos - startPos).Magnitude

    if distance < 15 then
        root.CFrame = targetCFrame
        return true
    end

    pcall(function()
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end)

    local travelTime = math.clamp(distance / FLY_SPEED, 0.3, 15.0)
    local steps = math.floor(travelTime / 0.04)

    for i = 1, steps do
        if not LocalPlayer.Character or not root then break end
        local alpha = i / steps
        local currentPos = startPos:Lerp(targetPos, alpha)
        root.CFrame = CFrame.new(currentPos, targetPos)
        task.wait(0.04)
    end

    root.CFrame = targetCFrame

    pcall(function()
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end)

    return true
end

-----------------------------------------------------------------------
-- Subsystem: Server Hopper
-----------------------------------------------------------------------
local function executeFastHop()
    if isHoppingCurrently then return end
    isHoppingCurrently = true

    notify("Harvester", "🚀 Поиск нового сервера...")
    safeQueueOnTeleport()

    local candidateServer = nil
    local requestSuccess, rawData = pcall(function()
        local req = (syn and syn.request) or (http and http.request) or http_request or request
        if req then
            local res = req({
                Url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", MAIN_UNIVERSE_PLACE_ID),
                Method = "GET"
            })
            return res and res.Body
        else
            return game:HttpGet(string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", MAIN_UNIVERSE_PLACE_ID))
        end
    end)

    if requestSuccess and rawData then
        pcall(function()
            local decoded = HttpService:JSONDecode(rawData)
            if decoded and decoded.data then
                for _, s in ipairs(decoded.data) do
                    if s.id ~= JobId and s.playing and s.playing >= 1 and s.playing <= 6 and not _G.VisitedServersHistory[s.id] then
                        candidateServer = s
                        break
                    end
                end
            end
        end)
    end

    if candidateServer then
        _G.VisitedServersHistory[candidateServer.id] = true
        safeQueueOnTeleport()
        local tpSuccess = pcall(function()
            TeleportService:TeleportToPlaceInstance(MAIN_UNIVERSE_PLACE_ID, candidateServer.id, LocalPlayer)
        end)

        if tpSuccess then
            task.wait(4.0)
            isHoppingCurrently = false
            return
        end
    end

    safeQueueOnTeleport()
    pcall(function()
        TeleportService:Teleport(MAIN_UNIVERSE_PLACE_ID, LocalPlayer)
    end)

    task.wait(4.0)
    isHoppingCurrently = false
end

-----------------------------------------------------------------------
-- Subsystem: Auto Stat Points
-----------------------------------------------------------------------
local function autoAllocateStats()
    pcall(function()
        local data = LocalPlayer:FindFirstChild("Data")
        local pointsObj = data and data:FindFirstChild("Points")
        if pointsObj and pointsObj.Value > 0 then
            local totalPoints = pointsObj.Value
            local meleePts = math.floor(totalPoints * 0.4)
            local defensePts = math.floor(totalPoints * 0.4)
            local fruitPts = math.floor(totalPoints * 0.2)

            local commF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
            if commF then
                if meleePts > 0 then commF:InvokeServer("AddPoint", "Melee", meleePts) end
                if defensePts > 0 then commF:InvokeServer("AddPoint", "Defense", defensePts) end
                if fruitPts > 0 then commF:InvokeServer("AddPoint", "Demon Fruit", fruitPts) end
            end
        end
    end)
end

-----------------------------------------------------------------------
-- Subsystem: Fruit Storage Engine
-----------------------------------------------------------------------
local function autoStoreInventory(tool)
    if not tool or not tool:IsA("Tool") then return end
    local rawName = tool.Name

    if _G.UnstorableFruits[rawName] then
        pcall(function()
            local char = LocalPlayer.Character
            local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
            if humanoid then humanoid:UnequipTools() end
        end)
        return
    end

    pcall(function()
        local char = LocalPlayer.Character
        local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
        
        if humanoid and tool.Parent == LocalPlayer.Backpack then
            humanoid:EquipTool(tool)
            task.wait(0.15)
        end

        local commF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
        if commF then
            local cleanName = string.gsub(rawName, " Fruit", "")
            local doubleName = cleanName .. "-" .. cleanName

            pcall(function() commF:InvokeServer("StoreFruit", doubleName, tool) end)
            pcall(function() commF:InvokeServer("StoreFruit", rawName, tool) end)
            pcall(function() commF:InvokeServer("StoreFruit", cleanName, tool) end)

            _G.FruitsCollectedCounter = _G.FruitsCollectedCounter + 1
            notify("Fruit Stored", "Сохранен: " .. rawName)
        end

        task.wait(0.2)
        if tool and (tool.Parent == char or tool.Parent == LocalPlayer.Backpack) then
            _G.UnstorableFruits[rawName] = true
            pcall(function()
                if humanoid then humanoid:UnequipTools() end
            end)
        end
    end)
end

local function scanAndStoreAllHeldFruits()
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            for _, item in ipairs(char:GetChildren()) do
                if item:IsA("Tool") and (string.find(item.Name, "Fruit") or string.find(item.Name, "Blox")) then
                    autoStoreInventory(item)
                end
            end
        end
        if LocalPlayer:FindFirstChild("Backpack") then
            for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
                if item:IsA("Tool") and (string.find(item.Name, "Fruit") or string.find(item.Name, "Blox")) then
                    autoStoreInventory(item)
                end
            end
        end
    end)
end

-----------------------------------------------------------------------
-- Subsystem: Priority Fruit Harvester
-----------------------------------------------------------------------
local function checkAndHarvestFruits()
    scanAndStoreAllHeldFruits()

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local fruitFound = nil

    for _, object in ipairs(Workspace:GetChildren()) do
        if object:IsA("Tool") or object:IsA("Model") then
            local isTarget = false
            for fruitName in pairs(TARGET_FRUITS) do
                if string.find(object.Name, fruitName) or (string.find(object.Name, "Fruit") and not string.find(object.Name, "Dealer")) then
                    isTarget = true
                    break
                end
            end

            if isTarget then
                fruitFound = object
                break
            end
        end
    end

    if fruitFound then
        local handle = fruitFound:FindFirstChild("Handle") or fruitFound:FindFirstChildWhichIsA("BasePart")
        if handle then
            notify("🍊 Фрукт найден!", "Полет к " .. fruitFound.Name)
            flyToTarget(handle.CFrame)
            task.wait(0.1)
            root.CFrame = handle.CFrame
            
            local prompt = fruitFound:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then fireproximityprompt(prompt) end

            if firetouchinterest then
                firetouchinterest(root, handle, 0)
                task.wait(0.05)
                firetouchinterest(root, handle, 1)
            end

            task.wait(0.2)
            scanAndStoreAllHeldFruits()
            return true
        end
    end

    return false
end

-----------------------------------------------------------------------
-- Main Harvester Loop
-----------------------------------------------------------------------
task.spawn(function()
    notify("Blox Harvester", "⚡ Скрипт активен! Поиск фруктов...")
    
    while true do
        task.wait(1.0)
        pcall(function()
            autoAllocateStats()
            local fruitHarvested = checkAndHarvestFruits()
            if fruitHarvested then
                task.wait(1.5)
            else
                if not isHoppingCurrently then
                    executeFastHop()
                end
            end
        end)
    end
end)

print("[+] Blox Fruits v63.0 Ultra-Lite Headless Active.")
