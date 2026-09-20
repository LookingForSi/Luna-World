--!strict

local ProgressionConfig = {
	LevelCap = 15,
	LevelAttribute = "Level",
	ExperienceAttribute = "LevelXP",

	ExperienceRequiredByLevel = table.freeze({
		[1] = 100,
		[2] = 160,
		[3] = 240,
		[4] = 340,
		[5] = 460,
		[6] = 600,
		[7] = 760,
		[8] = 940,
		[9] = 1140,
		[10] = 1360,
		[11] = 1600,
		[12] = 1860,
		[13] = 2140,
		[14] = 2440,
	}),

	ArchetypeBaseMaxHealth = table.freeze({
		knight = 100,
		ranger = 100,
		mystic = 100,
	}),

	ArchetypeGrowthPerLevel = table.freeze({
		knight = table.freeze({
			maxHealth = 10,
			maxResource = 3,
			physicalAttack = 2,
			magicAttack = 0,
			physicalDefense = 1.5,
			criticalChance = 0.002,
		}),
		ranger = table.freeze({
			maxHealth = 7,
			maxResource = 4,
			physicalAttack = 2,
			magicAttack = 0,
			physicalDefense = 1,
			criticalChance = 0.0035,
		}),
		mystic = table.freeze({
			maxHealth = 6,
			maxResource = 6,
			physicalAttack = 0,
			magicAttack = 2.5,
			physicalDefense = 0.75,
			criticalChance = 0.002,
		}),
	}),
}

return table.freeze(ProgressionConfig)
