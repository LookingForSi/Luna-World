--!strict

return table.freeze({
	Version = 1,
	MemoryStoreMapName = "LunaWorldExperienceSessionsV1",
	LeaseSeconds = 45,
	HeartbeatSeconds = 12,
	SessionIdMinLength = 16,
	SessionIdMaxLength = 128,
	ConflictKickMessage = "Luna World уже запущена на другом устройстве. Закройте игру там и подключитесь снова.",
	GuardUnavailableKickMessage = "Не удалось проверить игровую сессию Luna World. Попробуйте подключиться ещё раз через несколько секунд.",
})
