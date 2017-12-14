tauren_champion_champions_jump = class({})
LinkLuaModifier("modifier_tauren_champion_champions_jump","heroes/TaurenChampion/tauren_champion_champions_jump.lua",LUA_MODIFIER_MOTION_BOTH)

function tauren_champion_champions_jump:OnSpellStart() 
	if IsServer() then
		self.duration = self:GetSpecialValueFor("duration")
		
		local kv =
		{
			vLocX = self:GetCursorPosition().x,
			vLocY = self:GetCursorPosition().y,
			vLocZ = self:GetCursorPosition().z
		}

		self:GetCaster():AddNewModifier( self:GetCaster(), self, "modifier_tauren_champion_champions_jump", kv )
	end
end

-------------------------------------------------------------------------------

modifier_tauren_champion_champions_jump = class({})

--------------------------------------------------------------------------------

local MINIMUM_HEIGHT_ABOVE_LOWEST = 600
local MINIMUM_HEIGHT_ABOVE_HIGHEST = 400
local ACCELERATION_Z = 1500
local MAX_HORIZONTAL_ACCELERATION = 1500

--------------------------------------------------------------------------------

function modifier_tauren_champion_champions_jump:IsHidden()
	return true
end

--------------------------------------------------------------------------------

function modifier_tauren_champion_champions_jump:IsPurgable()
	return false
end

--------------------------------------------------------------------------------

function modifier_tauren_champion_champions_jump:RemoveOnDeath()
	return false
end

--------------------------------------------------------------------------------

function modifier_tauren_champion_champions_jump:OnCreated( kv )
	if IsServer() then
		self.bHorizontalMotionInterrupted = false
		self.bDamageApplied = false
		self.bTargetTeleported = false

		if self:ApplyHorizontalMotionController() == false or self:ApplyVerticalMotionController() == false then 
			self:Destroy()
			return
		end

		self.vStartPosition = GetGroundPosition( self:GetParent():GetOrigin(), self:GetParent() )
		self.flCurrentTimeHoriz = 0.0
		self.flCurrentTimeVert = 0.0

		self.vLoc = Vector( kv.vLocX, kv.vLocY, kv.vLocZ )
		self.vLastKnownTargetPos = self.vLoc

		local duration = self:GetAbility():GetSpecialValueFor( "duration" )
		local flDesiredHeight = MINIMUM_HEIGHT_ABOVE_LOWEST * duration * duration
		local flLowZ = math.min( self.vLastKnownTargetPos.z, self.vStartPosition.z )
		local flHighZ = math.max( self.vLastKnownTargetPos.z, self.vStartPosition.z )
		local flArcTopZ = math.max( flLowZ + flDesiredHeight, flHighZ + MINIMUM_HEIGHT_ABOVE_HIGHEST )

		local flArcDeltaZ = flArcTopZ - self.vStartPosition.z
		self.flInitialVelocityZ = math.sqrt( 2.0 * flArcDeltaZ * ACCELERATION_Z )

		local flDeltaZ = self.vLastKnownTargetPos.z - self.vStartPosition.z
		local flSqrtDet = math.sqrt( math.max( 0, ( self.flInitialVelocityZ * self.flInitialVelocityZ ) - 2.0 * ACCELERATION_Z * flDeltaZ ) )
		self.flPredictedTotalTime = math.max( ( self.flInitialVelocityZ + flSqrtDet) / ( ACCELERATION_Z ), ( self.flInitialVelocityZ - flSqrtDet) / ( ACCELERATION_Z ) )

		self.vHorizontalVelocity = ( self.vLastKnownTargetPos - self.vStartPosition ) / self.flPredictedTotalTime
		self.vHorizontalVelocity.z = 0.0
	end
end

--------------------------------------------------------------------------------

