--!strict

local CombatTypes = require(script.Parent.Parent.types.CombatTypes)

local function ability(values: any): CombatTypes.MobAbilityDefinition
	return table.freeze(values) :: CombatTypes.MobAbilityDefinition
end

local definitions: { [string]: CombatTypes.MobAbilityDefinition } = {
	wolf_pack_howl = ability({
		id = "wolf_pack_howl", displayName = "Вой стаи", kind = "AllyDamageBuff",
		damageType = "Physical", range = 28, damage = 0, windupSeconds = 0.6, cooldownSeconds = 18,
		presentationKey = "mob_wolf_howl", durationSeconds = 8, damageMultiplier = 1.15, radius = 34,
	}),
	goblin_sling_stone = ability({
		id = "goblin_sling_stone", displayName = "Камень из пращи", kind = "DirectDamage",
		damageType = "Physical", range = 40, damage = 20, windupSeconds = 0.5, cooldownSeconds = 6,
		presentationKey = "mob_goblin_sling",
	}),
	goblin_spirit_bolt = ability({
		id = "goblin_spirit_bolt", displayName = "Духовный снаряд", kind = "DirectDamage",
		damageType = "Magic", range = 46, damage = 24, windupSeconds = 0.7, cooldownSeconds = 4.5,
		presentationKey = "mob_spirit_bolt",
	}),
	goblin_war_chant = ability({
		id = "goblin_war_chant", displayName = "Боевой напев", kind = "AllyDamageBuff",
		damageType = "Magic", range = 38, damage = 0, windupSeconds = 0.9, cooldownSeconds = 18,
		presentationKey = "mob_war_chant", durationSeconds = 10, damageMultiplier = 1.20, radius = 42,
	}),
	goblin_heavy_strike = ability({
		id = "goblin_heavy_strike", displayName = "Тяжёлый удар", kind = "DirectDamage",
		damageType = "Physical", range = 12, damage = 34, windupSeconds = 0.65, cooldownSeconds = 6,
		presentationKey = "mob_heavy_strike",
	}),
	goblin_battle_cry = ability({
		id = "goblin_battle_cry", displayName = "Боевой клич", kind = "SelfDamageBuff",
		damageType = "Physical", range = 16, damage = 0, windupSeconds = 0.7, cooldownSeconds = 24,
		presentationKey = "mob_battle_cry", durationSeconds = 10, damageMultiplier = 1.30, healthBelowFraction = 0.60,
	}),
	spider_venom_spit = ability({
		id = "spider_venom_spit", displayName = "Ядовитый плевок", kind = "DamageOverTime",
		damageType = "Magic", range = 38, damage = 6, windupSeconds = 0.55, cooldownSeconds = 7,
		presentationKey = "mob_venom_spit", durationSeconds = 8, tickDamage = 4, tickIntervalSeconds = 2,
	}),
	spider_crippling_venom = ability({
		id = "spider_crippling_venom", displayName = "Парализующий яд", kind = "Crippling",
		damageType = "Magic", range = 35, damage = 5, windupSeconds = 0.7, cooldownSeconds = 11,
		presentationKey = "mob_crippling_venom", durationSeconds = 6, movementMultiplier = 0.65, attackSpeedMultiplier = 0.75,
	}),
	brood_venom_spit = ability({
		id = "brood_venom_spit", displayName = "Густой яд", kind = "DamageOverTime",
		damageType = "Magic", range = 42, damage = 9, windupSeconds = 0.55, cooldownSeconds = 6.5,
		presentationKey = "mob_brood_venom", durationSeconds = 8, tickDamage = 6, tickIntervalSeconds = 2,
	}),
	brood_crippling_venom = ability({
		id = "brood_crippling_venom", displayName = "Сковывающий яд", kind = "Crippling",
		damageType = "Magic", range = 38, damage = 7, windupSeconds = 0.75, cooldownSeconds = 10,
		presentationKey = "mob_brood_cripple", durationSeconds = 7, movementMultiplier = 0.58, attackSpeedMultiplier = 0.70,
	}),
	dire_wolf_pounce = ability({
		id = "dire_wolf_pounce", displayName = "Рывок", kind = "DirectDamage",
		damageType = "Physical", range = 24, damage = 30, windupSeconds = 0.4, cooldownSeconds = 8,
		presentationKey = "mob_wolf_pounce",
	}),
	skeleton_arrow = ability({
		id = "skeleton_arrow", displayName = "Костяная стрела", kind = "DirectDamage",
		damageType = "Physical", range = 48, damage = 28, windupSeconds = 0.55, cooldownSeconds = 3.8,
		presentationKey = "mob_skeleton_arrow",
	}),
	grave_guardian_slam = ability({
		id = "grave_guardian_slam", displayName = "Могильный удар", kind = "DirectDamage",
		damageType = "Physical", range = 13, damage = 42, windupSeconds = 0.8, cooldownSeconds = 6.5,
		presentationKey = "mob_grave_slam",
	}),
	acolyte_arcane_bolt = ability({
		id = "acolyte_arcane_bolt", displayName = "Осквернённый снаряд", kind = "DirectDamage",
		damageType = "Magic", range = 48, damage = 31, windupSeconds = 0.75, cooldownSeconds = 4,
		presentationKey = "mob_acolyte_bolt",
	}),
	acolyte_hex = ability({
		id = "acolyte_hex", displayName = "Печать немощи", kind = "Crippling",
		damageType = "Magic", range = 42, damage = 8, windupSeconds = 0.85, cooldownSeconds = 12,
		presentationKey = "mob_acolyte_hex", durationSeconds = 6, movementMultiplier = 0.80, attackSpeedMultiplier = 0.78,
	}),
	shrine_guardian_strike = ability({
		id = "shrine_guardian_strike", displayName = "Удар хранителя", kind = "DirectDamage",
		damageType = "Physical", range = 13, damage = 40, windupSeconds = 0.7, cooldownSeconds = 5.5,
		presentationKey = "mob_shrine_strike",
	}),
	ancient_sentinel_slam = ability({
		id = "ancient_sentinel_slam", displayName = "Удар древнего стража", kind = "AreaDamage",
		damageType = "Physical", range = 15, damage = 46, windupSeconds = 0.9, cooldownSeconds = 6,
		presentationKey = "mob_sentinel_slam", radius = 14,
	}),
	ancient_watcher_bolt = ability({
		id = "ancient_watcher_bolt", displayName = "Лунный импульс", kind = "DirectDamage",
		damageType = "Magic", range = 52, damage = 36, windupSeconds = 0.8, cooldownSeconds = 4.5,
		presentationKey = "mob_watcher_bolt",
	}),
	warden_ground_slam = ability({
		id = "warden_ground_slam", displayName = "Сотрясение", kind = "AreaDamage",
		damageType = "Physical", range = 16, damage = 54, windupSeconds = 1.0, cooldownSeconds = 6,
		presentationKey = "mob_warden_slam", radius = 18,
	}),
	warden_moon_bolt = ability({
		id = "warden_moon_bolt", displayName = "Лунный разряд", kind = "DirectDamage",
		damageType = "Magic", range = 52, damage = 42, windupSeconds = 0.9, cooldownSeconds = 7,
		presentationKey = "mob_warden_bolt",
	}),
	warden_enrage = ability({
		id = "warden_enrage", displayName = "Пробуждение стража", kind = "SelfDamageBuff",
		damageType = "Physical", range = 18, damage = 0, windupSeconds = 0.8, cooldownSeconds = 28,
		presentationKey = "mob_warden_enrage", durationSeconds = 12, damageMultiplier = 1.35, healthBelowFraction = 0.50,
	}),
}

return table.freeze(definitions)
