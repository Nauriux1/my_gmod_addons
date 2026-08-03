local MODE = MODE

MODE.PrintName = "Collect"
MODE.name = "collect"
MODE.Chance = 0.35
MODE.ROUND_TIME = 600
MODE.start_time = 5
MODE.CustardCount = 10 -- default; can be overridden per map / cvar later
MODE.ForBigMaps = true

-- Placeholder until custom Slendytubbies models are added
MODE.SurvivorModel = "models/player/group01/male_02.mdl"
MODE.EnemyNPCClass = "npc_fastzombie" -- temporary NPC stand-in for the enemy

function MODE:CanLaunch()
	local custards = zb.GetMapPoints("Tubby_Custard") or {}
	return #custards >= 1 or true -- allow launch even without points (uses random fallbacks)
end
