--// Настройки и переменные
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Видимость GUI панелей
local guiVisible = false 

local flyEnabled = false
local flySpeed = 2 
local flyConnection
local frozenY = nil

local xrayEnabled = false
local brightEnabled = false

-- Настройки невидимости под землей + белый контур + свободная ходьба/бег
local invisEnabled = false
local invisSavedParts = {}
local invisConnection = nil
local invisDropOffset = 15 -- Насколько ниже опускать персонажа (в стадах)
local invisAnchorPart = nil
local invisSavedCameraSubject = nil
local invisSavedCameraType = nil
local invisSurfaceY = nil

-- Выбранный игрок для сканера, ТП и Аимбота
local selectedPlayer = nil
local targetXRayEnabled = false

-- Переменные Аимбота (Lock on Head)
local aimbotConnection = nil
local isAiming = false

-- Раздельные значения скорости и прыжка (по умолчанию 16 и 50)
local customWalkSpeed = 16
local customJumpPower = 50

-- Переключатели усиления (Speed + Jump Power)
local boostKey = Enum.KeyCode.F
local boostEnabled = false
local boostKeyBinding = false

-- Переключатель Бесконечного Прыжка (по умолчанию переключается на J, прыгает на Space)
local infJumpKey = Enum.KeyCode.J
local infJumpEnabled = false
local infJumpKeyBinding = false

local speedLoopConnection = nil

-- Переменные для освещения
local oldBrightness = Lighting.Brightness
local oldClockTime = Lighting.ClockTime
local oldGlobalShadows = Lighting.GlobalShadows
local oldAmbient = Lighting.Ambient
local oldOutdoorAmbient = Lighting.OutdoorAmbient
local oldFogEnd = Lighting.FogEnd
local removedAtmospheres = {}

----------------------------------------------------------------
--// СОЗДАНИЕ ГРАФИЧЕСКОЙ ПАНЕЛИ (GUI)
----------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VigiUIPanel"
screenGui.ResetOnSpawn = false
pcall(function()
    screenGui.Parent = CoreGui
end)
if screenGui.Parent ~= CoreGui then
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 260, 0, 598)
mainFrame.Position = UDim2.new(0, 50, 0, 45)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false -- Скрыто до нажатия Numpad 9
mainFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 40)
titleLabel.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 16
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "vigiUI"
titleLabel.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleLabel

----------------------------------------------------------------
--// ЛОГИКА ПЕРЕТАСКИВАНИЯ ПАНЕЛИ МЫШКОЙ (DRAGGABLE)
----------------------------------------------------------------
local dragging = false
local dragInput, dragStart, startPos

local function updateInput(input)
    local delta = input.Position - dragStart
    mainFrame.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + delta.X,
        startPos.Y.Scale, startPos.Y.Offset + delta.Y
    )
end

titleLabel.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

titleLabel.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        updateInput(input)
    end
end)

----------------------------------------------------------------
--// ВСПОМОГАТЕЛЬНЫЕ ЭЛЕМЕНТЫ ПАНЕЛИ
----------------------------------------------------------------

local function createButton(name, yPos, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 240, 0, 32)
    btn.Position = UDim2.new(0, 10, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamSemibold
    btn.Text = name .. ": [OFF]"
    btn.Parent = mainFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    
    btn.MouseButton1Click:Connect(function()
        local newState = callback()
        if newState then
            btn.Text = name .. ": [ON]"
            btn.BackgroundColor3 = Color3.fromRGB(0, 170, 127)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.Text = name .. ": [OFF]"
            btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end)
    
    return btn
end

local function createStatInput(name, defaultVal, yPos, onValChange)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 100, 0, 25)
    label.Position = UDim2.new(0, 10, 0, yPos)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 12
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = name .. ":"
    label.Parent = mainFrame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 130, 0, 25)
    box.Position = UDim2.new(0, 120, 0, yPos)
    box.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.TextSize = 12
    box.Font = Enum.Font.GothamBold
    box.Text = tostring(defaultVal)
    box.ClearTextOnFocus = false
    box.Parent = mainFrame

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 4)
    boxCorner.Parent = box

    box.FocusLost:Connect(function()
        local num = tonumber(box.Text)
        if num then
            onValChange(num)
        else
            box.Text = tostring(defaultVal)
        end
    end)
