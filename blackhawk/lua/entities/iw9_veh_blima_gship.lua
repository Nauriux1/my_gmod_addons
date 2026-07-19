AddCSLuaFile()

if not Glide then return end

ENT.GlideCategory = "Neekosharediw9"

ENT.Type = "anim"
ENT.Base = "glide_gtav_armed_heli"
ENT.PrintName = "Vulture Gunship"
ENT.Author = "Neeko"

ENT.MainRotorOffset = Vector( 0, 0, 110 )
ENT.TailRotorOffset = Vector( -424, -26, 115 )
ENT.TailRotorAngle =  Angle( 0, 0, -22 )

function ENT:GetPlayerSitSequence( seatIndex )
    return (seatIndex == 3 or seatIndex == 4) and "cidle_rpg" or ( seatIndex > 1 and "sit" or "sit" )
end

DEFINE_BASECLASS( "glide_gtav_armed_heli" )

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

    ENT.WeaponInfo = {
        { name = "#glide.weapons.barrage_missiles", icon = "glide/icons/rocket.png" }
    }    

    ENT.CrosshairInfo = {
        { iconType = "square", traceOrigin = Vector( 0, 0, -15 ) }
    }

    local POSE_DATA2 = {
        ["ValveBiped.Bip01_Spine"] = Angle( 0, 10, 0 ),

        ["ValveBiped.Bip01_R_UpperArm"] = Angle( 0, 0, 0 ),
        ["ValveBiped.Bip01_R_Forearm"] = Angle( 0, 0, 0 ),
        ["ValveBiped.Bip01_R_Hand"] = Angle( 0, 0, 0 ),

        ["ValveBiped.Bip01_L_UpperArm"] = Angle( 0, 0, 0 ),
        ["ValveBiped.Bip01_L_Forearm"] = Angle( 0, 0, 0 ),
        ["ValveBiped.Bip01_L_Hand"] = Angle( 0, 0, 0 ),

        ["ValveBiped.Bip01_L_Thigh"] = Angle( 0, 0, 0 ),
        ["ValveBiped.Bip01_L_Calf"] = Angle( 0, 0, 0  ),
        ["ValveBiped.Bip01_L_Foot"] = Angle( 0, 0, 0 ),

        ["ValveBiped.Bip01_R_Thigh"] = Angle( 0, 0, 0 ),
        ["ValveBiped.Bip01_R_Calf"] = Angle( 0, 0, 0 ),
        ["ValveBiped.Bip01_R_Foot"] = Angle( 0, 0, 0 ),

    }

    local POSE_DATA1 = {
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
            return POSE_DATA1
        elseif seatIndex == 3 or seatIndex == 4 then
            return POSE_DATA2
        end
    end

    function ENT:AllowFirstPersonMuffledSound( seatIndex )
        return seatIndex == 2
    end

    function ENT:OnLocalPlayerEnter( seatIndex )
        self:DisableCrosshair()
        self.isUsingTurret = false

        if seatIndex == 2 or seatIndex == 3 or seatIndex == 4 then
            self:EnableCrosshair( {
                iconType = "dot",
                color = Color( 0, 255, 0 )
            } )

            self.isUsingTurret = true
        else
            BaseClass.OnLocalPlayerEnter( self, seatIndex )
        end
    end

    function ENT:OnLocalPlayerExit()
        self:DisableCrosshair()
        self.isUsingTurret = false
    end

    function ENT:UpdateCrosshairPosition()
        if self.isUsingTurret then
            self.crosshair.origin = Glide.GetCameraAimPos()
        else
            BaseClass.UpdateCrosshairPosition( self )
        end
    end

    local CAMERA_TYPE = Glide.CAMERA_TYPE

    function ENT:GetCameraType( seatIndex )
        return seatIndex > 1 and CAMERA_TYPE.TURRET or CAMERA_TYPE.AIRCRAFT
    end

    function ENT:GetFirstPersonOffset( seatIndex, localEyePos )
        if seatIndex == 2 then
            return Vector( 205, 0, -25 )
        end

        if seatIndex == 3 then
            return Vector( 25, 60, 35 )
        end

        if seatIndex == 4 then
            return Vector( 23, -60, 35 )
        end

        return BaseClass.GetFirstPersonOffset( self, seatIndex, localEyePos )
    end

end

if SERVER then
    ENT.SpawnPositionOffset = Vector( 0, 0, 30 )
    ENT.ChassisMass = 1700
    ENT.ChassisModel = "models/iw9/veh/vulturegunship/chassis.mdl"
    ENT.HasLandingGear = false

    ENT.BulletDamageMultiplier = 0.24

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

    ENT.AngularDrag = Vector( -30, -30, -35 )

    ENT.HelicopterParams = {
        pitchForce = 1700,
        turbulanceForce = 125, 
        yawForce = 2000,
        rollForce = 1500,

        maxPitch = 40,
        maxRoll = 55   
    }

    ENT.MissileOffsets = {
        Vector( -50, 85, -35 ),
        Vector( -50, -85, -35 )
    }

    function ENT:GetSpawnColor()
        return Color( 255, 255, 255)
    end    

    function ENT:CreateFeatures()

        self:CreateWeapon( "missile_launcher", {
              MaxAmmo = 14,
              AmmoType = "barrage",
              AmmoTypeShareCapacity = true,
              FireDelay = 0.2,
              ReloadDelay = 12,
              ProjectileOffsets = MissileOffsets
        } )
 
        self:SetBodygroup(0,math.random(0, 5))
        self:SetBodygroup(1,math.random(0, 1))	
        self:SetBodygroup(2,math.random(0, 1))
        self:SetBodygroup(3,math.random(0, 1))

        self:CreateSeat( Vector( 112, 27, -8 ), nil, Vector( 140, 100, 0 ), true )
        self:CreateSeat( Vector( 112, -27, -8 ), nil, Vector( 140, -100, 0 ), true )

        self:CreateSeat( Vector( 19, 50, -31 ), Angle( 0, 0, 0 ), Vector( -10, 110, 0 ), true )
        self:CreateSeat( Vector( 23, -50, -31), Angle( 0, 180, 0 ), Vector( -10, -110, 0 ), true )

        self:CreateSeat( Vector( 56, -26, -18 ), Angle( 0, 0, 0 ), Vector(-10, -110, 0 ), true )
        self:CreateSeat( Vector( 56, 26, -18 ), Angle( 0, 180, 0 ), Vector( 10, 110, 0 ), true )

        self:CreateSeat( Vector( -82, -26, -18), Angle( 0, 0, 0 ), Vector( -30, -110, 0 ), true )
        self:CreateSeat( Vector( -82, 26, -18), Angle( 0, 180, 0 ), Vector( -30, 110, 0 ), true )

        self.turret = Glide.CreateTurret( self, Vector( 188, 0, -12 ), Angle() )
        self.turret:SetModel( "models/iw9/veh/vulturegunship/turretbase.mdl" )
        self.turret:SetBodyModel( "models/iw9/veh/vulturegunship/turret.mdl", Vector( 0, 0, -18) )
        self.turret:SetMinYaw( -120 )
        self.turret:SetMaxYaw( 120 )
        self.turret:SetMinPitch( -20 )
        self.turret:SetMaxPitch( 90 )
        self.turret:SetFireDelay( 0.08 )
        self.turret:SetBulletOffset( Vector( 50, 0, 0 ) )
        
        self.turret:SetSingleShotSound( "iw9.fire.kilo121" )
        self.turret:SetShootLoopSound( "" )
        self.turret:SetShootStopSound( "" )

        self.leftTurret = Glide.CreateTurret( self, Vector( 20, 79.5, -5 ), Angle() )
        self.leftTurret:SetModel( "models/iw9/veh/vulturegunship/sidegunbase.mdl" )
        self.leftTurret:SetBodyModel( "models/iw9/veh/vulturegunship/sidegun.mdl", Vector( 3, 8.5, 13.5 ) )
        self.leftTurret:SetMinYaw( 0 )
        self.leftTurret:SetMaxYaw( 180 )
        self.leftTurret:SetMinPitch( -190 )
        self.leftTurret:SetMaxPitch( 40 )
        self.leftTurret:SetBulletOffset( Vector( 25, 0, -2) )

        self.leftTurret:SetSingleShotSound( "iw9.fire.kilo121" )
        self.leftTurret:SetShootLoopSound( "iw9.spinloop.kilo121" )
        self.leftTurret:SetShootStopSound( "iw9.spindown.kilo121" )

        self.rightTurret = Glide.CreateTurret( self, Vector( 20, -79.5, -5 ), Angle() )
        self.rightTurret:SetModel( "models/iw9/veh/vulturegunship/sidegunbase.mdl" )
        self.rightTurret:SetBodyModel( "models/iw9/veh/vulturegunship/sidegun.mdl", Vector( 3, 1.5, 13.5  ) )
        self.rightTurret:SetMinYaw( -180 )
        self.rightTurret:SetMaxYaw( 0 )
        self.rightTurret:SetMinPitch( -20 )
        self.rightTurret:SetMaxPitch( 90 )
        self.rightTurret:SetBulletOffset( Vector( 25, 0, -2 ) )

        self.rightTurret:SetSingleShotSound( "iw9.fire.kilo121" )
        self.rightTurret:SetShootLoopSound( "iw9.spinloop.kilo121" )
        self.rightTurret:SetShootStopSound( "iw9.spindown.kilo121" )

        self:SetupTurretBarrel( self.leftTurret )
        self:SetupTurretBarrel( self.rightTurret )

        -- Wheels for the landing gear
        local wheelParams = { suspensionLength = 12 }

        self:CreateWheel( Vector( 54, 53, -36 ), wheelParams  )
        self:CreateWheel( Vector( 54, -53, -36 ), wheelParams  )
        self:CreateWheel( Vector( -261, 0, -29 ), wheelParams  )
        self:ChangeWheelRadius( 15 )

        for _, w in ipairs( self.wheels ) do
            w:SetNoDraw( true )
            w.brake = 0.8
        end
    end

    function ENT:SetupTurretBarrel( turret )
        turret.spinAngle = Angle()
        turret.spinSpeed = 0

        turret.barrel = ents.Create( "prop_dynamic_override" )
        turret.barrel:SetModel( "models/iw9/veh/vulturegunship/sidegunbarrel.mdl" )
        turret.barrel:SetParent( turret:GetGunBody() )
        turret.barrel:SetLocalPos( Vector( 10, -0.5, -2 ) )
        turret.barrel:SetLocalAngles( Angle() )
        turret.barrel:Spawn()
        turret.barrel:DrawShadow( false )

        turret:DeleteOnRemove( turret.barrel )
    end

    local FrameTime = FrameTime

    function ENT:UpdateTurretBarrel( turret )
        local dt = FrameTime()

        turret.spinSpeed = Lerp( dt * 2.5, turret.spinSpeed, turret:GetIsFiring() and 4200 or 0 )
        turret.spinAngle[3] = ( turret.spinAngle[3] + dt * turret.spinSpeed ) % 360
        turret.barrel:SetLocalAngles( turret.spinAngle )
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

    function ENT:Think()
        BaseClass.Think( self )

        self.turret:UpdateUser( self:GetSeatDriver( 2 ) )

        self:UpdateTurretBarrel( self.leftTurret )
        self:UpdateTurretBarrel( self.rightTurret )

        self.leftTurret:UpdateUser( self:GetSeatDriver( 3 ) )
        self.rightTurret:UpdateUser( self:GetSeatDriver( 4 ) )

        return true
    end
end