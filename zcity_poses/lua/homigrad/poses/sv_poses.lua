if not SERVER then return end

util.AddNetworkString("zb_poses_set")
util.AddNetworkString("zb_poses_clear")
util.AddNetworkString("zb_poses_request")

local function canPose(ply)
	if not IsValid(ply) or not ply:Alive() then return false end
	if IsValid(ply.FakeRagdoll) or ply:InVehicle() then return false end
	if ply.organism and ply.organism.otrub then return false end
	return true
end

local function clearPose(ply)
	if not IsValid(ply) then return end

	ply.zb_pose_id = nil
	ply.zb_pose_seq = nil
	ply.zb_pose_act = nil
	ply.zb_pose_seq2 = nil
	ply.zb_pose_act2 = nil
	ply.zb_pose_hold = nil
	ply.zb_pose_phase = nil
	ply.zb_pose_next = nil

	if ply.AnimResetGestureSlot then
		ply:AnimResetGestureSlot(GESTURE_SLOT_VCD)
		ply:AnimResetGestureSlot(GESTURE_SLOT_GRENADE)
		ply:AnimResetGestureSlot(GESTURE_SLOT_CUSTOM)
	end

	net.Start("zb_poses_clear")
		net.WriteEntity(ply)
	net.Broadcast()
end

local function playLayer(ply, seqId, act, autoKill, slot)
	slot = slot or GESTURE_SLOT_VCD
	if seqId and seqId >= 0 then
		ply:AddVCDSequenceToGestureSlot(slot, seqId, 0, autoKill and true or false)
		return true
	end
	if act then
		ply:AnimRestartGesture(slot, act, autoKill and true or false)
		return true
	end
	return false
end

function zb.poses.Stop(ply, force)
	if not IsValid(ply) or not ply.zb_pose_id then return end

	if force then
		clearPose(ply)
		return
	end

	local pose = zb.poses.Get(ply.zb_pose_id)
	if not pose or ply.zb_pose_phase == 3 then
		clearPose(ply)
		return
	end

	local outroSeqId = pose.outro_seq and select(1, zb.poses.ResolveSequence(ply, {seq = pose.outro_seq})) or -1
	local outroAct = pose.outro_act
	local slot = pose.override_weapon and GESTURE_SLOT_CUSTOM or GESTURE_SLOT_VCD

	if outroSeqId >= 0 or outroAct then
		ply.zb_pose_phase = 3
		ply.zb_pose_seq = (outroSeqId >= 0) and outroSeqId or nil
		ply.zb_pose_act = outroAct
		ply.zb_pose_seq2 = nil
		ply.zb_pose_act2 = nil
		
		playLayer(ply, ply.zb_pose_seq, ply.zb_pose_act, true, slot)

		local dur = 2
		if ply.zb_pose_seq then
			local d = ply:SequenceDuration(ply.zb_pose_seq)
			if d and d > 0.1 then dur = d end
		end
		ply.zb_pose_next = CurTime() + math.max(0.4, dur * 0.95)

		net.Start("zb_poses_set")
			net.WriteEntity(ply)
			net.WriteString(pose.id)
			net.WriteInt(ply.zb_pose_seq or -1, 16)
			net.WriteInt(ply.zb_pose_act or 0, 16)
			net.WriteInt(-1, 16)
			net.WriteInt(0, 16)
			net.WriteBool(false)
			net.WriteInt(3, 8)
		net.Broadcast()
	else
		clearPose(ply)
	end
end

function zb.poses.Apply(ply, id)
	if not canPose(ply) then return end

	local pose = zb.poses.Get(id)
	if not pose then return end

	if pose.stop then
		zb.poses.Stop(ply, false)
		return
	end

	if ply.zb_pose_phase and ply.zb_pose_phase > 0 then clearPose(ply) end

	if pose.auto_holster and ply:HasWeapon("weapon_hands_sh") then
		local active = ply:GetActiveWeapon()
		if IsValid(active) and active:GetClass() ~= "weapon_hands_sh" then
			ply:SelectWeapon("weapon_hands_sh")
		end
	end

	if pose.zmanip then
		if hg and hg.RunZManipAnim then hg.RunZManipAnim(ply, pose.zmanip)
		else ply:ConCommand("hg_hand_gesture " .. pose.zmanip) end
		return
	end

	local seqId = pose.seq and select(1, zb.poses.ResolveSequence(ply, {seq = pose.seq})) or -1
	local seq2Id = pose.seq2 and select(1, zb.poses.ResolveSequence(ply, {seq = pose.seq2})) or -1
	local act = pose.act
	local act2 = pose.act2

	if (seqId < 0 and not act) and (seq2Id >= 0 or act2) then
		seqId = seq2Id
		act = act2
		seq2Id = -1
		act2 = nil
	end

	if (seqId < 0 and not act) then
		return
	end

	local hasPhase2 = (seq2Id >= 0) or (act2 ~= nil)
	local loops = pose.hold

	ply.zb_pose_id = pose.id
	ply.zb_pose_seq = (seqId >= 0) and seqId or nil
	ply.zb_pose_act = act
	ply.zb_pose_seq2 = (seq2Id >= 0) and seq2Id or nil
	ply.zb_pose_act2 = act2
	ply.zb_pose_hold = loops
	
	if hasPhase2 then ply.zb_pose_phase = 1
	elseif loops then ply.zb_pose_phase = 2
	else ply.zb_pose_phase = 0 end

	local s = ply.zb_pose_seq
	local a = ply.zb_pose_act
	local slot = pose.override_weapon and GESTURE_SLOT_CUSTOM or GESTURE_SLOT_VCD

	playLayer(ply, s, a, ply.zb_pose_phase == 0, slot)

	if ply.zb_pose_phase > 0 then
		if ply.zb_pose_phase == 1 and pose.switch_delay then
			ply.zb_pose_next = CurTime() + pose.switch_delay
		else
			local dur = 2
			if s then
				local d = ply:SequenceDuration(s)
				if d and d > 0.1 then dur = d end
			end
			ply.zb_pose_next = CurTime() + math.max(0.4, dur * 0.95)
		end
	else
		-- Phase 0 = one-shot, non-looping pose. The Think loop never touches
		-- this again, but CalcMainActivity still needs to know when the
		-- clip finishes so an override_weapon pose doesn't get stuck
		-- overriding the main sequence forever.
		local dur = 2
		if s then
			local d = ply:SequenceDuration(s)
			if d and d > 0.1 then dur = d end
		end
		ply.zb_pose_next = CurTime() + math.max(0.4, dur * 0.95)
	end

	net.Start("zb_poses_set")
		net.WriteEntity(ply)
		net.WriteString(pose.id)
		net.WriteInt(ply.zb_pose_seq or -1, 16)
		net.WriteInt(ply.zb_pose_act or 0, 16)
		net.WriteInt(ply.zb_pose_seq2 or -1, 16)
		net.WriteInt(ply.zb_pose_act2 or 0, 16)
		net.WriteBool(loops or false)
		net.WriteInt(ply.zb_pose_phase, 8)
	net.Broadcast()
