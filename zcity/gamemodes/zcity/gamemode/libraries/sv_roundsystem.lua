local player_GetAll = player.GetAll
zb.modes = zb.modes or {}

util.AddNetworkString("FadeScreen")

function zb.AddFade()
	net.Start("FadeScreen")
	net.Broadcast()
end

local forcemodeconvar = CreateConVar("zb_forcemode", "random", nil, "Set force mode (set to 'random' to disable)")
forcemodeconvar:SetString("random")
function zb:GetMode(round)
	if zb.modes[round] then return round end

	for name, mode in pairs(zb.modes) do
		if mode.Types and mode.Types[round] then
			return name
		end
	end
end

local DEFAULT_MODE = "collect"

local function ResolveModeKey(key)
	if key and zb.modes[key] then return key end
	if zb.modes[DEFAULT_MODE] then return DEFAULT_MODE end
	for name in pairs(zb.modes or {}) do
		return name
	end
	return DEFAULT_MODE
end

function CurrentRound()
	zb.CROUND = ResolveModeKey(zb.CROUND)

	if not zb.CROUND_MAIN or (zb.LASTCROUND != zb.CROUND) then
		zb.CROUND_MAIN = zb:GetMode(zb.CROUND) or zb.CROUND
		zb.LASTCROUND = zb.CROUND
	end

	local round = zb.CROUND_MAIN
	local mode = zb.modes[round]
	if not mode then
		round = ResolveModeKey(nil)
		zb.CROUND = round
		zb.CROUND_MAIN = round
		mode = zb.modes[round]
	end

	return mode, zb.CROUND
end

function NextRound(round)
	zb.nextround = round
end

function zb:PreRound()
	if ((((zb.Roundscount or 0) > 15) and !(GetConVar("zb_dev") and GetConVar("zb_dev"):GetBool())) or ( (player.GetCount() > 1) and zb.ROUND_STATE == 0 and zb.CheckRTVVotes and zb.CheckRTVVotes() )) then
		if zb.StartRTV then zb.StartRTV(20) end
		zb.ROUND_STATE = 0
		return
	end

	if zb.ROUND_STATE == 0 and #player_GetAll() > 1 then
		zb.END_TIME = nil

		local mode = CurrentRound()
		if not mode then return end
		zb.START_TIME = zb.START_TIME or CurTime() + (mode.start_time or 5)
		if zb.START_TIME < CurTime() then zb:RoundStart() end
	end
end

function zb:RoundThink()
	if zb.ROUND_STATE == 1 then
		local mode = CurrentRound()
		if mode and mode.RoundThink then mode:RoundThink(mode) end
	end
end

hook.Add("CanListenOthers","RoundStartChat",function(output, input, isChat, teamonly, text)
	if zb.ROUND_STATE == 0 or zb.ROUND_STATE == 3 then return true, false end
end)

function zb:EndRound()
	zb.ROUND_STATE = 3
	zb.Roundscount = (zb.Roundscount or 0) + 1

	local mode, round = CurrentRound()
	if not mode then
		print("[Tubbycity] EndRound: no mode loaded")
		return
	end

	net.Start("RoundInfo")
		net.WriteString(mode.name or round or DEFAULT_MODE)
		net.WriteInt(zb.ROUND_STATE, 4)
	net.Broadcast()

	if mode.EndRound then mode:EndRound() end
	hook.Run("ZB_EndRound")
	zb.AddFade()

	if hg and hg.achievements and hg.achievements.SavePlayerAchievements then
		hg.achievements.SavePlayerAchievements()
	end
end

function zb:CheckWinner(tbl)
	local playerTable = table.Copy(tbl)
	for i, players in pairs(playerTable) do
		if table.Count(players) == 0 then
			playerTable[i] = nil
			continue
		end
		playerTable[i] = i
	end

	local winner = (table.Count(playerTable) == 1 and table.Random(playerTable)) or (table.Count(playerTable) == 0 and 3) or false
	local shouldendround = winner and true or nil
	return shouldendround, winner
