--ArachnitCZ is cool and awesome and perfect and epic and he beat me and ViperCZ
AddCSLuaFile()
require("mw_utils")

function clearBaseClass(t)
    t.BaseClass = nil
    
    for i, v in pairs(t) do
        if (istable(v)) then
            clearBaseClass(v)
        end
    end
end

function SWEP:GetStoredAttachment(ind)
    if (istable(ind)) then
        PrintTable(ind)
        error("Something went wrong when loading an attachment! Probably still using old customization method (read above for info).")
    end
    
    if (MW_ATTS[ind] == nil) then
        error("Attachment "..(ind != nil && ind || "none").." is missing!")
    end
    
    return MW_ATTS[ind]
end

function SWEP:GetBreathingSwayAngle()
    local plr = self:GetOwner()
	if !IsValid(plr) then return end

    local ang = self:GetBreathingAngle()
    ang.p = math.NormalizeAngle(ang.p)
    ang.y = math.NormalizeAngle(ang.y)
    ang.r = math.NormalizeAngle(ang.r)
	
    if !GetConVar("mgbase_sv_breathing"):GetBool() then
		ang:Mul(0)
		return ang
	end

    local isAiming = self:GetAimDelta() >= 1
    local delaySpeed = isAiming and 0.2 or -0.6
    local weaponMult = self.Zoom.IdleSway
    
    if self:GetSight() && self:GetSight().Optic && self:GetAimModeDelta() <= self.m_hybridSwitchThreshold  && self:GetTacStanceDelta() <= self.m_hybridSwitchThreshold then
        delaySpeed = isAiming and 4 or -0.6
    end

    self.m_swayLerp = math.Clamp(self.m_swayLerp + delaySpeed*FrameTime(), 0, 1)
    ang:Mul(weaponMult * self.m_swayLerp)
    
    return ang
end

SWEP.Category = "MG" 
SWEP.Spawnable = false
SWEP.AdminOnly = false
SWEP.PrintName = "Base Weapon"
SWEP.Base = "weapon_base" 
SWEP.BounceWeaponIcon = false
-- SWEP.m_WeaponDeploySpeed = 12 --fastest it can be because Think freezes when weapon is drawing
SWEP.ViewModel = "models/weapons/c_arms.mdl"
SWEP.VModel = "models/weapons/v_357.mdl"

SWEP.RenderGroup = RENDERGROUP_OPAQUE
SWEP.RenderMode = RENDERMODE_NORMAL

SWEP.ViewModelFlip = false
SWEP.ViewModelFOV = 64
SWEP.WorldModel = "models/weapons/w_357.mdl"
SWEP.AutoSwitchFrom = false
SWEP.AutoSwitchTo = false
SWEP.BobScale = 0 
SWEP.SwayScale = 0
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = false
SWEP.UseHands = false

SWEP.Primary.DefaultClip = 0

SWEP.Secondary.ClipSize = 0
SWEP.Secondary.DefaultClip = 0
SWEP.Secondary.Ammo = -1
SWEP.CrouchVector = Vector(-1, -1, -1)

--modules: 
-- shared, dt and tasks should be first
-- load order is important
include("modules/shared/sh_datatables.lua")
include("modules/shared/sh_tasks.lua")

include("modules/shared/tasks/task_aimmode.lua")
include("modules/shared/tasks/task_customize.lua")
include("modules/shared/tasks/task_deploy.lua")
include("modules/shared/tasks/task_firemode.lua")
include("modules/shared/tasks/task_holster.lua")
include("modules/shared/tasks/task_inspect.lua")
include("modules/shared/tasks/task_lower.lua")
include("modules/shared/tasks/task_melee.lua")
include("modules/shared/tasks/task_primaryfire.lua")
include("modules/shared/tasks/task_raise.lua")
include("modules/shared/tasks/task_rechamber.lua")
include("modules/shared/tasks/task_reload_end.lua")
include("modules/shared/tasks/task_reload.lua")
include("modules/shared/tasks/task_sprint_in.lua")
include("modules/shared/tasks/task_sprint_out.lua")
include("modules/shared/tasks/task_underbarrel_in.lua")
include("modules/shared/tasks/task_underbarrel_out.lua")

