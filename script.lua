-- ====================================================================
-- Blox Fruits Ultimate Melee Auto-Farm Engine v29.0
-- File: script.lua
-- Fixes: 1. Fixed Character Shaking/Flinging (Removed invalid -90 pitch CFrame rotation)
--        2. Upright 7-Stud Mob Hover Lock (Stands upright 7 studs above mob)
--        3. 100% Guaranteed Melee Tool Auto-Equip Engine
--        4. Mob Magnet Cluster & Instant Mob-to-Mob Chain
--        5. Auto Stat Allocation & Fruit Interceptor
-- ====================================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId
local JobId = game.JobId

-- Config File Path for Persistence
local CONFIG_FILE = "BloxFruitsMaster_Config.json"

-- Master Configuration Flags
_G.AutoFarmMaster = true
_G.AutoFarmLevel = true
_G.AutoAllocateStats = true
_G.StatDistribution = {
    Melee = 0.4,
    Defense = 0.4,
    Fruit = 0.2
}

-- Load Saved Configuration State
pcall(function()
    if readfile and isfile and isfile(CONFIG_FILE) then
        local raw = readfile(CONFIG_FILE)
        local data = HttpService:JSONDecode(raw)
        if data then
            if data.AutoFarmMaster ~= nil then _G.AutoFarmMaster = data.AutoFarmMaster end
            if data.AutoFarmLevel ~= nil then _G.AutoFarmLevel = data.AutoFarmLevel end
            if data.AutoAllocateStats ~= nil then _G.AutoAllocateStats = data.AutoAllocateStats end
        end
    end
end)

local function saveConfig()
    pcall(function()
        if writefile then
            writefile(CONFIG_FILE, HttpService:JSONEncode({
                AutoFarmMaster = _G.AutoFarmMaster,
                AutoFarmLevel = _G.AutoFarmLevel,
                AutoAllocateStats = _G.AutoAllocateStats
            }))
        end
    end)
end

-- Persistent Memory Blacklists
if not _G.FailedServersList then _G.FailedServersList = {} end
if not _G.UnstorableFruits then _G.UnstorableFruits = {} end

-- Fast Safe Flight Speed (250 studs/sec)
local FLY_SPEED = 250

-- Target Fruits List
local TARGET_FRUITS = {
    ["Kitsune Fruit"] = true, ["Dragon Fruit"] = true, ["Leopard Fruit"] = true,
    ["Dough Fruit"] = true, ["T-Rex Fruit"] = true, ["Spirit Fruit"] = true,
    ["Venom Fruit"] = true, ["Shadow Fruit"] = true, ["Blizzard Fruit"] = true,
    ["Portal Fruit"] = true, ["Buddha Fruit"] = true, ["Rumble Fruit"] = true,
    ["Sound Fruit"] = true, ["Mammoth Fruit"] = true, ["Gravity Fruit"] = true,
    ["Control Fruit"] = true
}

