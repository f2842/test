local runUnlockAllCosmetics
if getgenv and type(getgenv) == "function" and getgenv().meow_cleanup then pcall(function() getgenv().meow_cleanup() end) end

local Players = cloneref and cloneref(game:GetService("Players")) or game:GetService("Players")
local RunService = cloneref and cloneref(game:GetService("RunService")) or game:GetService("RunService")
local Workspace = cloneref and cloneref(game:GetService("Workspace")) or game:GetService("Workspace")
local UserInputService = cloneref and cloneref(game:GetService("UserInputService")) or game:GetService("UserInputService")
local TweenService = cloneref and cloneref(game:GetService("TweenService")) or game:GetService("TweenService")
local SoundService = cloneref and cloneref(game:GetService("SoundService")) or game:GetService("SoundService")
local Lighting = cloneref and cloneref(game:GetService("Lighting")) or game:GetService("Lighting")
local TeleportService = cloneref and cloneref(game:GetService("TeleportService")) or game:GetService("TeleportService")
local HttpService = cloneref and cloneref(game:GetService("HttpService")) or game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

getgenv().meow_flags = getgenv().meow_flags or {}
local flags = getgenv().meow_flags

local meowState = {
    Destroyed = false,
    PriorityList = {},
    CustomSoundCache = {},
    ModDetectorChecked = {},
    CurrentTarget = nil,
    LastTargetPlayer = nil,
    LastMeleeAttack = 0,
    KnifeAt = 0,
    KnifeBurst = 0,
    IndicatorLabel = nil,
    IndicatorGui = nil,
    IndicatorFrame = nil,
    ManipulatedActive = false,
    DamageDealt = 0,
    DamageTaken = 0,
    LastHitmarkerTime = 0,

    TargetHudGui = nil,
    TargetHudFrame = nil,
    TargetHighlight = nil,
    TargetSnapline = nil,
    CrosshairLines = {},
    CrosshairOutlines = {},
    SilentFovCircle = nil,
    SilentFovOutline = nil,
    AimbotFovCircle = nil,
    TracerDrawings = {},
    OriginalCameraFov = nil,

    EspBoxes = {},
    ChamsHighlights = {},

    AppliedAdornments = {},
    AppliedSelectionBoxes = {},
    WeaponHighlight = nil,
    SavedPartProps = {},
    LastItemVisual = nil,

    OriginalSkybox = nil,
    ActiveSkybox = nil,
}

local fakePos = {
    Enabled           = false,
    Depth             = 5.8,
    WalkMode          = true,
    SurfaceCamera     = true,
    AutoNoclip        = true,
    AutoHandoff       = true,
    VisualizerEnabled = true,
    VisualizerColor   = Color3.fromRGB(0, 162, 255),
    Panic             = false,
    PanicMinX         = -5,
    PanicMaxX         = 5,
    PanicZ            = false,
    HideMeshes        = true,
    AnimationDesync   = true,
    ZeroVelocity      = true,
    CustomPitch       = 0,
    CustomYaw         = 0,
    InvertPitch       = false,
    DesyncMode        = "Position Desync V2",

    VirtualCF         = nil,
    LastMoveDir       = Vector3.zero,
    GhostBox          = nil,
    AnimTrack         = nil,
    OriginalParts     = nil,
    HandoffTicks      = 0,
    ClientCF          = nil,
    FakeCF            = nil,
}

local movementState = {
    WalkSpeedEnabled  = false,
    WalkSpeedMult     = 1.0,
    SlidingEnabled    = false,
    SlidingMult       = 1.0,
    NoclipEnabled     = false,
    FlightEnabled     = false,
    FlightSpeed       = 100,
    DoubleJump        = false,
    DoubleJumpHeight  = 1.0,
    LongJump          = false,
    LongJumpMode      = "Camera Look",
    LongJumpForce     = 150,
    LongJumpUpward    = 100,
    AutoStrafe        = false,
    AutoStrafeSpeed   = 50,
}

local staffDetectorState = {
    Enabled           = true,
    AutoHop           = false,
    AutoKick          = false,
    DetectedStaff     = {},
}

local function undergroundCaptureOriginal()
    local char = LocalPlayer and LocalPlayer.Character
    if not char then return end
    fakePos.OriginalParts = {}
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") or part:IsA("Decal") then
            table.insert(fakePos.OriginalParts, { part = part, transparency = part.Transparency })
            if fakePos.HideMeshes then
                pcall(function() part.Transparency = 1 end)
            end
        end
    end
end

local function undergroundRestoreOriginal()
    if not fakePos.OriginalParts then return end
    for _, data in ipairs(fakePos.OriginalParts) do
        if data.part and data.part.Parent then
            pcall(function() data.part.Transparency = data.transparency end)
        end
    end
    fakePos.OriginalParts = nil
end

local function playAnimDesync()
    local char = LocalPlayer and LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if not fakePos.AnimTrack then
        pcall(function()
            local anim = Instance.new("Animation")
            anim.AnimationId = "rbxassetid://10714003221"
            local track = hum:LoadAnimation(anim)
            track:Play(0, 1, 0)
            track.TimePosition = 1.48
            fakePos.AnimTrack = track
        end)
    end
end

local function stopAnimDesync()
    if fakePos.AnimTrack then
        pcall(function()
            fakePos.AnimTrack:Stop()
            fakePos.AnimTrack:Destroy()
        end)
        fakePos.AnimTrack = nil
    end
end

local function updateGhostVisualizer()
    local coreGui = cloneref and cloneref(game:GetService("CoreGui")) or game:GetService("CoreGui")
    if fakePos.Enabled and fakePos.VisualizerEnabled and fakePos.VirtualCF and not meowState.Destroyed then
        if not fakePos.GhostBox or not fakePos.GhostBox.Parent then
            local box = Instance.new("BoxHandleAdornment")
            box.Name = "_MeowFakePosGhost"
            box.Size = Vector3.new(2, 5, 1)
            box.Color3 = fakePos.VisualizerColor or Color3.fromRGB(0, 162, 255)
            box.Transparency = 0.55
            box.AlwaysOnTop = true
            box.ZIndex = 5
            box.Adornee = workspace.Terrain
            pcall(function() box.Parent = coreGui end)
            fakePos.GhostBox = box
        end
        fakePos.GhostBox.CFrame = fakePos.VirtualCF
        fakePos.GhostBox.Color3 = fakePos.VisualizerColor or Color3.fromRGB(0, 162, 255)
    else
        if fakePos.GhostBox then
            pcall(function() fakePos.GhostBox:Destroy() end)
            fakePos.GhostBox = nil
        end
    end
end

local function set_position_desync(source, clientCF, serverCF)
    local genv = getgenv()
    genv.position_desync_source = source
    genv.client_position = typeof(clientCF) == "CFrame" and clientCF.Position or clientCF
    genv.server_position = typeof(serverCF) == "CFrame" and serverCF.Position or serverCF
    genv.v2_tp_pos = (source == "v2" and genv.server_position) or nil
    fakePos.ClientCF = clientCF
    fakePos.FakeCF = serverCF
end

local function clear_position_desync()
    local genv = getgenv()
    local char = LocalPlayer and LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local pos = hrp and hrp.Position
    genv.position_desync_source = nil
    genv.client_position = pos
    genv.server_position = pos
    genv.v2_tp_pos = nil
    fakePos.ClientCF = nil
    fakePos.FakeCF = nil
end

getgenv().set_position_desync = set_position_desync
getgenv().clear_position_desync = clear_position_desync

local function setFakePosition(state)
    if fakePos.Enabled == state then return end
    fakePos.Enabled = state
    flags.fake_position_enabled = state
    getgenv().FakePositionEnabled = state
    getgenv().HideUndergroundEnabled = state
    meowState.ManipulatedActive = state

    local char = LocalPlayer and LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if state then
        if hrp then
            fakePos.VirtualCF = hrp.CFrame
        end
        if fakePos.HideMeshes then undergroundCaptureOriginal() end
        if fakePos.AnimationDesync then playAnimDesync() end

        pcall(function()
            RunService:UnbindFromRenderStep("FakePosCameraElevation")
        end)
        RunService:BindToRenderStep("FakePosCameraElevation", 201, function()
            if fakePos.Enabled and fakePos.SurfaceCamera and not meowState.Destroyed then
                local cam = workspace.CurrentCamera
                local depth = flags.fake_position_depth or fakePos.Depth or 5.8
                if cam and depth > 0 then
                    cam.CFrame = cam.CFrame + Vector3.new(0, depth, 0)
                end
            end
        end)
    else
        pcall(function()
            RunService:UnbindFromRenderStep("FakePosCameraElevation")
        end)
        undergroundRestoreOriginal()
        stopAnimDesync()
        updateGhostVisualizer()

        if hrp and fakePos.VirtualCF then
            pcall(function()
                if fakePos.ZeroVelocity then
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end
                hrp.CFrame = fakePos.VirtualCF
            end)
        end
        fakePos.VirtualCF = nil
        fakePos.HandoffTicks = 0
        clear_position_desync()
    end
end

getgenv().SetFakePosition = setFakePosition
getgenv().ToggleFakePosition = function()
    setFakePosition(not fakePos.Enabled)
    return fakePos.Enabled
end
getgenv().SetFakePositionDepth = function(d)
    if type(d) == "number" then fakePos.Depth = d end
end
getgenv().SetFakePositionHideMesh = function(h)
    fakePos.HideMeshes = (h == true)
    if not fakePos.HideMeshes then
        undergroundRestoreOriginal()
    elseif fakePos.Enabled then
        undergroundCaptureOriginal()
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if UserInputService:GetFocusedTextBox() then return end
    local kbData = flags.fake_position_keybind_data
    local targetKey = (type(kbData) == "table" and typeof(kbData.key) == "EnumItem" and kbData.key) or Enum.KeyCode.X
    if input.KeyCode == targetKey then
        setFakePosition(not fakePos.Enabled)
        pcall(function()
            if Library and Library.notifications then
                Library.notifications:create_notification({
                    name = "Fake Position",
                    info = fakePos.Enabled and ("Enabled (" .. tostring(fakePos.Depth) .. " studs underground)") or "Disabled",
                    lifetime = 2
                })
            end
        end)
    end
end)

RunService.Heartbeat:Connect(function(dt)
    if not fakePos.Enabled or meowState.Destroyed then return end
    local char = LocalPlayer and LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    if fakePos.HandoffTicks > 0 then
        fakePos.HandoffTicks = fakePos.HandoffTicks - 1
        if fakePos.VirtualCF then
            hrp.CFrame = fakePos.VirtualCF
            set_position_desync("handoff", fakePos.VirtualCF, hrp.CFrame)
        end
        return
    end

    if not fakePos.VirtualCF then
        fakePos.VirtualCF = hrp.CFrame
    end

    local cam = Workspace.CurrentCamera
    local camLook = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
    local camYaw = math.atan2(-camLook.X, -camLook.Z)
    local surfaceRot = CFrame.Angles(0, camYaw, 0)

    if not fakePos.VirtualCF then
        fakePos.VirtualCF = CFrame.new(hrp.CFrame.Position) * surfaceRot
    end

    if fakePos.WalkMode then
        local moveDir = hum.MoveDirection
        if moveDir.Magnitude > 0 then
            local speed = hum.WalkSpeed * (movementState.WalkSpeedEnabled and movementState.WalkSpeedMult or 1)
            local deltaPos = moveDir * (speed * dt)
            fakePos.VirtualCF = CFrame.new(fakePos.VirtualCF.Position + deltaPos) * surfaceRot
        else
            fakePos.VirtualCF = CFrame.new(fakePos.VirtualCF.Position) * surfaceRot
        end
    else
        fakePos.VirtualCF = CFrame.new(fakePos.VirtualCF.Position) * surfaceRot
    end

    local depth = flags.fake_position_depth or fakePos.Depth or 5.8
    local undergroundPos = fakePos.VirtualCF.Position - Vector3.new(0, depth, 0)

    if fakePos.Panic then
        local minX = math.min(fakePos.PanicMinX, fakePos.PanicMaxX)
        local maxX = math.max(fakePos.PanicMinX, fakePos.PanicMaxX)
        local jx = minX + math.random() * (maxX - minX)
        local jz = fakePos.PanicZ and ((math.random() - 0.5) * (maxX - minX)) or 0
        undergroundPos = undergroundPos + Vector3.new(jx, 0, jz)
    end

    local pitchAngle = fakePos.InvertPitch and (fakePos.CustomPitch or 0) or 0
    local pitchCF = CFrame.Angles(math.rad(pitchAngle), math.rad(fakePos.CustomYaw or 0), 0)

    if fakePos.AutoNoclip then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                p.CanCollide = false
            end
        end
    end

    if fakePos.ZeroVelocity then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end

    hrp.CFrame = CFrame.new(undergroundPos) * surfaceRot * pitchCF

    set_position_desync("fake", fakePos.VirtualCF, hrp.CFrame)

    updateGhostVisualizer()
end)

RunService.Heartbeat:Connect(function()
    if not fakePos.Enabled or not fakePos.HideMeshes or meowState.Destroyed then return end
    if not fakePos.OriginalParts then return end
    for _, data in ipairs(fakePos.OriginalParts) do
        local part = data.part
        if part and part.Parent and part.Transparency ~= 1 then
            pcall(function() part.Transparency = 1 end)
        end
    end
end)

RunService.Stepped:Connect(function()
    if meowState.Destroyed then return end
    local char = LocalPlayer and LocalPlayer.Character
    if not char then return end

    if movementState.NoclipEnabled then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                p.CanCollide = false
            end
        end
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        if movementState.WalkSpeedEnabled and movementState.WalkSpeedMult > 1.0 then
            hum.WalkSpeed = 16 * movementState.WalkSpeedMult
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not movementState.FlightEnabled or meowState.Destroyed then return end
    local char = LocalPlayer and LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local cam = Workspace.CurrentCamera
    local moveDir = Vector3.zero

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0) end

    if moveDir.Magnitude > 0 then
        hrp.Velocity = moveDir.Unit * movementState.FlightSpeed
    else
        hrp.Velocity = Vector3.zero
    end
end)

UserInputService.JumpRequest:Connect(function()
    if meowState.Destroyed then return end
    local char = LocalPlayer and LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    if movementState.DoubleJump then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
        hrp.Velocity = Vector3.new(hrp.Velocity.X, 50 * movementState.DoubleJumpHeight, hrp.Velocity.Z)
    end

    if movementState.LongJump then
        local cam = Workspace.CurrentCamera
        local dir = (movementState.LongJumpMode == "Camera Look" and cam and cam.CFrame.LookVector) or hrp.CFrame.LookVector
        hrp.Velocity = Vector3.new(dir.X * movementState.LongJumpForce, movementState.LongJumpUpward, dir.Z * movementState.LongJumpForce)
    end
end)

local MOD_KEYWORDS = { "mod", "admin", "staff", "owner", "developer", "tester", "creator", "contributor" }
local function checkStaffMember(player)
    if not staffDetectorState.Enabled or not player or player == LocalPlayer then return end
    task.spawn(function()
        pcall(function()
            local nameLower = player.Name:lower()
            local dispLower = (player.DisplayName or ""):lower()
            local isStaff = (player.UserId == game.CreatorId)

            if not isStaff then
                for _, kw in ipairs(MOD_KEYWORDS) do
                    if nameLower:find(kw) or dispLower:find(kw) then
                        isStaff = true
                        break
                    end
                end
            end

            if isStaff and not staffDetectorState.DetectedStaff[player.UserId] then
                staffDetectorState.DetectedStaff[player.UserId] = true
                local msg = "[Sleepy Hub] Staff / Mod detected: " .. player.Name .. " (" .. player.DisplayName .. ")"
                warn(msg)
                if Library and Library.notifications then
                    Library.notifications:create_notification({
                        name = "Staff Alert",
                        info = "Staff member detected: " .. player.Name,
                        lifetime = 8
                    })
                end
                if staffDetectorState.AutoHop then
                    pcall(function()
                        local ts = game:GetService("TeleportService")
                        ts:Teleport(game.PlaceId, LocalPlayer)
                    end)
                elseif staffDetectorState.AutoKick then
                    LocalPlayer:Kick("Preventive disconnect: Staff member joined")
                end
            end
        end)
    end)
end

Players.PlayerAdded:Connect(checkStaffMember)
task.defer(function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then checkStaffMember(p) end
    end
end)

match_in_round = function()
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

local_fighter_alive = function()
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

status_target_name = function(target)
    if not target then return nil end
    if typeof(target) == "Instance" then
        if target:IsA("Player") then return target.DisplayName or target.Name end
        local pl = Players:GetPlayerFromCharacter(target)
        if pl then return pl.DisplayName or pl.Name end
        return target.Name
    elseif type(target) == "table" and target.Player then
        return target.Player.DisplayName or target.Player.Name
    end
    return tostring(target)
end

is_katana_user = function(model, player)
    local char = model or (player and player.Character)
    if not char then return false end
    if char:FindFirstChild("Katana") then return true end
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and t.Name:lower():find("katana") then return true end
    end
    return false
end

manip_is_deflecting = function(fighter)
    if not fighter then return false end
    local char = (type(fighter) == "table" and fighter.Character) or (typeof(fighter) == "Instance" and fighter)
    if not char then return false end
    local katana = char:FindFirstChild("Katana")
    if katana and katana:FindFirstChild("Deflecting") and katana.Deflecting.Value == true then
        return true
    end
    return false
end

shield_blocks_shot = function(targetRoot, shooterPos)
    if not targetRoot then return false end
    local char = targetRoot.Parent
    if not char then return false end
    local shield = char:FindFirstChild("Riot Shield") or char:FindFirstChild("Shield")
    if not shield then return false end
    local targetLook = targetRoot.CFrame.LookVector
    local shotDir = (shooterPos - targetRoot.Position).Unit
    return targetLook:Dot(shotDir) < -0.2
end

ragebot_is_priority = function(player)
    if not player then return false end
    local name = typeof(player) == "Instance" and player.Name or tostring(player)
    return meowState.PriorityList[name:lower()] == true
end

ragebot_add_priority = function(player)
    if not player then return end
    local name = typeof(player) == "Instance" and player.Name or tostring(player)
    meowState.PriorityList[name:lower()] = true
end
getgenv()._Meow_AddPriority = ragebot_add_priority