include("modules/shared/sh_think.lua")
include("modules/shared/sh_button_dispatcher.lua")
include("modules/shared/sh_sprint_behaviour.lua")
include("modules/shared/sh_safety_behavior.lua")
include("modules/shared/sh_bipod_behavior.lua")
include("modules/shared/sh_inspect_behavior.lua")
include("modules/shared/sh_aim_behaviour.lua")
include("modules/shared/sh_aim_mode_behavior.lua")
include("modules/shared/sh_reload_behaviour.lua")
include("modules/shared/sh_trigger_behavior.lua")
include("modules/shared/sh_melee_behaviour.lua")
include("modules/shared/sh_firemode_behaviour.lua")
include("modules/shared/sh_primaryattack_behaviour.lua")
include("modules/shared/sh_holdtypes.lua")
include("modules/shared/sh_customization.lua")
include("modules/shared/sh_stats.lua")

-- client
include("modules/client/cl_calcview.lua") 
include("modules/client/cl_worldmodel_render.lua")  
include("modules/client/cl_hud.lua") 
include("modules/client/cl_spawnmenu.lua") 
include("modules/client/cl_new_customizemenu.lua")
-- reverb
include("modules/reverb/mw_reverb.lua")
include("modules/reverb/mw_reverbimpl.lua") 

--particles:
game.AddParticles("particles/ac_mw_handguns.pcf")
game.AddParticles("particles/mw_particles.pcf")
game.AddParticles("particles/mw19_attachments.pcf")
game.AddParticles("particles/mgbase_tracer.pcf")
game.AddParticles("particles/generic_explosions_pak.pcf")
game.AddParticles("particles/weapon_fx_mwb.pcf")
game.AddParticles("particles/matin_weapon_fx_mwb.pcf")

PrecacheParticleSystem("mw_ins2_shell_eject")
PrecacheParticleSystem("mw_fas2_shocksmoke")

PrecacheParticleSystem("mw_fas2_muzzleflash_ar")
PrecacheParticleSystem("mw_fas2_muzzleflash_pistol")
PrecacheParticleSystem("mw_fas2_muzzleflash_pistol_deagle")
PrecacheParticleSystem("mw_fas2_muzzleflash_dmr")
PrecacheParticleSystem("mw_fas2_muzzleflash_lmg")
PrecacheParticleSystem("mw_fas2_muzzleflash_shotgun")
PrecacheParticleSystem("mw_fas2_muzzleflash_slug")
PrecacheParticleSystem("mw_ins2_ins_weapon_rpg_frontblast")
PrecacheParticleSystem("mw_fas2_muzzleflash_suppressed")
PrecacheParticleSystem("matin_mw_muzzleflash_ak")

PrecacheParticleSystem("mw_doi_flamethrower")

PrecacheParticleSystem("AC_muzzle_pistol_suppressed")
PrecacheParticleSystem("ac_muzzle_muzzlebreak")
PrecacheParticleSystem("ac_muzzle_flashhider")
PrecacheParticleSystem("ac_muzzle_compensator")
PrecacheParticleSystem("AC_muzzle_shotgun")
PrecacheParticleSystem("AC_muzzle_rifle")
PrecacheParticleSystem("AC_muzzle_pistol")
PrecacheParticleSystem("AC_muzzle_desert")
PrecacheParticleSystem("AC_muzzle_shotgun_db")
PrecacheParticleSystem("AC_muzzle_pistol_ejection")
PrecacheParticleSystem("AC_muzzle_desert_ejection")
PrecacheParticleSystem("AC_muzzle_pistol_smoke_barrel")
PrecacheParticleSystem("AC_muzzle_minigun_smoke_barrel")

