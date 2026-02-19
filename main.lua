local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local LocalPlayer = Players.LocalPlayer
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

local Settings = {
    AutoFarmEnabled = false,
    IsDead = false,
    IgnoredSafes = {},
    ProcessedSafes = {},
    IgnoreTimers = {},
    IgnoreDuration = 60,
    Debug = true,
    MinYLevel = 4.8,
    SpeedMultiplier = 22,
    AntiAfkEnabled = true,
    MaxSegmentLength = 3,
    UseDirectFlight = true
}

local CoolDowns = {
    AutoPickUps = {
        MoneyCooldown = false
    }
}

local lastActivityTime = tick()
local currentTargetPart = nil
local isMoving = false

local function Log(msg)
    if Settings.Debug then
        print("[AutoFarm]", msg)
    end
end

local VirtualUser = game:GetService('VirtualUser')
local AntiAfkEnabled = true
local AntiAfkConnection = nil

local function StartAntiAfk()
    if AntiAfkConnection then return end
    AntiAfkConnection = LocalPlayer.Idled:Connect(function()
        if AntiAfkEnabled then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
            Log("Анти-АФК активирован - предотвращен кик")
        end
    end)
    Log("Анти-АФК запущен")
end

local function StopAntiAfk()
    if AntiAfkConnection then
        AntiAfkConnection:Disconnect()
        AntiAfkConnection = nil
    end
    Log("Анти-АФК остановлен")
end

StartAntiAfk()

local AutoPickupMoneyEnabled = false
local AutoPickupMoneyConnection

local function AutoPickupMoneyEnable()
    if AutoPickupMoneyEnabled then return end
    AutoPickupMoneyEnabled = true
    if AutoPickupMoneyConnection then
        AutoPickupMoneyConnection:Disconnect()
        AutoPickupMoneyConnection = nil
    end
    AutoPickupMoneyConnection = RunService.RenderStepped:Connect(function()
        if not AutoPickupMoneyEnabled then return end
        if Settings.IsDead then return end
        local cashFolder = Workspace:FindFirstChild("Filter") and Workspace.Filter:FindFirstChild("SpawnedBread")
        local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
        local remoteEvent = eventsFolder and eventsFolder:FindFirstChild("CZDPZUS")
        if not cashFolder or not remoteEvent then return end
        local player = Players.LocalPlayer
        local character = player and player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if CoolDowns.AutoPickUps.MoneyCooldown then return end
        local rootPosition = hrp.Position
        for _, v in ipairs(cashFolder:GetChildren()) do
            if (rootPosition - v.Position).Magnitude <= 5 then
                if not CoolDowns.AutoPickUps.MoneyCooldown then
                    CoolDowns.AutoPickUps.MoneyCooldown = true
                    pcall(function()
                        remoteEvent:FireServer(v)
                    end)
                    task.wait(1.1)
                    CoolDowns.AutoPickUps.MoneyCooldown = false
                    break
                end
            end
        end
    end)
end

local function AutoPickupMoneyDisable()
    if not AutoPickupMoneyEnabled then return end
    AutoPickupMoneyEnabled = false
    if AutoPickupMoneyConnection then
        AutoPickupMoneyConnection:Disconnect()
        AutoPickupMoneyConnection = nil
    end
    if CoolDowns and CoolDowns.AutoPickUps then
        CoolDowns.AutoPickUps.MoneyCooldown = false
    end
end

AutoPickupMoneyEnable()
Log("Автоподбор денег активирован")

local Invis_Fixed = true
local InvisEnabled = false
local Track = nil
local Animation = Instance.new("Animation")
Animation.AnimationId = "rbxassetid://215384594"
local WarnLabel = nil

