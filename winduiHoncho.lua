local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

if CoreGui:FindFirstChild("NokiaUI") then
    CoreGui.NokiaUI:Destroy()
end

local Config = {
    Background = Color3.fromRGB(240, 245, 255),
    Sidebar = Color3.fromRGB(245, 248, 255),
    Panel = Color3.fromRGB(255, 255, 255),
    Text = Color3.fromRGB(40, 40, 40),
    SubText = Color3.fromRGB(120, 120, 120),
    Accent = Color3.fromRGB(64, 140, 255),
    AccentLight = Color3.fromRGB(220, 235, 255),
    ToggleOff = Color3.fromRGB(200, 200, 200),
    Font = Enum.Font.GothamMedium,
    FontBold = Enum.Font.GothamBold
}

local MiniIconSize = 60

local AnimationPresets = {
    ButtonHover = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    ButtonClick = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    PageSwitch = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Indicator = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    SidebarToggle = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
}

local player = game.Players.LocalPlayer
local modelId = 104515922403348
local heightOffset = 3
local idleAnimationId = 101907348895136
local runAnimationId = 100466662502744
local landingAnimationId = 91194170893496
local landingSoundId = 82613796053949
local impactSoundId = 74149238738530
local ambienceSoundIds = {105438678078526, 92139743699536, 82618476532926}
local landingCooldown = 10
local toolGripOffset = CFrame.new(0, -0.4, 0) * CFrame.Angles(math.rad(180), 0, math.rad(90))
local isThirdPerson = false

local morph = nil
local originalCharacter = nil
local originalRootPart, originalHumanoid, originalHeadPart
local originalWalkSpeed, originalJumpPower, originalJumpHeight
local lastLandingTime = 0
local camera = workspace.CurrentCamera

local rootWeld, headWeld
local enforceLoop, movementLoop, inputConnection
local animationController, animator
local idleAnimation, runAnimation, landingAnimation
local landingSound, impactSound
local ambienceSounds = {}
local footstepsSound
local currentAmbience, movementEnabled
local runTrack, idleTrack, landingTrack, lastMoveState

local function loadModel()
    local objects = game:GetObjects("rbxassetid://" .. modelId)
    return objects[1]
end

local function createAnimation(animationId)
    local animation = Instance.new("Animation")
    animation.AnimationId = "rbxassetid://" .. animationId
    return animation
end

local function playAnimation(animationObject, looped)
    local track = animator:LoadAnimation(animationObject)
    if track then
        track.Looped = looped or false
        track:Play()
    end
    return track
end

local function createSound(soundId)
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://" .. soundId
    return sound
end

local function playSound(soundObject)
    if not soundObject then return end
    soundObject.Parent = morph or workspace
    soundObject:Play()
end