PrecacheParticleSystem("flashlight_mw19")
PrecacheParticleSystem("mw_envdust")
PrecacheParticleSystem("smoke_explosion_he")
PrecacheParticleSystem("Generic_explo_high")
PrecacheParticleSystem("mgbase_tracer")
PrecacheParticleSystem("mgbase_tracer_fast")
PrecacheParticleSystem("mgbase_tracer_slow")
PrecacheParticleSystem("mgbase_tracer_small")

-- common
PrecacheParticleSystem("matin_mw_muzzleflash_ar")
PrecacheParticleSystem("matin_mw_muzzleflash_ar2")
PrecacheParticleSystem("matin_mw_muzzleflash_ar3")
PrecacheParticleSystem("matin_mw_muzzleflash_ar4")
PrecacheParticleSystem("matin_mw_muzzleflash_ar5")
PrecacheParticleSystem("matin_mw_muzzleflash_ar6")
PrecacheParticleSystem("matin_mw_muzzleflash_ar7")
PrecacheParticleSystem("matin_mw_muzzleflash_pl")
PrecacheParticleSystem("matin_mw_muzzleflash_dmr")
PrecacheParticleSystem("matin_mw_muzzleflash_lmg")
PrecacheParticleSystem("matin_mw_muzzleflash_smg")
PrecacheParticleSystem("matin_mw_muzzleflash_smg2")
PrecacheParticleSystem("matin_mw_muzzleflash_smg3")
PrecacheParticleSystem("matin_mw_muzzleflash_sg")
PrecacheParticleSystem("matin_mw_muzzleflash_sr")
PrecacheParticleSystem("matin_mw_muzzleflash_sr2")
PrecacheParticleSystem("matin_mw_muzz_sg_db_f")
PrecacheParticleSystem("matin_mw_muzzleflash_sup")
PrecacheParticleSystem("matin_mw_muzzleflash_sup2")

--new muzzle particles
game.AddParticles("particles/matin_mwb_fx.pcf")
game.AddParticles("particles/matin_mwb_muzzlebrake_fx.pcf")
game.AddParticles("particles/matin_mwb_compensator_fx.pcf")
game.AddParticles("particles/matin_mwb_flashhider_fx.pcf")
game.AddParticles("particles/matin_mwb_suppressor_fx.pcf")
game.AddParticles("particles/matin_mwb_dragon_breath_impact_fx.pcf")


PrecacheParticleSystem("mwb_shell_eject")
PrecacheParticleSystem("mwb_shell_eject2")

--muzzle attachment
PrecacheParticleSystem("mwb_suppressor_0")
PrecacheParticleSystem("mwb_suppressor_1")
PrecacheParticleSystem("mwb_suppressor_2")
PrecacheParticleSystem("mwb_suppressor_3")
PrecacheParticleSystem("mwb_compensator_0")
PrecacheParticleSystem("mwb_compensator_1")
PrecacheParticleSystem("mwb_compensator_2")
PrecacheParticleSystem("mwb_compensator_3")
PrecacheParticleSystem("mwb_flashhider_0")
PrecacheParticleSystem("mwb_flashhider_1")
PrecacheParticleSystem("mwb_flashhider_2")
PrecacheParticleSystem("mwb_flashhider_3")
PrecacheParticleSystem("mwb_muzzlebrake_0")
PrecacheParticleSystem("mwb_muzzlebrake_1")
PrecacheParticleSystem("mwb_muzzlebrake_2")
PrecacheParticleSystem("mwb_muzzlebrake_3")

--Pistols Basic
PrecacheParticleSystem("mwb_muzzle_pl_0")
PrecacheParticleSystem("mwb_muzzle_pl_1")
PrecacheParticleSystem("mwb_muzzle_pl_2")
PrecacheParticleSystem("mwb_muzzle_pl_3")
PrecacheParticleSystem("mwb_muzzle_pl_4")
PrecacheParticleSystem("mwb_muzzle_pl_5")
PrecacheParticleSystem("mwb_muzzle_pl_6")