end

----------------------------------------------------------------
--// ФУНКЦИИ ЧИТОВ
----------------------------------------------------------------

-- Белый контур вокруг персонажа
local function setInvisOutline(char, enabled)
    if not char then return end
    local existing = char:FindFirstChild("VigiInvisOutline")
    if enabled then
        if not existing then
            local hl = Instance.new("Highlight")
            hl.Name = "VigiInvisOutline"
            hl.FillTransparency = 1
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.OutlineTransparency = 0
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = char
        end
    else
        if existing then
            existing:Destroy()
        end
    end
end

-- Отключение/восстановление столкновений частей персонажа
local function setCharacterCollision(char, canCollide)
    if not char then return end
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            if canCollide then
                if invisSavedParts[obj] and invisSavedParts[obj].CanCollide ~= nil then
                    obj.CanCollide = invisSavedParts[obj].CanCollide
                end
            else
                if not invisSavedParts[obj] then
                    invisSavedParts[obj] = {}
                end
                if invisSavedParts[obj].CanCollide == nil then
                    invisSavedParts[obj].CanCollide = obj.CanCollide
                end
                obj.CanCollide = false
            end
        end
    end
end

-- Очистка якоря камеры и возврат управления камерой игроку
local function cleanupInvisCameraAnchor()
    if invisConnection then
        invisConnection:Disconnect()
        invisConnection = nil
    end
    if invisAnchorPart then
        invisAnchorPart:Destroy()
        invisAnchorPart = nil
    end
    if invisSavedCameraType then
        Camera.CameraType = invisSavedCameraType
        invisSavedCameraType = nil
    end
    if invisSavedCameraSubject and invisSavedCameraSubject.Parent then
        Camera.CameraSubject = invisSavedCameraSubject
    else
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            Camera.CameraSubject = hum
        end
    end
    invisSavedCameraSubject = nil
end

-- Вычисление горизонтального направления движения с учётом камеры и ввода
local function getUndergroundMoveVector(hum)
    local lookFlat = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
    local rightFlat = Vector3.new(Camera.CFrame.RightVector.X, 0, Camera.CFrame.RightVector.Z)

    if lookFlat.Magnitude > 0 then lookFlat = lookFlat.Unit else lookFlat = Vector3.zero end
    if rightFlat.Magnitude > 0 then rightFlat = rightFlat.Unit else rightFlat = Vector3.zero end

    local dir = Vector3.zero
    if not UserInputService:GetFocusedTextBox() then
        if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
            dir = dir + lookFlat
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
            dir = dir - lookFlat
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
            dir = dir + rightFlat
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
            dir = dir - rightFlat
        end
    end

    if dir.Magnitude == 0 and hum and hum.MoveDirection.Magnitude > 0 then
        dir = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z)
    end

    if dir.Magnitude > 0 then
        return dir.Unit
    end
    return Vector3.zero
end