local function startMorph()
    if morph then return end

    originalCharacter = player.Character
    if not originalCharacter or not originalCharacter:FindFirstChild("HumanoidRootPart") then
        return
    end
    originalRootPart = originalCharacter:FindFirstChild("HumanoidRootPart")
    originalHumanoid = originalCharacter:FindFirstChildWhichIsA("Humanoid")
    originalHeadPart = originalCharacter:FindFirstChild("Head")
    if not originalRootPart or not originalHumanoid then return end

    originalWalkSpeed = originalHumanoid.WalkSpeed
    originalJumpPower = originalHumanoid.JumpPower
    originalJumpHeight = originalHumanoid.JumpHeight
    lastLandingTime = 0

    morph = loadModel()
    if not morph then return end

    local morphHumanoid = morph:FindFirstChildWhichIsA("Humanoid")
    if morphHumanoid then morphHumanoid:Destroy() end

    for _, part in ipairs(morph:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = false
            part.CanCollide = false
        end
    end

    local morphRootPart = morph:FindFirstChild("HumanoidRootPart", true) or morph:FindFirstChild("RootPart", true)
    if not morphRootPart then
        morphRootPart = Instance.new("Part")
        morphRootPart.Name = "HumanoidRootPart"
        morphRootPart.Size = Vector3.new(2, 1, 1)
        morphRootPart.Anchored = false
        morphRootPart.CanCollide = false
        morphRootPart.Parent = morph
    end
    morph.PrimaryPart = morphRootPart

    local morphHeadPart = morph:FindFirstChild("Head", true)
    if not morphHeadPart then
        morphHeadPart = Instance.new("Part")
        morphHeadPart.Name = "Head"
        morphHeadPart.Size = Vector3.new(1, 1, 1)
        morphHeadPart.Anchored = false
        morphHeadPart.CanCollide = false
        morphHeadPart.Parent = morph
    end

    morph.Parent = workspace

    for _, part in ipairs(originalCharacter:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = 1
            part.CanCollide = false
        end
    end

    rootWeld = Instance.new("Weld")
    rootWeld.Part0 = originalRootPart
    rootWeld.Part1 = morphRootPart
    rootWeld.C0 = CFrame.new(0, heightOffset, 0)
    rootWeld.Parent = originalRootPart

    headWeld = Instance.new("Weld")
    if originalHeadPart then
        headWeld.Part0 = originalHeadPart
    else
        headWeld.Part0 = originalRootPart
    end
    headWeld.Part1 = morphHeadPart
    local headWeldOffset = morphHeadPart.Position - (originalHeadPart and originalHeadPart.Position or originalRootPart.Position)
    headWeld.C0 = CFrame.new(headWeldOffset)
    headWeld.Parent = headWeld.Part0

    camera = workspace.CurrentCamera
    if not camera then return end
    camera.CameraType = Enum.CameraType.Scriptable

    animationController = morph:FindFirstChildWhichIsA("AnimationController") or morph:FindFirstChild("AnimationController", true)
    if not animationController then
        animationController = Instance.new("AnimationController", morph)
    end
    animator = morph:FindFirstChildWhichIsA("Animator") or (animationController and animationController:FindFirstChildWhichIsA("Animator"))
    if not animator then
        animator = Instance.new("Animator", animationController)
    end

    idleAnimation = createAnimation(idleAnimationId)
    runAnimation = createAnimation(runAnimationId)
    landingAnimation = createAnimation(landingAnimationId)

    landingSound = createSound(landingSoundId)
    impactSound = createSound(impactSoundId)

    ambienceSounds = {}
    for i, id in ipairs(ambienceSoundIds) do
        local sound = createSound(id)
        sound.Looped = true
        ambienceSounds[i] = sound
    end

    footstepsSound = nil
    for _, child in ipairs(morph:GetDescendants()) do
        if child:IsA("Sound") and child.Name == "Footsteps" then
            footstepsSound = child
            break
        end
    end

    currentAmbience = nil
    movementEnabled = false
    runTrack, idleTrack, landingTrack, lastMoveState = nil, nil, nil, nil

    enforceLoop = RunService.RenderStepped:Connect(function()
        if rootWeld and rootWeld.Parent then
            rootWeld.C0 = CFrame.new(0, heightOffset, 0)
        end

        if morphHeadPart and morphHeadPart:IsDescendantOf(workspace) then
            local lookVector = camera.CFrame.LookVector
            local upVector = camera.CFrame.UpVector
            local headPos = morphHeadPart.Position

            if isThirdPerson then
                local camPos = headPos - (lookVector * 12) + Vector3.new(0, 2, 0)
                camera.CFrame = CFrame.lookAt(camPos, headPos, upVector)
            else
                local offset = Vector3.new(0, 0.2, -0.5)
                local targetPosition = morphHeadPart.CFrame:PointToWorldSpace(offset)
                camera.CFrame = CFrame.lookAt(targetPosition, targetPosition + lookVector, upVector)
            end
        end

        local morphRightHand = morph:FindFirstChild("RightHand", true)
        if originalCharacter and morphRightHand then
            for _, tool in ipairs(originalCharacter:GetChildren()) do
                if tool:IsA("Tool") then
                    local handle = tool:FindFirstChild("Handle")
                    if handle then
                        local defaultGrip = handle:FindFirstChild("RightGrip")
                        if defaultGrip then
                            if defaultGrip:IsA("Motor6D") then
                                defaultGrip.Enabled = false
                            else
                                defaultGrip:Destroy()
                            end
                        end
                        local defaultLeftGrip = handle:FindFirstChild("LeftGrip")
                        if defaultLeftGrip then
                            if defaultLeftGrip:IsA("Motor6D") then
                                defaultLeftGrip.Enabled = false
                            else
                                defaultLeftGrip:Destroy()
                            end
                        end

                        local morphWeld = handle:FindFirstChild("MorphWeld")
                        if not morphWeld then
                            morphWeld = Instance.new("Weld")
                            morphWeld.Name = "MorphWeld"
                            morphWeld.Part0 = morphRightHand
                            morphWeld.Part1 = handle
                            morphWeld.C0 = toolGripOffset
                            morphWeld.Parent = handle
                        elseif morphWeld.Part0 ~= morphRightHand then
                            morphWeld.Part0 = morphRightHand
                        end
                    end
                end
            end
        end
    end)

    local function replayLanding()
        if tick() - lastLandingTime < landingCooldown then return end
        lastLandingTime = tick()

        if landingTrack then landingTrack:Stop() end
        landingTrack = playAnimation(landingAnimation, false)
        playSound(landingSound)
        playSound(impactSound)
        movementEnabled = false

        originalHumanoid.WalkSpeed = 0
        originalHumanoid.JumpPower = 0
        if originalHumanoid.JumpHeight then originalHumanoid.JumpHeight = 0 end

        if landingTrack then
            landingTrack.Stopped:Connect(function()
                originalHumanoid.WalkSpeed = originalWalkSpeed
                originalHumanoid.JumpPower = originalJumpPower
                if originalHumanoid.JumpHeight then originalHumanoid.JumpHeight = originalJumpHeight end
                movementEnabled = true
                if not runTrack or not runTrack.IsPlaying then
                    idleTrack = playAnimation(idleAnimation, true)
                end
            end)
        else
            originalHumanoid.WalkSpeed = originalWalkSpeed
            originalHumanoid.JumpPower = originalJumpPower
            if originalHumanoid.JumpHeight then originalHumanoid.JumpHeight = originalJumpHeight end
            movementEnabled = true
        end
    end

    inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            local key = input.KeyCode
            if key == Enum.KeyCode.B then
                replayLanding()
            elseif key == Enum.KeyCode.L then
                isThirdPerson = not isThirdPerson
            end
        end
    end)

    replayLanding()

    movementLoop = RunService.RenderStepped:Connect(function()
        if not movementEnabled then return end
        local moveDirection = originalHumanoid.MoveDirection
        if not moveDirection then return end
        local moving = moveDirection.Magnitude > 0.1

        if moving then
            if lastMoveState ~= "run" then
                if idleTrack then idleTrack:Stop() end
                runTrack = playAnimation(runAnimation, true)
                lastMoveState = "run"
            end
            if footstepsSound and not footstepsSound.IsPlaying then
                footstepsSound:Play()
            end
        else
            if lastMoveState ~= "idle" then
                if runTrack then runTrack:Stop() end
                idleTrack = playAnimation(idleAnimation, true)
                lastMoveState = "idle"
            end
            if footstepsSound and footstepsSound.IsPlaying then
                footstepsSound:Stop()
            end
        end
    end)

    _G._morphReplayLanding = replayLanding
end

local function stopMorph()
    if inputConnection then inputConnection:Disconnect() inputConnection = nil end
    if enforceLoop then enforceLoop:Disconnect() enforceLoop = nil end
    if movementLoop then movementLoop:Disconnect() movementLoop = nil end
    if currentAmbience then currentAmbience:Stop() end
    if landingTrack then landingTrack:Stop() end
    if runTrack then runTrack:Stop() end
    if idleTrack then idleTrack:Stop() end
    if footstepsSound then footstepsSound:Stop() end

    if camera then camera.CameraType = Enum.CameraType.Custom end

    if originalCharacter then
        for _, part in ipairs(originalCharacter:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = 0
                part.CanCollide = true
            end
        end
    end

    if morph then morph:Destroy() morph = nil end
    _G._morphReplayLanding = nil
end

if _G.morphCleanup then pcall(_G.morphCleanup) end
_G.morphCleanup = stopMorph

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local key = input.KeyCode
    if key == Enum.KeyCode.B then
        if _G._morphReplayLanding then _G._morphReplayLanding() end
    elseif key == Enum.KeyCode.L then
        isThirdPerson = not isThirdPerson
    elseif key == Enum.KeyCode.Z then
        if not ambienceSounds[1] then return end
        if currentAmbience == ambienceSounds[1] then
            ambienceSounds[1]:Stop() currentAmbience = nil
        else
            if currentAmbience then currentAmbience:Stop() end
            playSound(ambienceSounds[1]) currentAmbience = ambienceSounds[1]
        end
    elseif key == Enum.KeyCode.X then
        if not ambienceSounds[2] then return end
        if currentAmbience == ambienceSounds[2] then
            ambienceSounds[2]:Stop() currentAmbience = nil
        else
            if currentAmbience then currentAmbience:Stop() end
            playSound(ambienceSounds[2]) currentAmbience = ambienceSounds[2]
        end
    elseif key == Enum.KeyCode.V then
        if not ambienceSounds[3] then return end
        if currentAmbience == ambienceSounds[3] then
            ambienceSounds[3]:Stop() currentAmbience = nil
        else
            if currentAmbience then currentAmbience:Stop() end
            playSound(ambienceSounds[3]) currentAmbience = ambienceSounds[3]
        end
    end
end)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NokiaUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 700, 0, 480)
MainFrame.Position = UDim2.new(0.5, -350, 0.5, -240)
MainFrame.BackgroundColor3 = Config.Background
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui
local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local UIScale = Instance.new("UIScale")
UIScale.Scale = 1
UIScale.Parent = MainFrame

