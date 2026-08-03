local MODE = MODE

MODE.PrintName = "Sandbox"
MODE.name = "sandbox_st"
MODE.Chance = 0.05
MODE.ROUND_TIME = 3600
MODE.start_time = 0
MODE.ForBigMaps = true
MODE.OverrideSpawn = true -- free spawn

function MODE:CanLaunch()
	return true
end