silent_closest_hitbox = function(char)
    if not char then return nil end
    local mode = flags.target_hitbox or "Head"
    if mode == "Head" then
        return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    elseif mode == "HumanoidRootPart" or mode == "Torso" then
        return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    elseif mode == "Random" then
        local parts = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"}
        return char:FindFirstChild(parts[math.random(1, #parts)]) or char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end
silent_closest_part = silent_closest_hitbox
targeting_silent_part = silent_closest_hitbox
target_aim_part = silent_closest_hitbox
random_hitpart_name = function()
    local p = {"Head", "HumanoidRootPart", "Torso", "UpperTorso"}
    return p[math.random(1, #p)]
end

get_target = function()
    local myChar = LocalPlayer.Character
    if not myChar then return nil end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local bestTarget = nil
    local bestScore = math.huge
    local method = flags.target_priority or "Lowest Health"
    local fovRadius = flags.fov_radius_smoothed or 120
    local center = Camera.ViewportSize / 2

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character then
            local char = pl.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")

            if hum and hum.Health > 0 and root and not char:FindFirstChildOfClass("ForceField") then
                if not (flags.riot_shield_check and shield_blocks_shot(root, myRoot.Position)) then
                    if not (flags.avoid_katana and manip_is_deflecting(char)) then
                        local scrPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                        local fovDist = (Vector2.new(scrPos.X, scrPos.Y) - center).Magnitude

                        if not flags.silent_aim_enabled or fovDist <= fovRadius then
                            local dist = (root.Position - myRoot.Position).Magnitude
                            local health = hum.Health
                            local isPriority = ragebot_is_priority(pl)
                            local score = health

                            if method == "Distance" or method == "Closest Distance" then
                                score = dist
                            elseif method == "Crosshair" then
                                score = fovDist
                            elseif method == "FOV - Lowest Health" then
                                score = (health * 2) + fovDist
                            else
                                score = health
                            end

                            if isPriority then
                                score = score - 10000
                            end

                            if score < bestScore then
                                bestScore = score
                                bestTarget = {
                                    Player = pl,
                                    Character = char,
                                    Humanoid = hum,
                                    RootPart = root,
                                    HitPart = silent_closest_hitbox(char),
                                    Distance = dist,
                                    FOVDistance = fovDist,
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    meowState.CurrentTarget = bestTarget
    if bestTarget then meowState.LastTargetPlayer = bestTarget.Player end
    return bestTarget
end

manip_set_filter = function(char) end
manip_probe = function(origin, dir, model, part)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    local res = Workspace:Raycast(origin, dir, rp)
    if not res then return 1 end
    if res.Instance and (res.Instance:IsDescendantOf(model) or res.Instance == part) then
        return 1
    end
    return 0
end
manip_resolve = function() return true end
manip_in_control = function() return flags.manip_result == true end
manip_is_underground = function() return hideUndergroundEnabled end

collect_drops = function(char, root)
    if not flags.ACO then return end
    local drops = Workspace:FindFirstChild("Drops") or Workspace:FindFirstChild("Debris") or Workspace
    for _, item in ipairs(drops:GetChildren()) do
        if item:IsA("BasePart") and (item.Name:find("Orb") or item.Name:find("Ammo") or item.Name:find("Drop")) then
            if (item.Position - root.Position).Magnitude <= 35 then
                pcall(function()
                    if firetouchinterest then
                        firetouchinterest(root, item, 0)
                        firetouchinterest(root, item, 1)
                    end
                end)
            end
        end
    end
end

anti_subspace_friendly = function(mine)
    if not mine then return true end
    local creator = mine:GetAttribute("Creator") or mine:FindFirstChild("Creator")
    if creator and tostring(creator.Value or creator) == LocalPlayer.Name then
        return true
    end
    return false
end

antiaim_extended_char = function(val)
    local ok, char = pcall(function() return utf8 and utf8.char and utf8.char(val or 1114111) or "" end)
    return ok and char or "\255"
end

antiaim_pitch = function(mode, custom)
    mode = mode or flags.antiaim_pitch or "Down"
    if flags.antiaim_hidehead then return -89 end
    if mode == "Down" then return -89
    elseif mode == "Up" then return 89
    elseif mode == "Jitter" or mode == "Up & Down" then return (math.random(1, 2) == 1 and 89 or -89)
    elseif mode == "Random" then return math.random(-89, 89)
    elseif mode == "Custom" then return custom or flags.antiaim_custom_pitch or 0
    elseif mode == "Zero" then return 0 end
    return -89
end

local aaSpinAngle = 0
local aaSwayAngle = 0
local aaSwayDir = 1
local aaJitterFlip = false

antiaim_yaw = function(mode, speed, jitterRange)
    mode = mode or flags.antiaim_yaw or "Spin"
    speed = speed or flags.antiaim_spin_speed or 15
    jitterRange = jitterRange or flags.antiaim_jitter_range or 45
    local dt = 1/60

    if mode == "Backwards" then return 180
    elseif mode == "Left" then return 90
    elseif mode == "Right" then return -90
    elseif mode == "Spin" then
        aaSpinAngle = (aaSpinAngle + (speed * 10 * dt)) % 360
        return aaSpinAngle
    elseif mode == "Sway" then
        aaSwayAngle = aaSwayAngle + (speed * 4 * dt * aaSwayDir)
        if math.abs(aaSwayAngle) > 60 then aaSwayDir = -aaSwayDir end
        return 180 + aaSwayAngle
    elseif mode == "Jitter" then
        aaJitterFlip = not aaJitterFlip
        return aaJitterFlip and (180 + jitterRange) or (180 - jitterRange)
    elseif mode == "Random" then
        return math.random(-180, 180)
    elseif mode == "Custom" then
        return flags.antiaim_custom_yaw or 0
    end
    return 180
end

set_position_desync = function() meowState.ManipulatedActive = true end
clear_position_desync = function() meowState.ManipulatedActive = false end

display_font_face = function(fontName)
    fontName = fontName or flags.esp_font or "MonoSpace"
    if fontName == "ProggyTiny" then return Enum.Font.Code
    elseif fontName == "MonoSpace" then return Enum.Font.RobotoMono
    elseif fontName == "Tahoma" then return Enum.Font.Gotham end
    return Enum.Font.Code
end
apply_display_font = function(label)
    if label and label:IsA("TextLabel") then
        label.Font = display_font_face()
    end
end

spawn_world_marker = function(pos)
    meowState.LastHitmarkerTime = os.clock()
    if not (flags.world_marker_enabled ~= false) or not pos then return end
    task.spawn(function()
        local size = flags.world_marker_size or 1.0
        local length = flags.world_marker_length or 1.0
        local thickness = flags.world_marker_thickness or 0.15
        local duration = flags.world_marker_duration or 0.6
        local growth = (flags.world_marker_growth ~= false) and 1.5 or 1.0
        local markerColor = flags.world_marker_color or Color3.fromRGB(255, 60, 60)

        local anchor = Instance.new("Part")
        anchor.Name = "MeowHitmarker"
        anchor.Anchored = true
        anchor.CanCollide = false
        anchor.CanQuery = false
        anchor.Transparency = 1
        anchor.Size = Vector3.new(0.1, 0.1, 0.1)
        anchor.Position = pos
        anchor.Parent = Workspace

        local bbg = Instance.new("BillboardGui")
        bbg.Adornee = anchor
        bbg.AlwaysOnTop = true
        bbg.Size = UDim2.fromOffset(25 * size, 25 * size)
        bbg.Parent = anchor

        local function makeArm(rot)
            local arm = Instance.new("Frame")
            arm.AnchorPoint = Vector2.new(0.5, 0.5)
            arm.Position = UDim2.fromScale(0.5, 0.5)
            arm.Size = UDim2.new(0, math.max(2, 8 * thickness), 0, math.max(6, 20 * length))
            arm.Rotation = rot
            arm.BackgroundColor3 = markerColor
            arm.BorderSizePixel = 0
            arm.Parent = bbg
            return arm
        end
        makeArm(45)
        makeArm(-45)

        local tw = TweenService:Create(bbg, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(25 * size * growth, 25 * size * growth)
        })
        tw:Play()
        task.delay(duration, function() pcall(function() anchor:Destroy() end) end)
    end)
end
damage_label = function(text, pos) spawn_world_marker(pos) end

local function handleHitDetected(targetName, partName, damage, weaponName, hitPosition)
    if flags.hit_logs_enabled then
        local formatStr = flags.hit_logs_format or "{NAME} hit in {PART} for {DMG} with {WEAPON}"
        local logMsg = formatStr:gsub("{NAME}", tostring(targetName or "Enemy"))
                               :gsub("{PART}", tostring(partName or "Torso"))
                               :gsub("{DMG}", tostring(damage or "0"))
                               :gsub("{WEAPON}", tostring(weaponName or "Weapon"))
        print("[Meow HitLog] " .. logMsg)
    end

    if hitPosition then
        spawn_world_marker(hitPosition)
        if meowState.TriggerBulletTracer then
            meowState.TriggerBulletTracer(hitPosition)
        end
    end

    if playEventSound then playEventSound("hit") end
    if damage and tonumber(damage) then
        meowState.DamageDealt = meowState.DamageDealt + tonumber(damage)
    end
end
getgenv()._Meow_TriggerHit = handleHitDetected

local HIT_SOUND_PRESETS = {
    ["Rust"] = "rbxassetid://1255040462",
    ["Skeet"] = "rbxassetid://5633695679",
    ["Bell"] = "rbxassetid://6534947240",
    ["Bonk"] = "rbxassetid://3997129949",
    ["Neverlose"] = "rbxassetid://6607204501",
    ["Bubble"] = "rbxassetid://6534947588",
}

local KILL_SOUND_PRESETS = {
    ["Oof"] = "rbxassetid://5143383166",
    ["Fatality"] = "rbxassetid://6607204928",
    ["Headshot"] = "rbxassetid://6534948092",
    ["Skeet"] = "rbxassetid://5633695679",
}

local function playRawSound(assetId, volume, pitch)
    if not assetId or assetId == "" then return end
    task.spawn(function()
        local s = Instance.new("Sound")
        s.SoundId = assetId
        s.Volume = volume or 1.0
        s.PlaybackSpeed = pitch or 1.0
        s.Parent = SoundService
        s:Play()
        s.Ended:Connect(function() s:Destroy() end)
        task.delay(5, function() if s and s.Parent then s:Destroy() end end)
    end)
end

playEventSound = function(eventType)
    local volume = flags.sound_volume or 1.0
    local pitch = flags.sound_pitch or 1.0

    if eventType == "hit" and (flags.hit_sound_enabled ~= false) then
        local preset = flags.hit_sound_preset or "Rust"
        local asset = HIT_SOUND_PRESETS[preset] or HIT_SOUND_PRESETS["Rust"]
        if preset == "Custom ID" and flags.hit_sound_custom_id then
            asset = flags.hit_sound_custom_id
        end
        if asset then playRawSound(asset, volume, pitch) end
    elseif eventType == "kill" and flags.kill_sound_enabled then
        local preset = flags.kill_sound_preset or "Fatality"
        local asset = KILL_SOUND_PRESETS[preset] or KILL_SOUND_PRESETS["Fatality"]
        if preset == "Custom ID" and flags.kill_sound_custom_id then
            asset = flags.kill_sound_custom_id
        end
        if asset then playRawSound(asset, volume, pitch) end
    elseif eventType == "death" and flags.death_sound_enabled then
        playRawSound(KILL_SOUND_PRESETS["Oof"], volume, pitch)
    end
end
getgenv()._Meow_PlayEventSound = playEventSound

local function ensureTargetHudGui()
    if meowState.TargetHudGui and meowState.TargetHudGui.Parent then return end
    pcall(function()
        local parent = (gethui and gethui()) or game:GetService("CoreGui")
        local sg = Instance.new("ScreenGui")
        sg.Name = "_MeowTargetHUD"
        sg.ResetOnSpawn = false
        sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

        local frame = Instance.new("Frame")
        frame.Name = "HUDCard"
        frame.Size = UDim2.fromOffset(420, 136)
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.Position = UDim2.fromScale(0.5, 0.76)
        frame.BackgroundColor3 = Color3.fromRGB(15, 15, 17)
        frame.BorderSizePixel = 0
        frame.Visible = false
        frame.ZIndex = 120
        frame.Parent = sg

        local uisOuter = Instance.new("UIStroke")
        uisOuter.Color = Color3.fromRGB(0, 0, 0)
        uisOuter.Thickness = 1
        uisOuter.Parent = frame

        local nest1 = Instance.new("Frame")
        nest1.Position = UDim2.fromOffset(5, 5)
        nest1.Size = UDim2.new(1, -10, 1, -10)
        nest1.BackgroundTransparency = 1
        nest1.BorderSizePixel = 0
        nest1.ZIndex = 121
        nest1.Parent = frame

        local uisNest1 = Instance.new("UIStroke")
        uisNest1.Color = Color3.fromRGB(35, 35, 40)
        uisNest1.Thickness = 1
        uisNest1.Parent = nest1

        local content = Instance.new("Frame")
        content.Position = UDim2.fromOffset(5, 5)
        content.Size = UDim2.new(1, -10, 1, -10)
        content.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
        content.BorderSizePixel = 0
        content.ZIndex = 122
        content.Parent = nest1

        local uisContent = Instance.new("UIStroke")
        uisContent.Color = Color3.fromRGB(28, 28, 32)
        uisContent.Thickness = 1
        uisContent.Parent = content

        local dragging, dragStart, startPos
        frame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = frame.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)

        local slotPositions = {
            UDim2.fromOffset(10, 10),
            UDim2.fromOffset(10, 66),
            UDim2.new(1, -58, 0, 10),
            UDim2.new(1, -58, 0, 66),
        }

        local weaponSlots = {}
        for i = 1, 4 do
            local slotBox = Instance.new("Frame")
            slotBox.Name = "Slot" .. i
            slotBox.Position = slotPositions[i]
            slotBox.Size = UDim2.fromOffset(48, 48)
            slotBox.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
            slotBox.BorderSizePixel = 0
            slotBox.ZIndex = 124
            slotBox.Parent = content

            local sStroke = Instance.new("UIStroke")
            sStroke.Color = Color3.fromRGB(32, 32, 36)
            sStroke.Thickness = 1
            sStroke.Parent = slotBox

            local sImg = Instance.new("ImageLabel")
            sImg.Name = "Icon"
            sImg.AnchorPoint = Vector2.new(0.5, 0.5)
            sImg.Position = UDim2.fromScale(0.5, 0.5)
            sImg.Size = UDim2.fromScale(0.85, 0.85)
            sImg.BackgroundTransparency = 1
            sImg.ScaleType = Enum.ScaleType.Fit
            sImg.ImageColor3 = Color3.fromRGB(180, 185, 200)
            sImg.ImageTransparency = 0.4
            sImg.ZIndex = 125
            sImg.Parent = slotBox

            weaponSlots[i] = sImg
        end

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Name = "PlayerName"
        nameLbl.Position = UDim2.fromOffset(72, 10)
        nameLbl.Size = UDim2.new(1, -144, 0, 18)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.Text = "No Target"
        nameLbl.TextColor3 = Color3.fromRGB(240, 243, 255)
        nameLbl.TextSize = 14
        nameLbl.TextXAlignment = Enum.TextXAlignment.Center
        nameLbl.ZIndex = 125
        nameLbl.Parent = content

        local statsLbl = Instance.new("TextLabel")
        statsLbl.Name = "Stats"
        statsLbl.Position = UDim2.fromOffset(72, 30)
        statsLbl.Size = UDim2.new(1, -144, 0, 14)
        statsLbl.BackgroundTransparency = 1
        statsLbl.Font = Enum.Font.GothamMedium
        statsLbl.Text = 'level <font color="#00A2FF">N/A</font>  rank <font color="#00A2FF">N/A</font>  device <font color="#00A2FF">N/A</font>  streak <font color="#00A2FF">N/A</font>'
        statsLbl.RichText = true
        statsLbl.TextColor3 = Color3.fromRGB(160, 165, 180)
        statsLbl.TextSize = 10
        statsLbl.TextXAlignment = Enum.TextXAlignment.Center
        statsLbl.ZIndex = 125
        statsLbl.Parent = content

        local hpTrack = Instance.new("Frame")
        hpTrack.Name = "HealthTrack"
        hpTrack.Position = UDim2.fromOffset(72, 54)
        hpTrack.Size = UDim2.new(1, -144, 0, 16)
        hpTrack.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
        hpTrack.BorderSizePixel = 0
        hpTrack.ZIndex = 124
        hpTrack.Parent = content

        local hpTrackStroke = Instance.new("UIStroke")
        hpTrackStroke.Color = Color3.fromRGB(30, 30, 35)
        hpTrackStroke.Thickness = 1
        hpTrackStroke.Parent = hpTrack

        local hpFill = Instance.new("Frame")
        hpFill.Name = "Fill"
        hpFill.Size = UDim2.fromScale(1, 1)
        hpFill.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
        hpFill.BorderSizePixel = 0
        hpFill.ZIndex = 125
        hpFill.Parent = hpTrack

        local hpVal = Instance.new("TextLabel")
        hpVal.Name = "Value"
        hpVal.Size = UDim2.fromScale(1, 1)
        hpVal.BackgroundTransparency = 1
        hpVal.Font = Enum.Font.GothamBold
        hpVal.Text = "100 / 100"
        hpVal.TextColor3 = Color3.fromRGB(255, 255, 255)
        hpVal.TextSize = 10
        hpVal.ZIndex = 126
        hpVal.Parent = hpTrack

        local ratioTrack = Instance.new("Frame")
        ratioTrack.Name = "RatioTrack"
        ratioTrack.Position = UDim2.fromOffset(72, 78)
        ratioTrack.Size = UDim2.new(1, -144, 0, 14)
        ratioTrack.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
        ratioTrack.BorderSizePixel = 0
        ratioTrack.ZIndex = 124
        ratioTrack.Parent = content

        local rTrackStroke = Instance.new("UIStroke")
        rTrackStroke.Color = Color3.fromRGB(30, 30, 35)
        rTrackStroke.Thickness = 1
        rTrackStroke.Parent = ratioTrack

        local ratioFill = Instance.new("Frame")
        ratioFill.Name = "Fill"
        ratioFill.Size = UDim2.fromScale(0.5, 1)
        ratioFill.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
        ratioFill.BorderSizePixel = 0
        ratioFill.ZIndex = 125
        ratioFill.Parent = ratioTrack

        local ratioVal = Instance.new("TextLabel")
        ratioVal.Name = "Value"
        ratioVal.Size = UDim2.fromScale(1, 1)
        ratioVal.BackgroundTransparency = 1
        ratioVal.Font = Enum.Font.GothamBold
        ratioVal.Text = '<font color="#00A2FF">0 ▲</font>  <font color="#FF4560">0 ▼</font>'
        ratioVal.RichText = true
        ratioVal.TextColor3 = Color3.fromRGB(240, 240, 250)
        ratioVal.TextSize = 9.5
        ratioVal.ZIndex = 126
        ratioVal.Parent = ratioTrack

        sg.Parent = parent
        meowState.TargetHudGui = sg
        meowState.TargetHudSlots = weaponSlots
        meowState.TargetHudName = nameLbl
        meowState.TargetHudStats = statsLbl
        meowState.TargetHudHpFill = hpFill
        meowState.TargetHudHpVal = hpVal
        meowState.TargetHudRatioFill = ratioFill
        meowState.TargetHudRatioVal = ratioVal
        meowState.TargetHudFrame = frame
    end)
end

local function updateTargetVisuals()
    local target = meowState.CurrentTarget
    local hudEnabled = flags.target_hud or flags.target_hud_preview

    if hudEnabled then
        ensureTargetHudGui()
    end

    if meowState.TargetHudFrame then
        meowState.TargetHudFrame.Visible = hudEnabled and (target ~= nil or flags.target_hud_preview)
        if meowState.TargetHudFrame.Visible then
            local slots = meowState.TargetHudSlots or {}
            local nameLbl = meowState.TargetHudName
            local statsLbl = meowState.TargetHudStats
            local hpFill = meowState.TargetHudHpFill
            local hpVal = meowState.TargetHudHpVal
            local ratioFill = meowState.TargetHudRatioFill
            local ratioVal = meowState.TargetHudRatioVal

            if target and target.Player then
                local pl = target.Player
                if nameLbl then nameLbl.Text = pl.DisplayName or pl.Name end

                local level = "N/A"
                local streak = "N/A"
                local rank = "N/A"
                local device = "N/A"
                pcall(function()
                    local ls = pl:FindFirstChild("leaderstats")
                    if ls then
                        if ls:FindFirstChild("Level") then level = tostring(ls.Level.Value) end
                        if ls:FindFirstChild("Streak") then streak = tostring(ls.Streak.Value) end
                        if ls:FindFirstChild("Rank") then rank = tostring(ls.Rank.Value) end
                    end
                end)
                if statsLbl then
                    statsLbl.Text = string.format('level <font color="#00A2FF">%s</font>  rank <font color="#00A2FF">%s</font>  device <font color="#00A2FF">%s</font>  streak <font color="#00A2FF">%s</font>', level, rank, device, streak)
                end

                local hum = target.Humanoid
                if hum and hpFill and hpVal then
                    local hp = math.max(0, hum.Health)
                    local maxHp = math.max(1, hum.MaxHealth)
                    hpFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
                    hpVal.Text = string.format("%d / %d", math.floor(hp), math.floor(maxHp))
                end

                pcall(function()
                    local rep = game:GetService("ReplicatedStorage")
                    local ItemLibrary = rep:FindFirstChild("Modules") and rep.Modules:FindFirstChild("ItemLibrary") and require(rep.Modules.ItemLibrary)
                    local weps = { "Assault Rifle", "Revolver", "Knife", "Medkit" }
                    local char = pl.Character
                    if char then
                        local tool = char:FindFirstChildOfClass("Tool")
                        if tool then weps[1] = tool.Name end
                    end
                    for i = 1, 4 do
                        local sImg = slots[i]
                        if sImg then
                            local wName = weps[i]
                            if ItemLibrary and ItemLibrary.Items and ItemLibrary.Items[wName] then
                                local itm = ItemLibrary.Items[wName]
                                local img = itm.ImageHighResolution or itm.Image
                                if type(img) == "string" and #img > 0 then
                                    sImg.Image = img
                                    sImg.ImageTransparency = 0.1
                                end
                            end
                        end
                    end
                end)
            elseif flags.target_hud_preview then
                if nameLbl then nameLbl.Text = "rage sahur" end
                if statsLbl then
                    statsLbl.Text = 'level <font color="#00A2FF">36</font>  rank <font color="#00A2FF">platinum 1</font>  device <font color="#00A2FF">virtualreality</font>  streak <font color="#00A2FF">3</font>'
                end
                if hpFill and hpVal then
                    hpFill.Size = UDim2.fromScale(70 / 150, 1)
                    hpVal.Text = "70 / 150"
                end
                if ratioVal then
                    ratioVal.Text = '<font color="#FF4560">49 ▲</font>  <font color="#FF4560">52 ▼</font>'
                end
                if ratioFill then
                    ratioFill.Size = UDim2.fromScale(49 / (49 + 52), 1)
                end
                pcall(function()
                    local rep = game:GetService("ReplicatedStorage")
                    local ItemLibrary = rep:FindFirstChild("Modules") and rep.Modules:FindFirstChild("ItemLibrary") and require(rep.Modules.ItemLibrary)
                    local previewWeps = { "Assault Rifle", "Revolver", "Knife", "Medkit" }
                    for i = 1, 4 do
                        local sImg = slots[i]
                        if sImg and ItemLibrary and ItemLibrary.Items and ItemLibrary.Items[previewWeps[i]] then
                            local itm = ItemLibrary.Items[previewWeps[i]]
                            local img = itm.ImageHighResolution or itm.Image
                            if type(img) == "string" and #img > 0 then
                                sImg.Image = img
                                sImg.ImageTransparency = 0.2
                            end
                        end
                    end
                end)
            end
        end
    end

    if flags.target_highlight and target and target.Character then
        if not meowState.TargetHighlight or not meowState.TargetHighlight.Parent then
            local hl = Instance.new("Highlight")
            hl.Name = "_MeowTargetHighlight"
            hl.Parent = (gethui and gethui()) or game:GetService("CoreGui")
            meowState.TargetHighlight = hl
        end
        local hl = meowState.TargetHighlight
        hl.Adornee = target.Character
        hl.OutlineColor = flags.target_highlight_outline or Color3.fromRGB(255, 60, 60)
        hl.FillColor = flags.target_highlight_fill or Color3.fromRGB(180, 30, 30)
        hl.OutlineTransparency = 0
        hl.FillTransparency = 0.5
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Enabled = true
    elseif meowState.TargetHighlight then
        meowState.TargetHighlight.Enabled = false
        meowState.TargetHighlight.Adornee = nil
    end

    if flags.target_snapline and target and target.HitPart then
        local scrPos, onScreen = Camera:WorldToViewportPoint(target.HitPart.Position)
        if onScreen then
            if not meowState.TargetSnapline then
                pcall(function()
                    meowState.TargetSnapline = Drawing.new("Line")
                end)
            end
            local line = meowState.TargetSnapline
            if line then
                line.From = Camera.ViewportSize / 2
                line.To = Vector2.new(scrPos.X, scrPos.Y)
                line.Color = flags.target_snapline_color or Color3.fromRGB(255, 80, 80)
                line.Thickness = 1.5
                line.Transparency = 1
                line.Visible = true
            end
        elseif meowState.TargetSnapline then
            meowState.TargetSnapline.Visible = false
        end
    elseif meowState.TargetSnapline then
        meowState.TargetSnapline.Visible = false
    end
end

local function spawnBulletTracer(fromPos, toPos)
    if not flags.bullet_tracers then return end
    pcall(function()
        local line = Drawing.new("Line")
        local shadow = flags.tracer_shadows and Drawing.new("Line") or nil
        local tracer = {
            line = line,
            shadow = shadow,
            from = fromPos,
            to = toPos,
            born = os.clock(),
            hold = flags.tracer_hold or 0.6,
            fade = flags.tracer_fade or 0.4,
            travel = flags.tracer_travel or 0.15,
            color = flags.tracer_color or Color3.fromRGB(120, 180, 255),
        }
        table.insert(meowState.TracerDrawings, tracer)
    end)
end

meowState.TriggerBulletTracer = function(toPos)
    local char = LocalPlayer.Character
    local fromPos = char and char:FindFirstChild("Head") and char.Head.Position or Camera.CFrame.Position
    if fromPos and toPos then
        spawnBulletTracer(fromPos, toPos)
    end
end

local function updateBulletTracers()
    local now = os.clock()
    for idx = #meowState.TracerDrawings, 1, -1 do
        local d = meowState.TracerDrawings[idx]
        local age = now - d.born
        local totalLife = d.hold + d.fade
        if age >= totalLife then
            pcall(function() d.line:Destroy() end)
            if d.shadow then pcall(function() d.shadow:Destroy() end) end
            table.remove(meowState.TracerDrawings, idx)
        else
            local travelPct = d.travel > 0 and math.clamp(age / d.travel, 0, 1) or 1
            local currentTo = d.from:Lerp(d.to, travelPct)

            local p1, on1 = Camera:WorldToViewportPoint(d.from)
            local p2, on2 = Camera:WorldToViewportPoint(currentTo)

            if (on1 or on2) and p1.Z > 0 and p2.Z > 0 then
                local alpha = 1
                if age > d.hold then
                    alpha = math.clamp(1 - ((age - d.hold) / d.fade), 0, 1)
                end

                d.line.From = Vector2.new(p1.X, p1.Y)
                d.line.To = Vector2.new(p2.X, p2.Y)
                d.line.Color = d.color
                d.line.Thickness = 2
                d.line.Transparency = alpha
                d.line.Visible = true

                if d.shadow then
                    d.shadow.From = Vector2.new(p1.X, p1.Y)
                    d.shadow.To = Vector2.new(p2.X, p2.Y)
                    d.shadow.Color = Color3.fromRGB(0, 0, 0)
                    d.shadow.Thickness = 4
                    d.shadow.Transparency = alpha * 0.5
                    d.shadow.Visible = true
                end
            else
                d.line.Visible = false
                if d.shadow then d.shadow.Visible = false end
            end
        end
    end
end

local function getHeldItemVisual()
    local char = LocalPlayer.Character
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then return tool end
    end

    local fp = Workspace:FindFirstChild("FirstPerson")
    if fp then
        local prefix = LocalPlayer.Name .. " - "
        for _, child in ipairs(fp:GetChildren()) do
            if child.Name:sub(1, #prefix) == prefix then
                local iv = child:FindFirstChild("ItemVisual") or child
                if iv then return iv end
            end
        end
        for _, child in ipairs(fp:GetChildren()) do
            local iv = child:FindFirstChild("ItemVisual") or child
            if iv then return iv end
        end
    end

    local cam = Workspace.CurrentCamera
    if cam then
        local vms = cam:FindFirstChild("ViewModels") or Workspace:FindFirstChild("ViewModels") or cam:FindFirstChild("ViewModel")
        if vms then
            for _, child in ipairs(vms:GetChildren()) do
                local iv = child:FindFirstChild("ItemVisual") or child:FindFirstChild("Model") or child
                if iv then return iv end
            end
            return vms
        end

        for _, child in ipairs(cam:GetChildren()) do
            if child:IsA("Model") and child.Name ~= "IndicatorGui" then
                local p = child:FindFirstChildOfClass("BasePart")
                if p then return child end
            end
        end
    end

    return nil
end

local function restoreWeaponVisuals()
    if meowState.AppliedAdornments then
        for part, wire in pairs(meowState.AppliedAdornments) do
            pcall(function() wire:Destroy() end)
        end
        table.clear(meowState.AppliedAdornments)
    end

    if meowState.AppliedSelectionBoxes then
        for part, box in pairs(meowState.AppliedSelectionBoxes) do
            pcall(function() box:Destroy() end)
        end
        table.clear(meowState.AppliedSelectionBoxes)
    end

    if meowState.WeaponHighlight then
        pcall(function() meowState.WeaponHighlight:Destroy() end)
        meowState.WeaponHighlight = nil
    end

    if meowState.SavedPartProps then
        for part, orig in pairs(meowState.SavedPartProps) do
            pcall(function()
                if part and part.Parent then
                    part.Material = orig.Material
                    part.Color = orig.Color
                    part.Transparency = orig.Transparency
                end
            end)
        end
        table.clear(meowState.SavedPartProps)
    end
end

local MeowWireframe = {
    Enabled          = false,
    Color            = Color3.fromRGB(255, 255, 255),
    ColorMiddle      = Color3.fromRGB(0, 162, 255),
    Color2           = Color3.fromRGB(0, 162, 255),
    ColorMode        = "gradient",
    GradientAxis     = { "length", "height" },
    Transparency     = 0,
    Thickness        = 1,

    ArmEnabled       = false,
    ArmColor         = Color3.fromRGB(0, 162, 255),
    ArmColor2        = Color3.fromRGB(255, 255, 255),

    ActiveWires      = {},
    Connections      = {},
    PartCache        = {},
    CurrentGun       = nil,
    CurrentArms      = nil,
}

local MEOW_BOX_EDGES = {
    {1, 2}, {2, 4}, {4, 3}, {3, 1},
    {5, 6}, {6, 8}, {8, 7}, {7, 5},
    {1, 5}, {2, 6}, {3, 7}, {4, 8}
}

function MeowWireframe:GetColor(pct)
    local col1 = self.Color or Color3.fromRGB(255, 255, 255)
    local col2 = self.Color2 or Color3.fromRGB(0, 162, 255)
    local colMid = self.ColorMiddle or col1:Lerp(col2, 0.5)
    if pct <= 0.5 then
        return col1:Lerp(colMid, math.clamp(pct * 2, 0, 1))
    else
        return colMid:Lerp(col2, math.clamp((pct - 0.5) * 2, 0, 1))
    end
end

function MeowWireframe:GetDirection()
    local axis = self.GradientAxis or {"length"}
    local tbl = {}
    for _, a in ipairs(axis) do tbl[a] = true end
    local dx = (tbl.width and 1 or 0) - (tbl["reverse width"] and 1 or 0)
    local dy = (tbl.height and 1 or 0) - (tbl["reverse height"] and 1 or 0)
    local dz = (tbl.length and 1 or 0) - (tbl["reverse length"] and 1 or 0)
    return dx, dy, dz
end

function MeowWireframe:DrawGradient(wire, data)
    local pts = data.Points
    if not pts or #pts < 2 then return end

    local minP = data.Min or Vector3.new(-1, -1, -1)
    local maxP = data.Max or Vector3.new(1, 1, 1)
    local size = maxP - minP
    local dx, dy, dz = self:GetDirection()
    local totalD = math.abs(dx) + math.abs(dy) + math.abs(dz)

    local function getPct(p)
        if totalD == 0 then return 0.5 end
        local px = size.X > 0.0001 and (p.X - minP.X) / size.X or 0.5
        local py = size.Y > 0.0001 and (p.Y - minP.Y) / size.Y or 0.5
        local pz = size.Z > 0.0001 and (p.Z - minP.Z) / size.Z or 0.5
        local v = 0.5 + ((px - 0.5) * dx + (py - 0.5) * dy + (pz - 0.5) * dz) / totalD
        return math.clamp(v, 0, 1)
    end

    local segments = 6
    for i = 1, #pts, 2 do
        local p1 = pts[i]
        local p2 = pts[i + 1]
        local pct1 = getPct(p1)
        local pct2 = getPct(p2)
        local lastP = p1
        for s = 1, segments do
            local nextP = p1 + (p2 - p1) * (s / segments)
            local t = pct1 + (pct2 - pct1) * ((s - 0.5) / segments)
            wire.Color3 = self:GetColor(t)
            wire:AddLine(lastP, nextP)
            lastP = nextP
        end
    end
end

function MeowWireframe:Rebuild(wire, part)
    local size = part.Size
    local h = size * 0.5
    local corners = {
        Vector3.new(-h.X, -h.Y, -h.Z),
        Vector3.new( h.X, -h.Y, -h.Z),
        Vector3.new(-h.X,  h.Y, -h.Z),
        Vector3.new( h.X,  h.Y, -h.Z),
        Vector3.new(-h.X, -h.Y,  h.Z),
        Vector3.new( h.X, -h.Y,  h.Z),
        Vector3.new(-h.X,  h.Y,  h.Z),
        Vector3.new( h.X,  h.Y,  h.Z),
    }

    local points = {}
    for _, edge in ipairs(MEOW_BOX_EDGES) do
        table.insert(points, corners[edge[1]])
        table.insert(points, corners[edge[2]])
    end

    local data = {
        Points = points,
        Min    = -h,
        Max    = h,
    }

    wire:Clear()
    wire.Color3 = self.Color
    wire.Transparency = self.Transparency or 0
    wire.Thickness = self.Thickness or 1
    wire.AlwaysOnTop = true
    wire.ZIndex = 10

    if self.ColorMode == "gradient" then
        self:DrawGradient(wire, data)
    else
        wire:AddLines(points)
    end
end

function MeowWireframe:Draw(part)
    if self.ActiveWires[part] then return end
    local coreGui = cloneref and cloneref(game:GetService("CoreGui")) or game:GetService("CoreGui")
    local wire = Instance.new("WireframeHandleAdornment")
    wire.Name = "MeowWireframe"
    wire.ZIndex = 10
    wire.Thickness = self.Thickness or 1
    wire.AlwaysOnTop = true
    wire.Adornee = part
    pcall(function() wire.Parent = coreGui end)
    if not wire.Parent then
        pcall(function() wire.Parent = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 0.5) end)
    end
    if not wire.Parent then
        wire.Parent = Camera
    end

    self:Rebuild(wire, part)

    self.ActiveWires[part] = {
        Wire             = wire,
        OrigTransparency = part.Transparency,
        Size             = part.Size,
    }

    part.Transparency = 1
end

function MeowWireframe:Watch(part)
    if self.Connections[part] then return end
    local conns = {}

    table.insert(conns, part:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
        if part.LocalTransparencyModifier >= 0.99 then
            self:Remove(part)
        else
            self:Draw(part)
        end
    end))

    table.insert(conns, part.Destroying:Connect(function()
        self:Remove(part)
    end))

    self.Connections[part] = conns
end

function MeowWireframe:Scan(container)
    if not container then return end
    for _, p in ipairs(container:GetDescendants()) do
        if p:IsA("BasePart") and p.Transparency < 1 then
            self:Watch(p)
            if p.LocalTransparencyModifier < 0.99 then
                self:Draw(p)
            end
        end
    end
end

function MeowWireframe:Remove(part)
    local entry = self.ActiveWires[part]
    if entry then
        pcall(function() entry.Wire:Destroy() end)
        self.ActiveWires[part] = nil
        if part.Parent then
            pcall(function() part.Transparency = entry.OrigTransparency or 0 end)
        end
    end
    if self.Connections[part] then
        for _, c in ipairs(self.Connections[part]) do pcall(function() c:Disconnect() end) end
        self.Connections[part] = nil
    end
end

function MeowWireframe:Clear()
    for part in pairs(self.ActiveWires) do
        self:Remove(part)
    end
    for part, conns in pairs(self.Connections) do
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    end
    table.clear(self.ActiveWires)
    table.clear(self.Connections)
    self.CurrentGun = nil
    self.CurrentArms = nil
end

function MeowWireframe:GetGunModel()

    pcall(function()
        local fc = rawget(getgenv(), "FighterController")
        if fc and fc.LocalFighter and fc.LocalFighter.EquippedItem then
            local vm = fc.LocalFighter.EquippedItem.ViewModel
            if vm and vm.ItemModel then return vm.ItemModel end
        end
    end)

    local vms = Camera:FindFirstChild("ViewModels") or Workspace:FindFirstChild("ViewModels")
    if vms then
        for _, vm in ipairs(vms:GetChildren()) do
            local item = vm:FindFirstChild("ItemModel") or vm:FindFirstChild("ItemVisual") or vm:FindFirstChild("Weapon")
            if item then return item end
            if #vm:GetChildren() > 0 then return vm end
        end
    end

    local char = LocalPlayer and LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then return tool end
    return nil
end

function MeowWireframe:GetArmsModel()
    local vms = Camera:FindFirstChild("ViewModels") or Workspace:FindFirstChild("ViewModels")
    if vms then
        for _, vm in ipairs(vms:GetChildren()) do
            local arms = vm:FindFirstChild("Arms") or vm:FindFirstChild("LeftArm") or vm:FindFirstChild("RightArm")
            if arms then return arms.Parent end
        end
    end
    return nil
end

function MeowWireframe:Update()
    if not self.Enabled and not self.ArmEnabled then
        if self.CurrentGun or self.CurrentArms then
            self:Clear()
        end
        return
    end

    if self.Enabled then
        local gun = self:GetGunModel()
        if gun ~= self.CurrentGun then
            if self.CurrentGun then
                for part in pairs(self.ActiveWires) do
                    if part:IsDescendantOf(self.CurrentGun) then self:Remove(part) end
                end
            end
            self.CurrentGun = gun
            if self.CurrentGun then
                self:Scan(self.CurrentGun)
            end
        end
    elseif self.CurrentGun then
        for part in pairs(self.ActiveWires) do
            if part:IsDescendantOf(self.CurrentGun) then self:Remove(part) end
        end
        self.CurrentGun = nil
    end

    if self.ArmEnabled then
        local arms = self:GetArmsModel()
        if arms ~= self.CurrentArms then
            if self.CurrentArms then
                for part in pairs(self.ActiveWires) do
                    if part:IsDescendantOf(self.CurrentArms) then self:Remove(part) end
                end
            end
            self.CurrentArms = arms
            if self.CurrentArms then
                self:Scan(self.CurrentArms)
            end
        end
    elseif self.CurrentArms then
        for part in pairs(self.ActiveWires) do
            if part:IsDescendantOf(self.CurrentArms) then self:Remove(part) end
        end
        self.CurrentArms = nil
    end

    for part, entry in pairs(self.ActiveWires) do
        if part.Parent and part.Size ~= entry.Size then
            entry.Size = part.Size
            self:Rebuild(entry.Wire, part)
        end
    end
end

getgenv().MeowWireframe = MeowWireframe

local function restoreWeaponVisuals()
    MeowWireframe:Clear()
    if meowState.WeaponHighlight then
        pcall(function() meowState.WeaponHighlight:Destroy() end)
        meowState.WeaponHighlight = nil
    end
    for part, props in pairs(meowState.SavedPartProps) do
        pcall(function()
            if part and part.Parent then
                part.Material = props.Material
                part.Color = props.Color
                part.Transparency = props.Transparency
            end
        end)
    end
    table.clear(meowState.SavedPartProps)
end

local function updateWeaponVisuals()

    MeowWireframe.Enabled     = flags.item_wireframe or false
    MeowWireframe.ArmEnabled  = flags.arm_appearance or false
    MeowWireframe.Color       = flags.wireframe_color or Color3.fromRGB(255, 255, 255)
    MeowWireframe.Color2      = flags.wireframe_color2 or Color3.fromRGB(0, 162, 255)
    MeowWireframe.ColorMiddle = (flags.wireframe_color or Color3.fromRGB(255, 255, 255)):Lerp(flags.wireframe_color2 or Color3.fromRGB(0, 162, 255), 0.5)
    MeowWireframe.Transparency = flags.item_chams_transparency or 0

    MeowWireframe:Update()

    local itemVisual = MeowWireframe:GetGunModel()
    if not itemVisual then return end

    local chamsEnabled = flags.item_chams
    local chamsMat = flags.item_chams_material or "ForceField"
    local chamsColor = flags.item_chams_color or Color3.fromRGB(0, 162, 255)
    local chamsTrans = flags.item_chams_transparency or 0.2

    if chamsEnabled and not MeowWireframe.Enabled then
        for _, part in ipairs(itemVisual:GetDescendants()) do
            if part:IsA("BasePart") then
                if not meowState.SavedPartProps[part] then
                    meowState.SavedPartProps[part] = {
                        Material     = part.Material,
                        Color        = part.Color,
                        Transparency = part.Transparency,
                    }
                end
                pcall(function()
                    if Enum.Material[chamsMat] then
                        part.Material = Enum.Material[chamsMat]
                    else
                        part.Material = Enum.Material.ForceField
                    end
                    part.Color = chamsColor
                    part.Transparency = chamsTrans
                end)
            end
        end
    end
end
local function initProceduralDrawings()
    for i = 1, 4 do
        local l = Drawing.new("Line")
        local o = Drawing.new("Line")
        table.insert(meowState.CrosshairLines, l)
        table.insert(meowState.CrosshairOutlines, o)
    end
    local dot = Drawing.new("Circle")
    dot.Filled = true
    dot.Visible = false
    meowState.CrosshairDot = dot

    local dotOut = Drawing.new("Circle")
    dotOut.Filled = false
    dotOut.Visible = false
    meowState.CrosshairDotOutline = dotOut

    local circ = Drawing.new("Circle")
    circ.Thickness = 1.5
    circ.NumSides = 64
    circ.Visible = false
    meowState.SilentFovCircle = circ

    local aCirc = Drawing.new("Circle")
    aCirc.Thickness = 1.5
    aCirc.NumSides = 64
    aCirc.Visible = false
    meowState.AimbotFovCircle = aCirc
end

local crosshairRotAngle = 0
local function updateCrosshair()
    if not flags.crosshair_enabled then
        for _, l in ipairs(meowState.CrosshairLines) do l.Visible = false end
        for _, o in ipairs(meowState.CrosshairOutlines) do o.Visible = false end
        if meowState.CrosshairDot then meowState.CrosshairDot.Visible = false end
        if meowState.CrosshairDotOutline then meowState.CrosshairDotOutline.Visible = false end
        return
    end

    local center = Camera.ViewportSize / 2
    local length = flags.crosshair_length or 14
    local offset = flags.crosshair_offset or 6
    local thickness = flags.crosshair_thickness or 2
    local col = flags.crosshair_color or Color3.fromRGB(0, 162, 255)

    if flags.crosshair_rainbow then
        local spd = (flags.crosshair_rainbow_speed or 2) * 0.1
        col = Color3.fromHSV((tick() * spd) % 1, 0.85, 1)
    end

    local rotSpeed = flags.crosshair_rotation_speed or 0
    local staticRot = flags.crosshair_rotation or 0
    local bounceSpeed = flags.crosshair_bounce_speed or 0
    local bounceAmp = flags.crosshair_bounce_amp or 0

    if rotSpeed > 0 then
        crosshairRotAngle = (crosshairRotAngle + (rotSpeed * 0.05)) % (math.pi * 2)
    end

    local currentOffset = offset
    if bounceSpeed > 0 and bounceAmp > 0 then
        currentOffset = offset + ((math.sin(tick() * bounceSpeed) + 1) / 2 * bounceAmp)
    end

    if flags.crosshair_hit_pulse and (os.clock() - meowState.LastHitmarkerTime < 0.16) then
        currentOffset = currentOffset + 6
    end

    if flags.crosshair_dot and meowState.CrosshairDot then
        local dot = meowState.CrosshairDot
        local dotOut = meowState.CrosshairDotOutline
        local dotSize = flags.crosshair_dot_size or 2.5
        local dotColor = flags.crosshair_dot_color or col

        dot.Position = center
        dot.Radius = dotSize
        dot.Color = dotColor
        dot.Visible = true

        if (flags.crosshair_outline ~= false) and dotOut then
            dotOut.Position = center
            dotOut.Radius = dotSize + 1.2
            dotOut.Thickness = 1.5
            dotOut.Color = Color3.fromRGB(0, 0, 0)
            dotOut.Visible = true
        elseif dotOut then
            dotOut.Visible = false
        end
    else
        if meowState.CrosshairDot then meowState.CrosshairDot.Visible = false end
        if meowState.CrosshairDotOutline then meowState.CrosshairDotOutline.Visible = false end
    end

    local totalAngleBase = crosshairRotAngle + math.rad(staticRot)

    for idx = 1, 4 do
        local line = meowState.CrosshairLines[idx]
        local out = meowState.CrosshairOutlines[idx]

        if flags.crosshair_t_shape and idx == 1 then
            if line then line.Visible = false end
            if out then out.Visible = false end
        else
            local angle = totalAngleBase + ((idx - 1) * (math.pi / 2))
            local dir = Vector2.new(math.cos(angle), math.sin(angle))
            local fromP = center + dir * currentOffset
            local toP = center + dir * (currentOffset + length)

            if line then
                line.From = fromP
                line.To = toP
                line.Thickness = thickness
                line.Color = col
                line.Visible = true
            end

            if out and (flags.crosshair_outline ~= false) then
                out.From = center + dir * math.max(0, currentOffset - 1)
                out.To = center + dir * (currentOffset + length + 1)
                out.Thickness = thickness + 2
                out.Color = Color3.fromRGB(0, 0, 0)
                out.Visible = true
            elseif out then
                out.Visible = false
            end
        end
    end
end

local fovSpinAngle = 0
local function updateFovCircles()
    local center = Camera.ViewportSize / 2

    local circ = meowState.SilentFovCircle
    if circ then
        if flags.silent_aim_visualise_range and flags.silent_aim_enabled then
            circ.Position = center
            circ.Radius = flags.fov_radius_smoothed or 120
            circ.Color = flags.fov_color or Color3.fromRGB(0, 162, 255)
            if flags.fov_spin_value then
                fovSpinAngle = (fovSpinAngle + ((flags.fov_rotation_speed or 10) * 0.005)) % 1
                circ.Color = Color3.fromHSV(fovSpinAngle, 0.8, 1)
            end
            circ.Filled = flags.fov_filled == true
            circ.Transparency = flags.fov_filled and 0.25 or 1
            circ.Visible = true
        else
            circ.Visible = false
        end
    end

    local aCirc = meowState.AimbotFovCircle
    if aCirc then
        if flags.aimbot_enabled and flags.aimbot_visualise_range then
            aCirc.Position = center
            aCirc.Radius = flags.aimbot_radius_smoothed or 90
            aCirc.Color = Color3.fromRGB(120, 180, 255)
            aCirc.Visible = true
        else
            aCirc.Visible = false
        end
    end
end

local function createEspEntry(player)
    local corners = {}
    for i = 1, 8 do
        local l = Drawing.new("Line")
        l.Visible = false
        corners[i] = l
    end
    return {
        Player = player,
        Box = Drawing.new("Square"),
        BoxOutline = Drawing.new("Square"),
        BoxFill = Drawing.new("Square"),
        BoxCorners = corners,
        HealthBar = Drawing.new("Square"),
        HealthBarOutline = Drawing.new("Square"),
        HealthNumber = Drawing.new("Text"),
        AmmoBar = Drawing.new("Square"),
        AmmoBarOutline = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Weapon = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        Rank = Drawing.new("Text"),
        Streak = Drawing.new("Text"),
        Deflecting = Drawing.new("Text"),
        HeadMarker = Drawing.new("Circle"),
        Tracer = Drawing.new("Line"),
        TracerOutline = Drawing.new("Line"),
    }
end

local function cleanEspEntry(entry)
    if not entry then return end
    pcall(function() entry.Box:Destroy() end)
    pcall(function() entry.BoxOutline:Destroy() end)
    pcall(function() entry.BoxFill:Destroy() end)
    if entry.BoxCorners then
        for _, l in ipairs(entry.BoxCorners) do
            pcall(function() l:Destroy() end)
        end
    end
    pcall(function() entry.HealthBar:Destroy() end)
    pcall(function() entry.HealthBarOutline:Destroy() end)
    pcall(function() entry.HealthNumber:Destroy() end)
    pcall(function() entry.AmmoBar:Destroy() end)
    pcall(function() entry.AmmoBarOutline:Destroy() end)
    pcall(function() entry.Name:Destroy() end)
    pcall(function() entry.Weapon:Destroy() end)
    pcall(function() entry.Distance:Destroy() end)
    pcall(function() entry.Rank:Destroy() end)
    pcall(function() entry.Streak:Destroy() end)
    pcall(function() entry.Deflecting:Destroy() end)
    pcall(function() entry.HeadMarker:Destroy() end)
    pcall(function() entry.Tracer:Destroy() end)
    pcall(function() entry.TracerOutline:Destroy() end)
end

local function formatEspSurround(text, surround)
    surround = surround or "None"
    if surround == "[]" then return "[" .. text .. "]"
    elseif surround == "()" then return "(" .. text .. ")"
    elseif surround == "<>" then return "<" .. text .. ">"
    elseif surround == "{}" then return "{" .. text .. "}"
    end
    return text
end

local function formatEspCase(text, tcase)
    tcase = tcase or "Standard"
    if tcase == "UPPERCASE" then return string.upper(text)
    elseif tcase == "lowercase" then return string.lower(text)
    end
    return text
end

local function updateEsp()
    if not flags.esp_enabled and not flags.esp_team_enabled then
        for _, entry in pairs(meowState.EspBoxes) do
            entry.Box.Visible = false
            entry.BoxOutline.Visible = false
            entry.BoxFill.Visible = false
            if entry.BoxCorners then
                for _, l in ipairs(entry.BoxCorners) do l.Visible = false end
            end
            entry.HealthBar.Visible = false
            entry.HealthBarOutline.Visible = false
            entry.HealthNumber.Visible = false
            entry.AmmoBar.Visible = false
            entry.AmmoBarOutline.Visible = false
            entry.Name.Visible = false
            entry.Weapon.Visible = false
            entry.Distance.Visible = false
            entry.Rank.Visible = false
            entry.Streak.Visible = false
            entry.Deflecting.Visible = false
            entry.HeadMarker.Visible = false
            entry.Tracer.Visible = false
            entry.TracerOutline.Visible = false
        end
        return
    end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local maxDist = flags.esp_max_distance or 1500

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer then
            local isTeammate = pl.Team ~= nil and pl.Team == LocalPlayer.Team
            if isTeammate and flags.esp_team_check and not flags.esp_team_enabled then
                local e = meowState.EspBoxes[pl]
                if e then
                    e.Box.Visible = false
                    e.BoxOutline.Visible = false
                    e.BoxFill.Visible = false
                    if e.BoxCorners then
                        for _, l in ipairs(e.BoxCorners) do l.Visible = false end
                    end
                    e.HealthBar.Visible = false
                    e.HealthBarOutline.Visible = false
                    e.HealthNumber.Visible = false
                    e.AmmoBar.Visible = false
                    e.AmmoBarOutline.Visible = false
                    e.Name.Visible = false
                    e.Weapon.Visible = false
                    e.Distance.Visible = false
                    e.Rank.Visible = false
                    e.Streak.Visible = false
                    e.Deflecting.Visible = false
                    e.HeadMarker.Visible = false
                    e.Tracer.Visible = false
                    e.TracerOutline.Visible = false
                end
                continue
            end

            local entry = meowState.EspBoxes[pl]
            if not entry then
                entry = createEspEntry(pl)
                meowState.EspBoxes[pl] = entry
            end

            local char = pl.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")

            if char and hum and hum.Health > 0 and root and myRoot then
                local dist = (root.Position - myRoot.Position).Magnitude
                if dist <= maxDist then
                    local scrPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                    if onScreen then
                        local head = char:FindFirstChild("Head")
                        local headPos = head and Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.6, 0)) or scrPos
                        local footPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))

                        local boxHeight = math.abs(headPos.Y - footPos.Y)
                        local boxWidth = flags.esp_box_fit == "Static" and 50 or (boxHeight * 0.65)
                        local boxX = scrPos.X - (boxWidth / 2)
                        local boxY = headPos.Y

                        local showBox = isTeammate and flags.esp_team_boxes or (flags.esp_boxes ~= false and flags.esp_box ~= false)
                        local boxColor = isTeammate and (flags.esp_team_box_color or Color3.fromRGB(80, 180, 255)) or (flags.esp_box_color or Color3.fromRGB(255, 255, 255))
                        local boxStyle = flags.esp_box_style or "Corner"

                        if showBox and boxStyle == "Full" then
                            entry.BoxOutline.Position = Vector2.new(boxX - 1, boxY - 1)
                            entry.BoxOutline.Size = Vector2.new(boxWidth + 2, boxHeight + 2)
                            entry.BoxOutline.Color = Color3.fromRGB(0, 0, 0)
                            entry.BoxOutline.Thickness = 2.5
                            entry.BoxOutline.Visible = true

                            entry.Box.Position = Vector2.new(boxX, boxY)
                            entry.Box.Size = Vector2.new(boxWidth, boxHeight)
                            entry.Box.Color = boxColor
                            entry.Box.Thickness = 1.2
                            entry.Box.Visible = true

                            if entry.BoxCorners then
                                for _, l in ipairs(entry.BoxCorners) do l.Visible = false end
                            end
                        elseif showBox and boxStyle == "Corner" then
                            entry.Box.Visible = false
                            entry.BoxOutline.Visible = false
                            local clen = math.clamp(boxWidth * 0.25, 4, 18)
                            local c = entry.BoxCorners
                            if c and #c >= 8 then
                                c[1].From = Vector2.new(boxX, boxY)
                                c[1].To = Vector2.new(boxX + clen, boxY)
                                c[2].From = Vector2.new(boxX, boxY)
                                c[2].To = Vector2.new(boxX, boxY + clen)

                                c[3].From = Vector2.new(boxX + boxWidth, boxY)
                                c[3].To = Vector2.new(boxX + boxWidth - clen, boxY)
                                c[4].From = Vector2.new(boxX + boxWidth, boxY)
                                c[4].To = Vector2.new(boxX + boxWidth, boxY + clen)

                                c[5].From = Vector2.new(boxX, boxY + boxHeight)
                                c[5].To = Vector2.new(boxX + clen, boxY + boxHeight)
                                c[6].From = Vector2.new(boxX, boxY + boxHeight)
                                c[6].To = Vector2.new(boxX, boxY + boxHeight - clen)

                                c[7].From = Vector2.new(boxX + boxWidth, boxY + boxHeight)
                                c[7].To = Vector2.new(boxX + boxWidth - clen, boxY + boxHeight)
                                c[8].From = Vector2.new(boxX + boxWidth, boxY + boxHeight)
                                c[8].To = Vector2.new(boxX + boxWidth, boxY + boxHeight - clen)

                                for i = 1, 8 do
                                    c[i].Color = boxColor
                                    c[i].Thickness = 1.5
                                    c[i].Visible = true
                                end
                            end
                        else
                            entry.Box.Visible = false
                            entry.BoxOutline.Visible = false
                            if entry.BoxCorners then
                                for _, l in ipairs(entry.BoxCorners) do l.Visible = false end
                            end
                        end

                        if flags.esp_box_fill then
                            entry.BoxFill.Position = Vector2.new(boxX, boxY)
                            entry.BoxFill.Size = Vector2.new(boxWidth, boxHeight)
                            entry.BoxFill.Color = flags.esp_fill_color or Color3.fromRGB(0, 162, 255)
                            entry.BoxFill.Filled = true
                            entry.BoxFill.Transparency = 0.25
                            entry.BoxFill.Visible = true
                        else
                            entry.BoxFill.Visible = false
                        end

                        local showHp = isTeammate and flags.esp_team_health or (flags.esp_health_bars ~= false and flags.esp_health_bar ~= false)
                        local hpPct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        if showHp then
                            local barWidth = 3
                            local fillH = boxHeight * hpPct
                            local hpColor = flags.esp_health_color or Color3.fromRGB(0, 255, 120)
                            if flags.esp_health_mode == "Reactive" then
                                hpColor = Color3.fromRGB(math.floor(255 * (1 - hpPct)), math.floor(255 * hpPct), 40)
                            end

                            entry.HealthBarOutline.Position = Vector2.new(boxX - 6, boxY - 1)
                            entry.HealthBarOutline.Size = Vector2.new(barWidth + 2, boxHeight + 2)
                            entry.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)
                            entry.HealthBarOutline.Filled = true
                            entry.HealthBarOutline.Visible = true

                            entry.HealthBar.Position = Vector2.new(boxX - 5, boxY + (boxHeight - fillH))
                            entry.HealthBar.Size = Vector2.new(barWidth, fillH)
                            entry.HealthBar.Color = hpColor
                            entry.HealthBar.Filled = true
                            entry.HealthBar.Visible = true
                        else
                            entry.HealthBar.Visible = false
                            entry.HealthBarOutline.Visible = false
                        end

                        if flags.esp_health_number and showHp then
                            entry.HealthNumber.Text = tostring(math.floor(hum.Health))
                            entry.HealthNumber.Position = Vector2.new(boxX - 8, boxY + (boxHeight * (1 - hpPct)) - 5)
                            entry.HealthNumber.Size = 10
                            entry.HealthNumber.Color = flags.esp_hp_num_color or Color3.fromRGB(255, 255, 255)
                            entry.HealthNumber.Outline = true
                            entry.HealthNumber.Center = false
                            entry.HealthNumber.Visible = true
                        else
                            entry.HealthNumber.Visible = false
                        end

                        if flags.esp_ammo_bar then
                            local ammoPct = 0.75
                            pcall(function()
                                local tool = char:FindFirstChildOfClass("Tool")
                                if tool and tool:FindFirstChild("Ammo") then
                                    ammoPct = math.clamp(tool.Ammo.Value / (tool:FindFirstChild("MaxAmmo") and tool.MaxAmmo.Value or 30), 0, 1)
                                end
                            end)
                            entry.AmmoBarOutline.Position = Vector2.new(boxX - 1, boxY + boxHeight + 2)
                            entry.AmmoBarOutline.Size = Vector2.new(boxWidth + 2, 4)
                            entry.AmmoBarOutline.Color = Color3.fromRGB(0, 0, 0)
                            entry.AmmoBarOutline.Filled = true
                            entry.AmmoBarOutline.Visible = true

                            entry.AmmoBar.Position = Vector2.new(boxX, boxY + boxHeight + 3)
                            entry.AmmoBar.Size = Vector2.new(boxWidth * ammoPct, 2)
                            entry.AmmoBar.Color = flags.esp_ammo_color or Color3.fromRGB(0, 162, 255)
                            entry.AmmoBar.Filled = true
                            entry.AmmoBar.Visible = true
                        else
                            entry.AmmoBar.Visible = false
                            entry.AmmoBarOutline.Visible = false
                        end

                        local showName = isTeammate and flags.esp_team_names or (flags.esp_names ~= false and flags.esp_name ~= false)
                        if showName then
                            local rawName = flags.esp_display_names and pl.DisplayName or pl.Name
                            local formattedName = formatEspCase(rawName, flags.esp_text_case)
                            formattedName = formatEspSurround(formattedName, flags.esp_text_surround)
                            entry.Name.Text = formattedName
                            entry.Name.Position = Vector2.new(scrPos.X, boxY - (flags.esp_font_size or 13) - 2)
                            entry.Name.Center = true
                            entry.Name.Outline = true
                            entry.Name.Color = isTeammate and (flags.esp_team_name_color or Color3.fromRGB(80, 180, 255)) or (flags.esp_name_color or Color3.fromRGB(240, 240, 240))
                            entry.Name.Size = flags.esp_font_size or 13
                            entry.Name.Visible = true
                        else
                            entry.Name.Visible = false
                        end

                        local flagOffset = 0
                        local flagX = boxX + boxWidth + 4
                        local flagSize = flags.esp_flag_size or 10

                        if flags.esp_weapons ~= false and flags.esp_weapon ~= false then
                            local tool = char:FindFirstChildOfClass("Tool")
                            local wText = tool and tool.Name or "None"
                            wText = formatEspCase(wText, flags.esp_text_case)
                            entry.Weapon.Text = formatEspSurround(wText, flags.esp_flag_surround)
                            entry.Weapon.Position = Vector2.new(flagX, boxY + flagOffset)
                            entry.Weapon.Center = false
                            entry.Weapon.Outline = true
                            entry.Weapon.Color = flags.esp_weapon_color or Color3.fromRGB(220, 220, 220)
                            entry.Weapon.Size = flagSize
                            entry.Weapon.Visible = true
                            flagOffset = flagOffset + flagSize + 1
                        else
                            entry.Weapon.Visible = false
                        end

                        if flags.esp_distance ~= false then
                            local distText = tostring(math.floor(dist)) .. "m"
                            entry.Distance.Text = formatEspSurround(distText, flags.esp_flag_surround)
                            entry.Distance.Position = Vector2.new(flagX, boxY + flagOffset)
                            entry.Distance.Center = false
                            entry.Distance.Outline = true
                            entry.Distance.Color = flags.esp_dist_color or Color3.fromRGB(180, 180, 180)
                            entry.Distance.Size = flagSize
                            entry.Distance.Visible = true
                            flagOffset = flagOffset + flagSize + 1
                        else
                            entry.Distance.Visible = false
                        end

                        if flags.esp_rank then
                            local r = pl:GetAttribute("Rank") or pl:GetAttribute("RankName") or "Unranked"
                            entry.Rank.Text = formatEspSurround(tostring(r), flags.esp_flag_surround)
                            entry.Rank.Position = Vector2.new(flagX, boxY + flagOffset)
                            entry.Rank.Center = false
                            entry.Rank.Outline = true
                            entry.Rank.Color = flags.esp_rank_color or Color3.fromRGB(255, 215, 0)
                            entry.Rank.Size = flagSize
                            entry.Rank.Visible = true
                            flagOffset = flagOffset + flagSize + 1
                        else
                            entry.Rank.Visible = false
                        end

                        if flags.esp_streak then
                            local s = pl:GetAttribute("StatisticDuelsWinStreak") or pl:GetAttribute("WinStreak") or 0
                            entry.Streak.Text = formatEspSurround("WS: " .. tostring(s), flags.esp_flag_surround)
                            entry.Streak.Position = Vector2.new(flagX, boxY + flagOffset)
                            entry.Streak.Center = false
                            entry.Streak.Outline = true
                            entry.Streak.Color = flags.esp_streak_color or Color3.fromRGB(255, 100, 50)
                            entry.Streak.Size = flagSize
                            entry.Streak.Visible = true
                            flagOffset = flagOffset + flagSize + 1
                        else
                            entry.Streak.Visible = false
                        end

                        if flags.esp_deflecting then
                            local isDeflect = false
                            pcall(function()
                                isDeflect = char:GetAttribute("Deflecting") == true
                                    or char:GetAttribute("IsDeflecting") == true
                                    or char:FindFirstChild("DeflectEffect") ~= nil
                                    or char:FindFirstChild("Parry") ~= nil
                            end)
                            if isDeflect then
                                entry.Deflecting.Text = "[DEFLECTING]"
                                entry.Deflecting.Position = Vector2.new(flagX, boxY + flagOffset)
                                entry.Deflecting.Center = false
                                entry.Deflecting.Outline = true
                                entry.Deflecting.Color = flags.esp_deflect_color or Color3.fromRGB(255, 0, 150)
                                entry.Deflecting.Size = flagSize
                                entry.Deflecting.Visible = true
                                flagOffset = flagOffset + flagSize + 1
                            else
                                entry.Deflecting.Visible = false
                            end
                        else
                            entry.Deflecting.Visible = false
                        end

                        if flags.head_marker_enabled and head then
                            entry.HeadMarker.Position = Vector2.new(headPos.X, headPos.Y)
                            entry.HeadMarker.Radius = 4
                            entry.HeadMarker.Color = flags.head_marker_color or Color3.fromRGB(255, 50, 50)
                            entry.HeadMarker.Filled = flags.head_marker_filled == true
                            entry.HeadMarker.Thickness = 1.2
                            entry.HeadMarker.Visible = true
                        else
                            entry.HeadMarker.Visible = false
                        end

                        if flags.esp_tracers then
                            local origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                            if flags.esp_tracer_origin == "Center" then
                                origin = Camera.ViewportSize / 2
                            elseif flags.esp_tracer_origin == "Top" then
                                origin = Vector2.new(Camera.ViewportSize.X / 2, 0)
                            elseif flags.esp_tracer_origin == "Mouse" then
                                origin = UserInputService:GetMouseLocation()
                            end

                            local targetPos = Vector2.new(scrPos.X, footPos.Y)
                            if flags.esp_tracer_target == "Head" then
                                targetPos = Vector2.new(headPos.X, headPos.Y)
                            end

                            if flags.esp_tracer_outline then
                                entry.TracerOutline.From = origin
                                entry.TracerOutline.To = targetPos
                                entry.TracerOutline.Color = flags.esp_tracer_outline_color or Color3.fromRGB(0, 0, 0)
                                entry.TracerOutline.Thickness = (flags.esp_tracer_thickness or 1) + 2
                                entry.TracerOutline.Visible = true
                            else
                                entry.TracerOutline.Visible = false
                            end

                            entry.Tracer.From = origin
                            entry.Tracer.To = targetPos
                            entry.Tracer.Color = flags.esp_tracer_color or Color3.fromRGB(0, 162, 255)
                            entry.Tracer.Thickness = flags.esp_tracer_thickness or 1
                            entry.Tracer.Visible = true
                        else
                            entry.Tracer.Visible = false
                            entry.TracerOutline.Visible = false
                        end
                    else
                        entry.Box.Visible = false
                        entry.BoxOutline.Visible = false
                        entry.BoxFill.Visible = false
                        if entry.BoxCorners then
                            for _, l in ipairs(entry.BoxCorners) do l.Visible = false end
                        end
                        entry.HealthBar.Visible = false
                        entry.HealthBarOutline.Visible = false
                        entry.HealthNumber.Visible = false
                        entry.AmmoBar.Visible = false
                        entry.AmmoBarOutline.Visible = false
                        entry.Name.Visible = false
                        entry.Weapon.Visible = false
                        entry.Distance.Visible = false
                        entry.Rank.Visible = false
                        entry.Streak.Visible = false
                        entry.Deflecting.Visible = false
                        entry.HeadMarker.Visible = false
                        entry.Tracer.Visible = false
                        entry.TracerOutline.Visible = false
                    end
                else
                    entry.Box.Visible = false
                    entry.BoxOutline.Visible = false
                    entry.BoxFill.Visible = false
                    if entry.BoxCorners then
                        for _, l in ipairs(entry.BoxCorners) do l.Visible = false end
                    end
                    entry.HealthBar.Visible = false
                    entry.HealthBarOutline.Visible = false
                    entry.HealthNumber.Visible = false
                    entry.AmmoBar.Visible = false
                    entry.AmmoBarOutline.Visible = false
                    entry.Name.Visible = false
                    entry.Weapon.Visible = false
                    entry.Distance.Visible = false
                    entry.Rank.Visible = false
                    entry.Streak.Visible = false
                    entry.Deflecting.Visible = false
                    entry.HeadMarker.Visible = false
                    entry.Tracer.Visible = false
                    entry.TracerOutline.Visible = false
                end
            else
                entry.Box.Visible = false
                entry.BoxOutline.Visible = false
                entry.BoxFill.Visible = false
                if entry.BoxCorners then
                    for _, l in ipairs(entry.BoxCorners) do l.Visible = false end
                end
                entry.HealthBar.Visible = false
                entry.HealthBarOutline.Visible = false
                entry.HealthNumber.Visible = false
                entry.AmmoBar.Visible = false
                entry.AmmoBarOutline.Visible = false
                entry.Name.Visible = false
                entry.Weapon.Visible = false
                entry.Distance.Visible = false
                entry.Rank.Visible = false
                entry.Streak.Visible = false
                entry.Deflecting.Visible = false
                entry.HeadMarker.Visible = false
                entry.Tracer.Visible = false
                entry.TracerOutline.Visible = false
            end
        end
    end
