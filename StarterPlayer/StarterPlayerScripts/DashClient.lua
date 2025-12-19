-- StarterPlayer/StarterPlayerScripts/DashClient
-- DEEPWOKEN DASH CLIENT (FIXED MOVEMENT LOCK)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")
local rootPart = character:WaitForChild("HumanoidRootPart")

local Combat = ReplicatedStorage:WaitForChild("Combat")
local CombatData = require(Combat:WaitForChild("CombatData"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DashRemote = Remotes:FindFirstChild("DashRemote")

-- Create DashRemote if doesn't exist
if not DashRemote then
	DashRemote = Instance.new("RemoteEvent")
	DashRemote.Name = "DashRemote"
	DashRemote.Parent = Remotes
end

-- Animations
local DashTracks = {}
local RunTrack = nil

-- State
local IsDashing = false
local CanDash = true
local IsSprinting = false
local LastWPress = 0
local WKeyDown = false
local BaseSpeed = CombatData.Settings.WALK_SPEED
local DashLockConnection = nil

local function SetBool(name, val)
	local v = character:FindFirstChild(name)
	if not v then
		v = Instance.new("BoolValue")
		v.Name = name
		v.Parent = character
	end
	v.Value = val
end

local function GetBool(name)
	local v = character:FindFirstChild(name)
	return v and v.Value == true
end

local function LoadAnimations()
	for _, name in ipairs({"DASH_FRONT", "DASH_LEFT", "DASH_RIGHT", "DASH_BACK"}) do
		local id = CombatData.Animations[name]
		if id then
			local anim = Instance.new("Animation")
			anim.AnimationId = id
			local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
			if ok then
				track.Priority = Enum.AnimationPriority.Action4
				DashTracks[name] = track
			end
		end
	end

	if CombatData.Animations.RUN then
		local anim = Instance.new("Animation")
		anim.AnimationId = CombatData.Animations.RUN
		local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
		if ok then
			track.Priority = Enum.AnimationPriority.Movement
			track.Looped = true
			RunTrack = track
		end
	end

	print("[DASH] Animations loaded")
end

local function GetMoveDirection()
	local move = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + Vector3.new(0, 0, -1) end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move + Vector3.new(0, 0, 1) end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move + Vector3.new(-1, 0, 0) end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + Vector3.new(1, 0, 0) end
	return move
end

local function GetDashType(move)
	if move.Magnitude == 0 then return "DASH_FRONT" end
	local n = move.Unit
	if n.Z < -0.5 then return "DASH_FRONT" end
	if n.Z > 0.5 then return "DASH_BACK" end
	if n.X < -0.5 then return "DASH_LEFT" end
	if n.X > 0.5 then return "DASH_RIGHT" end
	return "DASH_FRONT"
end

local function StopSprint()
	if not IsSprinting then return end
	IsSprinting = false
	humanoid.WalkSpeed = BaseSpeed
	if RunTrack and RunTrack.IsPlaying then
		RunTrack:Stop(0.15)
	end
end

local function StartSprint()
	if IsSprinting or IsDashing then return end
	if GetBool("IsStunned") then return end
	if GetBool("IsBlocking") then return end

	IsSprinting = true
	humanoid.WalkSpeed = CombatData.Settings.SPRINT_SPEED
	if RunTrack then
		RunTrack:Play(0.15)
	end
end

local function DoDash(dashType)
	local track = DashTracks[dashType]
	if not track then return end

	IsDashing = true
	local wasSprinting = IsSprinting

	SetBool("IsDashing", true)

	-- Clear other states
	SetBool("IsBlocking", false)
	SetBool("InBlockAnim", false)
	SetBool("IsAttacking", false)

	-- Stop sprint but remember it
	if IsSprinting then
		IsSprinting = false
		if RunTrack and RunTrack.IsPlaying then RunTrack:Stop(0) end
	end

	-- Store original values
	local origSpeed = humanoid.WalkSpeed
	local origJumpPower = humanoid.JumpPower
	local origJumpHeight = humanoid.JumpHeight

	-- LOCK MOVEMENT (but don't disable Running state - that breaks anims)
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	-- CONTINUOUS FRAME-BY-FRAME LOCK
	DashLockConnection = RunService.RenderStepped:Connect(function()
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.Jump = false
	end)

	-- Only stop non-core animations (not walk/run/idle)
	for _, t in pairs(DashTracks) do
		if t and t.IsPlaying and t ~= track then
			t:Stop(0)
		end
	end
	if RunTrack and RunTrack.IsPlaying then
		RunTrack:Stop(0)
	end

	-- Play dash animation
	track:Play(0.02)

	-- Calculate dash direction (camera relative)
	local cam = workspace.CurrentCamera
	local moveDir = GetMoveDirection()
	local worldDir

	if moveDir.Magnitude > 0 then
		local camCF = cam.CFrame
		worldDir = (camCF * CFrame.new(moveDir)).Position - camCF.Position
		worldDir = Vector3.new(worldDir.X, 0, worldDir.Z)
		if worldDir.Magnitude > 0 then
			worldDir = worldDir.Unit
		else
			worldDir = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z).Unit
		end
	else
		local look = cam.CFrame.LookVector
		worldDir = Vector3.new(look.X, 0, look.Z).Unit
	end

	-- Apply dash velocity
	local dashVel = Instance.new("BodyVelocity")
	dashVel.Name = "DashVelocity"
	dashVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	dashVel.Velocity = worldDir * CombatData.Settings.DASH_FORCE
	dashVel.Parent = rootPart

	-- Lock rotation
	local dashGyro = Instance.new("BodyGyro")
	dashGyro.Name = "DashGyro"
	dashGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	dashGyro.CFrame = CFrame.new(rootPart.Position, rootPart.Position + worldDir)
	dashGyro.P = 500000
	dashGyro.D = 10000
	dashGyro.Parent = rootPart

	-- Wait for dash to complete
	task.wait(CombatData.Settings.DASH_DURATION)

	-- Cleanup
	if DashLockConnection then
		DashLockConnection:Disconnect()
		DashLockConnection = nil
	end

	dashVel:Destroy()
	dashGyro:Destroy()

	-- Restore humanoid
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	humanoid.JumpPower = origJumpPower
	humanoid.JumpHeight = origJumpHeight
	humanoid.AutoRotate = true
	SetBool("IsDashing", false)
	IsDashing = false

	-- Restore sprint if W still held
	if wasSprinting and UserInputService:IsKeyDown(Enum.KeyCode.W) then
		IsSprinting = true
		humanoid.WalkSpeed = CombatData.Settings.SPRINT_SPEED
		if RunTrack then RunTrack:Play(0.1) end
	else
		humanoid.WalkSpeed = BaseSpeed
	end
end

-- Input
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	-- Dash (Q)
	if input.KeyCode == Enum.KeyCode.Q then
		if IsDashing or not CanDash then return end
		if GetBool("IsStunned") then return end
		if GetBool("InBlockAnim") then return end

		local moveDir = GetMoveDirection()
		local dashType = GetDashType(moveDir)

		DashRemote:FireServer(dashType)
		DoDash(dashType)

		CanDash = false
		task.delay(CombatData.Settings.DASH_COOLDOWN, function()
			CanDash = true
		end)
	end

	-- Sprint (double-tap W)
	if input.KeyCode == Enum.KeyCode.W then
		local now = tick()
		if not WKeyDown then
			WKeyDown = true
			if now - LastWPress < CombatData.Settings.DOUBLE_TAP_TIME then
				StartSprint()
			end
			LastWPress = now
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.W then
		WKeyDown = false
		StopSprint()
	end
end)

-- Sprint monitor
RunService.Heartbeat:Connect(function()
	if not IsSprinting then return end
	if IsDashing then return end

	if not UserInputService:IsKeyDown(Enum.KeyCode.W) then
		StopSprint()
		return
	end

	if GetBool("IsStunned") or GetBool("IsBlocking") then
		StopSprint()
	end
end)

-- Respawn
player.CharacterAdded:Connect(function(char)
	character = char
	humanoid = character:WaitForChild("Humanoid")
	animator = humanoid:WaitForChild("Animator")
	rootPart = character:WaitForChild("HumanoidRootPart")

	if DashLockConnection then
		DashLockConnection:Disconnect()
		DashLockConnection = nil
	end

	DashTracks = {}
	RunTrack = nil
	IsDashing = false
	CanDash = true
	IsSprinting = false
	LastWPress = 0
	WKeyDown = false

	task.wait(0.3)
	LoadAnimations()
	BaseSpeed = humanoid.WalkSpeed
end)

task.wait(0.3)
LoadAnimations()
print("[DASH] Client ready!")