local function toggleInvisibility(enable)
    invisEnabled = enable
    cleanupInvisCameraAnchor()

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if invisEnabled then
        invisSavedParts = {}
        setInvisOutline(char, true)
        setCharacterCollision(char, false)

        if hrp then
            local originPos = hrp.Position
            invisSurfaceY = originPos.Y

            -- Создаём невидимый якорь на уровне поверхности для фиксации высоты камеры
            invisAnchorPart = Instance.new("Part")
            invisAnchorPart.Name = "VigiCamAnchor"
            invisAnchorPart.Size = Vector3.new(1, 1, 1)
            invisAnchorPart.Transparency = 1
            invisAnchorPart.Anchored = true
            invisAnchorPart.CanCollide = false
            invisAnchorPart.Position = Vector3.new(originPos.X, invisSurfaceY, originPos.Z)
            invisAnchorPart.Parent = workspace

            invisSavedCameraType = Camera.CameraType
            invisSavedCameraSubject = Camera.CameraSubject
            Camera.CameraType = Enum.CameraType.Custom
            Camera.CameraSubject = invisAnchorPart

            -- Опускаем персонажа под землю
            local undergroundPos = Vector3.new(originPos.X, invisSurfaceY - invisDropOffset, originPos.Z)
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            hrp.CFrame = CFrame.new(undergroundPos) * (hrp.CFrame - hrp.CFrame.Position)
        end

        invisConnection = RunService.Heartbeat:Connect(function(dt)
            if not invisEnabled then return end
            local currentChar = LocalPlayer.Character
            local currentHrp = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
            local currentHum = currentChar and currentChar:FindFirstChildOfClass("Humanoid")

            setInvisOutline(currentChar, true)
            setCharacterCollision(currentChar, false)

            if currentHum then
                currentHum.PlatformStand = true
            end

            if currentHrp and invisSurfaceY then
                local activeSpeed = boostEnabled and customWalkSpeed or (currentHum and currentHum.WalkSpeed or customWalkSpeed)
                local moveDir = getUndergroundMoveVector(currentHum)
                local stepXZ = moveDir * activeSpeed * dt

                local nextX = currentHrp.Position.X + stepXZ.X
                local nextZ = currentHrp.Position.Z + stepXZ.Z
                local targetUnderY = invisSurfaceY - invisDropOffset

                -- Поворачиваем персонажа в сторону движения, если он идёт/бежит
                local rotCFrame = currentHrp.CFrame - currentHrp.CFrame.Position
                if moveDir.Magnitude > 0 then
                    rotCFrame = CFrame.lookAt(Vector3.zero, moveDir)
                end

                currentHrp.AssemblyLinearVelocity = Vector3.zero
                currentHrp.AssemblyAngularVelocity = Vector3.zero
                currentHrp.CFrame = CFrame.new(nextX, targetUnderY, nextZ) * rotCFrame

                -- Камера остаётся на одном уровне по Y (invisSurfaceY) и следует по X/Z
                if invisAnchorPart and invisAnchorPart.Parent then
                    invisAnchorPart.Position = Vector3.new(nextX, invisSurfaceY, nextZ)
                    if Camera.CameraSubject ~= invisAnchorPart then
                        Camera.CameraSubject = invisAnchorPart
                    end
                end
            end
        end)
    else
        setInvisOutline(char, false)
        setCharacterCollision(char, true)
        if hum then
            hum.PlatformStand = false
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        if hrp and invisSurfaceY then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            hrp.CFrame = CFrame.new(hrp.Position.X, invisSurfaceY + 2, hrp.Position.Z) * (hrp.CFrame - hrp.CFrame.Position)
        end
        invisSurfaceY = nil
        invisSavedParts = {}
    end
    return invisEnabled
end

LocalPlayer.CharacterAdded:Connect(function(char)
    if invisEnabled then
        task.wait(0.2)
        toggleInvisibility(true)
    end
end)

-- Полет
local function toggleFly(enable)
    flyEnabled = enable
    if flyEnabled then
        local character = LocalPlayer.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        if rootPart then frozenY = rootPart.Position.Y end

        flyConnection = RunService.RenderStepped:Connect(function()
            local char = LocalPlayer.Character
            local rp = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            
            if rp and humanoid then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end

                rp.Velocity = Vector3.new(0, 0, 0)
                rp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                humanoid:ChangeState(Enum.HumanoidStateType.Physics)
                
                local flyDirection = Vector3.new(0, 0, 0)
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then flyDirection = flyDirection + Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then flyDirection = flyDirection - Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then flyDirection = flyDirection - Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then flyDirection = flyDirection + Camera.CFrame.RightVector end
                
                if flyDirection.Magnitude > 0 then
                    rp.CFrame = rp.CFrame + (flyDirection.Unit * flySpeed)
                    frozenY = rp.Position.Y
                else
                    local currentPos = rp.Position
                    rp.CFrame = CFrame.new(Vector3.new(currentPos.X, frozenY, currentPos.Z), currentPos + Camera.CFrame.LookVector)
                end
                
                local look = Camera.CFrame.LookVector
                rp.CFrame = CFrame.new(rp.Position, rp.Position + Vector3.new(look.X, 0, look.Z))
            end
        end)
    else
        if flyConnection then flyConnection:Disconnect() flyConnection = nil end
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
    end
    return flyEnabled