--AR Basic
PrecacheParticleSystem("mwb_muzzle_ar_0")
PrecacheParticleSystem("mwb_muzzle_ar_1")
PrecacheParticleSystem("mwb_muzzle_ar_2")
PrecacheParticleSystem("mwb_muzzle_ar_3")
PrecacheParticleSystem("mwb_muzzle_ar_4")
PrecacheParticleSystem("mwb_muzzle_ar_5")
PrecacheParticleSystem("mwb_muzzle_ar_6")
PrecacheParticleSystem("mwb_muzzle_ar_7")
PrecacheParticleSystem("mwb_muzzle_ar_8")
PrecacheParticleSystem("mwb_muzzle_ar_9")
PrecacheParticleSystem("mwb_muzzle_ar_10")
PrecacheParticleSystem("mwb_muzzle_ar_11")

--SMG Basic
PrecacheParticleSystem("mwb_muzzle_smg_0")
PrecacheParticleSystem("mwb_muzzle_smg_1")
PrecacheParticleSystem("mwb_muzzle_smg_2")
PrecacheParticleSystem("mwb_muzzle_smg_3")
PrecacheParticleSystem("mwb_muzzle_smg_4")
PrecacheParticleSystem("mwb_muzzle_smg_5")

--SG Basic
PrecacheParticleSystem("mwb_muzzle_sg_0")
PrecacheParticleSystem("mwb_muzzle_sg_1")
PrecacheParticleSystem("mwb_muzzle_sg_2")
PrecacheParticleSystem("mwb_muzzle_sg_3") --DB

--DMR Basic
PrecacheParticleSystem("mwb_muzzle_dmr_0")
PrecacheParticleSystem("mwb_muzzle_dmr_1")
PrecacheParticleSystem("mwb_muzzle_dmr_2")
PrecacheParticleSystem("mwb_muzzle_dmr_3")

--SR Basic
PrecacheParticleSystem("mwb_muzzle_sr_0")
PrecacheParticleSystem("mwb_muzzle_sr_1")
PrecacheParticleSystem("mwb_muzzle_sr_2")
PrecacheParticleSystem("mwb_muzzle_sr_3")
PrecacheParticleSystem("mwb_muzzle_sr_4")

--LMG Basic
PrecacheParticleSystem("mwb_muzzle_lmg_0")
PrecacheParticleSystem("mwb_muzzle_lmg_1")
PrecacheParticleSystem("mwb_muzzle_lmg_2")
PrecacheParticleSystem("mwb_muzzle_lmg_3")
PrecacheParticleSystem("mwb_muzzle_lmg_4")
PrecacheParticleSystem("mwb_muzzle_lmg_5")

--dragons breath impact
PrecacheParticleSystem("mwb_db_impact_effect")
--explosion impact
PrecacheParticleSystem("mwb_he_impact_effect")