end

local function updateChams()
    if not flags.chams_enabled then
        for _, hl in pairs(meowState.ChamsHighlights) do hl.Enabled = false end
        return
    end

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character then
            local hl = meowState.ChamsHighlights[pl]
            if not hl or not hl.Parent then
                hl = Instance.new("Highlight")
                hl.Name = "_MeowChams"
                hl.Parent = (gethui and gethui()) or game:GetService("CoreGui")
                meowState.ChamsHighlights[pl] = hl
            end

            hl.Adornee = pl.Character
            hl.FillColor = flags.chams_color or Color3.fromRGB(0, 162, 255)
            hl.OutlineColor = flags.chams_color or Color3.fromRGB(255, 255, 255)
            hl.FillTransparency = flags.chams_fill_transparency or 0.4
            hl.OutlineTransparency = flags.chams_outline_transparency or 0
            hl.DepthMode = (flags.chams_depth_mode == "Occluded") and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
            hl.Enabled = true
        end
    end
end

local originalLightingProps = {
    Ambient              = Lighting.Ambient,
    OutdoorAmbient       = Lighting.OutdoorAmbient,
    FogColor             = Lighting.FogColor,
    FogStart             = Lighting.FogStart,
    FogEnd               = Lighting.FogEnd,
    Brightness           = Lighting.Brightness,
    ClockTime            = Lighting.ClockTime,
    GlobalShadows        = Lighting.GlobalShadows,
    ShadowSoftness       = Lighting.ShadowSoftness,
    ExposureCompensation = Lighting.ExposureCompensation,
    Technology           = Lighting.Technology,
}