function modifier_tauren_champion_champions_jump:OnDestroy()
	if IsServer() then
		self:GetParent():RemoveHorizontalMotionController( self )
		self:GetParent():RemoveVerticalMotionController( self )
		self.radius = self:GetAbility():GetSpecialValueFor("radius")
		self.stun_duration = self:GetAbility():GetSpecialValueFor("stun_duration")
		self.land_damage = self:GetAbility():GetSpecialValueFor("land_damage")
		local targets = FindUnitsInRadius(self:GetParent():GetTeam(), 
											self:GetParent():GetAbsOrigin(), 
											nil, self.radius, 
											DOTA_UNIT_TARGET_TEAM_ENEMY, 
											DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, 
											0, 0, false)

		for k,v in pairs (targets) do
			v:ApplyDamage({ victim = v, attacker = self:GetCaster(), damage = land_damage, damage_type = DAMAGE_TYPE_MAGICAL, ability = self:GetAbility() })
			v:AddNewModifier(self:GetCaster(), self:GetAbility(), "modifier_stunned", {duration = self:stun_duration})
		end
	end
end

--------------------------------------------------------------------------------

function modifier_tauren_champion_champions_jump:CheckState()
	local state =
	{
		[MODIFIER_STATE_STUNNED] = true,
--		[MODIFIER_STATE_UNSELECTABLE] = true,
	}

	return state
end

--------------------------------------------------------------------------------

function modifier_tauren_champion_champions_jump:UpdateHorizontalMotion( me, dt )
	if IsServer() then
		self.flCurrentTimeHoriz = math.min( self.flCurrentTimeHoriz + dt, self.flPredictedTotalTime )
		local t = self.flCurrentTimeHoriz / self.flPredictedTotalTime
		local vStartToTarget = self.vLastKnownTargetPos - self.vStartPosition
		local vDesiredPos = self.vStartPosition + t * vStartToTarget

		local vOldPos = me:GetOrigin()
		local vToDesired = vDesiredPos - vOldPos
		vToDesired.z = 0.0
		local vDesiredVel = vToDesired / dt
		local vVelDif = vDesiredVel - self.vHorizontalVelocity
		local flVelDif = vVelDif:Length2D()
		vVelDif = vVelDif:Normalized()
		local flVelDelta = math.min( flVelDif, MAX_HORIZONTAL_ACCELERATION )

		self.vHorizontalVelocity = self.vHorizontalVelocity + vVelDif * flVelDelta * dt
		local vNewPos = vOldPos + self.vHorizontalVelocity * dt
		me:SetOrigin( vNewPos )
	end
end

--------------------------------------------------------------------------------

function modifier_tauren_champion_champions_jump:UpdateVerticalMotion( me, dt )
	if IsServer() then
		self.flCurrentTimeVert = self.flCurrentTimeVert + dt
		local bGoingDown = ( -ACCELERATION_Z * self.flCurrentTimeVert + self.flInitialVelocityZ ) < 0
		
		local vNewPos = me:GetOrigin()
		vNewPos.z = self.vStartPosition.z + ( -0.5 * ACCELERATION_Z * ( self.flCurrentTimeVert * self.flCurrentTimeVert ) + self.flInitialVelocityZ * self.flCurrentTimeVert )

		local flGroundHeight = GetGroundHeight( vNewPos, self:GetParent() )
		local bLanded = false
		if ( vNewPos.z < flGroundHeight and bGoingDown == true ) then
			vNewPos.z = flGroundHeight
			bLanded = true
		end

		me:SetOrigin( vNewPos )
		if bLanded == true then
			if self.bHorizontalMotionInterrupted == false then
				self:GetAbility():Splatter()
			end

			self:Destroy()
		end
	end
end

--------------------------------------------------------------------------------

function modifier_tauren_champion_champions_jump:OnHorizontalMotionInterrupted()
	if IsServer() then
		self.bHorizontalMotionInterrupted = true
	end
end

--------------------------------------------------------------------------------

function modifier_tauren_champion_champions_jump:OnVerticalMotionInterrupted()
	if IsServer() then
		self:Destroy()
	end
end

--------------------------------------------------------------------------------

function modifier_tauren_champion_champions_jump:DeclareFunctions()
	local funcs =
	{
		MODIFIER_PROPERTY_OVERRIDE_ANIMATION,
	}
	return funcs
end

--------------------------------------------------------------------------------

function modifier_tauren_champion_champions_jump:GetOverrideAnimation( params )
	return ACT_DOTA_CAST_ABILITY_2
end