end

-- X-Ray всех игроков
local function applyHighlight(player, tag)
    if player == LocalPlayer then return end
    local tagName = tag or "XRayHighlight"
    local function highlightChar(character)
        if not character then return end
        if not character:FindFirstChild(tagName) then
            local highlight = Instance.new("Highlight")
            highlight.Name = tagName
            highlight.FillColor = (tagName == "TargetHighlight") and Color3.fromRGB(0, 255, 255) or Color3.fromRGB(255, 0, 0)
            highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
            highlight.FillTransparency = 0.3
            highlight.OutlineTransparency = 0
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Parent = character
        end
    end
    if player.Character then highlightChar(player.Character) end
    player.CharacterAdded:Connect(highlightChar)
end

local function removeHighlights(tag)
    local tagName = tag or "XRayHighlight"
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild(tagName) then
            player.Character[tagName]:Destroy()
        end
    end
end

local function toggleXRay(enable)
    xrayEnabled = enable
    if xrayEnabled then
        for _, player in ipairs(Players:GetPlayers()) do applyHighlight(player, "XRayHighlight") end
    else
        removeHighlights("XRayHighlight")
    end
    return xrayEnabled
end

-- Персональный X-Ray для конкретного выбранного игрока
local function toggleTargetXRay(enable)
    targetXRayEnabled = enable
    if targetXRayEnabled and selectedPlayer then
        applyHighlight(selectedPlayer, "TargetHighlight")
    else
        removeHighlights("TargetHighlight")
    end
    return targetXRayEnabled
end

Players.PlayerAdded:Connect(function(player)
    if xrayEnabled then applyHighlight(player, "XRayHighlight") end
end)

-- Свет / Убрать тени и туман
local function applyBrightSettings()
    Lighting.GlobalShadows = false
    Lighting.Brightness = 3
    Lighting.Ambient = Color3.new(1, 1, 1)
    Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    Lighting.FogEnd = 1000000000
    
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("Atmosphere") or child:IsA("PostEffect") or child:IsA("SunRaysEffect") then
            child.Parent = nil
            table.insert(removedAtmospheres, child)
        end
    end
end

local function toggleBright(enable)
    brightEnabled = enable
    if brightEnabled then
        oldBrightness = Lighting.Brightness
        oldClockTime = Lighting.ClockTime
        oldGlobalShadows = Lighting.GlobalShadows
        oldAmbient = Lighting.Ambient
        oldOutdoorAmbient = Lighting.OutdoorAmbient
        oldFogEnd = Lighting.FogEnd
        
        removedAtmospheres = {}
        applyBrightSettings()
        
        task.spawn(function()
            while brightEnabled do
                applyBrightSettings()
                task.wait(3)
            end
        end)
    else
        Lighting.Brightness = oldBrightness
        Lighting.ClockTime = oldClockTime
        Lighting.GlobalShadows = oldGlobalShadows
        Lighting.Ambient = oldAmbient
        Lighting.OutdoorAmbient = oldOutdoorAmbient
        Lighting.FogEnd = oldFogEnd
        
        for _, child in ipairs(removedAtmospheres) do
            if child and child.Parent == nil then child.Parent = Lighting end
        end
        removedAtmospheres = {}
    end
    return brightEnabled
end

-- Усиление скорости и прыжка (с защитой от отката)
local function applyBoostState(state)
    boostEnabled = state
    
    if speedLoopConnection then
        speedLoopConnection:Disconnect()
        speedLoopConnection = nil
    end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if boostEnabled then
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = customJumpPower
            hum.JumpHeight = customJumpPower
        end

        speedLoopConnection = RunService.Heartbeat:Connect(function()
            local currentChar = LocalPlayer.Character
            local currentHum = currentChar and currentChar:FindFirstChildOfClass("Humanoid")
            local currentRoot = currentChar and currentChar:FindFirstChild("HumanoidRootPart")

            if currentHum and currentRoot then
                currentHum.WalkSpeed = customWalkSpeed
                currentHum.JumpPower = customJumpPower
                currentHum.JumpHeight = customJumpPower

                if not invisEnabled and currentHum.MoveDirection.Magnitude > 0 and customWalkSpeed > 50 then
                    currentRoot.AssemblyLinearVelocity = Vector3.new(
                        currentHum.MoveDirection.X * customWalkSpeed,
                        currentRoot.AssemblyLinearVelocity.Y,
                        currentHum.MoveDirection.Z * customWalkSpeed
                    )
                end
            end
        end)
    else
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
            hum.JumpHeight = 7.2
        end
    end
