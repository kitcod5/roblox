-- StarterPlayer/StarterPlayerScripts/CombatClient
-- DEEPWOKEN COMBAT CLIENT (FIXED)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")

local Combat = ReplicatedStorage:WaitForChild("Combat")
local CombatData = require(Combat:WaitForChild("CombatData"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CombatRemote = Remotes:WaitForChild("CombatRemote")

-- Animations
local M1Tracks = {}
local CritTrack = nil
local HitTracks = {}
local KnockbackTrack = nil

-- State
local IsSwinging = false
local InRecovery = false
local CanM1 = true
local CanCrit = true
local InCombatMode = false
local LastSwingTime = 0
local BaseWalkSpeed = CombatData.Settings.WALK_SPEED

-- Set character bool value
local function SetBool(name, val)
	local v = character:FindFirstChild(name)
	if not v then
		v = Instance.new("BoolValue")
		v.Name = name
		v.Parent = character
	end
	v.Value = val
end

-- Get character bool value
local function GetBool(name)
	local v = character:FindFirstChild(name)
	return v and v.Value == true
end

-- Load animations
local function LoadAnimations()
	-- M1 anims
	for i = 1, 5 do
		local id = CombatData.Animations["M1_" .. i]
		if id then
			local anim = Instance.new("Animation")
			anim.AnimationId = id
			local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
			if ok then
				track.Priority = Enum.AnimationPriority.Action2
				M1Tracks[i] = track
			end
		end
	end

	-- Crit
	if CombatData.Animations.CRIT then
		local anim = Instance.new("Animation")
		anim.AnimationId = CombatData.Animations.CRIT
		local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
		if ok then
			track.Priority = Enum.AnimationPriority.Action3
			CritTrack = track
		end
	end

	-- Hit reactions
	for i = 1, 4 do
		local id = CombatData.Animations["HIT_" .. i]
		if id then
			local anim = Instance.new("Animation")
			anim.AnimationId = id
			local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
			if ok then
				track.Priority = Enum.AnimationPriority.Action4
				track.Looped = false
				HitTracks[i] = track
			end
		end
	end

	-- Knockback
	if CombatData.Animations.KNOCKBACK then
		local anim = Instance.new("Animation")
		anim.AnimationId = CombatData.Animations.KNOCKBACK
		local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
		if ok then
			track.Priority = Enum.AnimationPriority.Action4
			track.Looped = false
			KnockbackTrack = track
		end
	end

	print("[COMBAT] Animations loaded")
end

-- Stop M1 animations
local function StopM1Anims()
	for _, t in pairs(M1Tracks) do
		if t and t.IsPlaying then t:Stop(0.1) end
	end
end

-- Stop all combat animations
local function StopAllCombatAnims()
	StopM1Anims()
	if CritTrack and CritTrack.IsPlaying then CritTrack:Stop(0.1) end
	for _, t in pairs(HitTracks) do
		if t and t.IsPlaying then t:Stop(0.1) end
	end
	if KnockbackTrack and KnockbackTrack.IsPlaying then KnockbackTrack:Stop(0.15) end
end

-- Clear all combat states (for counter window)
local function ClearCombatStates()
	IsSwinging = false
	InRecovery = false
	SetBool("IsAttacking", false)
	SetBool("InRecovery", false)
end

-- Speed management
RunService.Heartbeat:Connect(function()
	if not humanoid then return end

	-- If we're in counter window, don't slow down
	if GetBool("InCounter") then
		humanoid.WalkSpeed = BaseWalkSpeed
		return
	end

	local targetSpeed = BaseWalkSpeed

	-- Priority: Blocking > Swinging > Normal
	if GetBool("IsBlocking") then
		targetSpeed = CombatData.Settings.BLOCK_SPEED
	elseif IsSwinging or InCombatMode then
		targetSpeed = CombatData.Settings.COMBAT_SPEED
	end

	-- Smooth lerp
	humanoid.WalkSpeed = humanoid.WalkSpeed + (targetSpeed - humanoid.WalkSpeed) * 0.12

	-- Exit combat mode after not swinging
	if InCombatMode and tick() - LastSwingTime > 1.0 then
		InCombatMode = false
	end
end)

-- Play M1 animation
local function PlayM1(combo)
	local track = M1Tracks[combo]
	if not track then return end

	StopM1Anims()

	-- Adjust speed to match swing time
	local animLength = track.Length
	if animLength > 0 then
		track:AdjustSpeed(animLength / CombatData.Settings.M1_SWING_TIME)
	end

	track:Play(0.05)

	IsSwinging = true
	InCombatMode = true
	LastSwingTime = tick()
	SetBool("IsAttacking", true)

	-- Swing duration then recovery
	task.delay(CombatData.Settings.M1_SWING_TIME, function()
		IsSwinging = false
		SetBool("IsAttacking", false)
		InRecovery = true
		SetBool("InRecovery", true)

		task.delay(CombatData.Settings.M1_RECOVERY, function()
			InRecovery = false
			SetBool("InRecovery", false)
		end)
	end)
end

-- Play Crit animation
local function PlayCrit()
	if not CritTrack then return end

	StopM1Anims()

	local animLength = CritTrack.Length
	if animLength > 0 then
		CritTrack:AdjustSpeed(animLength / CombatData.Settings.CRIT_SWING_TIME)
	end

	CritTrack:Play(0.05)

	IsSwinging = true
	InCombatMode = true
	LastSwingTime = tick()
	SetBool("IsAttacking", true)

	task.delay(CombatData.Settings.CRIT_SWING_TIME, function()
		IsSwinging = false
		SetBool("IsAttacking", false)
		InRecovery = true
		SetBool("InRecovery", true)

		task.delay(CombatData.Settings.CRIT_RECOVERY, function()
			InRecovery = false
			SetBool("InRecovery", false)
		end)
	end)
end

-- Play hit reaction
local function PlayHit(num)
	local track = HitTracks[num] or HitTracks[math.random(1,4)]
	if not track then return end
	StopAllCombatAnims()
	ClearCombatStates()

	track:Play(0.05)
end

-- Play knockback
local function PlayKnockback()
	if not KnockbackTrack then return end

	StopAllCombatAnims()
	ClearCombatStates()

	KnockbackTrack:Play(0.05)

	-- Auto stop after duration
	task.delay(0.5, function()
		if KnockbackTrack and KnockbackTrack.IsPlaying then
			KnockbackTrack:Stop(0.2)
		end
	end)
end

-- Can we attack?
local function CanAttack()
	if GetBool("IsDashing") then return false end
	if GetBool("IsStunned") then return false end
	if GetBool("IsBlocking") then return false end
	if GetBool("InBlockAnim") then return false end
	if IsSwinging then return false end
	if InRecovery then return false end
	return true
end

-- Server events
CombatRemote.OnClientEvent:Connect(function(action, data)
	if action == "PLAY_M1" then
		PlayM1(data)

	elseif action == "PLAY_CRIT" then
		PlayCrit()

	elseif action == "PLAY_HIT" then
		PlayHit(data)

	elseif action == "PLAY_KNOCKBACK" then
		PlayKnockback()

	elseif action == "GOT_PARRIED" then
		-- We got parried - stop our attack
		StopAllCombatAnims()
		ClearCombatStates()

	elseif action == "COUNTER_WINDOW" then
		-- WE PARRIED - Clear all states so we can attack!
		StopAllCombatAnims()
		ClearCombatStates()
		SetBool("IsBlocking", false)
		SetBool("InBlockAnim", false)
		SetBool("InParryWindow", false)
		SetBool("IsStunned", false)
		SetBool("InCounter", true) -- This lets speed management know we're in counter

		-- Reset speed immediately so we're not slow
		InCombatMode = false
		humanoid.WalkSpeed = BaseWalkSpeed

		print("[COMBAT] Counter window! Attack now!")

		-- Counter window expires after duration
		task.delay(CombatData.Settings.COUNTER_WINDOW, function()
			SetBool("InCounter", false)
		end)

	elseif action == "BLOCKED" then
		-- We blocked something

	elseif action == "BLOCK_BROKEN" then
		-- Our block was broken
		StopAllCombatAnims()
		ClearCombatStates()

	elseif action == "HIT_BLOCKED" then
		-- Our attack was blocked

	elseif action == "HIT_LANDED" then
		-- We hit someone
	end
end)

-- Input
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	-- M1 Attack
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if CanM1 and CanAttack() then
			CombatRemote:FireServer("M1")
			CanM1 = false
			task.delay(CombatData.Settings.M1_COOLDOWN, function()
				CanM1 = true
			end)
		end
	end

	-- Crit Attack
	if input.KeyCode == Enum.KeyCode.R then
		if CanCrit and CanAttack() then
			CombatRemote:FireServer("CRIT")
			CanCrit = false
			task.delay(CombatData.Settings.CRIT_COOLDOWN, function()
				CanCrit = true
			end)
		end
	end
end)

-- Character respawn
player.CharacterAdded:Connect(function(char)
	character = char
	humanoid = character:WaitForChild("Humanoid")
	animator = humanoid:WaitForChild("Animator")

	M1Tracks = {}
	CritTrack = nil
	HitTracks = {}
	KnockbackTrack = nil
	IsSwinging = false
	InRecovery = false
	CanM1 = true
	CanCrit = true
	InCombatMode = false
	BaseWalkSpeed = CombatData.Settings.WALK_SPEED

	task.wait(0.3)
	LoadAnimations()
end)

task.wait(0.3)
LoadAnimations()
print("[COMBAT] Client ready!")
