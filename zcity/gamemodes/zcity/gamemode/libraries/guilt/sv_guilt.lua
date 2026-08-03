-- Guilt system — works offline without mysql; SQL optional
zb = zb or {}

zb.GuiltTable = zb.GuiltTable or {}
zb.HarmDone = zb.HarmDone or {}
zb.HarmDoneKarma = zb.HarmDoneKarma or {}
zb.HarmDoneDetailed = zb.HarmDoneDetailed or {}
zb.HarmAttacked = zb.HarmAttacked or {}
zb.GuiltSQL = zb.GuiltSQL or {}
zb.GuiltSQL.PlayerInstances = zb.GuiltSQL.PlayerInstances or {}

local hg_developer = ConVarExists("hg_developer") and GetConVar("hg_developer") or CreateConVar("hg_developer",0,FCVAR_SERVER_CAN_EXECUTE,"Toggle developer mode (enables damage traces)",0,1)

local function HasMySQL()
	return mysql ~= nil
end

local function SafeSetNetVar(ply, key, val)
	if not IsValid(ply) then return end
	if ply.SetNetVar then
		ply:SetNetVar(key, val)
	else
		-- Homigrad netvars not loaded yet; use NW fallback
		ply:SetNWFloat(key, isnumber(val) and val or 0)
	end
end

hook.Add("DatabaseConnected", "GuiltCreateData", function()
	if not HasMySQL() then return end
	local query

	query = mysql:Create("zb_guilt")
		query:Create("steamid", "VARCHAR(20) NOT NULL")
		query:Create("steam_name", "VARCHAR(32) NOT NULL")
		query:Create("value", "FLOAT NOT NULL")
		query:PrimaryKey("steamid")
	query:Execute()

    zb.GuiltSQL.Active = true
end)

