local MODE = MODE

MODE.PrintName = "Infection"
MODE.name = "infection"
MODE.Chance = 0.2
MODE.ROUND_TIME = 480
MODE.start_time = 8
MODE.ForBigMaps = true

MODE.SurvivorModel = "models/player/group01/male_02.mdl"
MODE.InfectedModel = "models/player/zombie_classic.mdl"

function MODE:CanLaunch()
	return #player.GetAll() >= 2
end