local SKYBOX_PRESETS = {
    ["GreenHaze"] = {
        SunAngularSize = 0,
        SkyboxUp = "rbxassetid://160193458", SkyboxDn = "rbxassetid://160193466",
        SkyboxFt = "rbxassetid://160193461", SkyboxBk = "rbxassetid://160193404",
        SkyboxLf = "rbxassetid://160193469", SkyboxRt = "rbxassetid://160193463"
    },
    ["Space2"] = {
        StarCount = 3000, SunAngularSize = 11, MoonAngularSize = 20,
        SkyboxUp = "rbxassetid://11844053742", SkyboxDn = "rbxassetid://11844069700",
        SkyboxFt = "rbxassetid://11844067209", SkyboxBk = "rbxassetid://11844076072",
        SkyboxLf = "rbxassetid://11844063543", SkyboxRt = "rbxassetid://11844058446"
    },
    ["PinkMountains"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://160188588", SkyboxDn = "rbxassetid://160188614",
        SkyboxFt = "rbxassetid://160188609", SkyboxBk = "rbxassetid://160188495",
        SkyboxLf = "rbxassetid://160188589", SkyboxRt = "rbxassetid://160188597"
    },
    ["Valentines"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://11427771954", SkyboxDn = "rbxassetid://11427770685",
        SkyboxFt = "rbxassetid://11427769401", SkyboxBk = "rbxassetid://11427769401",
        SkyboxLf = "rbxassetid://11427769401", SkyboxRt = "rbxassetid://11427769401"
    },
    ["PinkArt"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://79190209626172", SkyboxDn = "rbxassetid://78865378050055",
        SkyboxFt = "rbxassetid://104560113223878", SkyboxBk = "rbxassetid://71607054149497",
        SkyboxLf = "rbxassetid://80395333901607", SkyboxRt = "rbxassetid://87570388049514"
    },
    ["PurplePlanet"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://16262366016", SkyboxDn = "rbxassetid://16262358026",
        SkyboxFt = "rbxassetid://16262360469", SkyboxBk = "rbxassetid://16262356578",
        SkyboxLf = "rbxassetid://16262362003", SkyboxRt = "rbxassetid://16262363873"
    },
    ["Blizzard"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://16653228333", SkyboxDn = "rbxassetid://16653222701",
        SkyboxFt = "rbxassetid://16653224051", SkyboxBk = "rbxassetid://16653221738",
        SkyboxLf = "rbxassetid://16653225849", SkyboxRt = "rbxassetid://16653227200"
    },
    ["Winter"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://155674931", SkyboxDn = "rbxassetid://155674246",
        SkyboxFt = "rbxassetid://155657609", SkyboxBk = "rbxassetid://155657655",
        SkyboxLf = "rbxassetid://155657671", SkyboxRt = "rbxassetid://155657619"
    },
    ["FlamingSunset"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://415688354", SkyboxDn = "rbxassetid://415688193",
        SkyboxFt = "rbxassetid://415688242", SkyboxBk = "rbxassetid://415688378",
        SkyboxLf = "rbxassetid://415688310", SkyboxRt = "rbxassetid://415688274"
    },
    ["Mountains"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://15359412677", SkyboxDn = "rbxassetid://15359411132",
        SkyboxFt = "rbxassetid://15359412131", SkyboxBk = "rbxassetid://15359410490",
        SkyboxLf = "rbxassetid://15359411633", SkyboxRt = "rbxassetid://15359417656"
    },
    ["FPSBoost"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://11457548274", SkyboxDn = "rbxassetid://11457548274",
        SkyboxFt = "rbxassetid://11457548274", SkyboxBk = "rbxassetid://11457548274",
        SkyboxLf = "rbxassetid://11457548274", SkyboxRt = "rbxassetid://11457548274"
    },
    ["AestheticMountains"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 11,
        SkyboxUp = "rbxassetid://15470207755", SkyboxDn = "rbxassetid://15470151245",
        SkyboxFt = "rbxassetid://15470200128", SkyboxBk = "rbxassetid://15470198023",
        SkyboxLf = "rbxassetid://15470202648", SkyboxRt = "rbxassetid://15470204862"
    },
    ["BetterNight3"] = {
        StarCount = 500, SunAngularSize = 21, MoonAngularSize = 1.5,
        SkyboxUp = "rbxassetid://2670644331", SkyboxDn = "rbxassetid://2670643365",
        SkyboxFt = "rbxassetid://2670643214", SkyboxBk = "rbxassetid://2670643994",
        SkyboxLf = "rbxassetid://2670643070", SkyboxRt = "rbxassetid://2670644173"
    },
    ["Galaxy2"] = {
        StarCount = 500, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://14164405298", SkyboxDn = "rbxassetid://14164386126",
        SkyboxFt = "rbxassetid://14164389230", SkyboxBk = "rbxassetid://14164368678",
        SkyboxLf = "rbxassetid://14164398493", SkyboxRt = "rbxassetid://14164402782"
    },
    ["Aesthetic3"] = {
        StarCount = 500, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://151165227", SkyboxDn = "rbxassetid://151165197",
        SkyboxFt = "rbxassetid://151165224", SkyboxBk = "rbxassetid://151165214",
        SkyboxLf = "rbxassetid://151165191", SkyboxRt = "rbxassetid://151165206"
    },
    ["PurpleSpace"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://15983964246", SkyboxDn = "rbxassetid://15983966825",
        SkyboxFt = "rbxassetid://5260817288", SkyboxBk = "rbxassetid://15983968922",
        SkyboxLf = "rbxassetid://15983967420", SkyboxRt = "rbxassetid://15983966246"
    },
    ["Pink"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://271077958", SkyboxDn = "rbxassetid://271077243",
        SkyboxFt = "rbxassetid://271042556", SkyboxBk = "rbxassetid://271042516",
        SkyboxLf = "rbxassetid://271042310", SkyboxRt = "rbxassetid://271042467"
    },
    ["PurpleNight"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://5084576400", SkyboxDn = "rbxassetid://5260653793",
        SkyboxFt = "rbxassetid://5260817288", SkyboxBk = "rbxassetid://5260808177",
        SkyboxLf = "rbxassetid://5260800833", SkyboxRt = "rbxassetid://5260800833"
    },
    ["Flame"] = {
        StarCount = 3000, SunAngularSize = 21, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://6286790025", SkyboxDn = "rbxassetid://6286782353",
        SkyboxFt = "rbxassetid://6286784186", SkyboxBk = "rbxassetid://6286780109",
        SkyboxLf = "rbxassetid://6286785801", SkyboxRt = "rbxassetid://6286788245"
    },
    ["Galaxy3"] = {
        StarCount = 3000, SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://14543371676", SkyboxDn = "rbxassetid://14543358958",
        SkyboxFt = "rbxassetid://14543257810", SkyboxBk = "rbxassetid://14543264135",
        SkyboxLf = "rbxassetid://14543275895", SkyboxRt = "rbxassetid://14543280890"
    },
    ["Storm"] = {
        SunAngularSize = 0, MoonAngularSize = 0,
        SkyboxUp = "rbxassetid://1618913654", SkyboxDn = "rbxassetid://1618913943",
        SkyboxFt = "rbxassetid://1618913244", SkyboxBk = "rbxassetid://1618912481",
        SkyboxLf = "rbxassetid://1618912849", SkyboxRt = "rbxassetid://1618911568"
    },
    ["Vaporwave"] = {
        SkyboxUp = "rbxassetid://14164405298", SkyboxDn = "rbxassetid://14164386126",
        SkyboxFt = "rbxassetid://14164389230", SkyboxBk = "rbxassetid://14164368678",
        SkyboxLf = "rbxassetid://14164398493", SkyboxRt = "rbxassetid://14164402782"
    },
    ["Deep Space"] = {
        SkyboxUp = "rbxassetid://15983964246", SkyboxDn = "rbxassetid://15983966825",
        SkyboxFt = "rbxassetid://5260817288", SkyboxBk = "rbxassetid://15983968922",
        SkyboxLf = "rbxassetid://15983967420", SkyboxRt = "rbxassetid://15983966246"
    },
    ["Synthwave"] = {
        SkyboxUp = "rbxassetid://16642401907", SkyboxDn = "rbxassetid://16642397027",
        SkyboxBk = "rbxassetid://16642396302", SkyboxFt = "rbxassetid://16642398372",
        SkyboxLf = "rbxassetid://16642399309", SkyboxRt = "rbxassetid://16642400745"
    },
    ["Purple Nebula"] = {
        SkyboxUp = "rbxassetid://5084576400", SkyboxDn = "rbxassetid://5260653793",
        SkyboxFt = "rbxassetid://5260817288", SkyboxBk = "rbxassetid://5260808177",
        SkyboxLf = "rbxassetid://5260800833", SkyboxRt = "rbxassetid://5260800833"
    },
    ["Night Sky"] = {
        SkyboxUp = "rbxassetid://2670644331", SkyboxDn = "rbxassetid://2670643365",
        SkyboxFt = "rbxassetid://2670643214", SkyboxBk = "rbxassetid://2670643994",
        SkyboxLf = "rbxassetid://2670643070", SkyboxRt = "rbxassetid://2670644173"
    },
    ["Red Galaxy"] = {
        SkyboxUp = "rbxassetid://14365019327", SkyboxDn = "rbxassetid://14365023350",
        SkyboxBk = "rbxassetid://14365019002", SkyboxFt = "rbxassetid://14365018399",
        SkyboxLf = "rbxassetid://14365018705", SkyboxRt = "rbxassetid://14365018143"
    },
    ["Sunset"] = {
        SkyboxUp = "rbxassetid://415688354", SkyboxDn = "rbxassetid://415688193",
        SkyboxBk = "rbxassetid://415688378", SkyboxFt = "rbxassetid://415688242",
        SkyboxLf = "rbxassetid://415688310", SkyboxRt = "rbxassetid://415688274"
    }
}

