AddCSLuaFile()

if not Glide then return end

ENT.GlideCategory = "Neekosharediw9"

ENT.Type = "anim"
ENT.Base = "base_glide_heli"
ENT.PrintName = "Vulture"
ENT.Author = "Neeko"

ENT.MainRotorOffset = Vector( 0, 0, 110 )
ENT.TailRotorOffset = Vector( -424, -26, 115 )
ENT.TailRotorAngle =  Angle( 0, 0, -22 )

function ENT:GetPlayerSitSequence( seatIndex )
    return seatIndex >= 9 and "idle_melee_angry" or ( seatIndex > 1 and "sit" or "sit" )
end

if CLIENT then
    ENT.CameraOffset = Vector( -800, 0, 160 )

    ENT.StartSound = "neek0/iw9/veh/shared/palfa_startup.wav"

    -- Play this sound at the tail rotor
    ENT.TailSoundPath = "neek0/iw9/veh/shared/veh9_mil_air_heli_medium_tail_rotor_high_v0.wav"
    ENT.TailSoundLevel = 75
    ENT.TailSoundVolume = 0.3

    -- Play this sound at the engine
    ENT.EngineSoundPath = "neek0/iw9/veh/shared/apache_turbine_cls_lp.wav"
    ENT.EngineSoundLevel = 90
    ENT.EngineSoundVolume = 5

    -- Play this sound at the engine too
    ENT.JetSoundPath = "neek0/iw9/veh/shared/apache_base_moving_lp.wav"
    ENT.JetSoundLevel = 105
    ENT.JetSoundVolume = 1

    -- Play this sound that can be heard from far away
    ENT.DistantSoundPath = "neek0/iw9/veh/shared/veh9_mil_air_heli_blima_plunder_distant_lp.wav"

    -- Delay between each rotor "beat"
    ENT.RotorBeatInterval = 0.09

    -- Rotor beat sound sets (See lua/glide/sh_soundsets.lua)
    ENT.BassSoundSet = "Glide.GenericRotor.Bass"
    ENT.MidSoundSet = "Glide.GenericRotor.Mid"
    ENT.HighSoundSet = "Glide.GenericRotor.High"

    ENT.BassSoundVol = 0.2
    ENT.MidSoundVol = 0
    ENT.HighSoundVol = 0
    
    ENT.EngineFailSound = "glide/ui/stall_beep.wav"
    ENT.EngineFailVolume = 1.

    ENT.ExhaustPositions = {
        Vector( -112, -45, 55 ),
        Vector( -112, 45, 55  )
    }

    ENT.EngineFireOffsets = {
        { offset = Vector( -112, -45, 55 ), angle = Angle( 300, 0, 0 ), scale = 1.5 },
        { offset = Vector( -112, 45, 55 ), angle = Angle( 300, 0, 0 ), scale = 1.5 }
    }
    
    ENT.StrobeLights = {
        { offset = Vector( 104,64,-25 ), blinkTime = 0, blinkDuration = 1 },
        { offset = Vector( 104,-64,-25 ), blinkTime = 0, blinkDuration = 1 },
        { offset = Vector( -422,0,126 ), blinkTime = 0.9 },
        { offset = Vector(-210,0,-21), blinkTime = 0.6 },
        { offset = Vector(-62,0,91), blinkTime = 0.7 },
        { offset = Vector( 3, -2, 40 ), blinkTime = 0, blinkDuration = 1 }
    }

    ENT.StrobeLightSpriteSize = 32

    ENT.StrobeLightColors = {
        Color( 255, 51, 51 ),
        Color( 0, 255, 47),
        Color( 255, 51, 51),
        Color( 190, 228, 255 ),
        Color( 255, 51, 51 ),
        Color( 185, 241, 255)
    }

    function ENT:AllowFirstPersonMuffledSound( seatIndex )
        return seatIndex < 3
    end

    local POSE_DATA = {
        ["ValveBiped.Bip01_R_UpperArm"] = Angle( 0, -70, 35 ),
        ["ValveBiped.Bip01_R_Forearm"] = Angle(  0, 45, 0 ),
    }

    local POSE_DATA2 = {
        ["ValveBiped.Bip01_R_UpperArm"] = Angle( -20, 20, 0 ),
        ["ValveBiped.Bip01_R_Forearm"] = Angle( -20, 100, 0 ),

        ["ValveBiped.Bip01_L_UpperArm"] = Angle( -30, -30, -40 ),
        ["ValveBiped.Bip01_L_Forearm"] = Angle( -26, -59, 0 ),
    }

    local POSE_DATA3 = {
        ["ValveBiped.Bip01_L_UpperArm"] = Angle( 0, 10, 0 ),
        ["ValveBiped.Bip01_L_Forearm"] = Angle( 0, 0, 0 ),

        ["ValveBiped.Bip01_R_UpperArm"] = Angle( 0,-25, 0 ),
        ["ValveBiped.Bip01_R_Forearm"] = Angle(-15, 30, 20 ),
        ["ValveBiped.Bip01_R_Hand"] = Angle( -40, -35, 100 ),

        ["ValveBiped.Bip01_L_UpperArm"] = Angle( -10, 5, -25 ),
        ["ValveBiped.Bip01_L_Forearm"] = Angle(10, 45, -0 ),
        ["ValveBiped.Bip01_L_Hand"] = Angle( -20, -60, -110 ),

        ["ValveBiped.Bip01_L_Thigh"] = Angle( -5, 0, 10 ),
        ["ValveBiped.Bip01_L_Calf"] = Angle( 10, -5, 10  ),
        ["ValveBiped.Bip01_L_Foot"] = Angle( 5, -40, 0 ),

        ["ValveBiped.Bip01_R_Thigh"] = Angle( 10, 0, -10 ),
        ["ValveBiped.Bip01_R_Calf"] = Angle( -10, -5, -10 ),
        ["ValveBiped.Bip01_R_Foot"] = Angle( -20, -40, 0 ),

    }

    function ENT:GetSeatBoneManipulations( seatIndex )
        if seatIndex == 1 or seatIndex == 2 then
            return POSE_DATA3
        elseif seatIndex == 9 then
            return POSE_DATA
        elseif seatIndex == 10 then
            return POSE_DATA2
        end
    end