local dragging, dragInput, dragStart, startPos
local isSliderDragging = false
MainFrame.InputBegan:Connect(function(input)
    if isSliderDragging then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 50)
TopBar.BackgroundTransparency = 1
TopBar.Parent = MainFrame

local CollapseBtn = Instance.new("TextButton")
CollapseBtn.Text = "三"
CollapseBtn.Font = Enum.Font.GothamBold
CollapseBtn.TextSize = 20
CollapseBtn.TextColor3 = Config.Text
CollapseBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
CollapseBtn.AutoButtonColor = false
CollapseBtn.Size = UDim2.new(0, 30, 0, 30)
CollapseBtn.Position = UDim2.new(0, 20, 0, 10)
CollapseBtn.Parent = TopBar
local CollapseCorner = Instance.new("UICorner")
CollapseCorner.CornerRadius = UDim.new(1, 0)
CollapseCorner.Parent = CollapseBtn
local CollapseStroke = Instance.new("UIStroke")
CollapseStroke.Color = Color3.fromRGB(220, 230, 245)
CollapseStroke.Thickness = 1.5
CollapseStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
CollapseStroke.Parent = CollapseBtn

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Text = "切换"
ToggleBtn.Font = Config.FontBold
ToggleBtn.TextSize = 13
ToggleBtn.TextColor3 = Config.Text
ToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.AutoButtonColor = false
ToggleBtn.Size = UDim2.new(0, 50, 0, 26)
ToggleBtn.Position = UDim2.new(0, 55, 0, 12)
ToggleBtn.Parent = TopBar
local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 8)
ToggleCorner.Parent = ToggleBtn
local ToggleStroke = Instance.new("UIStroke")
ToggleStroke.Color = Color3.fromRGB(220, 230, 245)
ToggleStroke.Thickness = 1.5
ToggleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
ToggleStroke.Parent = ToggleBtn

local function addHoverEffect(btn)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(240, 248, 255)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
    end)
end
addHoverEffect(CollapseBtn)
addHoverEffect(ToggleBtn)

local HomeBtn = Instance.new("TextLabel")
HomeBtn.Text = "Home"
HomeBtn.Font = Config.FontBold
HomeBtn.TextSize = 25
HomeBtn.TextColor3 = Config.Text
HomeBtn.BackgroundTransparency = 1
HomeBtn.Size = UDim2.new(0, 100, 0, 30)
HomeBtn.Position = UDim2.new(0, 120, 0, 10)
HomeBtn.TextXAlignment = Enum.TextXAlignment.Left
HomeBtn.TextYAlignment = Enum.TextYAlignment.Center
HomeBtn.Parent = TopBar

local SearchBar = Instance.new("TextBox")
SearchBar.PlaceholderText = "Search..."
SearchBar.Text = ""
SearchBar.Font = Config.Font
SearchBar.TextSize = 14
SearchBar.TextColor3 = Config.Text
SearchBar.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
SearchBar.BackgroundColor3 = Color3.fromRGB(226, 241, 253)
SearchBar.Size = UDim2.new(0, 300, 0, 30)
SearchBar.Position = UDim2.new(0, 220, 0, 10)
SearchBar.TextXAlignment = Enum.TextXAlignment.Left
SearchBar.TextYAlignment = Enum.TextYAlignment.Center
SearchBar.ClearTextOnFocus = false
SearchBar.Parent = TopBar
local SearchCorner = Instance.new("UICorner")
SearchCorner.CornerRadius = UDim.new(0, 6)
SearchCorner.Parent = SearchBar
local SearchPadding = Instance.new("UIPadding")
SearchPadding.PaddingLeft = UDim.new(0, 10)
SearchPadding.PaddingRight = UDim.new(0, 10)
SearchPadding.Parent = SearchBar

