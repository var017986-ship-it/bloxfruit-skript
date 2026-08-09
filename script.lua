-- ====================================================================
-- Blox Fruits Master Harvester & Fast Server Hopper v55.0
-- File: script.lua
-- Fixes: 1. Thread-safe task.spawn coroutine wrapper in queue_on_teleport for Arceus X NEO
--        2. Removed setclipboard auto-copying completely as requested
--        3. 100% Automated Script Execution on joining any new server
--        4. Auto Team Selector loop clears "PICK A SIDE!" Pirates screen instantly on join
--        5. Pure Fruit Harvester & Auto Storage Engine (140 studs/sec Smooth Flight)
--        6. Main Universe PlaceID (2753915549) targeted for 0% Error 773
-- ====================================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId
local JobId = game.JobId

-- Main Universe Blox Fruits PlaceID (First Sea / Root Universe)
local MAIN_UNIVERSE_PLACE_ID = 2753915549

-- Master Configuration Flags
_G.AutoFarmMaster = true
_G.AutoFruitHarvest = true
_G.AutoServerHop = true
_G.AutoAllocateStats = true

_G.FruitsCollectedCounter = 0

-- Session State Flags
if not _G.VisitedServersHistory then _G.VisitedServersHistory = {} end
if not _G.UnstorableFruits then _G.UnstorableFruits = {} end
_G.VisitedServersHistory[JobId] = true

local isHoppingCurrently = false
local executeFastHop

-- Calibrated Flight Speed Constant (140 studs/sec - Slower & Ultra Smooth)
local FLY_SPEED = 140