hook.Add( "PlayerInitialSpawn","ZB_GuiltSQL", function( ply )
    local name = ply:Name()
	local steamID64 = ply:SteamID64()

	if not HasMySQL() then
		zb.GuiltSQL.PlayerInstances[steamID64] = zb.GuiltSQL.PlayerInstances[steamID64] or { value = 100 }
		ply.Karma = ply:guilt_GetValue()
		SafeSetNetVar(ply, "Karma", ply.Karma)
		return
	end

	local query = mysql:Select("zb_guilt")
		query:Select("value")
		query:Where("steamid", steamID64)
		query:Callback(function(result)
			if (IsValid(ply) and istable(result) and #result > 0 and result[1].value) then
				local updateQuery = mysql:Update("zb_guilt")
					updateQuery:Update("steam_name", name)
					updateQuery:Where("steamid", steamID64)
				updateQuery:Execute()

				zb.GuiltSQL.PlayerInstances[steamID64] = {}
                zb.GuiltSQL.PlayerInstances[steamID64].value = tonumber(result[1].value)

                ply.Karma = ply:guilt_GetValue()
                SafeSetNetVar(ply, "Karma", ply.Karma)

                if zb.GuiltSQL.PlayerInstances[steamID64].value < 0 then
                    ply:guilt_SetValue( 10 )
                    local karma = ply.Karma

                    ply.Karma = 10
                    SafeSetNetVar(ply, "Karma", ply.Karma)

                    timer.Simple(0, function()
                        if not IsValid(ply) then return end
                        ply:Ban(5, false)
                        ply:Kick("Your karma is too low: " .. math.Round( karma, 0 ) .. ". Try again in 5 minutes." )
                    end)
                end
			else
				local insertQuery = mysql:Insert("zb_guilt")
					insertQuery:Insert("steamid", steamID64)
					insertQuery:Insert("steam_name", name)
					insertQuery:Insert("value", 100)
				insertQuery:Execute()

				zb.GuiltSQL.PlayerInstances[steamID64] = {}
				zb.GuiltSQL.PlayerInstances[steamID64].value = 100

                ply.Karma = ply:guilt_GetValue()
                SafeSetNetVar(ply, "Karma", ply.Karma)
			end
		end)
	query:Execute()

end)

local plyMeta = FindMetaTable("Player")

function plyMeta:guilt_GetValue()
    return zb.GuiltSQL.PlayerInstances[self:SteamID64()] and zb.GuiltSQL.PlayerInstances[self:SteamID64()].value or 100
end

function plyMeta:guilt_SetValue( zb_guilt )
    local steamID64 = self:SteamID64()

	zb.GuiltSQL.PlayerInstances[steamID64] = zb.GuiltSQL.PlayerInstances[steamID64] or {}
	zb.GuiltSQL.PlayerInstances[steamID64].value = zb_guilt

	if not HasMySQL() then return end

	local updateQuery = mysql:Update("zb_guilt")
		updateQuery:Update("value", zb_guilt)
		updateQuery:Where("steamid", steamID64)
	updateQuery:Execute()
end

local function IsLookingAt(ply, targetVec)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    local diff = targetVec - ply:GetShootPos()
    return ply:GetAimVector():Dot(diff) / diff:Length() >= 0.8
end

hook.Add("HomigradDamage", "GuiltReg", function(ply, dmgInfo, hitgroup, ent, harm)
    local Attacker, Victim = dmgInfo:GetAttacker(), ply

    if not IsValid(Attacker) or not Attacker:IsPlayer() then return end
    if not IsValid(Victim) or not (Victim:IsPlayer() or (Victim.organism and Victim.organism.fakePlayer and Victim.organism.alive)) then return end
	if Victim:IsNPC() or Victim:IsNextBot() then return end

    local id = Victim:IsPlayer() and Victim:SteamID() or Victim:EntIndex()
    local id2 = Attacker:IsPlayer() and Attacker:SteamID() or Attacker:EntIndex()
    local maxharm = zb.MaximumHarm or 100
    zb.HarmDone[Victim] = zb.HarmDone[Victim] or {}
    zb.HarmDoneDetailed[id] = zb.HarmDoneDetailed[id] or {}
    zb.HarmDoneKarma[Victim] = zb.HarmDoneKarma[Victim] or {}
    zb.HarmDoneKarma[Victim][Attacker] = zb.HarmDoneKarma[Victim][Attacker] or 0

    local oldharmdone = zb.HarmDone[Victim][Attacker] or 0
    zb.HarmDone[Victim][Attacker] = math.Clamp((zb.HarmDone[Victim][Attacker] or 0) + harm, 0, maxharm)

    zb.HarmAttacked[Attacker] = zb.HarmAttacked[Attacker] or 0
    zb.HarmAttacked[Attacker] = zb.HarmAttacked[Attacker] + harm

    local newharm = math.min(harm + oldharmdone, maxharm)
    local harm2 = newharm - oldharmdone
    local amt = harm2 / maxharm

    if zb and zb.hostage and Victim == zb.hostage then
        zb.hostageLastTouched = Attacker
    end

    local attackerTeam = dmgInfo:GetInflictor().team or (Attacker:IsPlayer() and Attacker:Team()) or Attacker.team
    zb.HarmDoneDetailed[id][id2] = {
        harm = newharm,
        amt = newharm / maxharm,
        teamVictim = Victim:IsPlayer() and Victim:Team() or Victim.team or -1,
        teamAttacker = attackerTeam or -1,
        lasthitgroup = hitgroup,
        lastdmgtype = dmgInfo:GetDamageType(),
        lastattacked = CurTime(),
    }

    if hg_developer:GetBool() then
        Attacker:ChatPrint("This harm done is: "..math.Round(harm2,3))
        Attacker:ChatPrint("Overall amt done is: "..math.Round(amt,3))
        Attacker:ChatPrint("Overall harm done is: "..math.Round(newharm,3))
        Attacker:ChatPrint("Guilt done is: "..math.Round(amt * 60,3))
        Attacker:ChatPrint(" ")
    end

    hook.Run("HarmDone", Attacker, Victim, amt)

    Victim = (hg.GetCurrentCharacter and hg.GetCurrentCharacter(Victim)) or Victim
    Victim = (hg.RagdollOwner and hg.RagdollOwner(Victim)) or Victim

    local rnd, cround = CurrentRound()
    if not rnd then return end

    if rnd.GuiltDisabled or (GetConVar("zb_dev") and GetConVar("zb_dev"):GetBool()) then return end

    if Attacker == Victim then return end

    zb.GuiltTable[Attacker] = zb.GuiltTable[Attacker] or {}
    zb.GuiltTable[Victim] = zb.GuiltTable[Victim] or {}

    Attacker.LastAttacked = CurTime()

    if Victim.isTraitor and !Attacker.isTraitor and rnd.name == "hmcd" and !(zb.IsForce and zb.IsForce(Attacker)) then return end
    if Attacker.isTraitor and !Victim.isTraitor and rnd.name == "hmcd" then return end

    if rnd.name != "hmcd" and (Attacker.Team and Victim.Team and attackerTeam ~= Victim:Team()) then return end
    if zb.ROUND_STATE != 1 and (rnd.name != "cstrike" or !zb.RoundsLeft) then return end
    if Victim.Guilt and Victim.Guilt > 1 and !(zb.IsForce and zb.IsForce(Attacker)) then return end
    if Attacker.IsBerserk and Attacker:IsBerserk() then return end

    local victimWep = Victim:IsPlayer() and IsValid(Victim:GetActiveWeapon()) and Victim:GetActiveWeapon()

    amt = amt * 1
        * (Victim:IsPlayer() and math.Clamp(((Victim.Karma or 100) / 100), 1, 1.2) or 1)
        * (Victim:IsPlayer() and ((IsLookingAt(Victim, Attacker:EyePos()) and (victimWep and ((ishgweapon and ishgweapon(victimWep)) or ((victimWep:GetClass() == "weapon_hands_sh" and victimWep.GetFists and victimWep:GetFists() or victimWep.ismelee2) and Victim:EyePos():DistToSqr(Attacker:EyePos()) <= (90 * 90))))) and 0.5 or 1) or 1)

    local add = amt * maxharm

    if Victim:IsPlayer() and Attacker.PlayerClassEvent then
        add = add * (Attacker:PlayerClassEvent("Guilt", Victim) or 1)
    end
    add = add * 2

    local mul, shouldBanGuilt

    if rnd.GuiltCheck then
        mul, shouldBanGuilt = rnd.GuiltCheck(Attacker, Victim, add, harm2, amt)
        add = add * (mul or 1)
    end

    local guiltadd = amt * 60
    Attacker.Guilt = (Attacker.Guilt or 0) + guiltadd
    Attacker.Karma = math.Clamp((Attacker.Karma or 100) - add * math.max(((1 - (zb.GuiltTable[Victim][Attacker] or 0)) / 1),0), -60, zb.MaxKarma or 100)

    zb.HarmDoneKarma[Victim][Attacker] = zb.HarmDoneKarma[Victim][Attacker] + add

    if shouldBanGuilt and Attacker.Guilt >= 100 then
		if ULib then
			ULib.addBan( Attacker:SteamID(), 30, "Kicked and banned for dealing too much team damage.", Attacker:Name(), "System" )
		else
			Attacker:Ban(30, true)
		end
        PrintMessage(HUD_PRINTTALK, "Player "..Attacker:Name().." has been banned for 30 minutes for RDMing in a team based gamemode.")
    end

    SafeSetNetVar(Attacker, "Karma", Attacker.Karma)

    zb.GuiltTable[Attacker][Victim] = math.Clamp((zb.GuiltTable[Attacker][Victim] or 0) + guiltadd, 0, 200)

    if Attacker.Karma <= 0 then
        local steamID = Attacker:SteamID()
        local name = Attacker:Name()
        local karma = Attacker.Karma

        Attacker:guilt_SetValue( 10 )

        timer.Create("simplewaitforkarmadrop"..Attacker:EntIndex(), 0, 1, function()
            if IsValid(Attacker) then
                karma = Attacker.Karma
            end

            local time = math.Round(60 - karma * 4, 0)

			if ULib then
				ULib.addBan( steamID, 60, "Kicked and banned for having too low karma.", name, "System" )
			end

            PrintMessage(HUD_PRINTTALK, "Player "..name.." has been banned for "..time.." minutes for having too low karma.")
        end)
    end
end)

function zb.IsForce(Attacker)
    return Attacker.PlayerClassName == "police" or Attacker.PlayerClassName == "nationalguard" or Attacker.PlayerClassName == "swat"
end

hook.Add("PlayerDisconnected","GuiltSaveOnDisconect",function(ply)
    if ply.guilt_SetValue then ply:guilt_SetValue( ply.Karma or 100 ) end
end)

hook.Add("Player Spawn","SlowlyRestoreKarma",function(ply)
    if OverrideSpawn then return end

    ply.lastwarning = nil
    ply.Karma = ply.Karma or 100
    SafeSetNetVar(ply, "Karma", ply.Karma)
    ply.Guilt = 0
end)

hook.Add("Player Think", "karmagain", function(ply)
    if (ply.KarmaGainThink or 0) > CurTime() then return end
    ply.KarmaGainThink = CurTime() + 120

    ply.Karma = math.Clamp((ply.Karma or 100) + (ply.Karma > 100 and 0.1 or (ply.KarmaGain or 0.75)), 0, zb.MaxKarma or 100)
    SafeSetNetVar(ply, "Karma", ply.Karma)
end)

hook.Add("ZB_EndRound","savevalues",function()
    for i,ply in player.Iterator() do
        if ply.guilt_SetValue then ply:guilt_SetValue( ply.Karma or 100 ) end
    end
end)

hook.Add("ZB_StartRound","NO_HARM",function()
    for i,ply in player.Iterator() do
        if (ply.Guilt or 0) < 1 then
            ply.KarmaGain = math.Clamp((ply.KarmaGain or 0.75) + 0.25, 0.75, 1.5)
        else
            ply.KarmaGain = 0.75
        end
    end

    zb.HarmDone = {}
    zb.HarmDoneKarma = {}
end)

util.AddNetworkString("get_karma")
net.Receive("get_karma",function(len, ply)
    if not ply:IsAdmin() then return end

    local tbl = {}

    for i,pl in player.Iterator() do
        tbl[pl:UserID()] = pl.Karma
    end

    net.Start("get_karma")
    net.WriteTable(tbl)
    net.Send(ply)
end)

util.AddNetworkString("open_guilt_menu")
util.AddNetworkString("forgive_player")

net.Receive("open_guilt_menu",function(len, ply)
    if ply:Alive() then return end
    local tbl = zb.HarmDoneKarma[ply] or {}
    net.Start("open_guilt_menu")
    net.WriteTable(tbl)
    net.Send(ply)
end)

net.Receive("forgive_player", function(len, ply)
    local ent = net.ReadEntity()
    if not IsValid(ent) or not zb.HarmDoneKarma[ply] then return end
    local harm = zb.HarmDoneKarma[ply][ent]
    if not harm then return end

    ent.Karma = math.Clamp((ent.Karma or 100) + harm, 0, zb.MaxKarma or 100)
    SafeSetNetVar(ent, "Karma", ent.Karma)

    zb.HarmDone[ply] = zb.HarmDone[ply] or {}
    zb.HarmDone[ply][ent] = 0
    zb.HarmDoneKarma[ply][ent] = 0
    net.Start("open_guilt_menu")
    net.WriteTable(zb.HarmDoneKarma[ply])
    net.Send(ply)
end)

hook.Add("Player Spawn", "GuiltKnown",function(ply)
    if ply.Karma then
        ply:ChatPrint("Your current karma is "..tostring(math.Round(ply.Karma)).."")
    end
end)