local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 200, 1, -60)
Sidebar.Position = UDim2.new(0, 10, 0, 55)
Sidebar.BackgroundColor3 = Config.Sidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame
local SidebarCorner = Instance.new("UICorner")
SidebarCorner.CornerRadius = UDim.new(0, 10)
SidebarCorner.Parent = Sidebar

local LogoTitle = Instance.new("TextLabel")
LogoTitle.Text = "Honcho"
LogoTitle.Font = Enum.Font.GothamBlack
LogoTitle.TextSize = 24
LogoTitle.TextColor3 = Config.Text
LogoTitle.BackgroundTransparency = 1
LogoTitle.Size = UDim2.new(1, -20, 0, 40)
LogoTitle.Position = UDim2.new(0, 10, 0, 10)
LogoTitle.TextXAlignment = Enum.TextXAlignment.Left
LogoTitle.Parent = Sidebar

local TabScroll = Instance.new("ScrollingFrame")
TabScroll.Name = "TabScroll"
TabScroll.Size = UDim2.new(1, 0, 1, -70)
TabScroll.Position = UDim2.new(0, 0, 0, 60)
TabScroll.BackgroundTransparency = 1
TabScroll.BorderSizePixel = 0
TabScroll.ScrollBarThickness = 3
TabScroll.ScrollBarImageColor3 = Config.Accent
TabScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
TabScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
TabScroll.ScrollingDirection = Enum.ScrollingDirection.Y
TabScroll.ElasticBehavior = Enum.ElasticBehavior.Always
TabScroll.Parent = Sidebar

local TabContainer = Instance.new("Frame")
TabContainer.Name = "TabContainer"
TabContainer.Size = UDim2.new(1, 0, 0, 0)
TabContainer.AutomaticSize = Enum.AutomaticSize.Y
TabContainer.BackgroundTransparency = 1
TabContainer.Parent = TabScroll
local TabLayout = Instance.new("UIListLayout")
TabLayout.Padding = UDim.new(0, 8)
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabLayout.Parent = TabContainer
local TabPadding = Instance.new("UIPadding")
TabPadding.PaddingTop = UDim.new(0, 5)
TabPadding.PaddingBottom = UDim.new(0, 15)
TabPadding.Parent = TabContainer

local PageContainer = Instance.new("Frame")
PageContainer.Size = UDim2.new(1, -230, 1, -75)
PageContainer.Position = UDim2.new(0, 220, 0, 60)
PageContainer.BackgroundTransparency = 1
PageContainer.Parent = MainFrame

local Pages = {}
local CurrentPage = "Morph"

local function createPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name .. "Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = Config.Accent
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.ScrollingDirection = Enum.ScrollingDirection.Y
    page.Visible = false
    page.Parent = PageContainer

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 15)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 5)
    pad.PaddingBottom = UDim.new(0, 15)
    pad.PaddingLeft = UDim.new(0, 5)
    pad.PaddingRight = UDim.new(0, 15)
    pad.Parent = page

    Pages[name] = page
    return page
end

local function clearPageContent(page)
    for _, child in pairs(page:GetChildren()) do
        if child:IsA("Frame") then child.Visible = false end
    end
end

local function showPageContent(page)
    for _, child in pairs(page:GetChildren()) do
        if child:IsA("Frame") then child.Visible = true end
    end
end

local function switchPage(pageName)
    CurrentPage = pageName
    for name, page in pairs(Pages) do
        if name == pageName then
            page.Visible = true
            showPageContent(page)
        else
            page.Visible = false
            clearPageContent(page)
        end
    end
end

local function createAutoCard(parent, name)
    local card = Instance.new("Frame")
    card.Name = name
    card.Size = UDim2.new(1, -10, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = Config.Panel
    card.BorderSizePixel = 0
    card.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = card
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 15)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = card
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 15)
    padding.PaddingBottom = UDim.new(0, 15)
    padding.PaddingLeft = UDim.new(0, 20)
    padding.PaddingRight = UDim.new(0, 20)
    padding.Parent = card
    return card
end

local function createRow(parent, titleText, subText, hasToggle, toggleState, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 0)
    row.AutomaticSize = Enum.AutomaticSize.Y
    row.BackgroundTransparency = 1
    row.Parent = parent
    local rowLayout = Instance.new("UIListLayout")
    rowLayout.Padding = UDim.new(0, 2)
    rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rowLayout.Parent = row

    local title = Instance.new("TextLabel")
    title.Text = titleText
    title.Font = Config.FontBold
    title.TextSize = 16
    title.TextColor3 = Config.Text
    title.Size = UDim2.new(1, -60, 0, 20)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.BackgroundTransparency = 1
    title.LayoutOrder = 1
    title.Parent = row

    if subText and subText ~= "" then
        local sub = Instance.new("TextLabel")
        sub.Text = subText
        sub.Font = Config.Font
        sub.TextSize = 12
        sub.TextColor3 = Config.SubText
        sub.Size = UDim2.new(1, -60, 0, 16)
        sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.BackgroundTransparency = 1
        sub.LayoutOrder = 2
        sub.Parent = row
    end

    if hasToggle then
        local toggleBg = Instance.new("Frame")
        toggleBg.Size = UDim2.new(0, 40, 0, 22)
        toggleBg.Position = UDim2.new(1, -40, 0, 2)
        toggleBg.BackgroundColor3 = toggleState and Config.Accent or Config.ToggleOff
        toggleBg.Parent = row
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = toggleBg
        local circle = Instance.new("Frame")
        circle.Size = UDim2.new(0, 18, 0, 18)
        circle.Position = toggleState and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        circle.BackgroundColor3 = Color3.new(1,1,1)
        circle.Parent = toggleBg
        local circleCorner = Instance.new("UICorner")
        circleCorner.CornerRadius = UDim.new(1, 0)
        circleCorner.Parent = circle
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = toggleBg
        local state = toggleState
        btn.MouseButton1Click:Connect(function()
            state = not state
            TweenService:Create(toggleBg, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = state and Config.Accent or Config.ToggleOff}):Play()
            TweenService:Create(circle, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
            }):Play()
            if callback then callback(state) end
        end)
    end
    return row
