--!strict

-- Values in this module are working tuning defaults, not final balance.
return table.freeze({
	BasicAttackDamage = 25,
	BasicAttackRange = 12,
	BasicAttackInterval = 1.2,
	RangerBasicAttackRange = 55,
	RangerBasicAttackInterval = 1.4,
	MysticBasicAttackRange = 50,
	MysticBasicAttackInterval = 1.5,
	InputBufferSeconds = 0.2,
	RangeTolerance = 1.5,
	FacingArcDegrees = 120,
	MinAttackSpeedMultiplier = 0.5,
	MaxAttackSpeedMultiplier = 2,
	CriticalDamageMultiplier = 1.5,
	CooldownGroups = table.freeze({
		basic_attack = true,
		power_strike = true,
		shield_bash = true,
		defensive_stance = true,
		power_shot = true,
		rapid_shot = true,
		snare = true,
		arcane_bolt = true,
		flame_burst = true,
		heal = true,
	}),
	TargetSelectionRange = 100,
	SelectedTargetAttribute = "SelectedTargetEntityId",
	BasicAttackingAttribute = "IsBasicAttacking",
})