local function applySkybox(name)
    if not flags.world_skybox_enabled then
        if meowState.ActiveSkybox then
            pcall(function() meowState.ActiveSkybox:Destroy() end)
            meowState.ActiveSkybox = nil
        end
        if meowState.OriginalSkybox then
            pcall(function() meowState.OriginalSkybox.Parent = Lighting end)
        end
        return
    end

    local preset = SKYBOX_PRESETS[name]
    if not preset then return end

    if not meowState.ActiveSkybox or not meowState.ActiveSkybox.Parent then
        local oldSky = Lighting:FindFirstChildOfClass("Sky")
        if oldSky and oldSky.Name ~= "_MeowSky" then
            meowState.OriginalSkybox = oldSky
            oldSky.Parent = nil
        end
        local newSky = Instance.new("Sky")
        newSky.Name = "_MeowSky"
        newSky.Parent = Lighting
        meowState.ActiveSkybox = newSky
    end

    local sky = meowState.ActiveSkybox
    for prop, val in pairs(preset) do
        pcall(function() sky[prop] = val end)
    end
end

local strippedTextures = {}
local function updateNoTextures()
    if flags.world_no_textures then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Texture") or obj:IsA("Decal") then
                if not strippedTextures[obj] then
                    strippedTextures[obj] = obj.Transparency
                    obj.Transparency = 1
                end
            end
        end
    elseif next(strippedTextures) ~= nil then
        for obj, origTrans in pairs(strippedTextures) do
            if obj and obj.Parent then
                pcall(function() obj.Transparency = origTrans end)
            end
        end
        table.clear(strippedTextures)
    end
end

local function updateWorldLighting(dt)

    if flags.lighting_ambient_enabled then
        Lighting.Ambient = flags.lighting_ambient_color or Color3.fromRGB(150, 150, 150)
    elseif originalLightingProps.Ambient then
        Lighting.Ambient = originalLightingProps.Ambient
    end

    if flags.lighting_outdoor_ambient_enabled then
        Lighting.OutdoorAmbient = flags.lighting_outdoor_ambient_color or Color3.fromRGB(120, 120, 140)
    elseif originalLightingProps.OutdoorAmbient then
        Lighting.OutdoorAmbient = originalLightingProps.OutdoorAmbient
    end

    if flags.lighting_brightness_enabled then
        Lighting.Brightness = flags.lighting_brightness_value or 2
    elseif originalLightingProps.Brightness then
        Lighting.Brightness = originalLightingProps.Brightness
    end

    if flags.lighting_clocktime_enabled then
        Lighting.ClockTime = flags.lighting_clocktime_value or 14
    elseif flags.world_sky_autorotate then
        local spd = (flags.world_sky_rotate_speed or 100) / 100
        Lighting.ClockTime = (Lighting.ClockTime + (dt * spd)) % 24
    elseif originalLightingProps.ClockTime then
        Lighting.ClockTime = originalLightingProps.ClockTime
    end

    if flags.lighting_fog_enabled then
        Lighting.FogColor = flags.lighting_fog_color or Color3.fromRGB(160, 160, 180)
        Lighting.FogStart = flags.lighting_fog_start or 0
        Lighting.FogEnd   = flags.lighting_fog_end or 1000
    elseif flags.world_no_fog then
        Lighting.FogStart = 0
        Lighting.FogEnd   = 1000000
    elseif originalLightingProps.FogColor then
        Lighting.FogColor = originalLightingProps.FogColor
        Lighting.FogStart = originalLightingProps.FogStart
        Lighting.FogEnd   = originalLightingProps.FogEnd
    end

    if flags.lighting_shadows_enabled ~= nil then
        Lighting.GlobalShadows = flags.lighting_shadows_enabled
        if flags.lighting_shadow_softness then
            Lighting.ShadowSoftness = flags.lighting_shadow_softness
        end
    end

    if flags.lighting_exposure_enabled then
        Lighting.ExposureCompensation = flags.lighting_exposure_value or 0
    elseif originalLightingProps.ExposureCompensation then
        Lighting.ExposureCompensation = originalLightingProps.ExposureCompensation
    end

    if flags.lighting_technology_enabled and flags.lighting_technology then
        pcall(function()
            if Enum.Technology[flags.lighting_technology] then
                Lighting.Technology = Enum.Technology[flags.lighting_technology]
            end
        end)
    end

    if flags.color_correction_enabled then
        local cc = Lighting:FindFirstChild("_MeowColorCorrection")
        if not cc then
            cc = Instance.new("ColorCorrectionEffect")
            cc.Name = "_MeowColorCorrection"
            cc.Parent = Lighting
        end
        cc.TintColor  = flags.cc_tint_color or Color3.fromRGB(255, 255, 255)
        cc.Saturation = flags.cc_saturation or 0
        cc.Contrast   = flags.cc_contrast or 0
        cc.Brightness = flags.cc_brightness or 0
        cc.Enabled    = true
    else
        local cc = Lighting:FindFirstChild("_MeowColorCorrection")
        if cc then cc.Enabled = false end
    end

    if flags.atmosphere_enabled then
        local atm = Lighting:FindFirstChild("_MeowAtmosphere")
        if not atm then
            atm = Instance.new("Atmosphere")
            atm.Name = "_MeowAtmosphere"
            atm.Parent = Lighting
        end
        atm.Color   = flags.atmosphere_color or Color3.fromRGB(199, 170, 107)
        atm.Decay   = flags.atmosphere_decay or Color3.fromRGB(106, 112, 125)
        atm.Density = flags.atmosphere_density or 0.3
        atm.Haze    = flags.atmosphere_haze or 1
        atm.Glare   = flags.atmosphere_glare or 0
    else
        local atm = Lighting:FindFirstChild("_MeowAtmosphere")
        if atm then pcall(function() atm:Destroy() end) end
    end

    updateNoTextures()

    if flags.anti_flash then
        pcall(function()
            local fb = Lighting:FindFirstChild("Flashbang") or Camera:FindFirstChild("Flashbang")
            if fb then fb:Destroy() end
        end)
    end
    if flags.anti_shake then
        pcall(function()
            local shake = Camera:FindFirstChild("CameraShake") or Camera:FindFirstChild("Shake")
            if shake then shake:Destroy() end
        end)
    end
end

local PagesModule
local ItemLibModule
pcall(function()
    local ps = LocalPlayer:FindFirstChild("PlayerScripts") or LocalPlayer:WaitForChild("PlayerScripts", 0.5)
    if ps and ps:FindFirstChild("Modules") then
        local uiMod = ps.Modules:FindFirstChild("UserInterface")
        if uiMod and uiMod:FindFirstChild("Pages") then
            PagesModule = require(uiMod.Pages)
        end
    end
end)
pcall(function()
    local rep = game:GetService("ReplicatedStorage")
    if rep:FindFirstChild("Modules") and rep.Modules:FindFirstChild("ItemLibrary") then
        ItemLibModule = require(rep.Modules.ItemLibrary)
    end
end)

local autoLoadoutFinished = false
local function runAutoLoadout()
    if not flags.auto_loadout_enabled then return end
    if not PagesModule or not PagesModule.PageSystem then return end

    local currentPage = PagesModule.PageSystem.CurrentPage
    if currentPage and currentPage.Name == "PickWeapons" then
        local slotMap = {
            Primary   = 1,
            Secondary = 2,
            Melee     = 3,
            Utility   = 4,
        }
        local weaponChoices = {
            Primary   = flags.auto_loadout_primary or "Assault Rifle",
            Secondary = flags.auto_loadout_secondary or "Handgun",
            Melee     = flags.auto_loadout_melee or "Fists",
            Utility   = flags.auto_loadout_utility or "Grenade",
        }

        for slotName, weaponName in pairs(weaponChoices) do
            local slotId = slotMap[slotName]
            if slotId and weaponName then
                local oldId = getthreadidentity and getthreadidentity() or 7
                if type(setthreadidentity) == "function" then pcall(function() setthreadidentity(2) end) end
                if currentPage and type(currentPage.PickWeapon) == "function" then pcall(function() currentPage:PickWeapon(slotId, weaponName) end) end
                if type(setthreadidentity) == "function" then pcall(function() setthreadidentity(oldId) end) end
            end
        end

        if flags.auto_loadout_finish and not autoLoadoutFinished then
            autoLoadoutFinished = true
            task.spawn(function()
                task.wait(0.12)
                pcall(function() currentPage:Finish() end)
            end)
        end
    else
        autoLoadoutFinished = false
    end
end

local function runAutoQueue()
    if not flags.auto_queue_enabled then return end
    if not PagesModule or not PagesModule.PageSystem then return end

    local currentPage = PagesModule.PageSystem.CurrentPage
    if currentPage and currentPage.Name == "GameOver" then
        pcall(function()
            if currentPage.PlayAgain then
                currentPage:PlayAgain()
            elseif currentPage.Queue then
                currentPage:Queue()
            end
        end)
    end
end

local function runBunnyHop()
    if not movementState.BHopEnabled then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.FloorMaterial ~= Enum.Material.Air then
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end

local function runSpoofers()
    if flags.status_spoof_enabled and flags.status_spoof_value then
        pcall(function()
            LocalPlayer:SetAttribute("PlayerStatus", flags.status_spoof_value)
        end)
    end
end

local function runCombatAimbot()
    if not flags.aimbot_enabled or not flags.aimbot_active then return end
    local target = get_target()
    if target and target.HitPart then
        local camPos = Camera.CFrame.Position
        local targetPos = target.HitPart.Position
        local targetCFrame = CFrame.new(camPos, targetPos)
        local smooth = flags.aimbot_smooth_step or 6
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, 1 / smooth)
    end
end

local function runMeleeAura()
    if not flags.knife_rage then return end
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local now = os.clock()
    if now - meowState.LastMeleeAttack < 0.12 then return end

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character then
            local root = pl.Character:FindFirstChild("HumanoidRootPart")
            local hum = pl.Character:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 then
                local dist = (root.Position - myRoot.Position).Magnitude
                if dist <= (flags.melee_safe_reach or 12) then
                    meowState.LastMeleeAttack = now
                    pcall(function()
                        if flags.melee_auto_face_back ~= false then
                            myRoot.CFrame = CFrame.new(myRoot.Position, myRoot.Position - root.CFrame.LookVector)
                        end
                        local tool = myChar:FindFirstChildOfClass("Tool")
                        if tool then tool:Activate() end
                    end)
                    break
                end
            end
        end
    end
end

local function runAntiAim()
    if not flags.antiaim_enabled then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local pitchVal = antiaim_pitch(flags.antiaim_pitch, flags.antiaim_custom_pitch)
    local yawVal = antiaim_yaw(flags.antiaim_yaw, flags.antiaim_spin_speed, flags.antiaim_jitter_range)

    pcall(function()
        local baseLook = Camera.CFrame.LookVector
        local baseAngle = math.atan2(-baseLook.X, -baseLook.Z)
        local rot = CFrame.Angles(0, baseAngle + math.rad(yawVal), 0) * CFrame.Angles(math.rad(pitchVal), 0, 0)
        root.CFrame = CFrame.new(root.Position) * rot
    end)
end

local function updateCameraAndWorld(dt)

    if flags.third_person then
        pcall(function()
            local char = LocalPlayer.Character
            if char and LocalPlayer.CameraMode ~= Enum.CameraMode.Classic then
                LocalPlayer.CameraMode = Enum.CameraMode.Classic
            end
        end)
    end

    if flags.camera_fov_enabled and Camera then
        if not meowState.OriginalCameraFov then
            meowState.OriginalCameraFov = Camera.FieldOfView
        end
        Camera.FieldOfView = flags.camera_fov or 90
    elseif meowState.OriginalCameraFov and Camera then
        Camera.FieldOfView = meowState.OriginalCameraFov
        meowState.OriginalCameraFov = nil
    end

    if flags.world_sky_autorotate then
        local spd = (flags.world_sky_rotate_speed or 100) / 100
        Lighting.ClockTime = (Lighting.ClockTime + (dt * spd)) % 24
    end

    if flags.anti_flash then
        pcall(function()
            local fb = Lighting:FindFirstChild("Flashbang") or Camera:FindFirstChild("Flashbang")
            if fb then fb:Destroy() end
        end)
    end
end

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if not checkcaller() and flags.silent_aim_enabled then
        if (method == "Raycast" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRay") and self == Workspace then
            local origin = args[1]

            if fakePos.Enabled and fakePos.VirtualCF then
                origin = fakePos.VirtualCF.Position
                args[1] = origin
            end
            local target = meowState.CurrentTarget or get_target()
            if target and target.HitPart then
                local hitChance = flags.hit_chance or 100
                if math.random(1, 100) <= hitChance then
                    local targetDir = (target.HitPart.Position - origin).Unit * 1000
                    args[2] = targetDir
                    if fakePos.Enabled and fakePos.AutoHandoff then
                        fakePos.HandoffTicks = 2
                    end
                    return oldNamecall(self, table.unpack(args))
                end
            end
        end
    end

    return oldNamecall(self, ...)
end)

-- ============================================================
-- RAYFIELD ADAPTER v2 — DÜZELTİLMİŞ (MOBİL UYUMLU)
-- ============================================================
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

local _notif = {}
_notif.__index = _notif
function _notif:create_notification(opts)
    opts = opts or {}
    pcall(function()
        Rayfield:Notify({
            Title = opts.name or "Bildirim",
            Content = opts.info or "",
            Duration = opts.lifetime or 3,
        })
    end)
end

local Library = {}
Library.flags = {}
Library.config_flags = {}
Library.connections = {}
Library.notifications = _notif
Library.directory = "sleepy"
Library.folders = { "/fonts", "/configs" }
Library.current_open = nil
Library.window_cfg = nil
Library.window_items = nil

Library.tween = function() end
Library.resizify = function() end
Library.draggify = function() end
Library.close_element = function() end
Library.update_theme = function() end
Library.apply_theme = function() end
Library.set_theme = Library.update_theme
Library.update_config_list = function() end
Library.load_config = function() end
Library.convert = function() return nil end
Library.convert_enum = function() return nil end
Library.mouse_in_frame = function() return false end
Library.round = function(n, f) f = f or 1; return math.floor(n*(1/f)+0.5)/(1/f) end
Library.next_flag = function() return "flag_" .. tostring(math.random(1, 1e9)) end
Library.connection = function(_, signal, cb)
    local c = signal:Connect(cb)
    table.insert(Library.connections, c)
    return c
end
Library.create = function(_, className, opts)
    local inst = Instance.new(className)
    for p, v in pairs(opts or {}) do pcall(function() inst[p] = v end) end
    return inst
end
Library.get_config = function()
    local out = {}
    for k, v in pairs(Library.flags) do
        if type(v) ~= "function" and type(v) ~= "userdata" and type(v) ~= "thread" then
            out[k] = v
        end
    end
    return game:GetService("HttpService"):JSONEncode(out)
end
Library.unload_menu = function() pcall(function() Rayfield:Destroy() end) end
Library.init_config = function() end

-- Mobil Açma/Kapatma Tuşu (Floating Toggle Button) Ekran Butonu
pcall(function()
    local coreGui = (gethui and gethui()) or game:GetService("CoreGui")
    local mobileGui = Instance.new("ScreenGui")
    mobileGui.Name = "_SleepyMobileToggle"
    mobileGui.ResetOnSpawn = false
    mobileGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    mobileGui.Parent = coreGui

    local openBtn = Instance.new("TextButton")
    openBtn.Name = "ToggleMenuButton"
    openBtn.Size = UDim2.fromOffset(50, 50)
    openBtn.Position = UDim2.new(0, 20, 0.5, -25)
    openBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 17)
    openBtn.BorderSizePixel = 0
    openBtn.Text = "🌙"
    openBtn.TextSize = 24
    openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    openBtn.Parent = mobileGui

    Instance.new("UICorner", openBtn).CornerRadius = UDim.new(1, 0)
    local uis = Instance.new("UIStroke", openBtn)
    uis.Color = Color3.fromRGB(0, 162, 255)
    uis.Thickness = 2

    local menuVisible = true
    openBtn.MouseButton1Click:Connect(function()
        menuVisible = not menuVisible
        pcall(function()
            -- Rayfield ana penceresini bulup görünürlüğünü değiştirme
            for _, child in ipairs(coreGui:GetChildren()) do
                if child:IsA("ScreenGui") and child.Name ~= "_SleepyMobileToggle" and child.Name ~= "_MeowTargetHUD" and child.Name ~= "_MeowMusicPlayerGui" and child.Name ~= "_MeowKeybindsWidget" then
                    local mainFrame = child:FindFirstChild("Parent") or child:FindFirstChildOfClass("Frame")
                    if mainFrame then
                        child.Enabled = menuVisible
                    end
                end
            end
        end)
    end)
end)

-- ============================================================
-- WINDOW
-- ============================================================
function Library:window(properties)
    properties = properties or {}
    local win = Rayfield:CreateWindow({
        name = (properties.name or "Hub") .. (properties.suffix or ""),
        subtitle = properties.gameInfo or properties.game_info or "",
        sidebarLayout = true,
    })
    Library.window_cfg = properties
    Library.window_items = {}
    local self_obj = setmetatable({
        _rayfield_win = win,
        _parent_win = win,
        items = {},
    }, Library)
    return self_obj
end

-- ============================================================
-- TAB
-- ============================================================
function Library:tab(properties)
    properties = properties or {}
    local win = self._rayfield_win or self._parent_win
    if not win then return end

    local subTabs = properties.tabs or properties.Tabs or { "Main" }
    local groupName = properties.name or "Tab"
    local icon = properties.icon or 4483362458

    local results = {}

    for _, subName in ipairs(subTabs) do
        local rfTab = win:CreateTab({
            name = tostring(groupName) .. " / " .. tostring(subName),
            icon = icon,
        })

        local tabContext = setmetatable({
            _rayfield_tab = rfTab,
            _parent_win = win,
            items = {},
        }, Library)

        tabContext.column = function(_, _)
            return setmetatable({
                _rayfield_tab = rfTab,
                _parent_win = win,
                items = {},
            }, Library)
        end

        table.insert(results, tabContext)
    end

    return table.unpack(results)
end

-- ============================================================
-- COLUMN
-- ============================================================
function Library:column(_)
    return setmetatable({
        _rayfield_tab = self._rayfield_tab,
        _parent_win = self._parent_win,
        items = {},
    }, Library)
end

-- ============================================================
-- SECTION
-- ============================================================
function Library:section(properties)
    properties = properties or {}
    local rfTab = self._rayfield_tab
    local ctx = setmetatable({
        _rayfield_tab = rfTab,
        _parent_win = self._parent_win,
        items = {},
    }, Library)

    if rfTab and rfTab.CreateSection then
        pcall(function()
            rfTab:CreateSection(properties.name or "Section")
        end)
    end

    return ctx
end

-- ============================================================
-- BİLEŞENLER
-- ============================================================

function Library:toggle(options)
    options = options or {}
    local rfTab = self._rayfield_tab
    local flag = options.flag or self:next_flag()
    local defaultVal = options.default or false
    local ctx = setmetatable({ flag = flag, items = {} }, Library)

    Library.flags[flag] = defaultVal

    if rfTab then
        pcall(function()
            rfTab:CreateToggle({
                name = options.name or "Toggle",
                currentValue = defaultVal,
                flag = flag,
                callback = function(v)
                    Library.flags[flag] = v
                    if options.callback then pcall(options.callback, v) end
                end,
            })
        end)
    end

    ctx.set = function(v)
        Library.flags[flag] = v
        if options.callback then pcall(options.callback, v) end
    end
    Library.config_flags[flag] = ctx.set
    return ctx
end

function Library:slider(options)
    options = options or {}
    local rfTab = self._rayfield_tab
    local flag = options.flag or self:next_flag()
    local defaultVal = options.default or 0
    local ctx = setmetatable({ flag = flag, items = {} }, Library)

    Library.flags[flag] = defaultVal

    if rfTab then
        pcall(function()
            rfTab:CreateSlider({
                name = options.name or "Slider",
                range = { options.min or 0, options.max or 100 },
                increment = options.interval or 1,
                suffix = options.suffix or "",
                currentValue = defaultVal,
                flag = flag,
                callback = function(v)
                    Library.flags[flag] = v
                    if options.callback then pcall(options.callback, v) end
                end,
            })
        end)
    end

    ctx.set = function(v)
        Library.flags[flag] = v
        if options.callback then pcall(options.callback, v) end
    end
    Library.config_flags[flag] = ctx.set
    return ctx
end

function Library:dropdown(options)
    options = options or {}
    local rfTab = self._rayfield_tab
    local flag = options.flag or self:next_flag()
    local opts = options.items or options.options or {}
    local defaultVal = options.default or opts[1] or ""
    local isMulti = options.multi == true
    local ctx = setmetatable({ flag = flag, items = {} }, Library)

    Library.flags[flag] = defaultVal

    if rfTab and #opts > 0 then
        pcall(function()
            rfTab:CreateDropdown({
                name = options.name or "Dropdown",
                options = opts,
                currentOption = isMulti and { defaultVal } or { defaultVal },
                multipleOptions = isMulti,
                flag = flag,
                callback = function(v)
                    Library.flags[flag] = v
                    if options.callback then pcall(options.callback, v) end
                end,
            })
        end)
    end

    ctx.set = function(v)
        Library.flags[flag] = v
        if options.callback then pcall(options.callback, v) end
    end
    Library.config_flags[flag] = ctx.set
    return ctx
end

function Library:colorpicker(options)
    options = options or {}
    local rfTab = self._rayfield_tab
    local flag = options.flag or self:next_flag()
    local col = options.color or Color3.fromRGB(255, 255, 255)
    local ctx = setmetatable({ flag = flag, items = {} }, Library)

    Library.flags[flag] = { Color = col, Transparency = options.alpha or 0 }

    if rfTab then
        pcall(function()
            rfTab:CreateColorPicker({
                name = options.name or "Color",
                color = col,
                flag = flag,
                callback = function(c)
                    Library.flags[flag] = { Color = c, Transparency = 0 }
                    if options.callback then pcall(options.callback, c, 0) end
                end,
            })
        end)
    end

    ctx.set = function(c, a)
        Library.flags[flag] = { Color = c, Transparency = a or 0 }
        if options.callback then pcall(options.callback, c, a or 0) end
    end
    Library.config_flags[flag] = ctx.set
    return ctx
end

function Library:keybind(options)
    options = options or {}
    local rfTab = self._rayfield_tab
    local flag = options.flag or self:next_flag()
    local key = options.key or Enum.KeyCode.X
    local keyStr = tostring(key):gsub("Enum.KeyCode.", "")
    local ctx = setmetatable({ flag = flag, items = {} }, Library)

    Library.flags[flag] = { key = key, mode = options.mode or "Toggle", active = false }

    if rfTab then
        pcall(function()
            rfTab:CreateKeybind({
                name = options.name or "Keybind",
                currentKeybind = keyStr,
                holdToInteract = (options.mode == "Hold"),
                flag = flag,
                callback = function(k)
                    Library.flags[flag] = { key = k, mode = options.mode or "Toggle", active = false }
                    if options.callback then pcall(options.callback, k) end
                end,
            })
        end)
    end

    ctx.set = function(v)
        if type(v) == "table" and v.key then
            Library.flags[flag] = v
        end
    end
    Library.config_flags[flag] = ctx.set
    return ctx
end

function Library:textbox(options)
    options = options or {}
    local rfTab = self._rayfield_tab
    local flag = options.flag or self:next_flag()
    local ctx = setmetatable({ flag = flag, items = {} }, Library)

    Library.flags[flag] = options.default or ""

    if rfTab then
        pcall(function()
            rfTab:CreateInput({
                name = options.name or "Textbox",
                placeholderText = options.placeholder or "type here...",
                removeTextAfterFocusLost = false,
                flag = flag,
                callback = function(t)
                    Library.flags[flag] = t
                    if options.callback then pcall(options.callback, t) end
                end,
            })
        end)
    end

    ctx.set = function(t)
        Library.flags[flag] = t
        if options.callback then pcall(options.callback, t) end
    end
    Library.config_flags[flag] = ctx.set
    return ctx
end

function Library:button(options)
    options = options or {}
    local rfTab = self._rayfield_tab
    if rfTab then
        pcall(function()
            rfTab:CreateButton({
                name = options.name or "Button",
                callback = function()
                    if options.callback then pcall(options.callback) end
                end,
            })
        end)
    end
    return setmetatable({ items = {} }, Library)
end