end

zb.ROUND_TIME = zb.ROUND_TIME or 300

function zb:ShouldRoundEnd()
	local mode = CurrentRound()
	if not mode then return false end
	local time = zb.ROUND_TIME
	local shouldroundend = mode.ShouldRoundEnd and mode:ShouldRoundEnd()
	if shouldroundend ~= false then
		local boringround = ((zb.ROUND_START or 0) + time) < CurTime()

		if boringround and mode.BoringRoundFunction then
			PrintMessage(HUD_PRINTTALK, "Stopping round because it was TOO boring.")
			mode:BoringRoundFunction()
		end

		return (shouldroundend and true) or (boringround)
	else
		return false
	end
end

function zb:EndRoundThink()
	if zb.ROUND_STATE == 1 and zb:ShouldRoundEnd() then zb:EndRound() end
	if zb.ROUND_STATE == 3 then
		local mode = CurrentRound()
		if not mode then return end

		if !zb.END_TIME then
			zb.END_TIME = (CurTime() + (mode.end_time or 5))
		end

		zb.SHOULD_FADE = zb.SHOULD_FADE != nil and zb.SHOULD_FADE or true

		if zb.SHOULD_FADE and (zb.END_TIME < CurTime() + 1.5) then
			zb.SHOULD_FADE = false
			for _, ply in player.Iterator() do
				ply:ScreenFade(SCREENFADE.OUT, Color(0, 0, 0), 1, 7)
			end
		end

		if zb.END_TIME < CurTime() then
			zb.ROUND_STATE = 0
			zb.SHOULD_FADE = true

			hook.Run("ZB_PreRoundStart")
			hook.Run("TTTPrepareRound")

			zb.CROUND = ResolveModeKey(zb.nextround)
			mode = CurrentRound()
			if not mode then return end

			if mode.shouldfreeze then zb:Freeze() end

			net.Start("RoundInfo")
				net.WriteString(mode.name or zb.CROUND or DEFAULT_MODE)
				net.WriteInt(zb.ROUND_STATE, 4)
			net.Broadcast()

			if hg and hg.UpdateRoundTime then
				hg.UpdateRoundTime(mode.ROUND_TIME, CurTime(), CurTime() + (mode.start_time or 5))
			end

			self:KillPlayers()
			if self.AutoBalance then self:AutoBalance() end

			mode.saved = {}
			if mode.Intermission then mode:Intermission() end
			if mode.GiveEquipment then mode:GiveEquipment() end
		end
	end
end

hook.Add("PlayerInitialSpawn", "zb_SendRoundInfo", function(ply)
	local mode, round = CurrentRound()
	if mode then
		net.Start("RoundInfo")
			net.WriteString(mode.name or round or DEFAULT_MODE)
			net.WriteInt(zb.ROUND_STATE or 0, 4)
		net.Send(ply)
	end

	if ply.SyncVars then ply:SyncVars() end
end)

util.AddNetworkString("RoundInfo")
function zb:Think(time)
	if (zb.thinkTime or CurTime()) > time then return end
	zb.thinkTime = time + 1
	zb:PreRound()
	zb:RoundThink()
	zb:EndRoundThink()
end

hook.Add("Think", "zb-think", function() zb:Think(CurTime()) end)

function zb:KillPlayers()
	local mode = CurrentRound()
	for i, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end

		if ply.GiveExp then ply:GiveExp(math.random(4,15)) end

		if mode and ply:Alive() and mode.DontKillPlayer and mode:DontKillPlayer(ply) then
			if hg and hg.organism and hg.organism.Clear and ply.organism then hg.organism.Clear(ply.organism) end
			if hg and hg.FakeUp then hg.FakeUp(ply,true,true) end
			continue
		end

		if ply:FlashlightIsOn() then ply:Flashlight(false) end

		ply:KillSilent()
		ply:Spawn()
		if ply.SetPlayerClass then ply:SetPlayerClass() end
	end
end