end

local function createButton(parent, titleText, subText, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 0)
    row.AutomaticSize = Enum.AutomaticSize.Y
    row.BackgroundTransparency = 1
    row.Parent = parent

    local rowLayout = Instance.new("UIListLayout")
    rowLayout.Padding = UDim.new(0, 2)
    rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rowLayout.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = Config.AccentLight
    btn.AutoButtonColor = false
    btn.Text = titleText
    btn.Font = Config.FontBold
    btn.TextSize = 14
    btn.TextColor3 = Config.Text
    btn.LayoutOrder = 1
    btn.Parent = row
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    if subText and subText ~= "" then
        local sub = Instance.new("TextLabel")
        sub.Text = subText
        sub.Font = Config.Font
        sub.TextSize = 12
        sub.TextColor3 = Config.SubText
        sub.Size = UDim2.new(1, 0, 0, 16)
        sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.BackgroundTransparency = 1
        sub.LayoutOrder = 2
        sub.Parent = row
    end

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, AnimationPresets.ButtonHover, {BackgroundColor3 = Config.Accent, TextColor3 = Color3.new(1,1,1)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, AnimationPresets.ButtonHover, {BackgroundColor3 = Config.AccentLight, TextColor3 = Config.Text}):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)
    return row
end
local ActiveSlider = nil