-- Comprehensive Level Quest Database (Level 1 to 2550 across all 3 Seas)
local LEVEL_QUEST_DATABASE = {
    -- First Sea (1 - 699)
    {MinLvl = 1, MaxLvl = 9, QuestName = "BanditQuest1", QuestLvl = 1, MobName = "Bandit", QuestPos = Vector3.new(1060, 16, 1548), MobPos = Vector3.new(1060, 16, 1548)},
    {MinLvl = 10, MaxLvl = 14, QuestName = "JungleQuest", QuestLvl = 1, MobName = "Monkey", QuestPos = Vector3.new(-1600, 37, 153), MobPos = Vector3.new(-1613, 37, 149)},
    {MinLvl = 15, MaxLvl = 29, QuestName = "JungleQuest", QuestLvl = 2, MobName = "Gorilla", QuestPos = Vector3.new(-1600, 37, 153), MobPos = Vector3.new(-1237, 6, -486)},
    {MinLvl = 30, MaxLvl = 39, QuestName = "PirateQuest", QuestLvl = 1, MobName = "Pirate", QuestPos = Vector3.new(-1140, 4, 3828), MobPos = Vector3.new(-1160, 4, 3930)},
    {MinLvl = 40, MaxLvl = 59, QuestName = "PirateQuest", QuestLvl = 2, MobName = "Brute", QuestPos = Vector3.new(-1140, 4, 3828), MobPos = Vector3.new(-1145, 15, 4350)},
    {MinLvl = 60, MaxLvl = 89, QuestName = "DesertQuest", QuestLvl = 1, MobName = "Desert Bandit", QuestPos = Vector3.new(896, 6, 4388), MobPos = Vector3.new(932, 6, 4484)},
    {MinLvl = 90, MaxLvl = 119, QuestName = "SnowQuest", QuestLvl = 1, MobName = "Snow Bandit", QuestPos = Vector3.new(1385, 87, -1298), MobPos = Vector3.new(1286, 105, -1382)},
    {MinLvl = 120, MaxLvl = 149, QuestName = "MarineQuest2", QuestLvl = 1, MobName = "Chief Petty Officer", QuestPos = Vector3.new(-5036, 20, 4324), MobPos = Vector3.new(-5036, 20, 4324)},
    {MinLvl = 150, MaxLvl = 189, QuestName = "SkyQuest", QuestLvl = 1, MobName = "Sky Bandit", QuestPos = Vector3.new(-4840, 717, -2620), MobPos = Vector3.new(-4840, 717, -2620)},
    {MinLvl = 190, MaxLvl = 224, QuestName = "PrisonerQuest", QuestLvl = 1, MobName = "Prisoner", QuestPos = Vector3.new(5300, 1, 470), MobPos = Vector3.new(5300, 1, 470)},
    {MinLvl = 225, MaxLvl = 299, QuestName = "ColosseumQuest", QuestLvl = 1, MobName = "Toga Warrior", QuestPos = Vector3.new(-1580, 7, -2980), MobPos = Vector3.new(-1580, 7, -2980)},
    {MinLvl = 300, MaxLvl = 374, QuestName = "MagmaQuest", QuestLvl = 1, MobName = "Military Soldier", QuestPos = Vector3.new(-5313, 12, 8515), MobPos = Vector3.new(-5400, 15, 8500)},
    {MinLvl = 375, MaxLvl = 449, QuestName = "FishmanQuest", QuestLvl = 1, MobName = "Fishman Warrior", QuestPos = Vector3.new(61163, 18, 1567), MobPos = Vector3.new(61000, 18, 1500)},
    {MinLvl = 450, MaxLvl = 524, QuestName = "SkyExp1Quest", QuestLvl = 1, MobName = "Sky Guard", QuestPos = Vector3.new(-7860, 5545, -3800), MobPos = Vector3.new(-7900, 5545, -3800)},
    {MinLvl = 525, MaxLvl = 624, QuestName = "FountainQuest", QuestLvl = 1, MobName = "Forest Pirate", QuestPos = Vector3.new(5258, 38, 4050), MobPos = Vector3.new(5250, 38, 4050)},
    {MinLvl = 625, MaxLvl = 699, QuestName = "FountainQuest", QuestLvl = 2, MobName = "Galley Pirate", QuestPos = Vector3.new(5258, 38, 4050), MobPos = Vector3.new(5600, 38, 4950)},

    -- Second Sea (700 - 1499)
    {MinLvl = 700, MaxLvl = 724, QuestName = "Area1Quest", QuestLvl = 1, MobName = "Raider", QuestPos = Vector3.new(-425, 72, 1836), MobPos = Vector3.new(-425, 72, 1836)},
    {MinLvl = 725, MaxLvl = 774, QuestName = "Area1Quest", QuestLvl = 2, MobName = "Mercenary", QuestPos = Vector3.new(-425, 72, 1836), MobPos = Vector3.new(-875, 140, 1370)},
    {MinLvl = 775, MaxLvl = 874, QuestName = "Area2Quest", QuestLvl = 1, MobName = "Swan Pirate", QuestPos = Vector3.new(875, 120, 1220), MobPos = Vector3.new(875, 120, 1220)},
    {MinLvl = 875, MaxLvl = 949, QuestName = "MarineQuest3", QuestLvl = 1, MobName = "Marine Lieutenant", QuestPos = Vector3.new(-2440, 72, -3210), MobPos = Vector3.new(-2840, 72, -3000)},
    {MinLvl = 950, MaxLvl = 999, QuestName = "ZombieQuest", QuestLvl = 1, MobName = "Zombie", QuestPos = Vector3.new(-5480, 48, -7950), MobPos = Vector3.new(-5480, 48, -7950)},
    {MinLvl = 1000, MaxLvl = 1099, QuestName = "SnowMountainQuest", QuestLvl = 1, MobName = "Snow Trooper", QuestPos = Vector3.new(605, 400, -5370), MobPos = Vector3.new(650, 400, -5300)},
    {MinLvl = 1100, MaxLvl = 1174, QuestName = "IceSideQuest", QuestLvl = 1, MobName = "Lab Subordinate", QuestPos = Vector3.new(-6050, 15, -4900), MobPos = Vector3.new(-6050, 15, -4900)},
    {MinLvl = 1175, MaxLvl = 1249, QuestName = "FireSideQuest", QuestLvl = 1, MobName = "Magma Ninja", QuestPos = Vector3.new(-5400, 15, -5900), MobPos = Vector3.new(-5400, 15, -5900)},
    {MinLvl = 1250, MaxLvl = 1349, QuestName = "ShipQuest1", QuestLvl = 1, MobName = "Ship Deckhand", QuestPos = Vector3.new(900, 125, 33000), MobPos = Vector3.new(900, 125, 33000)},
    {MinLvl = 1350, MaxLvl = 1424, QuestName = "FrostQuest", QuestLvl = 1, MobName = "Arctic Warrior", QuestPos = Vector3.new(5670, 28, -6480), MobPos = Vector3.new(5850, 28, -6200)},
    {MinLvl = 1425, MaxLvl = 1499, QuestName = "ForgottenQuest", QuestLvl = 1, MobName = "Water Fighter", QuestPos = Vector3.new(-3050, 235, -10150), MobPos = Vector3.new(-3050, 235, -10150)},

    -- Third Sea (1500 - 2550)
    {MinLvl = 1500, MaxLvl = 1574, QuestName = "PiratePortQuest", QuestLvl = 1, MobName = "Pirate Port", QuestPos = Vector3.new(-2900, 42, 5450), MobPos = Vector3.new(-2900, 42, 5450)},
    {MinLvl = 1575, MaxLvl = 1699, QuestName = "AmazonQuest", QuestLvl = 1, MobName = "Dragon Crew Warrior", QuestPos = Vector3.new(5800, 50, -2500), MobPos = Vector3.new(5800, 50, -2500)},
    {MinLvl = 1700, MaxLvl = 1774, QuestName = "AmazonQuest2", QuestLvl = 1, MobName = "Female Islander", QuestPos = Vector3.new(5440, 600, 750), MobPos = Vector3.new(5400, 600, 750)},
    {MinLvl = 1775, MaxLvl = 1849, QuestName = "HydraQuest", QuestLvl = 1, MobName = "Giant Mythological", QuestPos = Vector3.new(5214, 1004, -315), MobPos = Vector3.new(5200, 1000, -300)},
    {MinLvl = 1850, MaxLvl = 1924, QuestName = "GreatTreeQuest", QuestLvl = 1, MobName = "Musketeer Pirate", QuestPos = Vector3.new(-2500, 15, -9600), MobPos = Vector3.new(-2500, 15, -9600)},
    {MinLvl = 1925, MaxLvl = 1999, QuestName = "TurtleQuest", QuestLvl = 1, MobName = "Jungle Pirate", QuestPos = Vector3.new(-11470, 335, -8860), MobPos = Vector3.new(-11500, 330, -8800)},
    {MinLvl = 2000, MaxLvl = 2074, QuestName = "HauntedQuest1", QuestLvl = 1, MobName = "Reborn Skeleton", QuestPos = Vector3.new(-9515, 142, 5530), MobPos = Vector3.new(-9500, 140, 5500)},
    {MinLvl = 2075, MaxLvl = 2149, QuestName = "HauntedQuest2", QuestLvl = 1, MobName = "Living Zombie", QuestPos = Vector3.new(-9515, 142, 5530), MobPos = Vector3.new(-10100, 140, 6000)},
    {MinLvl = 2150, MaxLvl = 2224, QuestName = "PeanutQuest", QuestLvl = 1, MobName = "Peanut Scout", QuestPos = Vector3.new(-2130, 45, -12240), MobPos = Vector3.new(-2100, 45, -12200)},
    {MinLvl = 2225, MaxLvl = 2299, QuestName = "IceCreamQuest", QuestLvl = 1, MobName = "Ice Cream Chef", QuestPos = Vector3.new(-820, 65, -10980), MobPos = Vector3.new(-800, 65, -11000)},
    {MinLvl = 2300, MaxLvl = 2399, QuestName = "CookieQuest", QuestLvl = 1, MobName = "Cocoa Warrior", QuestPos = Vector3.new(-250, 45, -13000), MobPos = Vector3.new(-250, 45, -13000)},
    {MinLvl = 2400, MaxLvl = 2550, QuestName = "CandyQuest", QuestLvl = 1, MobName = "Candy Rebel", QuestPos = Vector3.new(150, 45, -13800), MobPos = Vector3.new(150, 45, -13800)}
}