function Library:label(options)
    options = options or {}
    local rfTab = self._rayfield_tab
    if rfTab then
        pcall(function()
            rfTab:CreateParagraph({
                Title = options.name or "Label",
                Content = options.info or "",
            })
        end)
    end
    return setmetatable({ items = {} }, Library)
end

function Library:seperator(options)
    options = options or {}
    local rfTab = self._rayfield_tab
    if rfTab and rfTab.CreateSection then
        pcall(function() rfTab:CreateSection(options.name or "Section") end)
    end
    return setmetatable({ items = {} }, Library)
end
Library.separator = Library.seperator

function Library:list(options)
    options = options or {}
    local rfTab = self._rayfield_tab
    local flag = options.flag or self:next_flag()
    local ctx = setmetatable({ flag = flag, items = {} }, Library)
    if rfTab then
        local opts = options.options or {}
        pcall(function()
            rfTab:CreateDropdown({
                name = options.name or "List",
                options = opts,
                currentOption = { opts[1] or "" },
                multipleOptions = false,
                flag = flag,
                callback = function(v)
                    Library.flags[flag] = v
                    if options.callback then pcall(options.callback, v) end
                end,
            })
        end)
        ctx.refresh_options = function() end
    end
    return ctx
end

function Library:settings(_)
    local noop = setmetatable({ items = {} }, Library)
    noop.toggle = function() return noop end
    noop.slider = function() return noop end
    noop.dropdown = function() return noop end
    noop.colorpicker = function() return noop end
    noop.keybind = function() return noop end
    return noop
end

-- ============================================================
-- SCRIPT İÇERİĞİ
-- ============================================================

local window = Library:window({
    name        = "sleepy",
    suffix      = ".gg 🎃",
    gameInfo    = "quality at its finest",
    footer_left = "quality at its finest",
    sub_info    = "lifetime, ",
    size        = UDim2.fromOffset(780, 505)
})
Library:update_theme("accent", Color3.fromRGB(0, 162, 255))

window:seperator({ name = "game" })

local mainRageTab, mainVoidspamTab, mainLegitTab, mainAATab = window:tab({
    name = "main",
    icon = "rbxassetid://10723415766",
    tabs = { "rage", "voidspam", "legit", "anti-aim" }
})

do
    local col1 = mainRageTab:column({})
    local secSilent = col1:section({ name = "Silent Aim Suite", size = 0.63, default = true, icon = "rbxassetid://6031075931" })

    secSilent:toggle({
        name      = "Enable Silent Aim",
        default   = false,
        seperator = true,
        callback  = function(v) flags.silent_aim_enabled = v end
    })

    secSilent:slider({
        name      = "FOV Radius",
        min       = 10,
        max       = 800,
        interval  = 5,
        default   = 120,
        suffix    = " px",
        seperator = true,
        callback  = function(v) flags.fov_radius_smoothed = v end
    })

    local fovVis = secSilent:toggle({
        name      = "Visualise FOV",
        default   = false,
        seperator = true,
        callback  = function(v) flags.silent_aim_visualise_range = v end
    })
    fovVis:colorpicker({
        name     = "FOV Color",
        color    = Color3.fromRGB(0, 162, 255),
        callback = function(c) flags.fov_color = c end
    })

    local fovSettings = fovVis:settings({})
    fovSettings:toggle({
        name      = "Spin FOV (Rainbow)",
        default   = false,
        seperator = true,
        callback  = function(v) flags.fov_spin_value = v end
    })
    fovSettings:slider({
        name      = "Spin Speed",
        min       = 1,
        max       = 30,
        interval  = 1,
        default   = 10,
        seperator = true,
        callback  = function(v) flags.fov_rotation_speed = v end
    })
    fovSettings:toggle({
        name      = "Filled FOV Circle",
        default   = false,
        seperator = true,
        callback  = function(v) flags.fov_filled = v end
    })

    secSilent:slider({
        name      = "Hit Chance",
        min       = 1,
        max       = 100,
        interval  = 1,
        default   = 100,
        suffix    = " %",
        seperator = true,
        callback  = function(v) flags.hit_chance = v end
    })

    secSilent:toggle({
        name      = "Riot Shield Check",
        default   = false,
        seperator = true,
        callback  = function(v) flags.riot_shield_check = v end
    })

    secSilent:toggle({
        name      = "Avoid Katana Deflect",
        default   = false,
        seperator = true,
        callback  = function(v) flags.avoid_katana_deflect = v end
    })

    local secExploits = col1:section({ name = "Wallbang & CFrame Manipulation", size = 0.37, default = true, icon = "rbxassetid://6031075931" })

    secExploits:toggle({
        name      = "Wallbang / Manipulation",
        default   = false,
        seperator = true,
        callback  = function(v) flags.manipulation_enabled = v end
    })

    secExploits:toggle({
        name      = "Wallbang V2 Solver",
        default   = false,
        seperator = true,
        callback  = function(v) flags.wallbang_solver_v2 = v end
    })

    secExploits:toggle({
        name      = "Teleport V2 Origin",
        default   = false,
        seperator = true,
        callback  = function(v) flags.teleport_v2_origin = v end
    })

    local col2 = mainRageTab:column({})
    local secRageTarget = col2:section({ name = "Targeting & Priority", size = 0.63, default = true, icon = "rbxassetid://6031075931" })

    secRageTarget:textbox({
        name      = "Priority Username",
        default   = "",
        seperator = true,
        callback  = function(v) flags.priority_user_input = v end
    })

    secRageTarget:button({
        name     = "Add to Ragebot Priority",
        callback = function()
            local u = flags.priority_user_input
            if u and #u > 0 then
                meowState.PriorityList[u] = true
                if Library and Library.notifications then
                    Library.notifications:create_notification({
                        name     = "Priority Added",
                        info     = "Added " .. u .. " to Ragebot Priority list",
                        lifetime = 3
                    })
                end
            end
        end
    })

    secRageTarget:toggle({
        name      = "Ragebot Priority",
        default   = false,
        seperator = true,
        callback  = function(v) flags.ragebot_priority = v end
    })

    secRageTarget:dropdown({
        name      = "Target Hitbox",
        items     = { "Head", "Torso", "Random", "Smart Lowest HP" },
        default   = "Head",
        seperator = true,
        callback  = function(v) flags.target_hitbox_choice = v end
    })

    secRageTarget:dropdown({
        name      = "Priority Method",
        items     = { "Distance", "Lowest Health", "FOV", "Crosshair" },
        default   = "Distance",
        seperator = true,
        callback  = function(v) flags.targeting_priority_method = v end
    })

    secRageTarget:toggle({
        name      = "Auto Weapon Swap When Empty",
        default   = false,
        seperator = true,
        callback  = function(v) flags.auto_weapon_swap = v end
    })

    local secMelee = col2:section({ name = "Knife Rage & Melee Aura", size = 0.37, default = true, icon = "rbxassetid://6031075931" })

    secMelee:toggle({
        name      = "Knife / Melee Rage",
        default   = false,
        seperator = true,
        callback  = function(v) flags.melee_aura = v end
    })

    secMelee:slider({
        name      = "Melee Safe Reach",
        min       = 5,
        max       = 25,
        interval  = 1,
        default   = 16,
        suffix    = " studs",
        seperator = true,
        callback  = function(v) flags.melee_reach = v end
    })

    secMelee:toggle({
        name      = "Auto Face Back (Silent Backstab)",
        default   = false,
        seperator = true,
        callback  = function(v) flags.auto_face_back = v end
    })
end

do
    local col1 = mainVoidspamTab:column({})
    local secDesync = col1:section({ name = "Subterranean & Void Desync", default = true, icon = "rbxassetid://6031075931" })

    secDesync:dropdown({
        name      = "Dropdown",
        items     = { "Position Desync V2", "Position Desync V1", "Underground V2", "Void Teleport" },
        default   = "Position Desync V2",
        seperator = true,
        callback  = function(v) fakePos.DesyncMode = v end
    })

    secDesync:toggle({
        name      = "Auto Void On Low HP (< 25 HP)",
        default   = false,
        seperator = true,
        callback  = function(v) flags.auto_void_low_hp = v end
    })

    secDesync:toggle({
        name      = "Melee Underground Strike",
        default   = false,
        seperator = true,
        callback  = function(v) flags.melee_underground_strike = v end
    })

    secDesync:slider({
        name      = "Melee Desync Reach",
        min       = 1,
        max       = 30,
        interval  = 1,
        default   = 18,
        suffix    = " studs",
        seperator = true,
        callback  = function(v) flags.melee_reach = v end
    })

    local col2 = mainVoidspamTab:column({})
    local secLag = col2:section({ name = "Packet Choking (Fake Lag)", default = true, icon = "rbxassetid://6031075931" })

    secLag:toggle({
        name      = "Fake Lag / Choke Packets",
        default   = false,
        seperator = true,
        callback  = function(v) flags.fakelag_enabled = v end
    })

    secLag:slider({
        name      = "Choke Limit",
        min       = 1,
        max       = 20,
        interval  = 1,
        default   = 6,
        suffix    = " ticks",
        seperator = true,
        callback  = function(v) flags.fakelag_choke = v end
    })

    secLag:dropdown({
        name      = "Dropdown",
        items     = { "Fluctuate", "Static", "Adaptive", "Random", "Pulse" },
        default   = "Fluctuate",
        seperator = true,
        callback  = function(v) flags.fakelag_mode = v end
    })

    secLag:toggle({
        name      = "Break Lag Comp (LC Breaker)",
        default   = false,
        seperator = true,
        callback  = function(v) flags.break_lag_comp = v end
    })
end

do
    local col1 = mainLegitTab:column({})
    local secAimbot = col1:section({ name = "Legit Aimbot", default = true, icon = "rbxassetid://6031075931" })

    secAimbot:toggle({
        name      = "Enable Aimbot",
        default   = false,
        seperator = true,
        callback  = function(v) flags.aimbot_enabled = v end
    })

    secAimbot:keybind({
        name     = "Aim Keybind",
        mode     = "Hold",
        key      = Enum.KeyCode.E,
        callback = function(active) flags.aimbot_active = active end
    })

    secAimbot:slider({
        name      = "Smoothness",
        min       = 1,
        max       = 25,
        interval  = 1,
        default   = 6,
        seperator = true,
        callback  = function(v) flags.aimbot_smooth_step = v end
    })

    secAimbot:slider({
        name      = "Aimbot FOV",
        min       = 10,
        max       = 500,
        interval  = 5,
        default   = 90,
        suffix    = " px",
        seperator = true,
        callback  = function(v) flags.aimbot_radius_smoothed = v end
    })

    secAimbot:toggle({
        name      = "Visualise Aimbot FOV",
        default   = false,
        seperator = true,
        callback  = function(v) flags.aimbot_visualise_range = v end
    })

    secAimbot:toggle({
        name      = "Wall Check",
        default   = false,
        seperator = true,
        callback  = function(v) flags.aimbot_wall_check = v end
    })

    local col2 = mainLegitTab:column({})
    local secTrigger = col2:section({ name = "Triggerbot & Recoil", default = true, icon = "rbxassetid://6031075931" })

    secTrigger:toggle({
        name      = "Enable Triggerbot",
        default   = false,
        seperator = true,
        callback  = function(v) flags.triggerbot_enabled = v end
    })

    secTrigger:slider({
        name      = "Reaction Delay",
        min       = 0,
        max       = 200,
        interval  = 10,
        default   = 20,
        suffix    = " ms",
        seperator = true,
        callback  = function(v) flags.triggerbot_delay = v end
    })

    secTrigger:toggle({
        name      = "No Recoil",
        default   = false,
        seperator = true,
        callback  = function(v) flags.no_recoil = v end
    })

    secTrigger:toggle({
        name      = "No Spread",
        default   = false,
        seperator = true,
        callback  = function(v) flags.no_spread = v end
    })
end

do
    local col1 = mainAATab:column({})
    local secAA = col1:section({ name = "HvH Anti-Aim Angles", default = true, icon = "rbxassetid://6031075931" })

    secAA:toggle({
        name      = "Enable Anti-Aim",
        default   = false,
        seperator = true,
        callback  = function(v) flags.antiaim_enabled = v end
    })

    secAA:dropdown({
        name      = "Anti-Aim Preset",
        items     = { "Custom", "Spinbot", "Jitter Fast", "Jitter Slow", "Sway HvH", "Backward", "Side Angles (Left)", "Side Angles (Right)", "Random HvH", "Block Anti-Aim" },
        default   = "Custom",
        seperator = true,
        callback  = function(v) flags.antiaim_preset = v end
    })

    secAA:dropdown({
        name      = "Yaw Mode",
        items     = { "None", "Backwards", "Left", "Right", "Spin", "Sway", "Jitter", "Random", "Offset", "Custom", "Block", "LBY Breaker", "Freestanding" },
        default   = "Spin",
        seperator = true,
        callback  = function(v) flags.yaw_type = v end
    })

    secAA:dropdown({
        name      = "Pitch Mode",
        items     = { "None", "Up", "Down", "Up & Down", "Random", "Offset", "Custom", "Extended Random", "Extended Custom", "Zero" },
        default   = "Down",
        seperator = true,
        callback  = function(v) flags.pitch_type = v end
    })

    secAA:slider({
        name      = "Rotation Speed",
        min       = 1,
        max       = 50,
        interval  = 1,
        default   = 20,
        seperator = true,
        callback  = function(v) flags.rotation_speed = v end
    })

    secAA:slider({
        name      = "Jitter Angle Range",
        min       = 5,
        max       = 180,
        interval  = 5,
        default   = 60,
        suffix    = " deg",
        seperator = true,
        callback  = function(v) flags.jitter_range = v end
    })

    local col2 = mainAATab:column({})
    local secAAExp = col2:section({ name = "Anti-Aim Defensive Exploits", default = true, icon = "rbxassetid://6031075931" })

    secAAExp:toggle({
        name      = "Hide Head Angle",
        default   = false,
        seperator = true,
        callback  = function(v) flags.hide_head = v end
    })

    secAAExp:toggle({
        name      = "Camera Replication Decouple",
        default   = false,
        seperator = true,
        callback  = function(v) flags.camera_bypass = v end
    })

    secAAExp:toggle({
        name      = "Preserve Movement Direction",
        default   = false,
        seperator = true,
        callback  = function(v) flags.preserve_movement = v end
    })

    secAAExp:toggle({
        name      = "Pause On Attack / Knife",
        default   = false,
        seperator = true,
        callback  = function(v) flags.pause_on_attack = v end
    })
end

local visVMTab, visFXTab, visHUDTab, visWorldTab = window:tab({
    name = "visuals",
    icon = "rbxassetid://6031075931",
    tabs = { "viewmodel", "effects", "hud", "world" }
})

do
    local col1 = visVMTab:column({})
    local secVM = col1:section({
        name    = '<u>viewmodel</u>  <font color="rgb(72, 72, 73)">camera</font>',
        default = true,
        icon    = "rbxassetid://6031075931"
    })

    secVM:toggle({
        name      = "show cosmetics changer",
        default   = true,
        seperator = true,
        callback  = function(v)
            flags.show_cosmetics_changer = v
            pcall(function()
                if shared.MeowCosmeticChanger and shared.MeowCosmeticChanger.SetVisible then
                    shared.MeowCosmeticChanger.SetVisible(v)
                elseif shared.CosmeticChangerWindow then
                    shared.CosmeticChangerWindow.Visible = v
                end
            end)
            pcall(function()
                local coreGui = (gethui and gethui()) or game:GetService("CoreGui")
                local pill = coreGui:FindFirstChild("_MeowCosmeticPill")
                if pill then pill.Enabled = v end
            end)
        end
    })

    secVM:dropdown({
        name      = "disable",
        items     = { "None", "Arms", "Gun", "Both" },
        default   = "None",
        seperator = true,
        callback  = function(v) flags.vm_disable_parts = v end
    })

    secVM:toggle({
        name      = "override fps",
        default   = false,
        seperator = true,
        callback  = function(v) flags.viewmodel_fps_override = v end
    })

    secVM:slider({
        name      = "recoil percent",
        min       = 0,
        max       = 100,
        interval  = 1,
        default   = 100,
        style     = "bar",
        suffix    = "%",
        seperator = true,
        callback  = function(v) flags.recoil_percent = v end
    })

    local chamsTog = secVM:toggle({
        name      = "chams",
        default   = false,
        seperator = true,
        callback  = function(v) flags.item_chams = v end
    })
    chamsTog:colorpicker({
        name     = "Chams 1",
        color    = Color3.fromRGB(255, 255, 255),
        callback = function(c) flags.item_chams_color = c end
    })
    chamsTog:colorpicker({
        name     = "Chams 2",
        color    = Color3.fromRGB(255, 255, 255),
        callback = function(c) flags.item_chams_color2 = c end
    })

    secVM:toggle({
        name      = "offset",
        default   = false,
        seperator = true,
        callback  = function(v) flags.vm_offset_enabled = v end
    })

    local col2 = visVMTab:column({})
    local secOverride = col2:section({
        name    = '<u>override</u>  <font color="rgb(72, 72, 73)">item   scaling</font>',
        size    = 0.63,
        default = true,
        icon    = "rbxassetid://6031075931"
    })

    secOverride:toggle({
        name      = "viewmodel appearance",
        default   = false,
        seperator = true,
        callback  = function(v) flags.vm_appearance = v end
    })

    local wireToggle = secOverride:toggle({
        name      = "gun wireframe",
        default   = false,
        seperator = true,
        callback  = function(v) flags.item_wireframe = v end
    })
    wireToggle:colorpicker({
        name     = "Wire Color 1",
        color    = Color3.fromRGB(255, 255, 255),
        callback = function(c) flags.wireframe_color = c end
    })
    wireToggle:colorpicker({
        name     = "Wire Color 2",
        color    = Color3.fromRGB(155, 100, 255),
        callback = function(c) flags.wireframe_color2 = c end
    })

    secOverride:toggle({
        name      = "arm appearance",
        default   = false,
        seperator = true,
        callback  = function(v) flags.arm_appearance = v end
    })

    secOverride:toggle({
        name      = "character appearance",
        default   = false,
        seperator = true,
        callback  = function(v) flags.char_appearance = v end
    })

    local colTog = secOverride:toggle({
        name      = "color",
        default   = false,
        seperator = true,
        callback  = function(v) flags.color_override = v end
    })
    colTog:colorpicker({
        name     = "Override Tint",
        color    = Color3.fromRGB(255, 255, 255),
        callback = function(c) flags.global_color_override = c end
    })

    secOverride:toggle({
        name      = "material",
        default   = false,
        seperator = true,
        callback  = function(v) flags.item_material_enabled = v end
    })

    secOverride:dropdown({
        name      = "material",
        items     = { "ForceField", "Neon", "Plastic", "Glass", "Foil" },
        default   = "ForceField",
        seperator = true,
        callback  = function(v) flags.item_chams_material = v end
    })

    secOverride:toggle({
        name      = "disable textures",
        default   = false,
        seperator = true,
        callback  = function(v) flags.disable_textures = v end
    })

    secOverride:slider({
        name      = "transparency",
        min       = 0,
        max       = 100,
        interval  = 1,
        default   = 100,
        style     = "bar",
        suffix    = "%",
        seperator = true,
        callback  = function(v) flags.item_chams_transparency = v / 100 end
    })

    local secCosmetic = col2:section({
        name    = "cosmetic - changer",
        size    = 0.37,
        default = true,
        icon    = "rbxassetid://6031075931"
    })

    secCosmetic:toggle({
        name      = "unlock all",
        default   = false,
        seperator = true,
        callback  = function(v)
            flags.unlock_all = v
            pcall(function()
                if shared.SyncUnlockAll then
                    shared.SyncUnlockAll(v)
                end
            end)
        end
    })

    secCosmetic:toggle({
        name      = "unock all emotes are fe",
        default   = false,
        seperator = true,
        callback  = function(v)
            flags.unlock_emotes_fe = v
            pcall(function()
                if shared.SyncUnlockAll then
                    shared.SyncUnlockAll(flags.unlock_all)
                end
            end)
        end
    })

    pcall(function()
        secCosmetic:label({
            name      = '<font color="rgb(120, 120, 130)">everyone can see them</font>',
            seperator = true
        })
    end)
end

do
    local col1 = visFXTab:column({})
    local secHit = col1:section({ name = "Hit Effects & Sounds", default = true, icon = "rbxassetid://6031075931" })

    secHit:toggle({
        name      = "Hit Sound Enabled",
        default   = false,
        seperator = true,
        callback  = function(v) flags.hit_sound_enabled = v end
    })

    secHit:dropdown({
        name      = "Hit Sound Preset",
        items     = { "Rust", "Skeet", "Bell", "Bonk", "Neverlose", "Bubble" },
        default   = "Rust",
        seperator = true,
        callback  = function(v) flags.hit_sound_preset = v end
    })

    secHit:toggle({
        name      = "Kill Sound Enabled",
        default   = false,
        seperator = true,
        callback  = function(v) flags.kill_sound_enabled = v end
    })

    secHit:dropdown({
        name      = "Kill Sound Preset",
        items     = { "Fatality", "Headshot", "Skeet", "Oof" },
        default   = "Fatality",
        seperator = true,
        callback  = function(v) flags.kill_sound_preset = v end
    })

    secHit:slider({
        name      = "Sound Volume",
        min       = 0.1,
        max       = 2.0,
        interval  = 0.1,
        default   = 1.0,
        seperator = true,
        callback  = function(v) flags.sound_volume = v end
    })

    local wmToggle = secHit:toggle({
        name      = "3D World Hitmarker",
        default   = false,
        seperator = true,
        callback  = function(v) flags.world_marker_enabled = v end
    })
    wmToggle:colorpicker({
        name     = "Marker Color",
        color    = Color3.fromRGB(0, 162, 255),
        callback = function(c) flags.world_marker_color = c end
    })
end

do
    local col1 = visHUDTab:column({})
    local secTH = col1:section({ name = "Target HUD Card", default = true, icon = "rbxassetid://6031075931" })

    secTH:toggle({
        name      = "Enable Target Info HUD",
        default   = false,
        seperator = true,
        callback  = function(v) flags.target_hud = v end
    })

    secTH:toggle({
        name      = "Preview While Menu Open",
        default   = false,
        seperator = true,
        callback  = function(v) flags.target_hud_preview = v end
    })

    secTH:slider({
        name      = "HUD Scale Multiplier",
        min       = 0.5,
        max       = 2.0,
        interval  = 0.05,
        default   = 1.0,
        seperator = true,
        callback  = function(v) flags.target_hud_scale = v end
    })

    secTH:toggle({
        name      = "Show Music Player",
        default   = false,
        seperator = true,
        callback  = function(v)
            if shared.MeowMusicPlayer and shared.MeowMusicPlayer.MainFrame then
                shared.MeowMusicPlayer.MainFrame.Visible = v
            end
        end
    })

    local col2 = visHUDTab:column({})
    local secCross = col2:section({ name = "Procedural Crosshair", default = true, icon = "rbxassetid://6031075931" })

    local crossToggle = secCross:toggle({
        name      = "Custom Crosshair",
        default   = false,
        seperator = true,
        callback  = function(v) flags.crosshair_enabled = v end
    })
    crossToggle:colorpicker({
        name     = "Crosshair Color",
        color    = Color3.fromRGB(0, 162, 255),
        callback = function(c) flags.crosshair_color = c end
    })

    secCross:toggle({
        name      = "Rainbow Crosshair",
        default   = false,
        seperator = true,
        callback  = function(v) flags.crosshair_rainbow = v end
    })

    secCross:slider({
        name      = "Rainbow Speed",
        min       = 1,
        max       = 10,
        interval  = 1,
        default   = 2,
        seperator = true,
        callback  = function(v) flags.crosshair_rainbow_speed = v end
    })

    secCross:toggle({
        name      = "Crosshair Outlines",
        default   = false,
        seperator = true,
        callback  = function(v) flags.crosshair_outline = v end
    })

    local dotToggle = secCross:toggle({
        name      = "Center Dot",
        default   = false,
        seperator = true,
        callback  = function(v) flags.crosshair_dot = v end
    })
    dotToggle:colorpicker({
        name     = "Dot Color",
        color    = Color3.fromRGB(0, 162, 255),
        callback = function(c) flags.crosshair_dot_color = c end
    })

    secCross:slider({
        name      = "Center Dot Size",
        min       = 1,
        max       = 8,
        interval  = 0.5,
        default   = 2.5,
        seperator = true,
        callback  = function(v) flags.crosshair_dot_size = v end
    })

    secCross:toggle({
        name      = "T-Shape (No Top Line)",
        default   = false,
        seperator = true,
        callback  = function(v) flags.crosshair_t_shape = v end
    })

    secCross:slider({
        name      = "Crosshair Length",
        min       = 1,
        max       = 50,
        interval  = 1,
        default   = 14,
        suffix    = " px",
        seperator = true,
        callback  = function(v) flags.crosshair_length = v end
    })

    secCross:slider({
        name      = "Crosshair Gap / Offset",
        min       = 0,
        max       = 30,
        interval  = 1,
        default   = 6,
        suffix    = " px",
        seperator = true,
        callback  = function(v) flags.crosshair_offset = v end
    })

    secCross:slider({
        name      = "Crosshair Thickness",
        min       = 1,
        max       = 8,
        interval  = 1,
        default   = 2,
        suffix    = " px",
        seperator = true,
        callback  = function(v) flags.crosshair_thickness = v end
    })

    secCross:slider({
        name      = "Dynamic Rotation (Spin)",
        min       = 0,
        max       = 10,
        interval  = 0.2,
        default   = 0,
        seperator = true,
        callback  = function(v) flags.crosshair_rotation_speed = v end
    })

    secCross:slider({
        name      = "Static Rotation Angle",
        min       = 0,
        max       = 360,
        interval  = 5,
        default   = 0,
        suffix    = " deg",
        seperator = true,
        callback  = function(v) flags.crosshair_rotation = v end
    })

    secCross:slider({
        name      = "Bouncing Speed",
        min       = 0,
        max       = 15,
        interval  = 0.5,
        default   = 0,
        seperator = true,
        callback  = function(v) flags.crosshair_bounce_speed = v end
    })

    secCross:slider({
        name      = "Bouncing Amplitude",
        min       = 0,
        max       = 20,
        interval  = 1,
        default   = 0,
        seperator = true,
        callback  = function(v) flags.crosshair_bounce_amp = v end
    })

    secCross:toggle({
        name      = "Hitmarker Dynamic Pulse",
        default   = false,
        seperator = true,
        callback  = function(v) flags.crosshair_hit_pulse = v end
    })