end

----------------------------------------------------------------
--// ЛОГИКА АИМБОТА НА ГОЛОВУ (ЗАЖАТИЕ 'C')
----------------------------------------------------------------
local function startAiming()
    if isAiming then return end
    isAiming = true

    aimbotConnection = RunService.RenderStepped:Connect(function()
        if isAiming and selectedPlayer and selectedPlayer.Character then
            local head = selectedPlayer.Character:FindFirstChild("Head")
            if head then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position)
            end
        end
    end)
end

local function stopAiming()
    isAiming = false
    if aimbotConnection then
        aimbotConnection:Disconnect()
        aimbotConnection = nil
    end
end

----------------------------------------------------------------
--// СОЗДАНИЕ ЭЛЕМЕНТОВ НА ПАНЕЛИ
----------------------------------------------------------------
local flyBtnRef = createButton("Fly (R)", 45, function()
    return toggleFly(not flyEnabled)
end)

local xrayBtnRef = createButton("All X-Ray (V)", 82, function()
    return toggleXRay(not xrayEnabled)
end)

local brightBtnRef = createButton("Fullbright (N)", 119, function()
    return toggleBright(not brightEnabled)
end)

local invisBtnRef = createButton("Invisible (G)", 156, function()
    return toggleInvisibility(not invisEnabled)
end)

-- Поля ввода (по умолчанию 16 и 50)
createStatInput("Speed", customWalkSpeed, 198, function(val)
    customWalkSpeed = val
    if boostEnabled then applyBoostState(true) end
end)

createStatInput("Jump Power", customJumpPower, 228, function(val)
    customJumpPower = val
    if boostEnabled then applyBoostState(true) end
end)

-- Бинд переключения Усиления Скорости и Прыжка
local bindLabel = Instance.new("TextLabel")
bindLabel.Size = UDim2.new(0, 100, 0, 25)
bindLabel.Position = UDim2.new(0, 10, 0, 263)
bindLabel.BackgroundTransparency = 1
bindLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
bindLabel.TextSize = 12
bindLabel.Font = Enum.Font.Gotham
bindLabel.TextXAlignment = Enum.TextXAlignment.Left
bindLabel.Text = "Boost Key:"
bindLabel.Parent = mainFrame

local boostKeyBtn = Instance.new("TextButton")
boostKeyBtn.Size = UDim2.new(0, 130, 0, 25)
boostKeyBtn.Position = UDim2.new(0, 120, 0, 263)
boostKeyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
boostKeyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
boostKeyBtn.TextSize = 11
boostKeyBtn.Font = Enum.Font.GothamSemibold
boostKeyBtn.Text = "[" .. boostKey.Name .. "]"
boostKeyBtn.Parent = mainFrame

local keyCorner = Instance.new("UICorner")
keyCorner.CornerRadius = UDim.new(0, 4)
keyCorner.Parent = boostKeyBtn

boostKeyBtn.MouseButton1Click:Connect(function()
    boostKeyBtn.Text = "[...]"
    boostKeyBinding = true
    local conn; conn = UserInputService.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Keyboard then
            boostKey = inp.KeyCode
            boostKeyBtn.Text = "[" .. boostKey.Name .. "]"
            boostKeyBinding = false
            conn:Disconnect()
        end
    end)
end)

-- Кнопка смены клавиши для режима Бесконечного Прыжка
local infJumpBindLabel = Instance.new("TextLabel")
infJumpBindLabel.Size = UDim2.new(0, 100, 0, 25)
infJumpBindLabel.Position = UDim2.new(0, 10, 0, 293)
infJumpBindLabel.BackgroundTransparency = 1
infJumpBindLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
infJumpBindLabel.TextSize = 12
infJumpBindLabel.Font = Enum.Font.Gotham
infJumpBindLabel.TextXAlignment = Enum.TextXAlignment.Left
infJumpBindLabel.Text = "Inf Jump Key:"
infJumpBindLabel.Parent = mainFrame