do
    repeat task.wait() until game:IsLoaded()
    local cloneref = cloneref or function(...) return ... end
    local Service = setmetatable({}, { __index = function(_, k) return cloneref(game:GetService(k)); end })
    local Player = Service.Players.LocalPlayer
    local Character, Humanoid, HumanoidRootPart
    
    local function UpdateCharacterReferences()
        Character = Player.Character
        if Character then
            HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
            Humanoid = Character:FindFirstChildOfClass("Humanoid")
        else
            HumanoidRootPart = nil
            Humanoid = nil
        end
    end
    UpdateCharacterReferences()

    local Heartbeat = RunService.Heartbeat
    local RenderStepped = RunService.RenderStepped
    local CoreGui = game:GetService("CoreGui")
    local StarterGui = game:GetService("StarterGui")

    if Character and not Character:FindFirstChild("Torso") then
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "Невидимость НЕ РАБОТАЕТ",
                Text = "Функция требует R6 аватар",
                Duration = 5
            })
        end)
        Invis_Fixed = false
    end

    local GUI = Instance.new("ScreenGui")
    GUI.Name = "InvisWarningGUI"
    GUI.Parent = CoreGui
    GUI.ResetOnSpawn = false
    GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    WarnLabel = Instance.new("TextLabel", GUI)
    WarnLabel.Text = "⚠️Вы видны⚠️"
    WarnLabel.Visible = false
    WarnLabel.Size = UDim2.new(0, 200, 0, 30)
    WarnLabel.Position = UDim2.new(0.5, -100, 0.85, 0)
    WarnLabel.BackgroundTransparency = 1
    WarnLabel.Font = Enum.Font.GothamSemibold
    WarnLabel.TextSize = 24
    WarnLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
    WarnLabel.TextStrokeTransparency = 0.5
    WarnLabel.ZIndex = 10

    local function Grounded()
        return Humanoid and Humanoid:IsDescendantOf(workspace) and Humanoid.FloorMaterial ~= Enum.Material.Air
    end

    local function LoadAndPrepareTrack()
        if Track then
            pcall(function() Track:Stop() end)
            Track = nil
        end
        if Humanoid then
            local success, result = pcall(function() return Humanoid:LoadAnimation(Animation) end)
            if success then
                Track = result
                Track.Priority = Enum.AnimationPriority.Action4
            else
                Track = nil
            end
        else
            Track = nil
        end
    end

    local function Invis_Disable()
        if not InvisEnabled then return end
        InvisEnabled = false
        if Track then pcall(function() Track:Stop() end) end
        if Humanoid then workspace.CurrentCamera.CameraSubject = Humanoid end
        if Character then
            for _, v in pairs(Character:GetDescendants()) do
                if v:IsA("BasePart") and v.Transparency == 0.5 then v.Transparency = 0 end
            end
        end
        if WarnLabel then WarnLabel.Visible = false end
    end

    local function Invis_Enable()
        if InvisEnabled or not Invis_Fixed then return end
        UpdateCharacterReferences()
        if not Character or not Humanoid or not HumanoidRootPart then return end
        if not Character:FindFirstChild("Torso") then
            pcall(function()
                StarterGui:SetCore("SendNotification", {
                    Title = "Невидимость НЕ РАБОТАЕТ",
                    Text = "Функция требует R6 аватар",
                    Duration = 5
                })
            end)
            return
        end
        InvisEnabled = true
        workspace.CurrentCamera.CameraSubject = HumanoidRootPart
        LoadAndPrepareTrack()
    end

    local function Invis_Toggle()
        if InvisEnabled then
            Invis_Disable()
        else
            Invis_Enable()
        end
        return InvisEnabled
    end

    _G.Invis_Enable = Invis_Enable
    _G.Invis_Disable = Invis_Disable
    _G.Invis_Toggle = Invis_Toggle
    _G.IsInvisEnabled = function() return InvisEnabled end

    Player.CharacterAdded:Connect(function(NewCharacter)
        if Track then pcall(function() Track:Stop() end); Track = nil end
        task.wait()
        UpdateCharacterReferences()
        if not Humanoid then
            task.wait(0.5)
            UpdateCharacterReferences()
            if not Humanoid then
                Invis_Fixed = false
                if InvisEnabled then Invis_Disable() end
                pcall(function()
                    StarterGui:SetCore("SendNotification", {
                        Title = "Ошибка невидимости",
                        Text = "Не удалось определить тип персонажа",
                        Duration = 5
                    })
                end)
                return
            end
        end
        if Humanoid.RigType ~= Enum.HumanoidRigType.R6 then
            Invis_Fixed = false
            if InvisEnabled then Invis_Disable() end
            pcall(function()
                StarterGui:SetCore("SendNotification", {
                    Title = "Предупреждение невидимости",
                    Text = "Обнаружен не-R6 аватар. Невидимость отключена",
                    Duration = 5
                })
            end)
            return
        else
            Invis_Fixed = true
        end
        if InvisEnabled then
            if HumanoidRootPart then workspace.CurrentCamera.CameraSubject = HumanoidRootPart end
            LoadAndPrepareTrack()
        end
    end)

    Player.CharacterRemoving:Connect(function(OldCharacter)
        if Track then pcall(function() Track:Stop() end); Track = nil end
        if WarnLabel then WarnLabel.Visible = false end
    end)

    Heartbeat:Connect(function(deltaTime)
        if not InvisEnabled or not Invis_Fixed then
            if not InvisEnabled and Character then
                for _, v in pairs(Character:GetDescendants()) do
                    if v:IsA("BasePart") and v.Transparency == 0.5 then v.Transparency = 0 end
                end
            end
            if WarnLabel then WarnLabel.Visible = false end
            return
        end
        if not Character or not Humanoid or not HumanoidRootPart or not Humanoid:IsDescendantOf(workspace) or Humanoid.Health <= 0 then
            if WarnLabel then WarnLabel.Visible = false end
            return
        end
        if WarnLabel then WarnLabel.Visible = not Grounded() end

        local speed = 12
        if Humanoid.MoveDirection.Magnitude > 0 then
            local offset = Humanoid.MoveDirection * speed * deltaTime
            HumanoidRootPart.CFrame = HumanoidRootPart.CFrame + offset
        end

        local OldCFrame = HumanoidRootPart.CFrame
        local OldCameraOffset = Humanoid.CameraOffset
        local _, y = workspace.CurrentCamera.CFrame:ToOrientation()

        HumanoidRootPart.CFrame = CFrame.new(HumanoidRootPart.CFrame.Position) * CFrame.fromOrientation(0, y, 0)
        HumanoidRootPart.CFrame = HumanoidRootPart.CFrame * CFrame.Angles(math.rad(90), 0, 0)
        Humanoid.CameraOffset = Vector3.new(0, 1.44, 0)

        if Track then
            local successPlay = pcall(function()
                if not Track.IsPlaying then Track:Play() end
                Track:AdjustSpeed(0)
                Track.TimePosition = 0.3
            end)
            if not successPlay then LoadAndPrepareTrack() end
        elseif Humanoid and Humanoid.Health > 0 then
            LoadAndPrepareTrack()
        end

        RenderStepped:Wait()

        if Humanoid and Humanoid:IsDescendantOf(workspace) then
            Humanoid.CameraOffset = OldCameraOffset
        end
        if HumanoidRootPart and HumanoidRootPart:IsDescendantOf(workspace) then
            HumanoidRootPart.CFrame = OldCFrame
        end
        if Track then pcall(function() Track:Stop() end) end
        if HumanoidRootPart and HumanoidRootPart:IsDescendantOf(workspace) then
            local LookVector = workspace.CurrentCamera.CFrame.LookVector
            local Horizontal = Vector3.new(LookVector.X, 0, LookVector.Z).Unit
            if Horizontal.Magnitude > 0.1 then
                HumanoidRootPart.CFrame = CFrame.new(HumanoidRootPart.Position, HumanoidRootPart.Position + Horizontal)
            end
        end
        if Character then
            for _, v in pairs(Character:GetDescendants()) do
                if (v:IsA("BasePart") and v.Transparency ~= 1) then
                    v.Transparency = 0.5
                end
            end
        end
    end)