local function createSlider(parent, labelText, minValue, maxValue, currentValue, suffix, callback)
    local sliderRow = Instance.new("Frame")
    sliderRow.Size = UDim2.new(1, 0, 0, 0)
    sliderRow.AutomaticSize = Enum.AutomaticSize.Y
    sliderRow.BackgroundTransparency = 1
    sliderRow.Parent = parent
    local sliderLayout = Instance.new("UIListLayout")
    sliderLayout.Padding = UDim.new(0, 4)
    sliderLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sliderLayout.Parent = sliderRow
    local headerRow = Instance.new("Frame")
    headerRow.Size = UDim2.new(1, 0, 0, 20)
    headerRow.BackgroundTransparency = 1
    headerRow.LayoutOrder = 1
    headerRow.Parent = sliderRow
    local titleLbl = Instance.new("TextLabel")
    titleLbl.Text = labelText
    titleLbl.Font = Config.Font
    titleLbl.TextSize = 14
    titleLbl.TextColor3 = Config.SubText
    titleLbl.Size = UDim2.new(0.5, 0, 1, 0)
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.BackgroundTransparency = 1
    titleLbl.Parent = headerRow
    local valueLbl = Instance.new("TextLabel")
    valueLbl.Text = tostring(currentValue) .. suffix
    valueLbl.Font = Config.FontBold
    valueLbl.TextSize = 13
    valueLbl.TextColor3 = Config.SubText
    valueLbl.Size = UDim2.new(0.5, 0, 1, 0)
    valueLbl.Position = UDim2.new(0.5, 0, 0, 0)
    valueLbl.TextXAlignment = Enum.TextXAlignment.Right
    valueLbl.BackgroundTransparency = 1
    valueLbl.Parent = headerRow
    local trackBg = Instance.new("Frame")
    trackBg.Size = UDim2.new(1, 0, 0, 6)
    trackBg.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
    trackBg.BorderSizePixel = 0
    trackBg.LayoutOrder = 2
    trackBg.Parent = sliderRow
    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = trackBg
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((currentValue - minValue) / (maxValue - minValue), 0, 1, 0)
    fill.BackgroundColor3 = Config.Accent
    fill.BorderSizePixel = 0
    fill.Parent = trackBg
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new((currentValue - minValue) / (maxValue - minValue), 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.Parent = trackBg
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob
    local knobStroke = Instance.new("UIStroke")
    knobStroke.Color = Color3.fromRGB(180, 180, 180)
    knobStroke.Thickness = 1
    knobStroke.Parent = knob
    local hitbox = Instance.new("TextButton")
    hitbox.Size = UDim2.new(1, 0, 3, 0)
    hitbox.Position = UDim2.new(0, 0, -1, 0)
    hitbox.BackgroundTransparency = 1
    hitbox.Text = ""
    hitbox.Parent = trackBg
    local isDragging = false
    local currentVal = currentValue
    local lockedTrackPos = 0
    local lockedTrackSize = 0
    local function updateSlider(input)
        local mouseX = input.Position.X
        local percent = math.clamp((mouseX - lockedTrackPos) / lockedTrackSize, 0, 1)
        fill.Size = UDim2.new(percent, 0, 1, 0)
        knob.Position = UDim2.new(percent, 0, 0.5, 0)
        currentVal = minValue + (maxValue - minValue) * percent
        currentVal = math.floor(currentVal * 100 + 0.5) / 100
        valueLbl.Text = tostring(currentVal) .. suffix
        if callback then callback(currentVal) end
    end
    hitbox.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if ActiveSlider ~= nil and ActiveSlider ~= sliderRow then return end
            isDragging = true
            ActiveSlider = sliderRow
            isSliderDragging = true
            dragging = false
            lockedTrackPos = trackBg.AbsolutePosition.X
            lockedTrackSize = trackBg.AbsoluteSize.X
            updateSlider(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if isDragging and ActiveSlider == sliderRow and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if isDragging and ActiveSlider == sliderRow then
                isDragging = false
                ActiveSlider = nil
                isSliderDragging = false
            end
        end
    end)
    return sliderRow
end

local function buildMorphContent(page)
    local Card1 = createAutoCard(page, "变形控制")
    createButton(Card1, "开始变形", "加载模型并进入变形状态", function()
        StarterGui:SetCore("SendNotification", {Title = "提示", Text = "已开始变形", Duration = 1})
        startMorph()
    end)
    createButton(Card1, "停止变形", "还原角色、相机与音效", function()
        StarterGui:SetCore("SendNotification", {Title = "提示", Text = "已停止变形", Duration = 1})
        stopMorph()
    end)
    createButton(Card1, "触发落地动作 (B)", "播放落地动画与音效", function()
        if _G._morphReplayLanding then _G._morphReplayLanding() end
    end)
end

local function buildCameraContent(page)
    local Card = createAutoCard(page, "相机设置")
    createRow(Card, "第三人称 (L)", "切换第一/第三人称视角", true, false, function(state)
        isThirdPerson = state
    end)
end

local function buildSoundContent(page)
    local Card = createAutoCard(page, "遭遇战音乐")
    createButton(Card, "音乐 1 (Z)", "档案馆 Honcho 遭遇战音乐 1", function()
        if not ambienceSounds[1] then return end
        if currentAmbience == ambienceSounds[1] then
            ambienceSounds[1]:Stop() currentAmbience = nil
        else
            if currentAmbience then currentAmbience:Stop() end
            playSound(ambienceSounds[1]) currentAmbience = ambienceSounds[1]
        end
    end)
    createButton(Card, "音乐 2 (X)", "档案馆 Honcho 遭遇战音乐 2", function()
        if not ambienceSounds[2] then return end
        if currentAmbience == ambienceSounds[2] then
            ambienceSounds[2]:Stop() currentAmbience = nil
        else
            if currentAmbience then currentAmbience:Stop() end
            playSound(ambienceSounds[2]) currentAmbience = ambienceSounds[2]
        end
    end)
    createButton(Card, "音乐 3 (V)", "档案馆 Honcho 遭遇战音乐 3", function()
        if not ambienceSounds[3] then return end
        if currentAmbience == ambienceSounds[3] then
            ambienceSounds[3]:Stop() currentAmbience = nil
        else
            if currentAmbience then currentAmbience:Stop() end
            playSound(ambienceSounds[3]) currentAmbience = ambienceSounds[3]
        end
    end)
end

local function buildMiscContent(page)
    local SettingsCard = createAutoCard(page, "设置")
    createSlider(SettingsCard, "UI 缩放", 0.5, 1.5, 1.0, "x", function(value) UIScale.Scale = value end)
    createSlider(SettingsCard, "UI 透明度", 0.5, 1.0, 1.0, "", function(value) MainFrame.BackgroundTransparency = 1 - value end)
    createSlider(SettingsCard, "灯泡大小", 30, 100, MiniIconSize, "px", function(value)
        MiniIconSize = value
        MiniIcon.Size = UDim2.new(0, MiniIconSize, 0, MiniIconSize)
        if MiniInfo.Visible then
            MiniInfo.Position = UDim2.new(0, MiniIcon.Position.X.Offset + MiniIconSize + 8, 0, MiniIcon.Position.Y.Offset)
        end
    end)
end

local MorphPage = createPage("变形")
buildMorphContent(MorphPage)
local CameraPage = createPage("相机")
buildCameraContent(CameraPage)
local SoundPage = createPage("音乐")
buildSoundContent(SoundPage)
local MiscPage = createPage("设置")
buildMiscContent(MiscPage)
local AllPage = createPage("All")
buildMorphContent(AllPage)
buildCameraContent(AllPage)
buildSoundContent(AllPage)
buildMiscContent(AllPage)

local SidebarCollapsed = false
local PageBeforeCollapse = "变形"

local function toggleSidebar()
    SidebarCollapsed = not SidebarCollapsed
    TweenService:Create(CollapseBtn, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Rotation = SidebarCollapsed and 90 or 0
    }):Play()

    if SidebarCollapsed then
        PageBeforeCollapse = CurrentPage
        Sidebar.Visible = false
        TweenService:Create(PageContainer, AnimationPresets.SidebarToggle, {
            Size = UDim2.new(1, -30, 1, -75),
            Position = UDim2.new(0, 15, 0, 60)
        }):Play()
        switchPage("All")
    else
        Sidebar.Visible = true
        TweenService:Create(PageContainer, AnimationPresets.SidebarToggle, {
            Size = UDim2.new(1, -230, 1, -75),
            Position = UDim2.new(0, 220, 0, 60)
        }):Play()
        if PageBeforeCollapse and Pages[PageBeforeCollapse] then
            switchPage(PageBeforeCollapse)
        else
            switchPage("Morph")
        end
    end
end

CollapseBtn.MouseButton1Click:Connect(toggleSidebar)

local isMinimized = false
local savedSize = UDim2.new(0, 700, 0, 480)
local savedPos = UDim2.new(0.5, -350, 0.5, -240)
local savedUIScale = 1
local miniPosBeforeFly = UDim2.new(0, 20, 0, 20)