--game.AddParticles("particles/cstm_muzzleflashes.pcf")
--game.AddParticles("particles/realistic_muzzleflashes_1.pcf")
--game.AddParticles("particles/realistic_muzzleflashes_2.pcf")
CreateConVar("mgbase_sv_pvpdamage", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "PvP damage multiplier", 0, 10)
CreateConVar("mgbase_sv_pvedamage", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "PvE damage multiplier", 0, 10)
CreateConVar("mgbase_sv_recoil", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Recoil multiplier", 0, 10)
CreateConVar("mgbase_sv_range", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Range multiplier", 0, 10)
CreateConVar("mgbase_sv_accuracy", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Accuracy multiplier", 0.01, 10)
CreateConVar("mgbase_sv_customization", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Allow gun customization.", 0, 1)
CreateConVar("mgbase_sv_customization_limit", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Attachments limit.", 0)
CreateConVar("mgbase_sv_aimassist", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Aim assist.", 0, 1)
CreateConVar("mgbase_sv_breathing", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Scope breathing.", 0, 1)
CreateConVar("mgbase_sv_full_penetration", "0", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Enables a more detailed penetration model.", 0, 1)
CreateConVar("mgbase_sv_firstdraws", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Enables first draws.", 0, 1)
CreateConVar("mgbase_sv_tacstance", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Enables Tactical Stance.", 0, 1)
CreateConVar("mgbase_sv_sprintreloads", "0", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Enables sprint reloads.", 0, 1)
CreateConVar("mgbase_sv_sprintvmanip", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Enables VManip while sprinting.", 0, 1)
CreateConVar("mgbase_debug_reverb", "0", FCVAR_REPLICATED, "Show reverb.", 0, 1)
CreateConVar("mgbase_debug_range", "0", FCVAR_REPLICATED, "Show range at hit location.", 0, 1)
CreateConVar("mgbase_debug_projectiles", "0", FCVAR_REPLICATED, "Show projectiles info.", 0, 1)
CreateConVar("mgbase_debug_mag", "0", FCVAR_REPLICATED, "Forces mag to 1.", 0, 1)

function SWEP:CanAttackInterruptReload()
    return false
end

function SWEP:MakeEnvironmentDust(radius)
    --simple func for snipers
    radius = radius || 150
    
    if (!IsValid(self:GetOwner()) || !self:GetOwner():IsOnGround()) then
        return
    end
    
    local bInWater = self:GetOwner():WaterLevel() > 0
    
    if (IsFirstTimePredicted()) then
        local data = EffectData() 
        data:SetEntity(self:GetOwner())
        data:SetScale(bInWater && radius * 0.15 || radius)
        data:SetOrigin(bInWater && self:GetOwner():EyePos() || self:GetOwner():GetPos())
         
        util.Effect(bInWater && "waterripple" || "ThumperDust", data)
    end
end 

function SWEP:PostAttachment(attachment)
    --do stuff on the gun
end

function SWEP:CreateAttachmentEntity(attachmentClass)
    if (CLIENT) then
        return
    end
    
    local att = ents.Create("mg_attachment")
    att:SetOwner(self)
    att:SetIndex(1)
    for slot, atts in pairs(self.Customization) do
        for ind, attachmentCls in pairs(atts) do
            if (attachmentClass == attachmentCls) then
                att:SetSlot(slot)
                att:SetIndex(ind)
                break
            end
        end
    end
    
    att:Spawn()
    att:SetPos(self:GetPos())
    att:SetParent(self)
    
    self:DeleteOnRemove(att)
end

function SWEP:RemoveAttachment(att)
    if (att != nil) then --it could be nil if we are customizing for the first time (just spawned)
        att:OnRemove(self)
        att = nil
    end
end

function SWEP:CreateAttachmentForUse(attachmentClass, custTable)
    custTable = custTable || self.Customization 
    
    if (MW_ATTS[attachmentClass] == nil) then
        return
    end
    
    local slot = nil
    
    for s, atts in pairs(custTable) do
        if (table.HasValue(atts, attachmentClass)) then --kinda slow whatever
            slot = s
            break
        end
    end
    
    if (slot == nil) then 
        return
    end
    
    local oldAtt = self:GetAttachmentInUseForSlot(slot)
    
    if (oldAtt != nil && oldAtt.ClassName == attachmentClass) then
        return
    end 
    
    self:RemoveAttachment(oldAtt)
    
    --reload the attachment for developer
    mw_utils.ReloadAttachment(attachmentClass)
    
    local att = table.Copy(self:GetStoredAttachment(attachmentClass))
    att.Slot = slot
    att.Index = 1
    
    for ind, attClass in pairs(custTable[slot]) do
        if (attClass == att.ClassName) then
            att.Index = ind
        end
    end
    
    self.m_CustomizationInUse[slot] = att
    att:Init(self)
    return att
end

--this is for bullets in mag
function SWEP:AttachmentFunction(funcname)
    for slot, attachment in pairs(self:GetAllAttachmentsInUse()) do
        if (attachment[funcname] && isfunction(attachment[funcname])) then
            attachment[funcname](attachment, self)
        end
    end 
end

function SWEP:Initialize() 
    if (SERVER && !IsValid(self:GetViewModel())) then
        local vm = ents.Create("mg_viewmodel") 
        vm:SetParent(self)
        vm:SetOwner(self) 
        vm:Spawn() 
        vm:SetPos(self:GetPos())
        vm:SetModel(self.VModel)
        self:DeleteOnRemove(vm)
        self:SetViewModel(vm)
    end
    
    self:SetModel(self.WorldModel)
    self.m_bInitialized = true
    self.m_hybridSwitchThreshold = 0.4
    self.m_swayLerp = 0

    -- not gonna force every creator to update
    local originalweapon = weapons.GetStored(self:GetClass())
    originalweapon.Zoom.IdleSway = originalweapon.Zoom.IdleSway or 0.1
    
    if CLIENT then
        self.Camera = {
            Shake = 0,
            Fov = 0,
            AimDelta = 0,
            AimModeDelta = 0,
            FovAdditive = 0,
            LerpReloadBlur = 0,
            LerpCustomization = 0,
            LerpBreathing = Angle(0, 0, 0),
            SprayEffect = 0,
        }
        
        self.CantedReloadDisableDelta = 1
        self.m_AimModeDeltaLerp = Vector(0, 0, 0)
        self.m_AimModeDeltaVelocity = Vector(0, 0, 0)
        self.MouseX = ScrW() * 0.5
        self.MouseY = ScrH() * 0.5
        
        self.ViewModelMouseX = ScrW() * 0.5
        self.ViewModelMouseY = ScrH() * 0.5
    end
    
    self.LastReverbState = true
    self.ValuesToRemove = {} 
    self.StatBreadcrumbs = {}
     
    self:SetFiremode(1)
    
    if (self.Customization != nil) then
        self.m_CustomizationInUse = {}
        
        --create objects
        for slot, atts in pairs(self.Customization) do
            self:CreateAttachmentForUse(atts[1])
        end

        self:BuildCustomizedGun()
    end

    self:SetClip1(self.Primary.ClipSize)
    self:SetClip2(self.Secondary.ClipSize)

    --let tasks initialize
    for _, task in pairs(self.Tasks) do
        if (task.Initialize != nil) then
            task:Initialize(self)
        end
    end
end 

local function unloadPresetFunction(weapon)
    weapon.LoadSpawnPreset = function() end
end

function SWEP:LoadSpawnPreset()
    if (!CLIENT) then
        unloadPresetFunction(self)
        return
    end
    
    --creation time check is for when we transition levels 
    if (self:GetCreationTime() < 2) then
        unloadPresetFunction(self)
        return 
    end  

    local method = math.Clamp(GetConVar("mgbase_presetspawnmethod"):GetInt(), 0, 3)
    
    if (method > 0) then
        local presets = mw_utils.GetPresetsForSWEP(self:GetClass())
        
        if (#presets > 0) then
            if (method == 1) then --random
                mw_utils.LoadPreset(self, presets[math.random(1, #presets)])
            elseif (method == 2) then --random curated
                local toRemove = {}
                
                for i, preset in pairs(presets) do
                    if (preset._bUserGenerated) then
                        table.insert(toRemove, preset)
                    end
                end
                
                for _, preset in pairs(toRemove) do
                    table.RemoveByValue(presets, preset)  
                end 
                  
                if (#presets > 0) then
                    mw_utils.LoadPreset(self, presets[math.random(1, #presets)])
                end
            elseif (method == 3) then --random fav
                local toRemove = {}
                
                for i, preset in pairs(presets) do
                    if (!mw_utils.IsAssetFavorite(self:GetClass(), preset.ClassName)) then
                        table.insert(toRemove, preset)
                    end
                end
                
                for _, preset in pairs(toRemove) do
                    table.RemoveByValue(presets, preset) 
                end
                
                if (#presets > 0) then
                    mw_utils.LoadPreset(self, presets[math.random(1, #presets)])
                end
            end
        end
    end
    
    unloadPresetFunction(self)
end

function SWEP:PrimaryAttack()
end

function SWEP:SecondaryAttack()
end

function SWEP:OnDrop()
    self:AddFlag("PlayFirstDraw")
end

function SWEP:GetCurrentHoldType()
    if (self:HasFlag("BipodDeployed")) then
        return "Bipod"
    end  

    return self.HoldType 
end 

function SWEP:Deploy()
    self:GetOwner():SetSaveValue("m_flNextAttack", 0) --makes think tick instantly thanks chen
    self:SetButtons(0)
    self:SetButtonPressTime(0)

    --deploy resets task state, this shouldnt be done normally
    local currentTask = self.Tasks[self:GetCurrentTask()]

    if (currentTask != nil && currentTask.Flag != nil) then  
        self:RemoveFlag(currentTask.Flag)
    end

    self:SetCurrentTask(0) 
    self:TrySetTask("Deploy")
    self:RemoveFlag("OnLadder")

    return true
end 

function SWEP:Reload()
    if (self:HasFlag("UsingUnderbarrel")) then
        self:TrySetTask("UnderbarrelReload")
    else
        self:TrySetTask("Reload")
    end
end

function SWEP:UnderbarrelAttack()
    self:TrySetTask("UnderbarrelPrimaryFire")
end

function SWEP:Holster(weapon)
    if (IsValid(weapon) && weapon != self && weapon != self:GetOwner()) then
        if (self:HasFlag("Drawing")) then
            return true
        end

        self:SetNextWeapon(weapon)
    else
        self:SetNextWeapon(NULL)
    end

    self:TrySetTask("Holster")
    
    return self:HasFlag("CanSwitch") || !IsValid(weapon) || weapon == self
end

function SWEP:PreAttachments()
    --do stuff
end

local function removeChildren(ent)
    for _, c in pairs(ent:GetChildren()) do
        removeChildren(c)
    end
    
    ent:Remove()
end

function SWEP:OnRemove()
    if (CLIENT) then
        for _, att in pairs(self:GetAllAttachmentsInUse()) do
            if (att.OnRemove) then
                att:OnRemove(self)
            end
        end
    end
    
    for _, c in pairs(self:GetChildren()) do
        removeChildren(c)
    end
end

function SWEP:GetPrimaryDelay()
    return 60 / self.Primary.RPM
end

function SWEP:GetTranslatedAnimIndex(seqIndex)
    if (self:HasFlag("UsingUnderbarrel") && self.Secondary != nil && self.Secondary.TranslateAnimations != nil) then
        return self.Secondary.TranslateAnimations[seqIndex] || seqIndex
    end

    return seqIndex
end

function SWEP:PlayViewModelAnimation(seqIndex)
    if (self:GetTranslatedAnimIndex(seqIndex) == seqIndex) then
        self:RemoveFlag("UsingUnderbarrel")
    end

    if (!IsFirstTimePredicted() && !game.SinglePlayer()) then
        return 
    end
	
    self:GetViewModel():PlayAnimation(self:GetTranslatedAnimIndex(seqIndex))
end
 
function SWEP:PlayUnderbarrelAnimation(seqIndex)
    self:PlayViewModelAnimation(seqIndex)
    self:AddFlag("UsingUnderbarrel")
end

function SWEP:GetAnimLength(seqIndex, length)
    seqIndex = self:GetTranslatedAnimIndex(seqIndex)
    local seq = self:GetAnimation(seqIndex)
    if !seq then
        error(seqIndex.." does not exist on the weapon's animation list!")
        return
    end
    
    length = length || seq.Length
    
    local pb = seq.Fps / 30
    return length / pb
end

function SWEP:GetAnimation(seqIndex)
    seqIndex = self:GetTranslatedAnimIndex(seqIndex)

    local foundSequence
    for index, seq in pairs(self.Animations) do
        if (string.lower(index) == string.lower(seqIndex)) then
            foundSequence = seq
            break
        end
    end

    -- Merge base animation
    if foundSequence && foundSequence.Base then
        local baseAnim = self.Animations[foundSequence.Base]
        local newAnim = table.Copy(baseAnim)
        for _index, _value in pairs(foundSequence) do
            newAnim[_index] = _value
        end

        return newAnim
    end

    return foundSequence
end

function SWEP:PlayerGesture(slot, anim)
    if (CLIENT && IsFirstTimePredicted()) then 
        self:GetOwner():AnimRestartGesture(slot, anim, true)
    end
    
    if SERVER then
        net.Start("mgbase_tpanim", true)
        net.WriteUInt(slot, 2)
        net.WriteInt(anim, 12)
        net.WriteEntity(self:GetOwner())
        if (game.SinglePlayer()) then
            net.Send(self:GetOwner())
        else
            net.SendOmit(self:GetOwner())
        end
    end
end

function SWEP:OnReloaded()
    if (self.Customization != nil) then
        self:BuildCustomizedGun()
    else
        if (self.Firemodes != nil) then
            self:ApplyFiremode(self:GetFiremode())
        end
    end
    
    --self:SetAimMode(1)
end

function SWEP:OnRestore()
    self:Deploy()
end

function SWEP:DeepObjectCopy(original, holder)
    for index, value in pairs(original) do
        if istable(value) then
            if !holder[index] then
                holder[index] = {}
            end
            
            self:DeepObjectCopy(value, holder[index])
        elseif isvector(value) then
            holder[index] = Vector(0, 0, 0)
            holder[index]:Set(value)
        elseif (isangle(value)) then
            holder[index] = Angle(0, 0, 0)
            holder[index].p = value.p
            holder[index].y = value.y
            holder[index].r = value.r
        else
            if index == "LoadSpawnPreset" then
                continue
            end

            holder[index] = value
        end
    end
end 

function SWEP:GetIdleAnimation()
    if (self:HasFlag("UsingUnderbarrel")) then
        return "Underbarrel_Idle"
    end

    return "Idle"
end

--meme marine
local LastHoldType = nil

function SWEP:SetShouldHoldType(force)
    if (!IsValid(self:GetOwner())) then
        return
    end
    
    local ht = "Idle"
    if (self:GetAimDelta() > 0) then
        ht = "Aim"
    elseif (self:HasFlag("Sprinting") || self:HasFlag("Holstering") || self:HasFlag("Lowered")) then
        ht = "Down"
    end
    
    local fullht = "fist"
    
    local crouching = self:GetOwner():IsFlagSet(4)
    -- self:SetHoldType(crouching && self.HoldTypes[self:GetCurrentHoldType()][ht].Crouching || self.HoldTypes[self:GetCurrentHoldType()][ht].Standing)
    
    if crouching then
        fullht = self.HoldTypes[self:GetCurrentHoldType()][ht].Crouching
    else
        fullht = self.HoldTypes[self:GetCurrentHoldType()][ht].Standing
    end
    
    if LastHoldType != fullht || force then
        self:SetHoldType(fullht)
    end
    
    LastHoldType = fullht
end

--ttt support

SWEP.IsSuppresed = false
SWEP.IsEquipment = false

function SWEP:GetHeadshotMultiplier()
    return 2
end

function SWEP:DampenDrop()
    -- For some reason gmod drops guns on death at a speed of 400 units, which
    -- catapults them away from the body. Here we want people to actually be able
    -- to find a given corpse's weapon, so we override the velocity here and call
    -- this when dropping guns on death.
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetVelocityInstantaneous(Vector(0,0,-75) + phys:GetVelocity() * 0.001)
        phys:AddAngleVelocity(phys:GetAngleVelocity() * -0.99)
    end
end

function SWEP:IsEquipment()
    return self.IsEquipment
end

function SWEP:SetPoseParameters(vm) 
    return
end