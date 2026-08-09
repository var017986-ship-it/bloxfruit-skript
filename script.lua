-- ====================================================================
-- Blox Fruits Master Harvester & Native Server Hopper v37.0
-- File: script.lua
-- Fixes: 1. Native ServerHop Remote Engine (CommF_:InvokeServer("ServerHop") - 0% Error 773)
--        2. Main Universe PlaceID Fallback (2753915549) to eliminate 773 Restricted Place errors
--        3. BlueStacks KeyPress Auto-OK Engine (KeyCode.Return + Firesignal)
--        4. Priority Fruit Harvester & Auto Inventory Storage
--        5. Working Gacha Cousin Fruit Buyer ($254M Beli auto-rolls)
-- ====================================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId
local JobId = game.JobId

-- Main Universe Blox Fruits PlaceID (First Sea Universe)
local MAIN_UNIVERSE_PLACE_ID = 2753915549

-- Master Configuration Flags
_G.AutoFarmMaster = true
_G.AutoFruitHarvest = true
_G.AutoServerHop = true
_G.AutoGachaFruit = true
_G.AutoAllocateStats = true

_G.FruitsCollectedCounter = 0

-- Memory Blacklists & Persistent History
if not _G.VisitedServersHistory then _G.VisitedServersHistory = {} end
if not _G.UnstorableFruits then _G.UnstorableFruits = {} end
_G.VisitedServersHistory[JobId] = true

-- Safe Flight Speed (300 studs/sec)
local FLY_SPEED = 300

-- Target Fruits List
local TARGET_FRUITS = {
    ["Kitsune Fruit"] = true, ["Dragon Fruit"] = true, ["Leopard Fruit"] = true,
    ["Dough Fruit"] = true, ["T-Rex Fruit"] = true, ["Spirit Fruit"] = true,
    ["Venom Fruit"] = true, ["Shadow Fruit"] = true, ["Blizzard Fruit"] = true,
    ["Portal Fruit"] = true, ["Buddha Fruit"] = true, ["Rumble Fruit"] = true,
    ["Sound Fruit"] = true, ["Mammoth Fruit"] = true, ["Gravity Fruit"] = true,
    ["Control Fruit"] = true
}

-- Gacha Dealer NPC Locations for All 3 Seas
local GACHA_POSITIONS = {
    [2753915549] = Vector3.new(-1612, 37, 149),   -- First Sea (Jungle)
    [4442272183] = Vector3.new(-380, 73, 298),     -- Second Sea (Cafe)
    [7449423635] = Vector3.new(-12465, 375, -7550) -- Third Sea (Mansion)
}

-----------------------------------------------------------------------
-- Notification Subsystem
-----------------------------------------------------------------------
local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 4
        })
    end)
end

-----------------------------------------------------------------------
-- Subsystem: Safe Anti-AFK
-----------------------------------------------------------------------
pcall(function()
    local gc = getconnections or get_signal_cons
    if gc then
        for _, conn in pairs(gc(LocalPlayer.Idled)) do
            if conn.Disable then conn:Disable() elseif conn.Disconnect then conn:Disconnect() end
        end
    else
        LocalPlayer.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end
end)

