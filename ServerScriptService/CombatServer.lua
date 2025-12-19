-- ServerScriptService/CombatServer
-- DEEPWOKEN COMBAT SERVER (FIXED PARRY)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = ReplicatedStorage

local CombatRemote = Remotes:FindFirstChild("CombatRemote") or Instance.new("RemoteEvent")
CombatRemote.Name = "CombatRemote"
CombatRemote.Parent = Remotes

local Combat = ReplicatedStorage:WaitForChild("Combat")
local CombatData = require(Combat:WaitForChild("CombatData"))

local States = {}

local function GetState(plr)
	if not States[plr] then
		States[plr] = { Combo = 0, LastM1 = 0, LastCrit = 0, LastComboTime = 0 }
	end
	return States[plr]
end

-- Helper to set BoolValue
local function SetBool(char, name, val)
	if not char then return end
	local v = char:FindFirstChild(name)
	if not v then
		v = Instance.new("BoolValue")
		v.Name = name
		v.Parent = char
	end
	v.Value = val
end

-- Helper to get BoolValue
local function GetBool(char, name)
	if not char then return false end
	local v = char:FindFirstChild(name)
	return v and v.Value == true
end

-- Apply knockback
local function Knockback(attackerChar, targetChar, force, duration)
	local tRoot = targetChar:FindFirstChild("HumanoidRootPart")
	local aRoot = attackerChar:FindFirstChild("HumanoidRootPart")
	if not tRoot or not aRoot then return end

	local dir = (tRoot.Position - aRoot.Position)
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude > 0 then dir = dir.Unit else dir = aRoot.CFrame.LookVector end

	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(50000, 0, 50000)
	bv.Velocity = dir * force
	bv.Parent = tRoot

	game.Debris:AddItem(bv, duration)
end

-- Stun a player
local function Stun(plr, duration, stunType)
	local char = plr.Character
	if not char then return end

	SetBool(char, "IsStunned", true)

	-- Clear blocking when stunned
	SetBool(char, "IsBlocking", false)
	SetBool(char, "InParryWindow", false)

	task.delay(duration, function()
		if char then
			SetBool(char, "IsStunned", false)
		end
	end)
end

-- Grant counter window (CAN ATTACK IMMEDIATELY)
local function GrantCounterWindow(plr, duration)
	local char = plr.Character
	if not char then return end

	-- IMPORTANT: Clear ALL blocking states so player can attack
	SetBool(char, "IsStunned", false)
	SetBool(char, "IsBlocking", false)
	SetBool(char, "InParryWindow", false)
	SetBool(char, "InBlockAnim", false)
	SetBool(char, "InCounter", true)

	print("[COMBAT] " .. plr.Name .. " CAN NOW COUNTER ATTACK!")

	-- Tell client to clear states and allow attacking
	CombatRemote:FireClient(plr, "COUNTER_WINDOW")

	task.delay(duration, function()
		if char then
			SetBool(char, "InCounter", false)
		end
	end)
end

-- Hit detection
local function GetHits(char)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return {} end

	local pos = root.Position + root.CFrame.LookVector * CombatData.Hitbox.OFFSET
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char}

	local parts = workspace:GetPartBoundsInBox(CFrame.new(pos), CombatData.Hitbox.SIZE, params)
	local hits = {}
	local seen = {}

	for _, p in ipairs(parts) do
		local c = p.Parent
		local h = c and c:FindFirstChild("Humanoid")
		if h and c ~= char and not seen[c] then
			seen[c] = true
			table.insert(hits, {char = c, hum = h})
		end
	end
	return hits
end