-----------------------------------------------------------------------
-- Notification Subsystem
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
-- Subsystem: Auto Team Selector (Pirates)
-----------------------------------------------------------------------
local function autoSelectPiratesTeam()
    task.spawn(function()
        for i = 1, 15 do
            pcall(function()
                local commF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
                if commF then
                    commF:InvokeServer("SetTeam", "Pirates")
                end

                local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                local mainGui = playerGui and playerGui:FindFirstChild("Main")
                if mainGui then
                    local chooseTeam = mainGui:FindFirstChild("ChooseTeam")
                    if chooseTeam and chooseTeam.Visible then
                        for _, desc in ipairs(chooseTeam:GetDescendants()) do
                            if (desc:IsA("TextButton") or desc:IsA("ImageButton")) and string.find(string.lower(desc.Name), "pirate") then
                                if firesignal then firesignal(desc.MouseButton1Click) end
                            end
                        end
                    end
                end
            end)
            task.wait(0.2)
        end
    end)
end

autoSelectPiratesTeam()

-----------------------------------------------------------------------
-- Subsystem: Auto Stat Point Allocator
-----------------------------------------------------------------------
local function autoAllocateStats()
    if not _G.AutoAllocateStats then return end
    pcall(function()
        local data = LocalPlayer:FindFirstChild("Data")
        local pointsObj = data and data:FindFirstChild("Points")
        if pointsObj and pointsObj.Value > 0 then
            local totalPoints = pointsObj.Value
            local meleePts = math.floor(totalPoints * _G.StatDistribution.Melee)
            local defensePts = math.floor(totalPoints * _G.StatDistribution.Defense)
            local fruitPts = math.floor(totalPoints * _G.StatDistribution.Fruit)

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
-- Subsystem: Noclip Physics Flight Engine (250 studs/sec)
-----------------------------------------------------------------------
local function flyTo(targetCFrame)
    local char = LocalPlayer.Character
    if not char then return false end

    local root = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildWhichIsA("Humanoid")
    if not root or not humanoid then return false end

    local targetPos = targetCFrame.Position
    local startPos = root.Position
    local distance = (targetPos - startPos).Magnitude

    if distance < 10 then
        root.CFrame = targetCFrame
        return true
    end

    local noclipConnection = RunService.Stepped:Connect(function()
        if LocalPlayer.Character then
            for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end)

    humanoid:ChangeState(Enum.HumanoidStateType.Physics)

    local bv = Instance.new("BodyVelocity")
    bv.Velocity = (targetPos - root.Position).Unit * FLY_SPEED
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.Parent = root

    local startTime = tick()
    while char and root and (targetPos - root.Position).Magnitude > 8 and (tick() - startTime) < 25 do
        bv.Velocity = (targetPos - root.Position).Unit * FLY_SPEED
        root.CFrame = CFrame.new(root.Position, targetPos)
        task.wait()
    end

    if bv then bv:Destroy() end
    if noclipConnection then noclipConnection:Disconnect() end
    humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)

    root.CFrame = targetCFrame
    return true
