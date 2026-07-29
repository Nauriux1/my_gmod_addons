AddCSLuaFile()
module("mw_springs", package.seeall)

function Create(params)
    if (params.Damping == nil || params.Elasticity == nil) then
        return --return blank object to avoid checking for nils later
        {
            Decay = function() end,
            Get = function() return 0 end,
            Input = function() end
        }
    end

    local spring = {
        m_velocity = 0,
        m_value = 0,
        m_prevValue = 0,
        m_target = 0,
        Elasticity = math.abs(params.Elasticity),
        Damping = math.abs(params.Damping),
        Random = params.Random || 0
    }

    function spring:GetAcceleration(val, vel, target)
        local springForce = -self.Elasticity * (val - target)
        local dampingForce = -self.Damping * vel
        return springForce + dampingForce
    end

    function spring:Step(val, vel, target, frametime)
        local k1v = frametime * self:GetAcceleration(val, vel, target)
        local k1p = frametime * vel
        local k2v = frametime * self:GetAcceleration(val + 0.5 * k1p, vel + 0.5 * k1v, target)
        local k2p = frametime * (vel + 0.5 * k1v)
        local k3v = frametime * self:GetAcceleration(val + 0.5 * k2p, vel + 0.5 * k2v, target)
        local k3p = frametime * (vel + 0.5 * k2v)
        local k4v = frametime * self:GetAcceleration(val + k3p, vel + k3v, target)
        local k4p = frametime * (vel + k3v)
        
        local newVel = vel + (k1v + 2 * k2v + 2 * k3v + k4v) / 6
        local newVal = val + (k1p + 2 * k2p + 2 * k3p + k4p) / 6
         
        return newVal, newVel
    end

    --[[function spring:Decay(frametime) 
        local force = self.Elasticity * (self.m_target - self.m_value)
        local dampingForce = -self.Damping * self.m_velocity
        local totalForce = force + dampingForce
        
        self.m_velocity = self.m_velocity + totalForce * frametime
        self.m_value = self.m_value + self.m_velocity * frametime
    end]]

    function spring:Decay(frametime)
        frametime = math.min(frametime, 1 / 10)
        self.m_value, self.m_velocity = self:Step(self.m_value, self.m_velocity, self.m_target, frametime)
    end

    function spring:Get()
        return self.m_value
    end

    function spring:Input(val)
        --self.m_velocity = self.m_velocity + (val + math.Rand(val * self.Random, val * -self.Random))
        self.m_target = val
    end

    return spring
end