end

do
    local col1 = visWorldTab:column({})
    local secLighting = col1:section({ name = "World Lighting Modulation", default = true, icon = "rbxassetid://6031075931" })

    local ambToggle = secLighting:toggle({
        name      = "Ambient Override",
        default   = false,
        seperator = true,
        callback  = function(v) flags.lighting_ambient_enabled = v end
    })
    ambToggle:colorpicker({
        name     = "Ambient Color",
        color    = Color3.fromRGB(150, 150, 150),
        callback = function(c) flags.lighting_ambient_color = c end
    })

    local outAmbToggle = secLighting:toggle({
        name      = "Outdoor Ambient Override",
        default   = false,
        seperator = true,
        callback  = function(v) flags.lighting_outdoor_ambient_enabled = v end
    })
    outAmbToggle:colorpicker({
        name     = "Outdoor Color",
        color    = Color3.fromRGB(120, 120, 140),
        callback = function(c) flags.lighting_outdoor_ambient_color = c end
    })

    secLighting:toggle({
        name      = "Override Brightness",
        default   = false,
        seperator = true,
        callback  = function(v) flags.lighting_brightness_enabled = v end
    })

    secLighting:slider({
        name      = "Brightness Value",
        min       = 0,
        max       = 10,
        interval  = 0.1,
        default   = 2,
        seperator = true,
        callback  = function(v) flags.lighting_brightness_value = v end
    })

    secLighting:toggle({
        name      = "Override Time (ClockTime)",
        default   = false,
        seperator = true,
        callback  = function(v) flags.lighting_clocktime_enabled = v end
    })

    secLighting:slider({
        name      = "Time of Day",
        min       = 0,
        max       = 24,
        interval  = 0.5,
        default   = 14,
        suffix    = " h",
        seperator = true,
        callback  = function(v) flags.lighting_clocktime_value = v end
    })

    local fogToggle = secLighting:toggle({
        name      = "Custom Fog Modulation",
        default   = false,
        seperator = true,
        callback  = function(v) flags.lighting_fog_enabled = v end
    })
    fogToggle:colorpicker({
        name     = "Fog Color",
        color    = Color3.fromRGB(160, 160, 180),
        callback = function(c) flags.lighting_fog_color = c end
    })

    secLighting:slider({
        name      = "Fog Start Distance",
        min       = 0,
        max       = 500,
        interval  = 10,
        default   = 0,
        suffix    = " studs",
        seperator = true,
        callback  = function(v) flags.lighting_fog_start = v end
    })

    secLighting:slider({
        name      = "Fog End Distance",
        min       = 50,
        max       = 3000,
        interval  = 50,
        default   = 1000,
        suffix    = " studs",
        seperator = true,
        callback  = function(v) flags.lighting_fog_end = v end
    })

    secLighting:toggle({
        name      = "Global Shadows",
        default   = false,
        seperator = true,
        callback  = function(v) flags.lighting_shadows_enabled = v end
    })

    secLighting:slider({
        name      = "Shadow Softness",
        min       = 0,
        max       = 1,
        interval  = 0.05,
        default   = 0.5,
        seperator = true,
        callback  = function(v) flags.lighting_shadow_softness = v end
    })

    secLighting:toggle({
        name      = "Exposure Compensation",
        default   = false,
        seperator = true,
        callback  = function(v) flags.lighting_exposure_enabled = v end
    })

    secLighting:slider({
        name      = "Exposure Value",
        min       = -3,
        max       = 3,
        interval  = 0.1,
        default   = 0,
        seperator = true,
        callback  = function(v) flags.lighting_exposure_value = v end
    })

    secLighting:toggle({
        name      = "Lighting Technology",
        default   = false,
        seperator = true,
        callback  = function(v) flags.lighting_technology_enabled = v end
    })

    secLighting:dropdown({
        name      = "Technology Mode",
        items     = { "Future", "ShadowMap", "Compatibility", "Voxel" },
        default   = "Future",
        seperator = true,
        callback  = function(v) flags.lighting_technology = v end
    })

    local col2 = visWorldTab:column({})
    local secSky = col2:section({ name = "Skybox & Atmosphere", size = 0.5, default = true, icon = "rbxassetid://6031075931" })

    secSky:toggle({
        name      = "Enable Skybox Override",
        default   = false,
        seperator = true,
        callback  = function(v)
            flags.world_skybox_enabled = v
            applySkybox(flags.skybox_preset or "Synthwave")
        end
    })

    secSky:dropdown({
        name      = "Skybox Preset",
        items     = {
            "Synthwave", "Purple Nebula", "Vaporwave", "Night Sky", "Red Galaxy", "Sunset",
            "GreenHaze", "Space2", "PinkMountains", "Valentines", "PinkArt", "PurplePlanet",
            "Blizzard", "Winter", "FlamingSunset", "Mountains", "FPSBoost", "AestheticMountains",
            "BetterNight3", "Galaxy2", "Aesthetic3", "PurpleSpace", "Pink", "PurpleNight",
            "Flame", "Galaxy3", "Storm", "Deep Space"
        },
        default   = "Synthwave",
        seperator = true,
        callback  = function(v)
            flags.skybox_preset = v
            if flags.world_skybox_enabled then applySkybox(v) end
        end
    })

    secSky:toggle({
        name      = "Auto Rotate Sky (Day Cycle)",
        default   = false,
        seperator = true,
        callback  = function(v) flags.world_sky_autorotate = v end
    })

    secSky:slider({
        name      = "Sky Rotation Speed",
        min       = 10,
        max       = 500,
        interval  = 10,
        default   = 100,
        seperator = true,
        callback  = function(v) flags.world_sky_rotate_speed = v end
    })

    local atmToggle = secSky:toggle({
        name      = "Atmosphere Changer",
        default   = false,
        seperator = true,
        callback  = function(v) flags.atmosphere_enabled = v end
    })
    atmToggle:colorpicker({
        name     = "Atmosphere Color",
        color    = Color3.fromRGB(199, 170, 107),
        callback = function(c) flags.atmosphere_color = c end
    })
    atmToggle:colorpicker({
        name     = "Atmosphere Decay",
        color    = Color3.fromRGB(106, 112, 125),
        callback = function(c) flags.atmosphere_decay = c end
    })

    secSky:slider({
        name      = "Atmosphere Density",
        min       = 0,
        max       = 1,
        interval  = 0.05,
        default   = 0.3,
        seperator = true,
        callback  = function(v) flags.atmosphere_density = v end
    })

    secSky:slider({
        name      = "Atmosphere Haze",
        min       = 0,
        max       = 10,
        interval  = 0.5,
        default   = 1,
        seperator = true,
        callback  = function(v) flags.atmosphere_haze = v end
    })

    secSky:slider({
        name      = "Atmosphere Glare",
        min       = 0,
        max       = 1,
        interval  = 0.05,
        default   = 0,
        seperator = true,
        callback  = function(v) flags.atmosphere_glare = v end
    })

    local ccToggle = secSky:toggle({
        name      = "Color Correction Effect",
        default   = false,
        seperator = true,
        callback  = function(v) flags.color_correction_enabled = v end
    })
    ccToggle:colorpicker({
        name     = "Tint Color",
        color    = Color3.fromRGB(255, 255, 255),
        callback = function(c) flags.cc_tint_color = c end
    })

    secSky:slider({
        name      = "Color Saturation",
        min       = -1,
        max       = 2,
        interval  = 0.1,
        default   = 0,
        seperator = true,
        callback  = function(v) flags.cc_saturation = v end
    })

    secSky:slider({
        name      = "Color Contrast",
        min       = -1,
        max       = 2,
        interval  = 0.1,
        default   = 0,
        seperator = true,
        callback  = function(v) flags.cc_contrast = v end
    })

    local secRemovals = col2:section({ name = "World Removals & Camera", size = 0.5, default = true, icon = "rbxassetid://6031075931" })

    secRemovals:toggle({
        name      = "No Textures (Map Stripper)",
        default   = false,
        seperator = true,
        callback  = function(v) flags.world_no_textures = v end
    })

    secRemovals:toggle({
        name      = "No Fog",
        default   = false,
        seperator = true,
        callback  = function(v) flags.world_no_fog = v end
    })

    secRemovals:toggle({
        name      = "Anti-Flashbang",
        default   = false,
        seperator = true,
        callback  = function(v) flags.anti_flash = v end
    })

    secRemovals:toggle({
        name      = "Anti-Screen Shake",
        default   = false,
        seperator = true,
        callback  = function(v) flags.anti_shake = v end
    })

    secRemovals:toggle({
        name      = "Custom Camera FOV",
        default   = false,
        seperator = true,
        callback  = function(v) flags.camera_fov_enabled = v end
    })

    secRemovals:slider({
        name      = "Camera Field of View",
        min       = 60,
        max       = 130,
        interval  = 1,
        default   = 90,
        suffix    = " deg",
        seperator = true,
        callback  = function(v) flags.camera_fov = v end
    })

    secRemovals:toggle({
        name      = "Third Person POV",
        default   = false,
        seperator = true,
        callback  = function(v) flags.third_person = v end
    })
end

local espPlayersTab, espChamsTab, espTracersTab = window:tab({
    name = "esp",
    icon = "rbxassetid://10734975692",
    tabs = { "Players", "Chams", "Tracers" }
})

do
    local col1 = espPlayersTab:column({})
    local secEnemy = col1:section({ name = "Enemy ESP", default = true, icon = "rbxassetid://6031075931" })

    secEnemy:toggle({
        name      = "Enable Enemy ESP",
        default   = false,
        seperator = true,
        callback  = function(v) flags.esp_enabled = v end
    })

    secEnemy:dropdown({
        name      = "Box Style",
        items     = { "Corner", "Full", "3D Box" },
        default   = "Corner",
        seperator = true,
        callback  = function(v) flags.esp_box_style = v end
    })

    local boxTog = secEnemy:toggle({
        name      = "Bounding Box",
        default   = false,
        seperator = true,
        callback  = function(v) flags.esp_boxes = v end
    })
    boxTog:colorpicker({
        name     = "Box Color",
        color    = Color3.fromRGB(255, 255, 255),
        callback = function(c) flags.esp_box_color = c end
    })

    local fillTog = secEnemy:toggle({
        name      = "Filled Box",
        default   = false,
        seperator = true,
        callback  = function(v) flags.esp_box_fill = v end
    })
    fillTog:colorpicker({
        name     = "Fill Color",
        color    = Color3.fromRGB(0, 162, 255),
        callback = function(c) flags.esp_fill_color = c end
    })

    secEnemy:dropdown({
        name      = "Box Fit",
        items     = { "Dynamic", "Static" },
        default   = "Dynamic",
        seperator = true,
        callback  = function(v) flags.esp_box_fit = v end
    })

    local nameTog = secEnemy:toggle({
        name      = "Name Tags",
        default   = false,
        seperator = true,
        callback  = function(v) flags.esp_names = v end
    })
    nameTog:colorpicker({
        name     = "Name Color",
        color    = Color3.fromRGB(240, 240, 240),
        callback = function(c) flags.esp_name_color = c end
    })

    local hpTog = secEnemy:toggle({
        name      = "Health Bar",
        default   = false,
        seperator = true,
        callback  = function(v) flags.esp_health_bars = v end
    })
    hpTog:colorpicker({
        name     = "Health Bar Color",
        color    = Color3.fromRGB(0, 255, 120),
        callback = function(c) flags.esp_health_color = c end
    })

    secEnemy:dropdown({
        name      = "Health Color Mode",
        items     = { "Reactive", "Gradient", "Solid" },
        default   = "Reactive",
        seperator = true,
        callback  = function(v) flags.esp_health_mode = v end
    })

    local hpNum = secEnemy:toggle({
        name      = "Health Number",
        default   = false,
        seperator = true,
        callback  = function(v) flags.esp_health_number = v end
    })
    hpNum:colorpicker({
        name     = "HP Num Color",
        color    = Color3.fromRGB(255, 255, 255),
        callback = function(c) flags.esp_hp_num_color = c end
    })

    local ammoTog = secEnemy:toggle({
        name      = "Ammo Bar",
        default   = false,
        seperator = true,
        callback  = function(v) flags.esp_ammo_bar = v end
    })
    ammoTog:colorpicker({
        name     = "Ammo Bar Color",
        color    = Color3.fromRGB(0, 162, 255),
        callback = function(c) flags.esp_ammo_color = c end
    })

    secEnemy:dropdown({
        name      = "Ammo Color Mode",
        items     = { "Solid", "Gradient", "Reactive" },
        default   = "Solid",
        seperator = true,
        callback  = function(v) flags.esp_ammo_mode = v end
    })

    local wepTog = secEnemy:toggle({
        name      = "Held Weapon",
        default   = false,
        seperator = true,
        callback  = function(v) flags.esp_weapons = v end
    })
    wepTog:colorpicker({
        name     = "Weapon Color",
        color    = Color3.fromRGB(220, 220, 220),
        callback = function(c) flags.esp_weapon_color = c end
    })

    local distTog = secEnemy:toggle({
        name      = "Distance",
        default   = false,
        seperator = true,
        callback  = function(v) flags.esp_distance = v end
    })
    distTog:colorpicker({
        name     = "Distance Color",
        color    = Color3.fromRGB(180, 180, 180),
        callback = function(c) flags.esp_dist_color = c end
    })

    local rankTog = secEnemy:toggle({
        name      = "Rank Badge",
        default   = false,
        seperator = true,
        callback  = function(v) flags.esp_rank = v end
    })
    rankTog:colorpicker({
        name     = "Rank Color",
        color    = Color3.fromRGB(255, 215, 0),
        callback = function(c) flags.esp_rank_color = c end
    })

    local streakTog = secEnemy:toggle({
        name      = "Win Streak",
        default   = false,
        seperator = true,
        callback  = function(v) flags.esp_streak = v end
    })
    streakTog:colorpicker({
        name     = "Streak Color",
        color    = Color3.fromRGB(255, 100, 50),
        callback = function(c) flags.esp_streak_color = c end
    })

    local deflTog = secEnemy:toggle({
        name      = "Deflecting (Katana Shield)",
        default   = false,
        seperator = true,
        callback  = function(v) flags.esp_deflecting = v end
    })
    deflTog:colorpicker({
        name     = "Deflecting Color",
        color    = Color3.fromRGB(255, 0, 150),
        callback = function(c) flags.esp_deflect_color = c end
    })

    local col2 = espPlayersTab:column({})
    local secSettings = col2:section({ name = "Teammates & Text Settings", default = true, icon = "rbxassetid://6031075931" })

    secSettings:toggle({
        name      = "Enable Teammates ESP",
        default   = false,
        seperator = true,
        callback  = function(v) flags.esp_team_enabled = v end
    })

    local tmBox = secSettings:toggle({
        name      = "Teammate Box",
        default   = false,
        seperator = true,
        callback  = function(v) flags.esp_team_boxes = v end
    })
    tmBox:colorpicker({
        name     = "Team Box Color",
        color    = Color3.fromRGB(80, 180, 255),
        callback = function(c) flags.esp_team_box_color = c end
    })

    local tmName = secSettings:toggle({
        name      = "Teammate Name",
        default   = false,
        seperator = true,
        callback  = function(v) flags.esp_team_names = v end
    })
    tmName:colorpicker({
        name     = "Team Name Color",
        color    = Color3.fromRGB(80, 180, 255),
        callback = function(c) flags.esp_team_name_color = c end
    })

    local tmHp = secSettings:toggle({
        name      = "Teammate Health Bar",
        default   = false,
        seperator = true,
        callback  = function(v) flags.esp_team_health = v end
    })
    tmHp:colorpicker({
        name     = "Team HP Color",
        color    = Color3.fromRGB(0, 255, 120),
        callback = function(c) flags.esp_team_hp_color = c end
    })

    secSettings:toggle({
        name      = "Use Display Names",
        default   = false,
        seperator = true,
        callback  = function(v) flags.esp_display_names = v end
    })

    secSettings:dropdown({
        name      = "ESP Font",
        items     = { "Gotham", "SourceSans", "Arial", "Code", "Roboto" },
        default   = "Code",
        seperator = true,
        callback  = function(v) flags.esp_font_choice = v end
    })

    secSettings:slider({
        name      = "ESP Font Size",
        min       = 8,
        max       = 32,
        interval  = 1,
        default   = 13,
        seperator = true,
        callback  = function(v) flags.esp_font_size = v end
    })

    secSettings:dropdown({
        name      = "Text Case",
        items     = { "Standard", "UPPERCASE", "lowercase" },
        default   = "lowercase",
        seperator = true,
        callback  = function(v) flags.esp_text_case = v end
    })

    secSettings:dropdown({
        name      = "Text Surround",
        items     = { "None", "[]", "()", "<>", "{}" },
        default   = "None",
        seperator = true,
        callback  = function(v) flags.esp_text_surround = v end
    })

    secSettings:slider({
        name      = "Flag Font Size",
        min       = 6,
        max       = 24,
        interval  = 1,
        default   = 10,
        seperator = true,
        callback  = function(v) flags.esp_flag_size = v end
    })

    secSettings:dropdown({
        name      = "Flag Surround",
        items     = { "None", "[]", "()", "<>", "{}" },
        default   = "[]",
        seperator = true,
        callback  = function(v) flags.esp_flag_surround = v end
    })

    secSettings:toggle({
        name      = "Scale With Distance",
        default   = false,
        seperator = true,
        callback  = function(v) flags.esp_distance_scaling = v end
    })

    secSettings:slider({
        name      = "Reference Distance",
        min       = 10,
        max       = 300,
        interval  = 5,
        default   = 60,
        suffix    = " studs",
        seperator = true,
        callback  = function(v) flags.esp_distance_ref = v end
    })

    secSettings:toggle({
        name      = "Team Check (Ignore Teammates)",
        default   = false,
        seperator = true,
        callback  = function(v) flags.esp_team_check = v end
    })

    secSettings:slider({
        name      = "Max Render Distance",
        min       = 50,
        max       = 2000,
        interval  = 25,
        default   = 1500,
        suffix    = " studs",
        seperator = true,
        callback  = function(v) flags.esp_max_distance = v end
    })
end

do
    local col1 = espChamsTab:column({})
    local secChams = col1:section({ name = "Enemy Chams Suite", default = true, icon = "rbxassetid://6031075931" })

    secChams:toggle({
        name      = "Enable Enemy Chams",
        default   = false,
        seperator = true,
        callback  = function(v) flags.chams_enabled = v end
    })

    secChams:dropdown({
        name      = "Chams Kind",
        items     = { "Highlight", "Legacy", "ForceField", "Glass", "Neon" },
        default   = "Highlight",
        seperator = true,
        callback  = function(v) flags.chams_kind = v end
    })

    local cFill = secChams:toggle({
        name      = "Chams Fill",
        default   = false,
        seperator = true,
        callback  = function(v) flags.chams_fill_enabled = v end
    })
    cFill:colorpicker({
        name     = "Fill Color",
        color    = Color3.fromRGB(0, 162, 255),
        callback = function(c) flags.chams_fill_color = c end
    })

    secChams:slider({
        name      = "Fill Transparency",
        min       = 0,
        max       = 100,
        interval  = 5,
        default   = 50,
        suffix    = " %",
        seperator = true,
        callback  = function(v) flags.chams_fill_transparency = v / 100 end
    })

    local cOut = secChams:toggle({
        name      = "Chams Outline",
        default   = false,
        seperator = true,
        callback  = function(v) flags.chams_outline_enabled = v end
    })
    cOut:colorpicker({
        name     = "Outline Color",
        color    = Color3.fromRGB(255, 255, 255),
        callback = function(c) flags.chams_outline_color = c end
    })

    secChams:slider({
        name      = "Outline Transparency",
        min       = 0,
        max       = 100,
        interval  = 5,
        default   = 0,
        suffix    = " %",
        seperator = true,
        callback  = function(v) flags.chams_outline_transparency = v / 100 end
    })

    local cGlow = secChams:toggle({
        name      = "Chams Glow",
        default   = false,
        seperator = true,
        callback  = function(v) flags.chams_glow = v end
    })
    cGlow:colorpicker({
        name     = "Glow Color",
        color    = Color3.fromRGB(0, 162, 255),
        callback = function(c) flags.chams_glow_color = c end
    })

    secChams:toggle({
        name      = "Visible Depth Check",
        default   = false,
        seperator = true,
        callback  = function(v) flags.chams_visible_only = v end
    })

    local col2 = espChamsTab:column({})
    local secSkel = col2:section({ name = "Skeleton & Head Marker", default = true, icon = "rbxassetid://6031075931" })

    local skelTog = secSkel:toggle({
        name      = "Skeleton ESP",
        default   = false,
        seperator = true,
        callback  = function(v) flags.skeleton_enabled = v end
    })
    skelTog:colorpicker({
        name     = "Skeleton Color",
        color    = Color3.fromRGB(255, 255, 255),
        callback = function(c) flags.skeleton_color = c end
    })

    secSkel:slider({
        name      = "Skeleton Thickness",
        min       = 1,
        max       = 6,
        interval  = 1,
        default   = 1,
        suffix    = " px",
        seperator = true,
        callback  = function(v) flags.skeleton_thickness = v end
    })

    local hmTog = secSkel:toggle({
        name      = "Head Marker",
        default   = false,
        seperator = true,
        callback  = function(v) flags.head_marker_enabled = v end
    })
    hmTog:colorpicker({
        name     = "Head Marker Color",
        color    = Color3.fromRGB(255, 50, 50),
        callback = function(c) flags.head_marker_color = c end
    })

    secSkel:dropdown({
        name      = "Head Marker Shape",
        items     = { "Circle", "Cross", "Diamond" },
        default   = "Circle",
        seperator = true,
        callback  = function(v) flags.head_marker_shape = v end
    })

    secSkel:toggle({
        name      = "Head Marker Filled",
        default   = false,
        seperator = true,
        callback  = function(v) flags.head_marker_filled = v end
    })

    local hmOut = secSkel:toggle({
        name      = "Head Marker Outline",
        default   = false,
        seperator = true,
        callback  = function(v) flags.head_marker_outline = v end
    })
    hmOut:colorpicker({
        name     = "HM Outline Color",
        color    = Color3.fromRGB(0, 0, 0),
        callback = function(c) flags.head_marker_outline_color = c end
    })

    local arrTog = secSkel:toggle({
        name      = "Off-Screen Arrows",
        default   = false,
        seperator = true,
        callback  = function(v) flags.offscreen_arrows = v end
    })
    arrTog:colorpicker({
        name     = "Arrow Color",
        color    = Color3.fromRGB(0, 162, 255),
        callback = function(c) flags.arrow_color = c end
    })

    secSkel:slider({
        name      = "Arrow Radius",
        min       = 50,
        max       = 400,
        interval  = 10,
        default   = 150,
        suffix    = " px",
        seperator = true,
        callback  = function(v) flags.arrow_radius = v end
    })
end