end

if SERVER then
    ENT.SpawnPositionOffset = Vector( 0, 0, 30 )
    ENT.ChassisMass = 1700
    ENT.ChassisModel = "models/iw9/veh/vulture/chassis.mdl"
    ENT.HasLandingGear = false

    ENT.BulletDamageMultiplier = 0.3

    ENT.MainRotorRadius = 320
    ENT.TailRotorRadius = 60

    ENT.MainRotorModel = "models/iw9/veh/vulture/rotor.mdl"
    ENT.MainRotorFastModel = "models/iw9/veh/vulture/rotorblur.mdl"

    ENT.TailRotorModel = "models/iw9/veh/vulture/rearrotor.mdl"
    ENT.TailRotorFastModel = "models/iw9/veh/vulture/rearrotorblur.mdl"

    ENT.SoftCollisionSound = "iw9.aircraft.impact.light"
    ENT.HardCollisionSound = "iw9.aircraft.impact.heavy"

    ENT.CountermeasureCount = 2

    ENT.ExplosionGibs = {
        "models/iw9/veh/vulture/gib/body.mdl",
        "models/iw9/veh/vulture/gib/tailgib.mdl",
        "models/iw9/veh/vulture/gib/tailrgib.mdl",
        "models/iw9/veh/vulture/gib/rotorgib1.mdl",
        "models/iw9/veh/vulture/gib/rotorgib2.mdl",
        "models/iw9/veh/vulture/gib/door.mdl",
        "models/combine_apc_destroyed_gib03.mdl",
        "models/combine_apc_destroyed_gib03.mdl",
        "models/combine_apc_destroyed_gib04.mdl",
        "models/combine_apc_destroyed_gib04.mdl",
        "models/combine_apc_destroyed_gib05.mdl",
        "models/combine_apc_destroyed_gib05.mdl",
        "models/iw9/veh/vulture/gib/gearlgib.mdl",
        "models/iw9/veh/vulture/gib/gearrgib.mdl"
    }

    ENT.SpotlightOffset = Vector( 197,0,-33 )

    DEFINE_BASECLASS( "base_glide_heli" )

    local IsValid = IsValid

    ENT.AngularDrag = Vector( -30, -30, -35 )

    ENT.HelicopterParams = {
        pitchForce = 1700,
        turbulanceForce = 150, 
        yawForce = 2000,
        rollForce = 1500,

        maxPitch = 40,
        maxRoll = 55   
    }

    function ENT:GetSpawnColor()
        return Color( 255, 255, 255)
    end    

    function ENT:CreateFeatures()
        self.doorAnimEndTime = 0
        self.doorsOpen = false
        self.prevMouse2 = false
 
        self:SetBodygroup(0,math.random(0, 5))
        self:SetBodygroup(1,math.random(0, 1))	
        self:SetBodygroup(2,math.random(0, 1))
        self:SetBodygroup(3,math.random(0, 1))

        self:CreateSeat( Vector( 112, 27, -8 ), nil, Vector( 140, 100, 0 ), true )
        self:CreateSeat( Vector( 112, -27, -8 ), nil, Vector( 140, -100, 0 ), true )

        self:CreateSeat( Vector( 56, -26, -18 ), Angle( 0, 0, 0 ), Vector( 20, -90, 0 ), true )
        self:CreateSeat( Vector( 56, 26, -18 ), Angle( 0, 180, 0 ), Vector( 20, 90, 0 ), true )

        self:CreateSeat( Vector( -51, -26, -18), Angle( 0, 0, 0 ), Vector( -30, -90, 0 ), true )
        self:CreateSeat( Vector( -82, -26, -18), Angle( 0, 0, 0 ), Vector( -30, -90, 0 ), true )

        self:CreateSeat( Vector( -82, 26, -18), Angle( 0, 180, 0 ), Vector( -30, 90, 0 ), true )
        self:CreateSeat( Vector( -51, 26, -18), Angle( 0, 180, 0 ), Vector( -30, 90, 0 ), true )

        self:CreateSeat( Vector( 30, 29, -32), Angle( 0, 40, 0 ), Vector( 20, 90, 0 ), true )
        self:CreateSeat( Vector( 30, -29, -32), Angle( 0, 160, 0 ),Vector( 20, -90, 0 ), true )

        -- Wheels for the landing gear
        local wheelParams = { suspensionLength = 12 }

        self:CreateWheel( Vector( 54, 53, -36 ), wheelParams  )
        self:CreateWheel( Vector( 54, -53, -36 ), wheelParams  )
        self:CreateWheel( Vector( -261, 0, -29 ), wheelParams  )
        self:ChangeWheelRadius( 15 )

        self.isSpotlightOn = false
        self.keyToggle = false

        for _, w in ipairs( self.wheels ) do
            w:SetNoDraw( true )
            w.brake = 0.8
        end
    end

    function ENT:TurnOnSpotlight()
        self.isSpotlightOn = true

    if not IsValid(self.envSpotlight) then
        local beam = ents.Create("point_spotlight")
        if IsValid(beam) then
            beam:SetPos(self:LocalToWorld(self.SpotlightOffset))
            beam:SetAngles(self:GetAngles())
            beam:SetKeyValue("spotlightlength", "2000")
            beam:SetKeyValue("SpotlightWidth", "1024")
            beam:SetKeyValue("rendercolor", "170 217 217")
            beam:SetKeyValue("renderamt", "255")
            beam:SetKeyValue("fadespeed", "15")
            beam:SetKeyValue("fademaxdist", "4096")
            beam:SetKeyValue("HDRColorScale", "1.0")
            beam:SetKeyValue("spawnflags", "1") -- Start on
            beam:SetParent(self)
            beam:Spawn()
            beam:Activate()
            self.envSpotlight = beam
            self:DeleteOnRemove(beam)
        end
    end

    if not IsValid(self.lightProj) then
        local proj = ents.Create("env_projectedtexture")
        if IsValid(proj) then
            proj:SetParent(self)
            proj:SetLocalPos(self.SpotlightOffset)
            proj:SetKeyValue("enableshadows", 0)
            proj:SetKeyValue("LightWorld", 1)
            proj:SetKeyValue("LightStrength", 24)
            proj:SetKeyValue("farz", 8096)
            proj:SetKeyValue("nearz", 2)
            proj:SetKeyValue("lightfov", 25)
            proj:SetKeyValue("lightcolor", "170 217 217")
            proj:Spawn()
            proj:Input("SpotlightTexture", NULL, NULL, "effects/flashlight001")
            self.lightProj = proj
            self:DeleteOnRemove(proj)
        end
    end
