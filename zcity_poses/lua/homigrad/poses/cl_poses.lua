-- zb_poses client: layered VCD gesture + Z-City radial

if not CLIENT then return end

net.Receive("zb_poses_set", function()
	local ply = net.ReadEntity()
	local id = net.ReadString()
	local seq = net.ReadInt(16)
	local act = net.ReadInt(16)
	local seq2 = net.ReadInt(16)
	local act2 = net.ReadInt(16)
	local hold = net.ReadBool()
	local phase = net.ReadInt(8)

	if not IsValid(ply) then return end
	local pose = zb.poses.Get(id)

	ply.zb_pose_id = id
	ply.zb_pose_seq = (seq >= 0) and seq or nil
	ply.zb_pose_act = (act ~= 0) and act or nil
	ply.zb_pose_seq2 = (seq2 >= 0) and seq2 or nil
	ply.zb_pose_act2 = (act2 ~= 0) and act2 or nil
	ply.zb_pose_hold = hold
	ply.zb_pose_phase = phase

	local s = ply.zb_pose_seq
	local a = ply.zb_pose_act
	local slot = (pose and pose.override_weapon) and GESTURE_SLOT_CUSTOM or GESTURE_SLOT_VCD
	
	local autoKill = (phase == 0 or phase == 3)
	if s then
		ply:AddVCDSequenceToGestureSlot(slot, s, 0, autoKill)
	elseif a then
		ply:AnimRestartGesture(slot, a, autoKill)
	end

	if phase > 0 then
		if phase == 1 and pose and pose.switch_delay then
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
		-- Phase 0 = one-shot pose. Keep an expiry so CalcMainActivity (in
		-- sh_poses.lua) knows when to stop overriding the main sequence.
		local dur = 2
		if s then
			local d = ply:SequenceDuration(s)
			if d and d > 0.1 then dur = d end
		end
		ply.zb_pose_next = CurTime() + math.max(0.4, dur * 0.95)
	end
end)

net.Receive("zb_poses_clear", function()
	local ply = net.ReadEntity()
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
end)

hook.Add("Think", "zb_poses_hold_loop_cl", function()
	for _, ply in ipairs(player.GetAll()) do
		if not ply.zb_pose_phase or ply.zb_pose_phase == 0 then continue end
		if ply.zb_pose_phase == 3 then continue end
		if not ply:Alive() or IsValid(ply.FakeRagdoll) or ply:InVehicle() then continue end

		local nextT = ply.zb_pose_next
		if not nextT or nextT > CurTime() then continue end

		local pose = zb.poses.Get(ply.zb_pose_id)
		local slot = (pose and pose.override_weapon) and GESTURE_SLOT_CUSTOM or GESTURE_SLOT_VCD

		if ply.zb_pose_phase == 1 then
			ply.zb_pose_phase = 2
			local s = ply.zb_pose_seq2
			local a = ply.zb_pose_act2
			
			if s then ply:AddVCDSequenceToGestureSlot(slot, s, 0, not ply.zb_pose_hold)
			elseif a then ply:AnimRestartGesture(slot, a, not ply.zb_pose_hold) end
			
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
			
			if s then ply:AddVCDSequenceToGestureSlot(slot, s, 0, false)
			elseif a then ply:AnimRestartGesture(slot, a, false) end
			
			local dur = 2
			if s then
				local d = ply:SequenceDuration(s)
				if d and d > 0.1 then dur = d end
			end
			ply.zb_pose_next = CurTime() + math.max(0.4, dur * 0.95)
		end
	end
end)

local function requestPose(id)
	net.Start("zb_poses_request")
		net.WriteString(id)
	net.SendToServer()
end

concommand.Add("zb_pose", function(ply, cmd, args)
	local id = args[1]
	if not id or id == "0" or id == "stop" or id == "clear" then
		requestPose("stop")
		return
	end
	requestPose(id)
end, function(cmd, args)
	local input = string.Trim(args)
	local suggestions = {}
	for _, pose in ipairs(zb.poses.GetAll()) do
		if pose.stop then continue end
		if input == "" or string.find(pose.id, input, 1, true) then
			table.insert(suggestions, cmd .. " " .. pose.id)
		end
	end
	return suggestions
end)

local function buildPoseSubmenu()
	local commands = {}
	local sorted_poses = {}

	for _, pose in ipairs(zb.poses.GetAll()) do
		if pose.stop then continue end
		table.insert(sorted_poses, pose)
	end
	table.sort(sorted_poses, function(a, b) return a.name < b.name end)

	for i, pose in ipairs(sorted_poses) do
		commands[i] = {
			[1] = function() requestPose(pose.id) end,
			[2] = pose.name,
		}
	end
	return commands
end

hook.Add("radialOptions", "zb_poses", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end
	local organism = ply.organism or {}
	if organism.otrub then return end
	if hg.GetCurrentCharacter and hg.GetCurrentCharacter(ply) ~= ply then return end

	local tbl = {
		function(mouseClick)
			if mouseClick == 2 then
				if hg.CreateRadialMenu then
					hg.CreateRadialMenu(buildPoseSubmenu())
				end
				return -1
			else
				requestPose("stop")
			end
		end,
		"Poses\nRMB - Menu",
	}

	hg.radialOptions = hg.radialOptions or {}
	hg.radialOptions[#hg.radialOptions + 1] = tbl
end)

print("[zb_poses] layered gestures + radial ready")