end

-----------------------------------------------------------------------
-- Subsystem: 100% Guaranteed Melee Tool Auto-Equip Engine
-----------------------------------------------------------------------
local function equipMeleeWeapon()
    pcall(function()
        local char = LocalPlayer.Character
        local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
        if not humanoid then return end

        local currentTool = char:FindFirstChildWhichIsA("Tool")
        if currentTool then
            local isFruit = string.find(currentTool.Name, "Fruit") or string.find(currentTool.Name, "Blox")
            if not isFruit then
                return -- Already holding a Melee or Sword tool
            end
        end

        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack then
            for _, tool in ipairs(backpack:GetChildren()) do
                if tool:IsA("Tool") then
                    local isFruit = string.find(tool.Name, "Fruit") or string.find(tool.Name, "Blox")
                    if not isFruit then
                        humanoid:EquipTool(tool)
                        break
                    end
                end
            end
        end
    end)
end

-----------------------------------------------------------------------
-- Subsystem: Fruit Storage Engine
-----------------------------------------------------------------------
local function autoHandleInGameFruitMenu()
    pcall(function()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if not playerGui then return end

        for _, gui in ipairs(playerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled then
                for _, btn in ipairs(gui:GetDescendants()) do
                    if btn:IsA("TextButton") or btn:IsA("ImageButton") then
                        local txt = string.lower(btn.Text or btn.Name or "")
                        if txt == "store" or string.find(txt, "store") then
                            if firesignal then firesignal(btn.MouseButton1Click) end
                        elseif txt == "nevermind" or string.find(txt, "nevermind") then
                            if firesignal then firesignal(btn.MouseButton1Click) end
                        end
                    end
                end
            end
        end
    end)
end

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
            task.wait(0.2)
        end

        autoHandleInGameFruitMenu()

        local commF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
        if commF then
            local cleanName = string.gsub(rawName, " Fruit", "")
            local doubleName = cleanName .. "-" .. cleanName

            pcall(function() commF:InvokeServer("StoreFruit", doubleName, tool) end)
            pcall(function() commF:InvokeServer("StoreFruit", rawName, tool) end)
            pcall(function() commF:InvokeServer("StoreFruit", cleanName, tool) end)

            notify("Fruit Stored", "Сохранен в инвентарь: " .. rawName)
        end

        autoHandleInGameFruitMenu()

        task.wait(0.2)
        if tool and (tool.Parent == char or tool.Parent == LocalPlayer.Backpack) then
            _G.UnstorableFruits[rawName] = true
            pcall(function()
                if humanoid then humanoid:UnequipTools() end
                notify("Инвентарь полон", "Оставлен в рюкзаке: " .. rawName)
            end)
        end
    end)
