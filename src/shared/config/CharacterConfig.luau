--!strict

return table.freeze({
	CharacterSlotLimit = 5,
	NicknameMinLength = 3,
	NicknameMaxLength = 16,
	RequestWindowSeconds = 10,
	RequestsPerWindow = 12,
	DeleteConfirmationPrefix = "DELETE:",
	BuildLabel = "dev0.3-playtest-rc1",
})
