local MODE = MODE

MODE.name = "collect"
MODE.PrintName = "Collect"
MODE.Chance = 0.35
MODE.ROUND_TIME = 600
MODE.start_time = 5
MODE.CustardCount = 10
MODE.randomSpawns = true -- spawn anywhere until Tubby_SurvivorSpawn points exist

function MODE:CanLaunch()
	return true
end

local function SafePoints(group)
	if not zb.GetMapPoints then return {} end
	local pts = zb.GetMapPoints(group)
	if not pts or pts == false then return {} end
	return pts
end

local function PointsToPositions(group)
	local pts = SafePoints(group)
	if #pts == 0 then return {} end
	if zb.TranslatePointsToVectors then
		return zb.TranslatePointsToVectors(pts) or {}
	end
	local out = {}
	for _, p in ipairs(pts) do
		if isvector(p) then out[#out + 1] = p
		elseif istable(p) and p.pos then out[#out + 1] = p.pos end
	end
	return out
end

function MODE:Intermission()
	game.CleanUpMap()

	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end
		ply:SetupTeam(0)
	end
end

function MODE:RoundStart()
	for _, ply in player.Iterator() do
		if not ply:Alive() then continue end
		ply:Freeze(false)
	end

	self:SpawnCustards()
	self:SpawnEnemyNPC()
	PrintMessage(HUD_PRINTTALK, "Collect mode: Find all Tubby Custards. Avoid the enemy.")
end

function MODE:GetTeamSpawn()
	local survivors = PointsToPositions("Tubby_SurvivorSpawn")
	if not survivors or not next(survivors) then
		survivors = PointsToPositions("Spawnpoint")
	end
	if not survivors or not next(survivors) then
		local pos = zb.GetRandomSpawn and zb:GetRandomSpawn() or nil
		survivors = pos and { pos } or {}
	end
	return survivors, survivors
end

function MODE:GiveEquipment()
	timer.Simple(0.1, function()
		for _, ply in player.Iterator() do
			if not ply:Alive() then continue end
			if ply:Team() == TEAM_SPECTATOR then continue end

			ply:SetSuppressPickupNotices(true)
			ply.noSound = true

			-- Teletubby model + bodygroups from appearance menu
			if zb.Tubby and zb.Tubby.Apply then
				zb.Tubby.Apply(ply)
			elseif ApplyAppearance then
				ApplyAppearance(ply)
			end

			ply:Give("weapon_hands_sh")
			ply:SelectWeapon("weapon_hands_sh")
			pcall(function() ply:AllowFlashlight(true) end)

			if zb.GiveRole then zb.GiveRole(ply, "Survivor", Color(100, 200, 255)) end

			timer.Simple(0.1, function()
				if IsValid(ply) then ply.noSound = false end
			end)
			ply:SetSuppressPickupNotices(false)
		end
	end)
end

function MODE:SpawnCustards()
	local points = SafePoints("Tubby_Custard")
	local count = self.CustardCount or 10

	self.CustardsLeft = 0
	self.ActiveCustards = {}

	if #points == 0 then
		for i = 1, count do
			local pos = zb.GetRandomSpawn and zb:GetRandomSpawn()
			if pos then
				local ent = ents.Create("ent_tubby_custard")
				if IsValid(ent) then
					ent:SetPos(pos + Vector(0, 0, 8))
					ent:Spawn()
					self.CustardsLeft = self.CustardsLeft + 1
					table.insert(self.ActiveCustards, ent)
				end
			end
		end
		return
	end

	local shuffled = table.Copy(points)
	table.Shuffle(shuffled)

	for i = 1, math.min(count, #shuffled) do
		local p = shuffled[i]
		local ent = ents.Create("ent_tubby_custard")
		if IsValid(ent) then
			ent:SetPos((p.pos or p) + Vector(0, 0, 8))
			if p.ang then ent:SetAngles(p.ang) end
			ent:Spawn()
			self.CustardsLeft = self.CustardsLeft + 1
			table.insert(self.ActiveCustards, ent)
		end
	end
end

function MODE:SpawnEnemyNPC()
	local points = SafePoints("Tubby_EnemySpawn")
	local pos

	if #points > 0 then
		local p = points[math.random(#points)]
		pos = p.pos or p
	else
		pos = zb.GetRandomSpawn and zb:GetRandomSpawn()
	end

	if not pos then return end

	local npc = ents.Create("npc_zombie")
	if not IsValid(npc) then return end
	npc:SetPos(pos + Vector(0, 0, 8))
	npc:Spawn()
	npc:Activate()
	npc:SetHealth(500)
	npc:SetMaxHealth(500)
	self.EnemyNPC = npc
end

function MODE:ShouldRoundEnd()
	if (self.CustardsLeft or 0) <= 0 and self.ActiveCustards then
		return true
	end
	local alive = zb.CheckAlive and zb:CheckAlive(true) or {}
	return #alive == 0
end

function MODE:CheckAlivePlayers()
	return zb.CheckAliveTeams and zb:CheckAliveTeams(true) or {}
end

function MODE:RoundThink()
end

function MODE:EndRound()
	if IsValid(self.EnemyNPC) then self.EnemyNPC:Remove() end
end

function MODE:CanSpawn()
	return zb.ROUND_STATE == 0
end

function MODE:PlayerDeath(ply)
end
