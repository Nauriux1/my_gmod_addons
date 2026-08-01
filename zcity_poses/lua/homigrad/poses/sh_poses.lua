zb = zb or {}
zb.poses = zb.poses or {}

--[[
  Pose entry:
    id                – internal id
    name              – label shown on radial
    seq               – FIRST sequence name (preferred) or list of fallbacks
    act               – FIRST optional ACT_* gesture
    seq2              – SECOND sequence name (plays after seq finishes)
    act2              – SECOND optional ACT_* gesture
    outro_seq         – OUTRO sequence name (plays when stopping the pose)
    outro_act         – OUTRO optional ACT_* gesture
    switch_delay      - optional float (seconds) to force the switch to the 2nd animation after this exact time
    hold              – true = loop the FINAL animation in the chain until stopped
    zmanip            – optional zmanip / hg_hand_gesture name (one-shot hands)
    stop_on_move      - true = automatically clear/outro the pose if the player walks fast
    restrict_movement - true = forces the player's max speed to walk speed while active
    auto_holster      - true = automatically switches weapon to "weapon_hands_sh" when starting
    override_weapon   - true = forces the animation to play OVER two-handed weapons (like zmanip does)
]]

zb.poses.List = {
    { id = "stop", name = "STOP", hold = false, stop = false },
    
    { 
        id = "arms_crossed", name = "Arms crossed", 
        seq = { "idle_subtle", "menuidle1", "lineidle01", "idle_all_01" }, 
        hold = true, restrict_movement = true, auto_holster = true 
    },
    { 
        id = "hands_pockets", name = "Hands in pockets", 
        seq = { "lineidle02", "idle_subtle", "menuidle1", "cidle_all" }, 
        hold = true, restrict_movement = true, auto_holster = true 
    },
    { 
        id = "think", name = "Thinking", 
        seq = { "lineidle03", "idle_subtle", "menuidle1" }, 
        hold = true, restrict_movement = true, auto_holster = true 
    },
    { 
        id = "lean", name = "Lean", 
        seq = { "lean_left", "leanleft", "lineidle01", "idle_subtle" }, 
        hold = true, stop_on_move = true, restrict_movement = true, auto_holster = true 
    },
    
    { 
        id = "clap", name = "Clap Loop", 
        seq = "g_clap", 
        seq2 = { "g_claplooparms" }, 
        switch_delay = 1.5,
        hold = true, stop_on_move = false, auto_holster = true, override_weapon = true
    },
    { 
        id = "plead", name = "Plead", 
        seq = "g_plead_01", 
        hold = false, override_weapon = true
    },
    

}

zb.poses.ByID = {}
for _, p in ipairs(zb.poses.List) do
    zb.poses.ByID[p.id] = p
end

function zb.poses.Get(id) return zb.poses.ByID[id] end
function zb.poses.GetAll() return zb.poses.List end

function zb.poses.ResolveSequence(ent, pose)
    if not IsValid(ent) or not pose then return -1, nil end

    if isstring(pose.seq) then
        local id = ent:LookupSequence(pose.seq)
        if id and id >= 0 then return id, pose.seq end
    elseif istable(pose.seq) then
        for _, name in ipairs(pose.seq) do
            local id = ent:LookupSequence(name)
            if id and id >= 0 then return id, name end
        end
    end

    return -1, nil
end

-- Forced Walk Speed Logic
hook.Add("SetupMove", "zb_poses_slowdown", function(ply, mv, cmd)
    if ply.zb_pose_id then
        local pose = zb.poses.Get(ply.zb_pose_id)
        if pose and pose.restrict_movement then
            local walkSpeed = ply:GetWalkSpeed() or 100
            mv:SetMaxClientSpeed(math.min(mv:GetMaxClientSpeed(), walkSpeed))
            mv:SetMaxSpeed(math.min(mv:GetMaxSpeed(), walkSpeed))
        end
    end
end)

-- override_weapon poses need to beat the arm/hand IK that two-handed weapon
-- holdtypes drive - a gesture slot alone can't do that, it only layers on
-- top of whatever the main sequence already is.
--
-- We do NOT touch CalcMainActivity. That hook is what picks the correct
-- movement-based base activity (idle/walk/run) every frame - forcing it to
-- a fixed activity froze the legs regardless of actual movement, and could
-- even resolve to an invalid/mismatched activity on a non-stock playermodel.
--
-- Instead we only intercept TranslateActivity - the step that takes the
-- generic base activity CalcMainActivity picked (e.g. ACT_HL2MP_IDLE) and
-- maps it into the weapon-specific two-handed variant (e.g.
-- ACT_HL2MP_IDLE_AR2), which is what locks the arms into the gun grip.
-- Returning the incoming activity unchanged skips that weapon-specific
-- remap entirely, so legs keep playing whatever correct idle/walk/run
-- activity CalcMainActivity already chose, while the arms are freed up for
-- the gesture-slot layer (bone-masked to arms/upper body only, set up in
-- sv_poses.lua/cl_poses.lua) to actually show through.
--
-- NOTE: must return identically on client AND server (server needs it for
-- hit detection), which is why this lives in the shared file.
local function poseOverrideActive(ply)
    if not IsValid(ply) or not ply.zb_pose_id then return false end
    local pose = zb.poses.Get(ply.zb_pose_id)
    if not pose or not pose.override_weapon then return false end
    -- zb_pose_next doubles as "when does the current clip end" for every
    -- phase (including one-shots, see sv_poses.lua / cl_poses.lua)
    if not ply.zb_pose_next or CurTime() >= ply.zb_pose_next then return false end
    return true
end

-- Public: other files (e.g. weapons/homigrad_base/sh_worldmodel.lua's TPIK
-- code) can check this to know whether they should treat the player as
-- "posed" and back off their own animation/rotation overrides.
zb.poses.IsOverrideActive = poseOverrideActive
