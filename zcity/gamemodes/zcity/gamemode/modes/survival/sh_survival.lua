local MODE = MODE

MODE.PrintName = "Survival"
MODE.name = "survival"
MODE.Chance = 0.25
MODE.ROUND_TIME = 900
MODE.start_time = 10
MODE.MaxWaves = 10
MODE.ForBigMaps = true

MODE.SurvivorModel = "models/player/group01/male_02.mdl"
MODE.WaveNPCClass = "npc_zombie"

function MODE:CanLaunch()
	return true
end
