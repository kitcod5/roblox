-- StarterPlayer/StarterPlayerScripts/BlockClient
-- DEEPWOKEN BLOCK CLIENT (COMPLETELY REWRITTEN)

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
local BlockTrack = nil
local ParryTracks = {}
local ParriedTracks = {}
local BlockBreakTrack = nil

-- Simple state
local Blocking = false
local CanBlock = true
local FHeld = false

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
	if CombatData.Animations.BLOCK then
		local anim = Instance.new("Animation")
		anim.AnimationId = CombatData.Animations.BLOCK
		local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
		if ok then
			track.Priority = Enum.AnimationPriority.Action3
			track.Looped = true
			BlockTrack = track
		end
	end

	for _, name in ipairs({"PARRY_LEFT", "PARRY_RIGHT"}) do
		local id = CombatData.Animations[name]
		if id then
			local anim = Instance.new("Animation")
			anim.AnimationId = id
			local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
			if ok then
				track.Priority = Enum.AnimationPriority.Action4
				track.Looped = false
				ParryTracks[name] = track
			end
		end
	end

	for i = 1, 2 do
		local id = CombatData.Animations["BEING_PARRIED_" .. i]
		if id then
			local anim = Instance.new("Animation")
			anim.AnimationId = id
			local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
			if ok then
				track.Priority = Enum.AnimationPriority.Action4
				track.Looped = false
				ParriedTracks[i] = track
			end
		end
	end

	if CombatData.Animations.BLOCK_BREAKED then
		local anim = Instance.new("Animation")
		anim.AnimationId = CombatData.Animations.BLOCK_BREAKED
		local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
		if ok then
			track.Priority = Enum.AnimationPriority.Action4
			track.Looped = false
			BlockBreakTrack = track
		end
	end

	print("[BLOCK] Animations loaded")
end

local function StopAllBlockAnims()
	if BlockTrack and BlockTrack.IsPlaying then BlockTrack:Stop(0.1) end
	for _, t in pairs(ParryTracks) do
		if t and t.IsPlaying then t:Stop(0.1) end
	end
end

local function FullReset()
	Blocking = false
	SetBool("IsBlocking", false)
	SetBool("InBlockAnim", false)
	SetBool("InParryWindow", false)
	StopAllBlockAnims()
end

local function StopBlock()
	if not Blocking then return end

	Blocking = false
	SetBool("IsBlocking", false)
	SetBool("InBlockAnim", false)
	SetBool("InParryWindow", false)
	StopAllBlockAnims()

	CombatRemote:FireServer("BLOCK_STOP")
end

local function StartBlock()
	if Blocking then return end
	if not CanBlock then return end
	if GetBool("IsDashing") then return end
	if GetBool("IsStunned") then return end
	if GetBool("IsAttacking") then return end

	Blocking = true
	SetBool("IsBlocking", true)
	SetBool("InBlockAnim", true)

	-- Cooldown
	CanBlock = false
	task.delay(CombatData.Settings.PARRY_COOLDOWN, function()
		CanBlock = true
	end)

	-- Tell server
	CombatRemote:FireServer("BLOCK_START")

	-- Play parry animation first
	local choice = math.random(1, 2) == 1 and "PARRY_LEFT" or "PARRY_RIGHT"
	local parryTrack = ParryTracks[choice]

	if parryTrack then
		StopAllBlockAnims()
		parryTrack:Play(0.05)

		-- After parry anim ends, either hold block or stop
		local len = parryTrack.Length
		if len <= 0 then len = 0.25 end

		task.delay(len, function()
			-- Only continue if still blocking
			if not Blocking then return end

			SetBool("InBlockAnim", false)
			if FHeld then
				-- Still holding F - transition to block
				parryTrack:Stop(0.1)
				if BlockTrack then
					BlockTrack:Play(0.1)
				end
			else
				-- Released F - stop
				StopBlock()
			end
		end)
	end
end

-- Speed management - slow down while blocking
RunService.Heartbeat:Connect(function()
	if not humanoid then return end

	if Blocking then
		humanoid.WalkSpeed = CombatData.Settings.BLOCK_SPEED
	end
end)

-- Server events
CombatRemote.OnClientEvent:Connect(function(action, data)
	if action == "GOT_PARRIED" then
		-- We got parried
		local track = ParriedTracks[math.random(1, 2)]
		if track then track:Play(0.05) end

	elseif action == "BLOCK_BROKEN" then
		-- Our block was broken
		FullReset()
		if BlockBreakTrack then
			BlockBreakTrack:Play(0.05)
		end

	elseif action == "COUNTER_WINDOW" then
		-- WE SUCCESSFULLY PARRIED! Clear everything!
		print("[BLOCK] PARRY SUCCESS! Clearing all states!")

		Blocking = false
		FHeld = false
		CanBlock = true

		-- Stop all anims
		StopAllBlockAnims()

		-- Clear ALL character values
		SetBool("IsBlocking", false)
		SetBool("InBlockAnim", false)
		SetBool("InParryWindow", false)
		SetBool("IsStunned", false)
		SetBool("InRecovery", false)
		SetBool("IsAttacking", false)

		-- Reset speed NOW
		humanoid.WalkSpeed = CombatData.Settings.WALK_SPEED

	elseif action == "BLOCKED" then
		-- We blocked an attack (not parried)
		print("[BLOCK] Blocked attack!")
	end
end)

-- Input
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.F then
		FHeld = true
		StartBlock()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F then
		FHeld = false
		-- Small delay to allow parry anim to finish
		task.delay(0.05, function()
			if not FHeld and Blocking then
				StopBlock()
			end
		end)
	end
end)

-- Respawn
player.CharacterAdded:Connect(function(char)
	character = char
	humanoid = character:WaitForChild("Humanoid")
	animator = humanoid:WaitForChild("Animator")

	BlockTrack = nil
	ParryTracks = {}
	ParriedTracks = {}
	BlockBreakTrack = nil
	Blocking = false
	CanBlock = true
	FHeld = false

	task.wait(0.3)
	LoadAnimations()
end)

task.wait(0.3)
LoadAnimations()
print("[BLOCK] Client ready!")