end

local function scanAndStoreAllHeldFruits()
    pcall(function()
        autoHandleInGameFruitMenu()
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
-- Subsystem: Priority Fruit Interceptor
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
            flyTo(handle.CFrame)
            task.wait(0.2)
            root.CFrame = handle.CFrame
            
            local prompt = fruitFound:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then fireproximityprompt(prompt) end

            if firetouchinterest then
                firetouchinterest(root, handle, 0)
                task.wait(0.05)
                firetouchinterest(root, handle, 1)
            end

            task.wait(0.3)
            scanAndStoreAllHeldFruits()
            return true
        end
    end

    return false
end

-----------------------------------------------------------------------
-- Subsystem: Full Level Farming Engine (1 to 2550)
-----------------------------------------------------------------------
local function getPlayerLevel()
    local data = LocalPlayer:FindFirstChild("Data")
    local level = data and data:FindFirstChild("Level")
    return level and level.Value or 1
end

local function getUnallocatedPoints()
    local data = LocalPlayer:FindFirstChild("Data")
    local pts = data and data:FindFirstChild("Points")
    return pts and pts.Value or 0
end

local function hasActiveQuest()
    pcall(function()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        local mainGui = playerGui and playerGui:FindFirstChild("Main")
        local questFrame = mainGui and mainGui:FindFirstChild("Quest")
        if questFrame and questFrame.Visible then
            return true
        end
    end)
    return false
end

local function getCurrentQuestConfig()
    local lvl = getPlayerLevel()
    for _, q in ipairs(LEVEL_QUEST_DATABASE) do
        if lvl >= q.MinLvl and lvl <= q.MaxLvl then
            return q
        end
    end
    return LEVEL_QUEST_DATABASE[#LEVEL_QUEST_DATABASE]
end

local function farmLevelStep()
    autoAllocateStats()

    local questConfig = getCurrentQuestConfig()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
    if not root or not humanoid then return end

    equipMeleeWeapon()

    -- 1. Ensure Quest is Active
    if not hasActiveQuest() then
        local questDist = (questConfig.QuestPos - root.Position).Magnitude
        if questDist > 25 then
            flyTo(CFrame.new(questConfig.QuestPos))
        else
            root.CFrame = CFrame.new(questConfig.QuestPos)
            task.wait(0.2)
            local commF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
            if commF then
                commF:InvokeServer("StartQuest", questConfig.QuestName, questConfig.QuestLvl)
            end
            task.wait(0.3)
        end
        return
    end

    -- 2. Find target mob in Workspace.Enemies
    local targetMob = nil
    local enemies = Workspace:FindFirstChild("Enemies")
    if enemies then
        for _, mob in ipairs(enemies:GetChildren()) do
            if string.find(mob.Name, questConfig.MobName) then
                local mobHum = mob:FindFirstChildWhichIsA("Humanoid")
                local mobPart = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChildWhichIsA("BasePart")
                if mobHum and mobHum.Health > 0 and mobPart then
                    targetMob = mob
                    break
                end
            end
        end
    end

    -- 3. Fly to mob, hover 7 studs directly above (UPRIGHT, ZERO SHAKE), and execute Melee attacks!
    if targetMob then
        local mobPart = targetMob:FindFirstChild("HumanoidRootPart") or targetMob:FindFirstChildWhichIsA("BasePart")
        local mobHum = targetMob:FindFirstChildWhichIsA("Humanoid")

        if mobPart and mobHum then
            local hoverCFrame = CFrame.new(mobPart.Position + Vector3.new(0, 7, 0))
            local dist = (mobPart.Position - root.Position).Magnitude

            if dist > 15 then
                flyTo(hoverCFrame)
            else
                root.CFrame = hoverCFrame
            end

            equipMeleeWeapon()

            -- Mob Magnet (Pulls nearby same-named mobs into cluster)
            pcall(function()
                if enemies then
                    for _, otherMob in ipairs(enemies:GetChildren()) do
                        if otherMob.Name == targetMob.Name and otherMob ~= targetMob then
                            local oPart = otherMob:FindFirstChild("HumanoidRootPart")
                            local oHum = otherMob:FindFirstChildWhichIsA("Humanoid")
                            if oPart and oHum and oHum.Health > 0 and (oPart.Position - mobPart.Position).Magnitude < 250 then
                                oPart.CFrame = mobPart.CFrame
                                oPart.CanCollide = false
                                oHum.WalkSpeed = 0
                            end
                        end
                    end
                end
            end)

            -- Fast Melee Combat Execution
            pcall(function()
                local tool = char:FindFirstChildWhichIsA("Tool")
                if tool then
                    tool:Activate()
                end
                VirtualUser:CaptureController()
                VirtualUser:Button1Down(Vector2.new(500, 500), Workspace.CurrentCamera.CFrame)
            end)
        end
    else
        -- If mob not spawned in Workspace.Enemies yet, fly to mob spawn location
        flyTo(CFrame.new(questConfig.MobPos + Vector3.new(0, 15, 0)))
    end
end

-----------------------------------------------------------------------
-- Progress Dashboard GUI (Sleek Modern UI)
-----------------------------------------------------------------------
if CoreGui:FindFirstChild("BloxMasterDashboard") then
    CoreGui.BloxMasterDashboard:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BloxMasterDashboard"
ScreenGui.ResetOnSpawn = false

if gethui then
    ScreenGui.Parent = gethui()
elseif syn and syn.protect_gui then
    syn.protect_gui(ScreenGui)
    ScreenGui.Parent = CoreGui
else
    ScreenGui.Parent = CoreGui
end

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 360, 0, 260)
MainFrame.Position = UDim2.new(0.5, -180, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(55, 65, 95)
UIStroke.Thickness = 1.5
UIStroke.Parent = MainFrame

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 44)
Header.BackgroundColor3 = Color3.fromRGB(24, 28, 42)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 12)
HeaderCorner.Parent = Header

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -50, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "⚡ BLOX FRUITS MASTER AUTO-FARM"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Font = Enum.Font.SourceSansBold
TitleLabel.TextSize = 15
TitleLabel.Parent = Header

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 30, 0, 30)
MinimizeBtn.Position = UDim2.new(1, -38, 0, 7)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(38, 44, 64)
MinimizeBtn.Text = "—"
MinimizeBtn.TextColor3 = Color3.fromRGB(220, 220, 245)
MinimizeBtn.Font = Enum.Font.SourceSansBold
MinimizeBtn.TextSize = 16
MinimizeBtn.Parent = Header

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinimizeBtn

