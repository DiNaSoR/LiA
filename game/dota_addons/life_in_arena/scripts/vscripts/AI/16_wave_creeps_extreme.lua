require('survival/AIcreeps')

function Spawn(entityKeyValues)
	--print("Spawn")
    thisEntity:SetHullRadius(24) 
	if thisEntity:GetPlayerOwnerID() ~= -1 then
		return
	end
	
	ABILITY_16_wave_mana_burn = thisEntity:FindAbilityByName("16_wave_mana_burn_extreme")
	thisEntity:SetContextThink( "16_wave_think", Think16Wave , 0.1)
end

function Think16Wave()
	if not thisEntity:IsAlive() or thisEntity:IsIllusion() then
		return nil 
	end

	if GameRules:IsGamePaused() then
		return 1
	end

	AICreepsAttackOneUnit({unit = thisEntity})
	--print(Survival.AICreepCasts)

	if thisEntity:IsStunned() then 
		return 2 
	end
		
	if ABILITY_16_wave_mana_burn:IsFullyCastable() and Survival.AICreepCasts < Survival.AIMaxCreepCasts then
		local targets = FindUnitsInRadius(thisEntity:GetTeam(), 
						  thisEntity:GetOrigin(), 
						  nil, 
						  500, 
						  DOTA_UNIT_TARGET_TEAM_ENEMY, 
						  DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, 
						  DOTA_UNIT_TARGET_FLAG_MANA_ONLY, 
						  FIND_ANY_ORDER, 
						  false)
		if #targets ~= 0 then
			thisEntity:CastAbilityOnTarget(targets[RandomInt(1,#targets)], ABILITY_16_wave_mana_burn, -1)
			Survival.AICreepCasts = Survival.AICreepCasts + 1
		end
	end	
	
	return 2
end