zb.forcemode = zb.forcemode or "random"
local forcemode = zb.forcemode

function zb.GetModes()
	local newtbl = {}
	for name,tbl in pairs(zb.modes) do
		table.insert(newtbl,name)
	end
	return newtbl
end

ZBATTLE_BIGMAP = 5700

hook.Add("InitPostEntity", "loadbigmap", function()
	local filik = file.Read("zbattle/mapsizes.json", "DATA")
	if filik then
		local tbl = util.JSONToTable(filik)
		if tbl and tbl[game.GetMap()] then
			ZBATTLE_BIGMAP = tbl[game.GetMap()]
		end
	end
end)

COMMANDS = COMMANDS or {}
COMMANDS.bigmap = {
	function(ply, args)
		if not ply:IsAdmin() then ply:ChatPrint("You don't have access") return end
		ZBATTLE_BIGMAP = tonumber(args[1])
		ply:ChatPrint("Distance for big map: " .. ZBATTLE_BIGMAP)
		if zb.RerollChances then zb.RerollChances() end
		file.CreateDir("zbattle")
		local tbl = util.JSONToTable(file.Read("zbattle/mapsizes.json", "DATA") or util.TableToJSON({[game.GetMap()] = ZBATTLE_BIGMAP})) or {}
		tbl[game.GetMap()] = ZBATTLE_BIGMAP
		file.Write("zbattle/mapsizes.json", util.TableToJSON(tbl))
		ply:ChatPrint("Saved into a file")
	end,
	0
}

function zb.GetAvailableModes()
	if zb.tdm_checkpoints then zb.tdm_checkpoints() end

	local newtbl = {}
	for i, name in pairs(zb.GetModes()) do
		local tbl = zb.modes[name]
		if not tbl then continue end
		if (not tbl.CanLaunch or tbl:CanLaunch()) then
			if tbl.SubModes then
				for i, name2 in pairs(tbl:SubModes()) do
					table.insert(newtbl, name2)
				end
			else
				table.insert(newtbl, name)
			end
		end
	end
	return newtbl
end

zb.ModesPlaytime = zb.ModesPlaytime or {}

function zb.GetChance(name, addtbl)
	local mode = zb:GetMode(name)
	local tbl = mode and zb.modes[mode]
	if not tbl then return 0.1 end
	local newtbl = tbl.Types and tbl.Types[name] or tbl
	return (newtbl.ChanceFunction and newtbl:ChanceFunction(addtbl or {})) or (zb.ModesChances and zb.ModesChances[name]) or newtbl.Chance or 0.1
end

function zb.GetModesChances()
	local tbl = zb.GetAvailableModes()
	local newtbl = {}
	for i, name in pairs(tbl) do
		newtbl[name] = zb.GetChance(name)
	end
	return newtbl
end

function zb.WeightedChanceMode(modes_chances)
	local weight = 0
	local newchancestbl = {}
	for name, chance in pairs(modes_chances) do
		local newchance = zb.GetChance(name, {rounds = zb.RoundList}) or chance
		newchancestbl[name] = newchance
		weight = weight + newchance * 100
	end
	if weight <= 0 then return DEFAULT_MODE end
	local random = math.random(weight)
	local count = 0
	for name, chance in RandomPairs(modes_chances) do
		count = count + (newchancestbl[name] or chance) * 100
		if count >= random then
			return name
		end
	end
	return DEFAULT_MODE
end

function zb.GetWorldSize()
	local dist = 0
	local pts = zb.GetMapPoints and zb.GetMapPoints("RandomSpawns") or {}
	for _, pnt in pairs(pts) do
		for _, pnt2 in pairs(pts) do
			if pnt.pos and pnt2.pos then
				dist = math.max(dist, pnt.pos:DistToSqr(pnt2.pos))
			end
		end
	end
	return math.sqrt(dist)
end

function zb.GetRoundName(name)
	local mode = zb:GetMode(name)
	if not mode or not zb.modes[mode] then return tostring(name) end
	return zb.modes[mode].PrintName or zb.modes[mode].name or name