-- Level Card
local LevelCard = Instance.new("Frame")
LevelCard.Size = UDim2.new(1, -28, 0, 42)
LevelCard.Position = UDim2.new(0, 14, 0, 56)
LevelCard.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
LevelCard.BorderSizePixel = 0
LevelCard.Parent = MainFrame

local LevelCorner = Instance.new("UICorner")
LevelCorner.CornerRadius = UDim.new(0, 8)
LevelCorner.Parent = LevelCard

local LevelLabel = Instance.new("TextLabel")
LevelLabel.Size = UDim2.new(1, -16, 1, 0)
LevelLabel.Position = UDim2.new(0, 10, 0, 0)
LevelLabel.BackgroundTransparency = 1
LevelLabel.Text = "📜 УРОВЕНЬ: " .. getPlayerLevel() .. " / 2550"
LevelLabel.TextColor3 = Color3.fromRGB(100, 255, 180)
LevelLabel.TextXAlignment = Enum.TextXAlignment.Left
LevelLabel.Font = Enum.Font.SourceSansBold
LevelLabel.TextSize = 14
LevelLabel.Parent = LevelCard

-- Stats Card
local StatsCard = Instance.new("Frame")
StatsCard.Size = UDim2.new(1, -28, 0, 42)
StatsCard.Position = UDim2.new(0, 14, 0, 106)
StatsCard.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
StatsCard.BorderSizePixel = 0
StatsCard.Parent = MainFrame