end

function zb.poses.Clear(ply) clearPose(ply) end

net.Receive("zb_poses_request", function(_, ply)
	if not IsValid(ply) then return end
	local id = net.ReadString()
	if not id or id == "" then return end

	ply.zb_pose_cd = ply.zb_pose_cd or 0
	if ply.zb_pose_cd > CurTime() then return end
	ply.zb_pose_cd = CurTime() + 0.25

	zb.poses.Apply(ply, id)
end)

concommand.Add("zb_pose", function(ply, cmd, args)
	if not IsValid(ply) then return end
	local id = args[1]
	if not id or id == "0" or id == "stop" or id == "clear" then
		zb.poses.Stop(ply, false)
		return
	end
	zb.poses.Apply(ply, id)
end)

concommand.Add("zb_pose_list", function(ply)
	local out = function(s) if IsValid(ply) then ply:ChatPrint(s) else print(s) end end
	out("[zb_poses] poses:")
	for _, p in ipairs(zb.poses.GetAll()) do out("  " .. p.id .. " – " .. p.name) end
end)

hook.Add("Think", "zb_poses_hold_loop", function()
	for _, ply in ipairs(player.GetAll()) do
		if not ply.zb_pose_phase or ply.zb_pose_phase == 0 then continue end
		
		if not ply:Alive() or IsValid(ply.FakeRagdoll) or ply:InVehicle() or (ply.organism and ply.organism.otrub) then
			zb.poses.Stop(ply, true)
			continue
		end

		local pose = zb.poses.Get(ply.zb_pose_id)
		local slot = (pose and pose.override_weapon) and GESTURE_SLOT_CUSTOM or GESTURE_SLOT_VCD


		if pose and pose.stop_on_move and ply:GetVelocity():Length2DSqr() > 100 then
			zb.poses.Stop(ply, false)
			continue
		end


		if pose and pose.auto_holster then
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() ~= "weapon_hands_sh" then
				zb.poses.Stop(ply, false)
				continue
			end
		end

		local nextT = ply.zb_pose_next
		if not nextT or nextT > CurTime() then continue end

		if ply.zb_pose_phase == 1 then
			ply.zb_pose_phase = 2
			local s = ply.zb_pose_seq2
			local a = ply.zb_pose_act2
			playLayer(ply, s, a, not ply.zb_pose_hold, slot)
			
			if ply.zb_pose_hold then
				local dur = 2
				if s then
					local d = ply:SequenceDuration(s)
					if d and d > 0.1 then dur = d end
				end
				ply.zb_pose_next = CurTime() + math.max(0.4, dur * 0.95)
			else
				ply.zb_pose_phase = 0
				local dur = 2
				if s then
					local d = ply:SequenceDuration(s)
					if d and d > 0.1 then dur = d end
				end
				ply.zb_pose_next = CurTime() + math.max(0.4, dur * 0.95)
			end
			
		elseif ply.zb_pose_phase == 2 then
			local s = ply.zb_pose_seq2 or ply.zb_pose_seq
			local a = ply.zb_pose_act2 or ply.zb_pose_act
			playLayer(ply, s, a, false, slot)
			
			local dur = 2
			if s then
				local d = ply:SequenceDuration(s)
				if d and d > 0.1 then dur = d end
			end
			ply.zb_pose_next = CurTime() + math.max(0.4, dur * 0.95)
			
		elseif ply.zb_pose_phase == 3 then
			zb.poses.Stop(ply, true)
		end
	end
end)

hook.Add("PlayerDeath", "zb_poses_clear", function(ply) zb.poses.Stop(ply, true) end)
hook.Add("PlayerSpawn", "zb_poses_clear", function(ply)
	timer.Simple(0, function() if IsValid(ply) then zb.poses.Stop(ply, true) end end)
end)