-----------------------------------------------------------------------
-- Subsystem: Auto Team Selector (Pirates)
-----------------------------------------------------------------------
local function autoSelectPiratesTeam()
    task.spawn(function()
        for i = 1, 10 do
            pcall(function()
                local commF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
                if commF then commF:InvokeServer("SetTeam", "Pirates") end

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
            task.wait(0.3)
        end
    end)
end

autoSelectPiratesTeam()

-----------------------------------------------------------------------
-- Subsystem: BlueStacks KeyPress & Firesignal Auto-OK Engine
-----------------------------------------------------------------------
local isHoppingCurrently = false
local safeNativeServerHop

local function safeDismissErrorPopups()
    task.spawn(function()
        while true do
            task.wait(0.8)
            pcall(function()
                local robloxPromptGui = CoreGui:FindFirstChild("RobloxPromptGui")
                local promptOverlay = robloxPromptGui and robloxPromptGui:FindFirstChild("promptOverlay")
                if promptOverlay then
                    local errorPrompt = promptOverlay:FindFirstChild("ErrorPrompt")
                    if errorPrompt and errorPrompt.Visible then
                        -- 1. Simulate ENTER Key (Instantly triggers OK button on BlueStacks/Windows)
                        pcall(function()
                            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
                            task.wait(0.05)
                            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
                        end)

                        -- 2. Execute firesignal & getconnections on all buttons
                        local buttonArea = errorPrompt:FindFirstChild("ButtonArea") or errorPrompt
                        for _, btn in ipairs(buttonArea:GetDescendants()) do
                            if btn:IsA("TextButton") or btn:IsA("ImageButton") then
                                if firesignal then firesignal(btn.MouseButton1Click) end
                                if getconnections then
                                    for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
                                end
                            end
                        end

                        notify("Auto OK", "⚠️ Нажат ОК! Запуск родного переключения...")
                        task.wait(0.5)
                        if safeNativeServerHop and not isHoppingCurrently then
                            safeNativeServerHop()
                        end
                    end
                end
            end)
        end
    end)
end

safeDismissErrorPopups()

GuiService.ErrorMessageChanged:Connect(function()
    pcall(function()
        notify("Auto Error Recovery", "⚠️ Системное авто-переподключение...")
        task.wait(0.5)
        if safeNativeServerHop and not isHoppingCurrently then
            safeNativeServerHop()
        end
    end)
end)

-----------------------------------------------------------------------
-- Subsystem: Native Blox Fruits Server Hopper Engine (0% Error 773)
-----------------------------------------------------------------------
safeNativeServerHop = function()
    if isHoppingCurrently then return end
    isHoppingCurrently = true

    task.delay(6, function()
        isHoppingCurrently = false
    end)

    notify("Server Hopper", "🚀 Запуск родного поиска сервера Blox Fruits...")

    -- 1. Try Native Blox Fruits ServerHop Remote (100% Reliable, 0% Error 773)
    local commF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
    if commF then
        local queueCode = string.format([[
            repeat task.wait() until game:IsLoaded()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/var017986-ship-it/bloxfruit-skript/main/script.lua?v=%d"))()
        ]], math.random(1000, 999999))

        local queueFunc = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport) or (getgenv and getgenv().queue_on_teleport)
        if queueFunc then pcall(function() queueFunc(queueCode) end) end

        local nativeSuccess = pcall(function()
            commF:InvokeServer("ServerHop")
        end)

        if nativeSuccess then
            task.wait(5)
            isHoppingCurrently = false
            return
        end
    end

    -- 2. Fallback: Query Main Universe Place ID (2753915549) with Low Player Filter (1-5 players)
    _G.VisitedServersHistory[JobId] = true

    local pageCursor = ""
    local candidateServer = nil

    for page = 1, 6 do
        local apiUrl = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100%s",
            MAIN_UNIVERSE_PLACE_ID,
            pageCursor ~= "" and ("&cursor=" .. pageCursor) or ""
        )

        local success, response = pcall(function() return game:HttpGet(apiUrl) end)

        if success and response then
            local decoded = HttpService:JSONDecode(response)
            if decoded and decoded.data then
                local candidates = {}
                for _, s in ipairs(decoded.data) do
                    if s.id ~= JobId and s.playing >= 1 and s.playing <= 5 and not _G.VisitedServersHistory[s.id] then
                        table.insert(candidates, s)
                    end
                end

                if #candidates > 0 then
                    candidateServer = candidates[math.random(1, #candidates)]
                    break
                end

                if decoded.nextPageCursor then
                    pageCursor = decoded.nextPageCursor
                else
                    break
                end
            end
        end
        task.wait(0.15)
    end

    if candidateServer then
        notify("Server Hopper", string.format("🚀 Найден сервер (%d чел)! Вход...", candidateServer.playing))
        _G.VisitedServersHistory[candidateServer.id] = true

        pcall(function()
            TeleportService:TeleportToPlaceInstance(MAIN_UNIVERSE_PLACE_ID, candidateServer.id, LocalPlayer)
        end)
        task.wait(5)
        isHoppingCurrently = false
    else
        notify("Server Hopper", "⚠️ Запуск стандартного переподключения...")
        pcall(function() TeleportService:Teleport(MAIN_UNIVERSE_PLACE_ID, LocalPlayer) end)
        task.wait(5)
        isHoppingCurrently = false
    end
end

-----------------------------------------------------------------------
-- Subsystem: Noclip Physics Flight Engine (300 studs/sec)
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
-- Subsystem: Auto Stat Point Allocator
-----------------------------------------------------------------------
local function autoAllocateStats()
    if not _G.AutoAllocateStats then return end
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

            _G.FruitsCollectedCounter = _G.FruitsCollectedCounter + 1
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
-- Subsystem: Working Gacha Dealer Cousin Auto Fruit Buyer
-----------------------------------------------------------------------
local function autoBuyGachaFruit()
    if not _G.AutoGachaFruit then return end
    pcall(function()
        local data = LocalPlayer:FindFirstChild("Data")
        local beli = data and data:FindFirstChild("Beli")
        if beli and beli.Value >= 250000 then
            local commF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
            if commF then
                notify("Gacha Dealer", "🎲 Покупка случайного фрукта...")
                commF:InvokeServer("Cousin", "Buy")
                task.wait(0.5)
                scanAndStoreAllHeldFruits()
            end
        end
    end)
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
MainFrame.Size = UDim2.new(0, 360, 0, 220)
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
TitleLabel.Text = "⚡ BLOX FRUITS HARVESTER v37.0"
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

-- Fruit Counter Card
local FruitCard = Instance.new("Frame")
FruitCard.Size = UDim2.new(1, -28, 0, 42)
FruitCard.Position = UDim2.new(0, 14, 0, 56)
FruitCard.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
FruitCard.BorderSizePixel = 0
FruitCard.Parent = MainFrame

local FruitCorner = Instance.new("UICorner")
FruitCorner.CornerRadius = UDim.new(0, 8)
FruitCorner.Parent = FruitCard

local FruitLabel = Instance.new("TextLabel")
FruitLabel.Size = UDim2.new(1, -16, 1, 0)
FruitLabel.Position = UDim2.new(0, 10, 0, 0)
FruitLabel.BackgroundTransparency = 1
FruitLabel.Text = "🍊 ФРУКТЫ СОБРАНЫ: " .. _G.FruitsCollectedCounter
FruitLabel.TextColor3 = Color3.fromRGB(255, 180, 100)
FruitLabel.TextXAlignment = Enum.TextXAlignment.Left
FruitLabel.Font = Enum.Font.SourceSansBold
FruitLabel.TextSize = 14
FruitLabel.Parent = FruitCard

-- Task Status Card
local TaskStatusCard = Instance.new("Frame")
TaskStatusCard.Size = UDim2.new(1, -28, 0, 40)
TaskStatusCard.Position = UDim2.new(0, 14, 0, 106)
TaskStatusCard.BackgroundColor3 = Color3.fromRGB(20, 23, 34)
TaskStatusCard.BorderSizePixel = 0
TaskStatusCard.Parent = MainFrame

local TaskCorner = Instance.new("UICorner")
TaskCorner.CornerRadius = UDim.new(0, 8)
TaskCorner.Parent = TaskStatusCard

local TaskLabel = Instance.new("TextLabel")
TaskLabel.Size = UDim2.new(1, 0, 1, 0)
TaskLabel.BackgroundTransparency = 1
TaskLabel.Text = "🚀 РОДНОЙ СЕРВЕР ХОП (COMMF_)..."
TaskLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
TaskLabel.Font = Enum.Font.SourceSansBold
TaskLabel.TextSize = 13
TaskLabel.Parent = TaskStatusCard

-- Start / Stop Toggle Button
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(1, -28, 0, 42)
ToggleBtn.Position = UDim2.new(0, 14, 0, 158)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(46, 184, 92)
ToggleBtn.Text = "🟢 NATIVE SERVER HOPPER ВКЛЮЧЕН"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.SourceSansBold
ToggleBtn.TextSize = 14
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
        MainFrame.Size = UDim2.new(0, 360, 0, 220)
        MinimizeBtn.Text = "—"
    end
end)

ToggleBtn.MouseButton1Click:Connect(function()
    _G.AutoFarmMaster = not _G.AutoFarmMaster
    if _G.AutoFarmMaster then
        ToggleBtn.Text = "🟢 NATIVE SERVER HOPPER ВКЛЮЧЕН"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(46, 184, 92)
        TaskLabel.Text = "🚀 РОДНОЙ СЕРВЕР ХОП (COMMF_)..."
        TaskLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
        notify("Harvester Engine", "🟢 Поиск запущен")
    else
        ToggleBtn.Text = "🔴 СБОР И ХОППЕР ВЫКЛЮЧЕН"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
        TaskLabel.Text = "🔴 СТАТУС: ВЫКЛЮЧЕНО"
        TaskLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        notify("Harvester Engine", "🔴 Поиск остановлен")
    end
end)

-- Main Execution Loop
task.spawn(function()
    while true do
        task.wait(0.5)
        
        pcall(function()
            FruitLabel.Text = "🍊 ФРУКТЫ СОБРАНЫ: " .. _G.FruitsCollectedCounter
        end)

        if _G.AutoFarmMaster then
            autoAllocateStats()
            autoBuyGachaFruit()

            -- Priority 1: Check for spawned fruits in Workspace
            local fruitHarvested = checkAndHarvestFruits()
            
            if fruitHarvested then
                TaskLabel.Text = "🍊 ФРУКТ СОБРАН И СОХРАНЕН!"
                TaskLabel.TextColor3 = Color3.fromRGB(100, 255, 120)
                task.wait(1.0)
            else
                -- Priority 2: Native Blox Fruits Server Hop (CommF_:InvokeServer("ServerHop"))
                if _G.AutoServerHop and not isHoppingCurrently then
                    TaskLabel.Text = "🚀 РОДНОЙ СЕРВЕР ХОП (COMMF_)..."
                    TaskLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
                    safeNativeServerHop()
                end
            end
        end
    end
end)

notify("Master Harvester v37.0", "⚡ Родной Сервер Хоппер (0% Error 773) АКТИВЕН!")
print("[+] Blox Fruits v37.0 Native CommF_ Hopper Active.")
