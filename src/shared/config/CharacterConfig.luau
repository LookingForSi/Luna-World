--!strict

local BuildInfo = require(script.Parent.BuildInfo)

return table.freeze({
	CharacterSlotLimit = 5,
	NicknameMinLength = 3,
	NicknameMaxLength = 16,
	RequestWindowSeconds = 10,
	RequestsPerWindow = 12,
	DeleteConfirmationPrefix = "DELETE:",
	BuildLabel = BuildInfo.BuildLabel,
	NicknameAttribute = "CharacterNickname",
	BodyTypeAttribute = "CharacterBodyType",
	AppearancePresetAttribute = "CharacterAppearancePreset",
})
