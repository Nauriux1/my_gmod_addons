AddCSLuaFile()
module("mw_math", package.seeall)

--globals
--ik zero_vector and zero_angle exist, i'm just making sure i'm managing my own
mw_math.ZeroVector = Vector(0, 0, 0)
mw_math.ZeroAngle = Angle(0, 0, 0)

local cachedSquareRoots = {}

function mw_math.SquareRoot(val)
    val = math.floor(val)
    cachedSquareRoots[val] = cachedSquareRoots[val] || math.sqrt(val)
    return cachedSquareRoots[val]
end

function mw_math.CosineInterp(rate, current, target)
    rate = (1 - math.cos(rate * math.pi)) * 0.5
    return current * (1 - rate) + target * rate
end

--lerp
local clamp = math.Clamp
local lerp = Lerp

function mw_math.SafeLerp(rate, current, target)
    --[[if (math.abs(current - target) < 0.001) then
        return target
    end

    return Lerp(math.Clamp(rate, 0, 1), current, target)]]

    return lerp(clamp(rate, 0, 1), current, target)
end

function mw_math.SafeLerpVector(rate, current, target)
    current.x = SafeLerp(rate, current.x, target.x)
    current.y = SafeLerp(rate, current.y, target.y)
    current.z = SafeLerp(rate, current.z, target.z)
end

function mw_math.SafeLerpAngle(rate, current, target)
    current.p = SafeLerp(rate, current.p, target.p)
    current.y = SafeLerp(rate, current.y, target.y)
    current.r = SafeLerp(rate, current.r, target.r)
end

--add and mul
function mw_math.VectorAddAndMul(current, add, mul)
    current.x = current.x + (add.x * mul)
    current.y = current.y + (add.y * mul)
    current.z = current.z + (add.z * mul)
end

function mw_math.AngleAddAndMul(current, add, mul)
    current.p = current.p + (add.p * mul)
    current.y = current.y + (add.y * mul)
    current.r = current.r + (add.r * mul)
end

--spring
function mw_math.CreateSpring(springConstant, wobbleConstant)
    local spring = {
        target = 0,
        lerp = 0,
        vel = 0,
        sc = springConstant,
        wc = wobbleConstant,

        SetTarget = function(spring, target)
            spring.target = target
        end,

        Decay = function(spring, springConstant, wobbleConstant)
            spring.lerp, spring.vel = mw_math.NumberDecay(spring.target, spring.lerp, spring.vel, spring.sc || springConstant, spring.wc || wobbleConstant)
        end,

        GetValue = function(spring) 
            return spring.lerp 
        end
    }

    return spring
end

function mw_math.CreateVectorSpring(springConstant, wobbleConstant)
    local spring = {
        target = Vector(),
        lerp = Vector(),
        vel = Vector(),
        sc = springConstant,
        wc = wobbleConstant,

        SetTarget = function(spring, target)
            spring.target = target
        end,

        Decay = function(spring, springConstant, wobbleConstant)
            mw_math.VectorDecay(spring.target, spring.lerp, spring.vel, spring.sc || springConstant, spring.wc || wobbleConstant)
        end,

        GetValue = function(spring) 
            return spring.lerp 
        end
    }

    return spring
end

function mw_math.CreateAngleSpring(springConstant, wobbleConstant)
    local spring = {
        target = Angle(),
        lerp = Angle(),
        vel = Angle(),
        sc = springConstant,
        wc = wobbleConstant,

        SetTarget = function(spring, target)
            spring.target = target
        end,

        Decay = function(spring, springConstant, wobbleConstant)
            mw_math.AngleDecay(spring.target, spring.lerp, spring.vel, spring.sc || springConstant, spring.wc || wobbleConstant)
        end,

        GetValue = function(spring) 
            return spring.lerp 
        end
    }

    return spring
end

function mw_math.DecaySprings(...)
    --[[for _, s in pairs({...}) do
        s:Decay()
    end]]
    local args = {...}
    for s = 1, #args do
        args[s]:Decay()
    end
end

local realFrameTime = RealFrameTime
local gcVec = Vector()
local gcVecForce = Vector()
function mw_math.VectorDecay(target, lerp, vel, springConstant, wobbleConstant)
    gcVec.x = (target.x - lerp.x) * springConstant
    gcVec.y = (target.y - lerp.y) * springConstant
    gcVec.z = (target.z - lerp.z) * springConstant

    local sq = SquareRoot(springConstant)

    gcVecForce.x = (-vel.x * wobbleConstant) * sq
    gcVecForce.y = (-vel.y * wobbleConstant) * sq 
    gcVecForce.z = (-vel.z * wobbleConstant) * sq

    gcVec.x = gcVec.x + gcVecForce.x
    gcVec.y = gcVec.y + gcVecForce.y
    gcVec.z = gcVec.z + gcVecForce.z

    local rft = realFrameTime()
    VectorAddAndMul(vel, gcVec, rft)
    VectorAddAndMul(lerp, vel, rft)
end

local gcAng = Angle()
local gcAngForce = Angle()
function mw_math.AngleDecay(target, lerp, vel, springConstant, wobbleConstant)
    gcAng.p = (target.p - lerp.p) * springConstant
    gcAng.y = (target.y - lerp.y) * springConstant
    gcAng.r = (target.r - lerp.r) * springConstant

    local sq = SquareRoot(springConstant)

    gcAngForce.p = (-vel.p * wobbleConstant) * sq
    gcAngForce.y = (-vel.y * wobbleConstant) * sq
    gcAngForce.r = (-vel.r * wobbleConstant) * sq

    gcAng.p = gcAng.p + gcAngForce.p
    gcAng.y = gcAng.y + gcAngForce.y
    gcAng.r = gcAng.r + gcAngForce.r

    local rft = realFrameTime()
    AngleAddAndMul(vel, gcAng, rft)
    AngleAddAndMul(lerp, vel, rft)
end

function mw_math.NumberDecay(target, lerp, vel, springConstant, wobbleConstant)
    local currentToTarget = (target - lerp) * springConstant
    local dampingForce = (-vel * wobbleConstant) * SquareRoot(springConstant)

    currentToTarget = currentToTarget + dampingForce

    local rft = realFrameTime()
    vel = vel + (currentToTarget * rft)
    lerp = lerp + (vel * rft)

    return lerp, vel
end

--bool to number
local boolToNumber = {[false] = 0, [true] = 1}
function mw_math.btn(bool)
    return boolToNumber[bool]
end

local direction = {[false] = -1, [true] = 1}
local minmax = {[false] = math.max, [true] = math.min}
function mw_math.Approach(current, target, rate)
    local what = current < target
    rate = rate * direction[what]
    return minmax[what](current + rate, -target, target)
end

local angleDifference = math.AngleDifference
function mw_math.ApproachAngle(current, target, rate)
    local diff = angleDifference(target, current)
    return mw_math.Approach(current, current + diff, rate)
end

function mw_math.PackRGB(r, g, b)
    return r * 65536 + g * 256 + b
end

function mw_math.UnpackRGB(color)
    local r = math.floor(color / 65536) % 256
    local g = math.floor(color / 256) % 256
    local b = color % 256
    
    return r, g, b
end