local infJumpKeyBtn = Instance.new("TextButton")
infJumpKeyBtn.Size = UDim2.new(0, 130, 0, 25)
infJumpKeyBtn.Position = UDim2.new(0, 120, 0, 293)
infJumpKeyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
infJumpKeyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
infJumpKeyBtn.TextSize = 11
infJumpKeyBtn.Font = Enum.Font.GothamSemibold
infJumpKeyBtn.Text = "[" .. infJumpKey.Name .. "]"
infJumpKeyBtn.Parent = mainFrame

local ijKeyCorner = Instance.new("UICorner")
ijKeyCorner.CornerRadius = UDim.new(0, 4)
ijKeyCorner.Parent = infJumpKeyBtn

infJumpKeyBtn.MouseButton1Click:Connect(function()
    infJumpKeyBtn.Text = "[...]"
    infJumpKeyBinding = true
    local conn; conn = UserInputService.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Keyboard then
            infJumpKey = inp.KeyCode
            infJumpKeyBtn.Text = "[" .. infJumpKey.Name .. "]"
            infJumpKeyBinding = false
            conn:Disconnect()
        end
    end)
end)

----------------------------------------------------------------
--// СЕКЦИЯ: СКАНЕР, ВЫБОР, ТЕЛЕПОРТ И АИМ
----------------------------------------------------------------
local scanBtn = Instance.new("TextButton")
scanBtn.Size = UDim2.new(0, 240, 0, 28)
scanBtn.Position = UDim2.new(0, 10, 0, 328)
scanBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
scanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
scanBtn.TextSize = 12
scanBtn.Font = Enum.Font.GothamBold
scanBtn.Text = "🔍 Scan Players"
scanBtn.Parent = mainFrame

local scanCorner = Instance.new("UICorner")
scanCorner.CornerRadius = UDim.new(0, 6)
scanCorner.Parent = scanBtn

local playerListFrame = Instance.new("ScrollingFrame")
playerListFrame.Size = UDim2.new(0, 240, 0, 85)
playerListFrame.Position = UDim2.new(0, 10, 0, 363)
playerListFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
playerListFrame.BorderSizePixel = 0
playerListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
playerListFrame.ScrollBarThickness = 4
playerListFrame.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Parent = playerListFrame

local selectedLabel = Instance.new("TextLabel")
selectedLabel.Size = UDim2.new(0, 240, 0, 20)
selectedLabel.Position = UDim2.new(0, 10, 0, 453)
selectedLabel.BackgroundTransparency = 1
selectedLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
selectedLabel.TextSize = 11
selectedLabel.Font = Enum.Font.Gotham
selectedLabel.Text = "Target: None"
selectedLabel.Parent = mainFrame

-- Сканирование сервера
local function scanPlayers()
    for _, child in ipairs(playerListFrame:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    
    local count = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            count = count + 1
            local pBtn = Instance.new("TextButton")
            pBtn.Size = UDim2.new(1, 0, 0, 22)
            pBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
            pBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
            pBtn.TextSize = 11
            pBtn.Font = Enum.Font.Gotham
            pBtn.Text = plr.DisplayName .. " (@" .. plr.Name .. ")"
            pBtn.Parent = playerListFrame
            
            pBtn.MouseButton1Click:Connect(function()
                selectedPlayer = plr
                selectedLabel.Text = "Target: " .. plr.Name
                if targetXRayEnabled then
                    removeHighlights("TargetHighlight")
                    applyHighlight(selectedPlayer, "TargetHighlight")
                end
            end)
        end
    end
    playerListFrame.CanvasSize = UDim2.new(0, 0, 0, count * 22)
end

scanBtn.MouseButton1Click:Connect(function()
    scanPlayers()
end)

-- Подсветка выбранного игрока
local targetXRayBtnRef = createButton("Highlight Selected", 478, function()
    return toggleTargetXRay(not targetXRayEnabled)
end)

-- Кнопка Телепорта к выбранному игроку
local tpBtn = Instance.new("TextButton")
tpBtn.Size = UDim2.new(0, 240, 0, 28)
tpBtn.Position = UDim2.new(0, 10, 0, 516)
tpBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 180)
tpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
tpBtn.TextSize = 12
tpBtn.Font = Enum.Font.GothamBold
tpBtn.Text = "⚡ Teleport to Target"
tpBtn.Parent = mainFrame