do
    local col1 = espTracersTab:column({})
    local secTracer = col1:section({ name = "Tracers Suite", default = true, icon = "rbxassetid://6031075931" })

    local trTog = secTracer:toggle({
        name      = "Enable Tracer",
        default   = false,
        seperator = true,
        callback  = function(v) flags.esp_tracers = v end
    })
    trTog:colorpicker({
        name     = "Tracer Color",
        color    = Color3.fromRGB(0, 162, 255),
        callback = function(c) flags.esp_tracer_color = c end
    })

    secTracer:dropdown({
        name      = "From (Origin)",
        items     = { "Bottom", "Center", "Top", "Mouse" },
        default   = "Bottom",
        seperator = true,
        callback  = function(v) flags.esp_tracer_origin = v end
    })

    secTracer:dropdown({
        name      = "To (Target)",
        items     = { "Feet", "Head" },
        default   = "Feet",
        seperator = true,
        callback  = function(v) flags.esp_tracer_target = v end
    })

    secTracer:slider({
        name      = "Tracer Thickness",
        min       = 1,
        max       = 6,
        interval  = 1,
        default   = 1,
        suffix    = " px",
        seperator = true,
        callback  = function(v) flags.esp_tracer_thickness = v end
    })

    local trOut = secTracer:toggle({
        name      = "Tracer Outline",
        default   = false,
        seperator = true,
        callback  = function(v) flags.esp_tracer_outline = v end
    })
    trOut:colorpicker({
        name     = "Tracer Outline Color",
        color    = Color3.fromRGB(0, 0, 0),
        callback = function(c) flags.esp_tracer_outline_color = c end
    })

    secTracer:slider({
        name      = "Outline Thickness",
        min       = 1,
        max       = 6,
        interval  = 1,
        default   = 1,
        suffix    = " px",
        seperator = true,
        callback  = function(v) flags.esp_tracer_outline_thickness = v end
    })

    local col2 = espTracersTab:column({})
    local secBeams = col2:section({ name = "Bullet & Impact Tracers", default = true, icon = "rbxassetid://6031075931" })

    local beamTog = secBeams:toggle({
        name      = "Bullet Tracers (Beams)",
        default   = false,
        seperator = true,
        callback  = function(v) flags.bullet_tracers_enabled = v end
    })
    beamTog:colorpicker({
        name     = "Beam Color",
        color    = Color3.fromRGB(0, 162, 255),
        callback = function(c) flags.bullet_tracer_color = c end
    })

    local localBeam = secBeams:toggle({
        name      = "Local Bullet Beams",
        default   = false,
        seperator = true,
        callback  = function(v) flags.local_bullet_beams = v end
    })
    localBeam:colorpicker({
        name     = "Local Beam Color",
        color    = Color3.fromRGB(0, 255, 200),
        callback = function(c) flags.local_beam_color = c end
    })

    secBeams:slider({
        name      = "Beam Lifetime",
        min       = 0.5,
        max       = 5,
        interval  = 0.1,
        default   = 1.5,
        suffix    = " s",
        seperator = true,
        callback  = function(v) flags.bullet_tracer_lifetime = v end
    })

    secBeams:slider({
        name      = "Beam Width",
        min       = 0.5,
        max       = 4,
        interval  = 0.1,
        default   = 1.2,
        suffix    = " px",
        seperator = true,
        callback  = function(v) flags.bullet_tracer_width = v end
    })

    local impTog = secBeams:toggle({
        name      = "Bullet Impact Markers",
        default   = false,
        seperator = true,
        callback  = function(v) flags.impact_markers = v end
    })
    impTog:colorpicker({
        name     = "Impact Color",
        color    = Color3.fromRGB(255, 50, 50),
        callback = function(c) flags.impact_color = c end
    })
end

local miscMoveTab, miscAutoTab, miscExploitsTab = window:tab({
    name = "misc",
    icon = "rbxassetid://10709769508",
    tabs = { "Movement", "Automation", "Exploits" }
})

do
    local col1 = miscMoveTab:column({})
    local secGround = col1:section({ name = "Ground Movement", default = true, icon = "rbxassetid://6031075931" })

    secGround:toggle({
        name      = "Enable WalkSpeed Multiplier",
        default   = false,
        seperator = true,
        callback  = function(v) movementState.WalkSpeedEnabled = v end
    })

    secGround:slider({
        name      = "Walk Speed Multiplier",
        min       = 1.0,
        max       = 10.0,
        interval  = 0.1,
        default   = 1.5,
        suffix    = "x",
        seperator = true,
        callback  = function(v) movementState.WalkSpeedMult = v end
    })

    secGround:toggle({
        name      = "Noclip",
        default   = false,
        seperator = true,
        callback  = function(v) movementState.NoclipEnabled = v end
    })

    secGround:toggle({
        name      = "Auto Bunnyhop (B-Hop)",
        default   = false,
        seperator = true,
        callback  = function(v) movementState.BHopEnabled = v end
    })

    local col2 = miscMoveTab:column({})
    local secAir = col2:section({ name = "Flight & Jump", default = true, icon = "rbxassetid://6031075931" })

    secAir:toggle({
        name      = "Flight / Fly Hack",
        default   = false,
        seperator = true,
        callback  = function(v) movementState.FlightEnabled = v end
    })

    secAir:slider({
        name      = "Flight Speed",
        min       = 25,
        max       = 500,
        interval  = 25,
        default   = 100,
        suffix    = " studs/s",
        seperator = true,
        callback  = function(v) movementState.FlightSpeed = v end
    })

    secAir:toggle({
        name      = "Infinite Double Jumps",
        default   = false,
        seperator = true,
        callback  = function(v) movementState.DoubleJump = v end
    })
end

do
    local col1 = miscAutoTab:column({})
    local secLoadout = col1:section({ name = "Auto Loadout (Pre-Round)", default = true, icon = "rbxassetid://6031075931" })

    secLoadout:toggle({
        name      = "Enable Auto Loadout",
        default   = false,
        seperator = true,
        callback  = function(v) flags.auto_loadout_enabled = v end
    })

    secLoadout:dropdown({
        name      = "Slot 1 (Primary)",
        items     = { "Assault Rifle", "Sniper", "Shotgun", "Burst Rifle", "Minigun", "Paintball Gun" },
        default   = "Assault Rifle",
        seperator = true,
        callback  = function(v) flags.loadout_slot1 = v end
    })

    secLoadout:dropdown({
        name      = "Slot 2 (Secondary)",
        items     = { "Pistol", "Revolver", "SMG", "Uzi", "Wildcat" },
        default   = "Pistol",
        seperator = true,
        callback  = function(v) flags.loadout_slot2 = v end
    })

    secLoadout:dropdown({
        name      = "Slot 3 (Melee)",
        items     = { "Katana", "Knife", "Bat", "Fists", "Scythe" },
        default   = "Katana",
        seperator = true,
        callback  = function(v) flags.loadout_slot3 = v end
    })

    secLoadout:dropdown({
        name      = "Slot 4 (Utility)",
        items     = { "Grenade", "Smoke Grenade", "Flashbang", "Medkit", "Subspace Tripmine" },
        default   = "Grenade",
        seperator = true,
        callback  = function(v) flags.loadout_slot4 = v end
    })

    secLoadout:toggle({
        name      = "Auto Buy Ammunition",
        default   = false,
        seperator = true,
        callback  = function(v) flags.auto_buy_ammo = v end
    })

    local col2 = miscAutoTab:column({})
    local secStaff = col2:section({ name = "Staff Detector & Protection", default = true, icon = "rbxassetid://6031075931" })

    secStaff:toggle({
        name      = "Detect Staff / Admins",
        default   = false,
        seperator = true,
        callback  = function(v) flags.staff_detector = v end
    })

    secStaff:dropdown({
        name      = "Staff Detection Action",
        items     = { "Notify", "Server Hop", "Disconnect" },
        default   = "Notify",
        seperator = true,
        callback  = function(v) flags.staff_action = v end
    })
end

do
    local col1 = miscExploitsTab:column({})
    local secExp = col1:section({ name = "Exploits Suite", default = true, icon = "rbxassetid://6031075931" })

    secExp:toggle({
        name      = "Arcade Auto Respawn",
        default   = false,
        seperator = true,
        callback  = function(v) flags.arcade_respawn = v end
    })
end

local charFPTab, charAnglesTab, charDesyncTab = window:tab({
    name = "character",
    icon = "rbxassetid://10747373176",
    tabs = { "Fake Position", "Angles", "Desync" }
})

do
    local col1 = charFPTab:column({})
    local secFP = col1:section({ name = "Fake Position Engine", default = true, icon = "rbxassetid://6031075931" })

    secFP:toggle({
        name      = "Enable Fake Position (Underground)",
        default   = false,
        seperator = true,
        callback  = function(v) setFakePosition(v) end
    })

    secFP:keybind({
        name     = "Toggle Keybind",
        flag     = "fake_position_keybind_data",
        mode     = "Toggle",
        key      = Enum.KeyCode.X,
        callback = function() end
    })

    secFP:slider({
        name      = "Underground Depth",
        min       = 1.0,
        max       = 25.0,
        interval  = 0.2,
        default   = 5.8,
        suffix    = " studs",
        seperator = true,
        callback  = function(v)
            flags.fake_position_depth = v
            fakePos.Depth = v
            getgenv().SetFakePositionDepth(v)
        end
    })

    secFP:toggle({
        name      = "Dynamic Walk (WASD Smooth)",
        default   = false,
        seperator = true,
        callback  = function(v) fakePos.WalkMode = v end
    })

    secFP:toggle({
        name      = "Surface Camera Elevation",
        default   = false,
        seperator = true,
        callback  = function(v) fakePos.SurfaceCamera = v end
    })

    secFP:toggle({
        name      = "Auto Noclip Underground",
        default   = false,
        seperator = true,
        callback  = function(v) fakePos.AutoNoclip = v end
    })

    secFP:toggle({
        name      = "Auto Handoff On Shoot",
        default   = false,
        seperator = true,
        callback  = function(v) fakePos.AutoHandoff = v end
    })

    local col2 = charFPTab:column({})
    local secFPCloak = col2:section({ name = "Desync Cloak & Visualizer", default = true, icon = "rbxassetid://6031075931" })

    local ghostTog = secFPCloak:toggle({
        name      = "Visualise Fake Position (Ghost)",
        default   = false,
        seperator = true,
        callback  = function(v)
            fakePos.VisualizerEnabled = v
            updateGhostVisualizer()
        end
    })
    ghostTog:colorpicker({
        name     = "Ghost Color",
        color    = Color3.fromRGB(0, 162, 255),
        callback = function(c)
            fakePos.VisualizerColor = c
            updateGhostVisualizer()
        end
    })

    secFPCloak:toggle({
        name      = "Panic Jitter Mode (Anti-Aimbot)",
        default   = false,
        seperator = true,
        callback  = function(v) fakePos.Panic = v end
    })

    secFPCloak:slider({
        name      = "Panic X Min Range",
        min       = -15,
        max       = 0,
        interval  = 1,
        default   = -5,
        suffix    = " studs",
        seperator = true,
        callback  = function(v) fakePos.PanicMinX = v end
    })

    secFPCloak:slider({
        name      = "Panic X Max Range",
        min       = 0,
        max       = 15,
        interval  = 1,
        default   = 5,
        suffix    = " studs",
        seperator = true,
        callback  = function(v) fakePos.PanicMaxX = v end
    })

    secFPCloak:toggle({
        name      = "Panic Z Jitter Axis",
        default   = false,
        seperator = true,
        callback  = function(v) fakePos.PanicZ = v end
    })

    secFPCloak:toggle({
        name      = "Hide Character Meshes",
        default   = false,
        seperator = true,
        callback  = function(v)
            fakePos.HideMeshes = v
            getgenv().SetFakePositionHideMesh(v)
        end
    })

    secFPCloak:toggle({
        name      = "Freeze Desync Animation Pose",
        default   = false,
        seperator = true,
        callback  = function(v)
            fakePos.AnimationDesync = v
            if fakePos.Enabled then
                if v then playAnimDesync() else stopAnimDesync() end
            end
        end
    })

    secFPCloak:toggle({
        name      = "Zero Assembly Velocity",
        default   = false,
        seperator = true,
        callback  = function(v) fakePos.ZeroVelocity = v end
    })
end

do
    local col1 = charAnglesTab:column({})
    local secAngles = col1:section({ name = "Pitch & Yaw Manipulation", default = true, icon = "rbxassetid://6031075931" })

    secAngles:toggle({
        name      = "Invert Head Pitch (Anti-Headshot)",
        default   = false,
        seperator = true,
        callback  = function(v) fakePos.InvertPitch = v end
    })

    secAngles:slider({
        name      = "Custom Pitch Angle",
        min       = -89,
        max       = 89,
        interval  = 1,
        default   = -89,
        suffix    = " deg",
        seperator = true,
        callback  = function(v) fakePos.CustomPitch = v end
    })

    secAngles:slider({
        name      = "Custom Yaw Angle",
        min       = 0,
        max       = 360,
        interval  = 5,
        default   = 0,
        suffix    = " deg",
        seperator = true,
        callback  = function(v) fakePos.CustomYaw = v end
    })

    local col2 = charAnglesTab:column({})
    local secHitbox = col2:section({ name = "Hitbox Orientation Desync", default = true, icon = "rbxassetid://6031075931" })

    secHitbox:dropdown({
        name      = "Hitbox Preset",
        items     = { "Inverted Pitch (-89)", "Zero Pitch", "Backward Look", "Spinbot" },
        default   = "Inverted Pitch (-89)",
        seperator = true,
        callback  = function(v)
            if v == "Inverted Pitch (-89)" then
                fakePos.InvertPitch = true
            elseif v == "Zero Pitch" then
                fakePos.InvertPitch = false
                fakePos.CustomPitch = 0
            elseif v == "Backward Look" then
                fakePos.InvertPitch = false
                fakePos.CustomYaw = 180
            end
        end
    })

    secHitbox:slider({
        name      = "Spinbot Yaw Speed",
        min       = 1,
        max       = 50,
        interval  = 1,
        default   = 15,
        seperator = true,
        callback  = function(v) flags.antiaim_spin_speed = v end
    })
end

do
    local col1 = charDesyncTab:column({})
    local secDesync = col1:section({ name = "Subterranean & Void Desync", default = true, icon = "rbxassetid://6031075931" })

    secDesync:dropdown({
        name      = "Desync Mode",
        items     = { "Position Desync V2", "Voidspam Desync", "Lite Desync" },
        default   = "Position Desync V2",
        seperator = true,
        callback  = function(v) fakePos.DesyncMode = v end
    })

    secDesync:toggle({
        name      = "Auto Void On Low HP (< 25 HP)",
        default   = false,
        seperator = true,
        callback  = function(v) flags.auto_void_low_hp = v end
    })

    secDesync:toggle({
        name      = "Melee Underground Strike",
        default   = false,
        seperator = true,
        callback  = function(v) flags.melee_underground_strike = v end
    })

    secDesync:slider({
        name      = "Melee Desync Reach",
        min       = 5,
        max       = 30,
        interval  = 1,
        default   = 18,
        suffix    = " studs",
        seperator = true,
        callback  = function(v) flags.melee_reach = v end
    })

    local col2 = charDesyncTab:column({})
    local secLag = col2:section({ name = "Packet Choking (Fake Lag)", default = true, icon = "rbxassetid://6031075931" })

    secLag:toggle({
        name      = "Fake Lag / Choke Packets",
        default   = false,
        seperator = true,
        callback  = function(v) flags.fakelag_enabled = v end
    })

    secLag:slider({
        name      = "Choke Limit",
        min       = 1,
        max       = 14,
        interval  = 1,
        default   = 6,
        suffix    = " ticks",
        seperator = true,
        callback  = function(v) flags.fakelag_choke = v end
    })

    secLag:dropdown({
        name      = "Lag Mode",
        items     = { "Fluctuate", "Static", "Adaptive (Peak On Shoot)" },
        default   = "Fluctuate",
        seperator = true,
        callback  = function(v) flags.fakelag_mode = v end
    })

    secLag:toggle({
        name      = "Break Lag Comp (LC Breaker)",
        default   = false,
        seperator = true,
        callback  = function(v) flags.fakelag_break_lc = v end
    })
end

window:seperator({ name = "other" })

local configMainTab, settingsMainTab = window:tab({
    name = "configs",
    icon = "rbxassetid://10734950309",
    tabs = { "configs", "settings" }
})

do
    local col1 = configMainTab:column({})
    local secConfigList = col1:section({ name = "Saved Configs", size = 1, default = true, icon = "rbxassetid://139628202576511" })
    
    local cfgList
    cfgList = secConfigList:list({
        options = { "default" },
        default = "default",
        flag = "selected_config_name",
        callback = function(option)
            flags.selected_config_name = option
        end
    })

    local function refreshConfigs()
        pcall(function()
            if not isfolder or not listfiles then return end
            if not isfolder("sleepy") then makefolder("sleepy") end
            if not isfolder("sleepy/configs") then makefolder("sleepy/configs") end
            local files = listfiles("sleepy/configs")
            local list = {}
            for _, f in ipairs(files) do
                local name = tostring(f):gsub("sleepy/configs[\\/]", ""):gsub("sleepy[\\/]configs[\\/]", ""):gsub(".cfg", ""):gsub(".json", "")
                table.insert(list, name)
            end
            if #list == 0 then table.insert(list, "default") end
            if cfgList and cfgList.refresh_options then
                cfgList.refresh_options(list)
            end
        end)
    end

    local col2 = configMainTab:column({})
    local secConfigActions = col2:section({ name = "Config Actions", size = 1, default = true, icon = "rbxassetid://129380150574313" })
    
    secConfigActions:textbox({
        name = "Config Name",
        default = "",
        seperator = true,
        callback = function(t)
            flags.config_custom_name = t
        end
    })

    secConfigActions:button({
        name = "Save Config",
        callback = function()
            local cname = flags.config_custom_name
            if not cname or #cname == 0 then cname = flags.selected_config_name end
            if not cname or #cname == 0 then cname = "default" end
            pcall(function()
                if not isfolder("sleepy") then makefolder("sleepy") end
                if not isfolder("sleepy/configs") then makefolder("sleepy/configs") end
                local data = Library:get_config()
                writefile("sleepy/configs/" .. cname .. ".cfg", data)
                refreshConfigs()
                if Library.notifications then
                    Library.notifications:create_notification({
                        name = "Configs",
                        info = "Saved config: " .. cname,
                        lifetime = 3
                    })
                end
            end)
        end
    })

    secConfigActions:button({
        name = "Load Config",
        callback = function()
            local cname = flags.selected_config_name or flags.config_custom_name or "default"
            pcall(function()
                local path = "sleepy/configs/" .. cname .. ".cfg"
                if isfile and isfile(path) then
                    local data = readfile(path)
                    Library:load_config(data)
                    if Library.notifications then
                        Library.notifications:create_notification({
                            name = "Configs",
                            info = "Loaded config: " .. cname,
                            lifetime = 3
                        })
                    end
                else
                    warn("[Sleepy Hub] Config file not found: " .. path)
                end
            end)
        end
    })

    secConfigActions:button({
        name = "Delete Config",
        callback = function()
            local cname = flags.selected_config_name
            if not cname or #cname == 0 or cname == "default" then return end
            pcall(function()
                local path = "sleepy/configs/" .. cname .. ".cfg"
                if isfile and isfile(path) then
                    delfile(path)
                    refreshConfigs()
                    if Library.notifications then
                        Library.notifications:create_notification({
                            name = "Configs",
                            info = "Deleted config: " .. cname,
                            lifetime = 3
                        })
                    end
                end
            end)
        end
    })

    secConfigActions:button({
        name = "Export to Clipboard",
        callback = function()
            pcall(function()
                if setclipboard then
                    setclipboard(Library:get_config())
                    if Library.notifications then
                        Library.notifications:create_notification({
                            name = "Configs",
                            info = "Config copied to clipboard!",
                            lifetime = 3
                        })
                    end
                end
            end)
        end
    })

    secConfigActions:button({
        name = "Import from Clipboard",
        callback = function()
            pcall(function()
                if getclipboard then
                    local clip = getclipboard()
                    if clip and #clip > 0 then
                        Library:load_config(clip)
                        if Library.notifications then
                            Library.notifications:create_notification({
                                name = "Configs",
                                info = "Config loaded from clipboard!",
                                lifetime = 3
                            })
                        end
                    end
                end
            end)
        end
    })

    task.defer(refreshConfigs)
end

do
    local col1 = settingsMainTab:column({})
    local secTheme = col1:section({ name = "Menu Theme & Visuals", size = 1, default = true, icon = "rbxassetid://6031075931" })

    secTheme:colorpicker({
        name = "Accent Color",
        color = Color3.fromRGB(0, 162, 255),
        callback = function(c)
            Library:update_theme("accent", c)
        end
    })

    secTheme:keybind({
        name = "Menu Toggle Keybind",
        key = Enum.KeyCode.RightShift,
        default = true,
        mode = "Toggle",
        callback = function(state)
            if window and window.toggle_menu then
                window.toggle_menu(state)
            end
        end
    })

    secTheme:toggle({
        name = "Show Keybinds Widget",
        default = false,
        seperator = true,
        callback = function(v)
            flags.show_keybinds_widget = v
            pcall(function()
                local coreGui = (gethui and gethui()) or game:GetService("CoreGui")
                local kb = coreGui:FindFirstChild("_MeowKeybindsWidget")
                if kb then kb.Enabled = v end
            end)
        end
    })

    secTheme:toggle({
        name = "Show Music Player",
        default = false,
        seperator = true,
        callback = function(v)
            flags.show_music_player = v
            pcall(function()
                local coreGui = (gethui and gethui()) or game:GetService("CoreGui")
                local mp = coreGui:FindFirstChild("_MeowMusicPlayer")
                if mp then mp.Enabled = v end
            end)
        end
    })

    local col2 = settingsMainTab:column({})
    local secUtils = col2:section({ name = "Game Utilities", size = 1, default = true, icon = "rbxassetid://6031075931" })

    secUtils:button({
        name = "Rejoin Server",
        callback = function()
            pcall(function()
                game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, lp)
            end)
        end
    })

    secUtils:button({
        name = "Server Hop",
        callback = function()
            pcall(function()
                local ts = game:GetService("TeleportService")
                local http = game:GetService("HttpService")
                local servers = http:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
                for _, s in ipairs(servers.data) do
                    if s.playing < s.maxPlayers and s.id ~= game.JobId then
                        ts:TeleportToPlaceInstance(game.PlaceId, s.id, lp)
                        break
                    end
                end
            end)
        end
    })

    secUtils:button({
        name = "Unload Cheat",
        callback = function()
            pcall(function()
                if Library and Library.items then
                    Library.items:Destroy()
                end
                if shared.MeowCosmeticsGui then
                    shared.MeowCosmeticsGui:Destroy()
                end
                local coreGui = (gethui and gethui()) or game:GetService("CoreGui")
                local pill = coreGui:FindFirstChild("_MeowCosmeticPill")
                if pill then pill:Destroy() end
                meowState.Destroyed = true
            end)
        end
    })
end

Library:init_config(window)

initProceduralDrawings()

local stepConn = RunService.Heartbeat:Connect(function()
    if meowState.Destroyed then return end
    get_target()
    runCombatAimbot()
    runMeleeAura()
    updateTargetVisuals()
    updateWeaponVisuals()
    runAutoLoadout()
    runAutoQueue()
    runBunnyHop()
    runSpoofers()
end)

local renderConn = RunService.RenderStepped:Connect(function(dt)
    if meowState.Destroyed then return end
    runAntiAim()
    updateEsp()
    updateChams()
    updateCrosshair()
    updateFovCircles()
    updateBulletTracers()
    updateCameraAndWorld(dt)
    updateWorldLighting(dt)
end)

task.spawn(function()
    task.wait(0.2)
    pcall(function()
        if Library and Library.items then
            for _, v in ipairs(Library.items:GetDescendants()) do
                if v:IsA("TextButton") then
                    local label = v:FindFirstChildOfClass("TextLabel")
                    if label and label.Text == "main" then
                        if getconnections then
                            for _, conn in ipairs(getconnections(v.MouseButton1Down)) do
                                pcall(function()
                                    local fn = conn.Function
                                    if fn and debug and debug.getupvalues then
                                        for _, u in pairs(debug.getupvalues(fn)) do
                                            if type(u) == "table" and u.open_tab then
                                                u.open_tab()
                                            end
                                        end
                                    end
                                end)
                            end
                        end
                    end
                end
            end
        end
    end)
end)

Library.notifications:create_notification({
    name     = "Sleepy.gg 🎃",
    info     = "Halloween Edition loaded with Music Player & Blue UI!",
    lifetime = 4
})

print("[Sleepy.gg 🎃] Ultimate script loaded with Music Player & Electric Blue UI!")
