--!strict

local AccountSchema = require(script.Parent.AccountSchema)
local CharacterConfig = require(script.Parent.Parent.config.CharacterConfig)
local PersistenceTypes = require(script.Parent.Parent.types.PersistenceTypes)

local MigrationRules = {}

export type Migration = (any) -> any
export type Registry = { [number]: Migration }

local function deepClone(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local cloned = {}
	for key, child in value do
		cloned[deepClone(key)] = deepClone(child)
	end
	return cloned
end

local DEFAULT_MIGRATIONS: Registry = {
	[0] = function(old: any): any
		return {
			DataVersion = 1,
			Level = old.Level or 1,
			XP = old.XP or old.SessionXP or 0,
			Luna = old.Luna or 0,
			ArchetypeId = old.ArchetypeId or "knight",
			Items = old.Items or {},
			Inventory = old.Inventory or {},
			Equipment = old.Equipment or {},
		}
	end,
	[1] = function(old: any): any
		old.DataVersion = 2
		old.Quests = {}
		return old
	end,
	[2] = function(old: any): any
		local characterId = "legacy-" .. tostring(old.LegacyCharacterId or "primary")
		old.DataVersion = 2
		local character = deepClone(old)
		character.CharacterId = characterId
		character.Nickname = nil
		character.BodyType = nil
		character.AppearancePresetId = nil
		character.CreatedAt = 0
		character.LastPlayedAt = 0
		character.LastZoneId = nil
		character.NeedsIdentity = true
		return {
			DataVersion = 3,
			CharacterSlotLimit = CharacterConfig.CharacterSlotLimit,
			CharacterOrder = { characterId },
			Characters = { [characterId] = character },
			SelectedCharacterId = nil,
			Settings = { UiScale = 1, TextScale = 1, SoundVolume = 1 },
		}
	end,
}

function MigrationRules.run(rawProfile: unknown, registry: Registry?): (PersistenceTypes.AccountProfile?, string?)
	if typeof(rawProfile) ~= "table" then
		return nil, "profile must be a table"
	end
	local working: any = deepClone(rawProfile)
	local version = working.DataVersion
	if typeof(version) ~= "number" or version ~= version or version % 1 ~= 0 or version < 0 then
		return nil, "profile DataVersion is invalid"
	end
	if version > AccountSchema.DataVersion then
		return nil, "profile DataVersion is newer than this server"
	end

	local migrations = registry or DEFAULT_MIGRATIONS
	while version < AccountSchema.DataVersion do
		local migrate = migrations[version]
		if migrate == nil then
			return nil, string.format("missing migration from DataVersion %d", version)
		end
		local ok, migrated = pcall(migrate, working)
		if not ok or typeof(migrated) ~= "table" then
			return nil, string.format("migration from DataVersion %d failed", version)
		end
		working = migrated
		local nextVersion = working.DataVersion
		if typeof(nextVersion) ~= "number" or nextVersion ~= version + 1 then
			return nil, string.format("migration from DataVersion %d did not advance exactly one version", version)
		end
		version = nextVersion
	end

	local valid, reason = AccountSchema.validateCurrent(working)
	if not valid then
		return nil, reason or "migrated profile is invalid"
	end
	return working :: PersistenceTypes.AccountProfile, nil
end

return table.freeze(MigrationRules)
