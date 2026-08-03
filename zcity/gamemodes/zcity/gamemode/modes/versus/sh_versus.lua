local MODE = MODE

MODE.PrintName = "Versus"
MODE.name = "versus"
MODE.Chance = 0.25
MODE.ROUND_TIME = 600
MODE.start_time = 5
MODE.CustardCount = 10
MODE.ForBigMaps = true

MODE.SurvivorModel = "models/player/group01/male_02.mdl"
MODE.EnemyModel = "models/player/zombie_fast.mdl" -- placeholder until ST models

function MODE:CanLaunch()
	return #player.GetAll() >= 2
end
