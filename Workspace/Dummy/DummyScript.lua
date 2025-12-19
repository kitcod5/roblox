-- Put this Script inside your Dummy model
-- MAKE SURE HumanoidRootPart is NOT Anchored!

local dummy = script.Parent
local humanoid = dummy:WaitForChild("Humanoid")
local rootPart = dummy:WaitForChild("HumanoidRootPart")

-- Unanchor everything
rootPart.Anchored = false
for _, part in pairs(dummy:GetDescendants()) do
	if part:IsA("BasePart") then
		part.Anchored = false
	end
end

-- Setup
humanoid.MaxHealth = 10000
humanoid.Health = 10000
humanoid.WalkSpeed = 0
humanoid.JumpPower = 0
humanoid.BreakJointsOnDeath = false

-- Remove Animate script
local animate = dummy:FindFirstChild("Animate")
if animate then animate:Destroy() end

-- Create Animator
local animator = humanoid:FindFirstChild("Animator")
if not animator then
	animator = Instance.new("Animator")
	animator.Parent = humanoid
end

-- Animation IDs
local HIT_ANIMS = {
	"rbxassetid://92861080426324",
	"rbxassetid://123781164687474",
	"rbxassetid://77943716617257",
	"rbxassetid://105729820225182"
}
local KNOCKBACK_ANIM = "rbxassetid://108512375962910"

-- Load animations
local HitTracks = {}
local KnockbackTrack = nil

local function LoadAnims()
	for i, id in ipairs(HIT_ANIMS) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
		if ok then
			track.Priority = Enum.AnimationPriority.Action4
			track.Looped = false
			HitTracks[i] = track
		end
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = KNOCKBACK_ANIM
	local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
	if ok then
		track.Priority = Enum.AnimationPriority.Action4
		track.Looped = false
		KnockbackTrack = track
	end

	print("[DUMMY] Animations loaded!")
end

local function StopAll()
	for _, t in pairs(HitTracks) do
		if t and t.IsPlaying then t:Stop(0.05) end
	end
	if KnockbackTrack and KnockbackTrack.IsPlaying then
		KnockbackTrack:Stop(0.05)
	end
end

local function PlayHit()
	StopAll()
	local t = HitTracks[math.random(1, #HitTracks)]
	if t then t:Play(0.05) end
end

local function PlayKnockback()
	StopAll()
	if KnockbackTrack then
		KnockbackTrack:Play(0.05)
		task.delay(0.5, function()
			if KnockbackTrack.IsPlaying then
				KnockbackTrack:Stop(0.15)
			end
		end)
	end
end

-- Track damage
local lastHealth = humanoid.Health

humanoid.HealthChanged:Connect(function(health)
	local dmg = lastHealth - health
	if dmg > 0 then
		if dmg >= 20 then
			PlayKnockback()
		else
			PlayHit()
		end
	end
	lastHealth = health
end)

-- Regen
task.spawn(function()
	while task.wait(0.5) do
		if humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
			humanoid.Health = math.min(humanoid.Health + 200, humanoid.MaxHealth)
			lastHealth = humanoid.Health
		end
	end
end)

-- Respawn on death
humanoid.Died:Connect(function()
	task.wait(2)
	humanoid.Health = humanoid.MaxHealth
	lastHealth = humanoid.MaxHealth
end)

task.wait(1)
LoadAnims()
print("[DUMMY] Ready! Anchored:", rootPart.Anchored)