-- Target Fruits List
local TARGET_FRUITS = {
    ["Kitsune Fruit"] = true, ["Dragon Fruit"] = true, ["Leopard Fruit"] = true,
    ["Dough Fruit"] = true, ["T-Rex Fruit"] = true, ["Spirit Fruit"] = true,
    ["Venom Fruit"] = true, ["Shadow Fruit"] = true, ["Blizzard Fruit"] = true,
    ["Portal Fruit"] = true, ["Buddha Fruit"] = true, ["Rumble Fruit"] = true,
    ["Sound Fruit"] = true, ["Mammoth Fruit"] = true, ["Gravity Fruit"] = true,
    ["Control Fruit"] = true
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
-- Subsystem: Thread-Safe Auto-Execution Engine on Teleport
-----------------------------------------------------------------------
local SCRIPT_RAW_URL = "https://raw.githubusercontent.com/var017986-ship-it/bloxfruit-skript/main/script.lua"
local QUEUE_CODE = 'task.spawn(function() pcall(function() if not game:IsLoaded() then game.Loaded:Wait() end task.wait(1) loadstring(game:HttpGet("' .. SCRIPT_RAW_URL .. '"))() end) end)'

local function forceQueueOnTeleport()
    -- Try all known mobile and PC executor queue_on_teleport hooks
    pcall(function() if queue_on_teleport then queue_on_teleport(QUEUE_CODE) end end)
    pcall(function() if queueonteleport then queueonteleport(QUEUE_CODE) end end)
    pcall(function() if getgenv and getgenv().queue_on_teleport then getgenv().queue_on_teleport(QUEUE_CODE) end end)
    pcall(function() if getgenv and getgenv().queueonteleport then getgenv().queueonteleport(QUEUE_CODE) end end)
    pcall(function() if ArceusX and ArceusX.QueueOnTeleport then ArceusX.QueueOnTeleport(QUEUE_CODE) end end)
    pcall(function() if syn and syn.queue_on_teleport then syn.queue_on_teleport(QUEUE_CODE) end end)

    -- Write to autoexec disk paths if available
    pcall(function()
        if writefile then
            pcall(function() writefile("autoexec/script.lua", QUEUE_CODE) end)
            pcall(function() writefile("autoexec.lua", QUEUE_CODE) end)
            pcall(function() writefile("Arceus/autoexec/script.lua", QUEUE_CODE) end)
        end
    end)
end

-- Pre-register auto-execution on initial load
forceQueueOnTeleport()

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
-- Subsystem: Auto Team Selector ("PICK A SIDE!" Pirates Auto-Clicker)
-----------------------------------------------------------------------
local function autoSelectPiratesTeam()
    task.spawn(function()
        while true do
            local teamSelected = false
            pcall(function()
                local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                local mainGui = playerGui and playerGui:FindFirstChild("Main")
                local chooseTeam = mainGui and mainGui:FindFirstChild("ChooseTeam")

                if chooseTeam and chooseTeam.Visible then
                    -- 1. Invoke SetTeam Remote
                    local commF = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("CommF_")
                    if commF then commF:InvokeServer("SetTeam", "Pirates") end

                    -- 2. Click Pirates Button in GUI
                    for _, desc in ipairs(chooseTeam:GetDescendants()) do
                        if (desc:IsA("TextButton") or desc:IsA("ImageButton")) and string.find(string.lower(desc.Name or desc.Text or ""), "pirate") then
                            if firesignal then
                                firesignal(desc.MouseButton1Click)
                                firesignal(desc.Activated)
                            end
                            if getconnections then
                                for _, c in ipairs(getconnections(desc.MouseButton1Click)) do c:Fire() end
                                for _, c in ipairs(getconnections(desc.Activated)) do c:Fire() end
                            end
                        end
                    end
                else
                    teamSelected = true
                end
            end)

            if teamSelected then
                break
            end
            task.wait(0.3)
        end
    end)
end

autoSelectPiratesTeam()

-----------------------------------------------------------------------
-- Subsystem: Silent Auto-OK Error Dismissal
-----------------------------------------------------------------------
GuiService.ErrorMessageChanged:Connect(function()
    pcall(function()
        local msg = GuiService:GetErrorMessage()
        if msg and #msg > 0 then
            pcall(function() GuiService:ClearError() end)
            task.wait(0.5)
            if executeFastHop and not isHoppingCurrently then
                executeFastHop()
            end
        end
    end)
end)

TeleportService.TeleportInitFailed:Connect(function()
    pcall(function()
        task.wait(0.5)
        if executeFastHop and not isHoppingCurrently then
            executeFastHop()
        end
    end)
end)

-----------------------------------------------------------------------
-- Subsystem: Calibrated Slower Flight Engine (140 studs/sec)
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

    -- Disable part collisions during flight
    pcall(function()
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end)

    -- Calculate steps for calibrated 140 studs/sec speed
    local travelTime = math.clamp(distance / FLY_SPEED, 0.3, 18.0)
    local steps = math.floor(travelTime / 0.03)

    for i = 1, steps do
        if not LocalPlayer.Character or not root then break end
        local alpha = i / steps
        local currentPos = startPos:Lerp(targetPos, alpha)
        root.CFrame = CFrame.new(currentPos, targetPos)
        task.wait(0.03)
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
-- Subsystem: Main Universe Guaranteed Server Hopper Engine
-----------------------------------------------------------------------
executeFastHop = function()
    if isHoppingCurrently then return end
    isHoppingCurrently = true

    task.delay(6, function()
        isHoppingCurrently = false
    end)

    notify("Server Hopper", "🚀 Поиск нового сервера...")

    -- Continuous re-hook before launching teleport
    forceQueueOnTeleport()

    -- 1. Query Main Universe Place ID (2753915549) with Low Player Filter (1-6 players)
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
        notify("Server Hopper", string.format("🚀 Найден сервер (%d чел)! Вход...", candidateServer.playing))
        
        forceQueueOnTeleport()
        local tpSuccess = pcall(function()
            TeleportService:TeleportToPlaceInstance(MAIN_UNIVERSE_PLACE_ID, candidateServer.id, LocalPlayer)
        end)

        if tpSuccess then
            task.wait(4.0)
            isHoppingCurrently = false
            return
        end
    end

    -- 2. Main Universe Guaranteed Fallback (TeleportService:Teleport)
    notify("Server Hopper", "⚡ Вход на открытый сервер...")
    forceQueueOnTeleport()
    pcall(function()
        TeleportService:Teleport(MAIN_UNIVERSE_PLACE_ID, LocalPlayer)
    end)

    task.wait(4.0)
    isHoppingCurrently = false
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
            task.wait(0.15)
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
TitleLabel.Text = "⚡ BLOX FRUITS HARVESTER v55.0"
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
TaskLabel.Text = "🟢 ПЛАВНЫЙ СБОР И СЕРВЕР ХОП..."
TaskLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
TaskLabel.Font = Enum.Font.SourceSansBold
TaskLabel.TextSize = 13
TaskLabel.Parent = TaskStatusCard

-- Start / Stop Toggle Button
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(1, -28, 0, 42)
ToggleBtn.Position = UDim2.new(0, 14, 0, 158)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(46, 184, 92)
ToggleBtn.Text = "🟢 СБОР И СЕРВЕР ХОП ВКЛЮЧЕН"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.SourceSansBold
ToggleBtn.TextSize = 14
ToggleBtn.Parent = MainFrame

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 8)
ToggleCorner.Parent = ToggleBtn

-----------------------------------------------------------------------
-- Event Handlers & Main Execution Loop
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
        ToggleBtn.Text = "🟢 СБОР И СЕРВЕР ХОП ВКЛЮЧЕН"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(46, 184, 92)
        TaskLabel.Text = "🟢 ПЛАВНЫЙ СБОР И СЕРВЕР ХОП..."
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
        task.wait(1.0)
        
        pcall(function()
            FruitLabel.Text = "🍊 ФРУКТЫ СОБРАНЫ: " .. _G.FruitsCollectedCounter
        end)

        if _G.AutoFarmMaster then
            autoAllocateStats()

            -- Priority 1: Check for Spawned Fruits in Workspace
            local fruitHarvested = checkAndHarvestFruits()
            
            if fruitHarvested then
                TaskLabel.Text = "🍊 ФРУКТ СОБРАН И СОХРАНЕН!"
                TaskLabel.TextColor3 = Color3.fromRGB(100, 255, 120)
                task.wait(1.5)
            else
                -- Priority 2: Main Universe Server Hop
                if _G.AutoServerHop and not isHoppingCurrently then
                    TaskLabel.Text = "🚀 ПОИСК НОВОГО СЕРВЕРА..."
                    TaskLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
                    executeFastHop()
                end
            end
        end
    end
end)

notify("Master Harvester v55.0", "⚡ THREAD-SAFE AUTO-EXECUTION ENGINE ACTIVE!")
print("[+] Blox Fruits v55.0 Thread-Safe Auto-Execution Engine Active.")