local MiniIcon = Instance.new("TextButton")
MiniIcon.Text = "💡"
MiniIcon.Font = Enum.Font.GothamBold
MiniIcon.TextSize = 28
MiniIcon.TextColor3 = Color3.new(1, 1, 1)
MiniIcon.BackgroundColor3 = Config.Accent
MiniIcon.Size = UDim2.new(0, MiniIconSize, 0, MiniIconSize)
MiniIcon.Position = UDim2.new(0, 20, 0, 20)
MiniIcon.Visible = false
MiniIcon.AutoButtonColor = false
MiniIcon.Parent = ScreenGui
local MiniCorner = Instance.new("UICorner")
MiniCorner.CornerRadius = UDim.new(0.2, 0)
MiniCorner.Parent = MiniIcon

local MiniInfo = Instance.new("Frame")
MiniInfo.Name = "MiniInfo"
MiniInfo.BackgroundTransparency = 1
MiniInfo.Size = UDim2.new(0, 200, 0, 50)
MiniInfo.Position = UDim2.new(0, 20 + MiniIconSize + 8, 0, 20)
MiniInfo.Visible = false
MiniInfo.Parent = ScreenGui

local MiniTimeLbl = Instance.new("TextLabel")
MiniTimeLbl.Name = "MiniTime"
MiniTimeLbl.Text = os.date("%H:%M:%S")
MiniTimeLbl.Font = Config.FontBold
MiniTimeLbl.TextSize = 14
MiniTimeLbl.TextColor3 = Config.Accent
MiniTimeLbl.BackgroundTransparency = 1
MiniTimeLbl.Size = UDim2.new(1, 0, 0, 20)
MiniTimeLbl.TextXAlignment = Enum.TextXAlignment.Left
MiniTimeLbl.Parent = MiniInfo

local MiniNameLbl = Instance.new("TextLabel")
MiniNameLbl.Name = "HI_MiniName"
MiniNameLbl.Text = player.DisplayName or player.Name
MiniNameLbl.Font = Config.Font
MiniNameLbl.TextSize = 14
MiniNameLbl.TextColor3 = Config.SubText
MiniNameLbl.BackgroundTransparency = 1
MiniNameLbl.Size = UDim2.new(1, 0, 0, 16)
MiniNameLbl.Position = UDim2.new(0, 2, 0, 22)
MiniNameLbl.TextXAlignment = Enum.TextXAlignment.Left
MiniNameLbl.Parent = MiniInfo

task.spawn(function()
    while task.wait(1) do
        MiniTimeLbl.Text = os.date("%H:%M:%S")
    end
end)

local miniDragging = false
local miniDragStart, miniStartPos
local savedMiniPos = UDim2.new(0, 20, 0, 20)
MiniIcon.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        miniDragging = true
        miniDragStart = input.Position
        miniStartPos = MiniIcon.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then miniDragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if miniDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - miniDragStart
        MiniIcon.Position = UDim2.new(miniStartPos.X.Scale, miniStartPos.X.Offset + delta.X, miniStartPos.Y.Scale, miniStartPos.Y.Offset + delta.Y)
        savedMiniPos = MiniIcon.Position
        MiniInfo.Position = UDim2.new(0, MiniIcon.Position.X.Offset + MiniIconSize + 8, 0, MiniIcon.Position.Y.Offset)
    end
end)

local function toggleMinimize()
    isMinimized = not isMinimized
    if isMinimized then
        savedSize = MainFrame.Size
        savedPos = MainFrame.Position
        savedUIScale = UIScale.Scale
        miniPosBeforeFly = MiniIcon.Position
        MiniIcon.Position = savedMiniPos or UDim2.new(0, 20, 0, 20)

        TweenService:Create(UIScale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.1 }):Play()
        task.delay(0.25, function()
            MainFrame.Visible = false
            UIScale.Scale = savedUIScale
            MiniIcon.Visible = true
            MiniIcon.Size = UDim2.new(0, 0, 0, 0)
            TweenService:Create(MiniIcon, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(0, MiniIconSize, 0, MiniIconSize) }):Play()
            MiniInfo.Position = UDim2.new(0, MiniIcon.Position.X.Offset + MiniIconSize + 8, 0, MiniIcon.Position.Y.Offset)
            MiniInfo.Visible = true
        end)
    else
        TweenService:Create(MiniIcon, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(savedPos.X.Scale, savedPos.X.Offset, savedPos.Y.Scale, savedPos.Y.Offset),
            BackgroundTransparency = 1,
            TextTransparency = 1
        }):Play()
        MiniInfo.Visible = false
        task.delay(0.3, function()
            MiniIcon.Visible = false
            MiniIcon.Size = UDim2.new(0, MiniIconSize, 0, MiniIconSize)
            MiniIcon.Position = miniPosBeforeFly
            MiniIcon.BackgroundTransparency = 0
            MiniIcon.TextTransparency = 0
            MiniInfo.Position = UDim2.new(0, MiniIcon.Position.X.Offset + MiniIconSize + 8, 0, MiniIcon.Position.Y.Offset)
        end)

        MainFrame.Visible = true
        MainFrame.Size = savedSize
        MainFrame.Position = savedPos
        UIScale.Scale = 0.1
        TweenService:Create(UIScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = savedUIScale }):Play()
    end
end

ToggleBtn.MouseButton1Click:Connect(toggleMinimize)
MiniIcon.MouseButton1Click:Connect(toggleMinimize)

local isMaximized = false
local normalSize = UDim2.new(0, 700, 0, 480)
local normalPos = UDim2.new(0.5, -350, 0.5, -240)
local maximizedSize = UDim2.new(0, 1100, 0, 700)
local maximizedPos = UDim2.new(0.5, -550, 0.5, -350)

local lastClickTime = 0
HomeBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local now = tick()
        if now - lastClickTime < 0.3 then
            isMaximized = not isMaximized
            if isMaximized then
                TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = maximizedSize, Position = maximizedPos }):Play()
            else
                TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = normalSize, Position = normalPos }):Play()
            end
        end
        lastClickTime = now
    end
