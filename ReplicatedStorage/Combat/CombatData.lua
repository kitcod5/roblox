-- ReplicatedStorage/Combat/CombatData
-- DEEPWOKEN COMBAT SYSTEM (PROPER TIMING)

local CombatData = {}

CombatData.Animations = {
	M1_1 = "rbxassetid://80703820989833",
	M1_2 = "rbxassetid://99500623255862",
	M1_3 = "rbxassetid://79196933628226",
	M1_4 = "rbxassetid://107015278536598",
	M1_5 = "rbxassetid://99993110544244",
	CRIT = "rbxassetid://118141835488799",
	KNOCKBACK = "rbxassetid://108512375962910",

	DASH_FRONT = "rbxassetid://79241523165669",
	DASH_LEFT = "rbxassetid://100647029124224",
	DASH_RIGHT = "rbxassetid://118520799563131",
	DASH_BACK = "rbxassetid://72998974255918",

	BLOCK = "rbxassetid://112061974623225",
	PARRY_LEFT = "rbxassetid://138880173548582",
	PARRY_RIGHT = "rbxassetid://75828326431698",
	BEING_PARRIED_1 = "rbxassetid://87916664643279",
	BEING_PARRIED_2 = "rbxassetid://135483064076831",
	BLOCK_BREAKED = "rbxassetid://71477739324878",

	HIT_1 = "rbxassetid://92861080426324",
	HIT_2 = "rbxassetid://123781164687474",
	HIT_3 = "rbxassetid://77943716617257",
	HIT_4 = "rbxassetid://105729820225182",

	RUN = "rbxassetid://96843159646986"
}

CombatData.Settings = {
	-- ===== M1 COMBAT (SLOWER LIKE DEEPWOKEN) =====
	M1_DAMAGE = 10,
	M1_COOLDOWN = 0.5,        -- Time between M1 inputs (slower)
	M1_SWING_TIME = 0.35,     -- How long the swing animation takes
	M1_HIT_POINT = 0.15,      -- When in the swing the hit registers
	M1_RECOVERY = 0.2,        -- Recovery after swing before next action

	COMBO_RESET = 1.0,        -- Combo resets after this time
	MAX_COMBO = 5,            -- 5th hit is flourish

	-- ===== CRIT =====
	CRIT_DAMAGE = 25,
	CRIT_COOLDOWN = 2.5,
	CRIT_SWING_TIME = 0.5,
	CRIT_HIT_POINT = 0.2,
	CRIT_RECOVERY = 0.35,

	-- ===== KNOCKBACK =====
	M1_PUSHBACK = 10,
	FLOURISH_KNOCKBACK = 28,
	CRIT_KNOCKBACK = 32,
	KNOCKBACK_DURATION = 0.12,

	-- ===== STUN DURATIONS =====
	HITSTUN = 0.25,           -- When you get hit
	PARRY_PUNISH = 1.2,       -- Attacker stunned when parried
	BLOCK_BREAK_STUN = 0.9,   -- When your block is broken

	-- ===== PARRY SYSTEM =====
	PARRY_WINDOW = 0.25,      -- How long parry is active (tap F)
	PARRY_COOLDOWN = 0.4,     -- Cooldown before next parry
	COUNTER_WINDOW = 1.5,     -- Time to punish after successful parry

	-- ===== BLOCKING =====
	-- Hold F to block, reduces speed

	-- ===== MOVEMENT SPEEDS =====
	WALK_SPEED = 16,
	COMBAT_SPEED = 10,        -- While swinging
	BLOCK_SPEED = 6,          -- While blocking
	SPRINT_SPEED = 22,

	-- ===== DASH =====
	DASH_FORCE = 55,
	DASH_DURATION = 0.18,
	DASH_COOLDOWN = 0.7,

	-- ===== SPRINT =====
	DOUBLE_TAP_TIME = 0.3,
}

CombatData.Hitbox = {
	SIZE = Vector3.new(5, 5, 6),
	OFFSET = 3.5
}

return CombatData