local tpCorner = Instance.new("UICorner")
tpCorner.CornerRadius = UDim.new(0, 6)
tpCorner.Parent = tpBtn

tpBtn.MouseButton1Click:Connect(function()
    if not selectedPlayer then return end
    local myChar = LocalPlayer.Character
    local targetChar = selectedPlayer.Character
    
    if myChar and targetChar then
        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
        local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
        if myRoot and targetRoot then
            myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
        end
    end
end)

-- Подсказка по горячим клавишам
local jumpInfo = Instance.new("TextLabel")
jumpInfo.Size = UDim2.new(0, 240, 0, 20)
jumpInfo.Position = UDim2.new(0, 10, 0, 558)
jumpInfo.BackgroundTransparency = 1
jumpInfo.TextColor3 = Color3.fromRGB(150, 150, 150)
jumpInfo.TextSize = 10
jumpInfo.Font = Enum.Font.Gotham
jumpInfo.Text = "G = Invis | C = Aim | Space = Jump | Num 9 = Menu"
jumpInfo.Parent = mainFrame

----------------------------------------------------------------
--// ГЛОБАЛЬНАЯ ОБРАБОТКА НАЖАТИЙ КЛАВИШ (РАБОТАЕТ ВСЕГДА)
----------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end

    -- Переключение видимости панели (Numpad 9)
    if input.KeyCode == Enum.KeyCode.KeypadNine then
        guiVisible = not guiVisible
        mainFrame.Visible = guiVisible
        return
    end

    if boostKeyBinding or infJumpKeyBinding then return end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    -- Переключение режима Бесконечного Прыжка (по умолчанию на J)
    if input.KeyCode == infJumpKey then
        infJumpEnabled = not infJumpEnabled
    end

    -- Выполнение прыжка в воздухе на Пробел (Space), если функция активна
    if input.KeyCode == Enum.KeyCode.Space then
        if infJumpEnabled and not flyEnabled and hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end

    -- Переключение скорости и прыжка по настраиваемой кнопке
    if input.KeyCode == boostKey then
        applyBoostState(not boostEnabled)
    end

    -- Зажатие C -> Наведение на голову Target-игрока
    if input.KeyCode == Enum.KeyCode.C then
        startAiming()
    end

    -- Горячие клавиши функций
    if input.KeyCode == Enum.KeyCode.R then
        local res = toggleFly(not flyEnabled)
        flyBtnRef.Text = "Fly (R): " .. (res and "[ON]" or "[OFF]")
        flyBtnRef.BackgroundColor3 = res and Color3.fromRGB(0, 170, 127) or Color3.fromRGB(50, 50, 50)
    elseif input.KeyCode == Enum.KeyCode.V then
        local res = toggleXRay(not xrayEnabled)
        xrayBtnRef.Text = "All X-Ray (V): " .. (res and "[ON]" or "[OFF]")
        xrayBtnRef.BackgroundColor3 = res and Color3.fromRGB(0, 170, 127) or Color3.fromRGB(50, 50, 50)
    elseif input.KeyCode == Enum.KeyCode.N then
        local res = toggleBright(not brightEnabled)
        brightBtnRef.Text = "Fullbright (N): " .. (res and "[ON]" or "[OFF]")
        brightBtnRef.BackgroundColor3 = res and Color3.fromRGB(0, 170, 127) or Color3.fromRGB(50, 50, 50)
    elseif input.KeyCode == Enum.KeyCode.G then
        local res = toggleInvisibility(not invisEnabled)
        invisBtnRef.Text = "Invisible (G): " .. (res and "[ON]" or "[OFF]")
        invisBtnRef.BackgroundColor3 = res and Color3.fromRGB(0, 170, 127) or Color3.fromRGB(50, 50, 50)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.C then
        stopAiming()
    end
end)