end

function ENT:TurnOffSpotlight()
    self.isSpotlightOn = false

    if IsValid(self.envSpotlight) then
        self.envSpotlight:Remove()
        self.envSpotlight = nil
    end

    if IsValid(self.lightProj) then
        self.lightProj:Remove()
        self.lightProj = nil
    end
end

function ENT:Think()
    BaseClass.Think(self)

    local driver = self:GetDriver()
    local keyToggle = false
    local mouse2Down = false 

    if IsValid(driver) then
        keyToggle = driver:KeyDown(IN_ATTACK)
        mouse2Down = driver:KeyDown(IN_ATTACK2)

    if IsValid(self.lightProj) and IsValid(driver) then
        self.lightProj:SetAngles(driver:GlideGetCameraAngles())
    end

    if IsValid(self.envSpotlight) and IsValid(driver) then
       self.envSpotlight:SetAngles(driver:GlideGetCameraAngles())
    end
end

    if self.keyToggle ~= keyToggle then
        self.keyToggle = keyToggle
        if keyToggle then
            if self.isSpotlightOn then
                self:TurnOffSpotlight()
            else
                self:TurnOnSpotlight()
            end
        end
    end

    if not self.prevMouse2 and mouse2Down then
        if CurTime() >= (self.doorAnimEndTime or 0) then
            self.doorsOpen = not self.doorsOpen
            if self.doorsOpen then
                self:OpenDoors()
            else
                self:CloseDoors()
            end
        end
    end

    self.prevMouse2 = mouse2Down
    return true