end)

local TabButtons = {}
local function createTabButton(name, icon, isActive)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 180, 0, 45)
    btn.BackgroundColor3 = isActive and Config.AccentLight or Color3.new(1,1,1)
    btn.BackgroundTransparency = isActive and 0 or 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = TabContainer
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 4, 0, 20)
    indicator.Position = UDim2.new(0, 0, 0.5, -10)
    indicator.BackgroundColor3 = Config.Accent
    indicator.BorderSizePixel = 0
    indicator.Visible = isActive
    indicator.Parent = btn
    local indCorner = Instance.new("UICorner")
    indCorner.CornerRadius = UDim.new(1, 0)
    indCorner.Parent = indicator

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Text = icon
    iconLbl.Size = UDim2.new(0, 30, 0, 30)
    iconLbl.Position = UDim2.new(0, 15, 0.5, -15)
    iconLbl.BackgroundTransparency = 1
    iconLbl.TextSize = 18
    iconLbl.Parent = btn

    local txtLbl = Instance.new("TextLabel")
    txtLbl.Text = name
    txtLbl.Font = Config.FontBold
    txtLbl.TextSize = 14
    txtLbl.TextColor3 = isActive and Config.Accent or Config.Text
    txtLbl.Size = UDim2.new(0, 100, 1, 0)
    txtLbl.Position = UDim2.new(0, 50, 0, 0)
    txtLbl.TextXAlignment = Enum.TextXAlignment.Left
    txtLbl.BackgroundTransparency = 1
    txtLbl.Parent = btn

    local hoverLayer = Instance.new("Frame")
    hoverLayer.Size = UDim2.new(1, 0, 1, 0)
    hoverLayer.BackgroundColor3 = Config.AccentLight
    hoverLayer.BackgroundTransparency = 1
    hoverLayer.BorderSizePixel = 0
    hoverLayer.ZIndex = 0
    hoverLayer.Parent = btn
    local hlCorner = Instance.new("UICorner")
    hlCorner.CornerRadius = UDim.new(0, 8)
    hlCorner.Parent = hoverLayer

    TabButtons[name] = {Button = btn, Indicator = indicator, Label = txtLbl, Icon = iconLbl, Hover = hoverLayer, Active = isActive}

    btn.MouseEnter:Connect(function()
        if not TabButtons[name].Active then
            TweenService:Create(hoverLayer, AnimationPresets.ButtonHover, {BackgroundTransparency = 0.5}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(hoverLayer, AnimationPresets.ButtonHover, {BackgroundTransparency = 1}):Play()
        TweenService:Create(btn, AnimationPresets.ButtonHover, {Size = UDim2.new(0, 180, 0, 45)}):Play()
    end)
    btn.MouseButton1Down:Connect(function()
        TweenService:Create(btn, AnimationPresets.ButtonClick, {Size = UDim2.new(0, 170, 0, 42)}):Play()
    end)
    btn.MouseButton1Up:Connect(function()
        TweenService:Create(btn, AnimationPresets.ButtonHover, {Size = UDim2.new(0, 180, 0, 45)}):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        if SidebarCollapsed then toggleSidebar() end
        for n, data in pairs(TabButtons) do
            data.Active = false
            TweenService:Create(data.Button, AnimationPresets.ButtonHover, {BackgroundTransparency = 1, BackgroundColor3 = Color3.new(1,1,1)}):Play()
            TweenService:Create(data.Label, AnimationPresets.ButtonHover, {TextColor3 = Config.Text}):Play()
            TweenService:Create(data.Icon, AnimationPresets.ButtonHover, {TextColor3 = Config.Text}):Play()
            if data.Indicator.Visible then
                TweenService:Create(data.Indicator, AnimationPresets.ButtonClick, {Size = UDim2.new(0, 0, 0, 20)}):Play()
                task.delay(0.15, function()
                    data.Indicator.Visible = false
                    data.Indicator.Size = UDim2.new(0, 4, 0, 20)
                end)
            end
        end
        TabButtons[name].Active = true
        TweenService:Create(btn, AnimationPresets.ButtonHover, {BackgroundTransparency = 0, BackgroundColor3 = Config.AccentLight}):Play()
        TweenService:Create(txtLbl, AnimationPresets.ButtonHover, {TextColor3 = Config.Accent}):Play()
        TweenService:Create(iconLbl, AnimationPresets.ButtonHover, {TextColor3 = Config.Accent}):Play()
        indicator.Visible = true
        indicator.Size = UDim2.new(0, 0, 0, 20)
        TweenService:Create(indicator, AnimationPresets.Indicator, {Size = UDim2.new(0, 4, 0, 20)}):Play()
        switchPage(name)
    end)
end

createTabButton("变形", "🎭", true)
createTabButton("相机", "📷", false)
createTabButton("音乐", "🔊", false)
createTabButton("设置", "⚙️", false)

switchPage("Morph")
for name, page in pairs(Pages) do
    if name ~= "Morph" then clearPageContent(page) end
end

SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
    local txt = SearchBar.Text:lower()
    if txt == "" then
        for name, page in pairs(Pages) do
            if name == CurrentPage then
                page.Visible = true
                showPageContent(page)
            else
                page.Visible = false
                clearPageContent(page)
            end
        end
        return
    end
    for name, page in pairs(Pages) do
        local pageMatch = false
        for _, c in pairs(page:GetChildren()) do
            if c:IsA("Frame") then
                local m = string.find(c.Name:lower(), txt)
                c.Visible = m and true or false
                if m then pageMatch = true end
            end
        end
        page.Visible = pageMatch
    end
end)

StarterGui:SetCore("SendNotification", {
    Title = "提示",
    Text = "已启动脚本新ui制作:tyuioe958",
    Duration = 20
})