end

zb.RoundList = zb.RoundList or {}
zb.QueuedModes = zb.QueuedModes or {}

function zb.RerollChances()
	zb.RoundList = {}
	local chances = zb.GetModesChances()
	if not next(chances) then
		zb.nextround = DEFAULT_MODE
		return
	end
	for i = 1, 20 do
		zb.RoundList[i] = zb.WeightedChanceMode(chances)
	end
	zb.nextround = table.remove(zb.RoundList, 1)
end

function zb.GetModesInfo()
	local modesInfo = {}
	for name, mode in pairs(zb.modes) do
		table.insert(modesInfo, {
			key = name,
			name = mode.PrintName or mode.name or name,
			description = mode.Description or "",
			forBigMaps = mode.ForBigMaps or false,
			canlaunch = ((not mode.CanLaunch or mode:CanLaunch()) and 1 or 0)
		})
	end
	return modesInfo
end

function zb.SetRoundList(newList)
	local newLista = table.Copy(newList)
	if #newLista > 0 then
		zb.nextround = table.remove(newLista, 1)
		zb.RoundList = newLista
	else
		zb.RerollChances()
	end
end

util.AddNetworkString("ZB_SendModesInfo")
util.AddNetworkString("ZB_SendRoundList")
util.AddNetworkString("ZB_RequestRoundList")
util.AddNetworkString("ZB_UpdateRoundList")
util.AddNetworkString("ZB_NotifyRoundListChange")
util.AddNetworkString("SendAvailableModes")
util.AddNetworkString("AdminSetGameMode")
util.AddNetworkString("AdminEndRound")
util.AddNetworkString("AdminSetGameQueue")
util.AddNetworkString("RequestGameQueue")
util.AddNetworkString("SendGameQueue")
util.AddNetworkString("QueueEmptiedNotification")
util.AddNetworkString("QueueModifiedNotification")

function zb.SendModesInfoToClient(ply)
	net.Start("ZB_SendModesInfo")
		net.WriteTable(zb.GetModesInfo())
	net.Send(ply)
end

function zb.SendRoundListToClient(ply)
	net.Start("ZB_SendRoundList")
		net.WriteTable(zb.RoundList)
		net.WriteString(zb.nextround or "")
		net.WriteString(forcemodeconvar:GetString() or "random")
	net.Send(ply)
end

function zb.GetAllAdmins()
	local admins = {}
	for _, ply in player.Iterator() do
		if ply:IsAdmin() then table.insert(admins, ply) end
	end
	return admins
end

function zb.SyncForceModeToAdmins()
	for _, admin in ipairs(zb.GetAllAdmins()) do
		zb.SendRoundListToClient(admin)
	end
end

hook.Add("PlayerInitialSpawn", "ZB_SendModesOnSpawn", function(ply)
	if ply:IsAdmin() then
		timer.Simple(1, function()
			if IsValid(ply) then
				zb.SendModesInfoToClient(ply)
				zb.SendRoundListToClient(ply)
			end
		end)
	end
end)

net.Receive("ZB_RequestRoundList", function(len, ply)
	if IsValid(ply) and ply:IsAdmin() then
		zb.SendModesInfoToClient(ply)
		zb.SendRoundListToClient(ply)
	end
end)

net.Receive("ZB_UpdateRoundList", function(len, ply)
	if not IsValid(ply) or not ply:IsAdmin() then return end
	local newList = net.ReadTable()
	zb.SetRoundList(newList)
	net.Start("ZB_NotifyRoundListChange")
		net.WriteString(ply:Nick())
	net.Send(zb.GetAllAdmins())
	for _, admin in ipairs(zb.GetAllAdmins()) do
		zb.SendRoundListToClient(admin)
	end
end)

