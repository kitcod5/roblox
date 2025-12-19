-- ServerScriptService/DashServer
-- DEEPWOKEN DASH SERVER

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DashRemote = Remotes:FindFirstChild("DashRemote") or Instance.new("RemoteEvent")
DashRemote.Name = "DashRemote"
DashRemote.Parent = Remotes

local Combat = ReplicatedStorage:WaitForChild("Combat")
local CombatData = require(Combat:WaitForChild("CombatData"))

local Cooldowns = {}

DashRemote.OnServerEvent:Connect(function(player, dashType)
	local char = player.Character
	if not char then return end

	local hum = char:FindFirstChild("Humanoid")
	if not hum or hum.Health <= 0 then return end

	-- Check stunned
	local stunned = char:FindFirstChild("IsStunned")
	if stunned and stunned.Value then return end

	-- Check cooldown
	local now = tick()
	if Cooldowns[player] and now - Cooldowns[player] < CombatData.Settings.DASH_COOLDOWN then
		return
	end

	Cooldowns[player] = now

	-- Server validates the dash happened
	print("[DASH] " .. player.Name .. " dashed: " .. tostring(dashType))
end)

Players.PlayerRemoving:Connect(function(player)
	Cooldowns[player] = nil
end)

print("[DASH] Server ready!")