end

function ENT:FireCountermeasures()
    -- Prevent spam if still cooling down
    local t = CurTime()
    if t < (self.countermeasureCD or 0) then
        self:EmitSound("glide/weapons/flare_reloading.wav", 85, 100, 1.0, 6, 0, 0)
        return
    end

    local count = self.CountermeasureCount
    self.countermeasureCD = t + self.CountermeasureCooldown
    Glide.PlaySoundSet("iw9.Flares.Deploy", self, 1.0)

    -- Spawn 5 bursts
    for burst = 0, 4 do
        timer.Simple(burst * 0.15, function()
            if not IsValid(self) then return end

            local mins = self:OBBMins()
            local startPos = self:LocalToWorld(Vector(0, 0, mins[3] * 0.5))

            local cone = math.random(120, 180)
            local step = cone / count
            local ang = Angle(0, 180 - (step * 0.5) - (cone * 0.5), 0)
            local vel = self:GetVelocity()

            for _ = 1, count do
                ang[2] = ang[2] + step

                local flare = ents.Create("glide_flare")
                if not IsValid(flare) then continue end

                flare:SetPos(startPos)
                flare:SetAngles(self:LocalToWorldAngles(ang))
                flare:SetOwner(self)
                flare:Spawn()

                local phys = flare:GetPhysicsObject()
                if IsValid(phys) then
                    phys:SetVelocityInstantaneous(vel + flare:GetForward() * math.random(800, 1500))
                end
            end
        end)
    end
end

function ENT:OpenDoors()
    local seq = self:LookupSequence("open_door")
    if seq and seq >= 0 then
        self:ResetSequence(seq)
        local duration = self:SequenceDuration(seq)
        self.doorAnimEndTime = CurTime() + duration
    end
    self:EmitSound("neek0/iw9/veh/helo/sas1_veh1_door_ster_pan.wav", 75, 100, 1, CHAN_AUTO)
end

function ENT:CloseDoors()
    local seq = self:LookupSequence("close_door")
    if seq and seq >= 0 then
        self:ResetSequence(seq)
        local duration = self:SequenceDuration(seq)
        self.doorAnimEndTime = CurTime() + duration
    end
    self:EmitSound("neek0/iw9/veh/helo/sas1_veh1_door_ster_pan2.wav", 75, 100, 1, CHAN_AUTO)
   end
end
