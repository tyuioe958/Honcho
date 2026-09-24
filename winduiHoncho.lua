-- ============================================================
--  WindUI + Honcho变形插件
--  插件作者MorthenHubber
--  UI 库: WindUI (Footagesus)
-- ============================================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "提示",
    Text = "已启动脚本",
    Duration = 2
})

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
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")

local rootWeld, headWeld
local enforceLoop, movementLoop, inputConnection
local animationController, animator
local idleAnimation, runAnimation, landingAnimation
local landingSound, impactSound
local ambienceSounds = {}
local footstepsSound
local currentAmbience, movementEnabled
local runTrack, idleTrack, landingTrack, lastMoveState

local Window = WindUI:CreateWindow({
    Title = "Honcho变形插件控制面板",
    Author = "tyuioe958制作_UI库:Windui_插件作者MorthenHubber",
    Icon = "user",
    Theme = "Dark",
    Size = UDim2.fromOffset(520, 420),
})

local MainTab = Window:Tab({ Title = "变形", Icon = "person-standing" })
local CameraTab = Window:Tab({ Title = "相机", Icon = "camera" })
local SoundTab = Window:Tab({ Title = "音效", Icon = "volume-2" })

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

    enforceLoop = runService.RenderStepped:Connect(function()
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

    inputConnection = userInputService.InputBegan:Connect(function(input, gameProcessed)
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

    movementLoop = runService.RenderStepped:Connect(function()
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

MainTab:Button({
    Title = "开始变形",
    Desc = "加载模型并进入变形状态",
    Callback = function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "提示",
    Text = "已开始变形可以去用其他功能了🤑",
    Duration = 1
})
        startMorph()
    end,
})

MainTab:Button({
    Title = "停止变形",
    Desc = "还原角色、相机与音效",
    Callback = function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "提示",
    Text = "开启变形如果你已开启变形可无视",
    Duration = 1
})
        stopMorph()
    end,
})

MainTab:Button({
    Title = "触发落地动作电脑按键(B)",
    Desc = "播放落地动画与音效",
    Callback = function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "提示",
    Text = "开启变形如果你已开启变形可无视",
    Duration = 1
})
        if _G._morphReplayLanding then
            _G._morphReplayLanding()
        end
    end,
})

CameraTab:Toggle({
    Title = "第三人称电脑按键(L)",
    Desc = "切换第一/第三人称视角",
    Default = false,
    Callback = function(state)
    game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "提示",
    Text = "开启变形如果你已开启变形可无视",
    Duration = 1
})
        isThirdPerson = state
    end,
})

SoundTab:Button({
    Title = "播放/停止 档案馆Honcho遭遇战音乐1电脑按键(Z)",
    Desc = "免费音乐🤔(可能需要开启变形)",
    Callback = function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "提示",
    Text = "开启变形如果你已开启变形可无视",
    Duration = 1
})
        if not ambienceSounds[1] then return end
        if currentAmbience == ambienceSounds[1] then
            ambienceSounds[1]:Stop()
            currentAmbience = nil
        else
            if currentAmbience then currentAmbience:Stop() end
            playSound(ambienceSounds[1])
            currentAmbience = ambienceSounds[1]
        end
    end,
})

SoundTab:Button({
    Title = "播放/停止 档案馆Honcho遭遇战音乐2电脑按键(X)",
    Desc = "免费音乐🤔(可能需要开启变形)",
    Callback = function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "提示",
    Text = "开启变形如果你已开启变形可无视",
    Duration = 1
})
        if not ambienceSounds[2] then return end
        if currentAmbience == ambienceSounds[2] then
            ambienceSounds[2]:Stop()
            currentAmbience = nil
        else
            if currentAmbience then currentAmbience:Stop() end
            playSound(ambienceSounds[2])
            currentAmbience = ambienceSounds[2]
        end
    end,
})

SoundTab:Button({
    Title = "播放/停止 档案馆Honcho遭遇战音乐3电脑按键(V)",
    Desc = "免费音乐🤔(可能需要开启变形)",
    Callback = function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "提示",
    Text = "开启变形如果你已开启变形可无视",
    Duration = 1
})
        if not ambienceSounds[3] then return end
        if currentAmbience == ambienceSounds[3] then
            ambienceSounds[3]:Stop()
            currentAmbience = nil
        else
            if currentAmbience then currentAmbience:Stop() end
            playSound(ambienceSounds[3])
            currentAmbience = ambienceSounds[3]
        end
    end,
})

Window:Notify({
    Title = "信用",
    Content = "由 MorthenHubber 制作，UI 由 WindUI 驱动",
    Duration = 6,
})