end

RunService.Stepped:Connect(function()
    if Settings.AutoFarmEnabled and LocalPlayer.Character then
        pcall(function()
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    end
end)

local function DisableDoorsCollision()
    local map = Workspace:FindFirstChild("Map")
    if map then
        local doorsFolder = map:FindFirstChild("Doors")
        if doorsFolder then
            for _, door in ipairs(doorsFolder:GetDescendants()) do
                pcall(function()
                    if door:IsA("BasePart") then
                        door.CanCollide = false
                    end
                end)
            end
            Log("Коллизия дверей отключена")
        end
    end
end
DisableDoorsCollision()

local PathVisuals = Instance.new("Folder")
PathVisuals.Name = "PathVisuals"
PathVisuals.Parent = Workspace

local function ClearPathVisuals()
    for _, v in ipairs(PathVisuals:GetChildren()) do
        pcall(function() v:Destroy() end)
    end
end

local function CreatePathVisuals(waypoints, startPos)
    ClearPathVisuals()
    if not waypoints or #waypoints == 0 then return end
    for i, wp in ipairs(waypoints) do
        local sphere = Instance.new("Part")
        sphere.Name = "Waypoint" .. i
        sphere.Size = Vector3.new(2, 2, 2)
        sphere.Position = wp.Position
        sphere.Anchored = true
        sphere.CanCollide = false
        sphere.Material = Enum.Material.Neon
        sphere.Color = Color3.fromHSV(i / #waypoints, 1, 1)
        sphere.Transparency = 0.3
        sphere.Parent = PathVisuals
    end
    local prevPos = startPos
    for i, wp in ipairs(waypoints) do
        local start = prevPos
        local finish = wp.Position
        local distance = (finish - start).Magnitude
        if distance > 0.5 then
            local line = Instance.new("Part")
            line.Name = "PathLine" .. i
            line.Anchored = true
            line.CanCollide = false
            line.Material = Enum.Material.Neon
            line.Color = Color3.new(0, 1, 0)
            line.Transparency = 0.5
            line.Size = Vector3.new(0.5, 0.5, distance)
            line.CFrame = CFrame.lookAt(start + (finish - start)/2, finish)
            line.Parent = PathVisuals
        end
        prevPos = finish
    end
end

local function CleanIgnoredSafes()
    local now = tick()
    for safe, expiry in pairs(Settings.IgnoreTimers) do
        if now > expiry then
            Settings.IgnoreTimers[safe] = nil
            for i, v in ipairs(Settings.IgnoredSafes) do
                if v == safe then
                    table.remove(Settings.IgnoredSafes, i)
                    break
                end
            end
            Log("Повторно активирован игнорируемый сейф: " .. tostring(safe))
        end
    end
end

local function SplitPathIntoSegments(waypoints)
    if not waypoints or #waypoints < 2 then return waypoints end
    local newWaypoints = {}
    local maxSegmentLength = Settings.MaxSegmentLength
    table.insert(newWaypoints, waypoints[1])
    for i = 2, #waypoints do
        local start = waypoints[i-1].Position
        local finish = waypoints[i].Position
        local distance = (finish - start).Magnitude
        if distance <= maxSegmentLength then
            table.insert(newWaypoints, waypoints[i])
        else
            local numSegments = math.ceil(distance / maxSegmentLength)
            for j = 1, numSegments do
                local alpha = j / numSegments
                local pointPos = start:Lerp(finish, alpha)
                local newPoint = {
                    Position = pointPos,
                    Action = (j == numSegments and waypoints[i].Action) or Enum.PathWaypointAction.Walk
                }
                table.insert(newWaypoints, newPoint)
            end
        end
    end
    Log("Путь разбит: " .. #waypoints .. " -> " .. #newWaypoints .. " точек")
    return newWaypoints
end

local function ComputePathWithRetry(startPos, endPos)
    local attempts = {
        {radius = 1,   height = 4,   spacing = 2},
        {radius = 1.2, height = 4.5, spacing = 2.5},
        {radius = 1.5, height = 5,   spacing = 3},
        {radius = 2,   height = 5.5, spacing = 4},
        {radius = 2.5, height = 6,   spacing = 5},
        {radius = 3,   height = 6.5, spacing = 5},
        {radius = 3.5, height = 7,   spacing = 6},
        {radius = 4,   height = 7.5, spacing = 6},
        {radius = 1,   height = 8,   spacing = 3},
        {radius = 5,   height = 5,   spacing = 5},
    }

    for _, params in ipairs(attempts) do
        local pathParams = {
            AgentRadius = params.radius,
            AgentHeight = params.height,
            AgentCanJump = true,
            AgentCanClimb = true,
            WaypointSpacing = params.spacing,
            CostCalibration = true
        }
        local path = PathfindingService:CreatePath(pathParams)
        local success = pcall(function()
            path:ComputeAsync(startPos, endPos)
        end)
        if success and path.Status == Enum.PathStatus.Success then
            return SplitPathIntoSegments(path:GetWaypoints())
        end
        task.wait(0.05)
    end
    return nil
end

local function GetFrontPosition(targetPart, fromPos)
    if not targetPart then return nil end
    local success, objCF = pcall(function() return targetPart.CFrame end)
    if not success then return nil end
    local frontDirection = objCF.LookVector
    frontDirection = Vector3.new(frontDirection.X, 0, frontDirection.Z).Unit
    if frontDirection.Magnitude < 0.1 then
        frontDirection = (fromPos - objCF.Position).Unit
        frontDirection = Vector3.new(frontDirection.X, 0, frontDirection.Z).Unit
        if frontDirection.Magnitude < 0.1 then
            frontDirection = Vector3.new(1, 0, 0)
        end
    end
    return objCF.Position + frontDirection * 4
end

local function GetFootPosition()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local footPos = hrp.Position - Vector3.new(0, 2.5, 0)
    return footPos
end

local function WalkToTarget(targetPart)
    local char = LocalPlayer.Character
    if not char then Log("Нет персонажа"); return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then Log("Нет HRP или Humanoid"); return false end
    if not targetPart or not targetPart:IsA("BasePart") then Log("Неверная цель"); return false end

    currentTargetPart = targetPart
    isMoving = true
    local startPos = hrp.Position
    local frontPos = GetFrontPosition(targetPart, startPos)
    if not frontPos then Log("Не удалось вычислить позицию перед объектом"); isMoving = false; return false end
    local endPos = frontPos

    Log("Поиск пути к цели")
    local waypoints = ComputePathWithRetry(startPos, endPos)

    if not waypoints then
        if Settings.UseDirectFlight then
            Log("Путь не найден - лечу напрямую к цели")
            local dist = (endPos - hrp.Position).Magnitude
            if dist > 1 then
                local targetHrpPos = endPos + Vector3.new(0, 2.5, 0)
                local currentRot = hrp.CFrame - hrp.CFrame.Position
                local targetCFrame = CFrame.new(targetHrpPos) * currentRot
                local tween = TweenService:Create(hrp, TweenInfo.new(dist / Settings.SpeedMultiplier, Enum.EasingStyle.Linear), {
                    CFrame = targetCFrame
                })
                tween:Play()
                tween.Completed:Wait()
                lastActivityTime = tick()
            end
            hrp.CFrame = CFrame.new(targetHrpPos) * CFrame.Angles(0, math.rad(90), 0)
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            Log("Достиг цели прямым полетом")
            isMoving = false
            return true
        else
            Log("Путь не найден после всех попыток, невозможно достичь цели")
            isMoving = false
            return false
        end
    end

    Log("Путь найден, точек: " .. #waypoints)
    CreatePathVisuals(waypoints, startPos)

    for i, wp in ipairs(waypoints) do
        if not Settings.AutoFarmEnabled then
            ClearPathVisuals()
            isMoving = false
            return false
        end

        local footPos = GetFootPosition()
        if not footPos then continue end
        local targetFootPos = wp.Position
        local targetHrpPos = targetFootPos + Vector3.new(0, 2.5, 0)
        local currentRot = hrp.CFrame - hrp.CFrame.Position
        local targetCFrame = CFrame.new(targetHrpPos) * currentRot
        local dist = (targetHrpPos - hrp.Position).Magnitude
        if dist < 0.2 then continue end

        local tween = TweenService:Create(hrp, TweenInfo.new(dist / Settings.SpeedMultiplier, Enum.EasingStyle.Linear), {
            CFrame = targetCFrame
        })
        tween:Play()
        tween.Completed:Wait()
        lastActivityTime = tick()

        if math.random() < 0.2 then task.wait(math.random(5,10)/100) end
        if wp.Action == Enum.PathWaypointAction.Jump then
            hum.Jump = true
            task.wait(0.1)
        end
    end
    ClearPathVisuals()

    local finalFootPos = endPos
    local finalHrpPos = finalFootPos + Vector3.new(0, 2.5, 0)
    hrp.CFrame = CFrame.new(finalHrpPos) * CFrame.Angles(0, math.rad(90), 0)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    Log("Достиг цели")
    isMoving = false
    return true
end

local function HasTool(toolName)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local character = LocalPlayer.Character
    return (backpack and backpack:FindFirstChild(toolName)) or (character and character:FindFirstChild(toolName))
end

local function EquipTool(toolName)
    local tool = LocalPlayer:FindFirstChild("Backpack") and LocalPlayer.Backpack:FindFirstChild(toolName)
    if tool and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        pcall(function() LocalPlayer.Character.Humanoid:EquipTool(tool) end)
        task.wait(1)
        return true
    end
    return false
end

local function FindNearestDealer()
    local map = Workspace:FindFirstChild("Map")
    if not map then Log("Карта не найдена"); return nil end
    local shopz = map:FindFirstChild("Shopz")
    if not shopz then Log("Магазины не найдены"); return nil end
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local nearest = nil
    local bestDist = math.huge
    for _, dealer in ipairs(shopz:GetChildren()) do
        local stock = dealer:FindFirstChild("CurrentStocks")
        if stock then
            local crowbarStock = stock:FindFirstChild("Crowbar")
            if crowbarStock and crowbarStock.Value > 0 then
                local mainPart = dealer:FindFirstChild("MainPart")
                if mainPart then
                    local dist = (hrp.Position - mainPart.Position).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        nearest = dealer
                    end
                end
            end
        end
    end
    if nearest then
        Log("Найден дилер с ломом, расстояние: " .. math.floor(bestDist))
    else
        Log("Дилер с ломом не найден")
    end
    return nearest
end

local function BuyCrowbar()
    local dealer = FindNearestDealer()
    if not dealer then return false end
    local mainPart = dealer:FindFirstChild("MainPart")
    if not mainPart then Log("У дилера нет MainPart"); return false end
    Log("Лечу к дилеру для покупки лома")
    if WalkToTarget(mainPart) then
        task.wait(1.5)
        local events = ReplicatedStorage:FindFirstChild("Events")
        if events then
            Log("Открываю магазин")
            pcall(function() events.BYZERSPROTEC:FireServer(true, "shop", mainPart, "IllegalStore") end)
            task.wait(1)
            Log("Покупаю лом")
            pcall(function() events.SSHPRMTE1:InvokeServer("IllegalStore", "Melees", "Crowbar", mainPart, nil, true) end)
            task.wait(20)
            Log("Закрываю магазин")
            pcall(function() events.BYZERSPROTEC:FireServer(false) end)
        end
        task.wait(2)
        local has = HasTool("Crowbar")
        if has then 
            Log("Лом успешно куплен")
        else 
            Log("Не удалось купить лом")
        end
        lastActivityTime = tick()
        return has
    else
        Log("Не удалось долететь до дилера")
    end
    return false
end

local function FindNearestSafe()
    CleanIgnoredSafes()
    local folder = nil
    local map = Workspace:FindFirstChild("Map")
    if map then folder = map:FindFirstChild("BredMakurz") end
    if not folder then
        local filter = Workspace:FindFirstChild("Filter")
        if filter then folder = filter:FindFirstChild("BredMakurz") end
    end
    if not folder then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "BredMakurz" and obj:IsA("Folder") then
                folder = obj
                break
            end
        end
    end
    if not folder then Log("Папка BredMakurz не найдена"); return nil end
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local nearest = nil
    local bestDist = math.huge
    local count = 0
    for _, v in ipairs(folder:GetChildren()) do
        if Settings.ProcessedSafes[v] then continue end
        if Settings.IgnoreTimers[v] then continue end
        local name = v.Name:lower()
        if name:find("safe") or name:find("register") then
            count = count + 1
            local values = v:FindFirstChild("Values")
            if values then
                local broken = values:FindFirstChild("Broken")
                if broken and not broken.Value then
                    local mainPart = v:FindFirstChild("MainPart") or v.PrimaryPart
                    if mainPart then
                        if mainPart.Position.Y < Settings.MinYLevel then
                            Log("Пропускаю " .. v.Name .. " (Y = " .. mainPart.Position.Y .. " < 4.8)")
                            continue
                        end
                        local dist = (mainPart.Position - hrp.Position).Magnitude
                        if dist < bestDist then
                            bestDist = dist
                            nearest = v
                        end
                    end
                end
            end
        end
    end
    Log("Найдено " .. count .. " потенциальных сейфов/касс, невзломанных: " .. (nearest and "да" or "нет"))
    if nearest then
        Log("Ближайший сейф: " .. nearest.Name .. " на расстоянии " .. math.floor(bestDist))
        lastActivityTime = tick()
    end
    return nearest
end

local function GetMoneyNearSafe(safeModel)
    local mainPart = safeModel:FindFirstChild("MainPart") or safeModel.PrimaryPart
    if not mainPart then return {} end
    local cashFolder = Workspace:FindFirstChild("Filter") and Workspace.Filter:FindFirstChild("SpawnedBread")
    if not cashFolder then return {} end
    local moneyList = {}
    for _, money in ipairs(cashFolder:GetChildren()) do
        pcall(function()
            if money:IsA("Part") and money.Transparency < 1 then
                if (money.Position - mainPart.Position).Magnitude <= 25 then
                    table.insert(moneyList, money)
                end
            end
        end)
    end
    return moneyList
end

local function CollectAllMoneyAfterBreak(safeModel)
    local moneyList = GetMoneyNearSafe(safeModel)
    if #moneyList == 0 then return false end
    Log("Собираю " .. #moneyList .. " пачек денег возле сейфа")
    for _, moneyPart in ipairs(moneyList) do
        if not Settings.AutoFarmEnabled then break end
        pcall(function()
            if moneyPart and moneyPart.Parent and moneyPart.Transparency < 1 then
                WalkToTarget(moneyPart)
                local remote = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("CZDPZUS")
                if remote then
                    pcall(function() remote:FireServer(moneyPart) end)
                end
                task.wait(0.3)
            end
        end)
    end
    return #GetMoneyNearSafe(safeModel) > 0
end

local function OpenSafe(safeModel)
    if not HasTool("Crowbar") then Log("Нет лома для открытия сейфа"); return false end
    if not LocalPlayer.Character:FindFirstChild("Crowbar") then
        EquipTool("Crowbar")
    end
    task.wait(1.5)
    local events = ReplicatedStorage:FindFirstChild("Events")
    if not events then Log("Папка Events не найдена"); return false end
    local remote1 = events:FindFirstChild("XMHH.2")
    local remote2 = events:FindFirstChild("XMHH2.2")
    local mainPart = safeModel:FindFirstChild("MainPart") or safeModel.PrimaryPart
    if not remote1 or not remote2 then Log("Remote события для взлома не найдены"); return false end
    if not mainPart then Log("У сейфа нет основной части"); return false end
    Log("Начинаю взлом сейфа")
    local startTime = tick()
    local hitCount = 0
    while Settings.AutoFarmEnabled and safeModel and safeModel.Parent do
        local values = safeModel:FindFirstChild("Values")
        if not values then break end
        local broken = values:FindFirstChild("Broken")
        if broken and broken.Value then Log("Сейф уже взломан"); break end
        if tick() - startTime > 25 then Log("Таймаут взлома"); break end
        task.wait(0.4)
        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Crowbar")
        if not tool then
            tool = LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Crowbar")
            if tool then EquipTool("Crowbar") end
        end
        if not tool then break end
        local arm = LocalPlayer.Character:FindFirstChild("Right Arm") or LocalPlayer.Character:FindFirstChild("RightHand")
        if not arm then break end
        local success, val = pcall(function()
            return remote1:InvokeServer("🍞", tick(), tool, "DZDRRRKI", safeModel, "Register")
        end)
        if success and val then
            pcall(function()
                remote2:FireServer("🍞", tick(), tool, "2389ZFX34", val, false, arm, mainPart, safeModel, mainPart.Position, mainPart.Position)
            end)
            hitCount = hitCount + 1
        end
        if hitCount % 4 == 0 then task.wait(0.8) end
        lastActivityTime = tick()
    end
    task.wait(2)
    Log("Взлом сейфа завершен, ударов: " .. hitCount)
    return true
end

local DeathEActive = false
local DeathEConnection = nil

local function PressE()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

local function StopDeathEPress()
    if DeathEActive then
        DeathEActive = false
        if DeathEConnection then
            DeathEConnection:Disconnect()
            DeathEConnection = nil
        end
    end
end

local function StartDeathEPress()
    if DeathEActive then return end
    DeathEActive = true
    Log("Обнаружена смерть - нажимаю E для возрождения")
    DeathEConnection = RunService.Heartbeat:Connect(function()
        if not DeathEActive then
            if DeathEConnection then
                DeathEConnection:Disconnect()
                DeathEConnection = nil
            end
            return
        end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if char and hum and hum.Health > 0 then
            StopDeathEPress()
            return
        end
        pcall(PressE)
    end)
end

local function onCharacterAdded(char)
    StopDeathEPress()
    task.wait(3)
    if Settings.AutoFarmEnabled then
        Settings.IsDead = false
        lastActivityTime = tick()
        Log("Персонаж возродился, продолжаю")
    end
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        hum.Died:Connect(StartDeathEPress)
    end
end

LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
if LocalPlayer.Character then
    onCharacterAdded(LocalPlayer.Character)
end

local function FarmLoop()
    Log("Цикл автофермы запущен")
    while true do
        task.wait(2)
        if not Settings.AutoFarmEnabled then
            task.wait(1)
            continue
        end
        Log("=== Цикл фермы ===")
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        Settings.IsDead = (not hum) or (hum.Health <= 0)
        if Settings.IsDead then
            Log("Персонаж мертв, ожидаю")
            task.wait(3)
            continue
        end
        if not HasTool("Crowbar") then
            Log("Нет лома, пытаюсь купить")
            local bought = BuyCrowbar()
            if not bought then
                Log("Не удалось купить лом, жду 5 секунд")
                task.wait(5)
                continue
            end
        else
            Log("Лом уже есть")
        end
        local target = FindNearestSafe()
        if not target then
            Log("Невзломанные сейфы не найдены, жду 5 секунд")
            task.wait(5)
            continue
        end
        local mainPart = target:FindFirstChild("MainPart") or target.PrimaryPart
        if not mainPart then
            Log("У цели нет MainPart, помечаю как обработанный")
            Settings.ProcessedSafes[target] = true
            continue
        end
        Log("Лечу к цели: " .. target.Name)
        if WalkToTarget(mainPart) then
            if not LocalPlayer.Character:FindFirstChild("Crowbar") then
                EquipTool("Crowbar")
            end
            Log("Открываю сейф")
            local success = OpenSafe(target)
            if success then
                Log("Сейф открыт, собираю деньги")
                local moneyRemaining = CollectAllMoneyAfterBreak(target)
                local attempts = 5
                while moneyRemaining and attempts > 0 do
                    task.wait(2)
                    moneyRemaining = CollectAllMoneyAfterBreak(target)
                    attempts = attempts - 1
                end
                Settings.ProcessedSafes[target] = true
                Log("Сейф полностью обработан")
            else
                Log("Не удалось открыть сейф, временно игнорирую")
                Settings.IgnoreTimers[target] = tick() + Settings.IgnoreDuration
                table.insert(Settings.IgnoredSafes, target)
            end
        else
            Log("Не удалось долететь до цели, временно игнорирую")
            Settings.IgnoreTimers[target] = tick() + Settings.IgnoreDuration
            table.insert(Settings.IgnoredSafes, target)
        end
        task.wait(2)
    end
end

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Window = Fluent:CreateWindow({
    Title = "AutoFarm",
    SubTitle = "",
    TabWidth = 160,
    Size = UDim2.fromOffset(500, 550),
    Acrylic = true,
    Theme = "DarkPurple",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "zap" })
}

Tabs.Main:AddToggle("AutoFarmToggle", {
    Title = "Start Auto Farm",
    Description = "",
    Default = false,
    Callback = function(v)
        Settings.AutoFarmEnabled = v
        if v then
            Settings.IgnoredSafes = {}
            Settings.ProcessedSafes = {}
            Settings.IgnoreTimers = {}
            Log("Автоферма ВКЛЮЧЕНА")
            Fluent:Notify({ Title = "AutoFarm", Content = "Запущено", Duration = 2 })
        else
            ClearPathVisuals()
            Log("Автоферма ВЫКЛЮЧЕНА")
            Fluent:Notify({ Title = "AutoFarm", Content = "Остановлено", Duration = 2 })
        end
    end
})

Tabs.Main:AddToggle("AutoPickupMoneyToggle", {
    Title = "Auto Pickup Money",
    Description = "",
    Default = true,
    Callback = function(v)
        if v then
            AutoPickupMoneyEnable()
            Log("Автоподбор денег ВКЛЮЧЕН")
        else
            AutoPickupMoneyDisable()
            Log("Автоподбор денег ВЫКЛЮЧЕН")
        end
    end
})

Tabs.Main:AddToggle("InvisibilityToggle", {
    Title = "Invisibility (R6 only)",
    Description = "",
    Default = false,
    Callback = function(v)
        if v then
            _G.Invis_Enable()
            Log("Невидимость ВКЛЮЧЕНА")
        else
            _G.Invis_Disable()
            Log("Невидимость ВЫКЛЮЧЕНА")
        end
    end
})

Tabs.Main:AddToggle("AntiAfkToggle", {
    Title = "Anti-AFK",
    Description = "",
    Default = true,
    Callback = function(v)
        AntiAfkEnabled = v
        if v then
            StartAntiAfk()
            Log("Анти-АФК ВКЛЮЧЕН")
        else
            StopAntiAfk()
            Log("Анти-АФК ВЫКЛЮЧЕН")
        end
    end
})

Tabs.Main:AddSlider("SpeedSlider", {
    Title = "Movement Speed",
    Description = "",
    Default = 22,
    Min = 10,
    Max = 50,
    Rounding = 1,
    Callback = function(v)
        Settings.SpeedMultiplier = v
        Log("Скорость установлена на " .. v)
    end
})

Fluent:Notify({ Title = "AutoFarm Loaded", Content = "Автоподбор денег активен", Duration = 2 })

task.spawn(FarmLoop)