local StatsCorner = Instance.new("UICorner")
StatsCorner.CornerRadius = UDim.new(0, 8)
StatsCorner.Parent = StatsCard

local StatsLabel = Instance.new("TextLabel")
StatsLabel.Size = UDim2.new(1, -16, 1, 0)
StatsLabel.Position = UDim2.new(0, 10, 0, 0)
StatsLabel.BackgroundTransparency = 1
StatsLabel.Text = "📊 СТАТЫ: АВТО (" .. getUnallocatedPoints() .. " свободны)"
StatsLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
StatsLabel.TextXAlignment = Enum.TextXAlignment.Left
StatsLabel.Font = Enum.Font.SourceSansBold
StatsLabel.TextSize = 13
StatsLabel.Parent = StatsCard

-- Active Task Status Label
local TaskStatusCard = Instance.new("Frame")
TaskStatusCard.Size = UDim2.new(1, -28, 0, 40)
TaskStatusCard.Position = UDim2.new(0, 14, 0, 156)
TaskStatusCard.BackgroundColor3 = Color3.fromRGB(20, 23, 34)
TaskStatusCard.BorderSizePixel = 0
TaskStatusCard.Parent = MainFrame

local TaskCorner = Instance.new("UICorner")
TaskCorner.CornerRadius = UDim.new(0, 8)
TaskCorner.Parent = TaskStatusCard

