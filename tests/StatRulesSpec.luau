--!strict

local StatRules = require(game.ReplicatedStorage.Shared.progression.StatRules)

return function(TestRunner)
	TestRunner.run("level one derived stats preserve milestone one combat baselines", function()
		local knight = StatRules.derive("knight", 1, nil)
		assert(knight.maxHealth == 100)
		assert(knight.maxResource == 100)
		assert(knight.physicalAttack == 25)
		assert(knight.physicalDefense == 12)
		assert(knight.movementSpeed == 17)

		local ranger = StatRules.derive("ranger", 1, nil)
		assert(ranger.physicalAttack == 23)
		assert(ranger.movementSpeed == 16)

		local mystic = StatRules.derive("mystic", 1, nil)
		assert(mystic.magicAttack == 27)
		assert(mystic.movementSpeed == 16)
	end)

	TestRunner.run("approved per-level growth is deterministic for levels five and ten", function()
		local knight5 = StatRules.derive("knight", 5, nil)
		assert(knight5.maxHealth == 140)
		assert(knight5.maxResource == 112)
		assert(knight5.physicalAttack == 33)
		assert(knight5.physicalDefense == 18)

		local ranger10 = StatRules.derive("ranger", 10, nil)
		assert(ranger10.maxHealth == 163)
		assert(ranger10.maxResource == 136)
		assert(ranger10.physicalAttack == 41)
		assert(math.abs(ranger10.criticalChance - 0.1515) < 0.000001)

		local mystic10 = StatRules.derive("mystic", 10, nil)
		assert(mystic10.maxHealth == 154)
		assert(mystic10.maxResource == 154)
		assert(mystic10.magicAttack == 49.5)
		assert(mystic10.physicalDefense == 11.75)
	end)

	TestRunner.run("level fifteen continues archetype growth beyond the old vertical slice", function()
		local knight15 = StatRules.derive("knight", 15, nil)
		assert(knight15.maxHealth == 240)
		assert(knight15.maxResource == 142)
		assert(knight15.physicalAttack == 53)
		assert(knight15.physicalDefense == 33)

		local ranger15 = StatRules.derive("ranger", 15, nil)
		assert(ranger15.maxHealth == 198)
		assert(ranger15.maxResource == 156)
		assert(ranger15.physicalAttack == 51)
		assert(math.abs(ranger15.criticalChance - 0.169) < 0.000001)

		local mystic15 = StatRules.derive("mystic", 15, nil)
		assert(mystic15.maxHealth == 184)
		assert(mystic15.maxResource == 184)
		assert(mystic15.magicAttack == 62)
		assert(mystic15.physicalDefense == 15.5)
	end)

	TestRunner.run("equipment modifiers compose once and cannot change movement speed", function()
		local derived = StatRules.derive("knight", 2, {
			maxHealth = 15,
			maxResource = 7,
			physicalAttack = 4,
			magicAttack = 2,
			physicalDefense = 3,
			criticalChance = 0.01,
			attackSpeedMultiplier = 0.25,
		})
		assert(derived.maxHealth == 125)
		assert(derived.maxResource == 110)
		assert(derived.physicalAttack == 31)
		assert(derived.magicAttack == 2)
		assert(derived.physicalDefense == 16.5)
		assert(math.abs(derived.criticalChance - 0.112) < 0.000001)
		assert(derived.attackSpeedMultiplier == 1.25)
		assert(derived.movementSpeed == 17)
	end)
end