function zb:RoundStart()
	local mode, round = CurrentRound()
	if not mode then
		print("[Tubbycity] RoundStart: no mode loaded")
		return
	end

	if mode.shouldfreeze then zb:Unfreeze() end

	zb.ROUND_STATE = 1
	zb.START_TIME = nil
	zb.ROUND_BEGIN = CurTime()
	if hg and hg.UpdateRoundTime then hg.UpdateRoundTime() end

	net.Start("RoundInfo")
		net.WriteString(mode.name or round or DEFAULT_MODE)
		net.WriteInt(zb.ROUND_STATE, 4)
	net.Broadcast()

	if forcemodeconvar:GetString() != "" then
		forcemode = forcemodeconvar:GetString()
	end

	if mode.RoundStart then mode:RoundStart() end

	if #zb.RoundList == 0 then zb.RerollChances() end
	local nextMode = table.remove(zb.RoundList, 1)
	print("Next game mode is " .. tostring(nextMode))
	NextRound(forcemode ~= "random" and forcemode or (nextMode or DEFAULT_MODE))

	if mode.RoundStartPost then mode:RoundStartPost() end
	hook.Run("ZB_StartRound")

	for _, admin in ipairs(zb.GetAllAdmins()) do
		zb.SendRoundListToClient(admin)
	end
end

concommand.Add("zb_checkchances",function(ply) if IsValid(ply) and ply:IsAdmin() and zb.RerollChances then zb.RerollChances() end end)
concommand.Add("zb_rerollchances",function(ply) if IsValid(ply) and ply:IsAdmin() then zb.RerollChances() end end)

function zb.SyncQueueToAdmins()
	timer.Simple(0.1, function()
		net.Start("SendGameQueue")
		net.WriteTable(zb.QueuedModes)
		net.Send(zb.GetAllAdmins())
	end)
end

net.Receive("AdminSetGameMode", function(len, ply)
	if not ply:IsAdmin() then return end
	local command = net.ReadString()
	local modeKey = net.ReadString()
	local addToQueue = net.ReadBool() or false

	if command == "setmode" then
		NextRound(modeKey)
		ply:ChatPrint("Game mode set to: " .. modeKey)
		if addToQueue then
			table.insert(zb.QueuedModes, modeKey)
			zb.SyncQueueToAdmins()
		end
	elseif command == "setforcemode" then
		forcemodeconvar:SetString(modeKey)
		forcemode = modeKey
		if modeKey == "random" then
			ply:ChatPrint("Force mode disabled")
		else
			NextRound(forcemode)
			ply:ChatPrint("Force mode set to: " .. modeKey)
		end
		zb.SyncForceModeToAdmins()
	end
end)

net.Receive("AdminEndRound", function(len, ply)
	if not ply:IsAdmin() then return end
	ply:ChatPrint("Round ended!")
	zb:EndRound()
end)

net.Receive("AdminSetGameQueue", function(len, ply)
	if not ply:IsAdmin() then return end
	local modeQueue = net.ReadTable()
	zb.QueuedModes = modeQueue
	zb.SyncQueueToAdmins()
end)

function zb:Unfreeze()
	for i, ply in player.Iterator() do
		if ply:Alive() then ply:Freeze(false) end
	end
end

function zb:Freeze()
	for i, ply in player.Iterator() do
		if ply:Alive() then ply:Freeze(true) end
	end
end

COMMANDS.setmode = {
	function(ply, args)
		if not ply:IsAdmin() then ply:ChatPrint("You don't have access") return end
		if not args[1] then return end
		ply:ChatPrint(args[1])
		NextRound(args[1])
	end,
	0
}

COMMANDS.setforcemode = {
	function(ply, args)
		if not ply:IsAdmin() then ply:ChatPrint("You don't have access") return end
		if not args[1] then return end
		ply:ChatPrint(args[1])
		forcemode = args[1]
		if args[1] ~= "random" then NextRound(args[1]) end
	end, 0
}

COMMANDS.endround = {
	function(ply, args)
		if not ply:IsAdmin() then ply:ChatPrint("You don't have access") return end
		zb:EndRound()
	end, 0
}