local TaskLabel = Instance.new("TextLabel")
TaskLabel.Size = UDim2.new(1, 0, 1, 0)
TaskLabel.BackgroundTransparency = 1
TaskLabel.Text = "⚔️ ФАРМ УРОВНЯ (1 - 2550)..."
TaskLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
TaskLabel.Font = Enum.Font.SourceSansBold
TaskLabel.TextSize = 13
TaskLabel.Parent = TaskStatusCard

-- Start / Stop Toggle Button
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(1, -28, 0, 42)
ToggleBtn.Position = UDim2.new(0, 14, 0, 204)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(46, 184, 92)
ToggleBtn.Text = "🟢 АВТО-ФАРМ ВКЛЮЧЕН"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.SourceSansBold
ToggleBtn.TextSize = 15
ToggleBtn.Parent = MainFrame

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 8)
ToggleCorner.Parent = ToggleBtn

-----------------------------------------------------------------------
-- Event Handlers & Execution Loop
-----------------------------------------------------------------------
local isMinimized = false

MinimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        MainFrame.Size = UDim2.new(0, 360, 0, 44)
        MinimizeBtn.Text = "+"
    else
        MainFrame.Size = UDim2.new(0, 360, 0, 260)
        MinimizeBtn.Text = "—"
    end
end)

ToggleBtn.MouseButton1Click:Connect(function()
    _G.AutoFarmMaster = not _G.AutoFarmMaster
    saveConfig()
    if _G.AutoFarmMaster then
        ToggleBtn.Text = "🟢 АВТО-ФАРМ ВКЛЮЧЕН"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(46, 184, 92)
        notify("Master Farm", "🟢 Авто-фарм запущен")
    else
        ToggleBtn.Text = "🔴 АВТО-ФАРМ ВЫКЛЮЧЕН"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
        TaskLabel.Text = "🔴 СТАТУС: ВЫКЛЮЧЕНО"
        notify("Master Farm", "🔴 Авто-фарм остановлен")
    end
end)

-- Main Loop
task.spawn(function()
    while true do
        task.wait(0.2)
        
        pcall(function()
            LevelLabel.Text = "📜 УРОВЕНЬ: " .. getPlayerLevel() .. " / 2550"
            StatsLabel.Text = "📊 СТАТЫ: АВТО (" .. getUnallocatedPoints() .. " свободны)"
        end)

        if _G.AutoFarmMaster then
            local fruitHarvested = checkAndHarvestFruits()
            
            if fruitHarvested then
                TaskLabel.Text = "🍊 ФРУКТ СОБРАН И СОХРАНЕН!"
                TaskLabel.TextColor3 = Color3.fromRGB(100, 255, 120)
                task.wait(0.5)
            else
                local q = getCurrentQuestConfig()
                TaskLabel.Text = "⚔️ ФАРМ: " .. q.MobName .. " (Lvl " .. q.MinLvl .. "-" .. q.MaxLvl .. ")"
                TaskLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
                farmLevelStep()
            end
        end
    end
end)

notify("Master Farm Engine", "⚡ Upright Melee Farm v29.0 Active!")
print("[+] Blox Fruits v29.0 Upright Melee Farm Active.")
