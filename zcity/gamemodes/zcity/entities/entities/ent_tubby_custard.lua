AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Tubby Custard"
ENT.Author = "Tubbycity"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.Category = "Tubbycity"

ENT.Model = "models/custard/custard.mdl"

function ENT:Initialize()
	if SERVER then
		self:SetModel(self.Model)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(false)
		end
	end
end

function ENT:Use(activator, caller)
	if not SERVER then return end
	if not IsValid(activator) or not activator:IsPlayer() then return end
	if not activator:Alive() then return end
	if activator:Team() == TEAM_SPECTATOR then return end

	-- Only survivors collect (not enemy/infected teams)
	if activator:Team() == 1 or activator:Team() == 2 then return end

	local mode = zb.modes and zb.modes[zb.CROUND or ""]
	if mode and mode.OnCustardCollected then
		mode:OnCustardCollected(activator, self)
	end

	self:EmitSound("items/ammo_pickup.wav")
	self:Remove()
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()

		local dlight = DynamicLight(self:EntIndex())
		if dlight then
			dlight.pos = self:GetPos() + Vector(0, 0, 8)
			dlight.r = 255
			dlight.g = 200
			dlight.b = 50
			dlight.brightness = 1
			dlight.Decay = 500
			dlight.Size = 64
			dlight.DieTime = CurTime() + 0.1
		end
	end
end