-- Process damage
local function DoDamage(attackerChar, targets, dmg, isCrit, isFlourish)
	local attackerPlr = Players:GetPlayerFromCharacter(attackerChar)

	for _, t in ipairs(targets) do
		local targetPlr = Players:GetPlayerFromCharacter(t.char)

		-- Skip if target in counter window (immune)
		if GetBool(t.char, "InCounter") then
			continue
		end

		-- Check if target is blocking
		local isBlocking = GetBool(t.char, "IsBlocking")
		local inParry = GetBool(t.char, "InParryWindow")

		if isBlocking or inParry then
			if inParry then
				-- PARRIED!
				print("[COMBAT] PARRIED!")
				-- Stun attacker
				if attackerPlr then
					Stun(attackerPlr, CombatData.Settings.PARRY_PUNISH, "parried")
					CombatRemote:FireClient(attackerPlr, "GOT_PARRIED")
				end

				-- Give defender counter window
				if targetPlr then
					GrantCounterWindow(targetPlr, CombatData.Settings.COUNTER_WINDOW)
				end
				continue
			end

			-- Regular block
			if isCrit then
				-- BLOCK BROKEN
				if targetPlr then
					Stun(targetPlr, CombatData.Settings.BLOCK_BREAK_STUN, "blockbreak")
					CombatRemote:FireClient(targetPlr, "BLOCK_BROKEN")
				end
				Knockback(attackerChar, t.char, 18, 0.1)
				t.hum:TakeDamage(dmg)
			else
				-- Blocked - no damage
				if targetPlr then
					CombatRemote:FireClient(targetPlr, "BLOCKED")
				end
				if attackerPlr then
					CombatRemote:FireClient(attackerPlr, "HIT_BLOCKED")
				end
			end
		else
			-- NOT BLOCKING - Full damage
			t.hum:TakeDamage(dmg)

			-- Hitstun
			if targetPlr then
				Stun(targetPlr, CombatData.Settings.HITSTUN, "hitstun")
			end

			-- Knockback
			local kb = CombatData.Settings.M1_PUSHBACK
			if isFlourish then kb = CombatData.Settings.FLOURISH_KNOCKBACK end
			if isCrit then kb = CombatData.Settings.CRIT_KNOCKBACK end

			Knockback(attackerChar, t.char, kb, CombatData.Settings.KNOCKBACK_DURATION)

			-- Tell target to play hit anim
			if targetPlr then
				local hitNum = math.random(1, 4)
				CombatRemote:FireClient(targetPlr, "PLAY_HIT", hitNum)
			else
				-- NPC/Dummy - damage handled by their own script
			end

			-- Flourish or crit = knockback anim
			if isFlourish or isCrit then
				if targetPlr then
					CombatRemote:FireClient(targetPlr, "PLAY_KNOCKBACK")
				end
			end

			if attackerPlr then
				CombatRemote:FireClient(attackerPlr, "HIT_LANDED")
			end
		end
	end
end

-- Handle M1
local function HandleM1(plr)
	local char = plr.Character
	if not char then return end
	local hum = char:FindFirstChild("Humanoid")
	if not hum or hum.Health <= 0 then return end

	-- Can't attack while stunned, dashing, or blocking
	if GetBool(char, "IsStunned") then return end
	if GetBool(char, "IsDashing") then return end
	if GetBool(char, "IsBlocking") then return end
	if GetBool(char, "InBlockAnim") then return end

	local state = GetState(plr)
	local now = tick()

	-- Cooldown check
	if now - state.LastM1 < CombatData.Settings.M1_COOLDOWN then return end

	-- Combo logic
	if now - state.LastComboTime > CombatData.Settings.COMBO_RESET then
		state.Combo = 0
	end

	state.Combo = (state.Combo % CombatData.Settings.MAX_COMBO) + 1
	state.LastM1 = now
	state.LastComboTime = now

	local isFlourish = (state.Combo == 5)

	-- Play animation on client
	CombatRemote:FireClient(plr, "PLAY_M1", state.Combo)

	-- Wait for hit point in animation
	task.wait(CombatData.Settings.M1_HIT_POINT)

	-- Check still valid
	if not char or not hum or hum.Health <= 0 then return end
	if GetBool(char, "IsStunned") then return end

	-- Do damage
	local hits = GetHits(char)
	DoDamage(char, hits, CombatData.Settings.M1_DAMAGE, false, isFlourish)
end

-- Handle Crit
local function HandleCrit(plr)
	local char = plr.Character
	if not char then return end
	local hum = char:FindFirstChild("Humanoid")
	if not hum or hum.Health <= 0 then return end

	if GetBool(char, "IsStunned") then return end
	if GetBool(char, "IsDashing") then return end
	if GetBool(char, "IsBlocking") then return end
	if GetBool(char, "InBlockAnim") then return end

	local state = GetState(plr)
	local now = tick()

	if now - state.LastCrit < CombatData.Settings.CRIT_COOLDOWN then return end
	state.LastCrit = now

	CombatRemote:FireClient(plr, "PLAY_CRIT")

	task.wait(CombatData.Settings.CRIT_HIT_POINT)

	if not char or not hum or hum.Health <= 0 then return end
	if GetBool(char, "IsStunned") then return end

	local hits = GetHits(char)
	DoDamage(char, hits, CombatData.Settings.CRIT_DAMAGE, true, false)
end

-- Handle block start
local function HandleBlockStart(plr)
	local char = plr.Character
	if not char then return end

	if GetBool(char, "IsStunned") then return end
	if GetBool(char, "IsDashing") then return end

	SetBool(char, "IsBlocking", true)
	SetBool(char, "InParryWindow", true)

	-- Parry window closes after set time
	task.delay(CombatData.Settings.PARRY_WINDOW, function()
		if char then
			SetBool(char, "InParryWindow", false)
		end
	end)
end

-- Handle block stop
local function HandleBlockStop(plr)
	local char = plr.Character
	if not char then return end

	SetBool(char, "IsBlocking", false)
	SetBool(char, "InParryWindow", false)
end

CombatRemote.OnServerEvent:Connect(function(plr, action, data)
	if action == "M1" then
		HandleM1(plr)
	elseif action == "CRIT" then
		HandleCrit(plr)
	elseif action == "BLOCK_START" then
		HandleBlockStart(plr)
	elseif action == "BLOCK_STOP" then
		HandleBlockStop(plr)
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	States[plr] = nil
end)

print("[COMBAT] Server ready!")
